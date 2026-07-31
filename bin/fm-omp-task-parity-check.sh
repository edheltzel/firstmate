#!/usr/bin/env bash
# Validate the canonical OMP task contract and its plan/roadmap/backlog projections.
# This task semantic parity check is the cleanup/evidence owner for contract drift.
# Usage: bin/fm-omp-task-parity-check.sh [--json] [--manifest PATH] [--plan PATH] [--roadmap PATH] [--backlog PATH]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
PLAN="$ROOT/.agents/plans/omp-harness-integration-plan.md"
ROADMAP="$ROOT/.agents/tasks/roadmap.md"
BACKLOG="$ROOT/.agents/tasks/backlog.md"
JSON_OUTPUT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON_OUTPUT=1 ;;
    --manifest) shift; MANIFEST=${1-} ;;
    --plan) shift; PLAN=${1-} ;;
    --roadmap) shift; ROADMAP=${1-} ;;
    --backlog) shift; BACKLOG=${1-} ;;
    --help|-h) sed -n '2,3p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

ERRORS=()
error() { ERRORS+=("$1"); }

SHA256_TOOL=${SHA256_TOOL:-$(command -v shasum 2>/dev/null || command -v sha256sum 2>/dev/null || true)}
sha256_stdin() {
  case "$SHA256_TOOL" in
    */shasum|shasum) "$SHA256_TOOL" -a 256 | awk '{print $1}' ;;
    */sha256sum|sha256sum) "$SHA256_TOOL" | awk '{print $1}' ;;
    *) return 1 ;;
  esac
}

for file in "$MANIFEST" "$PLAN" "$ROADMAP" "$BACKLOG"; do
  [ -f "$file" ] || error "missing task contract input: $file"
done

if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  if ! jq -e '.schema == "omp-task-manifest.v1" and .version == 1 and (.tasks | type == "array") and (.task_contract_sha256 | type == "string")' "$MANIFEST" >/dev/null 2>&1; then
    error "manifest task contract schema or digest field is invalid"
  else
    EXPECTED_HASH=$(jq -cS '.tasks' "$MANIFEST" | sha256_stdin || true)
    DECLARED_HASH=$(jq -r '.task_contract_sha256' "$MANIFEST")
    [ "$EXPECTED_HASH" = "$DECLARED_HASH" ] || error "manifest task contract digest does not match its canonical task rows"
    TASK_COUNT=$(jq '.tasks | length' "$MANIFEST")
    [ "$TASK_COUNT" -gt 0 ] || error "manifest task contract is empty"
    if ! jq -e '
      . as $root
      | ([.tasks[].id] | length) == ([.tasks[].id] | unique | length)
      and ([.tasks[].depends_on[]] | all(. as $dep | ([$root.tasks[].id] | index($dep)) != null))
      and ([.tasks[] | select((.phase|type) != "string" or (.milestone|type) != "string" or (.title|type) != "string" or (.owner|type) != "string" or (.state|type) != "string" or (.validation_ids|type) != "array" or (.validation_owners|type) != "object" or (.evidence_ids|type) != "array" or (.evidence_owners|type) != "object" or (.rollback_id|type) != "string" or (.rollback_owner|type) != "string" or (.artifact_paths|type) != "object" or (.artifact_schemas|type) != "object" or (.artifact_owners|type) != "object")] | length) == 0
      and (.tasks | all(. as $task |
        (($task.validation_owners | keys | sort) == ($task.validation_ids | sort))
        and (($task.validation_owners | to_entries | all(.value == $task.owner)))
        and (($task.evidence_owners | keys | sort) == ($task.evidence_ids | sort))
        and (($task.evidence_owners | to_entries | all(.value == $task.owner)))
        and ($task.artifact_owners.evidence == $task.owner)
        and ($task.artifact_owners.rollback == $task.owner)
        and (($task.artifact_paths | keys | sort) == (["evidence", "rollback"] | sort))
        and (($task.artifact_schemas | keys | sort) == (["evidence", "rollback"] | sort))
      ))
    ' "$MANIFEST" >/dev/null 2>&1; then
      error "manifest task rows are not uniquely identified, closed, or Tasks Axi-operational"
    fi
  fi
fi

if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  O10_REPORT_TASK=$(jq -r '.activation_report_task_id // empty' "$MANIFEST")
  O10_REPORT_PATH=$(jq -r '.activation_report_path // empty' "$MANIFEST")
  SUPPORT_FENCE=$(jq -r '.support_fence // empty' "$MANIFEST")
  [ "$O10_REPORT_TASK" = "omp-final-authority-redteam-o10" ] || error "only O10 may be the activation report identity"
  [ "$O10_REPORT_PATH" = "data/omp-final-authority-redteam-o10/report.md" ] || error "activation report path is not the O10 path"
  [ -f "$ROOT/.agents/tasks/omp-runtime-pin.json" ] || error "versioned runtime pin is missing"
  [ -n "$SUPPORT_FENCE" ] || error "support fence is empty"
  jq -e '
    (.tasks | map(select(.id == "omp-corrected-plan-redteam-o8"))[0].state == "complete")
    and (.tasks | map(select(.id == "omp-corrected-plan-redteam-o8"))[0].disposition == "BLOCK")
    and (.tasks | map(select(.id == "omp-final-corrected-plan-redteam-o9"))[0].state == "complete")
    and (.tasks | map(select(.id == "omp-final-corrected-plan-redteam-o9"))[0].disposition == "BLOCK")
    and (.tasks | map(select(.id == "omp-final-authority-redteam-o10"))[0].state == "queued")
    and (.tasks | map(select(.id == "omp-final-authority-redteam-o10"))[0].depends_on == ["omp-final-corrected-plan-redteam-o9"])
    and (.tasks | map(select(.id == "omp-p1-activation-a7"))[0].state == "blocked")
    and (.tasks | map(select(.id == "omp-p1-activation-a7"))[0].depends_on == ["omp-final-authority-redteam-o10"])
  ' "$MANIFEST" >/dev/null 2>&1 || error "O8/O9 historical BLOCK, O10 authority, and A7 hold state are inconsistent"
fi

if [ -f "$MANIFEST" ] && [ -f "$PLAN" ] && [ -f "$ROADMAP" ] && [ -f "$BACKLOG" ]; then
  DECLARED_HASH=$(jq -r '.task_contract_sha256 // empty' "$MANIFEST" 2>/dev/null || true)
  for file in "$PLAN" "$ROADMAP" "$BACKLOG"; do
    if ! grep -Fqx "<!-- omp-task-contract-sha256: $DECLARED_HASH -->" "$file"; then
      error "task contract digest marker is missing or stale in $file"
    fi
    if ! grep -Fq '<!-- omp-task-contract-v1 -->' "$file" || ! grep -Fq '<!-- omp-task-contract-end -->' "$file"; then
      error "canonical task projection block is missing in $file"
    fi
    if ! grep -Fq 'omp-final-authority-redteam-o10' "$file" || ! grep -Fq 'data/omp-final-authority-redteam-o10/report.md' "$file"; then
      error "O10 authority identity/path is missing from $file"
    fi
    grep -Fq 'omp-final-corrected-plan-redteam-o9' "$file" || error "O9 historical identity is missing from $file"
    grep -Fq 'data/omp-final-corrected-plan-redteam-o9/report.md' "$file" || error "O9 historical report path is missing from $file"
    grep -Fq "$SUPPORT_FENCE" "$file" || error "support fence is missing from $file"
  done

  EXPECTED_ROWS=$(jq -S -c '.tasks' "$MANIFEST")
  for file in "$PLAN" "$ROADMAP" "$BACKLOG"; do
    ACTUAL_ROWS=$(awk '/^<!-- omp-task-row: / { sub(/^<!-- omp-task-row: /, ""); sub(/ -->$/, ""); print }' "$file" | jq -S -sc '.' 2>/dev/null || true)
    [ "$ACTUAL_ROWS" = "$EXPECTED_ROWS" ] || error "canonical task rows in $file do not exactly match the manifest"
  done
fi

if [ -f "$BACKLOG" ]; then
  grep -Fq 'omp-final-plan-redteam-o6 -' "$BACKLOG" || error "O6 tracked backlog row is missing"
  grep -Fq 'blocked-by: omp-o5-plan-traceability' "$BACKLOG" || error "O6 dependency does not use omp-o5-plan-traceability"
  if grep -Fq 'blocked-by: omp-firstmate-support-o5' "$BACKLOG"; then error "stale O6 dependency alias remains"; fi
  grep -Eq '^- \[[xX]\] omp-final-corrected-plan-redteam-o9([[:space:]-]|$)' "$BACKLOG" || error "O9 is not a completed historical backlog row"
  grep -Eq '^- \[ \] omp-final-authority-redteam-o10([[:space:]-]|$)' "$BACKLOG" || error "O10 is not the queued backlog gate"
  grep -Fq 'blocked-by: omp-final-corrected-plan-redteam-o9' "$BACKLOG" || error "O10 backlog dependency is missing"
  grep -Eq '^- \[ \] omp-p1-activation-a7([[:space:]-]|$)' "$BACKLOG" || error "A7 queued backlog gate is missing"
  grep -Fq 'blocked-by: omp-final-authority-redteam-o10' "$BACKLOG" || error "A7 does not wait for O10"
  PREMATURE_ROWS=$(grep -E '^- \[[ xX]\] omp-p[1-8]-' "$BACKLOG" | grep -Ev '^- \[[ xX]\] omp-p1-activation-a7([[:space:]-]|$)' || true)
  [ -z "$PREMATURE_ROWS" ] || error "tracked backlog contains premature P1-P8 implementation rows"
fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    ISSUES=$(printf '%s\n' "${ERRORS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    jq -n --arg schema 'omp-task-parity-check.v1' --arg status BLOCK --argjson issues "$ISSUES" '{schema:$schema,status:$status,issues:$issues}'
  else
    jq -n --arg schema 'omp-task-parity-check.v1' --arg status PASS '{schema:$schema,status:$status,issues:[]}'
  fi
else
  if [ "${#ERRORS[@]}" -gt 0 ]; then printf 'BLOCK\n%s\n' "${ERRORS[@]}" >&2; else printf 'PASS: OMP task projections are exact\n'; fi
fi

[ "${#ERRORS[@]}" -eq 0 ]
