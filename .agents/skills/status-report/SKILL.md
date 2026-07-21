---
name: status-report
description: >-
  Return a concise current Capt’s Debrief for /status-report, status, status report,
  or a standalone general request for report, using the deterministic local fleet
  and Tasks Axi snapshot by default and live GitHub status only when explicitly requested.
user-invocable: true
metadata:
  internal: true
---

# status-report

Use this skill for `/status-report`, `status`, `status report`, or a standalone or general request for `report`.
Do not trigger for a report about a named subject, artifact, file, PR, issue, or other specific object.
Those requests belong to the ordinary subject-specific response.

Return only the inline report below, with no preamble, follow-up, file write, or alternate digest.
The first line must be the exact title `Capt’s Debrief`.

## Source and freshness

Run `bin/fm-bearings-snapshot.sh --json` and use its project records as the deterministic local source.
Do not scrape raw status-event tails, read an earlier report, or make ad hoc backlog or GitHub calls.
The default path is local-only and must not query GitHub Projects, pull requests, or any other network service.
Query GitHub Projects or pull requests only when the captain explicitly asks for live GitHub status.
When a live board query supplies an explicit completion percentage, use that percentage and identify it as live board evidence.
Otherwise derive completion from explicit acceptance-criteria evidence when the snapshot provides it.
If that evidence is absent, derive completion from equally weighted scoped Tasks Axi records.
Report `unknown` instead of inventing a percentage when no defensible denominator exists.

## Inline report contract

Render this project-centered GitHub Projects-compatible layout and keep it concise.

```text
Capt’s Debrief
As of: <snapshot time> | Source: local snapshot [or live GitHub status]

## Actively progressing
### <project>
Status: <Tasks Axi state name>
Priority: <number or unknown>
Branch: <active branch name(s), or repository default branch when no active branch exists>
Progress: <percentage or unknown> (<completed>/<scoped> complete)
Actions: <current Tasks Axi record count>
- [<Tasks Axi state>] <current action>

## Blocked or held
### <project>
Status: <Tasks Axi state name>
...

## Captain-awaited
### <project>
Status: <Tasks Axi state name>
...
```

Use `in_flight`, `queued`, `held`, and `done` as the Tasks Axi state vocabulary.
Represent a blocker as blocker evidence on the record or project while retaining its Tasks Axi state.
Use `needs:human` on every captain-owned review, approval, choice, response, credential request, or blocker-clearing action.
Every `needs:human` line must include concise explicit response options such as `Options: approve / request changes` or the actual alternatives from the decision record.
Count each Tasks Axi record as exactly one action item, never each sentence, subtask, status event, or child process.
List only current action items inline.
Represent completed records only through progress percentages and completed/scoped counts.
Use each active branch name from the snapshot.
When a project has no active branch, display its repository default branch.
Order projects with self-progressing `in_flight` work first, blocked or held work second, and projects whose only current work is `needs:human` last.
Within each group, sort by numeric priority ascending with unknown priorities last, then by project name.

Include only projects with current `in_flight`, blocked, held, queued-next, or captain-awaited work.
Do not include a project whose only records are `done`.
If no project qualifies, render only this concise empty state after the title and source line:

```text
No active, blocked, held, queued-next, or captain-awaited work.
```

The inline report is complete on its own and must not link to or summarize the `/bearings` file.
