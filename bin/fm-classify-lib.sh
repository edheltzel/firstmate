#!/usr/bin/env bash
# Shared wake classifier: the common source of truth for captain-relevant status
# tests, declared-external-wait vocabulary, and the working/paused absorb
# classification that makes no-verb signal and stale-pane wakes safe to absorb.
# Sourced by BOTH the always-on watcher
# (bin/fm-watch.sh) and the away-mode daemon (bin/fm-supervise-daemon.sh) so the
# overlapping triage policy lives in one place instead of two copies that can
# drift apart.
#
# Most functions are pure, side-effect-free reads of status files: each takes
# what it needs as arguments and touches no globals beyond the optional
# FM_CAPTAIN_RE override. Consumers layer their own dedup/marker state on top (the
# daemon keeps its escalation-digest seen-markers; the watcher keeps its .seen-*
# signatures).
# Status-span classification captures one file endpoint and reports every
# actionable event through that endpoint before the endpoint may be committed.
# An absent status file is a successful empty span, while an existing status
# object that cannot be read or identified is a classification failure with no
# committable endpoint.
# A presentation marker independently stores the last reported file signature
# and the last successfully classified position.
# Successful classification advances both facts through the captured endpoint;
# after a failure is reported, only the reported signature advances, so the same
# observed state alarms once while every unclassified byte remains for recovery.
# The reported signature includes path type, mode, symlink target, and observable
# failure kind, so a readability change is a new state that triggers another read.
# A missing, malformed, identity-mismatched, or past-end classified position reads
# from byte 0, preferring a bounded duplicate over a lost event.
#
# There are three documented exceptions. The absorb classification
# (crew_absorb_class and its working/paused wrappers) is NOT a pure status-file
# read: it reuses bin/fm-crew-state.sh, which may make a bounded no-mistakes call,
# to decide whether a crew that just stopped its turn or went stale is working,
# deliberately paused, or neither. Callers run it ONLY on no-verb signal handling
# and first sighting of a stale hash, never on every wake, so the per-wake triage
# stays cheap. status_open_decisions_incremental (see "incremental (cursor-backed)
# open-decisions fold" below) also writes: it persists a per-status-file byte
# cursor and folded open-set as a side effect, so a per-drain fleet-wide scan
# stays bounded by new appends instead of re-reading each task's whole lifetime
# log every time. crew_worktree_written_since reads the task's meta file and walks
# a bounded slice of its worktree instead of a status file, so callers run it only
# at the moment they would otherwise escalate.

# Directory of this library, used to locate the sibling fm-crew-state.sh reader.
# Resolved at source time from BASH_SOURCE so it works whether sourced by a
# bin/ script (which sets its own SCRIPT_DIR) or directly by a test.
_FM_CLASSIFY_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd 2>/dev/null)" || _FM_CLASSIFY_LIB_DIR="."

# The crew current-state reader used for the "provably working" decision.
# Overridable so tests can stub the run-step/pane verdict without a real worktree
# or no-mistakes install; absent, it points at the real sibling script.
FM_CREW_STATE_BIN="${FM_CREW_STATE_BIN:-$_FM_CLASSIFY_LIB_DIR/fm-crew-state.sh}"

# fm_run_timed, the shared hard bound the worktree write probe below puts around
# its one filesystem walk. bin/fm-timeout-lib.sh owns bounded execution for this
# repo, so nothing here re-derives the coreutils/BSD/perl selection. That library
# declares `set -u` for its own hygiene, which a sourced sibling must not impose on
# THIS library's consumers - several of them deliberately run without it - so the
# caller's setting is restored around the source.
case $- in *u*) _fm_classify_nounset=on ;; *) _fm_classify_nounset=off ;; esac
# shellcheck source=bin/fm-timeout-lib.sh
# shellcheck disable=SC1091
. "$_FM_CLASSIFY_LIB_DIR/fm-timeout-lib.sh"
[ "$_fm_classify_nounset" = on ] || set +u
unset _fm_classify_nounset

# Captain-relevant status verbs. A status line carrying any of these is work
# firstmate must see. Lines without these verbs are no-verb signals: the watcher
# absorbs them only with positive provably-working evidence, while the daemon uses
# its away-mode classification. FM_CAPTAIN_RE overrides the whole set when a home
# needs a custom verb vocabulary; absent, this default applies.
#
# Free-text tokens (PR ready, checks green, ready in branch, merged) exist only for
# legacy lines that lack a standard terminal verb. status_is_captain_relevant is
# verb-aware: a nonterminal working: or paused: line never becomes captain-relevant
# merely because its prose contains one of those tokens (for example
# "working: rebased onto merged #76").
FM_CLASSIFY_CAPTAIN_RE_DEFAULT='done:|needs-decision:|blocked:|failed:|PR ready|checks green|ready in branch|merged'

# The deliberate-external-wait verb. A crew (or firstmate steering it) appends
#   paused: <reason>
# to declare it is intentionally idling on a KNOWN external dependency - an
# upstream release, a vendor rate-limit reset, a scheduled window. Unlike
# `blocked:` (stuck, firstmate must help) an idle `paused:` pane is EXPECTED, so
# the stale path absorbs it instead of escalating a possible wedge. It is
# deliberately NOT in the captain-relevant set above: a pause is a "stop
# wedge-nagging this idle pane" signal, not work to keep surfacing. This constant
# is the ONE definition of the verb; both the watcher and the daemon read it here
# (status_is_paused) rather than hardcoding the literal, so the vocabulary cannot
# drift between the two consumers. FM_CLASSIFY_PAUSED_VERB overrides it.
FM_CLASSIFY_PAUSED_VERB_DEFAULT='paused'

# Bounded re-surface cadence for a declared pause or a verified captain hold.
# Far longer than the wedge threshold (FM_STALE_ESCALATE_SECS, default 240s), it
# avoids nagging a deliberate wait while ensuring a forgotten hold cannot rot
# invisibly - it re-surfaces once for a recheck every window. One hour by default;
# both consumers read FM_PAUSE_RESURFACE_SECS with this default so the cadence has
# one owner.
# shellcheck disable=SC2034 # Read by the watcher and daemon (fm-watch.sh, fm-supervise-daemon.sh), not this lib.
FM_PAUSE_RESURFACE_SECS_DEFAULT=3600

# The resolution verb and durable-backlog-transfer verb that CLOSE a keyed
# status decision opened by needs-decision or blocked. See status_open_decisions
# below for the status-fold contract. The transfer verb is written only after
# fm-captain-hold.sh has verified the corresponding captain-held backlog item.
FM_CLASSIFY_RESOLVE_VERB_DEFAULT='resolved'
FM_CLASSIFY_CAPTAIN_HELD_VERB_DEFAULT='captain-held'

# Return the last non-blank line of a status file (empty if missing/blank).
last_status_line() {
  local f=$1
  [ -e "$f" ] || return 0
  grep -v '^[[:space:]]*$' "$f" 2>/dev/null | tail -1
}

# 0 if the given (last) status line's leading verb is a real terminal captain verb
# (done, needs-decision, blocked, failed). Free-text tokens alone never count here;
# callers that need legacy free-text matching use status_is_captain_relevant.
status_is_terminal_verb() {
  local line=$1 verb
  [ -n "$line" ] || return 1
  verb=$(status_line_verb "$line")
  case "$verb" in
    done|needs-decision|blocked|failed) return 0 ;;
    *) return 1 ;;
  esac
}

# 0 if the given (last) status line matches a captain-relevant verb.
# Verb-aware by default: terminal verbs always match; nonterminal progress verbs
# (working, resolved, captain-held) and paused never match from free-text prose;
# only lines without those leading verbs may still match free-text tokens for
# legacy bare lines such as "merged" or "PR ready".
status_is_captain_relevant() {
  local line=$1 verb
  [ -n "$line" ] || return 1
  status_is_paused "$line" && return 1
  verb=$(status_line_verb "$line")
  case "$verb" in
    working|resolved|captain-held|"${FM_CLASSIFY_PAUSED_VERB:-$FM_CLASSIFY_PAUSED_VERB_DEFAULT}")
      return 1
      ;;
  esac
  if [ -z "${FM_CAPTAIN_RE+x}" ]; then
    case "$verb" in
      done|needs-decision|blocked|failed) return 0 ;;
    esac
  fi
  printf '%s' "$line" | grep -qiE "${FM_CAPTAIN_RE:-$FM_CLASSIFY_CAPTAIN_RE_DEFAULT}"
}

# 0 if a status line's leading verb is the pause verb (paused: <reason>). A pure
# read of the line itself, so the daemon's classify_stale can reuse the last line
# it already read without a fm-crew-state.sh call. Matches only the verb before the
# first colon, so a reason mentioning "paused" elsewhere does not false-match.
status_is_paused() {  # <status-line>
  local line=$1 verb
  [ -n "$line" ] || return 1
  verb=$(status_line_verb "$line")
  [ "$verb" = "${FM_CLASSIFY_PAUSED_VERB:-$FM_CLASSIFY_PAUSED_VERB_DEFAULT}" ]
}

# 0 if a status line's leading verb is the verified captain-held transfer verb.
# The same pure verb read as status_is_paused, and the discriminator a supervisor
# needs once a declared wait has already been recognized: the two declarations get
# the same bounded cadence, but they block on DIFFERENT humans, so a recheck that
# names an external dependency for a hold points the captain away from the fact
# that they are the one who can clear it.
status_is_captain_held() {  # <status-line>
  local line=$1 verb
  [ -n "$line" ] || return 1
  verb=$(status_line_verb "$line")
  [ "$verb" = "${FM_CLASSIFY_CAPTAIN_HELD_VERB:-$FM_CLASSIFY_CAPTAIN_HELD_VERB_DEFAULT}" ]
}

# 0 if a status line declares either an external-wait pause or a verified
# captain-held transfer.
# Both declarations can intentionally leave a crew's endpoint idle, so both
# supervisors give them one cadence: the away-mode daemon defers the wedge and
# ages a pause marker instead, and the watcher applies its bounded pause cadence
# once pause_state_class has admitted the wait (fm-watch.sh owns which liveness
# evidence each kind of crew must supply for that).
status_is_paused_or_captain_held() {  # <status-line>
  local line=$1
  status_is_paused "$line" || status_is_captain_held "$line"
}

# --- durable keyed decisions ------------------------------------------------
#
# The status stream is an append-only EVENT log. Reading it last-event-wins
# (last_status_line above) cannot represent "an earlier decision is still open
# after a later, unrelated event": a subsequent done/paused/working line silently
# masks a still-open needs-decision. status_open_decisions is the ONE authoritative
# statement of the status-fold contract that fixes this - a needs-decision/blocked
# line OPENS a keyed decision, and only an explicit resolution or a verified
# captain-held backlog transfer referencing that key CLOSES it; a later unrelated
# terminal line never clears an open captain decision.
# Who WRITES the closing line is owned elsewhere: the answering firstmate closes
# at answer time through fm-send's --resolve-key (bin/fm-send.sh header), and a
# worker self-closes only a blocker that cleared without an answer (bin/fm-brief.sh
# rule 6), so closure never depends on a busy worker's discipline.
#
# Decision key grammar (backward-compatible with the existing "<verb>: <note>"
# format): an OPTIONAL "[key=<slug>]" token names the decision. Its documented
# position sits between the verb and the colon, and a complete token at the
# head of the note is accepted as an EQUIVALENT position, because that
# misplaced-colon shape is common real worker output whose stated key must
# never silently collapse into the shared "default" bucket (issue #2109):
#   needs-decision [key=api-shape]: <summary>
#   needs-decision: [key=api-shape] <summary>
#   resolved       [key=api-shape]: <how it was decided>
# Both positions state the same key and yield the same note (a consumed
# note-head token is key metadata, stripped from the note); when both positions
# carry a token, the documented before-colon one wins and the note-head token
# stays note text. A token deeper inside the note is prose, never a stated key,
# so a summary merely MENTIONING "[key=x]" cannot open or close that decision.
# A line with no token in either position uses the key "default", preserving
# the historical one-open-decision-per-task behavior (a bare "resolved:" closes
# "default"). A stated key whose slug fails the charset below is rejected (the
# folds skip the line), never rewritten to "default".
# The parsers are pure reads of a single line. Status metadata may contain any
# number of "[name=value]" tags before the colon, in any order, so verb parsing
# ends at the first tag rather than special-casing "[key=...]".
#
# Correlation tokens. That bracket rule already covers every BRACKETED tag,
# including the "[corr=<16 hex>]" form bin/fm-secondmate-report.sh writes. It
# does not cover the UNBRACKETED token that bin/fm-pending-reply-lib.sh writes
# (fm_pending_reply_corr_token), which a secondmate answering a marked request
# echoes on its parent status line ahead of the key tag (bin/fm-brief.sh), so a
# real transition routinely arrives as
#   needs-decision corr=<16 hex> [key=texte-du-mur]: <summary>
#   resolved       corr=<16 hex> [key=texte-du-mur]: <how it was decided>
# and a recovery turn can leave two such tokens on one line. All of those must
# read as the bare verb, in BOTH directions: a verb parse that keeps the token
# glued on matches no arm of _fm_decision_fold_line, so the opener never opens
# and the closer never closes, and a captain decision goes silently missing.
# Recognition starts only AFTER the retained leading verb: a token-first line
# keeps that token, so its following word cannot impersonate a transition and
# close a decision the captain is owed.
#
# The token grammar is OWNED by bin/fm-pending-reply-lib.sh
# (fm_pending_reply_corr_token, FM_PENDING_REPLY_CORR_RE). That library sources
# this one, so it cannot be sourced back here; the pattern below is a deliberate
# second statement of the SHAPE alone, and tests/fm-classify-corr-token.test.sh
# pins the two together through the real writers so they cannot drift.
#
# Recognition is deliberately narrow: EXACTLY the token that writer emits, whole
# word, and nothing else. An arbitrary "<name>=<value>" token is NOT skipped.
# Skipping unknown tokens would be the permissive road - it would let any
# free-text word carrying an equals sign ("resolved x=1 [key=k]: ...") reduce to
# a bare verb and impersonate a transition, which is the takeover the strict
# parse and _fm_decision_key_transition_allowed exist to prevent. Recognising
# only what a firstmate library actually writes costs one more line here each
# time a real new token shape is introduced, and that is the intended trade: a
# new shape is a deliberate, reviewed edit rather than a silent widening. A line
# whose token is malformed, wrong-length, or merely mentioned in prose keeps its
# extra words and therefore stays a non-transition, exactly as before.
#
# The 16 hex classes are written out literally rather than built from a
# variable, the same way bin/fm-secondmate-report.sh validates the id it is
# handed: a variable holding a glob is only re-read as a pattern under some
# shells' expansion rules, and a safety parse must not turn on that.
#
# 0 if <word> is, in whole, an unbracketed correlation token this fleet's own
# tooling writes. The bracketed form never reaches here: the tag rule above has
# already ended the verb parse at its opening bracket.
_fm_classify_is_corr_token() {  # <word>
  case "$1" in
    corr=[0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f][0-9A-Fa-f])
      return 0
      ;;
  esac
  return 1
}

status_line_verb() {  # <status-line> -> leading verb word
  local v=${1%%:*} out='' word
  v=${v%%\[*}
  v=${v#"${v%%[![:space:]]*}"}
  v=${v%"${v##*[![:space:]]}"}
  # Fast path, and the whole no-regression guarantee: a prefix that cannot
  # contain a correlation token is returned byte-for-byte as before, so every
  # line without one keeps its exact historical verb, spacing included.
  case "$v" in
    *corr=*) ;;
    *) printf '%s' "$v"; return 0 ;;
  esac
  # Retain the first word, then drop only recognised tokens from the remaining
  # whole words. Anything unrecognised stays, so prose still matches no verb.
  word=${v%%[[:space:]]*}
  out=$word
  v=${v#"$word"}
  v=${v#"${v%%[![:space:]]*}"}
  while [ -n "$v" ]; do
    word=${v%%[[:space:]]*}
    v=${v#"$word"}
    v=${v#"${v%%[![:space:]]*}"}
    _fm_classify_is_corr_token "$word" && continue
    out="$out $word"
  done
  printf '%s' "$out"
}
# 0 when a complete "[key=...]" token sits in the documented position before
# the line's first colon (or anywhere on a line that has no colon at all).
_fm_key_before_colon() {  # <status-line>
  case "${1%%:*}" in
    *\[key=*\]*) return 0 ;;
    *) return 1 ;;
  esac
}
# Raw slug of a complete "[key=<slug>]" token at the head of the note (the
# first thing after the line's first colon, ignoring whitespace). Fails when
# the line has no colon or no complete token there; slug charset validity is
# the caller's check via _fm_decision_slug_ok, exactly as for the before-colon
# position.
_fm_key_at_note_head() {  # <status-line> -> raw slug
  local rest
  case "$1" in
    *:*) rest=${1#*:} ;;
    *) return 1 ;;
  esac
  rest=${rest#"${rest%%[![:space:]]*}"}
  case "$rest" in
    \[key=*\]*) rest=${rest#\[key=}; printf '%s' "${rest%%\]*}" ;;
    *) return 1 ;;
  esac
}
# 0 when a stated key slug is well-formed: nonempty, A-Za-z0-9._- only.
_fm_decision_slug_ok() {  # <slug>
  case "$1" in
    ''|*[!A-Za-z0-9._-]*) return 1 ;;
    *) return 0 ;;
  esac
}
status_line_note() {  # <status-line> -> text after the first colon, trimmed
  local n k
  case "$1" in
    *:*) n=${1#*:}; n=${n#"${n%%[![:space:]]*}"} ;;
    *) printf '%s' "$1"; return 0 ;;
  esac
  # A note-head token that states this line's key (no before-colon token, valid
  # slug) is key metadata, not note text: strip it so both stated-key positions
  # yield the same note.
  if ! _fm_key_before_colon "$1" && k=$(_fm_key_at_note_head "$1") \
    && _fm_decision_slug_ok "$k"; then
    n=${n#"[key=$k]"}
    n=${n#"${n%%[![:space:]]*}"}
  fi
  printf '%s' "$n"
}
_fm_decision_key() {  # <status-line> -> key slug, or "default" when no token
  local k
  if _fm_key_before_colon "$1"; then
    k=${1%%:*}
    k=${k#*\[key=}
    k=${k%%\]*}
  else
    k=$(_fm_key_at_note_head "$1") || { printf 'default'; return 0; }
  fi
  _fm_decision_slug_ok "$k" || return 1
  printf '%s' "$k"
}
# Drop the record for <key> from a newline-terminated "<key>\t<verb>\t<note>" set.
# Portable (no associative arrays) so the fold runs on bash 3.2 as well as 4+.
_fm_decision_drop() {  # <open-set> <key>
  local set=$1 key=$2 line out=''
  while IFS= read -r line; do
    [ -n "$line" ] || continue
    case "$line" in
      "$key"$'\t'*) : ;;
      *) out="${out}${line}"$'\n' ;;
    esac
  done <<EOF
$set
EOF
  printf '%s' "$out"
}
# Fold ONE status line into an existing "<key>\t<verb>\t<note>\n"-per-line open
# set, applying the same needs-decision/blocked-opens, resolved/captain-held-closes
# rule status_open_decisions documents above. Pure text transform, no file I/O.
# This is the ONE place the per-line open/resolved rule is written; both the
# whole-file fold (status_open_decisions) and the incremental cursor-backed fold
# (status_open_decisions_incremental) below call this instead of re-deriving the
# rule, so the two consumption strategies can never drift apart on semantics.
# Reserved decision-key namespaces, and the rule that makes them mean something.
#
# A key like `pending-reply-<id>` names a decision that one library raises and is
# the only thing that ever closes it. Every writer reaches this same stream: a
# local mate appends straight into it, and a remote mate's lines are mirrored
# into it verbatim. So without a rule here, any writer could claim a reserved
# key with an unrelated note, take the key over in this fold, and permanently
# block the owner's close - leaving a decision nothing will ever resolve - or
# clear the owner's decision with a bare resolution.
#
# The rule is deliberately generic, so this fold needs no knowledge of any
# particular owner: a reserved key may only be opened or closed by a line whose
# note speaks that namespace's own vocabulary, which its owner states by
# beginning the note with a `<namespace>...:` token. A line failing that is not a
# decision transition at all here and is folded as ordinary status. This is a
# consumer-side rule on purpose - it protects local and remote writers
# identically, and it can never fail a whole delta or wedge a stream the way a
# writer-side rejection would.
FM_CLASSIFY_RESERVED_KEY_PREFIXES_DEFAULT='pending-reply-'

# 0 when <key> is not reserved, or is reserved and <note> speaks its vocabulary.
_fm_decision_key_transition_allowed() {  # <key> <note>
  local key=$1 note=$2 prefix
  for prefix in ${FM_CLASSIFY_RESERVED_KEY_PREFIXES:-$FM_CLASSIFY_RESERVED_KEY_PREFIXES_DEFAULT}; do
    case "$key" in
      "$prefix"*)
        case "$note" in
          "$prefix"*:*) return 0 ;;
          *) return 1 ;;
        esac
        ;;
    esac
  done
  return 0
}

_fm_decision_fold_line() {  # <open-set> <status-line> <resolve-verb> <held-verb>
  local open=$1 line=$2 resolve=$3 held=$4 verb key note
  # Blank-line guard. A `case` glob answers "does this line hold any non-space
  # character" in one pattern match; the equivalent ${line//[[:space:]]/} costs
  # tens of milliseconds per line under bash 3.2's global bracket-class
  # substitution, which is the whole per-line cost of both folds on a status log
  # of ordinary width. Same verdict, bounded cost.
  case "$line" in
    *[![:space:]]*) ;;
    *) printf '%s' "$open"; return 0 ;;
  esac
  verb=$(status_line_verb "$line")
  key=$(_fm_decision_key "$line") || { printf '%s' "$open"; return 0; }
  _fm_decision_key_transition_allowed "$key" "$(status_line_note "$line")" \
    || { printf '%s' "$open"; return 0; }
  case "$verb" in
    needs-decision|blocked)
      note=$(status_line_note "$line")
      open=$(_fm_decision_drop "$open" "$key")
      [ -n "$open" ] && open="${open}"$'\n'
      open="${open}${key}"$'\t'"${verb}"$'\t'"${note}"$'\n'
      ;;
    "$resolve"|"$held")
      open=$(_fm_decision_drop "$open" "$key")
      [ -n "$open" ] && open="${open}"$'\n'
      ;;
  esac
  printf '%s' "$open"
}

# Fold the WHOLE status stream into the set of decisions still open. Prints one
# TAB-separated "<key>\t<verb>\t<summary>" line per still-open decision, in
# most-recently-opened-last order; prints nothing when none are open. Pure read of
# the file, no globals beyond the optional FM_CLASSIFY_RESOLVE_VERB override. This
# is the durable open-set the fleet snapshot and any point-in-time consumer must use
# instead of trusting the last status line.
# The scan_open_decisions wrapper below enumerates a whole directory rather than
# a single caller-chosen path, so a status file that is itself a symlink (e.g.
# escaping the state directory) is rejected outright with a plain [ -L ] check
# before any read - a cheap builtin, unlike fm_wake_latest_event's O_NOFOLLOW
# subprocess read, which exists for that function's much narrower payload-driven
# path resolution rather than this directory-local glob.
status_open_decisions() {  # <status-file>
  local f=$1 line verb key note resolve held open='' stripped
  [ -f "$f" ] && [ -r "$f" ] && [ ! -L "$f" ] || return 0
  resolve=${FM_CLASSIFY_RESOLVE_VERB:-$FM_CLASSIFY_RESOLVE_VERB_DEFAULT}
  held=${FM_CLASSIFY_CAPTAIN_HELD_VERB:-$FM_CLASSIFY_CAPTAIN_HELD_VERB_DEFAULT}
  while IFS= read -r line || [ -n "$line" ]; do
    open=$(_fm_decision_fold_line "$open" "$line" "$resolve" "$held")
  done < "$f"
  printf '%s' "$open"
}

# Fleet-wide wrapper around status_open_decisions: scans every task's status
# log under <state> and prefixes each still-open decision with its owning task
# id, so a per-wake or per-session surface can print the consolidated open set
# without re-walking the fold itself. A thin directory scan only - the fold
# above remains the ONE place the open/resolved semantics are decided. Prints
# one "<task>\t<key>\t<verb>\t<note>" line per open decision, in glob (task id)
# order; prints nothing when none are open.
scan_open_decisions() {  # <state>
  local state=$1 f task open line
  for f in "$state"/*.status; do
    [ -e "$f" ] || continue
    task=$(basename "$f"); task="${task%.status}"
    open=$(status_open_decisions "$f") || continue
    [ -n "$open" ] || continue
    while IFS= read -r line; do
      [ -n "$line" ] || continue
      printf '%s\t%s\n' "$task" "$line"
    done <<EOF
$open
EOF
  done
  return 0
}

# Fold material routed-work phases in the same keyed event stream.
# A working or declared-pause event opens or replaces one phase for its key.
# A later done, failed, needs-decision, blocked, or resolved event carrying that
# key closes the phase, because it has moved to a terminal or separately tracked
# state.
# A bare legacy event uses the default key, preserving one-phase behavior.
# This fold is evidence about whether a parent event was explicitly superseded.
# It is never authoritative current crew state, and consumers must not let an open
# phase outrank a structured home snapshot or fm-crew-state result.
_fm_status_open_activities_stream() {
  local line verb key note resolve held open='' pause
  resolve=${FM_CLASSIFY_RESOLVE_VERB:-$FM_CLASSIFY_RESOLVE_VERB_DEFAULT}
  held=${FM_CLASSIFY_CAPTAIN_HELD_VERB:-$FM_CLASSIFY_CAPTAIN_HELD_VERB_DEFAULT}
  pause=${FM_CLASSIFY_PAUSED_VERB:-$FM_CLASSIFY_PAUSED_VERB_DEFAULT}
  while IFS= read -r line || [ -n "$line" ]; do
    # Blank-line guard; see _fm_decision_fold_line for why this is a glob.
    case "$line" in
      *[![:space:]]*) ;;
      *) continue ;;
    esac
    verb=$(status_line_verb "$line")
    key=$(_fm_decision_key "$line") || continue
    case "$verb" in
      working|"$pause")
        note=$(status_line_note "$line")
        open=$(_fm_decision_drop "$open" "$key")
        [ -n "$open" ] && open="${open}"$'\n'
        open="${open}${key}"$'\t'"${verb}"$'\t'"${note}"$'\n'
        ;;
      done|failed|needs-decision|blocked|"$resolve"|"$held")
        open=$(_fm_decision_drop "$open" "$key")
        [ -n "$open" ] && open="${open}"$'\n'
        ;;
    esac
  done
  printf '%s' "$open"
}

status_open_activities() {  # <status-file-or-dash>
  local f=$1
  if [ "$f" = - ]; then
    _fm_status_open_activities_stream
    return 0
  fi
  [ -f "$f" ] || return 0
  _fm_status_open_activities_stream < "$f"
}

# task id from a recorded window target, falling back to the tmux-shaped
# "<session>:fm-<id>" form when no metadata state is available.
window_to_task() {
  local w=$1 state=${2:-${STATE:-${FM_STATE_OVERRIDE:-}}} meta mw mt t
  if [ -n "$state" ]; then
    for meta in "$state"/*.meta; do
      [ -e "$meta" ] || continue
      mw=$(grep '^window=' "$meta" 2>/dev/null | tail -1 | cut -d= -f2- || true)
      mt=$(grep '^terminal=' "$meta" 2>/dev/null | tail -1 | cut -d= -f2- || true)
      [ "$mw" = "$w" ] || [ "$mt" = "$w" ] || continue
      t=$(basename "$meta")
      t=${t%.meta}
      printf '%s' "$t"
      return 0
    done
  fi
  t="${w##*:}"; t="${t#fm-}"; printf '%s' "$t"
}

# Capture the bytes of an append-only status log at or after <start-offset> under
# one size-and-identity snapshot.
# The record form prints `<endpoint>\t<identity>\t<events>` and returns 0 when
# the span has actionable events, joining every such event in source order with
# ` ; ` so callers report the complete captured span before committing it.
# It returns 1 after a successful classification with no actionable event; an
# existing log still prints its committable endpoint and identity, while an absent
# log is the ordinary empty case and prints no record.
# It returns 2 with no committable endpoint when an existing status object cannot
# be classified.
# The simpler wrapper prints only the event field, and the predicate discards the
# record; all three inherit the library-header contract above.
#
# A keyed `needs-decision` or `blocked` transition accepted by the whole-file
# fold is included only when that fold still names the exact opening as live.
# A transition rejected by the reserved-key vocabulary is surfaced instead as a
# reconciliation signal and never treated here as an open decision.
# status_open_decisions remains the single owner of open/closed semantics,
# including same-key reopening and reserved-key handling.
# Every other captain-relevant event is terminal and always actionable.
_fm_decision_origin_drop() {  # <origins> <key>
  local origin
  while IFS= read -r origin; do
    case "$origin" in "$2"$'\t'*) ;; *) [ -n "$origin" ] && printf '%s\n' "$origin" ;; esac
  done <<EOF
$1
EOF
}

_fm_status_open_decision_origins() {  # <status-file>
  local f=$1 line open='' after key verb note number=0 origins=''
  local resolve held
  resolve=${FM_CLASSIFY_RESOLVE_VERB:-$FM_CLASSIFY_RESOLVE_VERB_DEFAULT}
  held=${FM_CLASSIFY_CAPTAIN_HELD_VERB:-$FM_CLASSIFY_CAPTAIN_HELD_VERB_DEFAULT}
  while IFS= read -r line || [ -n "$line" ]; do
    number=$((number + 1))
    after=$(_fm_decision_fold_line "$open" "$line" "$resolve" "$held")
    key=$(_fm_decision_key "$line") || { open=$after; continue; }
    verb=$(status_line_verb "$line")
    note=$(status_line_note "$line")
    case "$verb" in
      needs-decision|blocked)
        if _fm_open_set_has "$after" "$key" \
          && [ "$(_fm_open_set_verb "$after" "$key")" = "$verb" ]; then
          case "$after" in
            "$key"$'\t'"$verb"$'\t'"$note"|*$'\n'"$key"$'\t'"$verb"$'\t'"$note")
              origins=$(_fm_decision_origin_drop "$origins" "$key")
              [ -n "$origins" ] && origins="${origins}"$'\n'
              origins="${origins}${key}"$'\t'"${number}"
              ;;
          esac
        fi
        ;;
      "$resolve"|"$held")
        _fm_open_set_has "$after" "$key" || origins=$(_fm_decision_origin_drop "$origins" "$key")
        ;;
    esac
    open=$after
  done < "$f"
  printf '%s' "$origins"
}

status_span_first_actionable_record() {  # <status-file> <start-offset>
  local f=$1 start=${2:-0} size ident cur_ident scratch chunk_file full_file prefix_file
  local line verb key origins='' folded=0 rc=1 failed=0 prefix_lines=0 line_number=0 live_line='' events='' _line _key
  [ -e "$f" ] || { [ -L "$f" ] && return 2; return 1; }
  [ -f "$f" ] && [ -r "$f" ] && [ ! -L "$f" ] || return 2
  ident=$(_fm_open_decisions_file_ident "$f") || return 2
  size=$(_fm_status_file_size "$f") || return 2
  size=${size//[[:space:]]/}
  case "$size" in ''|*[!0-9]*) return 2 ;; esac
  case "$start" in ''|*[!0-9]*) start=0 ;; esac
  [ "$start" -le "$size" ] || start=0
  [ "$start" -lt "$size" ] || { printf '%s\t%s' "$size" "$ident"; return 1; }
  scratch=$(_fm_status_span_scratch "$f") || return 2
  chunk_file="${scratch}.span"; full_file="${scratch}.full"; prefix_file="${scratch}.prefix"
  _fm_status_read_span "$f" "$start" "$((size - start))" > "$chunk_file" 2>/dev/null \
    || { rm -f "$chunk_file" "$full_file" "$prefix_file"; return 2; }
  cur_ident=$(_fm_open_decisions_file_ident "$f") || {
    rm -f "$chunk_file" "$full_file" "$prefix_file"; return 2;
  }
  [ "$cur_ident" = "$ident" ] || { rm -f "$chunk_file" "$full_file" "$prefix_file"; return 2; }
  while IFS= read -r line || [ -n "$line" ]; do
    line_number=$((line_number + 1))
    case "$line" in *[![:space:]]*) ;; *) continue ;; esac
    status_is_captain_relevant "$line" || continue
    verb=$(status_line_verb "$line")
    case "$verb" in
      needs-decision|blocked)
        key=$(_fm_decision_key "$line") || {
          [ -n "$events" ] && events="${events} ; "
          events="${events}${line}"
          rc=0
          continue
        }
        _fm_decision_key_transition_allowed "$key" "$(status_line_note "$line")" || {
          [ -n "$events" ] && events="${events} ; "
          events="${events}reconciliation-required: ${line}"
          rc=0
          continue
        }
        if [ "$folded" -eq 0 ]; then
          _fm_status_read_span "$f" 0 "$size" > "$full_file" 2>/dev/null \
            || { failed=1; break; }
          if [ "$start" -gt 0 ]; then
            _fm_status_read_span "$full_file" 0 "$start" > "$prefix_file" 2>/dev/null \
              || { failed=1; break; }
            while IFS= read -r _line || [ -n "$_line" ]; do prefix_lines=$((prefix_lines + 1)); done < "$prefix_file"
          fi
          origins=$(_fm_status_open_decision_origins "$full_file") || { failed=1; break; }
          folded=1
        fi
        live_line=$(while IFS=$(printf '\t') read -r _key _line; do
          [ "$_key" = "$key" ] && { printf '%s' "$_line"; break; }
        done <<EOF
$origins
EOF
)
        [ -n "$live_line" ] && [ "$((prefix_lines + line_number))" -eq "$live_line" ] || continue
        [ -n "$events" ] && events="${events} ; "
        events="${events}${line}"
        rc=0
        ;;
      *)
        [ -n "$events" ] && events="${events} ; "
        events="${events}${line}"
        rc=0
        ;;
    esac
  done < "$chunk_file"
  rm -f "$chunk_file" "$full_file" "$prefix_file"
  [ "$failed" -eq 0 ] || return 2
  if [ "$rc" -eq 0 ]; then printf '%s\t%s\t%s' "$size" "$ident" "$events"; else printf '%s\t%s' "$size" "$ident"; fi
  return "$rc"
}

status_span_first_actionable() {  # <status-file> <start-offset>
  local record rc rest
  record=$(status_span_first_actionable_record "$1" "${2:-0}")
  rc=$?
  if [ "$rc" -eq 0 ]; then
    rest=${record#*$'\t'}
    printf '%s' "${rest#*$'\t'}"
  fi
  return "$rc"
}

status_span_has_actionable() {  # <status-file> <start-offset>
  status_span_first_actionable_record "$1" "${2:-0}" > /dev/null
}

# Classify WHY an idle/stale crew MIGHT be safely absorbed instead of surfaced,
# from bin/fm-crew-state.sh's one authoritative current-state line
# ("state: <s> · source: <src> · <detail>"). Prints exactly one token:
#   working - an actively-running no-mistakes step (running/fixing/ci) or a busy
#             pane; the crew is legitimately mid-work on a static-looking pane
#             (e.g. waiting on CI);
#   paused  - the crew's authoritative current state is a declared external-wait
#             pause (paused:), which is EXPECTED to idle;
#   none    - neither, so the wake must surface (a stopped/finished/parked/failed/
#             torn-down/unknown crew, or an unreadable verdict).
# One fm-crew-state.sh read serves BOTH absorb reasons at once. Reading the state
# authoritatively (not the status log) is what keeps run-step precedence: a crew
# that appended paused: but then STARTED a run reports working, never paused.
# NOT a pure read: fm-crew-state.sh may make a bounded no-mistakes call, so callers
# run it only on no-verb signal and first-sighting stale paths, never every wake.
# FM_CREW_STATE_BIN lets tests stub the verdict.
crew_absorb_class() {  # <id>
  local id=$1 line state src
  [ -n "$id" ] || { printf 'none'; return; }
  line=$("$FM_CREW_STATE_BIN" "$id" 2>/dev/null) || true
  case "$line" in state:*) ;; *) printf 'none'; return ;; esac
  state=${line#state: }; state=${state%% *}
  if [ "$state" = paused ]; then printf 'paused'; return; fi
  if [ "$state" = working ]; then
    src=${line#*source: }; src=${src%% *}
    case "$src" in run-step|pane) printf 'working'; return ;; esac
  fi
  printf 'none'
}

# 0 if crew <id> shows POSITIVE evidence it is still working (crew_absorb_class
# reports `working`). This is the "provably working" predicate at the heart of
# absorb-only-on-positive-evidence. This is the sole proof for stale wakes and the
# shared authoritative proof for no-verb signals. Where a home opts in, fm-watch.sh
# may additionally absorb a bare turn-end on bounded pane churn, while every other
# failed verdict surfaces
# because the crew may be done, waiting on a decision, or wedged. For stale panes
# it is checked before trusting the status log so a pre-validation captain-relevant
# line does not override an active run. See crew_absorb_class for the exact
# working/paused/none decision.
crew_is_provably_working() {  # <id>
  [ "$(crew_absorb_class "$1")" = working ]
}

# 0 if crew <id>'s authoritative current state is a declared external-wait pause.
# The stale path absorbs such a crew (on a long re-surface cadence) instead of
# escalating a possible wedge.
crew_is_paused() {  # <id>
  [ "$(crew_absorb_class "$1")" = paused ]
}

# Directories excluded from the worktree write probe below, and the depth it walks.
# The excluded set is everything a supervisor read or a package manager can write
# without the crew doing any work - .git first, so firstmate's own read-only git
# commands against the worktree can never make the probe self-fulfilling - plus the
# large generated trees that would make the walk expensive. Both are overridable so
# a home with an unusual layout can widen or narrow the probe. The list is a skip
# list, so clearing it skips nothing and widens the walk to the whole depth-bounded
# tree; it never disables the probe, which would quietly cost the wedge detector a
# liveness input on a home that meant to widen it. Defaulted with the plain form so
# an explicitly empty value stays empty: clearing the knob in the environment is the
# documented way to ask for that wider walk, and treating empty as unset would hand
# the default skip list back to exactly the home that asked for more coverage.
FM_WORKTREE_WRITE_PRUNE=${FM_WORKTREE_WRITE_PRUNE-'.git node_modules .venv venv __pycache__ .mypy_cache .pytest_cache .ruff_cache .tox target dist build .next .cache vendor'}
FM_WORKTREE_WRITE_MAXDEPTH=${FM_WORKTREE_WRITE_MAXDEPTH:-6}

# Wall-clock seconds the probe's single walk may take. The walk runs synchronously
# inside the caller's poll loop at the exact moment an escalation would otherwise
# fire, and -xdev keeps it out of a nested mount but cannot help when the worktree
# root ITSELF sits on a hung network or container mount; unbounded, such a walk
# would wedge the very supervisor that exists to notice a wedge, stalling its
# heartbeat instead of escalating. Hitting the bound is a negative outcome like
# every other: it reads as no evidence, so the caller's escalation schedule is
# untouched and a stall that writes nothing still escalates on the existing
# schedule. A value that is not a positive integer is not a bound at all (`timeout
# 0` and the perl fallback's `alarm 0` both disable the deadline), so the default
# applies instead; the check lives at the point of use so an in-process override
# gets it too.
FM_WORKTREE_WRITE_TIMEOUT=${FM_WORKTREE_WRITE_TIMEOUT:-10}

# 0 when some regular file under <id>'s recorded worktree is newer than
# <anchor-file>: positive evidence the crew is still producing work even though its
# rendered pane has gone quiet. This is the third liveness input the wedge detector
# has, after pane quietness and the run step, and it exists because neither of
# those can see a crew that is writing source, then tests, then documentation
# behind a static pane - the 2026-08-14 case of eight consecutive possible-wedge
# escalations against a crew that was demonstrably working the whole time.
#
# 1 for every other outcome, including an id with no recorded worktree, a worktree
# that is gone, a missing anchor, and a walk that fails or finds nothing. Absence of
# evidence therefore always leaves the caller's existing escalation schedule
# untouched, so a crew that writes nothing still escalates exactly as before.
#
# A kind=secondmate task records a provisioned firstmate home, not a code tree, and
# such a home runs its OWN supervision inside it: its state/ directory churns a
# watcher beacon, pane hashes, and heartbeats whether or not the mate is producing
# anything, so a walk there would report liveness for a mate that has done nothing.
# Those homes are excluded outright rather than by pruning "state", which would also
# hide a legitimate source directory of that name in an ordinary worktree. The
# exclusion is a negative outcome like any other, so an unproductive mate keeps
# escalating on the caller's unchanged schedule.
#
# The anchor is the caller's own idle-window timer file, whose mtime already marks
# when the quiet window opened, so `-newer` needs no clock arithmetic, no temp
# file, and no portable mtime-setting. Not a pure status-file read (see the header):
# one pruned, depth-bounded, wall-clock-bounded walk per call, which callers must
# reach only when they are otherwise about to escalate, never on every poll. A walk
# that outlives FM_WORKTREE_WRITE_TIMEOUT is killed and reported as no evidence, so
# a hung mount costs the escalation nothing but the bound. -xdev holds that walk to the
# worktree's own filesystem rather than descending into a nested network or container
# mount, so a write that lands only under such a mount is one more negative outcome.
crew_worktree_written_since() {  # <id> <state> <anchor-file>
  local id=$1 state=$2 anchor=$3 wt kind name hit bound
  local -a names=() prune=()
  [ -n "$id" ] || return 1
  [ -f "$anchor" ] || return 1
  wt=$(grep '^worktree=' "$state/$id.meta" 2>/dev/null | tail -1 | cut -d= -f2- || true)
  [ -n "$wt" ] && [ -d "$wt" ] || return 1
  kind=$(grep '^kind=' "$state/$id.meta" 2>/dev/null | tail -1 | cut -d= -f2- || true)
  [ "$kind" != secondmate ] || return 1
  if [ -e "$wt/.fm-secondmate-home" ] || [ -L "$wt/.fm-secondmate-home" ]; then
    return 1
  fi
  read -r -a names <<< "$FM_WORKTREE_WRITE_PRUNE"
  for name in ${names[@]+"${names[@]}"}; do
    [ "${#prune[@]}" -eq 0 ] || prune+=( -o )
    prune+=( -name "$name" )
  done
  bound=$FM_WORKTREE_WRITE_TIMEOUT
  case "$bound" in ''|*[!0-9]*|0) bound=10 ;; esac
  if [ "${#prune[@]}" -gt 0 ]; then
    hit=$(fm_run_timed "$bound" find "$wt" -xdev -maxdepth "$FM_WORKTREE_WRITE_MAXDEPTH" \
      \( "${prune[@]}" \) -prune -o -type f -newer "$anchor" -print -quit 2>/dev/null || true)
  else
    hit=$(fm_run_timed "$bound" find "$wt" -xdev -maxdepth "$FM_WORKTREE_WRITE_MAXDEPTH" \
      -type f -newer "$anchor" -print -quit 2>/dev/null || true)
  fi
  [ -n "$hit" ]
}

# 0 (benign/absorb) if EVERY task referenced by a no-verb "signal:" wake is provably
# working; 1 (actionable/surface) if any is not, or no task can be resolved. Pass the
# same space-separated file list the caller classified with the span read above.
# Files are mapped to task ids by stripping the .status / .turn-ended suffix;
# a no-verb wake with nothing
# provably working must surface, so an empty/unresolvable list returns 1.
# A kind=secondmate task's .status signal is never absorbable here regardless of
# busy evidence: that stream is the mate's routed-reply channel, so every append
# is parent-directed content the supervisor must read (a routed reply, a newly
# raised decision, a mirrored remote line), and a busy mate agent makes its note
# more current, not less deliverable. Scoped to .status files - a mate's bare
# turn-ended ping still uses the ordinary provably-working absorb.
signal_crew_provably_working() {  # <file> ...
  local f base dir task seen=""
  for f in "$@"; do
    base=${f##*/}
    dir=${f%/*}
    [ "$dir" != "$f" ] || dir=.
    case "$base" in
      *.status)     task=${base%.status} ;;
      *.turn-ended) task=${base%.turn-ended} ;;
      *)            continue ;;
    esac
    [ -n "$task" ] || continue
    case "$base" in
      *.status)
        if [ "$(grep '^kind=' "$dir/$task.meta" 2>/dev/null | tail -1 | cut -d= -f2-)" = secondmate ]; then
          return 1
        fi
        ;;
    esac
    case " $seen " in *" $task "*) continue ;; esac
    seen="$seen $task"
    crew_is_provably_working "$task" || return 1
  done
  [ -n "$seen" ] || return 1
  return 0
}

# 0 (terminal/actionable) if a stale window's last status line is
# captain-relevant; 1 otherwise, including the no-status case. A 1 only means
# "non-terminal"; the always-on watcher then applies crew_is_provably_working,
# while the away-mode daemon applies its persistence recheck.
stale_is_terminal() {  # <window> <state>
  local win=$1 state=$2 last
  last=$(last_status_line "$state/$(window_to_task "$win" "$state").status")
  [ -n "$last" ] && status_is_captain_relevant "$last"
}
