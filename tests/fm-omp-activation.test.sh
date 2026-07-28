#!/usr/bin/env bash
# Behavior tests for the fail-closed OMP activation gate and atomic P1 publication.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACTIVATION="$ROOT/bin/fm-omp-activation.sh"
TASKS_AXI=${TASKS_AXI:-/opt/homebrew/bin/tasks-axi}
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
  printf '# Backlog\n\n## In flight\n\n## Queued\n\n## Done\n' >"$TMP_ROOT/live/backlog.md"
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
  shift
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

test_activate_requires_preflight() {
  local out status=0
  setup_fixture
  rm -f "$TMP_ROOT/records/preflight.json"
  out=$(invoke --activate) || status=$?
  expect_code 1 "$status" "activation without preflight should refuse"
  assert_contains "$out" 'missing required input' "missing preflight refusal was not reported"
  assert_contains "$out" 'requires a complete preflight' "activation preflight gate was not reported"
  pass "omp-activation: publication requires a complete preflight"
}

test_activate_publishes_atomically() {
  local out status=0 listed
  setup_fixture
  out=$(invoke --activate) || status=$?
  expect_code 0 "$status" "complete activation should publish atomically"
  assert_contains "$out" '"status": "PASS"' "atomic activation did not pass"
  listed=$($TASKS_AXI list --file "$TMP_ROOT/live/backlog.md")
  assert_contains "$listed" 'omp-p1-runtime-pin' "runtime P1 row was not published"
  assert_contains "$listed" 'omp-p1-discovery-isolation' "discovery P1 row was not published"
  assert_contains "$listed" 'omp-p1-identity-ancestry' "identity P1 row was not published"
  assert_contains "$(jq -c . "$TMP_ROOT/records/receipt.json")" 'omp-activation-receipt.v1' "activation receipt was not published"
  pass "omp-activation: P1 rows publish through the atomic transaction"
}

test_default_refuses_current_block
test_complete_preflight_passes
test_report_hash_refuses
test_dirty_tree_refuses
test_decision_and_stop_refuse
test_premature_task_refuses
test_activate_requires_preflight
test_activate_publishes_atomically
