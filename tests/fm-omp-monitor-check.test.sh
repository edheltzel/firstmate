#!/usr/bin/env bash
# Fixture matrix for OMP Status/Bearings monitoring projection.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

CHECK="$ROOT/bin/fm-omp-monitor-check.sh"
TMP_ROOT=$(fm_test_tmproot fm-omp-monitor-check)

write_live() {
  local state=$1 historical=$2
  mkdir -p "$TMP_ROOT"
  {
    printf '%s\n' '# Backlog' '' '## Queued'
    if [ "$historical" = yes ]; then
      printf '%s\n' '- [ ] omp-final-corrected-plan-redteam-o9 - historical review (repo: AgentThemis) (kind: scout) (priority: 0)'
    else
      printf '%s\n' '- [x] omp-final-corrected-plan-redteam-o9 - historical review (repo: AgentThemis) (kind: scout) (priority: 0)'
    fi
    if [ "$state" = "done" ]; then
      printf '%s\n' '- [x] omp-final-authority-redteam-o10 - final authority (repo: AgentThemis) (kind: scout) (priority: 0) (done 2026-07-28)'
    else
      printf '%s\n' '- [ ] omp-final-authority-redteam-o10 - final authority (repo: AgentThemis) (kind: scout) (priority: 0) blocked-by: omp-final-corrected-plan-redteam-o9'
      printf '%s\n' '  needs:human only when a genuine decision exists.'
    fi
  } >"$TMP_ROOT/live.md"
}

test_current_contract_passes() {
  local out status=0
  write_live blocked no
  out=$($CHECK --json --live-backlog "$TMP_ROOT/live.md" --repo-root "$ROOT") || status=$?
  expect_code 0 "$status" "blocked monitoring fixture should pass"
  assert_contains "$out" '"status": "PASS"' "monitoring fixture did not pass"
  assert_contains "$out" '"next_gate":' "monitoring fixture omitted next gate"
  assert_contains "$out" '"completed": 0' "manifest-only rows inflated completed count"
  assert_contains "$out" '"total": 1' "manifest-only rows inflated denominator"
  pass "omp-monitor-check: blocked and manifest-only fixture is exact"
}

test_terminal_fixture_excludes_historical() {
  local out status=0
  write_live "done" yes
  out=$($CHECK --json --live-backlog "$TMP_ROOT/live.md" --repo-root "$ROOT") || status=$?
  expect_code 0 "$status" "terminal monitoring fixture should pass"
  assert_contains "$out" '"completed": 1' "terminal fixture did not count live completion"
  assert_contains "$out" '"total": 1' "historical O9 row changed the denominator"
  assert_contains "$out" '"next_gate": null' "terminal fixture retained a next gate"
  assert_contains "$out" 'omp-final-corrected-plan-redteam-o9' "historical task was not disclosed"
  pass "omp-monitor-check: terminal and historical fixture is exact"
}

test_current_contract_passes
test_terminal_fixture_excludes_historical
