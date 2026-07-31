#!/usr/bin/env bash
# Behavior tests for the versioned OMP runtime pin.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-omp-runtime-pin-check.sh"
TMP_ROOT=$(fm_test_tmproot fm-omp-runtime-pin)
trap 'rm -rf "$TMP_ROOT"' EXIT

test_current_pin_passes() {
  local out status=0
  out=$($CHECK --json) || status=$?
  expect_code 0 "$status" "current runtime pin should pass"
  assert_contains "$out" '"status": "PASS"' "current runtime pin did not pass"
  pass "omp-runtime-pin: current installed package set passes"
}

test_version_mismatch_refuses() {
  local pin="$TMP_ROOT/version.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq '.executable.version = "17.1.6"' "$ROOT/.agents/tasks/omp-runtime-pin.json" >"$pin"
  out=$($CHECK --json --pin "$pin") || status=$?
  expect_code 1 "$status" "runtime version mismatch should refuse"
  assert_contains "$out" 'OMP version drift' "runtime version mismatch was not reported"
  pass "omp-runtime-pin: version drift is refused"
}

test_source_hash_mismatch_refuses() {
  local pin="$TMP_ROOT/source.json" out status=0
  mkdir -p "$TMP_ROOT"
  jq '.source_anchors[0].sha256 = ("0" * 64)' "$ROOT/.agents/tasks/omp-runtime-pin.json" >"$pin"
  out=$($CHECK --json --pin "$pin") || status=$?
  expect_code 1 "$status" "source hash mismatch should refuse"
  assert_contains "$out" 'source anchor hash drift' "source hash mismatch was not reported"
  pass "omp-runtime-pin: source drift is refused"
}

test_current_pin_passes
test_version_mismatch_refuses
test_source_hash_mismatch_refuses
