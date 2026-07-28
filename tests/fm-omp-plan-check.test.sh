#!/usr/bin/env bash
# Behavior tests for the OMP machine manifest and exact roadmap dependency graph.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-omp-plan-check.sh"
TMP_ROOT=$(fm_test_tmproot fm-omp-plan-check)

test_current_manifest_passes() {
  local out status=0
  out=$($CHECK --json) || status=$?
  expect_code 0 "$status" "current OMP manifest should pass its non-mutating validator"
  assert_contains "$out" '"status": "PASS"' "current OMP manifest did not return machine-readable PASS"
  assert_contains "$out" '"task_count": 28' "current OMP manifest task count drifted"
  pass "omp-plan-check: current manifest, roadmap, plan, and tracked backlog pass"
}

test_unknown_dependency_refuses() {
  local bad="$TMP_ROOT/missing-dependency.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq '.tasks[0].depends_on = ["omp-does-not-exist"]' \
    "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "unknown dependency should block the plan"
  assert_contains "$out" 'unknown dependency' "unknown dependency refusal was not reported"
  pass "omp-plan-check: unknown dependency is refused"
}

test_cycle_refuses() {
  local bad="$TMP_ROOT/cycle.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq '.tasks[0].depends_on = ["omp-final-plan-redteam-o6"] | .tasks[1].depends_on = ["omp-o5-plan-traceability"]' \
    "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "dependency cycle should block the plan"
  assert_contains "$out" 'dependency cycle detected' "dependency cycle refusal was not reported"
  pass "omp-plan-check: dependency cycle is refused"
}

test_forward_dependency_passes() {
  local forward="$TMP_ROOT/forward-dependency.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq '.tasks = [.tasks[0], .tasks[2], .tasks[1]] + .tasks[3:]' \
    "$ROOT/.agents/tasks/omp-manifest.json" >"$forward"
  out=$($CHECK --json --manifest "$forward") || status=$?
  expect_code 0 "$status" "a dependency on a later manifest row should remain valid"
  assert_contains "$out" '"status": "PASS"' "forward dependency was rejected by manifest order"
  pass "omp-plan-check: forward dependency is order-independent"
}

test_duplicate_stop_refuses() {
  local bad="$TMP_ROOT/duplicate-stop.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq '.stop_ids += [.stop_ids[0]]' "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "duplicate STOP identifier should block the plan"
  assert_contains "$out" 'duplicate STOP identifier' "duplicate STOP refusal was not reported"
  pass "omp-plan-check: duplicate STOP identifiers are refused"
}

test_duplicate_dependency_edge_refuses() {
  local bad="$TMP_ROOT/duplicate-dependency.json" out status=0
  jq '.tasks[1].depends_on += [.tasks[1].depends_on[0]]' "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "duplicate dependency edge should block the plan"
  assert_contains "$out" 'duplicate dependency edge' "duplicate dependency refusal was not reported"
  pass "omp-plan-check: duplicate dependency edges are refused"
}

test_duplicate_validation_refuses() {
  local bad="$TMP_ROOT/duplicate-validation.json" out status=0
  jq '.tasks[0].validation_ids += [.tasks[0].validation_ids[0]]' "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "duplicate validation identifier should block the plan"
  assert_contains "$out" 'duplicate per-task validation identifier' "duplicate validation refusal was not reported"
  pass "omp-plan-check: duplicate per-task validation identifiers are refused"
}

test_duplicate_evidence_refuses() {
  local bad="$TMP_ROOT/duplicate-evidence.json" out status=0
  jq '.tasks[0].evidence_ids += [.tasks[0].evidence_ids[0]]' "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "duplicate evidence identifier should block the plan"
  assert_contains "$out" 'duplicate per-task evidence identifier' "duplicate evidence refusal was not reported"
  pass "omp-plan-check: duplicate per-task evidence identifiers are refused"
}

test_report_identity_refuses() {
  local bad="$TMP_ROOT/identity-drift.json" out status=0
  jq '.activation_report_task_id = "omp-corrected-plan-redteam-o8"' "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "activation report identity drift should block the plan"
  assert_contains "$out" 'manifest activation report identity is not the O9 contract' "activation report identity refusal was not reported"
  pass "omp-plan-check: O9 report identity is exact"
}

test_o7_completion_state_parity_refuses() {
  local bad_plan="$TMP_ROOT/o7-state-plan.md" bad_roadmap="$TMP_ROOT/o7-state-roadmap.md" out status=0
  mkdir -p "$TMP_ROOT"
  sed 's/complete 2026-07-28; no runtime or support change/current planning\/tracking correction/' \
    "$ROOT/.agents/plans/omp-harness-integration-plan.md" >"$bad_plan"
  out=$($CHECK --json --plan "$bad_plan") || status=$?
  expect_code 1 "$status" "stale O7 plan state should block parity"
  assert_contains "$out" 'O7 completion state is not current in parity file' "stale O7 plan state was not reported"
  status=0
  sed 's/complete 2026-07-28; no runtime or support change/current planning\/tracking correction/' \
    "$ROOT/.agents/tasks/roadmap.md" >"$bad_roadmap"
  out=$($CHECK --json --roadmap "$bad_roadmap") || status=$?
  expect_code 1 "$status" "stale O7 roadmap state should block parity"
  assert_contains "$out" 'O7 completion state is not current in parity file' "stale O7 roadmap state was not reported"
  pass "omp-plan-check: O7 completion state parity is enforced"
}

test_tasks_axi_resolves_from_path() {
  local fakebin="$TMP_ROOT/fakebin" fake_axi out status=0
  mkdir -p "$fakebin"
  fake_axi="$fakebin/tasks-axi"
  cat >"$fake_axi" <<'SH'
#!/usr/bin/env bash
if [ "${1-}" = "--version" ]; then
  printf '%s\n' '0.2.3'
  exit 0
fi
exit 0
SH
  chmod +x "$fake_axi"
  out=$(TASKS_AXI='' PATH="$fakebin:$PATH" "$CHECK" --json) || status=$?
  expect_code 0 "$status" "Tasks Axi should resolve from PATH"
  assert_contains "$out" '"status": "PASS"' "PATH-resolved Tasks Axi did not pass"
  pass "omp-plan-check: Tasks Axi resolves from PATH"
}

test_plan_tmpdir_failure_refuses() {
  local out status=0
  out=$(TMPDIR="$TMP_ROOT/missing-plan-tmp" "$CHECK" --json) || status=$?
  expect_code 1 "$status" "plan-check temporary-root failure should refuse"
  assert_contains "$out" 'could not allocate plan-check temporary workspace' "plan-check temporary-root failure was not reported"
  pass "omp-plan-check: temporary-root failure is fail-safe"
}

test_current_manifest_passes
test_unknown_dependency_refuses
test_cycle_refuses
test_forward_dependency_passes
test_duplicate_stop_refuses
test_duplicate_dependency_edge_refuses
test_duplicate_validation_refuses
test_duplicate_evidence_refuses
test_report_identity_refuses
test_o7_completion_state_parity_refuses
test_tasks_axi_resolves_from_path
test_plan_tmpdir_failure_refuses
