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
  assert_contains "$out" '"task_count": 27' "current OMP manifest task count drifted"
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

test_current_manifest_passes
test_unknown_dependency_refuses
test_cycle_refuses
