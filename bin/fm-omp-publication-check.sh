#!/usr/bin/env bash
# Validate the machine publication inventory, current source ownership, and V29 interruption state without writing files.
# Usage: bin/fm-omp-publication-check.sh [--json] [--manifest PATH] [--inventory PATH] [--plan PATH] [--simulate STATE_JSON]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
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

error() {
  ERRORS+=("$1")
}

require_file() {
  if [ ! -f "$1" ]; then
    error "missing required file: $1"
  fi
}

require_inventory_token() {
  if ! grep -Fq "$1" "$INVENTORY"; then
    error "publication inventory omits: $1"
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
    if ! grep -Fq "$token" "$ROOT/$source_path"; then
      error "$owner_kind source token is missing from $source_path: $token"
    fi
  done < <(jq -r --arg kind "$owner_kind" --arg id "$artifact_id" --arg path "$source_path" '.artifacts[] | select(.id == $id) | .[$kind][] | select(.path == $path) | .tokens[]' "$MANIFEST")
}

require_file "$MANIFEST"
require_file "$INVENTORY"
require_file "$PLAN"

if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  if ! jq -e '.schema == "omp-publication-inventory.v1" and .version == 1 and .source_document == "docs/omp-publication-inventory.md" and (.tracked_paths | type == "array") and (.artifacts | type == "array")' "$MANIFEST" >/dev/null 2>&1; then
    error "publication manifest schema is invalid"
  else
    INVENTORY_COUNT=$(jq '.artifacts | length' "$MANIFEST")
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
      require_inventory_token "\`$artifact_id\`"
      if ! jq -e --arg id "$artifact_id" '.artifacts[] | select(.id == $id) | (.paths | length > 0) and (.creator | length > 0) and (.cleanup | length > 0) and ((.rollback_owner | length) > 0) and (.evidence_schema == "omp-evidence.v1" or .evidence_schema == "omp-activation-preflight.v1") and ((.rollback_schema | length) > 0)' "$MANIFEST" >/dev/null 2>&1; then
        error "publication artifact lacks paths, creator, cleanup, rollback owner, or schemas: $artifact_id"
      fi
      while IFS= read -r artifact_path; do
        [ -n "$artifact_path" ] || continue
        require_inventory_token "$artifact_path"
      done < <(jq -r --arg id "$artifact_id" '.artifacts[] | select(.id == $id) | .paths[]' "$MANIFEST")
      while IFS= read -r source_path; do
        [ -n "$source_path" ] || continue
        require_source_binding creator "$artifact_id" "$source_path"
      done < <(jq -r --arg id "$artifact_id" '.artifacts[] | select(.id == $id) | .creator[].path' "$MANIFEST")
      while IFS= read -r source_path; do
        [ -n "$source_path" ] || continue
        require_source_binding cleanup "$artifact_id" "$source_path"
      done < <(jq -r --arg id "$artifact_id" '.artifacts[] | select(.id == $id) | .cleanup[].path' "$MANIFEST")
    done < <(jq -r '.artifacts[].id' "$MANIFEST" | sort -u)

    INVENTORY_TICK=$(printf '\140')
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
    if ! jq -e '.schema == "omp-publication-state.v1"' "$SIMULATION" >/dev/null 2>&1; then
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
      if ! grep -Fq "$path" "$INVENTORY"; then
        error "simulation changed path is outside the publication inventory: $path"
      fi
    done < <(jq -r '.changed_paths[]?' "$SIMULATION")
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
