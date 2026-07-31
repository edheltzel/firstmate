#!/usr/bin/env bash
# Validate the machine publication inventory, current source ownership, and V29 interruption state without writing files.
# Usage: bin/fm-omp-publication-check.sh [--json] [--manifest PATH] [--inventory PATH] [--plan PATH] [--simulate STATE_JSON]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
TASK_MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
MANIFEST="$ROOT/.agents/tasks/omp-publication-manifest.json"
INVENTORY="$ROOT/docs/omp-publication-inventory.md"
PLAN="$ROOT/.agents/plans/omp-harness-integration-plan.md"
JSON_OUTPUT=0
SIMULATION=

usage() {
  sed -n '2,3p' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON_OUTPUT=1 ;;
    --manifest) shift; MANIFEST=${1-} ;;
    --inventory) shift; INVENTORY=${1-} ;;
    --plan) shift; PLAN=${1-} ;;
    --simulate) shift; SIMULATION=${1-} ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

ERRORS=()
INVENTORY_COUNT=0
INVENTORY_TICK=$(printf '\140')

TMP_DIR=
if ! TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fm-omp-publication-check.XXXXXX" 2>/dev/null); then
  if [ "$JSON_OUTPUT" -eq 1 ]; then
    jq -n '{schema:"omp-publication-check.v1",status:"BLOCK",inventory_count:0,issues:["could not allocate publication-check temporary workspace"]}'
  else
    printf 'BLOCK\ncould not allocate publication-check temporary workspace\n' >&2
  fi
  exit 1
fi
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

error() {
  ERRORS+=("$1")
}

require_file() {
  if [ ! -f "$1" ]; then
    error "missing required file: $1"
  fi
}

require_inventory_token() {
  if ! grep -Fq "$INVENTORY_TICK$1$INVENTORY_TICK" "$INVENTORY"; then
    error "publication inventory omits exact token: $1"
  fi
}

require_source_binding() {
  local owner_kind=$1 artifact_id=$2 source_path=$3 token
  if [ ! -f "$ROOT/$source_path" ]; then
    error "$owner_kind source path is missing: $source_path"
    return
  fi
  while IFS= read -r token; do
    [ -n "$token" ] || continue
    if [[ "$token" =~ ^[A-Za-z_][A-Za-z0-9_]*$ ]]; then
      if ! grep -Eq "(^|[^[:alnum:]_])$token([^[:alnum:]_]|$)" "$ROOT/$source_path"; then
        error "$owner_kind source token is missing from $source_path: $token"
      fi
    elif ! grep -Fq "$token" "$ROOT/$source_path"; then
      error "$owner_kind source token is missing from $source_path: $token"
    fi
  done < <(jq -r --arg kind "$owner_kind" --arg id "$artifact_id" --arg path "$source_path" '.artifacts[] | select(.id == $id) | .[$kind][] | select(.path == $path) | .tokens[]' "$MANIFEST")
}

require_file "$MANIFEST"
require_file "$INVENTORY"
require_file "$PLAN"

if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  if ! jq -e '.schema == "omp-publication-inventory.v1" and .version == 1 and .source_document == "docs/omp-publication-inventory.md" and (.tracked_paths | type == "array") and (.future_paths | type == "array") and (.artifacts | type == "array")' "$MANIFEST" >/dev/null 2>&1; then
    error "publication manifest schema is invalid"
  else
    INVENTORY_COUNT=$(jq '.artifacts | length' "$MANIFEST")
    while IFS= read -r duplicate_id; do
      [ -n "$duplicate_id" ] || continue
      error "publication manifest has duplicate artifact ID: $duplicate_id"
    done < <(jq -r '.artifacts[].id' "$MANIFEST" | sort | uniq -d)
    while IFS= read -r duplicate_path; do
      [ -n "$duplicate_path" ] || continue
      error "publication manifest has duplicate tracked path: $duplicate_path"
    done < <(jq -r '.tracked_paths[]' "$MANIFEST" | sort | uniq -d)
    while IFS= read -r duplicate_path; do
      [ -n "$duplicate_path" ] || continue
      error "publication manifest has duplicate artifact path: $duplicate_path"
    done < <(jq -r '.artifacts[].paths[]' "$MANIFEST" | sort | uniq -d)
    if [ "$(jq '[.tracked_paths[]] | length' "$MANIFEST")" -ne "$(jq '[.tracked_paths[]] | unique | length' "$MANIFEST")" ]; then
      error "publication manifest tracked path set is not unique"
    fi
    while IFS=$'\t' read -r owner_kind artifact_id source_path; do
      [ -n "$owner_kind" ] || continue
      error "publication manifest has duplicate $owner_kind binding: $artifact_id:$source_path"
    done < <(jq -r '.artifacts[] as $artifact | (["creator","cleanup"][] as $kind | $artifact[$kind][] | [$kind, $artifact.id, .path] | @tsv)' "$MANIFEST" | sort | uniq -d)
    while IFS= read -r tracked_path; do
      [ -n "$tracked_path" ] || continue
      if ! git -C "$ROOT" ls-files --error-unmatch -- "$tracked_path" >/dev/null 2>&1; then
        error "publication manifest tracked path is not tracked: $tracked_path"
      fi
      if [ ! -e "$ROOT/$tracked_path" ]; then
        error "publication manifest tracked path is missing from the worktree: $tracked_path"
      fi
    done < <(jq -r '.tracked_paths[]' "$MANIFEST")

    while IFS= read -r artifact_id; do
      [ -n "$artifact_id" ] || continue
      DOCUMENT_ID_COUNT=$(grep -oE "^\\| ${INVENTORY_TICK}[a-z0-9-]+${INVENTORY_TICK} \\|" "$INVENTORY" | sed -E "s/^\\| ${INVENTORY_TICK}//; s/${INVENTORY_TICK} \\|$//" | grep -Fxc "$artifact_id" || true)
      if [ "$DOCUMENT_ID_COUNT" -ne 1 ]; then
        error "publication artifact documentation row count is $DOCUMENT_ID_COUNT: $artifact_id"
      fi
      require_inventory_token "$artifact_id"
      if ! jq -e --arg id "$artifact_id" --slurpfile task_manifest "$TASK_MANIFEST" '.artifacts[] | select(.id == $id) | .task_id as $task_id | (.paths | length > 0) and (.creator | length > 0) and (.cleanup | length > 0) and ((.rollback_owner | length) > 0) and ((.owner | length) > 0) and ((.task_id | type) == "string") and ((.evidence_id | type) == "string") and ((.rollback_id | type) == "string") and (.evidence_schema == "omp-evidence.v1" or .evidence_schema == "omp-activation-preflight.v1") and ((.rollback_schema | length) > 0) and (([$task_manifest[0].tasks[].id] | index($task_id)) != null) and (.rollback_owner == $task_id)' "$MANIFEST" >/dev/null 2>&1; then
        error "publication artifact lacks paths, creator, cleanup, rollback owner, or schemas: $artifact_id"
      fi
      while IFS= read -r artifact_path; do
        [ -n "$artifact_path" ] || continue
        require_inventory_token "$artifact_path"
      done < <(jq -r --arg id "$artifact_id" '.artifacts[] | select(.id == $id) | .paths[]' "$MANIFEST")
      while IFS= read -r source_path; do
        [ -n "$source_path" ] || continue
        if ! jq -e --arg id "$artifact_id" '.artifacts[] | select(.id == $id and (.future // false))' "$MANIFEST" >/dev/null 2>&1; then
          require_source_binding creator "$artifact_id" "$source_path"
        fi
      done < <(jq -r --arg id "$artifact_id" '.artifacts[] | select(.id == $id) | .creator[].path' "$MANIFEST")
      while IFS= read -r source_path; do
        [ -n "$source_path" ] || continue
        if ! jq -e --arg id "$artifact_id" '.artifacts[] | select(.id == $id and (.future // false))' "$MANIFEST" >/dev/null 2>&1; then
          require_source_binding cleanup "$artifact_id" "$source_path"
        fi
      done < <(jq -r --arg id "$artifact_id" '.artifacts[] | select(.id == $id) | .cleanup[].path' "$MANIFEST")
    done < <(jq -r '.artifacts[].id' "$MANIFEST" | sort -u)

    while IFS= read -r future_path; do
      [ -n "$future_path" ] || continue
      require_inventory_token "$future_path"
    done < <(jq -r '.future_paths[].path' "$MANIFEST")

    # shellcheck disable=SC2016
    DOCUMENT_TRACKED=$(grep -oE '^<!-- omp-publication-tracked-path: \`[^\`]+\` -->$' "$INVENTORY" | sed -E 's/^<!-- omp-publication-tracked-path: \`([^\`]+)\` -->$/\1/' | sort -u || true)
    MANIFEST_TRACKED=$(jq -r '.tracked_paths[]' "$MANIFEST" | sort -u)
    # shellcheck disable=SC2016
    DOCUMENT_TRACKED_RAW=$(grep -oE '^<!-- omp-publication-tracked-path: \`[^\`]+\` -->$' "$INVENTORY" | sed -E 's/^<!-- omp-publication-tracked-path: \`([^\`]+)\` -->$/\1/' || true)
    DOCUMENT_TRACKED_ROW_COUNT=$(printf '%s\n' "$DOCUMENT_TRACKED_RAW" | sed '/^$/d' | wc -l | tr -d ' ')
    DOCUMENT_TRACKED_UNIQUE_COUNT=$(printf '%s\n' "$DOCUMENT_TRACKED_RAW" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
    [ "$DOCUMENT_TRACKED_ROW_COUNT" = "$DOCUMENT_TRACKED_UNIQUE_COUNT" ] || error "publication inventory tracked-path rows are duplicated"
    if [ "$DOCUMENT_TRACKED" != "$MANIFEST_TRACKED" ]; then
      error "publication inventory tracked-path set differs from manifest"
    fi

    # Future OMP-native surfaces are not files yet, so their exact path/owner/schema
    # binding must be compared as structured comment rows rather than by existence.
    # shellcheck disable=SC2016
    DOCUMENT_FUTURE_RAW=$(grep -oE '^<!-- omp-publication-future-path: \`[^\`]+\` owner=[^ ]+ schema=[^ ]+ -->$' "$INVENTORY" | sed -E 's/^<!-- omp-publication-future-path: \`([^\`]+)\` owner=([^ ]+) schema=([^ ]+) -->$/\1\towner=\2\tschema=\3/' || true)
    DOCUMENT_FUTURE=$(printf '%s\n' "$DOCUMENT_FUTURE_RAW" | sed '/^$/d' | sort -u)
    MANIFEST_FUTURE=$(jq -r '.future_paths[] | "\(.path)\towner=\(.owner)\tschema=\(.schema)"' "$MANIFEST" | sort -u)
    DOCUMENT_FUTURE_ROW_COUNT=$(printf '%s\n' "$DOCUMENT_FUTURE_RAW" | sed '/^$/d' | wc -l | tr -d ' ')
    DOCUMENT_FUTURE_UNIQUE_COUNT=$(printf '%s\n' "$DOCUMENT_FUTURE_RAW" | sed '/^$/d' | sort -u | wc -l | tr -d ' ')
    [ "$DOCUMENT_FUTURE_ROW_COUNT" = "$DOCUMENT_FUTURE_UNIQUE_COUNT" ] || error "publication inventory future-path rows are duplicated"
    if [ "$DOCUMENT_FUTURE" != "$MANIFEST_FUTURE" ]; then
      error "publication inventory future-path set differs from manifest"
    fi

    while IFS= read -r document_id; do
      [ -n "$document_id" ] || continue
      if ! jq -e --arg id "$document_id" '.artifacts | map(.id) | index($id) != null' "$MANIFEST" >/dev/null 2>&1; then
        error "publication document has an unregistered inventory ID: $document_id"
      fi
    done < <(grep -oE "^\\| ${INVENTORY_TICK}[a-z0-9-]+${INVENTORY_TICK} \\|" "$INVENTORY" | sed -E "s/^\\| ${INVENTORY_TICK}//; s/${INVENTORY_TICK} \\|$//" | sort -u)
  fi
else
  error "publication manifest is missing or invalid JSON: $MANIFEST"
fi

if [ -f "$PLAN" ]; then
  for token in 'docs/omp-publication-inventory.md' '.agents/tasks/omp-publication-manifest.json' 'bin/fm-omp-publication-check.sh' 'V29' 'atomic' 'rollback'; do
    if ! grep -Fq "$token" "$PLAN"; then
      error "OMP plan does not reference publication invariant token: $token"
    fi
  done
fi

if [ -n "$SIMULATION" ]; then
  if [ ! -f "$SIMULATION" ] || ! jq empty "$SIMULATION" >/dev/null 2>&1; then
    error "simulation state is missing or invalid JSON: $SIMULATION"
  else
    if ! jq -e '.schema == "omp-publication-state.v2" and (.inventory_ids | type == "array") and (.changed_paths | type == "array") and (.pre_paths | type == "array") and (.post_paths | type == "array")' "$SIMULATION" >/dev/null 2>&1; then
      error "simulation state has the wrong schema"
    fi
    STATE=$(jq -r '.state // empty' "$SIMULATION")
    case "$STATE" in
      pre|post) ;;
      mixed) error "publication interruption left a mixed old/new state" ;;
      *) error "simulation state is not pre, post, or mixed: $STATE" ;;
    esac
    while IFS= read -r path; do
      [ -n "$path" ] || continue
      if ! jq -e --arg path "$path" '([.tracked_paths[]] + [.artifacts[].paths[]] | index($path)) != null' "$MANIFEST" >/dev/null 2>&1; then
        error "simulation changed path is outside the publication inventory: $path"
      fi
    done < <(jq -r '.changed_paths[]?' "$SIMULATION")
    if [ "$(jq '[.changed_paths[]] | length' "$SIMULATION")" -ne "$(jq '[.changed_paths[]] | unique | length' "$SIMULATION")" ]; then
      error "simulation changed path list contains duplicates"
    fi
    if [ "$(jq '[.post_paths[]] | length' "$SIMULATION")" -eq 0 ]; then
      error "simulation post image is empty"
    fi
    if jq -e '(.state == "pre" and (.changed_paths | length > 0)) or (.state == "post" and (.changed_paths | length == 0))' "$SIMULATION" >/dev/null 2>&1; then
      error "simulation pre/post changed-path binding is inconsistent"
    fi
    if ! jq -e --slurpfile publication "$MANIFEST" '(.inventory_ids | unique | sort) == ([$publication[0].artifacts[].id] | unique | sort)' "$SIMULATION" >/dev/null 2>&1; then
      error "simulation inventory ID set is incomplete or stale"
    fi
    if ! jq -e '.support_fence == "experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support"' "$SIMULATION" >/dev/null 2>&1; then
      error "simulation does not preserve the experimental support fence"
    fi
  fi
fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    ISSUES=$(printf '%s\n' "${ERRORS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    jq -n --arg schema 'omp-publication-check.v1' --arg status 'BLOCK' --argjson inventory_count "$INVENTORY_COUNT" --argjson issues "$ISSUES" '{schema:$schema,status:$status,inventory_count:$inventory_count,issues:$issues}'
  else
    jq -n --arg schema 'omp-publication-check.v1' --arg status 'PASS' --argjson inventory_count "$INVENTORY_COUNT" '{schema:$schema,status:$status,inventory_count:$inventory_count,issues:[]}'
  fi
else
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    printf 'BLOCK\n'
    printf '%s\n' "${ERRORS[@]}" >&2
  else
    printf 'PASS: publication manifest, source ownership, and interruption invariant validated\n'
  fi
fi

[ "${#ERRORS[@]}" -eq 0 ]
