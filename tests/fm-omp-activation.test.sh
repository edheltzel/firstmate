#!/usr/bin/env bash
# Behavior tests for the fail-closed OMP activation gate and atomic P1 publication.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACTIVATION="$ROOT/bin/fm-omp-activation.sh"
ACTIVATION_MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
TASKS_AXI=${TASKS_AXI:-$(command -v tasks-axi 2>/dev/null || true)}
TMP_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/fm-omp-activation-test.XXXXXX")
TEST_SHA256_TOOL=${TEST_SHA256_TOOL:-$(command -v shasum 2>/dev/null || command -v sha256sum 2>/dev/null || true)}

test_sha256() {
  case "$TEST_SHA256_TOOL" in
    */shasum|shasum) "$TEST_SHA256_TOOL" -a 256 "$1" | awk '{print $1}' ;;
    */sha256sum|sha256sum) "$TEST_SHA256_TOOL" "$1" | awk '{print $1}' ;;
    *) fail "test SHA-256 tool is unavailable or unsupported: $TEST_SHA256_TOOL" ;;
  esac
}

cleanup() {
  rm -rf "$TMP_ROOT"
}
trap cleanup EXIT

setup_fixture() {
  local blocker_state=${1:-resolved}
  local repo="$TMP_ROOT/repo"
  rm -rf "$TMP_ROOT"
  mkdir -p "$TMP_ROOT/live" "$TMP_ROOT/records" "$TMP_ROOT/repo" "$TMP_ROOT/state" "$TMP_ROOT/data/omp-final-authority-redteam-o10" "$TMP_ROOT/data/omp-corrected-plan-redteam-o8" "$TMP_ROOT/data/omp-final-corrected-plan-redteam-o9"
  fm_git_init_commit "$repo"
  printf '# OMP report\n\n## Executive disposition\n\nPASS\n\n## Plan-blocking findings\n\nNone.\n' >"$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md"
  printf '# Historical O8 report\n\n## Executive disposition\n\nBLOCK\n' >"$TMP_ROOT/data/omp-corrected-plan-redteam-o8/report.md"
  cp "$ROOT/.agents/tasks/backlog.md" "$TMP_ROOT/tracked-backlog.md"
  if [ "$blocker_state" = resolved ]; then
    printf '%s\n' \
      '# Backlog' '' '## In flight' '' '## Queued' \
      '- [ ] omp-p1-activation-a7 - Activate OMP Phase 1 only after final authority PASS (repo: AgentThemis) (kind: ops) (priority: 0) (since 2026-07-27) blocked-by: omp-final-authority-redteam-o10' \
      '  Captain implementation authorization is recorded on 2026-07-27.' \
      '  The activation gate preserves its refusal contract.' \
      '  Evidence: omp-evidence-omp-p1-activation-a7; rollback: omp-rollback-omp-p1-activation-a7.' '' \
      '## Done' \
      '- [x] omp-final-authority-redteam-o10 - Final authority Red Team PASS (repo: AgentThemis) (kind: scout) (priority: 0) (since 2026-07-27)' >"$TMP_ROOT/live/backlog.md"
  else
    printf '%s\n' \
      '# Backlog' '' '## In flight' '' '## Queued' \
      '- [ ] omp-final-corrected-plan-redteam-o9 - Historical O9 BLOCK (repo: AgentThemis) (kind: scout) (priority: 0) (since 2026-07-27)' \
      '- [ ] omp-final-authority-redteam-o10 - Final authority Red Team PASS (repo: AgentThemis) (kind: scout) (priority: 0) (since 2026-07-27) blocked-by: omp-final-corrected-plan-redteam-o9' \
      '- [ ] omp-p1-activation-a7 - Activate OMP Phase 1 only after final authority PASS (repo: AgentThemis) (kind: ops) (priority: 0) (since 2026-07-27) blocked-by: omp-final-authority-redteam-o10' \
      '  Captain implementation authorization is recorded on 2026-07-27.' \
      '  The activation gate preserves its refusal contract.' \
      '  Evidence: omp-evidence-omp-p1-activation-a7; rollback: omp-rollback-omp-p1-activation-a7.' '' '## Done' >"$TMP_ROOT/live/backlog.md"
  fi
  jq -n --arg id 'captain-omp-implementation-authorization-2026-07-27' '{schema:"omp-captain-authorization.v1",records:[{id:$id,status:"authorized"}]}' >"$TMP_ROOT/records/authorization.json"
  jq -n '{schema:"omp-decision-inventory.v1",open_keys:[]}' >"$TMP_ROOT/records/decisions.json"
  jq -n '{schema:"omp-stop-ledger.v1",open_stop_ids:[]}' >"$TMP_ROOT/records/stops.json"
  REPORT_HASH=$(test_sha256 "$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md")
  TRACKED_HASH=$(test_sha256 "$TMP_ROOT/tracked-backlog.md")
  LIVE_HASH=$(test_sha256 "$TMP_ROOT/live/backlog.md")
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
    --test-only \
    --report "$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md" \
    --manifest "$ACTIVATION_MANIFEST" \
    --roadmap "$ROOT/.agents/tasks/roadmap.md" \
    --tracked-backlog "$TMP_ROOT/tracked-backlog.md" \
    --live-backlog "$TMP_ROOT/live/backlog.md" \
    --repo-root "$TMP_ROOT/repo" \
    --authorization "$TMP_ROOT/records/authorization.json" \
    --decisions "$TMP_ROOT/records/decisions.json" \
    --stops "$TMP_ROOT/records/stops.json" \
    --preflight "$TMP_ROOT/records/preflight.json" "$@"
  )
  if [ -n "$stage" ]; then
    FM_HOME="$TMP_ROOT" FM_OMP_TEST_MODE=1 FM_OMP_ACTIVATION_FAIL_STAGE="$stage" "${command[@]}"
  else
    FM_HOME="$TMP_ROOT" FM_OMP_TEST_MODE=1 "${command[@]}"
  fi
}

wait_for_pause() {
  local path=$1 attempts=0
  while [ ! -e "$path" ] && [ "$attempts" -lt 200 ]; do
    attempts=$((attempts + 1))
    sleep 0.05
  done
  [ -e "$path" ] && return 0
  fail "activation subprocess did not reach its pause point: $path"
}

start_paused_activation() {
  local stage=$1 ready=$2 resume=$3 log=$4
  local command=(
    "$ACTIVATION" --activate --json --test-only
    --report "$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md"
    --manifest "$ACTIVATION_MANIFEST"
    --roadmap "$ROOT/.agents/tasks/roadmap.md"
    --tracked-backlog "$TMP_ROOT/tracked-backlog.md"
    --live-backlog "$TMP_ROOT/live/backlog.md"
    --repo-root "$TMP_ROOT/repo"
    --authorization "$TMP_ROOT/records/authorization.json"
    --decisions "$TMP_ROOT/records/decisions.json"
    --stops "$TMP_ROOT/records/stops.json"
    --preflight "$TMP_ROOT/records/preflight.json"
  )
  FM_OMP_ACTIVATION_PAUSE_STAGE="$stage" \
    FM_OMP_ACTIVATION_PAUSE_READY_FILE="$ready" \
    FM_OMP_ACTIVATION_PAUSE_RESUME_FILE="$resume" \
    FM_HOME="$TMP_ROOT" FM_OMP_TEST_MODE=1 "${command[@]}" >"$log" 2>&1 &
  PAUSED_PID=$!
}

read_receipt() {
  sed -n 's/^  Activation receipt: //p' "$TMP_ROOT/live/backlog.md"
}

test_default_refuses_current_block() {
  local out status=0
  mkdir -p "$TMP_ROOT"
  printf '# OMP report\n\n## Executive disposition\n\nBLOCK\n' >"$TMP_ROOT/block-report.md"
  out=$(FM_OMP_TEST_MODE=1 $ACTIVATION --check --json --test-only --report "$TMP_ROOT/block-report.md") || status=$?
  expect_code 1 "$status" "current BLOCK report should refuse activation"
  assert_contains "$out" 'report disposition is BLOCK' "BLOCK report refusal was not reported"
  pass "omp-activation: historical BLOCK remains refused"
}

test_complete_preflight_passes() {
  local out status=0
  setup_fixture
  out=$(invoke --check) || status=$?
  expect_code 0 "$status" "complete activation preflight should pass check mode"
  assert_contains "$out" '"status": "PASS"' "complete activation preflight did not pass"
  pass "omp-activation: complete preflight passes without publication"
}

test_sha256sum_branch_passes() {
  local fakebin="$TMP_ROOT/fakebin" out status=0 mode
  setup_fixture
  mkdir -p "$fakebin"
  case "$TEST_SHA256_TOOL" in
    */shasum|shasum) mode=shasum ;;
    */sha256sum|sha256sum) mode=sha256sum ;;
    *) fail "cannot select hash wrapper mode: $TEST_SHA256_TOOL" ;;
  esac
  cat >"$fakebin/sha256sum" <<'SH'
#!/usr/bin/env bash
if [ "${REAL_HASH_MODE-}" = shasum ]; then
  exec "$REAL_HASH_IMPL" -a 256 "$@"
fi
exec "$REAL_HASH_IMPL" "$@"
SH
  chmod +x "$fakebin/sha256sum"
  out=$(SHA256_TOOL="$fakebin/sha256sum" REAL_HASH_IMPL="$TEST_SHA256_TOOL" REAL_HASH_MODE="$mode" invoke --check) || status=$?
  expect_code 0 "$status" "sha256sum production branch should pass check mode"
  assert_contains "$out" '"status": "PASS"' "sha256sum production branch did not pass"
  pass "omp-activation: sha256sum branch is covered"
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
  printf '# OMP report\n\n## Executive disposition\n\nBLOCK\n' >"$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "stale report should refuse activation"
  assert_contains "$out" 'report disposition is BLOCK' "stale report disposition was not reported"
  assert_contains "$out" 'report hash does not match' "stale report hash was not reported"
  pass "omp-activation: stale report and hash are refused"
}

test_plan_blocking_finding_refuses() {
  local out status=0
  setup_fixture
  printf '# OMP report\n\n## Executive disposition\n\nPASS\n\n## Plan-blocking findings\n\n- S1 transaction defect\n' >"$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "a plan-blocking finding should refuse activation"
  assert_contains "$out" 'report must declare no plan-blocking findings' "plan-blocking finding was not refused"
  pass "omp-activation: plan-blocking report findings are refused"
}

test_report_shape_is_strict() {
  local out status=0
  setup_fixture
  printf '# OMP report\n\n## Executive disposition\n\nThe report says PASS in prose.\n\n## Plan-blocking findings\n\nNone.\n' >"$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md"
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "prose PASS without a standalone disposition should refuse"
  assert_contains "$out" 'report has no exact Executive disposition' "prose-only PASS was accepted"
  setup_fixture
  printf '# OMP report\n\n## Executive disposition\n\nPASS\n\n## Plan-blocking findings\n\nNone.\n\n- stale text\n' >"$TMP_ROOT/data/omp-final-authority-redteam-o10/report.md"
  status=0
  out=$(invoke --check) || status=$?
  expect_code 1 "$status" "text after None. should refuse"
  assert_contains "$out" 'report must declare no plan-blocking findings' "trailing blocker text was accepted"
  pass "omp-activation: report disposition and blocker sections are exact"
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

test_fault_injection_preserves_or_publishes_backlog() {
  local stage out status before after
  for stage in template receipt-template postimage-validate pre-publication; do
    setup_fixture
    before=$(test_sha256 "$TMP_ROOT/live/backlog.md")
    status=0
    out=$(invoke --activate "$stage") || status=$?
    expect_code 1 "$status" "fault injection $stage should refuse activation"
    assert_contains "$out" "fault injection refused at $stage stage" "fault injection $stage was not reported"
    after=$(test_sha256 "$TMP_ROOT/live/backlog.md")
    [ "$before" = "$after" ] || fail "fault injection $stage changed the live backlog preimage"
    [ -z "$(read_receipt)" ] || fail "fault injection $stage left an authoritative receipt"
  done
  setup_fixture
  before=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  status=0
  out=$(invoke --activate post-publication) || status=$?
  expect_code 1 "$status" "post-publication interruption should report a blocked return"
  assert_contains "$out" 'fault injection refused immediately after the backlog rename' "post-publication interruption was not reported"
  after=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  [ "$before" != "$after" ] || fail "post-publication interruption did not leave the authoritative postimage"
  assert_contains "$(read_receipt)" 'omp-activation-receipt.v1' "post-publication interruption lost the receipt"
  pass "omp-activation: pre-rename failures preserve the preimage and post-rename failure preserves the postimage"
}

test_activate_publishes_atomically() {
  local out status=0 listed ready a7 receipt
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
  receipt=$(read_receipt)
  assert_contains "$receipt" 'omp-activation-receipt.v1' "activation receipt was not embedded"
  assert_contains "$receipt" 'activation_completed' "activation completion was not recorded"
  jq -e '.postimage_sha256 | test("^[0-9a-f]{64}$")' <<<"$receipt" >/dev/null || fail "embedded receipt lacks a postimage hash"
  [ ! -e "$TMP_ROOT/records/receipt.json" ] || fail "separate receipt authority was published"
  pass "omp-activation: P1 rows and activation completion publish atomically"
}

test_full_activation_record_survives() {
  local out status=0 backlog
  setup_fixture
  out=$(invoke --activate) || status=$?
  expect_code 0 "$status" "activation with a multiline record should pass"
  backlog=$(cat "$TMP_ROOT/live/backlog.md")
  assert_contains "$backlog" '  Captain implementation authorization is recorded on 2026-07-27.' "activation body line was lost"
  assert_contains "$backlog" '  The activation gate preserves its refusal contract.' "second activation body line was lost"
  assert_contains "$backlog" '  Evidence: omp-evidence-omp-p1-activation-a7; rollback: omp-rollback-omp-p1-activation-a7.' "activation evidence body line was lost"
  pass "omp-activation: full multiline activation record survives publication"
}

test_activation_blocker_readiness_refuses() {
  local out status=0 before after
  setup_fixture unresolved
  before=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  out=$(invoke --activate) || status=$?
  expect_code 1 "$status" "unresolved activation blocker should refuse publication"
  assert_contains "$out" 'activation record omp-p1-activation-a7 is not ready in the live backlog preimage' "unresolved activation blocker was not reported"
  after=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  [ "$before" = "$after" ] || fail "unresolved activation blocker changed the live backlog"
  [ -z "$(read_receipt)" ] || fail "unresolved activation blocker left a receipt"
  pass "omp-activation: unresolved A7 blocker is fail-safe"
}

test_activation_date_override() {
  local out status=0 backlog
  setup_fixture
  out=$(FM_OMP_ACTIVATION_DATE=2030-04-05 invoke --activate) || status=$?
  expect_code 0 "$status" "activation date override should pass"
  backlog=$(cat "$TMP_ROOT/live/backlog.md")
  assert_contains "$backlog" '(done 2030-04-05)' "activation completion date was not derived from override"
  assert_contains "$backlog" '(since 2030-04-05)' "published task date was not derived from override"
  pass "omp-activation: activation date is derived and validated"
}

test_activation_tmpdir_failure_refuses() {
  local out status=0 before after repo_before repo_after
  setup_fixture
  before=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  repo_before=$(git -C "$TMP_ROOT/repo" status --porcelain --untracked-files=all)
  out=$(TMPDIR="$TMP_ROOT/missing-activation-tmp" invoke --activate) || status=$?
  expect_code 1 "$status" "activation temporary-root failure should refuse"
  assert_contains "$out" 'could not allocate activation temporary workspace' "activation temporary-root failure was not reported"
  after=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  [ "$before" = "$after" ] || fail "activation temporary-root failure changed the live backlog"
  repo_after=$(git -C "$TMP_ROOT/repo" status --porcelain --untracked-files=all)
  [ "$repo_before" = "$repo_after" ] || fail "activation temporary-root failure changed the project worktree"
  [ -z "$(read_receipt)" ] || fail "activation temporary-root failure left a receipt"
  pass "omp-activation: temporary-root failure is fail-safe"
}

test_activation_lock_refuses_concurrent_and_recovers_stale() {
  local out status=0
  setup_fixture
  mkdir -p "$TMP_ROOT/state/.omp-activation.lock"
  printf 'pid=%s\nbranch=other\ncommit=other\n' "$$" >"$TMP_ROOT/state/.omp-activation.lock/owner"
  out=$(invoke --activate) || status=$?
  expect_code 1 "$status" "live activation lock should refuse"
  assert_contains "$out" 'activation lock is already held' "live activation lock refusal was not reported"
  setup_fixture
  mkdir -p "$TMP_ROOT/state/.omp-activation.lock"
  printf 'pid=999999999\nbranch=dead\ncommit=dead\n' >"$TMP_ROOT/state/.omp-activation.lock/owner"
  status=0
  out=$(invoke --activate) || status=$?
  expect_code 0 "$status" "dead activation lock should be quarantined"
  assert_contains "$out" '"status": "PASS"' "stale activation lock was not recovered"
  pass "omp-activation: concurrent lock refusal and stale-lock recovery are covered"
}

test_real_subprocess_concurrency_refuses() {
  local ready="$TMP_ROOT/concurrent.ready" resume="$TMP_ROOT/concurrent.resume" log="$TMP_ROOT/concurrent.log" pid out status=0
  setup_fixture
  start_paused_activation before-rename "$ready" "$resume" "$log"
  pid=$PAUSED_PID
  wait_for_pause "$ready"
  out=$(invoke --activate) || status=$?
  expect_code 1 "$status" "concurrent activation subprocess should refuse"
  assert_contains "$out" 'activation lock is already held' "concurrent subprocess refusal was not reported"
  : >"$resume"
  wait "$pid" || fail "the original activation did not finish after releasing its pause"
  pass "omp-activation: real concurrent subprocesses share one exclusive lock"
}

test_kill_before_rename_preserves_preimage_and_restart_recovers() {
  local ready="$TMP_ROOT/before.ready" resume="$TMP_ROOT/before.resume" log="$TMP_ROOT/before.log" pid before after out status=0
  setup_fixture
  before=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  start_paused_activation before-rename "$ready" "$resume" "$log"
  pid=$PAUSED_PID
  wait_for_pause "$ready"
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  after=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  [ "$before" = "$after" ] || fail "kill-before-rename changed the authoritative preimage"
  [ -z "$(read_receipt)" ] || fail "kill-before-rename left an authoritative receipt"
  out=$(invoke --activate) || status=$?
  expect_code 0 "$status" "restart after kill-before-rename should recover"
  assert_contains "$out" '"status": "PASS"' "restart after kill-before-rename did not publish"
  pass "omp-activation: kill-before-rename preserves the preimage and restart quarantines the stale lock"
}

test_kill_after_rename_preserves_postimage_and_restart_recognizes_receipt() {
  local ready="$TMP_ROOT/after.ready" resume="$TMP_ROOT/after.resume" log="$TMP_ROOT/after.log" pid before after out status=0
  setup_fixture
  before=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  start_paused_activation after-rename "$ready" "$resume" "$log"
  pid=$PAUSED_PID
  wait_for_pause "$ready"
  after=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  [ "$before" != "$after" ] || fail "kill-after-rename did not expose the postimage before process death"
  assert_contains "$(read_receipt)" 'omp-activation-receipt.v1' "postimage was missing its embedded receipt"
  kill -KILL "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  out=$(invoke --check) || status=$?
  expect_code 0 "$status" "restart after kill-after-rename should recognize the postimage"
  assert_contains "$out" '"already_activated": true' "restart after kill-after-rename did not recognize the receipt"
  pass "omp-activation: kill-after-rename preserves and recognizes the durable receipt-bearing postimage"
}

test_manifest_drives_publication_set() {
  local manifest="$TMP_ROOT/manifest.json" out status=0 backlog
  setup_fixture
  jq '.activation_task_ids = ["omp-p1-runtime-pin"]' "$ROOT/.agents/tasks/omp-manifest.json" >"$manifest"
  ACTIVATION_MANIFEST="$manifest"
  out=$(invoke --activate) || status=$?
  ACTIVATION_MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
  expect_code 0 "$status" "manifest-selected activation set should publish"
  backlog=$(cat "$TMP_ROOT/live/backlog.md")
  assert_contains "$backlog" 'omp-p1-runtime-pin' "manifest-selected task was not published"
  assert_not_contains "$backlog" 'omp-p1-discovery-isolation' "non-manifest task was published"
  assert_not_contains "$backlog" 'omp-p1-identity-ancestry' "non-manifest task was published"
  jq -e '.task_ids == ["omp-p1-runtime-pin"]' <<<"$(read_receipt)" >/dev/null || fail "embedded receipt task IDs did not match manifest activation set"
  pass "omp-activation: manifest drives task rows and receipt parity"
}

test_activation_dependency_closure_refuses() {
  local manifest="$TMP_ROOT/manifest.json" out status=0
  setup_fixture
  jq '.tasks[6].depends_on = ["omp-p1-identity-ancestry"]' "$ROOT/.agents/tasks/omp-manifest.json" >"$manifest"
  ACTIVATION_MANIFEST="$manifest"
  out=$(invoke --check) || status=$?
  ACTIVATION_MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
  expect_code 1 "$status" "manifest dependency drift should refuse activation"
  assert_contains "$out" 'machine-readable OMP plan check did not pass' "manifest dependency drift was not reported"
  pass "omp-activation: activation task dependency closure is exact"
}

test_historical_o8_cannot_authorize() {
  local out status=0
  setup_fixture
  out=$(invoke --check "" --report "$TMP_ROOT/data/omp-corrected-plan-redteam-o8/report.md") || status=$?
  expect_code 1 "$status" "historical O8 BLOCK report should not authorize activation"
  assert_contains "$out" 'report disposition is BLOCK' "historical O8 BLOCK was not refused"
  assert_contains "$out" 'activation report path does not match the O10 manifest path' "historical O8 report path was accepted"
  pass "omp-activation: historical O8 BLOCK cannot authorize"
}

test_historical_o9_pass_cannot_authorize() {
  local out status=0
  setup_fixture
  printf '# Historical O9 report\n\n## Executive disposition\n\nPASS\n\n## Plan-blocking findings\n\nNone.\n' >"$TMP_ROOT/data/omp-final-corrected-plan-redteam-o9/report.md"
  out=$(invoke --check "" --report "$TMP_ROOT/data/omp-final-corrected-plan-redteam-o9/report.md") || status=$?
  expect_code 1 "$status" "historical O9 PASS report should not authorize activation"
  assert_contains "$out" 'activation report path does not match the O10 manifest path' "historical O9 PASS was accepted"
  pass "omp-activation: historical O9 PASS cannot authorize"
}

test_o9_is_sole_pass_gate() {
  local manifest="$TMP_ROOT/manifest.json" out status=0
  setup_fixture
  jq '.activation_report_task_id = "omp-corrected-plan-redteam-o8" | .activation_report_path = "data/omp-corrected-plan-redteam-o8/report.md"' "$ROOT/.agents/tasks/omp-manifest.json" >"$manifest"
  ACTIVATION_MANIFEST="$manifest"
  out=$(invoke --check) || status=$?
  ACTIVATION_MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
  expect_code 1 "$status" "manifest/report identity drift should refuse activation"
  assert_contains "$out" 'activation report task must be omp-final-authority-redteam-o10' "O10 report task drift was not refused"
  pass "omp-activation: O10 is the sole report identity gate"
}

test_repeat_check_and_activate_are_single_unit_safe() {
  local out status=0 before after
  setup_fixture
  out=$(invoke --activate) || status=$?
  expect_code 0 "$status" "initial activation should publish"
  before=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  out=$(invoke --check) || status=$?
  expect_code 0 "$status" "repeat check should recognize the authoritative postimage"
  assert_contains "$out" '"already_activated": true' "repeat check did not report the authoritative activation"
  out=$(invoke --activate) || status=$?
  expect_code 1 "$status" "repeat activation should refuse duplicate publication"
  assert_contains "$out" 'authoritative activation record is already complete' "repeat activation refusal was not reported"
  after=$(test_sha256 "$TMP_ROOT/live/backlog.md")
  [ "$before" = "$after" ] || fail "repeat activation changed the authoritative backlog"
  pass "omp-activation: repeated check/activate remains one-unit and duplicate-safe"
}

test_default_refuses_current_block
test_complete_preflight_passes
test_sha256sum_branch_passes
test_check_requires_preflight
test_empty_and_mismatched_preflight_bindings_refuse
test_report_hash_refuses
test_plan_blocking_finding_refuses
test_report_shape_is_strict
test_dirty_tree_refuses
test_decision_and_stop_refuse
test_premature_task_refuses
test_activation_p1_rows_refuse
test_activate_requires_preflight
test_fault_injection_preserves_or_publishes_backlog
test_activate_publishes_atomically
test_full_activation_record_survives
test_activation_blocker_readiness_refuses
test_activation_date_override
test_activation_tmpdir_failure_refuses
test_activation_lock_refuses_concurrent_and_recovers_stale
test_real_subprocess_concurrency_refuses
test_kill_before_rename_preserves_preimage_and_restart_recovers
test_kill_after_rename_preserves_postimage_and_restart_recognizes_receipt
test_manifest_drives_publication_set
test_activation_dependency_closure_refuses
test_historical_o8_cannot_authorize
test_historical_o9_pass_cannot_authorize
test_o9_is_sole_pass_gate
test_repeat_check_and_activate_are_single_unit_safe
