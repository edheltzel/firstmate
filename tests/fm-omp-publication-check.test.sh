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

test_missing_tracked_path_refuses() {
  local manifest="$TMP_ROOT/missing-path.json" out status=0
  jq '.tracked_paths += ["bin/not-a-real-firstmate-path.sh"]' \
    "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "missing tracked publication path should block"
  assert_contains "$out" 'not tracked: bin/not-a-real-firstmate-path.sh' "missing tracked path refusal was not reported"
  pass "omp-publication-check: missing tracked path is refused"
}

test_unknown_changed_path_refuses() {
  local state="$TMP_ROOT/unknown-path.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq -n '{schema:"omp-publication-state.v1",state:"post",support_fence:"experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support",changed_paths:["state/not-in-inventory"]}' >"$state"
  out=$($CHECK --json --simulate "$state") || status=$?
  expect_code 1 "$status" "unknown changed publication path should block"
  assert_contains "$out" 'outside the publication inventory' "unknown changed path refusal was not reported"
  pass "omp-publication-check: unknown changed path is refused"
}

test_source_owner_token_drift_refuses() {
  local manifest="$TMP_ROOT/missing-creator-token.json" out status=0
  jq '.artifacts[0].creator[0].tokens = ["missing-creator-token"]' \
    "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "missing creator source token should block"
  assert_contains "$out" 'creator source token is missing' "missing creator token refusal was not reported"
  jq '.artifacts[0].cleanup[0].tokens = ["missing-cleanup-token"]' \
    "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "missing cleanup source token should block"
  assert_contains "$out" 'cleanup source token is missing' "missing cleanup token refusal was not reported"
  pass "omp-publication-check: creator and cleanup source drift are refused"
}

test_stale_inventory_id_refuses() {
  local inventory="$TMP_ROOT/stale-inventory.md" out status=0 tick
  tick=$(printf '\140')
  cp "$ROOT/docs/omp-publication-inventory.md" "$inventory"
  printf '%s\n' "| ${tick}stale-inventory-row${tick} | stale | ${tick}state/stale${tick} | stale | stale | stale | stale |" >>"$inventory"
  out=$($CHECK --json --inventory "$inventory") || status=$?
  expect_code 1 "$status" "stale documentation inventory row should block"
  assert_contains "$out" 'unregistered inventory ID' "stale inventory refusal was not reported"
  pass "omp-publication-check: stale documentation inventory is refused"
}

test_inventory_passes
test_mixed_state_refuses
test_pre_and_post_state_pass
test_missing_tracked_path_refuses
test_unknown_changed_path_refuses
test_source_owner_token_drift_refuses
test_stale_inventory_id_refuses
