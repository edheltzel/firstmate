---
name: updatefirstmate
description: >-
  Self-update a running Themis firstmate from Kun, then its secondmates.
  Use when the captain invokes /updatefirstmate (e.g. "/updatefirstmate", "update firstmate", "pull the latest firstmate").
  Brings Kun into the running Themis checkout without destroying unique Themis commits, fast-forwards every local or remote secondmate through its guarded path, then re-reads AGENTS.md and nudges each updated secondmate so the tree runs the latest bin/ and instructions.
user-invocable: true
metadata:
  internal: true
---

# updatefirstmate

Self-update firstmate in place.
Firstmate is its own repo, behind the same no-mistakes gate as any project, so new tracked material (`AGENTS.md`, `bin/`, `.agents/skills/`, and public `skills/`) reaches Kun and then sits there until each running firstmate pulls it.
On this fork the running home lives on Themis, and GitHub default `master` is the Kun mirror.
Only `AGENTS.md`, `bin/`, and `.agents/skills/` are a running firstmate instruction surface; public `skills/` is installer-facing and is not loaded by firstmate.
This skill performs that pull for the running Themis firstmate and every secondmate, without disturbing any in-flight work.

`bin/fm-update.sh` owns the git mechanics.
From a clean Themis checkout it fetches `upstream` (never invents that remote), fast-forwards local `master` to Kun, optionally pushes `origin/master` when that is a clean fast-forward of the GitHub mirror, and merges `master` into Themis so unique Themis commits remain.
It fast-forwards Themis only when Themis is already an ancestor of `master`.
If HEAD is not Themis, it skips that merge and reports `on <branch>, expected Themis`.
It never checks out `master` as HEAD of the running home, never forces, never stashes, and never discards unlanded work.
A merge conflict aborts, prints the conflicted paths, and leaves Themis untouched.
Secondmate homes stay on the existing origin fast-forward path.
A tracked-files fast-forward leaves the gitignored operational dirs (data/, state/, config/, projects/, .no-mistakes/) untouched, so a secondmate's in-flight work is never disrupted.
This touches only the firstmate repo and its own worktrees, never anything under `projects/`.

## What it does

1. **Run the updater:**
   ```sh
   bin/fm-update.sh
   ```
   It updates the running Themis checkout from Kun as described above, then updates every registered local or remote secondmate home through its placement-specific guarded path.
   It prints one status line per target (`updated <old>..<new>` / `already current` / `skipped: <reason>`), followed by two action lines that tell you exactly what to do next:
   - `reread-firstmate: yes|no`
   - `nudge-secondmates: fm-<id>...|none`

2. **Re-read AGENTS.md if your own instructions changed.**
   When the updater printed `reread-firstmate: yes`, the tracked instruction surface (`AGENTS.md`, `bin/`, or `.agents/skills/`) just advanced under you.
   **Read `AGENTS.md` now** (CLAUDE.md is a symlink to it) to refresh your operating instructions before doing anything else, so you are acting on the new instructions rather than the stale ones you were started with.
   When it printed `reread-firstmate: no`, nothing changed for you - skip the re-read.

3. **Nudge each updated live secondmate.**
   For every target listed on the `nudge-secondmates:` line (do nothing when it says `none`), send a one-line re-read nudge so that secondmate picks up its new instructions too:
   ```sh
   FM_HOME=<this-firstmate-home> bin/fm-send.sh <id> 'firstmate was updated to the latest - please re-read your AGENTS.md to pick up the new instructions.'
   ```
   Include `FM_HOME=<this-firstmate-home>` unless `FM_HOME` is already set to the active firstmate home.
   This is a gentle steer, not an interruption: the secondmate already got a safe tracked-files fast-forward, and the nudge never forces, tears down, or discards its work.
   A secondmate that was skipped, already current, or has no live metadata is not on the list and needs no nudge.

4. **Report to the captain in plain outcomes.**
   Summarize what landed under `AGENTS.md` section 9 without firstmate's internal vocabulary: which parts of the fleet are now on the latest, and which were left as-is and why.
   For example: "Captain, firstmate and both second mates are now on the latest."
   Surface any skipped target whose reason needs the captain's attention - for instance a home with its own un-landed changes (diverged) or local edits (dirty), which were left untouched on purpose.
   If the updater printed a merge conflict, say that Kun did not land and name the conflicted files.

## Safety

- **Never force, stash, or discard unlanded work.**
  Dirty, diverged, offline, and off-Themis running checkouts are skipped and reported.
  Local `master` moves only by fast-forward to Kun.
  Themis keeps unique commits by merging `master` rather than resetting onto Kun.
- **Only the firstmate repo and its worktrees** are touched, never `projects/`.
- **Secondmates are never disrupted.**
  A local or remote secondmate gets a tracked-files fast-forward only when its own checkout is safe to advance, plus a gentle re-read nudge when it changed.
  It is never torn down, interrupted, or forced.
