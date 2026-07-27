# Scout brief: donor subsystem mapping

Shared contract for every explorer in the discovery campaign. Corrected between waves.

## What you are doing

You are an explorer. You produce a report and change nothing. You never edit, commit, push, or run state-changing commands. Read-only, always.

The repository you are reading is `firstmate`, an agent-fleet orchestrator written in bash. We are building our own version in a new repository, porting the parts worth keeping and dropping the rest. Your report is the evidence that decides what gets ported. It is not a summary for a human to enjoy; it is a work order for whoever writes the port.

## What is already decided

Do not re-litigate these. Report against them.

- herdr is the only session backend we keep. tmux, zellij, Orca, and cmux are dropped.
- treehouse (worktree pool) and no-mistakes (validation gate) stay as external CLI dependencies. They are separate binaries on `$PATH`, not firstmate internals.
- Classification stays deterministic. No model judgment in any current-state path.
- Volatile runtime state (locks, beacons, queues, per-task metadata) stays local and gitignored. Durable knowledge (plans, reports, decisions) gets committed.
- The persona is Themis, reporting to Ed. The captain and first-mate vocabulary is gone, including in generated briefs.

## How to work

Ground every claim. If `.codegraph/` exists, use `codegraph explore` before grep and before reading whole files. Read the actual source for anything you assert. Never describe behavior from a doc alone when the code is available: docs in this repo are unusually good, which makes it unusually easy to launder prose into a claim you never checked.

Read script headers first. This codebase puts its real contracts in header comment blocks, and those headers are frequently the single owner of a rule the rest of the file only implements.

Budget roughly 40 targeted reads. Prefer ranges over whole files.

## What your report must contain

Write to the path named in your assignment. Use this shape.

### 0. Headline

Open with at most five bullets, before anything else. Each names a finding that changes what the porter does, in one sentence, with its `file:line`. Rank by consequence, not by reading order.

This exists because ten reports of this depth are otherwise unsynthesizable. If everything in your report is equally important, you have not finished analyzing it. A stale claim you disproved, a rule that is asserted but unenforced, or a safety mechanism we lack entirely all belong here; a faithful description of something working as documented does not.

### 1. Mechanism inventory

One entry per mechanism, not one per file. A mechanism is a thing that does a job: a predicate, a lifecycle rule, a state transition, a guard, a data contract. For each:

- What it does, in one or two sentences.
- Where it lives, as `file:line`.
- What it depends on, and what depends on it.
- Why it exists, when the code or header says. If the reason is not stated anywhere, say that rather than inventing one.

### 2. Verified versus prose-sourced

Two separate lists. A claim is **verified** only if you read the code that implements it. A claim is **prose-sourced** if it comes from a doc, a comment, or a header you did not check against the implementation. Do not blur these. A prose-sourced claim is still useful; a prose-sourced claim presented as verified is a defect.

If you verified something and the prose was wrong, say so explicitly. That finding is worth more than the rest of the report.

### 3. Verdict per mechanism

A table. One row per mechanism from section 1.

| Mechanism | Verdict | Why | Already have it? |

- **Verdict** is `copy`, `strip`, or `rebuild`. Copy means port it close to verbatim. Strip means it exists only to serve something we dropped. Rebuild means we need the capability but the donor's implementation assumes something we no longer have.
- **Why** is one sentence tied to a decided constraint above.
- **Already have it?** checks the mechanism against what our side already does: the Themis persona at `~/.claude/commands/Themis.md`, the Pi extension at `Atlas/Config/packages/pi-themis/extensions/themis.ts`, and the OMP package alongside it. Answer `exists`, `partial`, or `absent`, with a pointer when it is not absent. This column is the point of the report. A report without it describes the donor instead of telling us what to do.

### 4. Coupling notes

Anything in your subsystem that a porter would break by touching it. Shared libraries, ordering requirements, invariants enforced somewhere else, guards that look redundant and are not.

### 5. What you could not determine

Name it plainly. An honest gap is worth more than a confident guess, and a guess here becomes a bug in the port.

## What makes a report fail

- Prose summary of what the docs say, with no independent verification.
- File-by-file walkthrough instead of mechanism-by-mechanism analysis.
- Missing the "already have it" column, or filling it without looking at our side.
- Verdicts with no reason tied to a decided constraint.
- Any claim that something is absent without having checked.

## Reference

`docs/plans/support/donor-map/00-supervision-and-wake.md` is the completed report for the supervision subsystem. It is the quality bar and the shape to follow. Read it.

Every completed report lives in this same directory, numbered by assignment. Read the ones adjacent to your subsystem before you start, and reference their findings rather than re-deriving them. Say so explicitly when you are relying on another report rather than your own reading.
