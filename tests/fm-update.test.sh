#!/usr/bin/env bash
# Tests for bin/fm-update.sh: bring Kun into a running Themis firstmate without
# destroying unique Themis commits, then fast-forward registered secondmate homes.
#
# Guarantees under test:
#   - From a clean Themis checkout, fetch upstream, fast-forward local master to
#     upstream/main without checking master out, optionally push origin/master,
#     and merge master into Themis (fast-forward only when Themis is already an
#     ancestor of master).
#   - Unique Themis commits survive a successful merge.
#   - Merge conflicts abort, report conflicted paths, and leave Themis untouched.
#   - HEAD is never switched to master.
#   - A dirty, diverged, offline, or non-Themis running checkout is skipped and
#     reported, never forced or stashed.
#   - An unsafe origin/master push is skipped and does not block the Themis merge.
#   - Secondmate homes stay on the origin fast-forward path.
#   - reread-firstmate flips to yes only when the instruction surface changed,
#     and nudge-secondmates lists exactly the live secondmates that advanced.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

UPDATE="$ROOT/bin/fm-update.sh"

fm_git_identity fmtest fmtest@example.com

TMP_ROOT=$(fm_test_tmproot fm-update-tests)

# Build a world with Kun (upstream/main), a GitHub mirror (origin/master), and a
# Themis checkout. unique=yes (default) adds a Themis-only file so later Kun
# merges stay two-parent. Echoes the world dir.
new_world() {
  local name=$1 unique=${2:-yes} w
  w="$TMP_ROOT/$name"
  mkdir -p "$w/home/state" "$w/home/data"
  touch "$w/home/state/.last-watcher-beat"

  git init -q --bare "$w/kun.git"
  git -C "$w/kun.git" symbolic-ref HEAD refs/heads/main
  git clone -q "$w/kun.git" "$w/seed" 2>/dev/null

  printf 'v1\n' > "$w/seed/AGENTS.md"
  printf 'r1\n' > "$w/seed/README.md"
  mkdir -p "$w/seed/bin" "$w/seed/.agents/skills"
  printf 'echo a\n' > "$w/seed/bin/tool.sh"
  printf 's1\n' > "$w/seed/.agents/skills/note.md"
  git -C "$w/seed" add -A
  git -C "$w/seed" commit -qm c1
  git -C "$w/seed" push -q origin main

  git init -q --bare "$w/origin.git"
  git -C "$w/origin.git" symbolic-ref HEAD refs/heads/master
  git -C "$w/seed" push -q "$w/origin.git" main:master

  git clone -q "$w/origin.git" "$w/main"
  git -C "$w/main" remote set-head origin master >/dev/null 2>&1 || true
  git -C "$w/main" remote add upstream "$w/kun.git"
  git -C "$w/main" fetch -q upstream
  git -C "$w/main" checkout -q -B Themis
  if [ "$unique" = yes ]; then
    printf 'themis-custom\n' > "$w/main/THEMIS.md"
    git -C "$w/main" add THEMIS.md
    git -C "$w/main" commit -qm themis-custom
  fi

  printf '%s\n' "$w"
}

# Add a secondmate home as a DETACHED worktree of the firstmate repo on master
# (the GitHub default mirror), plus its state meta. Args: world id.
add_sm() {
  local w=$1 id=$2
  git -C "$w/main" worktree add -q --detach "$w/$id" master
  {
    printf 'window=main:fm-%s\n' "$id"
    printf 'kind=secondmate\n'
    printf 'home=%s/%s\n' "$w" "$id"
  } > "$w/home/state/$id.meta"
  printf '%s\n' "$id" > "$w/$id/.fm-secondmate-home"
}

# Advance Kun by one commit. mode=instr changes the instruction surface
# (AGENTS.md, bin, .agents/skills) plus README; mode=readme changes only README.
bump_kun() {
  local w=$1 mode=$2
  git -C "$w/seed" pull -q origin main >/dev/null 2>&1 || true
  printf 'r-%s\n' "$mode" >> "$w/seed/README.md"
  if [ "$mode" = instr ]; then
    printf 'v2\n' > "$w/seed/AGENTS.md"
    printf 'echo b\n' > "$w/seed/bin/tool.sh"
    printf 's2\n' > "$w/seed/.agents/skills/note.md"
  fi
  git -C "$w/seed" add -A
  git -C "$w/seed" commit -qm "bump-$mode"
  git -C "$w/seed" push -q origin main
}

run_update() {
  local w=$1
  FM_ROOT_OVERRIDE="$w/main" FM_HOME="$w/home" "$UPDATE" 2>/dev/null
}

head_branch() {
  git -C "$1" symbolic-ref --short HEAD 2>/dev/null || echo ""
}

assert_still_themis() {
  local dir=$1
  [ "$(head_branch "$dir")" = "Themis" ] || fail "running home left Themis (now $(head_branch "$dir" || echo detached))"
}

# --- T1: Themis unique + Kun instruction bump: merge, keep customizations ---
test_merges_kun_into_themis() {
  local w out themis_before
  w=$(new_world t1)
  add_sm "$w" sm1
  themis_before=$(git -C "$w/main" rev-parse HEAD)
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "master: updated " "local master fast-forwarded to Kun"
  assert_contains "$out" "origin/master: pushed " "GitHub master mirror pushed"
  assert_contains "$out" "firstmate: updated " "Themis merged master"
  assert_contains "$out" "secondmate sm1: updated " "secondmate fast-forwarded from origin"
  assert_contains "$out" "reread-firstmate: yes" "instruction change triggers reread"
  assert_contains "$out" "nudge-secondmates: fm-sm1" "updated secondmate is nudged"

  assert_still_themis "$w/main"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$(git -C "$w/main" rev-parse upstream/main)" ] \
    || fail "local master is not at upstream/main"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$(git -C "$w/main" rev-parse origin/master)" ] \
    || fail "origin/master is not at local master"
  git -C "$w/main" merge-base --is-ancestor "$themis_before" HEAD \
    || fail "Themis unique commit was not kept as a merge parent"
  grep -qx 'themis-custom' "$w/main/THEMIS.md" || fail "Themis customization was destroyed"
  grep -qx 'v2' "$w/main/AGENTS.md" || fail "Kun instruction change did not land on Themis"
  [ "$(git -C "$w/main" rev-list --parents -n1 HEAD | wc -w | tr -d ' ')" -eq 3 ] \
    || fail "Themis tip is not a merge commit"
  [ "$(git -C "$w/sm1" rev-parse HEAD)" = "$(git -C "$w/main" rev-parse origin/master)" ] \
    || fail "secondmate HEAD not at origin/master"
  git -C "$w/sm1" symbolic-ref -q HEAD >/dev/null \
    && fail "secondmate worktree is no longer detached"
  [ "$(git -C "$w/sm1" rev-list --parents -n1 HEAD | wc -w | tr -d ' ')" -eq 2 ] \
    || fail "secondmate tip is not a single-parent fast-forward"
  pass "T1 Themis merge keeps customizations, secondmate stays origin FF"
}

# --- T3: README-only Kun change does not trigger a reread -------------------
test_reread_gate_is_instruction_only() {
  local w out
  w=$(new_world t3)
  add_sm "$w" sm1
  bump_kun "$w" readme

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: updated " "Themis still merged Kun"
  assert_contains "$out" "reread-firstmate: no" "non-instruction change skips reread"
  assert_contains "$out" "nudge-secondmates: fm-sm1" "advanced secondmate still nudged"
  assert_still_themis "$w/main"
  pass "T3 reread gates on instruction surface, nudge on advancement"
}

# --- T4: dirty secondmate is skipped, its edit preserved --------------------
test_dirty_secondmate_skipped() {
  local w out
  w=$(new_world t4)
  add_sm "$w" sm1
  bump_kun "$w" instr
  printf 'uncommitted local edit\n' >> "$w/sm1/AGENTS.md"

  out=$(run_update "$w")

  assert_contains "$out" "secondmate sm1: skipped: dirty working tree" "dirty home skipped"
  assert_not_contains "$out" "fm-sm1" "skipped secondmate is not nudged"
  grep -q 'uncommitted local edit' "$w/sm1/AGENTS.md" \
    || fail "dirty edit was discarded"
  assert_still_themis "$w/main"
  pass "T4 dirty secondmate skipped, local edit preserved"
}

# --- T5: diverged secondmate is skipped, its commit preserved ---------------
test_diverged_secondmate_skipped() {
  local w out before
  w=$(new_world t5)
  add_sm "$w" sm1
  printf 'fork work\n' > "$w/sm1/AGENTS.md"
  git -C "$w/sm1" add -A
  git -C "$w/sm1" commit -qm local-work
  before=$(git -C "$w/sm1" rev-parse HEAD)
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "secondmate sm1: skipped: diverged from origin/master" "diverged home skipped"
  assert_not_contains "$out" "fm-sm1" "diverged secondmate is not nudged"
  [ "$(git -C "$w/sm1" rev-parse HEAD)" = "$before" ] \
    || fail "diverged secondmate HEAD moved (unlanded work at risk)"
  pass "T5 diverged secondmate skipped, local commit preserved"
}

# --- T6: idempotent; second run reports already current ---------------------
test_idempotent_already_current() {
  local w out
  w=$(new_world t6)
  add_sm "$w" sm1
  bump_kun "$w" instr
  run_update "$w" >/dev/null

  out=$(run_update "$w")

  assert_contains "$out" "master: already current" "master already current"
  assert_contains "$out" "origin/master: already current" "origin/master already current"
  assert_contains "$out" "firstmate: already current" "Themis already contains master"
  assert_contains "$out" "secondmate sm1: already current" "secondmate already current"
  assert_contains "$out" "reread-firstmate: no" "no reread when nothing changed"
  assert_contains "$out" "nudge-secondmates: none" "no nudge when nothing advanced"
  assert_still_themis "$w/main"
  pass "T6 idempotent: a second run is a no-op"
}

# --- T7: registry backstop + dedup + self-exclusion -------------------------
test_registry_backstop_dedup_and_self_exclusion() {
  local w out count nudge_line
  w=$(new_world t7)
  add_sm "$w" sm1
  git -C "$w/main" worktree add -q --detach "$w/reg1" master
  printf 'reg1\n' > "$w/reg1/.fm-secondmate-home"
  {
    printf '%s\n' "- reg1 - domain supervisor (home: $w/reg1; scope: things; projects: p; added 2026-06-23)"
    printf '%s\n' "- sm1 - dup (home: $w/sm1; scope: x; projects: p; added 2026-06-23)"
    printf '%s\n' "- selfish - self (home: $w/main; scope: x; projects: p; added 2026-06-23)"
  } > "$w/home/data/secondmates.md"
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "secondmate reg1: updated " "registry-only secondmate fast-forwarded"
  assert_contains "$out" "secondmate sm1: updated " "meta+registry secondmate fast-forwarded"
  count=$(printf '%s\n' "$out" | grep -c '^secondmate sm1:' || true)
  [ "$count" -eq 1 ] || fail "secondmate sm1 processed $count times, expected 1 (dedup across meta+registry)"
  assert_not_contains "$out" "secondmate selfish" "firstmate repo re-processed as its own secondmate"
  nudge_line=$(printf '%s\n' "$out" | grep '^nudge-secondmates:')
  assert_contains "$nudge_line" "fm-sm1" "live-meta secondmate is nudged"
  assert_not_contains "$nudge_line" "reg1" "registry-only secondmate without live metadata is not nudged"
  pass "T7 registry backstop resolves, dedups meta+registry, excludes the firstmate repo"
}

# --- T9: running home not on Themis skips the merge -------------------------
test_firstmate_wrong_branch_skipped() {
  local w out before
  w=$(new_world t9)
  bump_kun "$w" instr
  git -C "$w/main" checkout -q -b feature/wip
  before=$(git -C "$w/main" rev-parse HEAD)

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: skipped: on feature/wip, expected Themis" "off-Themis firstmate skipped"
  assert_contains "$out" "reread-firstmate: no" "no reread when firstmate was skipped"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] \
    || fail "skipped firstmate HEAD moved"
  [ "$(head_branch "$w/main")" = "feature/wip" ] || fail "skipped firstmate left its branch"
  pass "T9 firstmate off Themis is skipped, not merged into a random branch"
}

test_firstmate_detached_head_skipped() {
  local w out before
  w=$(new_world t10)
  bump_kun "$w" instr
  git -C "$w/main" checkout -q --detach HEAD
  before=$(git -C "$w/main" rev-parse HEAD)

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: skipped: detached HEAD, expected Themis" "detached firstmate skipped"
  assert_contains "$out" "reread-firstmate: no" "no reread when detached firstmate was skipped"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] \
    || fail "detached firstmate HEAD moved"
  pass "T10 firstmate detached HEAD is skipped"
}

test_unsafe_secondmate_home_skipped_before_git_update() {
  local w out bad before
  w=$(new_world t11)
  bad="$w/home/projects/bad"
  mkdir -p "$w/home/projects"
  git clone -q "$w/origin.git" "$bad"
  printf 'bad\n' > "$bad/.fm-secondmate-home"
  before=$(git -C "$bad" rev-parse HEAD)
  printf '%s\n' "- bad - bad home (home: $bad; scope: x; projects: p; added 2026-06-23)" \
    > "$w/home/data/secondmates.md"
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "secondmate bad: skipped: unsafe home: secondmate home cannot be inside the active firstmate home" \
    "unsafe project-like home skipped"
  assert_contains "$out" "nudge-secondmates: none" "unsafe home is not nudged"
  [ "$(git -C "$bad" rev-parse HEAD)" = "$before" ] \
    || fail "unsafe secondmate home HEAD moved"
  pass "T11 unsafe secondmate home is not fast-forwarded"
}

test_dirty_themis_skipped() {
  local w out before
  w=$(new_world t12)
  bump_kun "$w" instr
  printf 'uncommitted themis edit\n' >> "$w/main/THEMIS.md"
  before=$(git -C "$w/main" rev-parse HEAD)

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: skipped: dirty working tree" "dirty Themis skipped"
  assert_contains "$out" "reread-firstmate: no" "no reread when Themis was dirty"
  grep -q 'uncommitted themis edit' "$w/main/THEMIS.md" || fail "dirty Themis edit was discarded"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "dirty Themis HEAD moved"
  assert_still_themis "$w/main"
  pass "T12 dirty Themis skipped, local edit preserved"
}

test_missing_upstream_skipped() {
  local w out before
  w=$(new_world t13)
  git -C "$w/main" remote remove upstream
  before=$(git -C "$w/main" rev-parse HEAD)
  git -C "$w/seed" pull -q origin main >/dev/null 2>&1 || true
  printf 'r-instr\n' >> "$w/seed/README.md"
  printf 'v2\n' > "$w/seed/AGENTS.md"
  git -C "$w/seed" add -A
  git -C "$w/seed" commit -qm bump-offline
  git -C "$w/seed" push -q origin main

  out=$(run_update "$w")

  assert_contains "$out" "upstream: skipped: no upstream remote" "missing upstream is reported"
  assert_contains "$out" "master: skipped: upstream was not refreshed" "master is not trusted without upstream"
  assert_contains "$out" "origin/master: skipped: upstream was not refreshed" "mirror push is skipped without upstream"
  assert_contains "$out" "firstmate: skipped: upstream was not refreshed" "Themis does not use an unrefreshed mirror"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "Themis moved without upstream"
  grep -qx 'v1' "$w/main/AGENTS.md" || fail "Kun change landed without an upstream remote"
  assert_still_themis "$w/main"
  pass "T13 missing upstream is skipped and never invented"
}

test_diverged_master_skipped() {
  local w out master_before
  w=$(new_world t14)
  git -C "$w/main" worktree add -q "$w/master-wt" master
  printf 'local-master\n' > "$w/master-wt/MIRROR.md"
  git -C "$w/master-wt" add MIRROR.md
  git -C "$w/master-wt" commit -qm local-master
  master_before=$(git -C "$w/main" rev-parse refs/heads/master)
  git -C "$w/main" worktree remove "$w/master-wt"
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "master: skipped: diverged from upstream/main" "diverged master skipped"
  assert_contains "$out" "origin/master: skipped: local master is not at upstream/main" "diverged master is not pushed"
  assert_contains "$out" "firstmate: skipped: local master is not at upstream/main" "diverged master is not merged"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$master_before" ] \
    || fail "diverged master moved"
  grep -qx 'v1' "$w/main/AGENTS.md" || fail "Kun change landed through a diverged master"
  grep -qx 'themis-custom' "$w/main/THEMIS.md" || fail "Themis customization was destroyed"
  assert_still_themis "$w/main"
  [ "$(git -C "$w/main" rev-parse HEAD)" != "$master_before" ] || fail "running home checked out master"
  pass "T14 diverged master is skipped and Kun does not land"
}

test_failed_upstream_fetch_does_not_use_stale_ref() {
  local w out before master_before
  w=$(new_world t14-fetch)
  bump_kun "$w" instr
  git -C "$w/main" fetch -q upstream
  git -C "$w/main" remote set-url upstream "$w/missing-upstream.git"
  before=$(git -C "$w/main" rev-parse HEAD)
  master_before=$(git -C "$w/main" rev-parse refs/heads/master)

  out=$(run_update "$w")

  assert_contains "$out" "upstream: skipped: fetch failed" "failed upstream fetch is reported"
  assert_contains "$out" "master: skipped: upstream was not refreshed" "stale upstream ref is not trusted"
  assert_contains "$out" "firstmate: skipped: upstream was not refreshed" "stale upstream ref is not merged"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$master_before" ] \
    || fail "master advanced from a stale upstream ref"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "Themis moved after an upstream fetch failure"
  grep -qx 'v1' "$w/main/AGENTS.md" || fail "stale Kun instructions landed after a fetch failure"
  assert_still_themis "$w/main"
  pass "T14 failed upstream fetch does not trust its stale tracking ref"
}

test_dirty_master_skips_themis_merge() {
  local w out before master_before
  w=$(new_world t14-dirty)
  git -C "$w/main" worktree add -q "$w/master-wt" master
  printf 'uncommitted mirror edit\n' >> "$w/master-wt/README.md"
  before=$(git -C "$w/main" rev-parse HEAD)
  master_before=$(git -C "$w/main" rev-parse refs/heads/master)
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "master: skipped: dirty working tree" "dirty master skipped"
  assert_contains "$out" "firstmate: skipped: local master is not at upstream/main" "dirty master is not merged"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$master_before" ] || fail "dirty master moved"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "Themis moved after dirty master was skipped"
  grep -q 'uncommitted mirror edit' "$w/master-wt/README.md" || fail "dirty master edit was discarded"
  assert_still_themis "$w/main"
  pass "T14 dirty master is skipped before Themis merge"
}

test_remote_controller_updates_origin_only_root() {
  local w origin seed code home out
  w="$TMP_ROOT/remote-controller"
  origin="$w/origin.git"
  seed="$w/seed"
  code="$w/code"
  home="$w/home"
  mkdir -p "$w"
  git init -q --bare "$origin"
  git -C "$origin" symbolic-ref HEAD refs/heads/main
  git clone -q "$origin" "$seed" 2>/dev/null
  printf 'v1\n' > "$seed/AGENTS.md"
  mkdir -p "$seed/bin"
  printf 'echo v1\n' > "$seed/bin/tool.sh"
  git -C "$seed" add -A
  git -C "$seed" commit -qm initial
  git -C "$seed" push -q origin main
  git clone -q "$origin" "$code"
  git clone -q "$origin" "$home"
  git -C "$home" checkout -q --detach HEAD
  printf 'remote\n' > "$home/.fm-secondmate-home"
  printf 'v2\n' > "$seed/AGENTS.md"
  git -C "$seed" add AGENTS.md
  git -C "$seed" commit -qm update
  git -C "$seed" push -q origin main

  out=$(FM_ROOT_OVERRIDE="$code" FM_HOME="$home" \
    "$ROOT/bin/fm-remote-secondmate-control.sh" update remote)

  assert_contains "$out" "synced: " "remote controller reports the persistent-home fast-forward"
  [ "$(git -C "$code" rev-parse HEAD)" = "$(git -C "$code" rev-parse origin/main)" ] \
    || fail "remote code root did not fast-forward from origin"
  [ "$(head_branch "$code")" = main ] || fail "remote code root left its main branch"
  [ "$(git -C "$home" rev-parse HEAD)" = "$(git -C "$code" rev-parse HEAD)" ] \
    || fail "remote persistent home did not follow its code root"
  grep -qx 'v2' "$home/AGENTS.md" || fail "remote persistent home did not receive the origin update"
  pass "T14 remote controller keeps its origin-only update path"
}

test_unsafe_origin_push_does_not_block_themis() {
  local w out extra
  w=$(new_world t15)
  extra="$w/origin-extra"
  git clone -q "$w/origin.git" "$extra"
  printf 'origin-only\n' > "$extra/ORIGIN.md"
  git -C "$extra" add ORIGIN.md
  git -C "$extra" commit -qm origin-only
  git -C "$extra" push -q origin master
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "master: updated " "local master still fast-forwarded"
  assert_contains "$out" "origin/master: skipped: not a fast-forward" "unsafe mirror push skipped"
  assert_contains "$out" "firstmate: updated " "Themis merge still ran"
  grep -qx 'themis-custom' "$w/main/THEMIS.md" || fail "Themis customization was destroyed after skipped push"
  grep -qx 'v2' "$w/main/AGENTS.md" || fail "Kun change did not land after skipped push"
  assert_still_themis "$w/main"
  pass "T15 unsafe origin/master push does not block Themis merge"
}

test_merge_conflict_aborts() {
  local w out before
  w=$(new_world t16)
  printf 'themis-agents\n' > "$w/main/AGENTS.md"
  git -C "$w/main" add AGENTS.md
  git -C "$w/main" commit -qm themis-agents
  before=$(git -C "$w/main" rev-parse HEAD)
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: skipped: merge conflict" "conflict is reported"
  assert_contains "$out" "conflict: AGENTS.md" "conflicted path is listed"
  assert_contains "$out" "reread-firstmate: no" "no reread after aborted merge"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "conflicting merge moved Themis"
  ! git -C "$w/main" rev-parse --verify --quiet MERGE_HEAD \
    || fail "merge was left in progress"
  grep -qx 'themis-agents' "$w/main/AGENTS.md" || fail "Themis AGENTS.md was overwritten"
  assert_still_themis "$w/main"
  pass "T16 merge conflict aborts and leaves Themis untouched"
}

test_themis_fast_forwards_when_ancestor() {
  local w out
  w=$(new_world t17 no)
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: updated " "Themis fast-forwarded onto master"
  assert_still_themis "$w/main"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$(git -C "$w/main" rev-parse refs/heads/master)" ] \
    || fail "Themis HEAD is not at master after ancestor fast-forward"
  [ "$(git -C "$w/main" rev-list --parents -n1 HEAD | wc -w | tr -d ' ')" -eq 2 ] \
    || fail "ancestor Themis update was not a fast-forward"
  grep -qx 'v2' "$w/main/AGENTS.md" || fail "Kun change did not land on fast-forward Themis"
  pass "T17 Themis fast-forwards when it is already an ancestor of master"
}

test_merges_kun_into_themis
test_reread_gate_is_instruction_only
test_dirty_secondmate_skipped
test_diverged_secondmate_skipped
test_idempotent_already_current
test_registry_backstop_dedup_and_self_exclusion
test_firstmate_wrong_branch_skipped
test_firstmate_detached_head_skipped
test_unsafe_secondmate_home_skipped_before_git_update
test_dirty_themis_skipped
test_missing_upstream_skipped
test_diverged_master_skipped
test_failed_upstream_fetch_does_not_use_stale_ref
test_dirty_master_skips_themis_merge
test_remote_controller_updates_origin_only_root
test_unsafe_origin_push_does_not_block_themis
test_merge_conflict_aborts
test_themis_fast_forwards_when_ancestor

echo "# all fm-update tests passed"
