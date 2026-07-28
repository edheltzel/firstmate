#!/usr/bin/env bash
# Gate and atomically publish the first corrected OMP phase as one authoritative backlog postimage.
# Usage: bin/fm-omp-activation.sh [--check|--activate] [--json] [--test-only] [--report PATH] [--manifest PATH] [--roadmap PATH] [--tracked-backlog PATH] [--live-backlog PATH] [--repo-root PATH] [--authorization PATH] [--decisions PATH] [--stops PATH] [--preflight PATH]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
FM_HOME_ROOT=${FM_HOME:-$ROOT}
REPORT=${FM_OMP_REPORT:-$FM_HOME_ROOT/data/omp-final-authority-redteam-o10/report.md}
MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
RUNTIME_PIN="$ROOT/.agents/tasks/omp-runtime-pin.json"
ROADMAP="$ROOT/.agents/tasks/roadmap.md"
TRACKED_BACKLOG="$ROOT/.agents/tasks/backlog.md"
LIVE_BACKLOG="$FM_HOME_ROOT/data/backlog.md"
REPO_ROOT="$ROOT"
AUTHORIZATION="$FM_HOME_ROOT/data/omp-captain-authorization.json"
DECISIONS="$FM_HOME_ROOT/data/omp-decision-inventory.json"
STOPS="$FM_HOME_ROOT/data/omp-stop-ledger.json"
PREFLIGHT="$FM_HOME_ROOT/data/omp-activation-preflight.json"
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
TEST_ONLY=0
ACTIVATION_LOCK="$FM_HOME_ROOT/state/.omp-activation.lock"
LOCK_HELD=0

usage() {
  sed -n '2,3p' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) ACTION=check ;;
    --activate) ACTION=activate ;;
    --json) JSON_OUTPUT=1 ;;
    --test-only) TEST_ONLY=1 ;;
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
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$TEST_ONLY" -eq 1 ] && [ "${FM_OMP_TEST_MODE:-0}" != 1 ]; then
  printf 'test-only activation mode requires FM_OMP_TEST_MODE=1\n' >&2
  exit 2
fi

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
cleanup_activation_lock() {
  if [ "$LOCK_HELD" -eq 1 ] && [ -f "$ACTIVATION_LOCK/owner" ] && [ "$(sed -n 's/^pid=//p' "$ACTIVATION_LOCK/owner" | head -n 1)" = "$$" ]; then
    rmdir "$ACTIVATION_LOCK" 2>/dev/null || true
  fi
}
activation_test_pause() {
  local stage=$1 ready resume
  [ "$TEST_ONLY" -eq 1 ] || return 0
  [ "${FM_OMP_ACTIVATION_PAUSE_STAGE:-}" = "$stage" ] || return 0
  ready=${FM_OMP_ACTIVATION_PAUSE_READY_FILE:-$TMP_DIR/pause-ready}
  resume=${FM_OMP_ACTIVATION_PAUSE_RESUME_FILE:-$TMP_DIR/pause-resume}
  : >"$ready" || return 1
  while [ ! -e "$resume" ]; do sleep 0.05; done
}
trap 'cleanup_activation_lock; rm -rf "$TMP_DIR"' EXIT HUP INT TERM

if [ "$TEST_ONLY" -eq 0 ]; then
  if [ "$REPORT" != "$FM_HOME_ROOT/data/omp-final-authority-redteam-o10/report.md" ] ||
    [ "$MANIFEST" != "$ROOT/.agents/tasks/omp-manifest.json" ] ||
    [ "$RUNTIME_PIN" != "$ROOT/.agents/tasks/omp-runtime-pin.json" ] ||
    [ "$ROADMAP" != "$ROOT/.agents/tasks/roadmap.md" ] ||
    [ "$TRACKED_BACKLOG" != "$ROOT/.agents/tasks/backlog.md" ] ||
    [ "$LIVE_BACKLOG" != "$FM_HOME_ROOT/data/backlog.md" ] ||
    [ "$REPO_ROOT" != "$ROOT" ] ||
    [ "$AUTHORIZATION" != "$FM_HOME_ROOT/data/omp-captain-authorization.json" ] ||
    [ "$DECISIONS" != "$FM_HOME_ROOT/data/omp-decision-inventory.json" ] ||
    [ "$STOPS" != "$FM_HOME_ROOT/data/omp-stop-ledger.json" ] ||
    [ "$PREFLIGHT" != "$FM_HOME_ROOT/data/omp-activation-preflight.json" ]; then
    error "production activation inputs must be canonical; use explicit test-only mode for fixtures"
  fi
fi

acquire_activation_lock() {
  mkdir -p "$(dirname "$ACTIVATION_LOCK")" 2>/dev/null || {
    error "activation lock parent is unavailable: $(dirname "$ACTIVATION_LOCK")"
    return
  }
  if mkdir "$ACTIVATION_LOCK" 2>/dev/null; then
    printf 'pid=%s\nbranch=%s\ncommit=%s\n' "$$" "$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || true)" "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)" >"$ACTIVATION_LOCK/owner"
    LOCK_HELD=1
    return
  fi
  local owner_pid
  owner_pid=$(sed -n 's/^pid=//p' "$ACTIVATION_LOCK/owner" 2>/dev/null | head -n 1 || true)
  if printf '%s\n' "$owner_pid" | grep -Eq '^[0-9]+$' && [ "$owner_pid" != "$$" ] && ! kill -0 "$owner_pid" 2>/dev/null; then
    mv "$ACTIVATION_LOCK" "$ACTIVATION_LOCK.stale.$owner_pid" 2>/dev/null || {
      error "activation lock is held and stale-lock quarantine failed"
      return
    }
    if mkdir "$ACTIVATION_LOCK" 2>/dev/null; then
      printf 'pid=%s\nbranch=%s\ncommit=%s\n' "$$" "$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || true)" "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)" >"$ACTIVATION_LOCK/owner"
      LOCK_HELD=1
      return
    fi
  fi
  error "activation lock is already held; refusing concurrent publication"
}

if [ "$ACTION" = activate ]; then
  acquire_activation_lock
fi

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

sha256_stdin() {
  case "$SHA256_TOOL" in
    */shasum|shasum) "$SHA256_TOOL" -a 256 | awk '{print $1}' ;;
    */sha256sum|sha256sum) "$SHA256_TOOL" | awk '{print $1}' ;;
    *) return 1 ;;
  esac
}

postimage_hash() {
  sed -E 's/("postimage_sha256":")[0-9a-fA-F]{64}/\1<self>/' "$1" | sha256_stdin
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
    /^##[[:space:]]+Executive disposition[[:space:]]*$/ { section=1; headings++; next }
    /^##[[:space:]]/ { section=0; next }
    section && /^(PASS|BLOCK|CONDITIONAL PASS)$/ { status=$0; statuses++ }
    END { if (headings != 1 || statuses != 1) exit 1; print status }
  ' "$REPORT" 2>/dev/null || true)
  if [ -z "$REPORT_DISPOSITION" ]; then
    error "report has no exact Executive disposition"
  elif [ "$REPORT_DISPOSITION" != "PASS" ]; then
    error "report disposition is $REPORT_DISPOSITION; activation requires PASS"
  fi
else
  error "missing corrected-plan report: $REPORT"
fi

REPORT_PLAN_BLOCKERS=
if [ -f "$REPORT" ]; then
  REPORT_PLAN_BLOCKERS=$(awk '
    /^##[[:space:]]+Plan-blocking findings[[:space:]]*$/ { in_blockers=1; headings++; next }
    in_blockers && /^##[[:space:]]/ { in_blockers=0; next }
    in_blockers && NF {
      line=$0
      sub(/^[[:space:]]+/, "", line)
      sub(/[[:space:]]+$/, "", line)
      body = body (body == "" ? "" : "\n") line
      lines++
    }
    END { if (headings != 1 || lines != 1 || body != "None.") exit 1; print "none" }
  ' "$REPORT" 2>/dev/null || true)
  if [ "$REPORT_PLAN_BLOCKERS" != none ]; then
    error "report must declare no plan-blocking findings under the exact heading"
  fi
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

RUNTIME_PIN_JSON=$(
  "$ROOT/bin/fm-omp-runtime-pin-check.sh" --json --pin "$RUNTIME_PIN" 2>/dev/null || true
)
if [ "$(printf '%s' "$RUNTIME_PIN_JSON" | jq -r '.status // "BLOCK"' 2>/dev/null || printf BLOCK)" != PASS ]; then
  error "installed OMP runtime does not match the versioned pre-activation pin"
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
ACTIVATION_REPORT_TASK_ID=
ACTIVATION_REPORT_PATH=
SUPPORT_FENCE=
TASK_RECORDS_JSON='[]'
TASK_IDS_JSON='[]'
if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  AUTHORIZATION_ID=$(jq -r '.captain_authorization_id // empty' "$MANIFEST")
  ACTIVATION_TASK_ID=$(jq -r '.activation_task_id // empty' "$MANIFEST")
  ACTIVATION_PREREQUISITE=$(jq -r --arg activation_id "$ACTIVATION_TASK_ID" '.tasks[] | select(.id == $activation_id) | .depends_on[0] // empty' "$MANIFEST")
  ACTIVATION_REPORT_TASK_ID=$(jq -r '.activation_report_task_id // empty' "$MANIFEST")
  ACTIVATION_REPORT_PATH=$(jq -r '.activation_report_path // empty' "$MANIFEST")
  SUPPORT_FENCE=$(jq -r '.support_fence // empty' "$MANIFEST")
  TASK_RECORDS_JSON=$(jq -c '[.activation_task_ids[] as $id | .tasks[] | select(.id == $id) | {id:.id,depends_on:.depends_on,evidence_ids:.evidence_ids,rollback_id:.rollback_id}]' "$MANIFEST")
  TASK_IDS_JSON=$(jq -c '.activation_task_ids' "$MANIFEST")
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

if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  if [ "$ACTIVATION_REPORT_TASK_ID" != "omp-final-authority-redteam-o10" ]; then
    error "activation report task must be omp-final-authority-redteam-o10"
  fi
  if [ "$ACTIVATION_REPORT_PATH" != "data/omp-final-authority-redteam-o10/report.md" ]; then
    error "activation report path must be data/omp-final-authority-redteam-o10/report.md"
  fi
  EXPECTED_REPORT_PATH="$FM_HOME_ROOT/$ACTIVATION_REPORT_PATH"
  if [ "$REPORT" != "$EXPECTED_REPORT_PATH" ]; then
    error "activation report path does not match the O10 manifest path: $REPORT"
  fi
  if ! jq -e --arg id "$ACTIVATION_REPORT_TASK_ID" --arg path "$ACTIVATION_REPORT_PATH" '.tasks | map(select(.id == $id and .report_path == $path)) | length == 1' "$MANIFEST" >/dev/null 2>&1; then
    error "activation report task and manifest path are not paired"
  fi
  for parity_file in "$ROOT/.agents/plans/omp-harness-integration-plan.md" "$ROADMAP" "$TRACKED_BACKLOG"; do
    if [ -f "$parity_file" ] && { ! grep -Fq "$ACTIVATION_REPORT_TASK_ID" "$parity_file" || ! grep -Fq "$ACTIVATION_REPORT_PATH" "$parity_file"; }; then
      error "activation report task/path parity is missing from $parity_file"
    fi
  done
fi

validate_receipt_file() {
  local receipt_path=$1 expected_postimage=$2
  jq -e --arg expected_postimage "$expected_postimage" --arg expected_preimage "$EXPECTED_LIVE_SHA256" --arg report_task_id "$ACTIVATION_REPORT_TASK_ID" --arg report_path "$ACTIVATION_REPORT_PATH" --arg report_sha256 "$REPORT_SHA256" --arg authorization_id "$AUTHORIZATION_ID" --arg activation_id "$ACTIVATION_TASK_ID" --arg activation_date "$ACTIVATION_DATE" --arg support_fence "$SUPPORT_FENCE" --arg branch "$REPO_BRANCH" --arg commit "$REPO_COMMIT" --argjson task_ids "$TASK_IDS_JSON" --argjson task_records "$TASK_RECORDS_JSON" '
    .schema == "omp-activation-receipt.v1"
    and .action == "activate"
    and .activation_completed == true
    and (.preimage_sha256 | test("^[0-9a-fA-F]{64}$"))
    and (($expected_preimage == "") or .preimage_sha256 == $expected_preimage)
    and .postimage_sha256 == $expected_postimage
    and .repo_branch == $branch
    and .repo_commit == $commit
    and .report_task_id == $report_task_id
    and .report_path == $report_path
    and .report_sha256 == $report_sha256
    and .authorization_id == $authorization_id
    and .completed_activation_task_id == $activation_id
    and .activation_date == $activation_date
    and .support_fence == $support_fence
    and .task_ids == $task_ids
    and .task_records == $task_records
  ' "$receipt_path" >/dev/null 2>&1
}

ALREADY_ACTIVATED=0
AUTHORITATIVE_RECEIPT="$TMP_DIR/authoritative-receipt.json"
if [ -f "$LIVE_BACKLOG" ]; then
  AUTHORITATIVE_RECEIPT_LINE_COUNT=$(grep -Ec '^  Activation receipt: ' "$LIVE_BACKLOG" || true)
  if [ "$AUTHORITATIVE_RECEIPT_LINE_COUNT" -gt 1 ]; then
    error "live backlog contains multiple authoritative activation receipts"
  elif [ "$AUTHORITATIVE_RECEIPT_LINE_COUNT" -eq 1 ]; then
    sed -n 's/^  Activation receipt: //p' "$LIVE_BACKLOG" >"$AUTHORITATIVE_RECEIPT"
    if jq empty "$AUTHORITATIVE_RECEIPT" >/dev/null 2>&1; then
      ALREADY_ACTIVATED=1
    else
      error "embedded activation receipt is not valid JSON"
    fi
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
if [ "$TEST_ONLY" -eq 0 ]; then
  if [ ! -x "$ROOT/bin/fm-decision-hold.sh" ] || ! FM_HOME="$FM_HOME_ROOT" "$ROOT/bin/fm-decision-hold.sh" verify "$ACTIVATION_REPORT_TASK_ID" >/dev/null 2>&1; then
    error "decision-hold verification did not pass for the O10 authority task"
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
if [ "$ALREADY_ACTIVATED" -eq 0 ] && [ -f "$PREFLIGHT" ]; then
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

if [ "$ALREADY_ACTIVATED" -eq 1 ]; then
  AUTHORITATIVE_POSTIMAGE_SHA256=$(postimage_hash "$LIVE_BACKLOG" || true)
  if [ -z "$AUTHORITATIVE_POSTIMAGE_SHA256" ] || ! validate_receipt_file "$AUTHORITATIVE_RECEIPT" "$AUTHORITATIVE_POSTIMAGE_SHA256"; then
    error "authoritative activation receipt does not match the completed backlog postimage"
  fi
  if [ "$ACTION" = activate ]; then
    error "authoritative activation record is already complete; refusing duplicate publication"
  fi
fi

if [ -f "$ROOT/bin/fm-harness.sh" ]; then
  if grep -Eq '(^|[^[:alnum:]_-])omp([^[:alnum:]_-]|$)' "$ROOT/bin/fm-harness.sh"; then
    error "OMP appears in the verified harness allowlist"
  fi
fi

if [ -f "$MANIFEST" ]; then
  if [ "$ALREADY_ACTIVATED" -eq 0 ]; then
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
  else
    for activation_id in "${ACTIVATION_IDS[@]}"; do
      if ! contains_task "$activation_id" "$LIVE_BACKLOG"; then
        error "authoritative activation postimage is missing published task: $activation_id"
      fi
      if contains_task "$activation_id" "$TRACKED_BACKLOG"; then
        error "tracked backlog contains an activation-published P1 row: $activation_id"
      fi
    done
  fi
  while IFS= read -r future_id; do
    [ -n "$future_id" ] || continue
    if ! is_activation_task "$future_id" && { contains_task "$future_id" "$TRACKED_BACKLOG" || contains_task "$future_id" "$LIVE_BACKLOG"; }; then
      error "premature P1-P8 task is present in a live or tracked backlog: $future_id"
    fi
  done < <(jq -r --arg activation_id "$ACTIVATION_TASK_ID" '.tasks[] | select(.phase != "P0" and .id != $activation_id) | .id' "$MANIFEST")
fi

if [ "$ACTION" = activate ] && [ "${#ERRORS[@]}" -eq 0 ]; then
  ROWS="$TMP_DIR/activation-rows.md"
  NEW_BACKLOG_TEMPLATE="$TMP_DIR/activation-backlog-template.md"
  NEW_BACKLOG=
  RECEIPT_TEMPLATE_FILE="$TMP_DIR/activation-receipt-template.json"
  RECEIPT_FINAL_FILE="$TMP_DIR/activation-receipt-final.json"
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

    if [ "${#ERRORS[@]}" -eq 0 ]; then
      if [ "$FAIL_STAGE" = receipt-template ]; then
        error "fault injection refused at receipt-template stage"
      elif ! jq -cn --arg schema 'omp-activation-receipt.v1' --arg preimage "$EXPECTED_LIVE_SHA256" --arg postimage '<self>' --arg branch "$REPO_BRANCH" --arg commit "$REPO_COMMIT" --arg report_task_id "$ACTIVATION_REPORT_TASK_ID" --arg report_path "$ACTIVATION_REPORT_PATH" --arg report_sha256 "$REPORT_SHA256" --arg authorization_id "$AUTHORIZATION_ID" --arg completed "$ACTIVATION_TASK_ID" --arg activation_date "$ACTIVATION_DATE" --arg support_fence "$SUPPORT_FENCE" --argjson task_ids "$TASK_IDS_JSON" --argjson task_records "$TASK_RECORDS_JSON" '{schema:$schema,action:"activate",activation_completed:true,preimage_sha256:$preimage,postimage_sha256:$postimage,repo_branch:$branch,repo_commit:$commit,report_task_id:$report_task_id,report_path:$report_path,report_sha256:$report_sha256,authorization_id:$authorization_id,completed_activation_task_id:$completed,activation_date:$activation_date,support_fence:$support_fence,task_ids:$task_ids,task_records:$task_records}' >"$RECEIPT_TEMPLATE_FILE"; then
        error "could not write activation receipt template"
      elif ! validate_receipt_file "$RECEIPT_TEMPLATE_FILE" '<self>'; then
        error "activation receipt template failed schema validation"
      fi
    fi

    LIVE_DIR=$(dirname -- "$LIVE_BACKLOG")
    if [ "${#ERRORS[@]}" -eq 0 ] && [ ! -d "$LIVE_DIR" ]; then
      error "live backlog directory is unavailable"
    elif [ "${#ERRORS[@]}" -eq 0 ] && [ "$FAIL_STAGE" = template ]; then
      error "fault injection refused at template stage"
    elif [ "${#ERRORS[@]}" -eq 0 ] && ! awk -v rows="$ROWS" -v receipt_file="$RECEIPT_TEMPLATE_FILE" -v activation_id="$ACTIVATION_TASK_ID" -v prerequisite_id="$ACTIVATION_PREREQUISITE" -v activation_date="$ACTIVATION_DATE" '
      BEGIN {
        activation_seen=0
        activation_block=0
        activation_record=""
        pending_blank=""
        inserted=0
        moved=0
        if ((getline receipt < receipt_file) <= 0) exit 3
        close(receipt_file)
      }
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
          print "  Activation receipt: " receipt
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
    ' "$LIVE_BACKLOG" >"$NEW_BACKLOG_TEMPLATE"; then
      error "live backlog postimage did not contain exactly one completed activation record and queue insertion"
    elif ! "$TASKS_AXI" list --file "$NEW_BACKLOG_TEMPLATE" >/dev/null 2>&1; then
      error "Tasks Axi rejected the proposed atomic backlog publication"
    elif ! POSTIMAGE_LIST=$($TASKS_AXI list --file "$NEW_BACKLOG_TEMPLATE" 2>/dev/null); then
      error "Tasks Axi could not inspect the activation postimage"
    elif ! printf '%s\n' "$POSTIMAGE_LIST" | grep -Fq "${ACTIVATION_TASK_ID},done,"; then
      error "proposed backlog postimage did not complete $ACTIVATION_TASK_ID: $POSTIMAGE_LIST"
    elif [ "$(grep -Ec '^  Activation receipt: ' "$NEW_BACKLOG_TEMPLATE" || true)" -ne 1 ]; then
      error "proposed backlog postimage does not contain exactly one activation receipt"
    elif ! sed -n 's/^  Activation receipt: //p' "$NEW_BACKLOG_TEMPLATE" >"$TMP_DIR/receipt-from-template.json" || ! validate_receipt_file "$TMP_DIR/receipt-from-template.json" '<self>'; then
      error "proposed backlog activation receipt failed schema validation"
    elif ! READY_OUTPUT=$($TASKS_AXI ready --file "$NEW_BACKLOG_TEMPLATE" 2>/dev/null); then
      error "Tasks Axi could not compute readiness for the proposed backlog postimage"
    else
      for activation_id in "${ACTIVATION_IDS[@]}"; do
        if ! printf '%s\n' "$READY_OUTPUT" | grep -Fq "$activation_id"; then
          error "proposed backlog postimage did not make activation task ready: $activation_id"
        fi
      done
    fi

    if [ "${#ERRORS[@]}" -eq 0 ]; then
      if ! POST_LIVE_SHA256=$(postimage_hash "$NEW_BACKLOG_TEMPLATE"); then
        error "could not hash atomic backlog postimage"
      elif ! jq -c --arg postimage "$POST_LIVE_SHA256" '.postimage_sha256 = $postimage' "$RECEIPT_TEMPLATE_FILE" >"$RECEIPT_FINAL_FILE"; then
        error "could not write activation receipt postimage"
      elif ! validate_receipt_file "$RECEIPT_FINAL_FILE" "$POST_LIVE_SHA256"; then
        error "activation receipt postimage failed schema validation"
      elif ! NEW_BACKLOG=$(mktemp "$LIVE_DIR/.omp-activation-backlog.XXXXXX"); then
        error "could not allocate atomic backlog postimage"
      elif ! awk -v receipt_file="$RECEIPT_FINAL_FILE" '
        BEGIN {
          receipt_count=0
          if ((getline receipt < receipt_file) <= 0) exit 2
          close(receipt_file)
        }
        /^  Activation receipt: / {
          print "  Activation receipt: " receipt
          receipt_count++
          next
        }
        { print }
        END { if (receipt_count != 1) exit 3 }
      ' "$NEW_BACKLOG_TEMPLATE" >"$NEW_BACKLOG"; then
        error "could not embed the authoritative activation receipt"
      elif ! "$TASKS_AXI" list --file "$NEW_BACKLOG" >/dev/null 2>&1; then
        error "Tasks Axi rejected the complete activation postimage"
      elif ! FINAL_POSTIMAGE_LIST=$("$TASKS_AXI" list --file "$NEW_BACKLOG" 2>/dev/null); then
        error "Tasks Axi could not inspect the complete activation postimage"
      elif ! printf '%s\n' "$FINAL_POSTIMAGE_LIST" | grep -Fq "${ACTIVATION_TASK_ID},done,"; then
        error "complete backlog postimage did not complete $ACTIVATION_TASK_ID: $FINAL_POSTIMAGE_LIST"
      elif ! FINAL_READY_OUTPUT=$("$TASKS_AXI" ready --file "$NEW_BACKLOG" 2>/dev/null); then
        error "Tasks Axi could not compute readiness for the complete activation postimage"
      else
        for activation_id in "${ACTIVATION_IDS[@]}"; do
          if ! printf '%s\n' "$FINAL_READY_OUTPUT" | grep -Fq "$activation_id"; then
            error "complete backlog postimage did not make activation task ready: $activation_id"
          fi
        done
      fi
    fi

    if [ "${#ERRORS[@]}" -eq 0 ]; then
      sed -n 's/^  Activation receipt: //p' "$NEW_BACKLOG" >"$TMP_DIR/receipt-from-postimage.json"
      if [ "$(grep -Ec '^  Activation receipt: ' "$NEW_BACKLOG" || true)" -ne 1 ]; then
        error "complete backlog postimage does not contain exactly one authoritative receipt"
      elif ! validate_receipt_file "$TMP_DIR/receipt-from-postimage.json" "$POST_LIVE_SHA256"; then
        error "embedded activation receipt does not validate against the complete postimage"
      elif [ "$(postimage_hash "$NEW_BACKLOG")" != "$POST_LIVE_SHA256" ]; then
        error "embedded postimage hash is not self-consistent"
      elif [ "$FAIL_STAGE" = postimage-validate ]; then
        error "fault injection refused at postimage-validate stage"
      elif [ "$FAIL_STAGE" = pre-publication ]; then
        error "fault injection refused at pre-publication stage"
      elif ! sync; then
        error "could not flush the prepared activation postimage before rename"
      elif ! activation_test_pause before-rename; then
        error "test pause before rename could not be established"
      elif [ -n "$EXPECTED_LIVE_SHA256" ] && [ "$(sha256 "$LIVE_BACKLOG")" != "$EXPECTED_LIVE_SHA256" ]; then
        error "live backlog changed during activation; refusing atomic rename"
      elif ! mv -f -- "$NEW_BACKLOG" "$LIVE_BACKLOG"; then
        error "could not publish the authoritative backlog postimage"
      else
        NEW_BACKLOG=
        if ! sync; then
          error "could not flush the authoritative activation postimage after rename"
        elif ! activation_test_pause after-rename; then
          error "test pause after rename could not be established"
        elif [ "$FAIL_STAGE" = post-publication ]; then
          error "fault injection refused immediately after the backlog rename"
        fi
      fi
    fi

    [ -z "$NEW_BACKLOG" ] || [ ! -e "$NEW_BACKLOG" ] || rm -f -- "$NEW_BACKLOG" || error "activation cleanup could not remove backlog temporary file"
  fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    ISSUES=$(printf '%s\n' "${ERRORS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'BLOCK' --arg action "$ACTION" --argjson issues "$ISSUES" '{schema:$schema,status:$status,action:$action,issues:$issues}'
  elif [ "$ALREADY_ACTIVATED" -eq 1 ]; then
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'PASS' --arg action "$ACTION" --argjson task_ids "$TASK_IDS_JSON" '{schema:$schema,status:$status,action:$action,already_activated:true,authoritative:true,published_task_ids:$task_ids}'
  elif [ "$ACTION" = activate ]; then
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'PASS' --arg action "$ACTION" --argjson task_ids "$(printf '%s\n' "${ACTIVATION_IDS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')" '{schema:$schema,status:$status,action:$action,published_task_ids:$task_ids}'
  else
    jq -n --arg schema 'omp-activation-check.v1' --arg status 'PASS' --arg action "$ACTION" '{schema:$schema,status:$status,action:$action,published_task_ids:[]}'
  fi
else
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    printf 'BLOCK\n'
    printf '%s\n' "${ERRORS[@]}" >&2
  elif [ "$ALREADY_ACTIVATED" -eq 1 ]; then
    printf 'PASS: authoritative activation postimage already published\n'
  elif [ "$ACTION" = activate ]; then
    printf 'PASS: activation publication committed atomically\n'
  else
    printf 'PASS: activation gate passed without publication\n'
  fi
fi

[ "${#ERRORS[@]}" -eq 0 ]
