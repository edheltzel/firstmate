#!/usr/bin/env bash
# tests/fm-backend-herdr-workspace-per-home-e2e.test.sh - mandatory ISOLATED
# end-to-end real-herdr test for the project-keyed "<name>-Fleet" worker
# workspace contract. Drives the REAL bin/fm-spawn.sh and bin/fm-teardown.sh
# (not just adapter primitives), because the requirements under test - a worker
# landing in its PROJECT's Fleet workspace regardless of spawning home, two
# projects never sharing a workspace, and a --secondmate spawn keeping its own
# Archon supervisor workspace - only exist at fm-spawn.sh's herdr case arm and
# fm_backend_herdr_workspace_label's KIND + project resolution; none is
# exercised by the adapter-primitive smoke test.
#
# Mirrors tests/fm-backend-autodetect-smoke.test.sh's isolated-session
# convention: a private throwaway HERDR_SESSION (never the captain's
# default), scratch FM_HOME(s), and scratch local-only projects.
#
# Safety (2026-07-02 incident, see tests/herdr-test-safety.sh): cleanup uses
# ONLY herdr_safe_stop_and_delete, never a bare/inline-prefixed `herdr server
# stop`.
#
# Covers, at minimum (per the task brief):
#   - an ordinary worker landing in its PROJECT's own "<name>-Fleet" workspace
#   - two workers for the SAME project sharing one workspace even when spawned
#     from DIFFERENT homes (project-keyed, not home-keyed)
#   - two DIFFERENT projects never sharing a workspace
#   - a --secondmate spawn keeping its own "Archon-<id>" supervisor workspace,
#     never a Fleet worker label
#   - teardown closing the right tab (and no other) within a shared workspace
#   - list-live recovery scoped to a given project's Fleet, across homes
set -u

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

fail() { printf 'not ok - %s\n' "$1" >&2; cleanup_all; exit 1; }
pass() { printf 'ok - %s\n' "$1"; }
assert_contains_local() {  # <haystack> <needle> <msg>
  case "$1" in
    *"$2"*) : ;;
    *) fail "$3"$'\n'"--- got ---"$'\n'"$1" ;;
  esac
}
assert_not_contains_local() {  # <haystack> <needle> <msg>
  case "$1" in
    *"$2"*) fail "$3"$'\n'"--- got ---"$'\n'"$1" ;;
    *) : ;;
  esac
}

command -v herdr >/dev/null 2>&1 || { echo "skip: herdr not found"; exit 0; }
command -v jq >/dev/null 2>&1 || { echo "skip: jq not found (required by the herdr adapter)"; exit 0; }
command -v treehouse >/dev/null 2>&1 || { echo "skip: treehouse not found (required by fm-spawn.sh)"; exit 0; }

# shellcheck source=tests/herdr-test-safety.sh
. "$ROOT/tests/herdr-test-safety.sh"

# TMP_ROOT is physically resolved (mktemp -d "$(pwd -P)"-relative) for the same
# low-noise scratch fixture shape used by
# tests/fm-backend-autodetect-smoke.test.sh.
# fm-spawn no longer needs this as a symlink workaround: fm-spawn-symlink-guard-s8
# canonicalized project and backend cwd comparisons in the worktree-discovery
# poll.
TMP_ROOT=$(mktemp -d "$(cd "${TMPDIR:-/tmp}" && pwd -P)/fm-herdr-e2e.XXXXXX")
SESSION="fm-lab-herdr-e2e-$$"
export HERDR_SESSION="$SESSION"
WT1=; WT2=; WT3=
cleanup_all() {
  [ -n "$WT1" ] && command -v treehouse >/dev/null 2>&1 && treehouse return --force "$WT1" >/dev/null 2>&1
  [ -n "$WT2" ] && command -v treehouse >/dev/null 2>&1 && treehouse return --force "$WT2" >/dev/null 2>&1
  [ -n "$WT3" ] && command -v treehouse >/dev/null 2>&1 && treehouse return --force "$WT3" >/dev/null 2>&1
  herdr_safe_stop_and_delete "$SESSION"
  rm -rf "$TMP_ROOT"
}
trap cleanup_all EXIT
fm_herdr_lab_prepare "$SESSION" || fail "could not prepare isolated Herdr lab session"

# shellcheck source=bin/fm-backend.sh
. "$ROOT/bin/fm-backend.sh"
fm_backend_source herdr || fail "fm_backend_source herdr failed"

# --- scratch world: a primary-shaped home, a secondmate-shaped home, two projects ---

PRIMARY_HOME="$TMP_ROOT/primary-home"
mkdir -p "$PRIMARY_HOME/state" "$PRIMARY_HOME/data/cm1" "$PRIMARY_HOME/config"
printf 'trivial e2e primary crewmate brief: nothing to do.\n' > "$PRIMARY_HOME/data/cm1/brief.md"

SM_HOME="$TMP_ROOT/secondmate-home"
mkdir -p "$SM_HOME/state" "$SM_HOME/data/cm2" "$SM_HOME/data/cm3" "$SM_HOME/config" "$SM_HOME/projects" "$SM_HOME/bin"
printf '# scratch secondmate home AGENTS.md placeholder\n' > "$SM_HOME/AGENTS.md"
printf 'e2esm1\n' > "$SM_HOME/.fm-secondmate-home"
printf 'trivial e2e secondmate charter: nothing to do.\n' > "$SM_HOME/data/charter.md"
printf 'trivial e2e secondmate-owned crewmate brief: nothing to do.\n' > "$SM_HOME/data/cm2/brief.md"
printf 'trivial e2e secondmate-owned second crewmate brief: nothing to do.\n' > "$SM_HOME/data/cm3/brief.md"

make_scratch_project() {  # <dir>
  local dir=$1
  mkdir -p "$dir"
  git -C "$dir" init -q
  printf '# scratch\n' > "$dir/README.md"
  git -C "$dir" add README.md
  git -C "$dir" -c user.name='Firstmate Tests' -c user.email='tests@example.invalid' commit -qm initial
}

PROJ1="$TMP_ROOT/scratch-project-1"; make_scratch_project "$PROJ1"
PROJ2="$TMP_ROOT/scratch-project-2"; make_scratch_project "$PROJ2"
# Ordinary workers land in their PROJECT's own "<repo-name>-Fleet" workspace.
# Neither home has a data/projects.md registry, so the Fleet name defaults to
# the project clone basename.
PROJ1_FLEET="$(basename "$PROJ1")-Fleet"
PROJ2_FLEET="$(basename "$PROJ2")-Fleet"

ws_label_of_pane() {  # <pane_id> -> the herdr workspace label hosting that pane
  local pane=$1 wsid
  wsid=$(herdr pane get "$pane" --session "$SESSION" 2>/dev/null | jq -r '.result.pane.workspace_id // empty')
  [ -n "$wsid" ] || return 1
  herdr workspace list --session "$SESSION" 2>&1 | jq -r --arg id "$wsid" '.result.workspaces[]? | select(.workspace_id == $id) | .label'
}

# --- 1. an ordinary worker lands in its PROJECT's own "<name>-Fleet" space ---

CM1_OUT="$TMP_ROOT/cm1.out"; CM1_ERR="$TMP_ROOT/cm1.err"
FM_SPAWN_NO_GUARD=1 FM_HOME="$PRIMARY_HOME" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-spawn.sh" cm1 "$PROJ1" "sh -c 'echo primary-crew-ok'" --backend herdr \
  >"$CM1_OUT" 2>"$CM1_ERR"
rc=$?
[ "$rc" -eq 0 ] || fail "PROJ1 worker spawn failed"$'\n'"--- stdout ---"$'\n'"$(cat "$CM1_OUT")"$'\n'"--- stderr ---"$'\n'"$(cat "$CM1_ERR")"

CM1_META="$PRIMARY_HOME/state/cm1.meta"
[ -f "$CM1_META" ] || fail "no meta written for cm1"
assert_contains_local "$(cat "$CM1_META")" "backend=herdr" "cm1 meta missing backend=herdr"
WT1=$(grep '^worktree=' "$CM1_META" | cut -d= -f2-)
CM1_PANE=$(grep '^herdr_pane_id=' "$CM1_META" | cut -d= -f2-)
[ -n "$CM1_PANE" ] || fail "cm1 meta missing herdr_pane_id"
pass "real herdr E2E: a worker for PROJ1 spawns on the herdr backend"

sleep 1
CM1_CAPTURE=$(fm_backend_herdr_capture "$SESSION:$CM1_PANE" 30) || fail "capture failed on cm1's pane"
assert_contains_local "$CM1_CAPTURE" "primary-crew-ok" "cm1's raw launch command did not run in its herdr pane"

CM1_WSID=$(herdr pane get "$CM1_PANE" --session "$SESSION" 2>/dev/null | jq -r '.result.pane.workspace_id // empty')
[ -n "$CM1_WSID" ] || fail "could not read cm1's pane workspace_id"
CM1_WS_LABEL=$(ws_label_of_pane "$CM1_PANE")
[ "$CM1_WS_LABEL" = "$PROJ1_FLEET" ] || fail "a PROJ1 worker should land in the '$PROJ1_FLEET' workspace, got '$CM1_WS_LABEL'"
pass "real herdr E2E: the PROJ1 worker landed in its project's '$PROJ1_FLEET' workspace"

# --- 2. the PRIMARY spawns a secondmate: its tab lands in its Archon space ---
# The persistent secondmate agent keeps its own "Archon-<id>" supervisor
# workspace (never a Fleet worker label), read from the .fm-secondmate-home
# marker at the secondmate's home.

SM_OUT="$TMP_ROOT/sm.out"; SM_ERR="$TMP_ROOT/sm.err"
FM_SPAWN_NO_GUARD=1 FM_HOME="$PRIMARY_HOME" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-spawn.sh" e2esm1 "$SM_HOME" "sh -c 'echo secondmate-launch-ok'" --secondmate --backend herdr \
  >"$SM_OUT" 2>"$SM_ERR"
rc=$?
[ "$rc" -eq 0 ] || fail "the primary's --secondmate spawn of e2esm1 failed"$'\n'"--- stdout ---"$'\n'"$(cat "$SM_OUT")"$'\n'"--- stderr ---"$'\n'"$(cat "$SM_ERR")"

SM_META="$PRIMARY_HOME/state/e2esm1.meta"
[ -f "$SM_META" ] || fail "no meta written for e2esm1 (recorded in the PRIMARY's own state dir, since the primary did the spawning)"
assert_contains_local "$(cat "$SM_META")" "kind=secondmate" "e2esm1 meta missing kind=secondmate"
assert_contains_local "$(cat "$SM_META")" "backend=herdr" "e2esm1 meta missing backend=herdr"
assert_contains_local "$(cat "$SM_META")" "home=$SM_HOME" "e2esm1 meta does not record its own home"
SM_PANE=$(grep '^herdr_pane_id=' "$SM_META" | cut -d= -f2-)
[ -n "$SM_PANE" ] || fail "e2esm1 meta missing herdr_pane_id"
pass "real herdr E2E: the primary spawns a --secondmate task on the herdr backend"

SM_WSID=$(herdr pane get "$SM_PANE" --session "$SESSION" 2>/dev/null | jq -r '.result.pane.workspace_id // empty')
[ -n "$SM_WSID" ] || fail "could not read e2esm1's pane workspace_id"
[ "$SM_WSID" != "$CM1_WSID" ] || fail "the secondmate's tab must NOT land in a worker's Fleet workspace, but it shares $CM1_WSID"
SM_WS_LABEL=$(ws_label_of_pane "$SM_PANE")
[ "$SM_WS_LABEL" = "Archon-e2esm1" ] || fail "a --secondmate spawn should land in 'Archon-<id>', got '$SM_WS_LABEL'"
pass "real herdr E2E: a --secondmate spawn lands in its own 'Archon-<id>' supervisor workspace, never a Fleet worker label"

# --- 3. cross-home SAME-project sharing: a worker for PROJ1 spawned FROM the
# secondmate home lands in the SAME "<PROJ1>-Fleet" workspace as cm1, proving
# the workspace is keyed by PROJECT, not by the spawning home ----------------

CM2_OUT="$TMP_ROOT/cm2.out"; CM2_ERR="$TMP_ROOT/cm2.err"
FM_SPAWN_NO_GUARD=1 FM_HOME="$SM_HOME" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-spawn.sh" cm2 "$PROJ1" "sh -c 'echo sm-crew-ok'" --backend herdr \
  >"$CM2_OUT" 2>"$CM2_ERR"
rc=$?
[ "$rc" -eq 0 ] || fail "a PROJ1 worker spawned FROM the secondmate home failed"$'\n'"--- stdout ---"$'\n'"$(cat "$CM2_OUT")"$'\n'"--- stderr ---"$'\n'"$(cat "$CM2_ERR")"

CM2_META="$SM_HOME/state/cm2.meta"
[ -f "$CM2_META" ] || fail "no meta written for cm2 (recorded in the SECONDMATE's own state dir - it did its own spawning)"
assert_contains_local "$(cat "$CM2_META")" "backend=herdr" "cm2 meta missing backend=herdr"
WT2=$(grep '^worktree=' "$CM2_META" | cut -d= -f2-)
CM2_PANE=$(grep '^herdr_pane_id=' "$CM2_META" | cut -d= -f2-)
[ -n "$CM2_PANE" ] || fail "cm2 meta missing herdr_pane_id"
pass "real herdr E2E: a second PROJ1 worker spawns FROM the secondmate home's own fm-spawn.sh process"

sleep 1
CM2_CAPTURE=$(fm_backend_herdr_capture "$SESSION:$CM2_PANE" 30) || fail "capture failed on cm2's pane"
assert_contains_local "$CM2_CAPTURE" "sm-crew-ok" "cm2's raw launch command did not run in its herdr pane"

CM2_WSID=$(herdr pane get "$CM2_PANE" --session "$SESSION" 2>/dev/null | jq -r '.result.pane.workspace_id // empty')
CM2_WS_LABEL=$(ws_label_of_pane "$CM2_PANE")
[ "$CM2_WS_LABEL" = "$PROJ1_FLEET" ] || fail "a PROJ1 worker must land in '$PROJ1_FLEET' regardless of spawning home, got '$CM2_WS_LABEL'"
[ "$CM2_WSID" = "$CM1_WSID" ] || fail "two workers for PROJ1 must SHARE one workspace even across homes (cm1=$CM1_WSID cm2=$CM2_WSID)"
[ "$CM2_WSID" != "$SM_WSID" ] || fail "a PROJ1 worker must NOT land in the secondmate's Archon workspace - the supervisor identity must not capture workers"
pass "real herdr E2E: two workers for one project SHARE its Fleet workspace across different homes (project-keyed, not home-keyed)"

# --- 4. cross-project separation: a worker for a DIFFERENT project gets a
# DIFFERENT workspace ---------------------------------------------------------

CM3_OUT="$TMP_ROOT/cm3.out"; CM3_ERR="$TMP_ROOT/cm3.err"
FM_SPAWN_NO_GUARD=1 FM_HOME="$SM_HOME" FM_ROOT_OVERRIDE="$ROOT" \
  "$ROOT/bin/fm-spawn.sh" cm3 "$PROJ2" "sh -c 'echo sm-crew2-ok'" --backend herdr \
  >"$CM3_OUT" 2>"$CM3_ERR"
rc=$?
[ "$rc" -eq 0 ] || fail "a PROJ2 worker spawn failed"$'\n'"--- stdout ---"$'\n'"$(cat "$CM3_OUT")"$'\n'"--- stderr ---"$'\n'"$(cat "$CM3_ERR")"

CM3_META="$SM_HOME/state/cm3.meta"
[ -f "$CM3_META" ] || fail "no meta written for cm3"
WT3=$(grep '^worktree=' "$CM3_META" | cut -d= -f2-)
CM3_PANE=$(grep '^herdr_pane_id=' "$CM3_META" | cut -d= -f2-)
[ -n "$CM3_PANE" ] || fail "cm3 meta missing herdr_pane_id"
CM3_WSID=$(herdr pane get "$CM3_PANE" --session "$SESSION" 2>/dev/null | jq -r '.result.pane.workspace_id // empty')
CM3_WS_LABEL=$(ws_label_of_pane "$CM3_PANE")
[ "$CM3_WS_LABEL" = "$PROJ2_FLEET" ] || fail "a PROJ2 worker should land in '$PROJ2_FLEET', got '$CM3_WS_LABEL'"
[ "$CM3_WSID" != "$CM1_WSID" ] || fail "PROJ2 and PROJ1 workers must never share a workspace"
[ "$CM3_WSID" != "$SM_WSID" ] || fail "a PROJ2 worker must not land in the secondmate's Archon workspace"
pass "real herdr E2E: a worker for a different project gets a distinct '$PROJ2_FLEET' workspace - projects never share (cross-project separation)"

# --- 5. list-live recovery: scoped to the given project's own Fleet ---------

PROJ1_LIVE=$(fm_backend_herdr_list_live "$SESSION" "$PROJ1_FLEET")
assert_contains_local "$PROJ1_LIVE" "fm-cm1" "the PROJ1 Fleet's list_live did not see its own worker cm1"
assert_contains_local "$PROJ1_LIVE" "fm-cm2" "the PROJ1 Fleet's list_live did not see the second PROJ1 worker cm2 (same project, different home)"
assert_not_contains_local "$PROJ1_LIVE" "fm-cm3" "the PROJ1 Fleet's list_live must not see a different project's worker"
assert_not_contains_local "$PROJ1_LIVE" "fm-e2esm1" "the PROJ1 Fleet's list_live must not see the secondmate agent"
pass "real herdr E2E: list_live for a project's Fleet sees exactly that project's workers, across homes, and no other"

SM_LIVE=$(fm_backend_herdr_list_live "$SESSION" "Archon-e2esm1")
assert_contains_local "$SM_LIVE" "fm-e2esm1" "the secondmate's Archon list_live did not see its own task"
assert_not_contains_local "$SM_LIVE" "fm-cm1" "the secondmate's Archon list_live must not see a worker's task"
assert_not_contains_local "$SM_LIVE" "fm-cm2" "the secondmate's Archon list_live must not see a worker's task"
pass "real herdr E2E: list_live for the secondmate's Archon workspace sees only the secondmate's own task, never workers"

# --- 6. teardown closes the RIGHT tab, and no other ------------------------
# cm1 and cm2 share one PROJ1 Fleet workspace, so tearing down one must leave
# the other's tab (same workspace) untouched - the prune-only-the-right-tab
# property now within a genuinely shared workspace.

TD1_OUT="$TMP_ROOT/td1.out"
FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$PRIMARY_HOME/state" FM_DATA_OVERRIDE="$PRIMARY_HOME/data" \
  FM_CONFIG_OVERRIDE="$PRIMARY_HOME/config" \
  "$ROOT/bin/fm-teardown.sh" cm1 >"$TD1_OUT" 2>&1
rc=$?
[ "$rc" -eq 0 ] || fail "fm-teardown.sh failed for the PROJ1 worker cm1"$'\n'"$(cat "$TD1_OUT")"
[ -f "$CM1_META" ] && fail "fm-teardown.sh did not remove cm1's meta"
if herdr pane get "$CM1_PANE" --session "$SESSION" >/dev/null 2>&1; then
  fail "fm-teardown.sh did not close cm1's pane"
fi
if ! herdr pane get "$CM2_PANE" --session "$SESSION" >/dev/null 2>&1; then
  fail "tearing down cm1 must not have closed cm2's pane (same PROJ1 Fleet workspace - wrong tab closed)"
fi
if ! herdr pane get "$SM_PANE" --session "$SESSION" >/dev/null 2>&1; then
  fail "tearing down cm1 must not have closed the secondmate's OWN pane (wrong tab closed)"
fi
if ! herdr pane get "$CM3_PANE" --session "$SESSION" >/dev/null 2>&1; then
  fail "tearing down cm1 must not have closed the PROJ2 worker cm3's pane (wrong tab closed)"
fi
WT1=
pass "real herdr E2E: tearing down cm1 closes only its own tab - cm2 (same Fleet), the secondmate, and cm3 survive untouched"

TD2_OUT="$TMP_ROOT/td2.out"
FM_ROOT_OVERRIDE="$ROOT" FM_STATE_OVERRIDE="$SM_HOME/state" FM_DATA_OVERRIDE="$SM_HOME/data" \
  FM_CONFIG_OVERRIDE="$SM_HOME/config" \
  "$ROOT/bin/fm-teardown.sh" cm2 >"$TD2_OUT" 2>&1
rc=$?
[ "$rc" -eq 0 ] || fail "fm-teardown.sh failed for the PROJ1 worker cm2"$'\n'"$(cat "$TD2_OUT")"
[ -f "$CM2_META" ] && fail "fm-teardown.sh did not remove cm2's meta"
if herdr pane get "$CM2_PANE" --session "$SESSION" >/dev/null 2>&1; then
  fail "fm-teardown.sh did not close cm2's pane"
fi
if ! herdr pane get "$SM_PANE" --session "$SESSION" >/dev/null 2>&1; then
  fail "tearing down cm2 must not have closed the secondmate's OWN pane (wrong tab closed)"
fi
WT2=
pass "real herdr E2E: tearing down cm2 closes only its own tab - the secondmate's own tab survives untouched"

fm_backend_herdr_kill "$SESSION:$CM3_PANE"
fm_backend_herdr_kill "$SESSION:$SM_PANE"

cleanup_all
trap - EXIT
