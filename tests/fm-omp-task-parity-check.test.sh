#!/usr/bin/env bash
# Behavior tests for canonical OMP task semantic parity.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-omp-task-parity-check.sh"
TMP_ROOT=$(fm_test_tmproot fm-omp-task-parity-check)
mkdir -p "$TMP_ROOT"

test_current_contract_passes() {
  local out status=0
  out=$($CHECK --json) || status=$?
  expect_code 0 "$status" "current task contract should pass"
  assert_contains "$out" '"status": "PASS"' "current task contract did not pass"
  pass "omp-task-parity-check: canonical projections pass"
}

test_forged_semantic_field_refuses() {
  local bad="$TMP_ROOT/forged.json" out status=0
  jq '.tasks[0].title = "forged title"' "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
  out=$($CHECK --json --manifest "$bad") || status=$?
  expect_code 1 "$status" "forged task title should refuse"
  assert_contains "$out" 'manifest task contract digest' "forged task title was not bound to the digest"
  pass "omp-task-parity-check: forged semantic row is refused"
}

test_forged_contract_fields_refuse() {
  local expression bad out status label
  while IFS='|' read -r label expression; do
    bad="$TMP_ROOT/forged-$label.json"
    jq "$expression" "$ROOT/.agents/tasks/omp-manifest.json" >"$bad"
    out=$($CHECK --json --manifest "$bad") || status=$?
    status=${status:-0}
    expect_code 1 "$status" "forged $label should refuse"
    assert_contains "$out" 'manifest task contract digest' "forged $label was not bound to the digest"
    unset status
  done <<'EOF'
phase|.tasks[0].phase = "P9"
milestone|.tasks[0].milestone = "forged milestone"
title|.tasks[0].title = "forged title"
owner|.tasks[0].owner = "forged owner"
state|.tasks[0].state = "running"
validation|.tasks[0].validation_ids = ["V99"]
evidence|.tasks[0].evidence_ids = ["forged-evidence"]
rollback|.tasks[0].rollback_id = "forged-rollback"
dependency|.tasks[1].depends_on = ["missing-task"]
artifact|.tasks[0].artifact_paths.evidence = "data/forged/{task_id}.json"
EOF
  pass "omp-task-parity-check: forged phase/milestone/title/owner/state/validation/evidence/rollback/dependency/artifact rows are refused"
}

test_missing_projection_row_refuses() {
  local bad="$TMP_ROOT/missing.md" out status=0
  sed '/^<!-- omp-task-row: .*omp-final-authority-redteam-o10/d' "$ROOT/.agents/tasks/roadmap.md" >"$bad"
  out=$($CHECK --json --roadmap "$bad") || status=$?
  expect_code 1 "$status" "missing O10 projection row should refuse"
  assert_contains "$out" 'canonical task rows' "missing projection row was not reported"
  pass "omp-task-parity-check: incomplete projection is refused"
}

test_current_contract_passes
test_forged_semantic_field_refuses
test_forged_contract_fields_refuse
test_missing_projection_row_refuses
