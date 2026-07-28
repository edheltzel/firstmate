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
  local inventory_ids
  inventory_ids=$(jq -c '[.artifacts[].id]' "$ROOT/.agents/tasks/omp-publication-manifest.json")
  if [ "$state" = pre ]; then
    jq -n --arg state "$state" --argjson inventory_ids "$inventory_ids" '{schema:"omp-publication-state.v2",state:$state,support_fence:"experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support",inventory_ids:$inventory_ids,changed_paths:[],pre_paths:["state/{task}.pr-poll"],post_paths:["state/{task}.pr-poll"]}' >"$path"
  else
    jq -n --arg state "$state" --argjson inventory_ids "$inventory_ids" '{schema:"omp-publication-state.v2",state:$state,support_fence:"experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support",inventory_ids:$inventory_ids,changed_paths:["state/{task}.pr-poll"],pre_paths:["state/{task}.pr-poll"],post_paths:["state/{task}.pr-poll"]}' >"$path"
  fi
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

test_duplicate_machine_inventory_refuses() {
  local manifest="$TMP_ROOT/duplicate-inventory.json" out status
  jq '.artifacts += [.artifacts[0]]' "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  status=0
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "duplicate artifact ID should block"
  assert_contains "$out" 'duplicate artifact ID: shared-lock-identity' "duplicate artifact ID refusal was not reported"
  jq '.tracked_paths += [.tracked_paths[0]]' "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  status=0
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "duplicate tracked path should block"
  assert_contains "$out" 'duplicate tracked path:' "duplicate tracked path refusal was not reported"
  jq '.artifacts[1].paths += [.artifacts[1].paths[0]]' "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  status=0
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "duplicate artifact path should block"
  assert_contains "$out" 'duplicate artifact path: bin/fm-backend.sh' "duplicate artifact path refusal was not reported"
  jq '.artifacts[0].creator += [.artifacts[0].creator[0]]' "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  status=0
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "duplicate creator binding should block"
  assert_contains "$out" 'duplicate creator binding: shared-lock-identity:bin/fm-session-lock-lib.sh' "duplicate creator binding refusal was not reported"
  jq '.artifacts[0].cleanup += [.artifacts[0].cleanup[0]]' "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  status=0
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "duplicate cleanup binding should block"
  assert_contains "$out" 'duplicate cleanup binding: shared-lock-identity:bin/fm-lock.sh' "duplicate cleanup binding refusal was not reported"
  pass "omp-publication-check: duplicate machine inventory rows are refused"
}

test_unknown_changed_path_refuses() {
  local state="$TMP_ROOT/unknown-path.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq -n --argjson inventory_ids "$(jq -c '[.artifacts[].id]' "$ROOT/.agents/tasks/omp-publication-manifest.json")" '{schema:"omp-publication-state.v2",state:"post",support_fence:"experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support",inventory_ids:$inventory_ids,changed_paths:["state/not-in-inventory"],pre_paths:["state/{task}.pr-poll"],post_paths:["state/{task}.pr-poll"]}' >"$state"
  out=$($CHECK --json --simulate "$state") || status=$?
  expect_code 1 "$status" "unknown changed publication path should block"
  assert_contains "$out" 'outside the publication inventory' "unknown changed path refusal was not reported"
  jq '.changed_paths = ["state/{task}.pr-pol"]' "$state" >"$TMP_ROOT/substring-path.json"
  out=$($CHECK --json --simulate "$TMP_ROOT/substring-path.json") || status=$?
  expect_code 1 "$status" "substring-collision changed publication path should block"
  assert_contains "$out" 'outside the publication inventory: state/{task}.pr-pol' "substring-collision changed path refusal was not reported"
  pass "omp-publication-check: unknown changed path is refused"
}

test_false_pass_shapes_refuse() {
  local state="$TMP_ROOT/false-pass.json" out status=0
  write_state "$state" post
  jq '.changed_paths += [.changed_paths[0]]' "$state" >"$TMP_ROOT/duplicate.json"
  out=$($CHECK --json --simulate "$TMP_ROOT/duplicate.json") || status=$?
  expect_code 1 "$status" "duplicate changed paths should block"
  assert_contains "$out" 'changed path list contains duplicates' "duplicate changed paths were accepted"
  jq '.post_paths = []' "$state" >"$TMP_ROOT/empty-post.json"
  status=0
  out=$($CHECK --json --simulate "$TMP_ROOT/empty-post.json") || status=$?
  expect_code 1 "$status" "empty post image should block"
  assert_contains "$out" 'post image is empty' "empty post image was accepted"
  jq '.inventory_ids = .inventory_ids[0:1]' "$state" >"$TMP_ROOT/missing-group.json"
  status=0
  out=$($CHECK --json --simulate "$TMP_ROOT/missing-group.json") || status=$?
  expect_code 1 "$status" "partial inventory IDs should block"
  assert_contains "$out" 'inventory ID set is incomplete' "partial inventory IDs were accepted"
  pass "omp-publication-check: duplicate, empty, and partial states are refused"
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
  jq '.artifacts[0].rollback_owner = "wrong-owner"' \
    "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  status=0
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "rollback owner drift should block"
  assert_contains "$out" 'publication artifact lacks paths, creator, cleanup, rollback owner, or schemas' "rollback owner drift was not reported"
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

test_future_inventory_binding_refuses() {
  local manifest="$TMP_ROOT/missing-future.json" inventory="$TMP_ROOT/duplicate-future.md" out status=0 row
  jq '.future_paths = .future_paths[0:-1]' \
    "$ROOT/.agents/tasks/omp-publication-manifest.json" >"$manifest"
  out=$($CHECK --json --manifest "$manifest") || status=$?
  expect_code 1 "$status" "missing future publication path should block"
  assert_contains "$out" 'future-path set differs from manifest' "missing future path was not reported"
  cp "$ROOT/docs/omp-publication-inventory.md" "$inventory"
  # shellcheck disable=SC2016
  row=$(grep -F 'omp-publication-future-path: `bin/fm-omp-watcher.sh`' "$inventory")
  printf '%s\n' "$row" >>"$inventory"
  status=0
  out=$($CHECK --json --inventory "$inventory") || status=$?
  expect_code 1 "$status" "duplicate future publication path should block"
  assert_contains "$out" 'future-path rows are duplicated' "duplicate future path was not reported"
  pass "omp-publication-check: future watcher/continuity path-owner-schema bindings are exact"
}

test_duplicate_documentation_row_refuses() {
  local inventory="$TMP_ROOT/duplicate-inventory.md" row out status=0 tick
  tick=$(printf '\140')
  cp "$ROOT/docs/omp-publication-inventory.md" "$inventory"
  row=$(grep -F "| ${tick}shared-lock-identity${tick} |" "$inventory")
  printf '%s\n' "$row" >>"$inventory"
  out=$($CHECK --json --inventory "$inventory") || status=$?
  expect_code 1 "$status" "duplicate documentation row should block"
  assert_contains "$out" 'documentation row count is 2: shared-lock-identity' "duplicate documentation row refusal was not reported"
  pass "omp-publication-check: duplicate documentation rows are refused"
}

test_publication_tmpdir_failure_refuses() {
  local out status=0
  out=$(TMPDIR="$TMP_ROOT/missing-publication-tmp" $CHECK --json) || status=$?
  expect_code 1 "$status" "publication temporary-root failure should refuse"
  assert_contains "$out" 'could not allocate publication-check temporary workspace' "publication temporary-root failure was not reported"
  pass "omp-publication-check: temporary-root failure is fail-safe"
}

test_inventory_passes
test_mixed_state_refuses
test_pre_and_post_state_pass
test_missing_tracked_path_refuses
test_duplicate_machine_inventory_refuses
test_unknown_changed_path_refuses
test_false_pass_shapes_refuse
test_source_owner_token_drift_refuses
test_stale_inventory_id_refuses
test_future_inventory_binding_refuses
test_duplicate_documentation_row_refuses
test_publication_tmpdir_failure_refuses
