#!/usr/bin/env bash
# Validate the machine-readable OMP runtime and source pin without launching OMP.
# Usage: bin/fm-omp-runtime-pin-check.sh [--json] [--pin PATH]

set -u

ROOT=$(cd -- "$(dirname -- "$0")/.." && pwd)
PIN="$ROOT/.agents/tasks/omp-runtime-pin.json"
JSON_OUTPUT=0

usage() { sed -n '2,3p' "$0"; }

while [ "$#" -gt 0 ]; do
  case "$1" in
    --json) JSON_OUTPUT=1 ;;
    --pin) shift; PIN=${1-} ;;
    --help|-h) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage >&2; exit 2 ;;
  esac
  shift
done

ERRORS=()
error() { ERRORS+=("$1"); }

SHA256_TOOL=${SHA256_TOOL:-$(command -v shasum 2>/dev/null || command -v sha256sum 2>/dev/null || true)}
sha256() {
  case "$SHA256_TOOL" in
    */shasum|shasum) "$SHA256_TOOL" -a 256 "$1" | awk '{print $1}' ;;
    */sha256sum|sha256sum) "$SHA256_TOOL" "$1" | awk '{print $1}' ;;
    *) return 1 ;;
  esac
}

if [ ! -f "$PIN" ] || ! jq empty "$PIN" >/dev/null 2>&1; then
  error "runtime pin is missing or invalid JSON: $PIN"
fi
if [ "${#ERRORS[@]}" -eq 0 ] && ! jq -e '.schema == "omp-runtime-pin.v1" and .version == 1 and (.packages | type == "array") and (.source_anchors | type == "array")' "$PIN" >/dev/null 2>&1; then
  error "runtime pin schema is invalid"
fi

if [ "${#ERRORS[@]}" -eq 0 ]; then
  EXPECTED_COMMAND=$(jq -r '.executable.command // empty' "$PIN")
  EXPECTED_VERSION=$(jq -r '.executable.version // empty' "$PIN")
  EXPECTED_EXECUTABLE_SHA256=$(jq -r '.executable.sha256 // empty' "$PIN")
  EXPECTED_BUN=$(jq -r '.bun_version // empty' "$PIN")
  ACTUAL_COMMAND=$(command -v "$EXPECTED_COMMAND" 2>/dev/null || true)
  if [ -z "$ACTUAL_COMMAND" ]; then
    error "pinned executable is unavailable: $EXPECTED_COMMAND"
  else
    ACTUAL_VERSION=$($EXPECTED_COMMAND --version 2>/dev/null | sed -n 's/^omp\/\(.*\)$/\1/p' | head -n 1)
    [ "$ACTUAL_VERSION" = "$EXPECTED_VERSION" ] || error "OMP version drift: expected $EXPECTED_VERSION, got ${ACTUAL_VERSION:-<unknown>}"
    ACTUAL_RESOLVED=$(python3 -c 'import os,sys; print(os.path.realpath(sys.argv[1]))' "$ACTUAL_COMMAND" 2>/dev/null || true)
    EXPECTED_RESOLVED=$(jq -r '.executable.resolved_path // empty' "$PIN")
    [ "$ACTUAL_RESOLVED" = "$EXPECTED_RESOLVED" ] || error "OMP executable path drift: expected $EXPECTED_RESOLVED, got ${ACTUAL_RESOLVED:-<unknown>}"
    ACTUAL_EXECUTABLE_SHA256=$(sha256 "$ACTUAL_RESOLVED" 2>/dev/null || true)
    [ "$ACTUAL_EXECUTABLE_SHA256" = "$EXPECTED_EXECUTABLE_SHA256" ] || error "OMP executable hash drift"
  fi
  ACTUAL_BUN=$(bun --version 2>/dev/null || true)
  [ "$ACTUAL_BUN" = "$EXPECTED_BUN" ] || error "Bun version drift: expected $EXPECTED_BUN, got ${ACTUAL_BUN:-<unknown>}"

  while IFS=$'\t' read -r name version root; do
    [ -n "$name" ] || continue
    [ -d "$root" ] || { error "pinned package root is missing: $root"; continue; }
    ACTUAL_PACKAGE_VERSION=$(jq -r '.version // empty' "$root/package.json" 2>/dev/null || true)
    [ "$ACTUAL_PACKAGE_VERSION" = "$version" ] || error "package version drift for $name: expected $version, got ${ACTUAL_PACKAGE_VERSION:-<unknown>}"
  done < <(jq -r '.packages[] | [.name,.version,.root] | @tsv' "$PIN")

  while IFS=$'\t' read -r root relative expected; do
    [ -n "$relative" ] || continue
    ACTUAL_FILE="$root/$relative"
    [ -f "$ACTUAL_FILE" ] || { error "pinned package file is missing: $ACTUAL_FILE"; continue; }
    ACTUAL_HASH=$(sha256 "$ACTUAL_FILE" 2>/dev/null || true)
    [ "$ACTUAL_HASH" = "$expected" ] || error "package file hash drift: $ACTUAL_FILE"
  done < <(jq -r '.packages[] as $package | $package.files[] | [$package.root,.path,.sha256] | @tsv' "$PIN")

  while IFS=$'\t' read -r path line needle expected; do
    [ -n "$path" ] || continue
    [ -f "$path" ] || { error "pinned source anchor is missing: $path"; continue; }
    ACTUAL_HASH=$(sha256 "$path" 2>/dev/null || true)
    [ "$ACTUAL_HASH" = "$expected" ] || error "source anchor hash drift: $path"
    grep -Fq "$needle" "$path" || error "source anchor text is missing: $path:$line"
  done < <(jq -r '.source_anchors[] | [.path,.line,.needle,.sha256] | @tsv' "$PIN")
fi

if [ "$JSON_OUTPUT" -eq 1 ]; then
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    ISSUES=$(printf '%s\n' "${ERRORS[@]}" | jq -Rsc 'split("\n") | map(select(length > 0))')
    jq -n --arg schema 'omp-runtime-pin-check.v1' --arg status BLOCK --argjson issues "$ISSUES" '{schema:$schema,status:$status,issues:$issues}'
  else
    jq -n --arg schema 'omp-runtime-pin-check.v1' --arg status PASS '{schema:$schema,status:$status,issues:[]}'
  fi
else
  if [ "${#ERRORS[@]}" -gt 0 ]; then
    printf 'BLOCK\n%s\n' "${ERRORS[@]}" >&2
  else
    printf 'PASS: OMP runtime pin and source anchors match\n'
  fi
fi

[ "${#ERRORS[@]}" -eq 0 ]
