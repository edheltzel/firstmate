#!/usr/bin/env bash
# Validate the OMP machine manifest, prose-roadmap parity, and tracked backlog without changing files.
# Usage: bin/fm-omp-plan-check.sh [--json] [--manifest PATH] [--plan PATH] [--roadmap PATH] [--backlog PATH]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
PLAN="$ROOT/.agents/plans/omp-harness-integration-plan.md"
ROADMAP="$ROOT/.agents/tasks/roadmap.md"
BACKLOG="$ROOT/.agents/tasks/backlog.md"
TASKS_AXI=${TASKS_AXI:-/opt/homebrew/bin/tasks-axi}
JSON_OUTPUT=0

usage() {
  sed -n '2,3p' "$0"
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON_OUTPUT=1 ;;
    --manifest) shift; MANIFEST=${1-} ;;
    --plan) shift; PLAN=${1-} ;;
    --roadmap) shift; ROADMAP=${1-} ;;
    --backlog) shift; BACKLOG=${1-} ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fm-omp-plan-check.XXXXXX")
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM
ERRORS=()
MANIFEST_VALID=0
TASK_COUNT=0
VALIDATION_COUNT=0
EVIDENCE_COUNT=0
ROLLBACK_COUNT=0

error() {
  ERRORS+=("$1")
}

require_file() {
  if [ ! -f "$1" ]; then
    error "missing file: $1"
  fi
}

require_file "$MANIFEST"
require_file "$PLAN"
require_file "$ROADMAP"
require_file "$BACKLOG"

if [ -f "$MANIFEST" ] && jq empty "$MANIFEST" >/dev/null 2>&1; then
  MANIFEST_VALID=1
else
  error "manifest is not valid JSON: $MANIFEST"
fi

if [ "$MANIFEST_VALID" -eq 1 ]; then
  if ! jq -e '.schema == "omp-task-manifest.v1" and .version == 1 and .dependency_mode == "exact-task-ids"' "$MANIFEST" >/dev/null 2>&1; then
    error "manifest schema, version, or dependency mode is invalid"
  fi

  TASK_COUNT=$(jq '.tasks | length' "$MANIFEST")
  VALIDATION_COUNT=$(jq '[.tasks[].validation_ids[]] | unique | length' "$MANIFEST")
  EVIDENCE_COUNT=$(jq '[.tasks[].evidence_ids[]] | unique | length' "$MANIFEST")
  ROLLBACK_COUNT=$(jq '[.tasks[].rollback_id] | unique | length' "$MANIFEST")
  jq -r '.tasks[] | . as $task | if (($task.depends_on // []) | length) == 0 then [$task.id] | @tsv else $task.depends_on[] | [$task.id, .] | @tsv end' "$MANIFEST" >"$TMP_DIR/tasks.tsv"

  while IFS= read -r duplicate_id; do
    [ -n "$duplicate_id" ] && error "duplicate task id: $duplicate_id"
  done < <(jq -r '.tasks[].id' "$MANIFEST" | sort | uniq -d)

  while IFS= read -r issue; do
    [ -n "$issue" ] && error "$issue"
  done < <(awk -F '\t' '
    {
      id=$1
      if (!seen[id]++) total++
      ids[id]=1
      for (i=2; i<=NF; i++) if ($i != "") {
        if (!ids[$i]) missing[$i]=1
        adjacency[$i]=adjacency[$i] " " id
        indegree[id]++
      }
    }
    END {
      for (dep in missing) print "unknown dependency: " dep
      changed=1
      while (changed) {
        changed=0
        for (id in ids) if (!removed[id] && indegree[id] == 0) {
          removed[id]=1
          removed_count++
          changed=1
          next_count=split(adjacency[id], nexts, " ")
          for (i=1; i<=next_count; i++) if (nexts[i] != "") indegree[nexts[i]]--
        }
      }
      if (removed_count != total) print "dependency cycle detected"
    }
  ' "$TMP_DIR/tasks.tsv")

  if ! jq -e '(.tasks | all(.id | test("^omp-[a-z0-9-]+$"))) and (.stop_ids | all(test("^STOP-[0-9]{2}$")))' "$MANIFEST" >/dev/null 2>&1; then
    error "manifest contains an invalid task or STOP identifier"
  fi
  if [ "$(jq '[.tasks[].evidence_ids[]] | length' "$MANIFEST")" -ne "$EVIDENCE_COUNT" ]; then
    error "evidence identifiers are duplicated"
  fi
  if [ "$(jq '[.tasks[].rollback_id] | length' "$MANIFEST")" -ne "$ROLLBACK_COUNT" ]; then
    error "rollback identifiers are duplicated"
  fi
  if ! jq -e '(.tasks | all((.validation_ids // [])[] | test("^V[0-9]+$"))) and (.tasks | all((.evidence_ids // [])[] | test("^omp-evidence-"))) and (.tasks | all((.rollback_id // "") | test("^omp-rollback-")))' "$MANIFEST" >/dev/null 2>&1; then
    error "manifest contains an invalid validation, evidence, or rollback identifier"
  fi
  if ! jq -e '.tasks | all(has("owner") and has("artifact_paths") and has("artifact_schemas") and (.artifact_paths.evidence | contains("{task_id}")) and (.artifact_paths.rollback | contains("{task_id}")) and (.artifact_schemas.evidence == "omp-evidence.v1") and (.artifact_schemas.rollback == "omp-rollback.v1"))' "$MANIFEST" >/dev/null 2>&1; then
    error "one or more task rows lack stable owner, path, or schema fields"
  fi
  if ! jq -e '.activation_task_id as $a | (.tasks | map(.id) | index($a)) != null and (.activation_task_ids | all(. as $id | $ARGS.named.task_ids | index($id) != null))' --argjson task_ids "$(jq '[.tasks[].id]' "$MANIFEST")" "$MANIFEST" >/dev/null 2>&1; then
    error "activation task identifiers are not closed over the manifest"
  fi
  if ! jq -e '.current_task_ids | all(. as $id | $ARGS.named.task_ids | index($id) != null)' --argjson task_ids "$(jq '[.tasks[].id]' "$MANIFEST")" "$MANIFEST" >/dev/null 2>&1; then
    error "current task identifiers are not closed over the manifest"
  fi
  if ! jq -e '.support_fence == "experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support"' "$MANIFEST" >/dev/null 2>&1; then
    error "support-state fence is not the required experimental-only label"
  fi

  if [ -f "$ROADMAP" ]; then
    while IFS= read -r id; do
      [ -n "$id" ] || continue
      if ! grep -Fq "$id" "$PLAN"; then
        error "manifest task is absent from plan: $id"
      fi
      row=$(grep -F "| \`$id\` |" "$ROADMAP" | head -n 1 || true)
      if [ -z "$row" ]; then
        error "manifest task is absent from roadmap table: $id"
        continue
      fi
      deps=$(jq -r --arg id "$id" '.tasks[] | select(.id == $id) | (.depends_on // [])[]?' "$MANIFEST")
      roadmap_dependency_cell=$(printf '%s\n' "$row" | awk -F '|' '{print $5}')
      roadmap_deps=$(printf '%s\n' "$roadmap_dependency_cell" | grep -oE 'omp-[a-z0-9-]+' | sort -u || true)
      expected_deps=$(printf '%s\n' "$deps" | sed '/^$/d' | sort -u)
      if [ "$roadmap_deps" != "$expected_deps" ]; then
        error "roadmap dependency set differs from manifest: $id"
      fi
      if [ -z "$deps" ]; then
        if ! printf '%s\n' "$row" | grep -Eq '\|[[:space:]]*none[[:space:]]*\|'; then
          error "roadmap does not encode none for dependency-free task: $id"
        fi
      else
        while IFS= read -r dep; do
          [ -n "$dep" ] || continue
          if ! printf '%s\n' "$row" | grep -Fq "$dep"; then
            error "roadmap dependency parity mismatch: $id requires $dep"
          fi
        done <<<"$deps"
      fi
      if printf '%s\n' "$row" | grep -Eiq 'all P[0-9]|launcher preflight|classifier and all|no open stops|all P[0-9]-P[0-9]'; then
        error "roadmap uses a prose dependency alias for task: $id"
      fi
    done < <(jq -r '.tasks[].id' "$MANIFEST")
  fi

  while IFS= read -r validation; do
    [ -n "$validation" ] || continue
    if ! grep -Fq "$validation" "$PLAN"; then
      error "manifest validation ID is absent from plan: $validation"
    fi
  done < <(jq -r '.tasks[].validation_ids[]' "$MANIFEST" | sort -u)
fi

if command -v "$TASKS_AXI" >/dev/null 2>&1; then
  TASKS_VERSION=$($TASKS_AXI --version 2>&1 || true)
  if ! printf '%s\n' "$TASKS_VERSION" | grep -Fq '0.2.3'; then
    error "Tasks Axi version is not pinned to 0.2.3: $TASKS_VERSION"
  fi
  if [ -f "$BACKLOG" ] && ! "$TASKS_AXI" list --file "$BACKLOG" >/dev/null 2>&1; then
    error "Tasks Axi cannot parse tracked backlog: $BACKLOG"
  fi
else
  error "Tasks Axi executable is unavailable: $TASKS_AXI"
fi

if [ -f "$BACKLOG" ] && [ "$MANIFEST_VALID" -eq 1 ]; then
  while IFS= read -r id; do
    [ -n "$id" ] || continue
      if ! jq -e --arg id "$id" '.tasks | map(.id) | index($id) != null' "$MANIFEST" >/dev/null 2>&1; then
      error "tracked backlog task is absent from manifest: $id"
    fi
  done < <(grep -oE '^- \[[ xX]\] omp-[a-z0-9-]+' "$BACKLOG" | sed -E 's/^- \[[ xX]\] //' | sort -u)
fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    ISSUES=$(printf '%s\n' "${ERRORS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    jq -n --arg schema 'omp-plan-check.v1' --arg status 'BLOCK' --argjson task_count "$TASK_COUNT" --argjson validation_count "$VALIDATION_COUNT" --argjson evidence_count "$EVIDENCE_COUNT" --argjson rollback_count "$ROLLBACK_COUNT" --argjson issues "$ISSUES" '{schema:$schema,status:$status,task_count:$task_count,validation_count:$validation_count,evidence_count:$evidence_count,rollback_count:$rollback_count,issues:$issues}'
  else
    jq -n --arg schema 'omp-plan-check.v1' --arg status 'PASS' --argjson task_count "$TASK_COUNT" --argjson validation_count "$VALIDATION_COUNT" --argjson evidence_count "$EVIDENCE_COUNT" --argjson rollback_count "$ROLLBACK_COUNT" '{schema:$schema,status:$status,task_count:$task_count,validation_count:$validation_count,evidence_count:$evidence_count,rollback_count:$rollback_count,issues:[]}'
  fi
else
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    printf 'BLOCK\n'
    printf '%s\n' "${ERRORS[@]}" >&2
  else
    printf 'PASS: %s tasks, %s validations, %s evidence IDs, %s rollback IDs\n' "$TASK_COUNT" "$VALIDATION_COUNT" "$EVIDENCE_COUNT" "$ROLLBACK_COUNT"
  fi
fi

[ "${#ERRORS[@]}" -eq 0 ]
