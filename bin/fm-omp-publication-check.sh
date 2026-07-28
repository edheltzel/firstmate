#!/usr/bin/env bash
# Validate the OMP publication inventory and refuse mixed interrupted publication states without writing files.
# Usage: bin/fm-omp-publication-check.sh [--json] [--inventory PATH] [--plan PATH] [--simulate STATE_JSON]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
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

require_inventory_token() {
  if ! grep -Fq "$1" "$INVENTORY"; then
    error "publication inventory omits: $1"
  fi
}

if [ ! -f "$INVENTORY" ]; then
  error "missing publication inventory: $INVENTORY"
else
  INVENTORY_COUNT=$(grep -c '^|[^-].*|' "$INVENTORY" || true)
  for token in \
    'bin/fm-session-lock-lib.sh' \
    'tests/fm-session-lock.test.sh' \
    'bin/fm-backend.sh' \
    'bin/backends/tmux.sh' \
    'bin/backends/herdr.sh' \
    'bin/fm-crew-state.sh' \
    'state/{task}.pi-ext' \
    'state/{task}.grok-token' \
    'state/{task}.grok-token.pointer' \
    'projects/{project}/.claude/settings.local.json' \
    'projects/{project}/.opencode/plugins/' \
    'state/{task}.check.sh' \
    'state/{task}.check-trust' \
    'state/{task}.pr-poll' \
    'state/{task}.pr-poll-registration' \
    'state/{task}.pr-publication' \
    'state/{task}.pr-binding' \
    'state/.pr-check-quarantine/' \
    'state/{task}.herdr-presentation' \
    'state/{task}.backend-transition' \
    'state/{task}.task-temp' \
    'data/omp-evidence/{task_id}.json' \
    'data/omp-rollback/{task_id}.json' \
    'data/omp-activation-preflight.json' \
    'data/omp-activation-receipt.json'; do
    require_inventory_token "$token"
  done
  for owner in 'Creation owner' 'Cleanup owner' 'Rollback owner' 'omp-evidence.v1' 'omp-rollback.v1'; do
    require_inventory_token "$owner"
  done
fi

if [ ! -f "$PLAN" ]; then
  error "missing OMP plan: $PLAN"
else
  for token in 'docs/omp-publication-inventory.md' 'bin/fm-omp-publication-check.sh' 'V29' 'atomic' 'rollback'; do
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
    printf 'PASS: publication inventory and interruption invariant validated\n'
  fi
fi

[ "${#ERRORS[@]}" -eq 0 ]
