#!/usr/bin/env bash
# Deterministic contract checks for the user-invocable status-report skill.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

SKILL="$ROOT/.agents/skills/status-report/SKILL.md"
[ -f "$SKILL" ] || fail "status-report SKILL.md missing"
BODY=$(sed -n '1,240p' "$SKILL")

test_trigger_semantics() {
  for trigger in '/status-report' 'status' 'status report' "standalone or general request for \`report\`"; do
    assert_contains "$BODY" "$trigger" "status-report trigger $trigger"
  done
  assert_contains "$BODY" "Do not trigger for a report about a named subject" "named subject requests stay with their subject"
  assert_contains "$BODY" "Return only the inline report" "status-report is inline-only"
  assert_contains "$BODY" "Capt’s Debrief" "status-report title"
  assert_contains "$BODY" "one flat ordered project list" "flat project list"
  assert_contains "$BODY" "no group headings or per-project headings" "no category headings"
  assert_contains "$BODY" "<Project> - <percentage or unknown> complete" "exact project spine"
  assert_not_contains "$BODY" "## Actively progressing" "flat report must not add an active section heading"
  assert_not_contains "$BODY" "## Blocked or held" "flat report must not add a blocked section heading"
  assert_not_contains "$BODY" "## Captain-awaited" "flat report must not add a captain section heading"
  pass "status-report trigger semantics and inline title are explicit"
}

test_active_filter_order_and_counts() {
  assert_contains "$BODY" "Include only projects with current" "active-only filtering"
  assert_contains "$BODY" "Do not include a project whose only records are \`done\`" "done-only projects are filtered"
  assert_contains "$BODY" "Order projects with self-progressing \`in_flight\` work first" "project ordering"
  assert_contains "$BODY" "numeric priority ascending" "priority ordering"
  assert_contains "$BODY" "Count each Tasks Axi record as exactly one action item" "action-item counting"
  assert_contains "$BODY" "folded to the registered project key" "canonical project identity"
  assert_contains "$BODY" "List only current action items inline" "completed action omission"
  pass "status-report filters active projects, orders them, and counts records"
}

test_progress_branch_and_human_options() {
  assert_contains "$BODY" "live board query supplies an explicit completion percentage" "live board percentage precedence"
  assert_contains "$BODY" "equally weighted scoped Tasks Axi records" "Tasks Axi percentage derivation"
  assert_contains "$BODY" "Report \`unknown\` instead of inventing a percentage" "unknown progress fallback"
  assert_contains "$BODY" "active branch name(s), or repository default branch" "branch selection"
  assert_contains "$BODY" "needs:human" "captain-owned marker"
  assert_contains "$BODY" "Every \`needs:human\` line must include concise explicit response options" "human response options"
  pass "status-report defines progress, branch selection, and explicit captain options"
}

test_local_default_and_empty_state() {
  assert_contains "$BODY" "Run \`bin/fm-bearings-snapshot.sh --json\`" "deterministic local source"
  assert_contains "$BODY" "must not query GitHub Projects, pull requests, or any other network service" "zero-network default"
  assert_contains "$BODY" "only when the captain explicitly asks for live GitHub status" "live GitHub opt-in"
  assert_contains "$BODY" "No active, blocked, held, queued-next, or captain-awaited work" "empty state"
  pass "status-report preserves local-only default and concise empty state"
}

test_trigger_semantics
test_active_filter_order_and_counts
test_progress_branch_and_human_options
test_local_default_and_empty_state
