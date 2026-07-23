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
if [ "${1:-}" = --version ]; then printf '0.1.27\n'; exit 0; fi
 [ "${GH_TOKEN:-}" = synthetic-token ] || exit 1
case "$*" in
  "api /user") printf 'login: Atlas-Key\n' ;;
  *collaborators/Atlas-Key/permission*) printf 'permission: write\n' ;;
  *required_signatures*)
    case "${FM_TEST_POLICY_MODE:-false}" in
      404) printf 'HTTP 404\n' >&2; exit 1 ;;
      403) printf 'HTTP 403\n' >&2; exit 1 ;;
      401) printf 'HTTP 401\n' >&2; exit 1 ;;
      500) printf 'HTTP 500\n' >&2; exit 1 ;;
      malformed) printf 'enabled: maybe\n' ;;
      true) printf 'enabled: true\n' ;;
      *) printf 'enabled: false\n' ;;
    esac
    ;;
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

test_installed_gh_axi_contract() {
  local gh_axi_bin gh_axi_root tmp_open tmp_commits actual_version
  gh_axi_bin=$(command -v gh-axi || true)
  if [ -z "$gh_axi_bin" ]; then
    pass "installed gh-axi contract fixture check skipped when gh-axi is unavailable"
    return 0
  fi
  gh_axi_root=$(cd "$(dirname "$gh_axi_bin")/../lib/node_modules/gh-axi" 2>/dev/null && pwd -P || true)
  if [ ! -f "$gh_axi_root/node_modules/@toon-format/toon/dist/index.mjs" ] || ! command -v node >/dev/null 2>&1; then
    pass "installed gh-axi encoder fixture check skipped when its local encoder is unavailable"
    return 0
  fi
  actual_version=$("$gh_axi_bin" --version) || fail "installed gh-axi version check failed"
  printf '%s\n' "$actual_version" > "$CASE_ROOT/.actual-gh-axi-version"
  cmp -s "$ROOT/tests/fixtures/gh-axi-contract-version.txt" "$CASE_ROOT/.actual-gh-axi-version" \
    || fail "supported gh-axi version must match the committed local contract"
  tmp_open=$(mktemp "$CASE_ROOT/.golden-open.XXXXXX")
  tmp_commits=$(mktemp "$CASE_ROOT/.golden-commits.XXXXXX")
  node --input-type=module - "$tmp_open" "$tmp_commits" "$gh_axi_root" <<'NODE'
import { writeFileSync } from 'node:fs';
const { encode } = await import(`${process.argv[4]}/node_modules/@toon-format/toon/dist/index.mjs`);
writeFileSync(process.argv[2], encode({base:{ref:'main'},head:{ref:'fm/task-a',sha:'2222222222222222222222222222222222222222'},merged:false,merged_at:null,state:'open',user:'Atlas-Key'}) + '\n');
writeFileSync(process.argv[3], encode([
  {sha:'1111111111111111111111111111111111111111',author:{login:'Atlas-Key'},committer:{login:'Atlas-Key'}},
  {sha:'2222222222222222222222222222222222222222',author:{login:'Atlas-Key'},committer:{login:'Atlas-Key'}}
]) + '\n');
NODE
  cmp -s "$ROOT/tests/fixtures/gh-axi-pr-open.golden.toon" "$tmp_open" \
    || fail "PR golden fixture must match the installed gh-axi TOON encoder"
  cmp -s "$ROOT/tests/fixtures/gh-axi-pr-commits.golden.toon" "$tmp_commits" \
    || fail "commit golden fixture must match the installed gh-axi TOON encoder"
  pass "installed gh-axi 0.1.27 output contract matches local golden encoder fixtures without network calls"
}

test_installed_gh_axi_contract

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

awk '{ if ($0 == "pr_identity=atlas-pat") print "pr_identity=none"; else print }' \
  "$HOME_DIR/state/task-a.meta" > "$CASE_ROOT/tampered.meta"
mv "$CASE_ROOT/tampered.meta" "$HOME_DIR/state/task-a.meta"
set +e
tampered=$(run_broker read task-a 'https://github.com/edheltzel/fixture/pull/1' 2>&1)
tampered_rc=$?
set -e
[ "$tampered_rc" -ne 0 ] || fail "metadata identity downgrade must fail"
assert_contains "$tampered" 'metadata disagrees with the host identity binding' \
  "metadata identity downgrade should be rejected by the host binding"
awk '{ if ($0 == "pr_identity=none") print "pr_identity=atlas-pat"; else print }' \
  "$HOME_DIR/state/task-a.meta" > "$CASE_ROOT/restored.meta"
mv "$CASE_ROOT/restored.meta" "$HOME_DIR/state/task-a.meta"
pass "mutable task metadata cannot downgrade the host-bound Atlas identity"

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
  *'log --format=%H '* ) printf '%s\n' "${FM_TEST_LOCAL_COMMITS:-2222222222222222222222222222222222222222}" ;;
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
  --version) printf '0.1.27\n' ;;
  *'/pulls/1/commits?per_page=100&page=2'*)
    if [ "${FM_TEST_PAGE_TWO:-0}" = 1 ]; then cat "$FM_TEST_PAGE_TWO_FILE"; else printf '[0]:\n'; fi
    ;;
  *'/pulls/1/commits?per_page=100&page=1'*)
    if [ "${FM_TEST_PAGE_TWO:-0}" = 1 ]; then
      cat "$FM_TEST_PAGE_ONE_FILE"
    elif [ "${FM_TEST_BAD_COMMITS:-0}" = 1 ]; then
      printf '[1]:\n  - sha: "3333333333333333333333333333333333333333"\n    author:\n      login: Atlas-Key\n    committer:\n      login: Atlas-Key\n'
    else
      cat "${FM_TEST_COMMIT_FIXTURE:-$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-commits.toon}"
    fi
    ;;
  *'/pulls/1/commits'*)
    if [ "${FM_TEST_BAD_COMMITS:-0}" = 1 ]; then
      printf '[1]:\n  - sha: "3333333333333333333333333333333333333333"\n    author:\n      login: Atlas-Key\n    committer:\n      login: Atlas-Key\n'
    else
      cat "${FM_TEST_COMMIT_FIXTURE:-$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-commits.toon}"
    fi
    ;;
  *'/pulls/1'*) cat "$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-${FM_TEST_PR_VIEW:-open}.toon" ;;
  *'api /user'*)
    if [ -n "${GH_TOKEN:-}" ]; then printf 'login: Atlas-Key\n'; else printf 'login: edheltzel\n'; fi
    ;;
  *collaborators/Atlas-Key/permission*) printf 'permission: write\n' ;;
  *required_signatures*)
    case "${FM_TEST_POLICY_MODE:-false}" in
      404) printf 'HTTP 404\n' >&2; exit 1 ;;
      403) printf 'HTTP 403\n' >&2; exit 1 ;;
      401) printf 'HTTP 401\n' >&2; exit 1 ;;
      500) printf 'HTTP 500\n' >&2; exit 1 ;;
      malformed) printf 'enabled: maybe\n' ;;
      true) printf 'enabled: true\n' ;;
      *) printf 'enabled: false\n' ;;
    esac
    ;;
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

test_unsigned_policy_contract() {
  local mode output rc
  export FM_TEST_POLICY_MODE=404
  output=$(run_broker preflight task-policy Atlas "$PROJECT") \
    || fail "documented not-protected signing policy should be accepted"
  assert_contains "$output" 'profile=atlas-pat' "404 not-protected result should retain the broker profile"
  for mode in 403 401 500 malformed true; do
    export FM_TEST_POLICY_MODE=$mode
    set +e
    output=$(run_broker preflight task-policy Atlas "$PROJECT" 2>&1)
    rc=$?
    set -e
    [ "$rc" -ne 0 ] || fail "signing policy mode $mode must refuse preflight"
    assert_contains "$output" 'signing-policy' "signing policy mode $mode should remain unknown or refused"
  done
  unset FM_TEST_POLICY_MODE
  pass "unsigned policy accepts only documented 404 absence and refuses 403/auth/server/malformed/protected results"
}

test_unsigned_policy_contract

test_commit_shapes_and_pagination() {
  local tabular hidden null_attribution malformed page_one page_two many_out failure failure_rc
  export FM_TEST_LOCAL_COMMITS=$'1111111111111111111111111111111111111111\n2222222222222222222222222222222222222222'
  export FM_TEST_COMMIT_FIXTURE="$ROOT/tests/fixtures/gh-axi-pr-commits.golden.toon"
  verify_out=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1') \
    || fail "two-commit item-list verification unexpectedly failed"
  assert_contains "$verify_out" 'verified=1' "two-commit item-list verification should accept every row"

  tabular="$CASE_ROOT/tabular.toon"
  printf '%s\n' '[2]{sha,author,committer}:' \
    '  "1111111111111111111111111111111111111111",Atlas-Key,Atlas-Key' \
    '  "2222222222222222222222222222222222222222",Atlas-Key,Atlas-Key' > "$tabular"
  FM_TEST_COMMIT_FIXTURE="$tabular"
  verify_out=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1') \
    || fail "two-commit tabular verification unexpectedly failed"
  assert_contains "$verify_out" 'verified=1' "tabular commit verification should accept every declared row"

  many_out="$CASE_ROOT/many.toon"
  printf '%s\n' '[3]:' \
    '  - sha: "1111111111111111111111111111111111111111"' \
    '    author:' '      login: Atlas-Key' \
    '    committer:' '      login: Atlas-Key' \
    '  - sha: "2222222222222222222222222222222222222222"' \
    '    author:' '      login: Atlas-Key' \
    '    committer:' '      login: Atlas-Key' \
    '  - sha: "4444444444444444444444444444444444444444"' \
    '    author:' '      login: Atlas-Key' \
    '    committer:' '      login: Atlas-Key' > "$many_out"
  export FM_TEST_LOCAL_COMMITS=$'1111111111111111111111111111111111111111\n2222222222222222222222222222222222222222\n4444444444444444444444444444444444444444'
  FM_TEST_COMMIT_FIXTURE="$many_out"
  verify_out=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1') \
    || fail "many-commit item-list verification unexpectedly failed"
  assert_contains "$verify_out" 'verified=1' "many-commit verification should compare the complete remote set"

  hidden="$CASE_ROOT/hidden-foreign.toon"
  printf '%s\n' '[3]:' \
    '  - sha: "3333333333333333333333333333333333333333"' \
    '    author:' '      login: Other-User' \
    '    committer:' '      login: Other-User' \
    '  - sha: "1111111111111111111111111111111111111111"' \
    '    author:' '      login: Atlas-Key' \
    '    committer:' '      login: Atlas-Key' \
    '  - sha: "2222222222222222222222222222222222222222"' \
    '    author:' '      login: Atlas-Key' \
    '    committer:' '      login: Atlas-Key' > "$hidden"
  export FM_TEST_LOCAL_COMMITS=$'1111111111111111111111111111111111111111\n2222222222222222222222222222222222222222'
  FM_TEST_COMMIT_FIXTURE="$hidden"
  set +e
  failure=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1' 2>&1)
  failure_rc=$?
  set -e
  [ "$failure_rc" -ne 0 ] || fail "hidden foreign commit row must refuse verification"
  assert_contains "$failure" 'commit-attribution' "hidden foreign rows must not disappear from attribution"

  null_attribution="$CASE_ROOT/null-attribution.toon"
  printf '%s\n' '[1]:' \
    '  - sha: "2222222222222222222222222222222222222222"' \
    '    author: null' \
    '    committer:' '      login: Atlas-Key' > "$null_attribution"
  FM_TEST_COMMIT_FIXTURE="$null_attribution"
  set +e
  failure=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1' 2>&1)
  failure_rc=$?
  set -e
  [ "$failure_rc" -ne 0 ] || fail "null attribution must refuse verification"
  assert_contains "$failure" 'commit-attribution' "null attribution must not be treated as Atlas-Key"

  malformed="$CASE_ROOT/malformed-shape.toon"
  printf '%s\n' '[2]:' \
    '  - sha: "2222222222222222222222222222222222222222"' \
    '    author:' '      login: Atlas-Key' > "$malformed"
  FM_TEST_COMMIT_FIXTURE="$malformed"
  set +e
  failure=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1' 2>&1)
  failure_rc=$?
  set -e
  [ "$failure_rc" -ne 0 ] || fail "incomplete commit list must refuse verification"
  assert_contains "$failure" 'verify-malformed' "incomplete commit list should use the malformed category"

  page_one="$CASE_ROOT/page-one.toon"
  page_two="$CASE_ROOT/page-two.toon"
  {
    printf '%s\n' '[100]:'
    for _ in $(seq 1 100); do
      printf '%s\n' '  - sha: "1111111111111111111111111111111111111111"' \
        '    author:' '      login: Atlas-Key' \
        '    committer:' '      login: Atlas-Key'
    done
  } > "$page_one"
  printf '%s\n' '[1]:' \
    '  - sha: "2222222222222222222222222222222222222222"' \
    '    author:' '      login: Atlas-Key' \
    '    committer:' '      login: Atlas-Key' > "$page_two"
  export FM_TEST_PAGE_TWO=1 FM_TEST_PAGE_ONE_FILE="$page_one" FM_TEST_PAGE_TWO_FILE="$page_two"
  FM_TEST_COMMIT_FIXTURE="$ROOT/tests/fixtures/gh-axi-pr-commits.golden.toon"
  verify_out=$(run_broker verify task-a 'https://github.com/edheltzel/fixture/pull/1') \
    || fail "paginated commit verification unexpectedly failed"
  assert_contains "$verify_out" 'verified=1' "pagination should combine all pages before exact comparison"
  unset FM_TEST_PAGE_TWO FM_TEST_PAGE_ONE_FILE FM_TEST_PAGE_TWO_FILE FM_TEST_COMMIT_FIXTURE FM_TEST_LOCAL_COMMITS
  pass "commit parser covers one/two/many rows, tabular output, foreign/null attribution, malformed shape, and pagination"
}

test_commit_shapes_and_pagination

reconcile_out=$(run_broker reconcile task-a 'https://github.com/edheltzel/fixture/pull/1') \
  || fail "explicit reconciliation should recover a known PR after a verification refusal"
assert_contains "$reconcile_out" 'verified=1' "reconciliation should re-establish a verified publication record"
pass "explicit reconcile path clears a known retry-unsafe publication without creating a duplicate PR"

printf 'synthetic title\n' > "$CASE_ROOT/title.md"
printf 'synthetic body\n' > "$CASE_ROOT/body.md"
set +e
duplicate_create=$(run_broker create task-a "$CASE_ROOT/title.md" "$CASE_ROOT/body.md" 2>&1)
duplicate_create_rc=$?
set -e
[ "$duplicate_create_rc" -ne 0 ] || fail "a known PR must not be created a second time"
assert_contains "$duplicate_create" 'publication-duplicate' "known PR retries should require reconciliation instead of creating a duplicate"
printf '%s\n' 'pr_url=https://github.com/edheltzel/fixture/pull/1' >> "$HOME_DIR/state/task-a.pr-publication"
set +e
duplicate_field_create=$(run_broker create task-a "$CASE_ROOT/title.md" "$CASE_ROOT/body.md" 2>&1)
duplicate_field_create_rc=$?
set -e
[ "$duplicate_field_create_rc" -ne 0 ] || fail "duplicate publication fields must refuse create"
assert_contains "$duplicate_field_create" 'publication-state' \
  "duplicate publication fields should fail closed before a second PR request"
rm -f -- "$HOME_DIR/state/task-a.pr-publication"
reset_out=$(run_broker reset task-a --confirm-no-pr) || fail "explicit no-PR reset should restore a retry-safe state"
assert_contains "$reset_out" 'retry_safe=yes' "reset should publish an explicit retry-safe reconciliation state"
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
set +e
retry_create=$(run_broker create task-a "$CASE_ROOT/title.md" "$CASE_ROOT/body.md" 2>&1)
retry_create_rc=$?
retry_push=$(run_broker push task-a 2>&1)
retry_push_rc=$?
set -e
[ "$retry_create_rc" -ne 0 ] || fail "retry-unsafe create must refuse a duplicate retry"
[ "$retry_push_rc" -ne 0 ] || fail "retry-unsafe push must refuse an ambiguous retry"
assert_contains "$retry_create" 'retry-unsafe' "create retry should honor durable retry_safe=no"
assert_contains "$retry_push" 'retry-unsafe' "push retry should honor durable retry_safe=no"
unset FM_TEST_BAD_COMMITS
pass "create persists a verification failure with the created PR URL and retry_safe=no"

printf 'pr_head=2222222222222222222222222222222222222222\n' >> "$HOME_DIR/state/task-a.meta"
cp "$ROOT/bin/fm-pr-poll.sh" "$HOME_DIR/state/task-a.check.sh"
chmod 0700 "$HOME_DIR/state/task-a.check.sh"
printf 'github\nhttps://github.com/edheltzel/fixture/pull/1\ngithub.com\nedheltzel/fixture\n1\n' > "$HOME_DIR/state/task-a.pr-poll"
chmod 0600 "$HOME_DIR/state/task-a.pr-poll"
FM_PR_IDENTITY_TEST_MODE=1 FM_PR_POLL_ROOT="$ROOT" FM_PR_POLL_HOME="$HOME_DIR" \
  FM_PR_POLL_STATE="$HOME_DIR/state" FM_PR_POLL_TASK_ID=task-a \
  FM_TEST_PR_VIEW=merged PATH="$FAKEBIN:$PATH" bash "$HOME_DIR/state/task-a.check.sh" > "$CASE_ROOT/poll.out"
poll_out=$(cat "$CASE_ROOT/poll.out")
[ "$poll_out" = merged ] || fail "opted-in merged poll should emit exactly merged, got '$poll_out'"
mv "$HOME_DIR/state/task-a.pr-binding" "$CASE_ROOT/task-a.pr-binding.saved"
poll_missing=$(FM_PR_IDENTITY_TEST_MODE=1 FM_PR_POLL_ROOT="$ROOT" FM_PR_POLL_HOME="$HOME_DIR" \
  FM_PR_POLL_STATE="$HOME_DIR/state" FM_PR_POLL_TASK_ID=task-a PATH="$FAKEBIN:$PATH" \
  bash "$HOME_DIR/state/task-a.check.sh")
assert_contains "$poll_missing" 'read-error: Atlas PR binding is unavailable' \
  "opted-in polling must refuse a missing host binding"
mv "$CASE_ROOT/task-a.pr-binding.saved" "$HOME_DIR/state/task-a.pr-binding"
sed -i.bak 's/^pr_identity=atlas-pat$/pr_identity=none/' "$HOME_DIR/state/task-a.meta"
rm -f "$HOME_DIR/state/task-a.meta.bak"
poll_downgrade=$(FM_PR_IDENTITY_TEST_MODE=1 FM_PR_POLL_ROOT="$ROOT" FM_PR_POLL_HOME="$HOME_DIR" \
  FM_PR_POLL_STATE="$HOME_DIR/state" FM_PR_POLL_TASK_ID=task-a PATH="$FAKEBIN:$PATH" \
  bash "$HOME_DIR/state/task-a.check.sh")
assert_contains "$poll_downgrade" 'read-error: Atlas PR binding is invalid or downgraded' \
  "opted-in polling must refuse a metadata identity downgrade"
sed -i.bak 's/^pr_identity=none$/pr_identity=atlas-pat/' "$HOME_DIR/state/task-a.meta"
rm -f "$HOME_DIR/state/task-a.meta.bak"
pass "opted-in polling rejects missing bindings and identity-downgraded metadata"
cat > "$FAKEBIN/gh-axi-merge" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$FM_TEST_MERGE_LOG"
case "$*" in
  --version) printf '0.1.27\n' ;;
  *'api PUT /repos/edheltzel/fixture/pulls/1/merge'*)
    if [ "${FM_TEST_MOVED_HEAD:-0}" = 1 ]; then printf 'HTTP 409\n' >&2; exit 1; fi
    printf 'merged\n'
    ;;
  *'api DELETE /repos/edheltzel/fixture/git/refs/heads/fm/task-a'*) printf 'deleted\n' ;;
  *'/pulls/1/commits?per_page=100&page=2'*) printf '[0]:\n' ;;
  *'/pulls/1/commits?per_page=100&page=1'*) cat "$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-commits.golden.toon" ;;
  *'/pulls/1/commits'*) cat "$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-commits.golden.toon" ;;
  *'/pulls/1'*) cat "$FM_TEST_ROOT/tests/fixtures/gh-axi-pr-open.golden.toon" ;;
  *'api /user'*)
    if [ -n "${GH_TOKEN:-}" ]; then printf 'login: Atlas-Key\n'; else printf 'login: edheltzel\n'; fi
    ;;
  *collaborators/Atlas-Key/permission*) printf 'permission: write\n' ;;
  *required_signatures*) printf 'enabled: false\n' ;;
  *) exit 1 ;;
esac
SH
chmod +x "$FAKEBIN/gh-axi-merge"
cp "$FAKEBIN/gh-axi-merge" "$FAKEBIN/gh-axi"
export FM_TEST_LOCAL_COMMITS=$'1111111111111111111111111111111111111111\n2222222222222222222222222222222222222222'
FM_TEST_PR_VIEW=open FM_TEST_MERGE_LOG="$CASE_ROOT/merge.log" \
  FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" \
  FM_PR_IDENTITY_TEST_MODE=1 FM_PR_IDENTITY_GH_AXI="$FAKEBIN/gh-axi-merge" \
  PATH="$FAKEBIN:$PATH" "$ROOT/bin/fm-pr-merge.sh" task-a \
  'https://github.com/edheltzel/fixture/pull/1' > "$CASE_ROOT/merge.out" \
  || fail "Atlas REST merge unexpectedly failed"
assert_grep 'api PUT /repos/edheltzel/fixture/pulls/1/merge --field sha=2222222222222222222222222222222222222222 --field merge_method=squash' \
  "$CASE_ROOT/merge.log" "Atlas merge must pass the verified head SHA to REST"
pass "Atlas merge uses the captain-selected REST SHA-pinned endpoint"

: > "$CASE_ROOT/merge.log"
set +e
FM_TEST_MOVED_HEAD=1 FM_TEST_PR_VIEW=open FM_TEST_MERGE_LOG="$CASE_ROOT/merge.log" \
  FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$HOME_DIR" FM_STATE_OVERRIDE="$HOME_DIR/state" \
  FM_PR_IDENTITY_TEST_MODE=1 FM_PR_IDENTITY_GH_AXI="$FAKEBIN/gh-axi-merge" \
  PATH="$FAKEBIN:$PATH" "$ROOT/bin/fm-pr-merge.sh" task-a \
  'https://github.com/edheltzel/fixture/pull/1' > "$CASE_ROOT/moved-merge.out" 2>&1
moved_merge_rc=$?
set -e
[ "$moved_merge_rc" -ne 0 ] || fail "moved-head REST merge must be rejected"
assert_grep 'api PUT /repos/edheltzel/fixture/pulls/1/merge --field sha=2222222222222222222222222222222222222222' \
  "$CASE_ROOT/merge.log" "moved-head rejection must still use the verified SHA pin"
assert_no_grep 'pr merge' "$CASE_ROOT/merge.log" \
  "Atlas merge must not fall back to the unpinned gh-axi pr merge command"
pass "REST merge rejects a moved PR head atomically"

cat > "$FAKEBIN/gh-axi" <<'SH'
#!/usr/bin/env bash
exit 1
SH
chmod +x "$FAKEBIN/gh-axi"
poll_error=$(FM_PR_IDENTITY_TEST_MODE=1 FM_PR_POLL_ROOT="$ROOT" FM_PR_POLL_HOME="$HOME_DIR" \
  FM_PR_POLL_STATE="$HOME_DIR/state" FM_PR_POLL_TASK_ID=task-a PATH="$FAKEBIN:$PATH" \
  bash "$HOME_DIR/state/task-a.check.sh")
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
