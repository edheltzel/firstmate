#!/usr/bin/env bash
# Provider selection plus both spawn/teardown isolation branches:
# GitButler worktrees when but is selected, Treehouse when it is not.
# Ownership proofs stay the same on both branches.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

LIB="$ROOT/bin/fm-worktree-lib.sh"
SPAWN="$ROOT/bin/fm-spawn.sh"
TEARDOWN="$ROOT/bin/fm-teardown.sh"
TMP_ROOT=$(fm_test_tmproot fm-worktree-provider)

# shellcheck source=bin/fm-worktree-lib.sh
. "$LIB"
# shellcheck source=bin/fm-backend.sh
. "$ROOT/bin/fm-backend.sh"

make_spawn_fakebin() {
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
printf '%s\n' "$*" >> "${FM_TMUX_LOG:?}"
case "$*" in
  *"#{pane_current_path}"*)
    printf '%s\n' "${FM_FAKE_PANE_PATH:-}"
    exit 0
    ;;
esac
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
  list-windows) exit 0 ;;
  has-session|new-session|new-window|kill-window) exit 0 ;;
  send-keys) exit 0 ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  fm_fake_exit0 "$fakebin" treehouse
  printf '%s\n' "$fakebin"
}

make_home() {
  local name=$1 id=$2 home proj
  home="$TMP_ROOT/$name/home"
  proj="$TMP_ROOT/$name/project"
  mkdir -p "$home/data" "$home/projects" "$home/state" "$home/config"
  printf 'codex\n' > "$home/config/crew-harness"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
  mkdir -p "$home/data/$id"
  printf 'brief for %s\n' "$id" > "$home/data/$id/brief.md"
  touch "$home/state/.last-watcher-beat"
  printf '%s\n' "$home|$proj"
}

test_override_pins_provider() {
  local got
  got=$(FM_WORKTREE_PROVIDER=but fm_worktree_provider)
  [ "$got" = but ] || fail "override but: got $got"
  got=$(FM_WORKTREE_PROVIDER=treehouse fm_worktree_provider)
  [ "$got" = treehouse ] || fail "override treehouse: got $got"
  pass "FM_WORKTREE_PROVIDER pins but and treehouse"
}

test_auto_detects_but_then_treehouse() {
  local fakebin got gitbin pathdir
  gitbin=$(command -v git)
  fakebin=$(fm_fakebin "$TMP_ROOT/auto-but")
  fm_fake_exit0 "$fakebin" but
  pathdir="$TMP_ROOT/auto-but/path"
  mkdir -p "$pathdir"
  ln -sf "$fakebin/but" "$pathdir/but"
  ln -sf "$gitbin" "$pathdir/git"
  got=$(unset FM_WORKTREE_PROVIDER; PATH="$pathdir" fm_worktree_provider)
  [ "$got" = but ] || fail "auto with but: got $got"
  fakebin=$(fm_fakebin "$TMP_ROOT/auto-treehouse")
  fm_fake_exit0 "$fakebin" treehouse
  pathdir="$TMP_ROOT/auto-treehouse/path"
  mkdir -p "$pathdir"
  ln -sf "$fakebin/treehouse" "$pathdir/treehouse"
  ln -sf "$gitbin" "$pathdir/git"
  got=$(unset FM_WORKTREE_PROVIDER; PATH="$pathdir" fm_worktree_provider)
  [ "$got" = treehouse ] || fail "auto without but: got $got"
  pass "auto-detect prefers but when present, else treehouse"
}

test_required_tools_follow_provider() {
  local tools
  tools=$(FM_WORKTREE_PROVIDER=but fm_backend_required_tools tmux)
  [ "$tools" = tmux ] || fail "but tmux tools: $tools"
  tools=$(FM_WORKTREE_PROVIDER=but fm_backend_required_tools herdr)
  [ "$tools" = "herdr jq" ] || fail "but herdr tools: $tools"
  tools=$(FM_WORKTREE_PROVIDER=treehouse fm_backend_required_tools tmux)
  [ "$tools" = "tmux treehouse" ] || fail "treehouse tmux tools: $tools"
  tools=$(FM_WORKTREE_PROVIDER=treehouse fm_backend_required_tools herdr)
  [ "$tools" = "herdr jq treehouse" ] || fail "treehouse herdr tools: $tools"
  tools=$(FM_WORKTREE_PROVIDER=but fm_backend_required_tools orca)
  [ "$tools" = orca ] || fail "orca must stay orca-only: $tools"
  pass "required tools omit treehouse on the but branch and keep it on treehouse"
}

test_spawn_but_creates_git_worktree() {
  local rec home proj id fakebin wt log out status owner_token
  id=but-spawn-a1
  rec=$(make_home spawn-but "$id")
  IFS='|' read -r home proj <<EOF
$rec
EOF
  wt="$TMP_ROOT/but-wts/$id"
  fakebin=$(make_spawn_fakebin "$TMP_ROOT/spawn-but/fake")
  log="$TMP_ROOT/spawn-but/tmux.log"
  mkdir -p "$(dirname "$wt")"
  out=$(
    FM_ROOT_OVERRIDE='' FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
      FM_SPAWN_NO_GUARD=1 TMUX="fake,1,0" \
      FM_WORKTREE_PROVIDER=but FM_BUT_WORKTREE_ROOT="$TMP_ROOT/but-wts" \
      FM_FAKE_PANE_PATH="$wt" FM_TMUX_LOG="$log" \
      PATH="$fakebin:$PATH" \
      "$SPAWN" "$id" "$proj" --mode no-mistakes --yolo off 2>&1
  )
  status=$?
  expect_code 0 "$status" "but spawn should succeed"
  assert_contains "$out" "spawned $id" "but spawn did not report success"
  assert_present "$wt" "but spawn did not create a git worktree"
  [ "$(git -C "$wt" rev-parse --is-inside-work-tree)" = true ] \
    || fail "but spawn path is not a git worktree"
  [ "$(cd "$wt" && pwd -P)" != "$(cd "$proj" && pwd -P)" ] \
    || fail "but spawn used the primary checkout"
  assert_grep "worktree=$wt" "$home/state/$id.meta" \
    "but spawn did not record the created worktree"
  assert_grep "worktree_provider=but" "$home/state/$id.meta" \
    "but spawn did not record worktree_provider=but"
  owner_token=$(sed -n 's/^worktree_owner_token=//p' "$home/state/$id.meta")
  case "$owner_token" in
    fmw.????????????) : ;;
    *) fail "but spawn did not record a valid ownership token" ;;
  esac
  assert_grep "task_id=$id" "$wt/.fm-worktree-owner" \
    "but spawn did not mark the worktree with its task id"
  assert_grep "token=$owner_token" "$wt/.fm-worktree-owner" \
    "but spawn marker token does not match metadata"
  grep -F 'treehouse get' "$log" >/dev/null \
    && fail "but spawn sent treehouse get"
  grep -F "cd '$wt'" "$log" >/dev/null \
    || fail "but spawn did not cd the pane into the created worktree"
  pass "but spawn creates a git worktree, marks ownership, and skips treehouse get"
}

test_spawn_treehouse_still_types_get() {
  local rec home proj id fakebin wt log out status
  id=th-spawn-b2
  rec=$(make_home spawn-th "$id")
  IFS='|' read -r home proj <<EOF
$rec
EOF
  wt="$TMP_ROOT/spawn-th/wt"
  fm_git_worktree "$proj" "$wt" "wt-$id"
  fakebin=$(make_spawn_fakebin "$TMP_ROOT/spawn-th/fake")
  log="$TMP_ROOT/spawn-th/tmux.log"
  out=$(
    FM_ROOT_OVERRIDE='' FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
      FM_SPAWN_NO_GUARD=1 TMUX="fake,1,0" \
      FM_WORKTREE_PROVIDER=treehouse \
      FM_FAKE_PANE_PATH="$wt" FM_TMUX_LOG="$log" \
      PATH="$fakebin:$PATH" \
      "$SPAWN" "$id" "$proj" --mode no-mistakes --yolo off 2>&1
  )
  status=$?
  expect_code 0 "$status" "treehouse spawn should succeed"
  assert_grep "worktree=$wt" "$home/state/$id.meta" \
    "treehouse spawn did not record the settled worktree"
  assert_no_grep "worktree_provider=but" "$home/state/$id.meta" \
    "treehouse spawn recorded a but provider"
  grep -F 'treehouse get' "$log" >/dev/null \
    || fail "treehouse spawn did not send treehouse get"
  pass "treehouse spawn still types treehouse get and omits worktree_provider"
}

test_spawn_but_closes_endpoint_when_add_fails() {
  local rec home proj id fakebin wt log out status
  id=but-add-failure-b3
  rec=$(make_home spawn-but-add-failure "$id")
  IFS='|' read -r home proj <<EOF
$rec
EOF
  wt="$TMP_ROOT/but-add-failure-wts/$id"
  fakebin=$(make_spawn_fakebin "$TMP_ROOT/spawn-but-add-failure/fake")
  log="$TMP_ROOT/spawn-but-add-failure/tmux.log"
  mkdir -p "$wt"
  out=$(
    FM_ROOT_OVERRIDE='' FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
      FM_SPAWN_NO_GUARD=1 TMUX="fake,1,0" \
      FM_WORKTREE_PROVIDER=but FM_BUT_WORKTREE_ROOT="$TMP_ROOT/but-add-failure-wts" \
      FM_FAKE_PANE_PATH="$proj" FM_TMUX_LOG="$log" \
      PATH="$fakebin:$PATH" \
      "$SPAWN" "$id" "$proj" --mode no-mistakes --yolo off 2>&1
  )
  status=$?
  [ "$status" -ne 0 ] || fail "existing but worktree path should fail spawn"
  assert_contains "$out" "GitButler worktree path already exists" \
    "but add failure was not reported"
  assert_present "$wt" "but add failure removed the pre-existing path"
  assert_absent "$home/state/$id.meta" "but add failure retained endpoint metadata"
  assert_grep "kill-window" "$log" "but add failure left the backend endpoint alive"
  pass "but add failures close their already-created backend endpoint"
}

test_spawn_but_preserves_recovery_when_remove_fails() {
  local rec home proj id fakebin wt wt_real log out status tasktmp owner_token real_git wt_status
  id=but-abort-recovery-c3
  rec=$(make_home spawn-but-abort "$id")
  IFS='|' read -r home proj <<EOF
$rec
EOF
  wt="$TMP_ROOT/but-abort-wts/$id"
  fakebin=$(make_spawn_fakebin "$TMP_ROOT/spawn-but-abort/fake")
  log="$TMP_ROOT/spawn-but-abort/tmux.log"
  real_git=$(command -v git)
  cat > "$fakebin/git" <<'SH'
#!/usr/bin/env bash
if [ "${FM_FAKE_GIT_REMOVE_FAIL:-0}" = 1 ] \
   && [ "${1:-}" = -C ] && [ "${3:-}" = worktree ] && [ "${4:-}" = remove ]; then
  echo "fatal: simulated registered worktree removal failure" >&2
  exit 1
fi
exec "${FM_REAL_GIT:?}" "$@"
SH
  chmod +x "$fakebin/git"
  tasktmp="/tmp/fm-$id"
  [ ! -e "$tasktmp" ] || fail "abort recovery tasktmp fixture already exists: $tasktmp"
  printf 'fixture\n' > "$tasktmp"
  out=$(
    FM_ROOT_OVERRIDE='' FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
      FM_SPAWN_NO_GUARD=1 TMUX="fake,1,0" \
      FM_WORKTREE_PROVIDER=but FM_BUT_WORKTREE_ROOT="$TMP_ROOT/but-abort-wts" \
      FM_FAKE_PANE_PATH="$wt" FM_TMUX_LOG="$log" \
      FM_FAKE_GIT_REMOVE_FAIL=1 FM_REAL_GIT="$real_git" \
      PATH="$fakebin:$PATH" \
      "$SPAWN" "$id" "$proj" --mode no-mistakes --yolo off 2>&1
  )
  status=$?
  rm -f "$tasktmp"
  [ "$status" -ne 0 ] || fail "but spawn abort fixture should fail after worktree creation"
  assert_contains "$out" "git worktree remove failed for $wt" \
    "but abort cleanup did not report the failed worktree removal"
  assert_contains "$out" "recovery metadata preserved at $home/state/$id.meta" \
    "but abort cleanup did not report durable recovery metadata"
  assert_present "$home/state/$id.meta" "but abort cleanup did not preserve task metadata"
  assert_grep "endpoint_task_id=$id" "$home/state/$id.meta" \
    "but abort recovery metadata lacks the task binding"
  assert_grep "worktree=$wt" "$home/state/$id.meta" \
    "but abort recovery metadata lacks the worktree"
  assert_grep "worktree_provider=but" "$home/state/$id.meta" \
    "but abort recovery metadata lacks the provider"
  owner_token=$(sed -n 's/^worktree_owner_token=//p' "$home/state/$id.meta")
  assert_grep "token=$owner_token" "$wt/.fm-worktree-owner" \
    "but abort recovery metadata lost the ownership proof"
  wt_status=$(git -C "$wt" status --porcelain --untracked-files=all)
  assert_not_contains "$wt_status" ".fm-worktree-owner" \
    "but abort recovery left the ownership marker unignored"
  wt_real=$(cd "$wt" && pwd -P)
  git -C "$proj" worktree list --porcelain | grep -F "worktree $wt_real" >/dev/null \
    || fail "but abort fixture did not retain the registered worktree"
  git -C "$proj" worktree remove --force "$wt"
  pass "but spawn abort reports cleanup failure and preserves recovery metadata"
}

test_spawn_but_preserves_endpoint_recovery_after_remove() {
  local rec home proj id fakebin wt log out status tasktmp teardown_out
  id=but-abort-endpoint-c4
  rec=$(make_home spawn-but-endpoint-abort "$id")
  IFS='|' read -r home proj <<EOF
$rec
EOF
  wt="$TMP_ROOT/but-endpoint-abort-wts/$id"
  fakebin=$(make_spawn_fakebin "$TMP_ROOT/spawn-but-endpoint-abort/fake")
  log="$TMP_ROOT/spawn-but-endpoint-abort/tmux.log"
  tasktmp="/tmp/fm-$id"
  [ ! -e "$tasktmp" ] || fail "endpoint recovery tasktmp fixture already exists: $tasktmp"
  printf 'fixture\n' > "$tasktmp"
  out=$(
    FM_ROOT_OVERRIDE='' FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
      FM_SPAWN_NO_GUARD=1 TMUX="fake,1,0" \
      FM_WORKTREE_PROVIDER=but FM_BUT_WORKTREE_ROOT="$TMP_ROOT/but-endpoint-abort-wts" \
      FM_FAKE_PANE_PATH="$wt" FM_TMUX_LOG="$log" \
      PATH="$fakebin:$PATH" \
      "$SPAWN" "$id" "$proj" --mode no-mistakes --yolo off 2>&1
  )
  status=$?
  rm -f "$tasktmp"
  [ "$status" -ne 0 ] || fail "endpoint recovery spawn fixture should fail after worktree creation"
  assert_contains "$out" "endpoint recovery metadata preserved at $home/state/$id.meta" \
    "successful abort worktree removal did not retain endpoint recovery metadata"
  assert_present "$home/state/$id.meta" \
    "successful abort worktree removal lost endpoint recovery metadata"
  assert_absent "$wt" "successful abort cleanup left the worktree path"
  git -C "$proj" worktree list --porcelain | grep -F "worktree $wt" >/dev/null \
    && fail "successful abort cleanup left the worktree registered"
  teardown_out=$(
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_CONFIG_OVERRIDE="$home/config" FM_TEARDOWN_GUARD_DONE=1 \
      FM_TMUX_LOG="$log" PATH="$fakebin:$PATH" \
      "$TEARDOWN" "$id" --force 2>&1
  )
  status=$?
  expect_code 0 "$status" "endpoint recovery metadata should support teardown"
  assert_contains "$teardown_out" "teardown $id complete" \
    "endpoint recovery teardown did not complete"
  assert_absent "$home/state/$id.meta" "endpoint recovery teardown retained task metadata"
  assert_grep "kill-window" "$log" "endpoint recovery teardown did not close the backend endpoint"
  pass "but spawn abort retains teardown-capable endpoint recovery metadata"
}

test_teardown_but_removes_git_worktree() {
  local home proj wt called
  home="$TMP_ROOT/td-but/home"
  proj="$TMP_ROOT/td-but/project"
  wt="$TMP_ROOT/td-but/wt"
  mkdir -p "$home/data" "$home/state" "$home/config" "$home/fakebin"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
  git -C "$proj" branch fm/task-x1 main
  git -C "$proj" worktree add --quiet --detach "$wt" main
  printf 'version=1\ntask_id=%s\ntoken=%s\n' task-x1 fmw.AAAAAAAAAAAA > "$wt/.fm-worktree-owner"
  fm_write_meta "$home/state/task-x1.meta" \
    "window=firstmate:fm-task-x1" \
    "endpoint_task_id=task-x1" \
    "worktree=$wt" \
    "project=$proj" \
    "kind=ship" \
    "mode=local-only" \
    "worktree_provider=but" \
    "worktree_owner_token=fmw.AAAAAAAAAAAA"
  cat > "$home/fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
: > "${FM_TREEHOUSE_CALLED:?}"
exit 0
SH
  cat > "$home/fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$home/fakebin/treehouse" "$home/fakebin/tmux"
  called="$TMP_ROOT/td-but/treehouse-called"
  FM_TREEHOUSE_CALLED="$called" \
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_CONFIG_OVERRIDE="$home/config" \
    PATH="$home/fakebin:$PATH" \
    "$TEARDOWN" task-x1 --force >/dev/null
  assert_absent "$wt" "but teardown left the git worktree"
  git -C "$proj" worktree list | grep -F "$wt" >/dev/null \
    && fail "but teardown left a registered git worktree"
  git -C "$proj" show-ref --verify --quiet refs/heads/fm/task-x1 \
    || fail "detached but teardown deleted an unowned same-id branch"
  assert_absent "$called" "but teardown called treehouse return"
  pass "but teardown removes detached worktrees without deleting unowned branches"
}

test_teardown_but_missing_path_preserves_registration_recovery() {
  local home proj wt fakebin log out status real_git remove_log
  home="$TMP_ROOT/td-missing/home"
  proj="$TMP_ROOT/td-missing/project"
  wt="$TMP_ROOT/td-missing/wt"
  fakebin="$TMP_ROOT/td-missing/fakebin"
  log="$TMP_ROOT/td-missing/tmux.log"
  remove_log="$TMP_ROOT/td-missing/remove.log"
  mkdir -p "$home/data" "$home/state" "$home/config" "$fakebin"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
  git -C "$proj" worktree add --quiet --detach "$wt" main
  printf 'version=1\ntask_id=%s\ntoken=%s\n' task-missing-c5 fmw.EEEEEEEEEEEE > "$wt/.fm-worktree-owner"
  fm_write_meta "$home/state/task-missing-c5.meta" \
    "window=firstmate:fm-task-missing-c5" \
    "endpoint_task_id=task-missing-c5" \
    "worktree=$wt" \
    "project=$proj" \
    "kind=ship" \
    "mode=local-only" \
    "worktree_provider=but" \
    "worktree_owner_token=fmw.EEEEEEEEEEEE"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FM_TMUX_LOG:?}"
exit 0
SH
  real_git=$(command -v git)
  cat > "$fakebin/git" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = -C ] && [ "${3:-}" = worktree ] && [ "${4:-}" = remove ]; then
  printf '%s\n' "$*" >> "${FM_GIT_REMOVE_LOG:?}"
  echo "fatal: simulated stale worktree registration removal failure" >&2
  exit 1
fi
exec "${FM_REAL_GIT:?}" "$@"
SH
  chmod +x "$fakebin/tmux" "$fakebin/git"
  rm -rf "$wt"
  set +e
  out=$(
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_CONFIG_OVERRIDE="$home/config" FM_TEARDOWN_GUARD_DONE=1 \
      FM_TMUX_LOG="$log" FM_GIT_REMOVE_LOG="$remove_log" FM_REAL_GIT="$real_git" \
      PATH="$fakebin:$PATH" \
      "$TEARDOWN" task-missing-c5 --force 2>&1
  )
  status=$?
  set -e
  expect_code 1 "$status" "registered missing but path should refuse when exact removal fails"
  assert_present "$remove_log" "missing but path cleanup did not attempt exact registration removal"
  assert_present "$home/state/task-missing-c5.meta" \
    "missing but path refusal dropped recovery metadata"
  assert_contains "$out" "preserving metadata" \
    "missing but path refusal did not report retained recovery metadata"
  [ ! -e "$log" ] || [ ! -s "$log" ] \
    || fail "missing but path refusal closed the endpoint before registration cleanup"
  pass "missing but paths preserve recovery when exact registration removal fails"
}

test_teardown_but_still_requires_owner() {
  local home proj wt called rc
  home="$TMP_ROOT/td-own/home"
  proj="$TMP_ROOT/td-own/project"
  wt="$TMP_ROOT/td-own/wt"
  mkdir -p "$home/data" "$home/state" "$home/config" "$home/fakebin"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
  git -C "$proj" worktree add --quiet --detach "$wt" main
  printf 'version=1\ntask_id=%s\ntoken=%s\n' other-task fmw.BBBBBBBBBBBB > "$wt/.fm-worktree-owner"
  fm_write_meta "$home/state/task-x1.meta" \
    "window=firstmate:fm-task-x1" \
    "endpoint_task_id=task-x1" \
    "worktree=$wt" \
    "project=$proj" \
    "kind=ship" \
    "mode=local-only" \
    "worktree_provider=but" \
    "worktree_owner_token=fmw.AAAAAAAAAAAA"
  cat > "$home/fakebin/treehouse" <<'SH'
#!/usr/bin/env bash
: > "${FM_TREEHOUSE_CALLED:?}"
exit 0
SH
  cat > "$home/fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  chmod +x "$home/fakebin/treehouse" "$home/fakebin/tmux"
  called="$TMP_ROOT/td-own/treehouse-called"
  set +e
  FM_TREEHOUSE_CALLED="$called" \
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_CONFIG_OVERRIDE="$home/config" \
    PATH="$home/fakebin:$PATH" \
    "$TEARDOWN" task-x1 --force >/dev/null 2>"$TMP_ROOT/td-own/stderr"
  rc=$?
  set -e
  expect_code 1 "$rc" "mismatched but owner must refuse"
  assert_present "$wt" "ownership refusal removed the but worktree"
  assert_absent "$called" "ownership refusal called treehouse return"
  pass "but teardown still refuses a mismatched ownership marker"
}

test_teardown_but_rechecks_before_branch_mutation() {
  local home proj wt fakebin id out status real_git count_file exclude_file
  id=but-safety-race-c6
  home="$TMP_ROOT/td-race/home"
  proj="$TMP_ROOT/td-race/project"
  wt="$TMP_ROOT/td-race/wt"
  fakebin="$TMP_ROOT/td-race/fakebin"
  count_file="$TMP_ROOT/td-race/status-count"
  mkdir -p "$home/data" "$home/state" "$home/config" "$fakebin"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
  git -C "$proj" worktree add --quiet -b "fm/$id" "$wt" main
  printf 'version=1\ntask_id=%s\ntoken=%s\n' "$id" fmw.FFFFFFFFFFFF > "$wt/.fm-worktree-owner"
  exclude_file=$(git -C "$wt" rev-parse --git-path info/exclude)
  case "$exclude_file" in
    /*) ;;
    *) exclude_file="$wt/$exclude_file" ;;
  esac
  printf '%s\n' .fm-worktree-owner >> "$exclude_file"
  fm_write_meta "$home/state/$id.meta" \
    "window=firstmate:fm-$id" \
    "endpoint_task_id=$id" \
    "worktree=$wt" \
    "project=$proj" \
    "kind=ship" \
    "mode=local-only" \
    "worktree_provider=but" \
    "worktree_owner_token=fmw.FFFFFFFFFFFF"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
exit 0
SH
  fm_fake_exit0 "$fakebin" no-mistakes
  real_git=$(command -v git)
  cat > "$fakebin/git" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = -C ] && [ "${2:-}" = "${FM_RACE_WORKTREE:?}" ] \
   && [ "${3:-}" = status ] && [ "${4:-}" = --porcelain ]; then
  count=$(cat "${FM_RACE_COUNT_FILE:?}" 2>/dev/null || printf '0')
  count=$((count + 1))
  printf '%s\n' "$count" > "$FM_RACE_COUNT_FILE"
  if [ "$count" -eq 2 ]; then
    printf 'late work\n' > "$FM_RACE_WORKTREE/race.txt"
  fi
fi
exec "${FM_REAL_GIT:?}" "$@"
SH
  chmod +x "$fakebin/tmux" "$fakebin/git"
  set +e
  out=$(
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_CONFIG_OVERRIDE="$home/config" FM_TEARDOWN_GUARD_DONE=1 \
      FM_RACE_WORKTREE="$wt" FM_RACE_COUNT_FILE="$count_file" FM_REAL_GIT="$real_git" \
      PATH="$fakebin:$PATH" \
      "$TEARDOWN" "$id" 2>&1
  )
  status=$?
  set -e
  expect_code 1 "$status" "late work should fail the final but safety check"
  assert_contains "$out" "GitButler worktree safety check failed" \
    "late work did not trigger the final but safety refusal"
  assert_present "$wt" "late-work refusal removed the but worktree"
  assert_present "$home/state/$id.meta" "late-work refusal removed task metadata"
  [ "$(git -C "$wt" symbolic-ref --quiet --short HEAD)" = "fm/$id" ] \
    || fail "late-work refusal detached the task branch"
  git -C "$proj" show-ref --verify --quiet "refs/heads/fm/$id" \
    || fail "late-work refusal deleted the task branch"
  pass "but safety rechecks before detaching or deleting the task branch"
}

test_forced_secondmate_but_child_runs_full_cleanup() {
  local home subhome proj wt fakebin parent_id child_id pid out status head nm_log
  parent_id=but-parent-d4
  child_id=but-child-d4
  home="$TMP_ROOT/child-but/home"
  subhome="$TMP_ROOT/child-but/secondmate"
  proj="$TMP_ROOT/child-but/project"
  wt="$TMP_ROOT/child-but/worktree"
  fakebin="$TMP_ROOT/child-but/fakebin"
  mkdir -p "$home/state" "$home/data" "$home/config" \
    "$subhome/state" "$subhome/data" "$subhome/config" "$subhome/projects" "$fakebin"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
  git -C "$proj" worktree add --quiet -b "fm/$child_id" "$wt" main
  printf '%s\n' "$parent_id" > "$subhome/.fm-secondmate-home"
  printf 'version=1\ntask_id=%s\ntoken=%s\n' "$child_id" fmw.CCCCCCCCCCCC \
    > "$wt/.fm-worktree-owner"
  fm_write_meta "$home/state/$parent_id.meta" \
    "window=firstmate:fm-$parent_id" \
    "endpoint_task_id=$parent_id" \
    "worktree=$subhome" \
    "project=$subhome" \
    "kind=secondmate" \
    "mode=secondmate" \
    "home=$subhome"
  printf -- '- %s - synthetic (home: %s; scope: cleanup; projects: ; added 2026-08-26)\n' \
    "$parent_id" "$subhome" > "$home/data/secondmates.md"
  fm_write_meta "$subhome/state/$child_id.meta" \
    "window=firstmate:fm-$child_id" \
    "endpoint_task_id=$child_id" \
    "worktree=$wt" \
    "project=$proj" \
    "harness=codex" \
    "kind=ship" \
    "mode=local-only" \
    "worktree_provider=but" \
    "worktree_owner_token=fmw.CCCCCCCCCCCC"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = display-message ] && [ "${*: -1}" = '#{pane_pid}' ]; then
  printf '%s\n' "${FM_FAKE_PANE_PID:-}"
fi
exit 0
SH
  cat > "$fakebin/no-mistakes" <<'SH'
#!/usr/bin/env bash
case "${1:-} ${2:-}" in
  "axi status")
    if [ -s "${FM_FAKE_NM_ABORT_LOG:?}" ]; then
      printf 'run:\n  id: "01CHILD"\n  outcome: cancelled\n'
    else
      printf 'run:\n  id: "01CHILD"\n  branch: %s\n  status: awaiting_approval\n  awaiting_agent: parked 2m\n  head: "%s"\n  pr: ""\n  findings: none\ngate: review\n' \
        "${FM_FAKE_NM_BRANCH:?}" "${FM_FAKE_NM_HEAD:?}"
    fi
    ;;
  "axi abort")
    shift 2
    printf 'abort %s\n' "$*" >> "${FM_FAKE_NM_ABORT_LOG:?}"
    ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux" "$fakebin/no-mistakes"
  head=$(git -C "$wt" rev-parse HEAD)
  nm_log="$TMP_ROOT/child-but/no-mistakes-abort.log"
  perl -e 'setpgrp(0, 0); chdir shift or die; exec "sleep", "300"' "$wt" &
  pid=$!
  disown
  sleep 0.3
  kill -0 "$pid" 2>/dev/null || fail "but child cleanup sleeper did not start"
  out=$(
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_CONFIG_OVERRIDE="$home/config" FM_TEARDOWN_GUARD_DONE=1 \
      FM_FAKE_PANE_PID="$pid" FM_FAKE_NM_BRANCH="fm/$child_id" \
      FM_FAKE_NM_HEAD="$head" FM_FAKE_NM_ABORT_LOG="$nm_log" \
      PATH="$fakebin:$PATH" \
      "$TEARDOWN" "$parent_id" --force 2>&1
  )
  status=$?
  expect_code 0 "$status" "forced secondmate teardown should clean a But child"
  if kill -0 "$pid" 2>/dev/null; then
    kill -KILL "$pid" 2>/dev/null || true
    fail "forced secondmate teardown left a But child process alive"
  fi
  assert_contains "$out" "reaping leaked worktree process" \
    "forced secondmate teardown did not run the ordinary process reap"
  assert_grep "abort --run 01CHILD" "$nm_log" \
    "forced secondmate teardown orphaned the child's parked no-mistakes run"
  assert_contains "$out" "no-mistakes run for $child_id is parked at a gate" \
    "forced secondmate teardown did not run the child-scoped parked-run cleanup"
  assert_absent "$wt" "forced secondmate teardown left the But child worktree"
  git -C "$proj" worktree list | grep -F "$wt" >/dev/null \
    && fail "forced secondmate teardown left the But child registered"
  git -C "$proj" show-ref --verify --quiet "refs/heads/fm/$child_id" \
    && fail "forced secondmate teardown left the But child task branch"
  pass "forced secondmate teardown reaps and removes a But child lifecycle"
}

test_forced_secondmate_refuses_unknown_child_provider_before_cleanup() {
  local home subhome proj wt fakebin parent_id child_id out status
  parent_id=unknown-parent-e5
  child_id=unknown-child-e5
  home="$TMP_ROOT/child-unknown/home"
  subhome="$TMP_ROOT/child-unknown/secondmate"
  proj="$TMP_ROOT/child-unknown/project"
  wt="$TMP_ROOT/child-unknown/worktree"
  fakebin="$TMP_ROOT/child-unknown/fakebin"
  mkdir -p "$home/state" "$home/data" "$home/config" \
    "$subhome/state" "$subhome/data" "$subhome/config" "$subhome/projects" "$fakebin"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
  git -C "$proj" worktree add --quiet -b "fm/$child_id" "$wt" main
  printf '%s\n' "$parent_id" > "$subhome/.fm-secondmate-home"
  printf 'version=1\ntask_id=%s\ntoken=%s\n' "$child_id" fmw.DDDDDDDDDDDD \
    > "$wt/.fm-worktree-owner"
  fm_write_meta "$home/state/$parent_id.meta" \
    "window=firstmate:fm-$parent_id" \
    "endpoint_task_id=$parent_id" \
    "worktree=$subhome" \
    "project=$subhome" \
    "kind=secondmate" \
    "mode=secondmate" \
    "home=$subhome"
  printf -- '- %s - synthetic (home: %s; scope: cleanup; projects: ; added 2026-08-26)\n' \
    "$parent_id" "$subhome" > "$home/data/secondmates.md"
  fm_write_meta "$subhome/state/$child_id.meta" \
    "window=firstmate:fm-$child_id" \
    "endpoint_task_id=$child_id" \
    "worktree=$wt" \
    "project=$proj" \
    "kind=ship" \
    "mode=local-only" \
    "worktree_provider=future" \
    "worktree_owner_token=fmw.DDDDDDDDDDDD"
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "${FM_TMUX_LOG:?}"
exit 0
SH
  chmod +x "$fakebin/tmux"
  : > "$home/tmux.log"
  set +e
  out=$(
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_CONFIG_OVERRIDE="$home/config" FM_TEARDOWN_GUARD_DONE=1 \
      FM_TMUX_LOG="$home/tmux.log" PATH="$fakebin:$PATH" \
      "$TEARDOWN" "$parent_id" --force 2>&1
  )
  status=$?
  set -e
  expect_code 1 "$status" "unknown child worktree provider should refuse"
  assert_contains "$out" "invalid worktree_provider metadata" \
    "unknown child provider refusal was not reported"
  assert_present "$wt" "unknown child provider refusal removed the worktree"
  assert_present "$subhome/state/$child_id.meta" \
    "unknown child provider refusal removed child metadata"
  [ ! -s "$home/tmux.log" ] || fail "unknown child provider refusal killed an endpoint"
  pass "forced secondmate teardown refuses unknown providers before cleanup"
}

test_override_pins_provider
test_auto_detects_but_then_treehouse
test_required_tools_follow_provider
test_spawn_but_creates_git_worktree
test_spawn_treehouse_still_types_get
test_spawn_but_closes_endpoint_when_add_fails
test_spawn_but_preserves_recovery_when_remove_fails
test_spawn_but_preserves_endpoint_recovery_after_remove
test_teardown_but_removes_git_worktree
test_teardown_but_missing_path_preserves_registration_recovery
test_teardown_but_still_requires_owner
test_teardown_but_rechecks_before_branch_mutation
test_forced_secondmate_but_child_runs_full_cleanup
test_forced_secondmate_refuses_unknown_child_provider_before_cleanup

echo "# all fm-worktree-provider tests passed"
