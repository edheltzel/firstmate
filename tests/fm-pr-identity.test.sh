#!/usr/bin/env bash
# Synthetic tests for the host-owned Atlas PR broker.
set -u

# shellcheck source=tests/lib.sh disable=SC1091
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

BROKER="$ROOT/bin/fm-pr-identity.sh"
CASE_ROOT=$(fm_test_tmproot fm-pr-identity)
HOME_DIR="$CASE_ROOT/home"
PROJECT="$CASE_ROOT/project"
FAKEBIN="$CASE_ROOT/fakebin"
ENV_FILE="$CASE_ROOT/synthetic.env"
mkdir -p "$HOME_DIR/data" "$HOME_DIR/state" "$FAKEBIN" "$PROJECT"

cat > "$HOME_DIR/data/projects.md" <<'EOF'
- Atlas [direct-PR pr-identity=atlas-pat] - synthetic broker project (added 2026-07-22)
- Local [local-only pr-identity=atlas-pat] - rejected combination (added 2026-07-22)
EOF
cat > "$ENV_FILE" <<'EOF'
ATLAS_KEY_PAT=synthetic-token
EOF
cat > "$FAKEBIN/gh-axi" <<'SH'
#!/usr/bin/env bash
 [ "${GH_TOKEN:-}" = synthetic-token ] || exit 1
case "$*" in
  "api /user") printf 'login: Atlas-Key\n' ;;
  *collaborators/Atlas-Key/permission*) printf 'permission: write\n' ;;
  *required_signatures*) printf 'enabled: false\n' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$FAKEBIN/gh-axi"

git -C "$PROJECT" init -q
printf 'fixture\n' > "$PROJECT/README.md"
git -C "$PROJECT" -c user.name='Atlas' -c user.email='atlas@rainyday.media' add README.md
git -C "$PROJECT" -c user.name='Atlas' -c user.email='atlas@rainyday.media' commit -qm initial
git -C "$PROJECT" branch -M main
git -C "$PROJECT" remote add origin git@github.com:edheltzel/fixture.git

run_broker() {
  FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$HOME_DIR" FM_DATA_OVERRIDE="$HOME_DIR/data" \
    FM_STATE_OVERRIDE="$HOME_DIR/state" FM_ATLAS_ENV_FILE="$ENV_FILE" \
    FM_PR_IDENTITY_TEST_MODE=1 FM_PR_IDENTITY_GH_AXI="$FAKEBIN/gh-axi" PATH="$FAKEBIN:$PATH" "$BROKER" "$@"
}

out=$(run_broker preflight task-a Atlas "$PROJECT") || fail "synthetic preflight unexpectedly failed"
assert_contains "$out" 'profile=atlas-pat' "preflight should return the non-secret profile"
assert_contains "$out" 'repo=edheltzel/fixture' "preflight should bind the exact origin repository"
assert_contains "$out" 'branch=fm/task-a' "preflight should bind the exact task branch"
assert_not_contains "$out" 'synthetic-token' "preflight must never return the credential"
pass "broker preflight resolves one synthetic credential and returns only safe binding metadata"

printf 'ATLAS_KEY_PAT=synthetic-token\nATLAS_KEY_PAT=second-synthetic-token\n' > "$ENV_FILE"
set +e
duplicate=$(run_broker preflight task-a Atlas "$PROJECT" 2>&1)
duplicate_rc=$?
set -e
[ "$duplicate_rc" -ne 0 ] || fail "duplicate credential definitions must fail"
assert_contains "$duplicate" 'credential-duplicate' "duplicate credentials should use the credential-duplicate category"
assert_not_contains "$duplicate" 'synthetic-token' "duplicate credential diagnostics must not expose values"
pass "broker rejects duplicate credential definitions without exposing either value"

printf 'ATLAS_KEY_PAT=synthetic-token\n' > "$ENV_FILE"
set +e
local_out=$(run_broker preflight task-a Local "$PROJECT" 2>&1)
local_rc=$?
set -e
[ "$local_rc" -ne 0 ] || fail "local-only identity combination must fail"
assert_contains "$local_out" 'invalid or local-only' "local-only profile must be refused before credentials are loaded"
pass "broker preserves the local-only exclusion"

: > "$ENV_FILE"
set +e
missing=$(run_broker preflight task-a Atlas "$PROJECT" 2>&1)
missing_rc=$?
set -e
[ "$missing_rc" -ne 0 ] || fail "missing credential definitions must fail"
assert_contains "$missing" 'credential-missing' "missing credentials should use the credential-missing category"
pass "broker rejects a missing credential without consulting ambient authentication"

printf 'ATLAS_KEY_PAT="synthetic-token"\n' > "$ENV_FILE"
set +e
malformed=$(run_broker preflight task-a Atlas "$PROJECT" 2>&1)
malformed_rc=$?
set -e
[ "$malformed_rc" -ne 0 ] || fail "quoted credential definitions must fail the strict parser"
assert_contains "$malformed" 'credential-malformed' "malformed credentials should use the credential-malformed category"
pass "broker rejects malformed credential assignments"

printf 'ATLAS_KEY_PAT=synthetic-token\n' > "$ENV_FILE"

fm_write_meta "$HOME_DIR/state/task-a.meta" \
  'window=fm-task-a' \
  "worktree=$PROJECT" \
  "project=$PROJECT" \
  'kind=ship' \
  'mode=direct-PR' \
  'pr_identity=atlas-pat' \
  'pr_project_key=Atlas' \
  'pr_repo=edheltzel/fixture' \
  'pr_branch=fm/task-a' \
  'pr_base=main'

printf 'login: Atlas-Key\n' > "$CASE_ROOT/user.out"
printf 'secret-looking text must not be emitted\n' > "$CASE_ROOT/body.md"
set +e
bad_url=$(run_broker read task-a 'https://github.com/other/repo/pull/1' 2>&1)
bad_url_rc=$?
set -e
[ "$bad_url_rc" -ne 0 ] || fail "repository override in read URL must fail"
assert_contains "$bad_url" 'pr-mismatch' "wrong repository must use the PR mismatch category"
assert_not_contains "$bad_url" 'synthetic-token' "read failures must not expose credentials"
pass "broker rejects a PR URL outside the recorded repository without ambient fallback"

cat > "$FAKEBIN/git" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *'remote get-url origin'*) printf 'git@github.com:edheltzel/fixture.git\n' ;;
  *'rev-parse --show-toplevel'*) printf '%s\n' "$FM_TEST_PROJECT" ;;
  *'symbolic-ref'* ) printf 'refs/remotes/origin/main\n' ;;
  *'rev-parse --verify refs/remotes/origin/main'*) printf '1111111111111111111111111111111111111111\n' ;;
  *'rev-parse --verify HEAD'*) printf '2222222222222222222222222222222222222222\n' ;;
  *'status --porcelain'*) ;;
  *'rev-list'*) printf '2222222222222222222222222222222222222222\n' ;;
  *'log --format=%H '* ) printf '2222222222222222222222222222222222222222\n' ;;
  *'log --format='*) printf '2222222222222222222222222222222222222222\tAtlas\tatlas@rainyday.media\tAtlas\tatlas@rainyday.media\n' ;;
  *'cat-file commit'*) ;;
  *'branch --show-current'*) printf 'fm/task-a\n' ;;
  *'ls-remote'*) printf '2222222222222222222222222222222222222222\trefs/heads/fm/task-a\n' ;;
  *'push origin fm/task-a:fm/task-a'*)
    [ "${GIT_TERMINAL_PROMPT:-}" = 0 ] || exit 1
    [ "${GIT_ASKPASS:-}" = '' ] || exit 1
    printf 'transport-ok\n' > "$FM_TEST_TRANSPORT_LOG"
    ;;
  *) exit 1 ;;
esac
SH
chmod +x "$FAKEBIN/git"
FM_TEST_PROJECT=$(cd "$PROJECT" && pwd -P)
FM_TEST_TRANSPORT_LOG="$CASE_ROOT/transport.log"
export FM_TEST_PROJECT FM_TEST_TRANSPORT_LOG
push_out=$(run_broker push task-a) || fail "synthetic broker push unexpectedly failed"
assert_contains "$push_out" 'pushed: repo=edheltzel/fixture branch=fm/task-a' "push should report only safe binding data"
assert_present "$HOME_DIR/state/task-a.pr-publication" "push should publish a partial-publication record"
assert_grep 'remote_state=pushed' "$HOME_DIR/state/task-a.pr-publication" "push record should preserve remote state"
assert_not_contains "$(cat "$HOME_DIR/state/task-a.pr-publication")" 'synthetic-token' "publication records must never contain credentials"
assert_present "$FM_TEST_TRANSPORT_LOG" "push should use the host transport helper"
pass "broker push checks exact branch and commit attribution while disabling prompting"

cat > "$FAKEBIN/gh-axi" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *'/pulls/1/commits'*)
    if [ "${FM_TEST_BAD_COMMITS:-0}" = 1 ]; then
      printf '[1]:\n  - sha: 3333333333333333333333333333333333333333\n    author:\n      login: Atlas-Key\n    committer:\n      login: Atlas-Key\n'
    else
      cat "$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-commits.toon"
    fi
    ;;
  *'/pulls/1'*) cat "$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-${FM_TEST_PR_VIEW:-open}.toon" ;;
  *'api /user'*)
    if [ -n "${GH_TOKEN:-}" ]; then printf 'login: Atlas-Key\n'; else printf 'login: edheltzel\n'; fi
    ;;
  *collaborators/Atlas-Key/permission*) printf 'permission: write\n' ;;
  *required_signatures*) printf 'enabled: false\n' ;;
  *'pr create'*) printf 'https://github.com/edheltzel/fixture/pull/1\n' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$FAKEBIN/gh-axi"
export FM_TEST_ROOT="$ROOT" FM_TEST_PR_VIEW=open
read_out=$(run_broker read task-a 'https://github.com/edheltzel/fixture/pull/1') || fail "real-TOON PR read unexpectedly failed"
assert_contains "$read_out" 'author=Atlas-Key' "read verification should assert the PR author"
assert_contains "$read_out" 'head_sha=2222222222222222222222222222222222222222' "read verification should return the exact head"
verify_out=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1') || fail "real-TOON PR verification unexpectedly failed"
assert_contains "$verify_out" 'verified=1' "verify should complete only after the commit-set check"
merge_out=$(run_broker merge-assert task-a 'https://github.com/edheltzel/fixture/pull/1') || fail "synthetic merge assertion unexpectedly failed"
assert_contains "$merge_out" 'merge-authority=edheltzel' "merge assertion should require Ed authentication"
pass "broker parses real gh-axi TOON for read and exact commit verification"

printf 'synthetic title\n' > "$CASE_ROOT/title.md"
printf 'synthetic body\n' > "$CASE_ROOT/body.md"
run_broker push task-a >/dev/null || fail "synthetic push reset unexpectedly failed"
export FM_TEST_BAD_COMMITS=1
set +e
create_failure=$(run_broker create task-a "$CASE_ROOT/title.md" "$CASE_ROOT/body.md" 2>&1)
create_failure_rc=$?
set -e
[ "$create_failure_rc" -ne 0 ] || fail "a changed remote commit set must fail create"
assert_contains "$create_failure" 'PR commit set differs' "create verification failure should explain the mismatch"
assert_grep 'pr_state=verification-failed' "$HOME_DIR/state/task-a.pr-publication" \
  "create verification failure should be durable"
assert_grep 'retry_safe=no' "$HOME_DIR/state/task-a.pr-publication" \
  "create verification failure must disable automatic retry"
assert_grep 'pr_url=https://github.com/edheltzel/fixture/pull/1' "$HOME_DIR/state/task-a.pr-publication" \
  "create verification failure must preserve the created PR URL"
unset FM_TEST_BAD_COMMITS
pass "create persists a verification failure with the created PR URL and retry_safe=no"

printf 'pr_head=2222222222222222222222222222222222222222\n' >> "$HOME_DIR/state/task-a.meta"
cp "$ROOT/bin/fm-pr-poll.sh" "$HOME_DIR/state/task-a.check.sh"
chmod 0700 "$HOME_DIR/state/task-a.check.sh"
printf 'github\nhttps://github.com/edheltzel/fixture/pull/1\ngithub.com\nedheltzel/fixture\n1\n' > "$HOME_DIR/state/task-a.pr-poll"
chmod 0600 "$HOME_DIR/state/task-a.pr-poll"
FM_PR_IDENTITY_TEST_MODE=1 FM_PR_POLL_ROOT="$ROOT" FM_PR_POLL_HOME="$HOME_DIR" \
  FM_PR_POLL_STATE="$HOME_DIR/state" FM_PR_POLL_TASK_ID=task-a \
  FM_TEST_PR_VIEW=merged PATH="$FAKEBIN:$PATH" "$HOME_DIR/state/task-a.check.sh" > "$CASE_ROOT/poll.out"
poll_out=$(cat "$CASE_ROOT/poll.out")
[ "$poll_out" = merged ] || fail "opted-in merged poll should emit exactly merged, got '$poll_out'"
cat > "$FAKEBIN/gh-axi" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$FAKEBIN/gh-axi"
poll_error=$(FM_PR_IDENTITY_TEST_MODE=1 FM_PR_POLL_ROOT="$ROOT" FM_PR_POLL_HOME="$HOME_DIR" \
  FM_PR_POLL_STATE="$HOME_DIR/state" FM_PR_POLL_TASK_ID=task-a PATH="$FAKEBIN:$PATH" \
  "$HOME_DIR/state/task-a.check.sh")
assert_contains "$poll_error" 'read-error:' "opted-in poll auth failures must be visible"
pass "opted-in polling uses the broker verification path and detects REST merged state"

set +e
help_out=$("$BROKER" --help)
help_rc=$?
set -e
[ "$help_rc" -eq 0 ] || fail "broker help should be available"
assert_contains "$help_out" 'preflight' "broker help should document the allowlisted preflight operation"
assert_contains "$help_out" 'merge-assert' "broker help should document the explicit merge assertion"
pass "broker help exposes only the narrow lifecycle operations"
