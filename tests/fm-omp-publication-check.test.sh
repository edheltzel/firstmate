#!/usr/bin/env bash
# Behavior tests for the OMP publication inventory and V29 interruption invariant.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-omp-publication-check.sh"
TMP_ROOT=$(fm_test_tmproot fm-omp-publication-check)

write_state() {
  local path=$1 state=$2
  mkdir -p "$TMP_ROOT"
  jq -n --arg state "$state" '{schema:"omp-publication-state.v1",state:$state,support_fence:"experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support",changed_paths:["state/{task}.pr-poll"]}' >"$path"
}

test_inventory_passes() {
  local out status=0
  out=$($CHECK --json) || status=$?
  expect_code 0 "$status" "publication inventory should pass"
  assert_contains "$out" '"status": "PASS"' "publication inventory did not pass"
  pass "omp-publication-check: exact artifact inventory passes"
}

test_mixed_state_refuses() {
  local state="$TMP_ROOT/mixed.json" out status=0
  write_state "$state" mixed
  out=$($CHECK --json --simulate "$state") || status=$?
  expect_code 1 "$status" "mixed publication state should block"
  assert_contains "$out" 'mixed old/new state' "mixed publication refusal was not reported"
  pass "omp-publication-check: mixed interruption state is refused"
}

test_pre_and_post_state_pass() {
  local state="$TMP_ROOT/pre.json" out status=0
  write_state "$state" pre
  out=$($CHECK --json --simulate "$state") || status=$?
  expect_code 0 "$status" "pre-publication state should pass"
  assert_contains "$out" '"status": "PASS"' "pre-publication state did not pass"
  write_state "$state" post
  out=$($CHECK --json --simulate "$state") || status=$?
  expect_code 0 "$status" "post-publication state should pass"
  assert_contains "$out" '"status": "PASS"' "post-publication state did not pass"
  pass "omp-publication-check: pre and post images pass"
}

test_inventory_passes
test_mixed_state_refuses
test_pre_and_post_state_pass
