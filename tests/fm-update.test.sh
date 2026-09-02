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
#   - Merge conflicts are reported and left in progress for resolution.
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

test_reread_uses_merged_instruction_tree() {
  local w out
  w=$(new_world t3-merged-tree)
  printf 'themis-agents\n' > "$w/main/AGENTS.md"
  git -C "$w/main" add AGENTS.md
  git -C "$w/main" commit -qm themis-agents
  bump_kun "$w" readme

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: updated " "Themis merged the README-only Kun change"
  assert_contains "$out" "reread-firstmate: no" "unchanged merged instructions do not trigger reread"
  grep -qx 'themis-agents' "$w/main/AGENTS.md" || fail "Themis instruction customization changed"
  grep -q 'r-readme' "$w/main/README.md" || fail "Kun README change did not land"
  pass "T3 reread follows the merged instruction tree"
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

test_upstream_main_fetch_ignores_narrow_remote_config() {
  local w out kun_rev
  w=$(new_world t14-explicit-upstream)
  git -C "$w/seed" branch side
  git -C "$w/seed" push -q origin side
  git -C "$w/main" config --replace-all remote.upstream.fetch \
    '+refs/heads/side:refs/remotes/upstream/side'
  bump_kun "$w" readme
  kun_rev=$(git -C "$w/seed" rev-parse HEAD)

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: updated " "explicit upstream main refspec reaches Kun"
  [ "$(git -C "$w/main" rev-parse upstream/main)" = "$kun_rev" ] \
    || fail "upstream/main stayed stale after a successful fetch"
  git -C "$w/main" merge-base --is-ancestor "$kun_rev" HEAD \
    || fail "Themis did not receive explicitly fetched upstream/main"
  grep -q 'r-readme' "$w/main/README.md" || fail "latest Kun change did not land"
  pass "T14 upstream main fetch ignores narrow remote config"
}

test_dirty_master_skips_themis_merge() {
  local w out before master_before head_path
  w=$(new_world t14-dirty)
  git -C "$w/main" worktree add -q "$w/master-wt" master
  head_path=$(git -C "$w/master-wt" rev-parse --path-format=absolute --git-path HEAD)
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
  [ ! -e "${head_path}.lock" ] || fail "dirty master left HEAD.lock behind"
  assert_still_themis "$w/main"
  pass "T14 dirty master is skipped before Themis merge"
}

test_clean_master_worktree_fast_forwards() {
  local w out
  w=$(new_world t14-clean-master)
  git -C "$w/main" worktree add -q "$w/master-wt" master
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "master: updated " "clean checked-out master fast-forwarded"
  assert_contains "$out" "firstmate: updated " "Themis merged the fast-forwarded master"
  [ "$(head_branch "$w/master-wt")" = master ] || fail "master worktree left master"
  [ "$(git -C "$w/master-wt" rev-parse HEAD)" = "$(git -C "$w/main" rev-parse upstream/main)" ] \
    || fail "clean master worktree did not reach upstream/main"
  grep -qx 'v2' "$w/master-wt/AGENTS.md" || fail "clean master worktree did not update its files"
  assert_still_themis "$w/main"
  pass "T14 clean master worktree fast-forwards safely"
}

test_current_master_worktree_allows_themis_merge() {
  local w out upstream_rev
  w=$(new_world t14-current-master)
  bump_kun "$w" instr
  git -C "$w/main" fetch -q upstream
  upstream_rev=$(git -C "$w/main" rev-parse upstream/main)
  git -C "$w/main" update-ref refs/heads/master "$upstream_rev"
  git -C "$w/main" worktree add -q "$w/master-wt" master

  out=$(run_update "$w")

  assert_contains "$out" "master: already current" "current checked-out master is trusted"
  assert_contains "$out" "firstmate: updated " "Themis merged the current master"
  [ "$(git -C "$w/main" rev-parse HEAD)" != "$upstream_rev" ] \
    || fail "Themis unique commit was lost instead of merged"
  git -C "$w/main" merge-base --is-ancestor "$upstream_rev" HEAD \
    || fail "Themis did not contain the current checked-out master"
  assert_still_themis "$w/main"
  pass "T14 current master worktree permits the Themis merge"
}

test_checked_out_master_ignores_merge_options() {
  local w out
  w=$(new_world t14-master-options)
  git -C "$w/main" worktree add -q "$w/master-wt" master
  git -C "$w/main" config branch.master.mergeOptions --squash
  bump_kun "$w" instr

  out=$(run_update "$w")

  assert_contains "$out" "master: updated " "master ignores configured squash"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$(git -C "$w/main" rev-parse upstream/main)" ] \
    || fail "configured merge options prevented the master fast-forward"
  [ -z "$(git -C "$w/master-wt" status --porcelain)" ] \
    || fail "configured merge options dirtied the master worktree"
  assert_still_themis "$w/main"
  pass "T14 checked-out master ignores configured merge options"
}

test_themis_ignores_merge_options() {
  local w out before kun_rev
  w=$(new_world t14-themis-options)
  before=$(git -C "$w/main" rev-parse HEAD)
  git -C "$w/main" config branch.Themis.mergeOptions --no-commit
  bump_kun "$w" instr
  kun_rev=$(git -C "$w/seed" rev-parse HEAD)

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: updated " "Themis ignores configured no-commit"
  [ "$(git -C "$w/main" rev-parse HEAD)" != "$before" ] \
    || fail "configured merge options prevented Themis from advancing"
  git -C "$w/main" merge-base --is-ancestor "$before" HEAD \
    || fail "Themis lost its pre-update commit"
  git -C "$w/main" merge-base --is-ancestor "$kun_rev" HEAD \
    || fail "Themis update omitted Kun"
  ! git -C "$w/main" rev-parse --verify --quiet MERGE_HEAD >/dev/null \
    || fail "Themis merge remained uncommitted"
  [ -z "$(git -C "$w/main" status --porcelain)" ] \
    || fail "configured merge options left Themis dirty"
  assert_still_themis "$w/main"
  pass "T14 Themis ignores configured merge options"
}

test_master_worktree_branch_switch_is_blocked() {
  local w out fakebin real_git master_before feature_before switch_worktree
  w=$(new_world t14-master-switch)
  master_before=$(git -C "$w/main" rev-parse refs/heads/master)
  git -C "$w/main" branch race-feature "$master_before"
  feature_before=$(git -C "$w/main" rev-parse refs/heads/race-feature)
  git -C "$w/main" worktree add -q "$w/master-wt" master
  switch_worktree=$(cd "$w/master-wt" && pwd -P)
  bump_kun "$w" instr
  fakebin="$w/fakebin"
  mkdir -p "$fakebin"
  real_git=$(command -v git)
  cat > "$fakebin/git" <<'SH'
#!/usr/bin/env bash
ff_only=no
previous=""
for argument in "$@"; do
  if [ "$previous" = merge ] && [ "$argument" = --ff-only ]; then
    ff_only=yes
  fi
  previous=$argument
done
if [ "${1:-}" = -C ] && [ "${2:-}" = "$FM_TEST_SWITCH_WORKTREE" ] \
  && [ "$ff_only" = yes ]; then
  if env -u GIT_DIR -u GIT_COMMON_DIR -u GIT_WORK_TREE -u GIT_INDEX_FILE \
    "$FM_TEST_REAL_GIT" -C "$FM_TEST_SWITCH_WORKTREE" switch -q race-feature; then
    printf 'switched\n' > "$FM_TEST_SWITCH_RESULT"
  else
    printf 'blocked\n' > "$FM_TEST_SWITCH_RESULT"
  fi
fi
exec "$FM_TEST_REAL_GIT" "$@"
SH
  chmod +x "$fakebin/git"

  out=$(PATH="$fakebin:$PATH" FM_TEST_REAL_GIT="$real_git" \
    FM_TEST_SWITCH_WORKTREE="$switch_worktree" FM_TEST_SWITCH_RESULT="$w/switch-result" \
    FM_ROOT_OVERRIDE="$w/main" FM_HOME="$w/home" "$UPDATE" 2>/dev/null)

  [ "$(cat "$w/switch-result")" = blocked ] || fail "master worktree switched branches during update"
  assert_contains "$out" "master: updated " "locked master worktree fast-forwarded"
  [ "$(head_branch "$w/master-wt")" = master ] || fail "master worktree left master"
  [ "$(git -C "$w/main" rev-parse refs/heads/race-feature)" = "$feature_before" ] \
    || fail "feature branch moved during master update"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$(git -C "$w/main" rev-parse upstream/main)" ] \
    || fail "master did not reach upstream/main"
  assert_still_themis "$w/main"
  pass "T14 master worktree branch switch is blocked"
}

test_preexisting_merge_is_preserved() {
  local w out before merge_head_before
  w=$(new_world t14-preexisting-merge)
  printf 'themis-agents\n' > "$w/main/AGENTS.md"
  git -C "$w/main" add AGENTS.md
  git -C "$w/main" commit -qm themis-agents
  git -C "$w/main" worktree add -q -b preexisting-other "$w/preexisting-other" HEAD~1
  printf 'other-agents\n' > "$w/preexisting-other/AGENTS.md"
  git -C "$w/preexisting-other" add AGENTS.md
  git -C "$w/preexisting-other" commit -qm other-agents
  git -C "$w/main" worktree remove "$w/preexisting-other"
  if git -C "$w/main" merge --no-edit preexisting-other >/dev/null 2>&1; then
    fail "precondition: expected a conflicting pre-existing merge"
  fi
  git -C "$w/main" checkout --ours AGENTS.md
  git -C "$w/main" add AGENTS.md
  [ -z "$(git -C "$w/main" status --porcelain)" ] \
    || fail "precondition: resolved merge should have an empty porcelain status"
  before=$(git -C "$w/main" rev-parse HEAD)
  merge_head_before=$(git -C "$w/main" rev-parse MERGE_HEAD)
  bump_kun "$w" readme

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: skipped: git operation in progress" "pre-existing merge is reported"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "pre-existing merge moved HEAD"
  [ "$(git -C "$w/main" rev-parse MERGE_HEAD)" = "$merge_head_before" ] \
    || fail "pre-existing merge was aborted or replaced"
  grep -qx 'themis-agents' "$w/main/AGENTS.md" || fail "pre-existing merge resolution changed"
  pass "T14 pre-existing merge remains in progress"
}

test_verified_upstream_commit_survives_master_race() {
  local w out rogue fakebin real_git rogue_rev kun_rev
  w=$(new_world t14-master-race)
  bump_kun "$w" instr
  kun_rev=$(git -C "$w/seed" rev-parse HEAD)
  rogue="$w/rogue"
  git clone -q "$w/origin.git" "$rogue"
  printf 'rogue\n' > "$rogue/ROGUE.md"
  git -C "$rogue" add ROGUE.md
  git -C "$rogue" commit -qm rogue-master
  rogue_rev=$(git -C "$rogue" rev-parse HEAD)
  git -C "$w/main" fetch -q "$rogue" master
  fakebin="$w/fakebin"
  mkdir -p "$fakebin"
  real_git=$(command -v git)
  cat > "$fakebin/git" <<'SH'
#!/usr/bin/env bash
if [ "${1:-}" = -C ] && [ "${2:-}" = "$FM_TEST_MOVE_REPO" ] \
  && [ "${3:-}" = fetch ] && [ "${4:-}" = origin ]; then
  "$FM_TEST_REAL_GIT" "$@"
  rc=$?
  if [ "$rc" -eq 0 ]; then
    "$FM_TEST_REAL_GIT" -C "$FM_TEST_MOVE_REPO" update-ref refs/heads/master "$FM_TEST_MOVE_REV"
  fi
  exit "$rc"
fi
exec "$FM_TEST_REAL_GIT" "$@"
SH
  chmod +x "$fakebin/git"

  out=$(PATH="$fakebin:$PATH" FM_TEST_REAL_GIT="$real_git" \
    FM_TEST_MOVE_REPO="$w/main" FM_TEST_MOVE_REV="$rogue_rev" \
    FM_ROOT_OVERRIDE="$w/main" FM_HOME="$w/home" "$UPDATE" 2>/dev/null)

  assert_contains "$out" "firstmate: updated " "Themis merged the verified Kun commit"
  [ "$(git -C "$w/main" rev-parse refs/heads/master)" = "$rogue_rev" ] \
    || fail "precondition: the race did not move master"
  git -C "$w/main" merge-base --is-ancestor "$kun_rev" HEAD \
    || fail "Themis omitted the verified Kun commit"
  [ ! -e "$w/main/ROGUE.md" ] || fail "Themis merged the raced master commit"
  [ "$(git -C "$w/origin.git" rev-parse refs/heads/master)" = "$kun_rev" ] \
    || fail "origin/master did not receive the verified Kun commit"
  assert_still_themis "$w/main"
  pass "T14 verified Kun commit survives a moving master ref"
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

test_foreign_merge_race_is_preserved() {
  local w out fakebin real_git foreign_rev before
  w=$(new_world t16-foreign-race)
  printf 'themis-agents\n' > "$w/main/AGENTS.md"
  git -C "$w/main" add AGENTS.md
  git -C "$w/main" commit -qm themis-agents
  before=$(git -C "$w/main" rev-parse HEAD)
  git -C "$w/main" worktree add -q -b foreign-merge "$w/foreign" HEAD~1
  printf 'foreign-agents\n' > "$w/foreign/AGENTS.md"
  git -C "$w/foreign" add AGENTS.md
  git -C "$w/foreign" commit -qm foreign-agents
  foreign_rev=$(git -C "$w/foreign" rev-parse HEAD)
  git -C "$w/main" worktree remove "$w/foreign"
  bump_kun "$w" readme
  fakebin="$w/fakebin"
  mkdir -p "$fakebin"
  real_git=$(command -v git)
  cat > "$fakebin/git" <<'SH'
#!/usr/bin/env bash
themis_merge=no
previous=""
for argument in "$@"; do
  if [ "$previous" = merge ] && [ "$argument" = --ff ]; then
    themis_merge=yes
  fi
  previous=$argument
done
if [ "${1:-}" = -C ] && [ "${2:-}" = "$FM_TEST_MERGE_REPO" ] \
  && [ "$themis_merge" = yes ]; then
  "$FM_TEST_REAL_GIT" -C "$FM_TEST_MERGE_REPO" merge --no-edit foreign-merge >/dev/null 2>&1 || true
fi
exec "$FM_TEST_REAL_GIT" "$@"
SH
  chmod +x "$fakebin/git"

  out=$(PATH="$fakebin:$PATH" FM_TEST_REAL_GIT="$real_git" \
    FM_TEST_MERGE_REPO="$w/main" FM_ROOT_OVERRIDE="$w/main" FM_HOME="$w/home" \
    "$UPDATE" 2>/dev/null)

  assert_contains "$out" "firstmate: skipped: merge conflict" "foreign merge race is reported"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "foreign merge race moved Themis HEAD"
  [ "$(git -C "$w/main" rev-parse MERGE_HEAD)" = "$foreign_rev" ] \
    || fail "foreign merge race was aborted or replaced"
  git -C "$w/main" diff --name-only --diff-filter=U | grep -qx AGENTS.md \
    || fail "foreign merge conflict was not preserved"
  assert_still_themis "$w/main"
  pass "T16 foreign merge race remains in progress"
}

test_merge_conflict_is_left_reported() {
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
  assert_contains "$out" "reread-firstmate: no" "no reread after conflicted merge"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] || fail "conflicting merge moved Themis"
  git -C "$w/main" rev-parse --verify --quiet MERGE_HEAD >/dev/null \
    || fail "conflicting merge was not left in progress"
  git -C "$w/main" diff --name-only --diff-filter=U | grep -qx AGENTS.md \
    || fail "conflicted path was not left for resolution"
  assert_still_themis "$w/main"
  pass "T16 merge conflict remains reported for resolution"
}

test_nonconflict_merge_failure_is_reported() {
  local w out before hooks_dir
  w=$(new_world t16-hook-failure)
  before=$(git -C "$w/main" rev-parse HEAD)
  hooks_dir=$(git -C "$w/main" rev-parse --path-format=absolute --git-path hooks)
  printf '%s\n' '#!/usr/bin/env bash' \
    "printf 'merge hook rejected commit\\n' >&2" \
    'exit 1' > "$hooks_dir/pre-merge-commit"
  chmod +x "$hooks_dir/pre-merge-commit"
  bump_kun "$w" readme

  out=$(run_update "$w")

  assert_contains "$out" "firstmate: skipped: merge failed: merge hook rejected commit" \
    "nonconflict merge failure reports the hook error"
  assert_contains "$out" "merge remains in progress" "nonconflict merge state is reported"
  assert_contains "$out" "reread-firstmate: no" "failed merge does not trigger a reread"
  assert_not_contains "$out" "firstmate: skipped: merge conflict" \
    "clean merge failure is not mislabeled as a conflict"
  [ "$(git -C "$w/main" rev-parse HEAD)" = "$before" ] \
    || fail "failed merge moved Themis HEAD"
  git -C "$w/main" rev-parse --verify --quiet MERGE_HEAD >/dev/null \
    || fail "failed merge was not left in progress"
  [ -z "$(git -C "$w/main" diff --name-only --diff-filter=U)" ] \
    || fail "hook failure unexpectedly left unmerged paths"
  [ -n "$(git -C "$w/main" status --porcelain)" ] \
    || fail "failed merge did not preserve its staged result"
  assert_still_themis "$w/main"
  pass "T16 nonconflict merge failure remains actionable"
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
test_reread_uses_merged_instruction_tree
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
test_upstream_main_fetch_ignores_narrow_remote_config
test_dirty_master_skips_themis_merge
test_clean_master_worktree_fast_forwards
test_current_master_worktree_allows_themis_merge
test_checked_out_master_ignores_merge_options
test_themis_ignores_merge_options
test_master_worktree_branch_switch_is_blocked
test_preexisting_merge_is_preserved
test_verified_upstream_commit_survives_master_race
test_remote_controller_updates_origin_only_root
test_unsafe_origin_push_does_not_block_themis
test_foreign_merge_race_is_preserved
test_merge_conflict_is_left_reported
test_nonconflict_merge_failure_is_reported
test_themis_fast_forwards_when_ancestor

echo "# all fm-update tests passed"
