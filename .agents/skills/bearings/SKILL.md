---
name: bearings
description: Generate a "pick up where I left off" status report from firstmate's live fleet state. Use when the captain invokes /bearings, asks for a bearings report or morning brief, requests a catch-up, asks "where did I leave off", or asks "what's in the works". Reads bounded local fleet state cheaply, optionally checks open PRs when requested, composes a scannable dated report to data/status-report-<YYYY-MM-DD>.md, and returns only that file path in chat; it is read-mostly and must not tear down, merge, or mutate task state as a side effect of producing the brief.
user-invocable: true
metadata:
  internal: true
---

# bearings

Generate a complete standalone snapshot from the fleet's current state, so the captain can resume in one read after a break, a night, or a context reset.
The deliverable is one dated markdown file and the only chat response is its path.
This skill is read-mostly.
It reads fleet state and writes exactly one report file.
It never tears down a task, merges a PR, dispatches new work, or mutates any task state as a side effect of producing the brief - those belong to the captain's explicit word and the normal task lifecycle.

## What it does

1. **Gather live fleet state with one deterministic command.**
   Run `bin/fm-bearings-snapshot.sh` and read its compact output.
   It is the single bounded, deterministic source for this report and renders TOON by default.
   Do not hand-probe the snapshot schema and do not make ad-hoc `gh-axi`/`gh` calls to assemble fleet facts; this command already assembles them.
   The command's header and `--help` output own its exact fields, bounds, opt-ins, and output contract.
   When the captain asks to include PRs, use the command's live-PR opt-in; otherwise keep the default local-only read.
   If the command is unavailable, fall back to `bin/fm-fleet-snapshot.sh --json` and `bin/fm-crew-state.sh <id>`; never infer current state from a raw `tail` of `state/<id>.status`, which is append-only wake-event history whose last line goes stale.
   For registered secondmates, use the snapshot's structured-home classification and provenance; a parent event or bounded terminal contradiction is fallback evidence, never authority over readable structured home state.
   Structured captain-held decisions come from `decision-hold-lifecycle` and appear under `decisions_open`; do not scrape reports or visual-review artifacts to supplement them.
   A queued item under `gates` only becomes "next work" when its blocker is gone and its time/date gate has arrived; until then it stays queued with the reason.

2. **Compose the detailed report file around the project-centered Capt’s Debrief structure.**
   The gather step is deterministic; your judgment is scoped to the last mile only - ranking the command's facts by what matters right now and writing the scannable prose.
   Never read an earlier `data/status-report-*.md` to decide what to omit, include, describe as changed, or call current.
   The report uses the complete current project-centered structure defined in the detailed file contract below.
   - **Title** - `# Capt’s Debrief` followed by the snapshot date, source, and freshness note.
   - **Projects** - each project is a GitHub Projects-compatible group with identity, Tasks Axi state counts, progress evidence, priority, active or default branch, current action items, and recent completions.
   - **Captain decisions** - every open decision, review, approval, credential, or login with `needs:human`, explicit response options, and its project.
   - **Recent completions** - the bounded current recent-completions baseline from structured state across the main fleet and every registered secondmate home, rendered in full on every run.
   - **Underway** - each live direct report making progress, with its current Tasks Axi state and the plans or main pickup pointers worth reopening, including `data/<id>/report.md` files and `.lavish/*.html` boards.
   - **Queued/gated work** - queued, blocked, and held work with each blocker, date reason, or `needs:human` response.
   - **Reports** - current scout or investigation report pointers.
   - **Pull requests** - locally recorded PRs by default, with live PR discovery and checks only when explicitly requested by the captain.
   - **Secondmate state** - each registered secondmate's structured state, provenance, freshness, active child work, and return-channel condition.
   - **Blockers** - blocked work, unhealthy endpoints, unavailable structured homes, and captain-owned blockers with `needs:human` options.
   - **Omitted surface** - every bounded or opt-in surface omitted from the snapshot, with its reveal flag or reason.
   - **Freshness and provenance** - snapshot generation time, local-only or live source, structured-home provenance, and any stale, fallback, contradiction, or unavailable evidence.

3. **Write the dated report file so it persists, then return only its path in chat.**
   - Write the full report to `data/status-report-<YYYY-MM-DD>.md` using today's date.
     This is the required artifact; it lives in gitignored `data/`.
     If today's file already exists, delete it first, then create a new file from scratch.
   - The chat response is exactly `data/status-report-<YYYY-MM-DD>.md` and contains no inline digest, summary, link wrapper, or additional section.
   - Do not open a Lavish board or create any second artifact as part of `/bearings`.

## Detailed file contract

This skill is the one owner of the `/bearings` detailed Markdown file format.
The inline `/status-report` format is owned by [`status-report`](../status-report/SKILL.md), and this file preserves that project's identity, state, priority, branch, progress, and action-item spine in richer detail.
Every detailed report is a complete current snapshot, never a delta against an earlier report.
Every current action item uses Tasks Axi state names, and every captain-owned item is marked `needs:human` with explicit response options.
Projects with only recent completions may appear in this file because the detailed report preserves the complete current Bearings baseline.

## Tone and content rules

- This report is a private, captain-facing internal artifact that lives in gitignored `data/`, so unlike normal captain chat it MAY reference task ids, PR URLs, and repo names - the captain works with these directly and needs them to resume; keep it organized and scannable, not a raw dump.
- Every PR reference is a full `https://...` URL, never a bare `#number`; a shorthand `#number` is fine only as a back-reference after the full URL has already appeared in the same report.
- Never include PHI or secret values; the report is an operational artifact, but it is still subject to the same security and compliance rules that govern everything else in this fleet.

## Supervision discipline

This skill is read-mostly and changes no fleet state.
Do not tear down a task, merge a PR, dispatch queued work, or mutate any `state/` or `data/` file other than the single report file as a side effect of generating the brief.
If the state you read suggests an action - a PR ready to merge, a queued item whose gate has arrived, a needs-decision finding, or an unhealthy endpoint - name it in the relevant detailed section and let the captain decide, rather than taking the action from inside this skill.
