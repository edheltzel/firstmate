#!/usr/bin/env bash
# Present durable watcher wake records, optionally acknowledge handled records,
# annotate every unread line for validated signal status keys, surface unread
# informational status lines, latest captain-facing statuses not covered by a
# newer branch outcome, OPEN DECISIONS, and captain-call record divergence,
# then assert liveness.
#
# Keep sequence-bound row consumption independent from generation-bound episode
# retirement; docs/watcher-continuity.md owns the recovery contract.
# FM_STATUS_PRESENTATION_LOCK_TIMEOUT sets the positive whole-second wait for
# presentation-path locks (default 10); queue mutation locks remain blocking.
set -u

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=bin/fm-wake-lib.sh
. "$SCRIPT_DIR/fm-wake-lib.sh"
# shellcheck source=bin/fm-classify-lib.sh
. "$SCRIPT_DIR/fm-classify-lib.sh"

DRAIN_TMP=
DRAIN_VIEW_TMP=
DRAIN_LOCK_HELD=false
RAW_ROWS=
RECOVERY_MARKER="$STATE/.watcher-down"
RECOVERY_MARKER_TOKEN=
RECOVERY_ACK_REQUIRED=false
RECOVERY_ACK_MOVED=false
ACK_THROUGH=
ACK_GENERATION=
ACK_FINGERPRINTS=
ACK_NOTICE_FINGERPRINTS=
PRESENTATION_LOCK_TIMEOUT=${FM_STATUS_PRESENTATION_LOCK_TIMEOUT:-10}
case "$PRESENTATION_LOCK_TIMEOUT" in ''|*[!0-9]*|0) PRESENTATION_LOCK_TIMEOUT=10 ;; esac

# --- per-actor consume (docs/watcher-continuity.md "Per-actor acknowledgement") --
# main (FM_SUPERVISION_ACTOR unset or "main", via fm-lease-lib.sh's fm_lease_actor
# - the same actor identity fm-send.sh/fm-control.sh/fm-teardown.sh already use)
# claims every row not already granted to branch, then drains and acks only
# that claimed set. branch (FM_SUPERVISION_ACTOR=branch, injected
# deterministically by the Pi branch extension's bash tool - never agent
# memory) drains and acks only the row set the extension granted to it.
# .pi/extensions/lib/fm-branch-dispatch.ts is the single owner of that
# eligibility classification (which signal/stale rows resolve to a known
# project, and the existing all-unread-rows-safe rule for a heartbeat); this
# script never reclassifies a row itself, it only consumes the extension's
# already-computed verdict. The extension writes the exact eligible sequence
# numbers to ELIGIBLE_ROWS_FILE under the queue lock, immediately before every
# branch prompt, so the file is always fresh for the one wake that prompt is about to
# handle (the branch drains and acks exactly once per prompt, serialized by
# its own branchChain, before the next wake can overwrite the file).
# A row whose sequence number is not in that file is left completely
# untouched by a branch-actor drain or ack, no matter its sequence number
# relative to what the branch presents or consumes - that per-row scoping,
# not a cutoff comparison, is what makes a mixed main-only + task-local queue
# safe to split: the branch's ack can never remove a row it was not granted,
# so it can never swallow a main-owned row still waiting for main.
ACTOR=$(fm_lease_actor) || exit 2
ELIGIBLE_ROWS_FILE="$STATE/.branch-eligible-rows"
ELIGIBLE_OWNER_FILE="$STATE/.branch-eligible-owner"
MAIN_ROWS_FILE="$STATE/.main-eligible-rows"

rows_file_valid() {
  [ -s "$1" ] && awk 'BEGIN { ok=1 } !/^[0-9]+$/ || seen[$0]++ { ok=0 } END { exit !ok }' "$1"
}

branch_grant_live_locked() {
  local version pid identity generation current
  [ -f "$ELIGIBLE_OWNER_FILE" ] && [ ! -L "$ELIGIBLE_OWNER_FILE" ] || return 1
  exec 8< "$ELIGIBLE_OWNER_FILE" || return 1
  IFS= read -r version <&8 || { exec 8<&-; return 1; }
  IFS= read -r pid <&8 || { exec 8<&-; return 1; }
  IFS= read -r identity <&8 || { exec 8<&-; return 1; }
  IFS= read -r generation <&8 || { exec 8<&-; return 1; }
  if IFS= read -r _extra <&8; then exec 8<&-; return 1; fi
  exec 8<&-
  [ "$version" = fm-branch-eligible-owner-v1 ] || return 1
  case "$pid" in ''|*[!0-9]*|1) return 1 ;; esac
  case "$generation" in ''|*[!A-Za-z0-9._-]*) return 1 ;; esac
  current=$(fm_pid_identity "$pid" 2>/dev/null) || return 1
  [ -n "$current" ] && [ "$current" = "$identity" ]
}

reclaim_stale_branch_grant_locked() {
  [ -e "$ELIGIBLE_ROWS_FILE" ] || [ -L "$ELIGIBLE_ROWS_FILE" ] || return 0
  if ! rows_file_valid "$ELIGIBLE_ROWS_FILE" || ! branch_grant_live_locked; then
    rm -f -- "$ELIGIBLE_ROWS_FILE" "$ELIGIBLE_OWNER_FILE"
  fi
}

write_rows_file_locked() { # <target> <source>
  local target=$1 source=$2
  if [ ! -s "$source" ]; then
    rm -f -- "$target"
    return
  fi
  chmod 0600 "$source" || return 1
  _fm_atomic_replace "$source" "$target"
}

claim_main_rows_locked() {
  DRAIN_TMP=$(mktemp "$STATE/.main-eligible-rows.tmp.XXXXXX") || return 1
  awk -F '\t' -v branch="$ELIGIBLE_ROWS_FILE" -v main="$MAIN_ROWS_FILE" '
    BEGIN {
      while ((getline line < branch) > 0) reserved[line]=1
      while ((getline line < main) > 0) owned[line]=1
    }
    NF >= 5 && $2 ~ /^[0-9]+$/ {
      present[$2]=1
      if (!($2 in reserved)) owned[$2]=1
    }
    END { for (seq in owned) if (seq in present) print seq }
  ' "$FM_WAKE_QUEUE" | LC_ALL=C sort -n > "$DRAIN_TMP" || return 1
  write_rows_file_locked "$MAIN_ROWS_FILE" "$DRAIN_TMP" || return 1
  DRAIN_TMP=
}

consume_actor_rows_locked() { # <rows-file> <cutoff>
  local rows=$1 cutoff=$2
  if [ ! -e "$rows" ] && [ ! -L "$rows" ]; then
    return 0
  fi
  DRAIN_TMP=$(mktemp "$STATE/.wake-rows.consume.XXXXXX") || return 1
  awk -v cutoff="$cutoff" '$1 ~ /^[0-9]+$/ && $1 > cutoff { print $1 }' "$rows" > "$DRAIN_TMP" || return 1
  write_rows_file_locked "$rows" "$DRAIN_TMP" || return 1
  DRAIN_TMP=
}

# A branch-actor drain or ack requires a snapshot to already exist and name at
# least one row. The extension always writes a non-empty snapshot before it
# ever prompts the branch (an empty eligible set means no prompt at all), so a
# missing or empty file here means this ran outside that handoff - a wiring
# bug, never "nothing eligible" - and must fail loudly rather than silently
# draining or acking nothing.
require_branch_eligible_rows() {
  rows_file_valid "$ELIGIBLE_ROWS_FILE" || {
    echo "wake drain: no branch-eligible row snapshot at $ELIGIBLE_ROWS_FILE; refusing to guess what this actor may consume" >&2
    return 1
  }
}

case "${1:-}" in
  '') ;;
  --ack-through)
    ACK_THROUGH=${2:-}
    case "$ACK_THROUGH" in ''|*[!0-9]*) echo "wake drain: invalid acknowledgement sequence" >&2; exit 2 ;; esac
    [ "${3:-}" = --recovery-generation ] \
      || { echo "wake drain: acknowledgement requires its recovery generation" >&2; exit 2; }
    ACK_GENERATION=${4:-}
    case "$ACK_GENERATION" in ''|*[!A-Za-z0-9._-]*) echo "wake drain: invalid recovery generation" >&2; exit 2 ;; esac
    [ "$#" -eq 4 ] || { echo "wake drain: unexpected acknowledgement arguments" >&2; exit 2; }
    ;;
  *) echo "usage: fm-wake-drain.sh [--ack-through SEQUENCE --recovery-generation GENERATION]" >&2; exit 2 ;;
esac

[ "$ACTOR" != branch ] || require_branch_eligible_rows || exit 1

# Defense in depth for the supervision chain: this script runs at the top of
# every wake-handling and recovery turn, so assert supervision health here too. A
# lapsed supervision chain then surfaces on a plain drain-and-handle turn, not
# only when a guarded supervision script (fm-peek/fm-send/...) happens to run.
# Reuse fm-guard.sh's model-aware alarm and FM_GUARD_GRACE instead of duplicating
# its supervision verdict. Under Claude's between-turns auto-arm model, a normal
# fire leaves a recent beacon well inside grace and stays silent mid-turn. Under
# persistent-watcher models, the guard also requires the live identity-matched
# watcher. Call after the queue is emptied so guard never re-prints its own
# queued-wakes notice for the records this run just drained, and never let a
# guard hiccup change the drain's exit status.
assert_watcher_liveness() {
  "$SCRIPT_DIR/fm-guard.sh" || true
}

# Print the consolidated OPEN DECISIONS section: every still-open
# needs-decision/blocked, fleet-wide, folded from the durable status logs by
# fm-classify-lib.sh's status_open_decisions (via its scan_open_decisions
# wrapper) rather than from the latest-line annotations above, so a decision
# buried under later unrelated appends cannot be silently missed. Runs on
# every drain - including the empty-queue fast path - because the decision can
# still be open even when nothing new is queued for its task this turn.
# Bounded and silent: prints nothing when no decision is open, which is the
# common case.
print_open_decisions_section() {
  local open task key verb note line item_bytes=220 global_bytes=4000
  local output='' used=0 shown=0 omitted=0 bytes suffix keep

  open=$(scan_open_decisions "$STATE") || return 0
  [ -n "$open" ] || return 0

  while IFS=$(printf '\t') read -r task key verb note; do
    [ -n "$task" ] || continue
    line="$task"
    [ "$key" = default ] || line="$line [key=$key]"
    line="$line $verb: $note"
    if [ $(( ${#line} + 1 )) -gt "$item_bytes" ]; then
      suffix=' [truncated]'
      keep=$((item_bytes - ${#suffix} - 1))
      line="${line:0:$keep}$suffix"
    fi
    bytes=$(( ${#line} + 1 ))
    if [ $((used + bytes)) -gt "$global_bytes" ]; then
      omitted=$((omitted + 1))
      continue
    fi
    output="$output$line
"
    used=$((used + bytes))
    shown=$((shown + 1))
  done <<EOF
$open
EOF

  [ "$shown" -gt 0 ] || [ "$omitted" -gt 0 ] || return 0
  printf 'OPEN DECISIONS (still open, folded from the durable status logs - not just the latest line):\n'
  printf '%s' "$output"
  if [ "$omitted" -gt 0 ]; then
    printf 'OPEN DECISIONS: %d more omitted (byte cap)\n' "$omitted"
  fi
}

# shellcheck disable=SC2317,SC2329 # Invoked by trap handlers below.
cleanup() {
  local status=$?
  [ -z "$DRAIN_TMP" ] || rm -f -- "$DRAIN_TMP" 2>/dev/null || true
  [ -z "$DRAIN_VIEW_TMP" ] || rm -f -- "$DRAIN_VIEW_TMP" 2>/dev/null || true
  if [ "$DRAIN_LOCK_HELD" = true ]; then
    fm_lock_release "$FM_WAKE_QUEUE_LOCK"
  fi
  exit "$status"
}

trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

if [ -n "$ACK_THROUGH" ]; then
  fm_lock_acquire_wait "$FM_WAKE_QUEUE_LOCK"
elif fm_lock_acquire_wait_bounded "$FM_WAKE_QUEUE_LOCK" "$PRESENTATION_LOCK_TIMEOUT"; then
  :
else
  lock_rc=$?
  if [ "$lock_rc" -eq 124 ]; then
    printf 'WAKE DRAIN SKIPPED: queue lock remains held by live pid %s after %ss; retry on the next drain.\n' \
      "${FM_LOCK_HELD_PID:-unknown}" "$PRESENTATION_LOCK_TIMEOUT"
    exit 0
  fi
  printf 'wake drain: queue lock could not be acquired safely\n' >&2
  exit 1
fi
DRAIN_LOCK_HELD=true
reclaim_stale_branch_grant_locked || exit 1
[ "$ACTOR" != branch ] || require_branch_eligible_rows || exit 1

if [ -n "$ACK_THROUGH" ]; then
  if [ "$ACTOR" = main ]; then
    # Preserve main's original whole-cutoff acknowledgement contract: rows may
    # arrive after presentation but before the printed ack runs, and a direct
    # or replayed main ack still owns every unreserved row through its cutoff.
    # Claim again under the queue lock so those rows cannot be stranded merely
    # because they were not present during the earlier drain. A live branch
    # grant remains excluded by claim_main_rows_locked.
    claim_main_rows_locked || exit 1
  fi
  if [ "$ACTOR" = branch ]; then
    # check-kind rows (inactive-outcome receipts, secondmate stall markers)
    # are never in a branch's eligible snapshot - they are main-only by
    # construction (docs/pi-supervision-branch.md) - so a branch-actor ack
    # never removes one and these scans would find nothing relevant anyway.
    ACK_FINGERPRINTS=
    ACK_NOTICE_FINGERPRINTS=
  else
    if { [ -e "$MAIN_ROWS_FILE" ] || [ -L "$MAIN_ROWS_FILE" ]; } \
      && ! rows_file_valid "$MAIN_ROWS_FILE"; then
      echo "wake drain: main acknowledgement has an invalid presented-row claim" >&2
      exit 1
    fi
    ACK_FINGERPRINTS=$(inactive_outcome_fingerprints "$ACK_THROUGH" 'inactive-outcome:' "$MAIN_ROWS_FILE") || exit 1
    ACK_NOTICE_FINGERPRINTS=$(inactive_outcome_fingerprints "$ACK_THROUGH" 'inactive-reconcile:' "$MAIN_ROWS_FILE") || exit 1
  fi
  fm_lock_release "$FM_WAKE_QUEUE_LOCK"
  DRAIN_LOCK_HELD=false
  if ! acknowledge_inactive_outcomes acknowledge "$ACK_FINGERPRINTS" \
    || ! acknowledge_inactive_outcomes acknowledge-notice "$ACK_NOTICE_FINGERPRINTS"; then
    echo "wake drain: inactive outcome receipt could not be recorded safely" >&2
    exit 1
  fi
  fm_lock_acquire_wait "$FM_WAKE_QUEUE_LOCK"
  DRAIN_LOCK_HELD=true
  DRAIN_TMP=$(mktemp "$STATE/.wake-queue.ack.XXXXXX") || exit 1
  chmod 0600 "$DRAIN_TMP" || exit 1
  if [ "$ACTOR" = branch ]; then
    require_branch_eligible_rows || exit 1
    # Delete a row only when its sequence is <= cutoff AND it is named in the
    # extension's eligible snapshot; every other row - including one whose
    # sequence is below cutoff but not in the snapshot - is kept untouched.
    awk -F '\t' -v cutoff="$ACK_THROUGH" -v seqs="$ELIGIBLE_ROWS_FILE" '
      BEGIN { while ((getline line < seqs) > 0) if (line ~ /^[0-9]+$/) keep[line] = 1 }
      NF < 5 || $2 !~ /^[0-9]+$/ || $2 > cutoff || !($2 in keep) { print }
    ' "$FM_WAKE_QUEUE" > "$DRAIN_TMP" || exit 1
  else
    awk -F '\t' -v cutoff="$ACK_THROUGH" -v seqs="$MAIN_ROWS_FILE" '
      BEGIN { while ((getline line < seqs) > 0) owned[line]=1 }
      NF < 5 || $2 !~ /^[0-9]+$/ || $2 > cutoff || !($2 in owned) { print }
    ' "$FM_WAKE_QUEUE" > "$DRAIN_TMP" || exit 1
    fm_wake_commit_secondmate_stall_receipts_through "$ACK_THROUGH" "$MAIN_ROWS_FILE" || {
      echo "wake drain: secondmate stall receipt could not be recorded safely" >&2
      exit 1
    }
  fi
  if [ ! -s "$DRAIN_TMP" ]; then
    fm_recovery_marker_ack "$RECOVERY_MARKER" "$ACK_GENERATION"
    RECOVERY_ACK_STATUS=$?
    case "$RECOVERY_ACK_STATUS" in
      0) ;;
      3) RECOVERY_ACK_MOVED=true ;;
      *)
        echo "wake drain: recovery episode could not be retired safely; re-run bin/fm-wake-drain.sh and use the new WAKE_ACK_REQUIRED command" >&2
        exit 1
        ;;
    esac
  else
    fm_recovery_marker_snapshot "$RECOVERY_MARKER" || exit 1
    RECOVERY_MARKER_TOKEN=$FM_RECOVERY_MARKER_TOKEN
    if [ "${RECOVERY_MARKER_TOKEN##*:}" != "$ACK_GENERATION" ]; then
      RECOVERY_ACK_MOVED=true
    fi
  fi
  if ! _fm_atomic_replace "$DRAIN_TMP" "$FM_WAKE_QUEUE"; then
    echo "wake drain: acknowledged wakes could not be consumed safely" >&2
    exit 1
  fi
  DRAIN_TMP=
  if [ "$ACTOR" = branch ]; then
    consume_actor_rows_locked "$ELIGIBLE_ROWS_FILE" "$ACK_THROUGH" || exit 1
  else
    consume_actor_rows_locked "$MAIN_ROWS_FILE" "$ACK_THROUGH" || exit 1
  fi
  fm_lock_release "$FM_WAKE_QUEUE_LOCK"
  DRAIN_LOCK_HELD=false
  if [ "$RECOVERY_ACK_MOVED" = true ]; then
    printf 'wake drain: acknowledged wakes through %s, but a newer recovery episode is pending; re-run bin/fm-wake-drain.sh and use the new WAKE_ACK_REQUIRED command\n' \
      "$ACK_THROUGH" >&2
  fi
  exit 0
fi

if [ ! -s "$FM_WAKE_QUEUE" ]; then
  : > "$FM_WAKE_QUEUE"
  fm_lock_release "$FM_WAKE_QUEUE_LOCK"
  DRAIN_LOCK_HELD=false
  (print_open_decisions_section) || true
  assert_watcher_liveness
  exit 0
fi

if [ "$ACTOR" = main ]; then
  if [ -e "$ELIGIBLE_ROWS_FILE" ] || [ -L "$ELIGIBLE_ROWS_FILE" ]; then
    require_branch_eligible_rows || exit 1
  fi
  claim_main_rows_locked || exit 1
  if [ ! -s "$MAIN_ROWS_FILE" ]; then
    fm_lock_release "$FM_WAKE_QUEUE_LOCK"
    DRAIN_LOCK_HELD=false
    (print_status_presentation) || true
    assert_watcher_liveness
    exit 0
  fi
fi

fm_recovery_marker_snapshot "$RECOVERY_MARKER" || true
RECOVERY_MARKER_TOKEN=$FM_RECOVERY_MARKER_TOKEN
if [ -z "$RECOVERY_MARKER_TOKEN" ]; then
  if [ -e "$RECOVERY_MARKER" ] || [ -L "$RECOVERY_MARKER" ]; then
    echo "wake drain: durable wakes have invalid recovery state" >&2
    exit 1
  fi
  fm_recovery_marker_publish "$RECOVERY_MARKER" downtime || {
    echo "wake drain: legacy durable wakes could not be adopted safely" >&2
    exit 1
  }
elif [ "${RECOVERY_MARKER_TOKEN%%:*}" = acked ]; then
  fm_recovery_marker_publish "$RECOVERY_MARKER" downtime || {
    echo "wake drain: durable wakes could not enter a fresh recovery generation" >&2
    exit 1
  }
fi
fm_recovery_marker_begin_handling "$RECOVERY_MARKER" || {
  echo "wake drain: durable wakes could not begin handling safely" >&2
  exit 1
}
RECOVERY_MARKER_TOKEN=$FM_RECOVERY_MARKER_TOKEN

DRAIN_VIEW_TMP=$(mktemp "$STATE/.wake-queue.actor-view.XXXXXX") || exit 1
if [ "$ACTOR" = branch ]; then
  ACTOR_ROWS_FILE=$ELIGIBLE_ROWS_FILE
else
  ACTOR_ROWS_FILE=$MAIN_ROWS_FILE
fi
awk -F '\t' -v seqs="$ACTOR_ROWS_FILE" '
  BEGIN { while ((getline line < seqs) > 0) keep[line]=1 }
  NF >= 5 && ($2 in keep)
' "$FM_WAKE_QUEUE" > "$DRAIN_VIEW_TMP" || exit 1
RAW_ROWS=$(fm_wake_print_deduped "$DRAIN_VIEW_TMP") || exit "$?"
rm -f -- "$DRAIN_VIEW_TMP" || exit 1
DRAIN_VIEW_TMP=
ACK_THROUGH=$(printf '%s\n' "$RAW_ROWS" | awk -F '\t' '$2 ~ /^[0-9]+$/ && $2 > max { max=$2 } END { print max + 0 }') || exit 1
case "${FM_WAKE_DRAIN_TEST_DELAY_BEFORE_COMMIT:-0}" in
  0) ;;
  ''|*[!0-9]*) ;;
  *) sleep "$FM_WAKE_DRAIN_TEST_DELAY_BEFORE_COMMIT" ;;
esac
if [ -n "$RAW_ROWS" ]; then
  printf '%s\n' "$RAW_ROWS" || exit "$?"
fi
fm_recovery_marker_snapshot "$RECOVERY_MARKER" || exit 1
RECOVERY_MARKER_TOKEN=$FM_RECOVERY_MARKER_TOKEN
case "$RECOVERY_MARKER_TOKEN" in
  pending:*|announced:*|acked:*) ;;
  *) echo "wake drain: durable wakes have no recovery generation" >&2; exit 1 ;;
esac
fm_lock_release "$FM_WAKE_QUEUE_LOCK"
DRAIN_LOCK_HELD=false
printf 'WAKE_ACK_REQUIRED: after handling completes run bin/fm-wake-drain.sh --ack-through %s --recovery-generation %s\n' \
  "$ACK_THROUGH" "${RECOVERY_MARKER_TOKEN##*:}" >&2

# Raw output and queue deletion are authoritative. Everything below is
# best-effort and cannot restore, duplicate, hide, or fail the consumed rows.
(fm_wake_print_annotations "$RAW_ROWS") || true
(print_open_decisions_section) || true
assert_watcher_liveness
exit 0
