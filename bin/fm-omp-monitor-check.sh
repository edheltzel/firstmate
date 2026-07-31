#!/usr/bin/env bash
# Project the live OMP task state for Status/Bearings without treating manifest-only rows as progress.
# Usage: bin/fm-omp-monitor-check.sh [--json] [--manifest PATH] [--live-backlog PATH] [--repo-root PATH]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
MANIFEST="$ROOT/.agents/tasks/omp-manifest.json"
LIVE_BACKLOG="${FM_HOME:-$ROOT}/data/backlog.md"
REPO_ROOT="$ROOT"
JSON_OUTPUT=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON_OUTPUT=1 ;;
    --manifest) shift; MANIFEST=${1-} ;;
    --live-backlog) shift; LIVE_BACKLOG=${1-} ;;
    --repo-root) shift; REPO_ROOT=${1-} ;;
    --help|-h) sed -n '2,3p' "$0"; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; exit 2 ;;
  esac
  shift
done

ERRORS=()
error() { ERRORS+=("$1"); }
TMP_DIR=$(mktemp -d "${TMPDIR:-/tmp}/fm-omp-monitor.XXXXXX" 2>/dev/null || true)
if [ -z "$TMP_DIR" ]; then
  printf 'BLOCK\ncould not allocate monitoring temporary workspace\n' >&2
  exit 1
fi
trap 'rm -rf "$TMP_DIR"' EXIT HUP INT TERM

[ -f "$MANIFEST" ] || error "missing OMP monitoring manifest: $MANIFEST"
[ -f "$LIVE_BACKLOG" ] || error "missing live backlog for OMP monitoring: $LIVE_BACKLOG"

if [ -f "$MANIFEST" ] && ! jq empty "$MANIFEST" >/dev/null 2>&1; then error "OMP monitoring manifest is invalid JSON"; fi
if [ -f "$MANIFEST" ] && [ -f "$LIVE_BACKLOG" ]; then
  MANIFEST_IDS=$(jq -c '[.tasks[].id]' "$MANIFEST")
  jq -n --arg branch "$(git -C "$REPO_ROOT" branch --show-current 2>/dev/null || true)" --arg commit "$(git -C "$REPO_ROOT" rev-parse HEAD 2>/dev/null || true)" --argjson ids "$MANIFEST_IDS" '{branch:$branch,commit:$commit,manifest_ids:$ids}' >"$TMP_DIR/meta.json"
  {
    sed -nE 's/^- \[[xX]\] (omp-[a-z0-9-]+)(.*)$/\1\tdone\t\2/p' "$LIVE_BACKLOG"
    sed -nE 's/^- \[ \] (omp-[a-z0-9-]+)(.*)$/\1\tqueued\t\2/p' "$LIVE_BACKLOG"
  } >"$TMP_DIR/live.tsv"
  if [ "$(cut -f1 "$TMP_DIR/live.tsv" | sort | uniq -d | wc -l | tr -d ' ')" -ne 0 ]; then error "live OMP backlog contains duplicate task rows"; fi
  jq -Rsc 'split("\n") | map(select(length > 0) | split("\t") | {id:.[0],state:.[1],detail:.[2]})' "$TMP_DIR/live.tsv" >"$TMP_DIR/live.json"
  jq --slurpfile live "$TMP_DIR/live.json" --slurpfile meta "$TMP_DIR/meta.json" --argjson historical '["omp-corrected-plan-redteam-o8","omp-final-corrected-plan-redteam-o9"]' '
    . as $manifest
    | ($live[0]) as $rows
    | ($meta[0]) as $m
    | ($rows | map(.id)) as $live_ids
    | ($rows | map(. as $row | ($manifest.tasks | map(select(.id == $row.id)) | .[0]) as $task | select($task != null and ($historical | index($row.id) == null)) | $task + {live_state:$row.state})) as $scoped
    | ($scoped | map(select(.live_state == "done")) | length) as $completed
    | ($scoped | length) as $total
    | ($scoped[0] // null) as $first
    | ($rows | map(select(.id as $id | ($manifest.tasks | map(.id) | index($id)) != null and ($historical | index($id) == null) and .state != "done")) | .[0] // null) as $next_row
    | (($manifest.tasks | map(select(.id == ($next_row.id // ""))) | .[0]) // null) as $next_task
    | {
        schema:"omp-monitor-check.v1",
        branch:$m.branch,
        commit:$m.commit,
        phase:($next_task.phase // $first.phase // null),
        milestone:($next_task.milestone // $first.milestone // null),
        completed:$completed,
        total:$total,
        scoped_task_ids:($scoped | map(.id)),
        manifest_only_ids:($manifest.tasks | map(select(.id as $id | ($live_ids | index($id) == null))) | map(.id)),
        historical_task_ids:($rows | map(. as $row | select($historical | index($row.id) != null) | $row.id)),
        next_gate:(if $next_task == null then null else {id:$next_task.id,phase:$next_task.phase,milestone:$next_task.milestone,owner:$next_task.owner} end),
        blockers:($rows | map(select(.state != "done" and (.detail | test("blocked-by:"))) | . as $row | ($row.detail | capture("blocked-by: (?<dependency>[^ ]+)")) as $block | ($manifest.tasks | map(select(.id == $row.id)) | .[0]) as $task | {task_id:$row.id,blocked_by:$block.dependency,owner:($task.owner // "unknown"),containment:(($task.blocked_by_stop_ids // []) | join(","))})),
        needs_human:(($rows | map(.detail) | join("\n") | test("needs:human")))
      }
  ' "$MANIFEST" >"$TMP_DIR/result.json" 2>/dev/null || error "could not derive OMP monitoring projection"
fi

if [ "${#ERRORS[@]}" -gt 0 ]; then
  ISSUES=$(printf '%s\n' "${ERRORS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
  if [ "$JSON_OUTPUT" -eq 1 ]; then jq -n --arg schema 'omp-monitor-check.v1' --arg status BLOCK --argjson issues "$ISSUES" '{schema:$schema,status:$status,issues:$issues}'; else printf 'BLOCK\n%s\n' "${ERRORS[@]}" >&2; fi
  exit 1
fi

if [ ! -s "$TMP_DIR/result.json" ] || ! jq empty "$TMP_DIR/result.json" >/dev/null 2>&1; then
  if [ "$JSON_OUTPUT" -eq 1 ]; then jq -n '{schema:"omp-monitor-check.v1",status:"BLOCK",issues:["monitoring projection is empty or invalid"]}'; else printf 'BLOCK\nmonitoring projection is empty or invalid\n' >&2; fi
  exit 1
fi
if [ "$JSON_OUTPUT" -eq 1 ]; then jq '. + {status:"PASS"}' "$TMP_DIR/result.json"; else jq -r '"PASS: phase=" + (.phase // "none") + " completed=" + (.completed|tostring) + "/" + (.total|tostring) + " next=" + ((.next_gate.id // "none"))' "$TMP_DIR/result.json"; fi
