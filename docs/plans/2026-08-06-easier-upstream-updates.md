# Plan: Easier AgentThemis upstream updates

Date: 2026-08-06
Project: AgentThemis (`edheltzel/firstmate`, upstream `kunchenguid/firstmate`)
Status: draft for captain review

## Problem

Upstream catch-up is painful and easy to stall:

- Gaps grow to dozens of commits while a PR sits open or cancelled.
- Primary checkout accumulates half-finished merge/rebase state (this session: mid-rebase with conflict, local `main` ahead/behind origin).
- Old task/PR state points at worktrees later reused by Archon, so recovery risks the wrong home.
- Conflict surface is wide (`AGENTS.md`, spawn/session/teardown, Herdr/tmux backends, supervision docs/tests).
- Delivery mode has drifted between direct-PR and no-mistakes; cancelled pipeline runs leave non-authoritative gate commits.

## Goal

Make routine upstream updates boring:

1. Small, frequent catch-ups instead of large archaeology.
2. One standard playbook a worker can run without reinventing policy.
3. Primary checkout stays clean; only isolated copies do merge work.
4. Fork-only contracts survive merges without rediscovery.
5. Captain gets a short outcome report, not a recovery project.

## Non-goals

- Not a full automated merge bot with unsupervised conflict resolution.
- Not rewriting published fork history.
- Not pushing to upstream.
- Not expanding merge authority beyond existing low-risk / yolo rules.

## Recommended operating model

### Cadence

- **Default:** weekly catch-up, or anytime upstream is **>= 5 commits** ahead of `origin/main`.
- **Hard stop:** if gap hits **15+ commits**, catch up before starting unrelated AgentThemis feature work.
- Optional heartbeat mention in fleet debrief: `upstream gap: N commits`.

### One-command intake shape (human or firstmate)

When captain says "update firstmate / catch up upstream":

1. Fetch `origin` + `upstream`.
2. Report gap: commit count + short subject list.
3. If gap is 0: stop, nothing to do.
4. Else dispatch one ship task with the standard brief template below.
5. Never start the merge in the primary checkout.

### Standard task template

- **Project:** AgentThemis
- **Mode:** `no-mistakes` (standing upstream delivery rule)
- **Branch:** `fm/firstmate-upstream-catchup-YYYYMMDD`
- **Base:** current `origin/main` only (ignore dirty local `main`)
- **Merge:** `git merge --no-ff upstream/main` only (no rebase of published history)
- **Implementation phase:** merge + conflict resolve + commit only
- **Validation phase:** no-mistakes exclusively (tests/review/fix/push/PR/CI)
- **PR body must include:** exact SHAs, conflict file list, preserved fork contracts, link to any superseded PR

### Conflict policy (stable)

1. Read upstream intent first.
2. Keep fork change only if it still serves an unmet need.
3. Otherwise take upstream.
4. Never drop known fork contracts without an explicit captain decision:
   - Project-key / explicit delivery-contract spawn behavior
   - Herdr fleet labeling (`*-Fleet`, Themis/Archon identities)
   - OMP as standard harness adapter (no retired staging apparatus)
   - Host-local signed worker identity (do not remote-propagate `config/worker-git-identity`)
   - Captain low-risk PR merge posture and Atlas/DOX standing rules where encoded in tracked surfaces
5. No unrelated edits in a catch-up PR.

### Primary-checkout hygiene (mandatory)

Before/after every catch-up:

- Primary must not be mid-merge/mid-rebase.
- Local `main` should match `origin/main` after the PR lands and fleet sync runs.
- Half-finished local merges are aborted or finished in an isolated copy, never left on primary.
- Catch-up task metadata must never share Archon's home/worktree.

### After green PR

1. Merge under existing authority (low-risk standing grant when truly low-risk and green; otherwise ask).
2. Fleet-sync primary + Archon home.
3. Close the task and delete the catch-up branch after land.
- Record one line in learnings only if a new recurring conflict pattern appeared.

## Make it easier in the tooling (incremental)

Ship these as small follow-ups only if the playbook still hurts after 2–3 manual cycles.

| Priority | Change | Why |
| --- | --- | --- |
| P0 | Checked-in brief snippet or skill trigger: "upstream catch-up" fills the standard task text | Removes re-deriving SHAs/policy each time |
| P0 | `bin` helper or status line: `fm-upstream-gap` prints commits ahead/behind + overlap file count | Makes cadence mechanical |
| P1 | Fork-contract checklist file (`docs/fork-contracts.md` or skill) cited by every catch-up brief | Stops re-losing hard-won fork behavior |
| P1 | Guard: refuse catch-up spawn if primary has merge/rebase in progress | Prevents this session's primary tangle |
| P2 | Optional scheduled scout every week that only reports gap (no merge) | Captain sees drift early |
| P2 | Supersede-old-PR recipe in brief (close/note old catch-up PRs) | Avoids zombie PR #6 class confusion |

Do **not** build a multi-phase activation apparatus or custom merge control plane. Use the ordinary ship + no-mistakes path.

## Immediate path for the current gap

Already kicked off under task `firstmate-upstream-catchup-20260803` (restarted 2026-08-06):

- Fresh branch from current `origin/main`
- Merge current `upstream/main`
- no-mistakes to green PR
- Supersedes closed https://github.com/edheltzel/firstmate/pull/6

This plan governs **future** updates after that lands.

## Success metrics

- Catch-up PR opened within one work session of the request
- Primary checkout never left mid-rebase/merge from catch-up work
- No accidental Archon/home collision
- Conflict resolutions cite the fork-contract checklist
- Median upstream gap stays under 10 commits

## Captain decisions requested

1. **Cadence:** weekly + 5-commit trigger (recommended), or different threshold?
2. **Auto-dispatch:** when gap >= threshold on session start, should firstmate auto-file/dispatch catch-up, or only report?
3. **Tooling now vs later:** implement P0 helpers in the same PR after this catch-up, or wait until the current merge lands?

## Recommendation

Adopt the playbook immediately (cadence + standard brief + primary hygiene + fork-contract list).
Implement only P0 helpers after the current catch-up lands, unless catch-up itself is blocked by missing tooling.
Keep auto-dispatch off at first; report gap and ask, to avoid surprise multi-hour merges.
