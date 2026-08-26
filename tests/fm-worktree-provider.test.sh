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

test_spawn_but_preserves_recovery_when_remove_fails() {
  local rec home proj id fakebin wt wt_real log out status tasktmp owner_token real_git
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
  wt_real=$(cd "$wt" && pwd -P)
  git -C "$proj" worktree list --porcelain | grep -F "worktree $wt_real" >/dev/null \
    || fail "but abort fixture did not retain the registered worktree"
  git -C "$proj" worktree remove --force "$wt"
  pass "but spawn abort reports cleanup failure and preserves recovery metadata"
}

test_teardown_but_removes_git_worktree() {
  local home proj wt called
  home="$TMP_ROOT/td-but/home"
  proj="$TMP_ROOT/td-but/project"
  wt="$TMP_ROOT/td-but/wt"
  mkdir -p "$home/data" "$home/state" "$home/config" "$home/fakebin"
  fm_git_init_commit "$proj"
  git -C "$proj" branch -M main
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
  assert_absent "$called" "but teardown called treehouse return"
  pass "but teardown removes the git worktree and does not call treehouse"
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

test_forced_secondmate_but_child_runs_full_cleanup() {
  local home subhome proj wt fakebin parent_id child_id pid out status
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
  chmod +x "$fakebin/tmux"
  perl -e 'setpgrp(0, 0); chdir shift or die; exec "sleep", "300"' "$wt" &
  pid=$!
  disown
  sleep 0.3
  kill -0 "$pid" 2>/dev/null || fail "but child cleanup sleeper did not start"
  out=$(
    FM_ROOT_OVERRIDE="$ROOT" FM_HOME="$home" \
      FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
      FM_CONFIG_OVERRIDE="$home/config" FM_TEARDOWN_GUARD_DONE=1 \
      FM_FAKE_PANE_PID="$pid" PATH="$fakebin:$PATH" \
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
test_spawn_but_preserves_recovery_when_remove_fails
test_teardown_but_removes_git_worktree
test_teardown_but_still_requires_owner
test_forced_secondmate_but_child_runs_full_cleanup
test_forced_secondmate_refuses_unknown_child_provider_before_cleanup

echo "# all fm-worktree-provider tests passed"
