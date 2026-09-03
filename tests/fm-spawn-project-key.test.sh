#!/usr/bin/env bash
# Behavior tests for fm-spawn.sh canonical project-key identity (--project-key).
#
# These drive the REAL bin/fm-spawn.sh through meta writing with a fake tmux pane
# and a real isolated git worktree (the same harness shape as
# tests/fm-spawn-dispatch-profile.test.sh), so each case asserts the project_key=
# identity and the explicit per-task delivery contract that firstmate would
# record - WITHOUT the interactive `treehouse get`-in-a-pane step that is
# environment-flaky under some login shells.
#
# The identity contract: fm-spawn derives the registry identity from
# basename($PROJ_ABS) unless --project-key or the fm-brief-persisted
# data/<id>/project-key sidecar carries the canonical key (the firstmate repo
# registered as "Agent-Themis" while its checkout basename is "Firstmate").
# The key is ADVISORY identity only - PR identity lookup, standing-posture
# context, and durable project_key= recording. A ship task's delivery mode and
# yolo are the explicit --mode/--yolo flags, validated and recorded verbatim;
# the registry never decides or overrides them.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SPAWN="$ROOT/bin/fm-spawn.sh"
TMP_ROOT=$(fm_test_tmproot fm-spawn-project-key)

# Fake tmux: answers the worktree-discovery poll with FM_FAKE_PANE_PATH (a real
# git worktree), reports the container session for display-message, and swallows
# every window/send op so no real backend or agent starts. Mirrors the fakebin in
# tests/fm-spawn-dispatch-profile.test.sh.
make_spawn_fakebin() {
  local dir=$1 fakebin
  fakebin=$(fm_fakebin "$dir")
  cat > "$fakebin/tmux" <<'SH'
#!/usr/bin/env bash
set -u
case "$*" in
  *"#{pane_current_path}"*) printf '%s\n' "${FM_FAKE_PANE_PATH:-}"; exit 0 ;;
esac
case "${1:-}" in
  display-message) printf 'firstmate\n'; exit 0 ;;
  list-windows) exit 0 ;;
  has-session|new-session|new-window|kill-window|set-window-option) exit 0 ;;
  send-keys) exit 0 ;;
esac
exit 0
SH
  chmod +x "$fakebin/tmux"
  fm_fake_exit0 "$fakebin" treehouse
  printf '%s\n' "$fakebin"
}

# make_case <name> <clone-basename> [<registry-line>]: build a home plus a project
# git repo whose DIRECTORY basename is <clone-basename> and an isolated worktree
# the fake pane reports. <registry-line>, if given, is written verbatim to
# data/projects.md. Echoes "home|proj|wt|fakebin".
make_case() {
  local name=$1 clone=$2 regline=${3:-} case_dir home proj wt fakebin
  case_dir="$TMP_ROOT/$name"
  home="$case_dir/home"
  proj="$case_dir/$clone"
  wt="$case_dir/wt"
  fakebin=$(make_spawn_fakebin "$case_dir/fake")
  mkdir -p "$home/data" "$home/projects" "$home/state" "$home/config"
  printf 'claude\n' > "$home/config/crew-harness"
  touch "$home/state/.last-watcher-beat"
  [ -z "$regline" ] || printf '%s\n' "$regline" > "$home/data/projects.md"
  fm_git_worktree "$proj" "$wt" "wt-$name"
  printf '%s\n' "$home|$proj|$wt|$fakebin"
}

read_case() {
  IFS='|' read -r HOME_DIR PROJ_DIR WT_DIR FAKEBIN_DIR <<EOF
$1
EOF
}

# Run fm-spawn with the fake tmux. A raw launch command ("sh -c :") takes the
# unverified-adapter path, so no crew-harness template lookup or real agent is
# needed. Prints combined stdout+stderr; the caller reads $? for the exit code.
run_spawn() {
  local home=$1 wt=$2 fakebin=$3
  shift 3
  FM_ROOT_OVERRIDE='' FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$wt" TMUX="fake,1,0" \
    GROK_HOME="$home/grok-home" PATH="$fakebin:$PATH" \
    "$SPAWN" "$@" 2>&1
}

run_spawn_with_pane() {
  local home=$1 wt=$2 fakebin=$3 pane=$4
  shift 4
  FM_ROOT_OVERRIDE="$FM_FAKE_ROOT" FM_HOME="$home" \
    FM_STATE_OVERRIDE="$home/state" FM_DATA_OVERRIDE="$home/data" \
    FM_PROJECTS_OVERRIDE="$home/projects" FM_CONFIG_OVERRIDE="$home/config" \
    FM_SPAWN_NO_GUARD=1 FM_FAKE_PANE_PATH="$pane" TMUX="fake,1,0" \
    GROK_HOME="$home/grok-home" PATH="$fakebin:$PATH" \
    "$SPAWN" "$@" 2>&1
}

seed_brief() {  # <home> <id>
  mkdir -p "$1/data/$2"
  printf 'trivial brief for %s\n' "$2" > "$1/data/$2/brief.md"
}

# Persist the canonical registry key exactly as bin/fm-brief.sh does, so fm-spawn
# picks it up as the default identity without an explicit --project-key.
seed_project_key() {  # <home> <id> <key>
  mkdir -p "$1/data/$2"
  printf '%s\n' "$3" > "$1/data/$2/project-key"
}

# --- 1. ship: --project-key records identity; explicit --mode/--yolo record ---
# Project dir basename is "Firstmate"; the registry key is "Agent-Themis
# [local-only]". Passing --project-key Agent-Themis must persist project_key,
# and the explicit --mode/--yolo flags must reach meta verbatim - the registry
# posture is context only and never rewrites them.
test_ship_project_key_differs_from_basename() {
  read_case "$(make_case ship-key-diff Firstmate '- Agent-Themis [local-only] - firstmate repo (added 2026-07-20)')"
  seed_brief "$HOME_DIR" cm-a-z1
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-a-z1 "$PROJ_DIR" "sh -c :" --project-key Agent-Themis --mode local-only --yolo on)
  expect_code 0 "$?" "ship --project-key spawn should succeed"$'\n'"$out"
  meta="$HOME_DIR/state/cm-a-z1.meta"
  assert_present "$meta" "ship --project-key spawn must write meta"
  assert_grep "mode=local-only" "$meta" "the explicit --mode local-only must be recorded verbatim"
  assert_grep "yolo=on" "$meta" "the explicit --yolo on must be recorded verbatim, never rewritten from the registry"
  assert_grep "project_key=Agent-Themis" "$meta" "the canonical key must be recorded in meta when it differs from the basename"
  assert_grep "kind=ship" "$meta" "meta must record kind=ship"
  pass "fm-spawn --project-key: a key differing from the clone basename is recorded, and the explicit delivery contract reaches meta verbatim"
}

# --- 2. ship: key == basename (matching-key project) stays byte-identical -------
# The common case (clones under projects/): no --project-key, basename IS a
# registry key. NO project_key= line is written, so the meta stays
# byte-identical, and the explicit mode is recorded as passed.
test_ship_matching_key_no_project_key_line() {
  read_case "$(make_case ship-key-match Echo '- Echo [no-mistakes] - voice daemon (added 2026-07-20)')"
  seed_brief "$HOME_DIR" cm-b-z2
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-b-z2 "$PROJ_DIR" "sh -c :" --mode no-mistakes --yolo off)
  expect_code 0 "$?" "matching-key spawn should succeed"$'\n'"$out"
  meta="$HOME_DIR/state/cm-b-z2.meta"
  assert_grep "mode=no-mistakes" "$meta" "the explicit --mode no-mistakes must be recorded"
  assert_no_grep "project_key=" "$meta" "when the key equals the basename, meta must NOT carry a project_key= line (byte-identical)"
  pass "fm-spawn: a matching-key project (key==basename) records no project_key= line, keeping meta byte-identical"
}

# --- 3. ship: no --project-key + a non-key basename keeps the identity default --
# The preserved back-compat identity path: without --project-key or a sidecar,
# the identity is basename "Firstmate" (key==basename, so no project_key= line),
# and registry membership neither decides nor blocks anything - the explicit
# delivery contract is recorded as passed.
test_ship_basename_fallback_records_no_key_line() {
  read_case "$(make_case ship-fallback Firstmate '- Agent-Themis [local-only] - firstmate repo (added 2026-07-20)')"
  seed_brief "$HOME_DIR" cm-c-z3
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-c-z3 "$PROJ_DIR" "sh -c :" --mode no-mistakes --yolo off)
  expect_code 0 "$?" "basename-fallback spawn should still succeed"$'\n'"$out"
  meta="$HOME_DIR/state/cm-c-z3.meta"
  assert_grep "mode=no-mistakes" "$meta" "the explicit --mode no-mistakes must be recorded on the basename-identity path"
  assert_no_grep "project_key=" "$meta" "the basename fallback records no project_key= line (key==basename)"
  pass "fm-spawn: the basename identity fallback records no project_key= line and the explicit delivery contract as passed"
}

# --- 3b. deterministic propagation: the fm-brief sidecar drives the key ---------
# The robust path: firstmate names the key ONCE as fm-brief's repo-name, which
# persists data/<id>/project-key; fm-spawn reads it with NO --project-key and
# records the canonical identity. The key's registered [local-only] posture must
# NOT override the explicit --mode: the registry is advisory identity only.
test_sidecar_drives_key_without_flag() {
  read_case "$(make_case sidecar-drives Firstmate '- Agent-Themis [local-only] - firstmate repo (added 2026-07-20)')"
  seed_brief "$HOME_DIR" cm-s-z1
  seed_project_key "$HOME_DIR" cm-s-z1 Agent-Themis
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-s-z1 "$PROJ_DIR" "sh -c :" --mode no-mistakes --yolo off)
  expect_code 0 "$?" "sidecar-driven spawn should succeed"$'\n'"$out"
  meta="$HOME_DIR/state/cm-s-z1.meta"
  assert_grep "mode=no-mistakes" "$meta" "the explicit --mode must win even though the sidecar key's registered posture is local-only"
  assert_grep "project_key=Agent-Themis" "$meta" "the sidecar-resolved key must be recorded when it differs from the basename"
  pass "fm-spawn: the fm-brief-persisted data/<id>/project-key drives the recorded identity, and the registry posture never overrides the explicit mode"
}

# --- 3c. an explicit --project-key overrides the persisted sidecar --------------
test_explicit_key_overrides_sidecar() {
  read_case "$(make_case sidecar-override Firstmate '- Agent-Themis [local-only] - firstmate repo (added 2026-07-20)
- Echo [no-mistakes] - voice daemon (added 2026-07-20)')"
  seed_brief "$HOME_DIR" cm-s-z2
  seed_project_key "$HOME_DIR" cm-s-z2 Echo
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-s-z2 "$PROJ_DIR" "sh -c :" --project-key Agent-Themis --mode no-mistakes --yolo off)
  expect_code 0 "$?" "override spawn should succeed"$'\n'"$out"
  meta="$HOME_DIR/state/cm-s-z2.meta"
  assert_grep "project_key=Agent-Themis" "$meta" "the explicit key must win over the persisted sidecar (Agent-Themis, not the sidecar's Echo)"
  assert_grep "mode=no-mistakes" "$meta" "the explicit --mode must be recorded regardless of either key's registered posture"
  pass "fm-spawn: an explicit --project-key overrides the fm-brief-persisted sidecar"
}

# --- 3d. END-TO-END: real fm-brief -> real fm-spawn agree on the sidecar --------
# The whole-bug-class regression guard: the two scripts independently derived
# identity and disagreed. Here real fm-brief writes the sidecar (no hand-mimic)
# and real fm-spawn reads it, proving they agree on the file's PATH and FORMAT.
# key != basename: Agent-Themis must flow through end to end, and the brief's
# recorded "Delivery contract: mode=" line must agree with the spawn's --mode.
test_end_to_end_brief_then_spawn_key_differs() {
  read_case "$(make_case e2e-key-diff Firstmate '- Agent-Themis [local-only] - firstmate repo (added 2026-07-20)')"
  FM_HOME="$HOME_DIR" "$ROOT/bin/fm-brief.sh" e2e-a1 Agent-Themis --mode local-only >/dev/null 2>&1 \
    || fail "real fm-brief should scaffold the Agent-Themis brief"
  assert_present "$HOME_DIR/data/e2e-a1/project-key" "real fm-brief must persist the sidecar that fm-spawn reads"
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" e2e-a1 "$PROJ_DIR" "sh -c :" --mode local-only --yolo off)
  expect_code 0 "$?" "the real fm-brief -> fm-spawn chain should succeed"$'\n'"$out"
  meta="$HOME_DIR/state/e2e-a1.meta"
  assert_grep "mode=local-only" "$meta" "real chain: the explicit mode agreed between brief and spawn must be recorded"
  assert_grep "project_key=Agent-Themis" "$meta" "real chain: the key fm-brief persisted must be the one fm-spawn records"
  pass "fm-brief -> fm-spawn (real, no hand-mimic): the two scripts agree on the persisted-key path, format, and delivery contract (key != basename)"
}

# --- 3e. END-TO-END: matching key stays byte-identical WITH a real sidecar ------
# The new production normal: fm-brief ALWAYS writes a sidecar now. For a
# matching-key project it equals the basename, so fm-spawn must still write NO
# project_key= line - byte-identical meta, proven with a real sidecar present.
test_end_to_end_brief_then_spawn_matching_key_byte_identical() {
  read_case "$(make_case e2e-key-match Echo '- Echo [no-mistakes] - voice daemon (added 2026-07-20)')"
  FM_HOME="$HOME_DIR" "$ROOT/bin/fm-brief.sh" e2e-b2 Echo --mode no-mistakes >/dev/null 2>&1 \
    || fail "real fm-brief should scaffold the Echo brief"
  assert_present "$HOME_DIR/data/e2e-b2/project-key" "fm-brief writes a sidecar even for a matching-key project"
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" e2e-b2 "$PROJ_DIR" "sh -c :" --mode no-mistakes --yolo off)
  expect_code 0 "$?" "the real matching-key chain should succeed"$'\n'"$out"
  meta="$HOME_DIR/state/e2e-b2.meta"
  assert_grep "mode=no-mistakes" "$meta" "real chain: the explicit no-mistakes contract is recorded end to end"
  assert_no_grep "project_key=" "$meta" "real chain: a matching-key project with a real sidecar present must still write NO project_key= line (byte-identical meta)"
  pass "fm-brief -> fm-spawn (real): a matching-key project writes a sidecar yet keeps meta byte-identical (no project_key= line)"
}

# --- 4. scout: honors --project-key the same way (every worker kind) -----------
# A scout delivers a report and records no delivery posture: --mode is rejected
# for scouts, so its meta must carry the canonical key but no mode= line.
test_scout_project_key_resolves_mode() {
  read_case "$(make_case scout-key-diff Firstmate '- Agent-Themis [local-only] - firstmate repo (added 2026-07-20)')"
  seed_brief "$HOME_DIR" sc-a-z4
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" sc-a-z4 "$PROJ_DIR" "sh -c :" --project-key Agent-Themis --scout)
  expect_code 0 "$?" "scout --project-key spawn should succeed"$'\n'"$out"
  meta="$HOME_DIR/state/sc-a-z4.meta"
  assert_grep "kind=scout" "$meta" "meta must record kind=scout"
  assert_no_grep "mode=" "$meta" "a scout records no delivery posture (no mode= line)"
  assert_grep "project_key=Agent-Themis" "$meta" "a scout records the canonical key when it differs from the basename"
  pass "fm-spawn --project-key --scout: a scout honors the same canonical-key identity contract and records no delivery posture"
}

# --- 5. unknown key via --project-key: recorded for traceability ---------------
# An unregistered key does not block a spawn: delivery comes from the explicit
# flags, the identity is recorded verbatim, and PR identity resolves to none.
test_unknown_project_key_falls_back_and_warns() {
  read_case "$(make_case unknown-key Firstmate '- Echo [no-mistakes] - voice daemon (added 2026-07-20)')"
  seed_brief "$HOME_DIR" cm-d-z5
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-d-z5 "$PROJ_DIR" "sh -c :" --project-key Nonexistent-Key --mode no-mistakes --yolo off)
  expect_code 0 "$?" "unknown-key spawn should still succeed"$'\n'"$out"
  meta="$HOME_DIR/state/cm-d-z5.meta"
  assert_grep "mode=no-mistakes" "$meta" "an unknown key spawns on the explicit delivery contract"
  assert_grep "project_key=Nonexistent-Key" "$meta" "the explicit key is still recorded when it differs from the basename, for traceability"
  pass "fm-spawn --project-key: an unknown key is recorded for traceability and never decides delivery"
}

test_atlas_spawn_abort_removes_only_unpublished_binding() {
  local case_dir fake_root out rc
  read_case "$(make_case atlas-abort Firstmate '- Atlas [direct-PR pr-identity=atlas-pat] - synthetic broker project (added 2026-07-23)')"
  seed_brief "$HOME_DIR" atlas-abort-z8
  case_dir=$(dirname "$HOME_DIR")
  fake_root="$case_dir/fake-root"
  mkdir -p "$fake_root"
  cp -R "$ROOT/bin" "$fake_root/bin"
  rm -f "$fake_root/bin/fm-pr-identity.sh"
  cat > "$fake_root/bin/fm-pr-identity.sh" <<'SH'
#!/usr/bin/env bash
set -eu
[ "${1:-}" = preflight ] || exit 1
id=$2
project_key=$3
project=$4
project_real=$(cd "$project" && pwd -P)
umask 077
printf '%s\n' \
  'version=1' \
  "task=$id" \
  'profile=atlas-pat' \
  "project_key=$project_key" \
  'repo=example/repo' \
  "branch=fm/$id" \
  'base=main' \
  "project=$project_real" > "$FM_STATE_OVERRIDE/$id.pr-binding"
chmod 0600 "$FM_STATE_OVERRIDE/$id.pr-binding"
printf 'profile=atlas-pat\nrepo=example/repo\nbranch=fm/%s\nbase=main\n' "$id"
SH
  chmod +x "$fake_root/bin/fm-pr-identity.sh"
  FM_FAKE_ROOT="$fake_root"
  out=$(run_spawn_with_pane "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "$HOME_DIR" \
    atlas-abort-z8 "$PROJ_DIR" --harness claude --project-key Atlas --mode direct-PR --yolo off)
  rc=$?
  [ "$rc" -ne 0 ] || fail "Atlas spawn abort should fail when the backend did not enter a worktree"$'\n'"$out"
  assert_absent "$HOME_DIR/state/atlas-abort-z8.pr-binding" \
    "an aborted Atlas spawn must remove the binding created before backend setup"
  assert_absent "$HOME_DIR/state/atlas-abort-z8.meta" \
    "an aborted Atlas spawn must not publish task metadata"
  pass "Atlas spawn abort removes an unpublished preflight binding and leaves no runnable task state"
}

# --- 6. secondmate: --project-key is rejected (identity is the home) -----------
test_secondmate_rejects_project_key() {
  read_case "$(make_case sm-reject Firstmate '')"
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" sm-a-z6 "$HOME_DIR/some-home" "sh -c :" --secondmate --project-key Whatever)
  rc=$?
  [ "$rc" -ne 0 ] || fail "a --secondmate spawn with --project-key must be rejected"$'\n'"$out"
  assert_contains "$out" "does not apply to --secondmate" "the rejection must name the reason"
  assert_absent "$HOME_DIR/state/sm-a-z6.meta" "a rejected --secondmate --project-key spawn must not write meta"
  pass "fm-spawn: --project-key is rejected for a --secondmate spawn (its identity is its home, mode=secondmate)"
}

# --- 7. batch: --project-key is rejected (heterogeneous pairs) -----------------
test_batch_rejects_project_key() {
  read_case "$(make_case batch-reject Firstmate '')"
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" "a-z7=projects/x" "b-z8=projects/y" --project-key Whatever --mode no-mistakes --yolo off)
  rc=$?
  [ "$rc" -ne 0 ] || fail "a batch spawn with --project-key must be rejected"$'\n'"$out"
  assert_contains "$out" "applies to a single spawn only" "the batch rejection must name the reason"
  pass "fm-spawn: --project-key is rejected for a batch (id=repo pairs are heterogeneous)"
}

# --- 8. --project-key requires a value ----------------------------------------
test_project_key_requires_value() {
  read_case "$(make_case key-needs-value Firstmate '')"
  seed_brief "$HOME_DIR" cm-e-z9
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-e-z9 "$PROJ_DIR" "sh -c :" --project-key)
  rc=$?
  [ "$rc" -ne 0 ] || fail "--project-key with no value must be rejected"$'\n'"$out"
  assert_contains "$out" "--project-key requires a value" "a bare --project-key must report the missing value"
  out=$(run_spawn "$HOME_DIR" "$WT_DIR" "$FAKEBIN_DIR" cm-e-z9 "$PROJ_DIR" "sh -c :" --project-key=)
  rc=$?
  [ "$rc" -ne 0 ] || fail "--project-key= (empty) must be rejected"$'\n'"$out"
  assert_contains "$out" "--project-key requires a non-empty value" "an empty --project-key= must be rejected"
  pass "fm-spawn: --project-key fails closed on a missing or empty value"
}

test_ship_project_key_differs_from_basename
test_ship_matching_key_no_project_key_line
test_ship_basename_fallback_records_no_key_line
test_sidecar_drives_key_without_flag
test_explicit_key_overrides_sidecar
test_end_to_end_brief_then_spawn_key_differs
test_end_to_end_brief_then_spawn_matching_key_byte_identical
test_scout_project_key_resolves_mode
test_unknown_project_key_falls_back_and_warns
test_atlas_spawn_abort_removes_only_unpublished_binding
test_secondmate_rejects_project_key
test_batch_rejects_project_key
test_project_key_requires_value
