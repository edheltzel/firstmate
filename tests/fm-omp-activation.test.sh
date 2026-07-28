#!/usr/bin/env bash
# Behavior tests for the fail-closed OMP activation gate and atomic P1 publication.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACTIVATION="$ROOT/bin/fm-omp-activation.sh"
TASKS_AXI=${TASKS_AXI:-$(command -v tasks-axi 2>/dev/null || true)}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-omp-activation-test.XXXXXX")

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

setup_fixture() {
  local repo="$TMP_ROOT/repo"
  rm -rf "$TMP_ROOT"
  mkdir -p "$TMP_ROOT/live" "$TMP_ROOT/records" "$TMP_ROOT/repo"
  fm_git_init_commit "$repo"
  printf '# OMP report\n\n## Executive disposition\n\nPASS\n' >"$TMP_ROOT/report.md"
  cp "$ROOT/.agents/tasks/backlog.md" "$TMP_ROOT/tracked-backlog.md"
  printf '%s\n' \
    '# Backlog' \
    '' \
    '## In flight' \
    '' \
    '## Queued' \
    '- [ ] omp-p1-activation-a7 - Activate OMP Phase 1 only after corrected-plan PASS (repo: AgentThemis) (kind: ops) (priority: 0) (since 2026-07-27) blocked-by: omp-corrected-plan-redteam-o8' \
    '' \
    '## Done' >"$TMP_ROOT/live/backlog.md"
  jq -n --arg id 'captain-omp-implementation-authorization-2026-07-27' '{schema:"omp-captain-authorization.v1",records:[{id:$id,status:"authorized"}]}' >"$TMP_ROOT/records/authorization.json"
  jq -n '{schema:"omp-decision-inventory.v1",open_keys:[]}' >"$TMP_ROOT/records/decisions.json"
  jq -n '{schema:"omp-stop-ledger.v1",open_stop_ids:[]}' >"$TMP_ROOT/records/stops.json"
  REPORT_HASH=$(shasum -a 256 "$TMP_ROOT/report.md" | awk '{print $1}')
  TRACKED_HASH=$(shasum -a 256 "$TMP_ROOT/tracked-backlog.md" | awk '{print $1}')
  LIVE_HASH=$(shasum -a 256 "$TMP_ROOT/live/backlog.md" | awk '{print $1}')
  BRANCH=$(git -C "$repo" branch --show-current)
  COMMIT=$(git -C "$repo" rev-parse HEAD)
  jq -n --arg report "$REPORT_HASH" --arg tracked "$TRACKED_HASH" --arg live "$LIVE_HASH" --arg branch "$BRANCH" --arg commit "$COMMIT" '{schema:"omp-activation-preflight.v1",report_sha256:$report,tracked_backlog_sha256:$tracked,live_backlog_sha256:$live,repo_branch:$branch,repo_commit:$commit}' >"$TMP_ROOT/records/preflight.json"
}

invoke() {
  local action=$1
  local stage=${2-}
  if [ "$#" -gt 1 ]; then
    shift 2
  else
    shift
  fi
  local command=(
    "$ACTIVATION" "$action" --json \
    --report "$TMP_ROOT/report.md" \
    --manifest "$ROOT/.agents/tasks/omp-manifest.json" \
    --roadmap "$ROOT/.agents/tasks/roadmap.md" \
    --tracked-backlog "$TMP_ROOT/tracked-backlog.md" \
    --live-backlog "$TMP_ROOT/live/backlog.md" \
    --repo-root "$TMP_ROOT/repo" \
    --authorization "$TMP_ROOT/records/authorization.json" \
    --decisions "$TMP_ROOT/records/decisions.json" \
    --stops "$TMP_ROOT/records/stops.json" \
    --preflight "$TMP_ROOT/records/preflight.json" \
    --receipt "$TMP_ROOT/records/receipt.json" "$@"
  )
  if [ -n "$stage" ]; then
    FM_OMP_ACTIVATION_FAIL_STAGE="$stage" "${command[@]}"
  else
    "${command[@]}"
  fi
}

test_default_refuses_current_block() {
  local out status=0
  mkdir -p "$TMP_ROOT"
  printf '# OMP report\n\n## Executive disposition\n\nBLOCK\n' >"$TMP_ROOT/block-report.md"
  out=$($ACTIVATION --check --json --report "$TMP_ROOT/block-report.md") || status=$?
  expect_code 1 "$status" "current BLOCK report should refuse activation"
  assert_contains "$out" 'report disposition is BLOCK' "BLOCK report refusal was not reported"
  pass "omp-activation: current O8 BLOCK remains refused"
}

test_complete_preflight_passes() {
  local out status=0
  setup_fixture
  out=$(invoke --check) || status=$?
  expect_code 0 "$status" "complete activation preflight should pass check mode"
  assert_contains "$out" '"status": "PASS"' "complete activation preflight did not pass"
  pass "omp-activation: complete preflight passes without publication"
}

test_check_requires_preflight() {
  local out status=0
  setup_fixture
  rm -f "$TMP_ROOT/records/preflight.json"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "check mode without preflight should refuse"
  assert_contains "$out" 'missing required input' "check-mode missing preflight refusal was not reported"
  pass "omp-activation: check mode requires preflight"
}

test_empty_and_mismatched_preflight_bindings_refuse() {
  local field out status=0
  for field in report_sha256 tracked_backlog_sha256 live_backlog_sha256 repo_branch repo_commit; do
    setup_fixture
    jq --arg field "$field" '.[$field] = ""' "$TMP_ROOT/records/preflight.json" >"$TMP_ROOT/records/preflight.tmp"
    mv "$TMP_ROOT/records/preflight.tmp" "$TMP_ROOT/records/preflight.json"
    out=$(invoke --check) || status=$?
    expect_code 1 "$status" "empty preflight field $field should refuse"
    assert_contains "$out" "preflight field $field is empty" "empty preflight field $field was not reported"
  done
  for field in tracked_backlog_sha256 live_backlog_sha256 repo_branch repo_commit; do
    setup_fixture
    case "$field" in
      tracked_backlog_sha256|live_backlog_sha256) jq --arg field "$field" '.[$field] = "0000000000000000000000000000000000000000000000000000000000000000"' "$TMP_ROOT/records/preflight.json" >"$TMP_ROOT/records/preflight.tmp" ;;
      repo_branch) jq '.repo_branch = "not-the-current-branch"' "$TMP_ROOT/records/preflight.json" >"$TMP_ROOT/records/preflight.tmp" ;;
      repo_commit) jq '.repo_commit = "0000000000000000000000000000000000000000"' "$TMP_ROOT/records/preflight.json" >"$TMP_ROOT/records/preflight.tmp" ;;
    esac
    mv "$TMP_ROOT/records/preflight.tmp" "$TMP_ROOT/records/preflight.json"
    out=$(invoke --check) || status=$?
    expect_code 1 "$status" "mismatched preflight field $field should refuse"
    case "$field" in
      tracked_backlog_sha256) assert_contains "$out" 'tracked backlog bytes do not match' "tracked preimage mismatch was not reported" ;;
      live_backlog_sha256) assert_contains "$out" 'live backlog bytes do not match' "live preimage mismatch was not reported" ;;
      repo_branch) assert_contains "$out" 'Git branch does not match' "branch mismatch was not reported" ;;
      repo_commit) assert_contains "$out" 'Git commit does not match' "commit mismatch was not reported" ;;
    esac
  done
  pass "omp-activation: empty and mismatched preflight bindings are refused"
}

test_report_hash_refuses() {
  local out status=0
  setup_fixture
  printf '# OMP report\n\n## Executive disposition\n\nBLOCK\n' >"$TMP_ROOT/report.md"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "stale report should refuse activation"
  assert_contains "$out" 'report disposition is BLOCK' "stale report disposition was not reported"
  assert_contains "$out" 'report hash does not match' "stale report hash was not reported"
  pass "omp-activation: stale report and hash are refused"
}

test_dirty_tree_refuses() {
  local out status=0
  setup_fixture
  printf 'dirty\n' >"$TMP_ROOT/repo/untracked.txt"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "dirty repository should refuse activation"
  assert_contains "$out" 'activation repository is not clean' "dirty-tree refusal was not reported"
  pass "omp-activation: dirty repository is refused"
}

test_decision_and_stop_refuse() {
  local out status=0
  setup_fixture
  jq '{schema:.schema,open_keys:["new-choice"]}' "$TMP_ROOT/records/decisions.json" >"$TMP_ROOT/records/decisions.tmp"
  mv "$TMP_ROOT/records/decisions.tmp" "$TMP_ROOT/records/decisions.json"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "open decision should refuse activation"
  assert_contains "$out" 'decision-hold inventory is not clean' "open decision refusal was not reported"
  setup_fixture
  jq '{schema:.schema,open_stop_ids:["STOP-01"]}' "$TMP_ROOT/records/stops.json" >"$TMP_ROOT/records/stops.tmp"
  mv "$TMP_ROOT/records/stops.tmp" "$TMP_ROOT/records/stops.json"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "open STOP should refuse activation"
  assert_contains "$out" 'STOP ledger has an open' "open STOP refusal was not reported"
  pass "omp-activation: decision and STOP holds are refused"
}

test_premature_task_refuses() {
  local out status=0
  setup_fixture
  printf '%s\n' '- [ ] omp-p2-experimental-launch - premature' >>"$TMP_ROOT/live/backlog.md"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "premature implementation task should refuse activation"
  assert_contains "$out" 'premature P1-P8 task is present' "premature task refusal was not reported"
  pass "omp-activation: premature implementation row is refused"
}

test_activation_p1_rows_refuse() {
  local activation_id out status=0
  for activation_id in omp-p1-runtime-pin omp-p1-discovery-isolation omp-p1-identity-ancestry; do
    setup_fixture
    printf '%s\n' "- [ ] $activation_id - pre-existing activation row" >>"$TMP_ROOT/live/backlog.md"
    out=$(invoke --check) || status=$?
    expect_code 1 "$status" "pre-existing activation row $activation_id should refuse"
    assert_contains "$out" "activation-published P1 row already exists" "pre-existing activation row $activation_id was not reported"
  done
  pass "omp-activation: every activation-published P1 row is absent before publication"
}

test_activate_requires_preflight() {
  local out status=0
  setup_fixture
  rm -f "$TMP_ROOT/records/preflight.json"
  out=$(invoke --activate) || status=$?
  expect_code 1 "$status" "activation without preflight should refuse"
  assert_contains "$out" 'missing required input' "missing preflight refusal was not reported"
  pass "omp-activation: publication requires a complete preflight"
}

test_fault_injection_restores_backlog() {
  local stage out status=0 before after
  for stage in receipt-dir receipt-temp receipt-write backlog-move receipt-move; do
    setup_fixture
    before=$(shasum -a 256 "$TMP_ROOT/live/backlog.md" | awk '{print $1}')
    out=$(invoke --activate "$stage") || status=$?
    expect_code 1 "$status" "fault injection $stage should refuse activation"
    if [ "$stage" = receipt-dir ]; then
      assert_contains "$out" 'fault injection refused at receipt-directory stage' "fault injection $stage was not reported"
    else
      assert_contains "$out" "fault injection refused at $stage stage" "fault injection $stage was not reported"
    fi
    after=$(shasum -a 256 "$TMP_ROOT/live/backlog.md" | awk '{print $1}')
    [ "$before" = "$after" ] || fail "fault injection $stage changed the live backlog preimage"
    [ ! -e "$TMP_ROOT/records/receipt.json" ] || fail "fault injection $stage left a success receipt"
  done
  pass "omp-activation: receipt and move failures restore the exact backlog preimage"
}

test_activate_publishes_atomically() {
  local out status=0 listed ready a7
  setup_fixture
  out=$(invoke --activate) || status=$?
  expect_code 0 "$status" "complete activation should publish atomically"
  assert_contains "$out" '"status": "PASS"' "atomic activation did not pass"
  listed=$($TASKS_AXI list --file "$TMP_ROOT/live/backlog.md")
  assert_contains "$listed" 'omp-p1-runtime-pin' "runtime P1 row was not published"
  assert_contains "$listed" 'omp-p1-discovery-isolation' "discovery P1 row was not published"
  assert_contains "$listed" 'omp-p1-identity-ancestry' "identity P1 row was not published"
  ready=$($TASKS_AXI ready --file "$TMP_ROOT/live/backlog.md")
  assert_contains "$ready" 'omp-p1-runtime-pin' "runtime P1 row was not ready after activation"
  assert_contains "$ready" 'omp-p1-discovery-isolation' "discovery P1 row was not ready after activation"
  assert_contains "$ready" 'omp-p1-identity-ancestry' "identity P1 row was not ready after activation"
  a7=$($TASKS_AXI list --file "$TMP_ROOT/live/backlog.md")
  assert_contains "$a7" 'omp-p1-activation-a7,done,' "activation record was not completed in the postimage"
  assert_contains "$(jq -c . "$TMP_ROOT/records/receipt.json")" 'omp-activation-receipt.v1' "activation receipt was not published"
  assert_contains "$(jq -c . "$TMP_ROOT/records/receipt.json")" 'activation_completed' "activation completion was not recorded"
  pass "omp-activation: P1 rows and activation completion publish atomically"
}

test_default_refuses_current_block
test_complete_preflight_passes
test_check_requires_preflight
test_empty_and_mismatched_preflight_bindings_refuse
test_report_hash_refuses
test_dirty_tree_refuses
test_decision_and_stop_refuse
test_premature_task_refuses
test_activation_p1_rows_refuse
test_activate_requires_preflight
test_fault_injection_restores_backlog
test_activate_publishes_atomically
