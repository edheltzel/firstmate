#!/usr/bin/env bash
# Gate and atomically publish the first corrected OMP phase; check mode never writes project or backlog files.
# Usage: bin/fm-omp-activation.sh [--check|--activate] [--json] [--report PATH] [--manifest PATH] [--roadmap PATH] [--tracked-backlog PATH] [--live-backlog PATH] [--repo-root PATH] [--authorization PATH] [--decisions PATH] [--stops PATH] [--preflight PATH] [--receipt PATH]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
FM_HOME_ROOT=${FM_HOME:-$ROOT}
REPORT=${FM_OMP_REPORT:-$FM_HOME_ROOT/data/omp-corrected-plan-redteam-o8/report.md}
MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
ROADMAP="$ROOT/.agents/tasks/roadmap.md"
TRACKED_BACKLOG="$ROOT/.agents/tasks/backlog.md"
LIVE_BACKLOG="$FM_HOME_ROOT/data/backlog.md"
REPO_ROOT="$ROOT"
AUTHORIZATION="$FM_HOME_ROOT/data/omp-captain-authorization.json"
DECISIONS="$FM_HOME_ROOT/data/omp-decision-inventory.json"
STOPS="$FM_HOME_ROOT/data/omp-stop-ledger.json"
PREFLIGHT="$FM_HOME_ROOT/data/omp-activation-preflight.json"
RECEIPT="$FM_HOME_ROOT/data/omp-activation-receipt.json"
TASKS_AXI=${TASKS_AXI:-}
if [ -z "$TASKS_AXI" ]; then
  TASKS_AXI=$(command -v tasks-axi 2>/dev/null || true)
fi
SHA256_TOOL=${SHA256_TOOL:-}
if [ -z "$SHA256_TOOL" ]; then
  SHA256_TOOL=$(command -v shasum 2>/dev/null || command -v sha256sum 2>/dev/null || true)
fi
FAIL_STAGE=${FM_OMP_ACTIVATION_FAIL_STAGE:-}
ACTIVATION_DATE=${FM_OMP_ACTIVATION_DATE:-$(date -u +%F)}
ACTION=check
JSON_OUTPUT=0

usage() {
  sed -n '2,3p' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) ACTION=check ;;
    --activate) ACTION=activate ;;
    --json) JSON_OUTPUT=1 ;;
    --report) shift; REPORT=${1-} ;;
    --manifest) shift; MANIFEST=${1-} ;;
    --roadmap) shift; ROADMAP=${1-} ;;
    --tracked-backlog) shift; TRACKED_BACKLOG=${1-} ;;
    --live-backlog) shift; LIVE_BACKLOG=${1-} ;;
    --repo-root) shift; REPO_ROOT=${1-} ;;
    --authorization) shift; AUTHORIZATION=${1-} ;;
    --decisions) shift; DECISIONS=${1-} ;;
    --stops) shift; STOPS=${1-} ;;
    --preflight) shift; PREFLIGHT=${1-} ;;
    --receipt) shift; RECEIPT=${1-} ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

ERRORS=()
ACTIVATION_IDS=()

error() {
  ERRORS+=("$1")
}

TMP_DIR=
if ! TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fm-omp-activation.XXXXXX" 2>/dev/null); then
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'BLOCK' --arg action "$ACTION" --arg issue 'could not allocate activation temporary workspace' '{schema:$schema,status:$status,action:$action,issues:[$issue]}'
  else
    printf 'BLOCK\ncould not allocate activation temporary workspace\n' >&2
  fi
  exit 1
fi
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

if ! printf '%s\n' "$ACTIVATION_DATE" | grep -Eq '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
  error "activation date must match YYYY-MM-DD: $ACTIVATION_DATE"
fi

if [ -z "$TASKS_AXI" ]; then
  error "Tasks Axi executable is unavailable on PATH"
fi
if [ -z "$SHA256_TOOL" ]; then
  error "SHA-256 tool is unavailable; install shasum or sha256sum"
fi

require_file() {
  if [ ! -f "$1" ]; then
    error "missing required input: $1"
  fi
}

sha256() {
  case "$SHA256_TOOL" in
    */shasum|shasum) "$SHA256_TOOL" -a 256 "$1" | awk '{print $1}' ;;
    */sha256sum|sha256sum) "$SHA256_TOOL" "$1" | awk '{print $1}' ;;
    *) return 1 ;;
  esac
}

contains_task() {
  local task_id=$1
  local path=$2
  [ -f "$path" ] && grep -Eq "^- \[[ xX]\] ${task_id}([[:space:]-]|$)" "$path"
}

is_activation_task() {
  local candidate=$1 activation_id
  for activation_id in "${ACTIVATION_IDS[@]}"; do
    [ "$candidate" = "$activation_id" ] && return 0
  done
  return 1
}

REPORT_DISPOSITION=
if [ -f "$REPORT" ]; then
  REPORT_DISPOSITION=$(awk '
    /^##[[:space:]]+Executive disposition/ { in_disposition=1; next }
    in_disposition && /(CONDITIONAL PASS|PASS|BLOCK)/ {
      if ($0 ~ /CONDITIONAL PASS/) { print "CONDITIONAL PASS"; exit }
      if ($0 ~ /BLOCK/) { print "BLOCK"; exit }
      if ($0 ~ /PASS/) { print "PASS"; exit }
    }
  ' "$REPORT")
  if [ -z "$REPORT_DISPOSITION" ]; then
    error "report has no exact Executive disposition"
  elif [ "$REPORT_DISPOSITION" != "PASS" ]; then
    error "report disposition is $REPORT_DISPOSITION; activation requires PASS"
  fi
else
  error "missing corrected-plan report: $REPORT"
fi

if [ -f "$REPORT" ]; then
  REPORT_SHA256=$(sha256 "$REPORT")
else
  REPORT_SHA256=
fi

PLAN_CHECK_JSON=$(
  "$ROOT/bin/fm-omp-plan-check.sh" --json --manifest "$MANIFEST" --plan "$ROOT/.agents/plans/omp-harness-integration-plan.md" --roadmap "$ROADMAP" --backlog "$TRACKED_BACKLOG" 2>/dev/null || true
)
if [ "$(printf '%s' "$PLAN_CHECK_JSON" | jq -r '.status // "BLOCK"' 2>/dev/null || printf BLOCK)" != PASS ]; then
  error "machine-readable OMP plan check did not pass"
fi

require_file "$MANIFEST"
require_file "$TRACKED_BACKLOG"
require_file "$LIVE_BACKLOG"
require_file "$AUTHORIZATION"
require_file "$DECISIONS"
require_file "$STOPS"
require_file "$PREFLIGHT"

AUTHORIZATION_ID=
ACTIVATION_TASK_ID=
ACTIVATION_PREREQUISITE=
if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  AUTHORIZATION_ID=$(jq -r '.captain_authorization_id // empty' "$MANIFEST")
  ACTIVATION_TASK_ID=$(jq -r '.activation_task_id // empty' "$MANIFEST")
  ACTIVATION_PREREQUISITE=$(jq -r --arg activation_id "$ACTIVATION_TASK_ID" '.tasks[] | select(.id == $activation_id) | .depends_on[0] // empty' "$MANIFEST")
  while IFS= read -r id; do
    [ -n "$id" ] || continue
    ACTIVATION_IDS+=("$id")
  done < <(jq -r '.activation_task_ids[]?' "$MANIFEST")
else
  AUTHORIZATION_ID=
fi

if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  if [ -z "$ACTIVATION_TASK_ID" ]; then
    error "manifest activation_task_id is missing"
  elif [ -z "$ACTIVATION_PREREQUISITE" ]; then
    error "activation task prerequisite is missing from the manifest"
  elif ! jq -e --arg activation_id "$ACTIVATION_TASK_ID" '
    . as $root
    | [$root.activation_task_ids[] as $id | $root.tasks[] | select(.id == $id)] as $rows
    | if (($root.activation_task_id == $activation_id)
        and (([$root.tasks[] | select(.id == $activation_id)] | length) == 1)
        and (([$root.tasks[] | select(.id == $activation_id)][0].depends_on | length) == 1)
        and (($root.activation_task_ids | all(. != $activation_id)))
        and (($root.activation_task_ids | length) > 0)
        and (($root.activation_task_ids | unique | length) == ($root.activation_task_ids | length))
        and (($rows | length) == ($root.activation_task_ids | length))
        and (($rows | map(
          ((.title | type) == "string")
          and ((.title | length) > 0)
          and (.depends_on == [$activation_id])
          and ((.evidence_ids | length) == 1)
          and ((.evidence_ids[0] | test("^omp-evidence-")))
          and ((.rollback_id | type) == "string")
          and ((.rollback_id | test("^omp-rollback-")))
        )) | all))
      then true else false end
  ' "$MANIFEST" >/dev/null 2>&1; then
    error "activation task manifest rows are not closed over the activation record"
  fi
fi

if [ -f "$AUTHORIZATION" ]; then
  if ! jq -e --arg id "$AUTHORIZATION_ID" '.schema == "omp-captain-authorization.v1" and ([.records[]? | select(.id == $id and .status == "authorized")] | length) == 1' "$AUTHORIZATION" >/dev/null 2>&1; then
    error "captain authorization is absent, unauthorized, or has the wrong schema"
  fi
fi

if [ -f "$DECISIONS" ]; then
  if ! jq -e '.schema == "omp-decision-inventory.v1" and ((.open_keys // []) | length) == 0' "$DECISIONS" >/dev/null 2>&1; then
    error "decision-hold inventory is not clean"
  fi
fi

if [ -f "$STOPS" ]; then
  if ! jq -e '.schema == "omp-stop-ledger.v1" and ((.open_stop_ids // []) | length) == 0' "$STOPS" >/dev/null 2>&1; then
    error "STOP ledger has an open or invalid row"
  fi
fi

if [ -d "$REPO_ROOT/.git" ] || [ -f "$REPO_ROOT/.git" ]; then
  REPO_STATUS=$(git -C "$REPO_ROOT" status --porcelain --untracked-files=all 2>/dev/null || true)
  if [ -n "$REPO_STATUS" ]; then
    error "activation repository is not clean"
  fi
  REPO_BRANCH=$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || true)
  REPO_COMMIT=$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)
else
  error "activation repository is not a Git worktree: $REPO_ROOT"
  REPO_BRANCH=
  REPO_COMMIT=
fi

EXPECTED_REPORT_SHA256=
EXPECTED_TRACKED_SHA256=
EXPECTED_LIVE_SHA256=
EXPECTED_BRANCH=
EXPECTED_COMMIT=
if [ -f "$PREFLIGHT" ]; then
  if ! jq -e '.schema == "omp-activation-preflight.v1"' "$PREFLIGHT" >/dev/null 2>&1; then
    error "activation preflight has the wrong schema"
  fi
  EXPECTED_REPORT_SHA256=$(jq -r '.report_sha256 // empty' "$PREFLIGHT")
  EXPECTED_TRACKED_SHA256=$(jq -r '.tracked_backlog_sha256 // empty' "$PREFLIGHT")
  EXPECTED_LIVE_SHA256=$(jq -r '.live_backlog_sha256 // empty' "$PREFLIGHT")
  EXPECTED_BRANCH=$(jq -r '.repo_branch // empty' "$PREFLIGHT")
  EXPECTED_COMMIT=$(jq -r '.repo_commit // empty' "$PREFLIGHT")
  [ -n "$EXPECTED_REPORT_SHA256" ] || error "activation preflight field report_sha256 is empty"
  [ -n "$EXPECTED_TRACKED_SHA256" ] || error "activation preflight field tracked_backlog_sha256 is empty"
  [ -n "$EXPECTED_LIVE_SHA256" ] || error "activation preflight field live_backlog_sha256 is empty"
  [ -n "$EXPECTED_BRANCH" ] || error "activation preflight field repo_branch is empty"
  [ -n "$EXPECTED_COMMIT" ] || error "activation preflight field repo_commit is empty"
  printf '%s\n' "$EXPECTED_REPORT_SHA256" | grep -Eq '^[0-9a-fA-F]{64}$' || error "activation preflight report_sha256 is not a SHA-256 digest"
  printf '%s\n' "$EXPECTED_TRACKED_SHA256" | grep -Eq '^[0-9a-fA-F]{64}$' || error "activation preflight tracked_backlog_sha256 is not a SHA-256 digest"
  printf '%s\n' "$EXPECTED_LIVE_SHA256" | grep -Eq '^[0-9a-fA-F]{64}$' || error "activation preflight live_backlog_sha256 is not a SHA-256 digest"
  printf '%s\n' "$EXPECTED_COMMIT" | grep -Eq '^[0-9a-fA-F]{40}$' || error "activation preflight repo_commit is not a full Git commit"
  if [ -n "$EXPECTED_REPORT_SHA256" ] && [ "$EXPECTED_REPORT_SHA256" != "$REPORT_SHA256" ]; then
    error "report hash does not match activation preflight"
  fi
  if [ -n "$EXPECTED_TRACKED_SHA256" ] && [ -f "$TRACKED_BACKLOG" ] && [ "$EXPECTED_TRACKED_SHA256" != "$(sha256 "$TRACKED_BACKLOG")" ]; then
    error "tracked backlog bytes do not match activation preflight"
  fi
  if [ -n "$EXPECTED_LIVE_SHA256" ] && [ -f "$LIVE_BACKLOG" ] && [ "$EXPECTED_LIVE_SHA256" != "$(sha256 "$LIVE_BACKLOG")" ]; then
    error "live backlog bytes do not match activation preflight"
  fi
  if [ -n "$EXPECTED_BRANCH" ] && [ "$EXPECTED_BRANCH" != "$REPO_BRANCH" ]; then
    error "Git branch does not match activation preflight"
  fi
  if [ -n "$EXPECTED_COMMIT" ] && [ "$EXPECTED_COMMIT" != "$REPO_COMMIT" ]; then
    error "Git commit does not match activation preflight"
  fi
fi

if [ -f "$ROOT/bin/fm-harness.sh" ]; then
  if grep -Eq '(^|[^[:alnum:]_-])omp([^[:alnum:]_-]|$)' "$ROOT/bin/fm-harness.sh"; then
    error "OMP appears in the verified harness allowlist"
  fi
fi

if [ -f "$MANIFEST" ]; then
  if [ -z "${ACTIVATION_TASK_ID}" ] || ! grep -Eq "^- \[ \] ${ACTIVATION_TASK_ID}([[:space:]-]|$)" "$LIVE_BACKLOG"; then
    error "activation record ${ACTIVATION_TASK_ID:-<missing>} is not queued in the live backlog"
  elif ! PREIMAGE_READY_OUTPUT=$("$TASKS_AXI" ready --file "$LIVE_BACKLOG" 2>/dev/null); then
    error "Tasks Axi could not compute readiness for the activation preimage"
  elif ! printf '%s\n' "$PREIMAGE_READY_OUTPUT" | grep -Eq "(^|[[:space:],])${ACTIVATION_TASK_ID}(,|$)"; then
    error "activation record $ACTIVATION_TASK_ID is not ready in the live backlog preimage"
  fi
  for activation_id in "${ACTIVATION_IDS[@]}"; do
    if contains_task "$activation_id" "$TRACKED_BACKLOG" || contains_task "$activation_id" "$LIVE_BACKLOG"; then
      error "activation-published P1 row already exists in a live or tracked backlog: $activation_id"
    fi
  done
  while IFS= read -r future_id; do
    [ -n "$future_id" ] || continue
    if ! is_activation_task "$future_id" && { contains_task "$future_id" "$TRACKED_BACKLOG" || contains_task "$future_id" "$LIVE_BACKLOG"; }; then
      error "premature P1-P8 task is present in a live or tracked backlog: $future_id"
    fi
  done < <(jq -r --arg activation_id "$ACTIVATION_TASK_ID" '.tasks[] | select(.phase != "P0" and .id != $activation_id) | .id' "$MANIFEST")
fi

if [ "$ACTION" = activate ] && [ "${#ERRORS[@]}" -eq 0 ]; then
  if [ -e "$RECEIPT" ] || [ -L "$RECEIPT" ]; then
    error "activation receipt already exists; refusing a second publication"
  else
    ROWS="$TMP_DIR/activation-rows.md"
    NEW_BACKLOG=
    BACKUP=
    NEW_RECEIPT=
    BACKLOG_PUBLISHED=0
    RECEIPT_PUBLISHED=0
    PUBLISHED_ROW_COUNT=0
    : >"$ROWS"
    while IFS=$'\t' read -r task_id title dependency evidence_id rollback_id; do
      [ -n "$task_id" ] || continue
      {
        printf '%s\n' "- [ ] $task_id - $title (repo: AgentThemis) (kind: ops) (priority: 0) (since $ACTIVATION_DATE) blocked-by: $dependency"
        printf '%s\n' "  Manifest: .agents/tasks/omp-manifest.json; evidence: $evidence_id; rollback: $rollback_id."
        printf '%s\n' "  Support fence: experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support."
      } >>"$ROWS"
      PUBLISHED_ROW_COUNT=$((PUBLISHED_ROW_COUNT + 1))
    done < <(jq -r --arg activation_id "$ACTIVATION_TASK_ID" '.activation_task_ids[] as $id | .tasks[] | select(.id == $id) | [$id, .title, (.depends_on | join(",")), .evidence_ids[0], .rollback_id] | @tsv' "$MANIFEST")
    if [ "$PUBLISHED_ROW_COUNT" -ne "${#ACTIVATION_IDS[@]}" ]; then
      error "manifest activation task rows did not produce the expected publication set"
    fi

    LIVE_DIR=$(dirname -- "$LIVE_BACKLOG")
    RECEIPT_DIR=$(dirname -- "$RECEIPT")
    if [ ! -d "$LIVE_DIR" ]; then
      error "live backlog directory is unavailable"
    elif [ ! -d "$RECEIPT_DIR" ]; then
      error "activation receipt directory is unavailable"
    elif [ "$FAIL_STAGE" = receipt-dir ]; then
      error "fault injection refused at receipt-directory stage"
    elif ! NEW_BACKLOG=$(mktemp "$LIVE_DIR/.omp-activation-backlog.XXXXXX"); then
      error "could not allocate atomic backlog postimage"
    elif ! BACKUP=$(mktemp "$LIVE_DIR/.omp-activation-backup.XXXXXX"); then
      error "could not allocate exact backlog preimage"
    elif ! cp "$LIVE_BACKLOG" "$BACKUP"; then
      error "could not preserve exact backlog preimage"
    elif ! awk -v rows="$ROWS" -v activation_id="$ACTIVATION_TASK_ID" -v prerequisite_id="$ACTIVATION_PREREQUISITE" -v activation_date="$ACTIVATION_DATE" '
      BEGIN { activation_seen=0; activation_block=0; activation_record=""; pending_blank=""; inserted=0; moved=0 }
      $0 ~ "^- \\[ \\] " activation_id "([[:space:]-]|$)" {
        sub(/^- \[ \]/, "- [x]")
        sub("[[:space:]]+blocked-by:[[:space:]]*" prerequisite_id, "")
        sub(/\(since [^)]+\)/, "(done " activation_date ")")
        activation_seen++
        activation_record=$0 "\n"
        activation_block=1
        next
      }
      activation_block {
        if ($0 ~ /^[[:space:]]/) {
          activation_record=activation_record pending_blank $0 "\n"
          pending_blank=""
          next
        }
        if ($0 == "") {
          pending_blank=pending_blank "\n"
          next
        }
        activation_block=0
        pending_blank=""
      }
      $0 == "## Done" {
        print
        if (activation_record != "") {
          printf "%s", activation_record
          activation_record=""
          moved=1
        }
        next
      }
      activation_block && ($0 ~ /^- \[[ xX]\] / || $0 ~ /^## /) { activation_block=0 }
      activation_block { next }
      $0 == "## Queued" {
        print
        while ((getline line < rows) > 0) print line
        close(rows)
        inserted=1
        next
      }
      { print }
      END { if (activation_seen != 1 || inserted != 1 || moved != 1 || activation_record != "") exit 2 }
    ' "$LIVE_BACKLOG" >"$NEW_BACKLOG"; then
      error "live backlog postimage did not contain exactly one completed activation record and queue insertion"
    elif ! "$TASKS_AXI" list --file "$NEW_BACKLOG" >/dev/null 2>&1; then
      error "Tasks Axi rejected the proposed atomic backlog publication"
    elif ! POSTIMAGE_LIST=$($TASKS_AXI list --file "$NEW_BACKLOG" 2>/dev/null); then
      error "Tasks Axi could not inspect the activation postimage"
    elif ! printf '%s\n' "$POSTIMAGE_LIST" | grep -Fq "${ACTIVATION_TASK_ID},done,"; then
      error "proposed backlog postimage did not complete $ACTIVATION_TASK_ID: $POSTIMAGE_LIST"
    elif ! READY_OUTPUT=$($TASKS_AXI ready --file "$NEW_BACKLOG" 2>/dev/null); then
      error "Tasks Axi could not compute readiness for the proposed backlog postimage"
    else
      for activation_id in "${ACTIVATION_IDS[@]}"; do
        if ! printf '%s\n' "$READY_OUTPUT" | grep -Fq "$activation_id"; then
          error "proposed backlog postimage did not make activation task ready: $activation_id"
        fi
      done
    fi

    if [ "${#ERRORS[@]}" -eq 0 ]; then
      POST_LIVE_SHA256=$(sha256 "$NEW_BACKLOG") || error "could not hash atomic backlog postimage"
      TASK_IDS_JSON=$(printf '%s\n' "${ACTIVATION_IDS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
      if [ "$FAIL_STAGE" = receipt-temp ]; then
        error "fault injection refused at receipt-temp stage"
      elif ! NEW_RECEIPT=$(mktemp "$RECEIPT_DIR/.omp-activation-receipt.XXXXXX"); then
        error "could not allocate activation receipt postimage"
      elif [ "$FAIL_STAGE" = receipt-write ]; then
        error "fault injection refused at receipt-write stage"
      elif ! jq -n --arg schema 'omp-activation-receipt.v1' --arg preimage "$EXPECTED_LIVE_SHA256" --arg postimage "$POST_LIVE_SHA256" --arg branch "$REPO_BRANCH" --arg commit "$REPO_COMMIT" --arg report "$REPORT_SHA256" --arg completed "$ACTIVATION_TASK_ID" --argjson task_ids "$TASK_IDS_JSON" '{schema:$schema,action:"activate",preimage_sha256:$preimage,postimage_sha256:$postimage,repo_branch:$branch,repo_commit:$commit,report_sha256:$report,completed_activation_task_id:$completed,activation_completed:true,task_ids:$task_ids}' >"$NEW_RECEIPT"; then
        error "could not write activation receipt postimage"
      elif ! jq -e --arg activation_id "$ACTIVATION_TASK_ID" --argjson expected_task_ids "$TASK_IDS_JSON" '.schema == "omp-activation-receipt.v1" and .activation_completed == true and .completed_activation_task_id == $activation_id and .task_ids == $expected_task_ids' "$NEW_RECEIPT" >/dev/null 2>&1; then
        error "activation receipt postimage failed schema validation"
      elif [ "$FAIL_STAGE" = backlog-move ]; then
        error "fault injection refused at backlog-move stage"
      elif ! mv -f -- "$NEW_BACKLOG" "$LIVE_BACKLOG"; then
        error "could not publish backlog postimage"
      else
        BACKLOG_PUBLISHED=1
        if [ "$FAIL_STAGE" = receipt-move ]; then
          error "fault injection refused at receipt-move stage"
        elif ! mv -f -- "$NEW_RECEIPT" "$RECEIPT"; then
          error "could not publish activation receipt"
        else
          RECEIPT_PUBLISHED=1
        fi
      fi
    fi

    if [ "${#ERRORS[@]}" -gt 0 ] && [ "$BACKLOG_PUBLISHED" -eq 1 ]; then
      if ! mv -f -- "$BACKUP" "$LIVE_BACKLOG"; then
        error "activation rollback could not restore the exact backlog preimage"
      else
        BACKUP=
      fi
      if [ "$RECEIPT_PUBLISHED" -eq 1 ] || [ -e "$RECEIPT" ] || [ -L "$RECEIPT" ]; then
        if ! rm -f -- "$RECEIPT"; then
          error "activation rollback could not remove the failed receipt"
        fi
      fi
    fi
    [ -z "$NEW_BACKLOG" ] || [ ! -e "$NEW_BACKLOG" ] || rm -f -- "$NEW_BACKLOG" || error "activation cleanup could not remove backlog temporary file"
    [ -z "$NEW_RECEIPT" ] || [ ! -e "$NEW_RECEIPT" ] || rm -f -- "$NEW_RECEIPT" || error "activation cleanup could not remove receipt temporary file"
    [ -z "$BACKUP" ] || [ ! -e "$BACKUP" ] || rm -f -- "$BACKUP" || error "activation cleanup could not remove backlog preimage temporary file"
  fi
fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    ISSUES=$(printf '%s\n' "${ERRORS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'BLOCK' --arg action "$ACTION" --argjson issues "$ISSUES" '{schema:$schema,status:$status,action:$action,issues:$issues}'
  elif [ "$ACTION" = activate ]; then
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'PASS' --arg action "$ACTION" --argjson task_ids "$(printf '%s\n' "${ACTIVATION_IDS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')" '{schema:$schema,status:$status,action:$action,published_task_ids:$task_ids}'
  else
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'PASS' --arg action "$ACTION" '{schema:$schema,status:$status,action:$action,published_task_ids:[]}'
  fi
else
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    printf 'BLOCK\n'
    printf '%s\n' "${ERRORS[@]}" >&2
  elif [ "$ACTION" = activate ]; then
    printf 'PASS: activation publication committed atomically\n'
  else
    printf 'PASS: activation gate passed without publication\n'
  fi
fi

[ "${#ERRORS[@]}" -eq 0 ]
