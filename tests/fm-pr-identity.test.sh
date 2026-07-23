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
    FM_PR_IDENTITY_GH_AXI="$FAKEBIN/gh-axi" PATH="$FAKEBIN:$PATH" "$BROKER" "$@"
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

set +e
help_out=$("$BROKER" --help)
help_rc=$?
set -e
[ "$help_rc" -eq 0 ] || fail "broker help should be available"
assert_contains "$help_out" 'preflight' "broker help should document the allowlisted preflight operation"
assert_contains "$help_out" 'merge-assert' "broker help should document the explicit merge assertion"
pass "broker help exposes only the narrow lifecycle operations"
