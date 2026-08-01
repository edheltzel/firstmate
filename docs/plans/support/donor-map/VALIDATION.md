# Adversarial validation of four load-bearing donor-map claims

Method: refute-first. Every verdict below rests on code I opened in this working tree
(`6048b1a`), plus executed probes where behavior was cheaper to run than to argue about.
Reports 00-06 were not treated as evidence.

Summary:

| Claim | Verdict | One-line result |
| --- | --- | --- |
| C1 keyed-decision eviction | **CONFIRMED** (and worse than reported) | Eviction is real; a second hazard sits downstream in `fm-decision-hold.sh` |
| C2 lock-refused mode unenforced | **CONFIRMED** (count corrected) | 3 files, 4 line-sites; the three named mutators contain zero lock references |
| C3 OMP read-only is permanent | **SPLIT: CONFIRMED it never self-clears without a code change; REFUTED that any durable artifact is involved** | No recovery path exists in-session, but there is nothing to clean up |
| C4 teardown ladder is complete | **REFUTED** | `scout` and `secondmate` bypass the whole ladder with no `--force` |

---

## C1 - keyed decisions: only the secondmate charter teaches opening, so ordinary decisions collide on `default`

**Verdict: CONFIRMED.** I could not refute it, and the failure surface is larger than report 04 states.

### Brief side

- `bin/fm-brief.sh:177` (secondmate charter) is the only place that teaches opening with a key:
  "open it with `working [key=<work-slug>]: {material phase}`, and use the same key on its later
  `paused`, `done`, `failed`, `needs-decision`, or `blocked` event".
- `bin/fm-brief.sh:405` (ship rule 6) and `bin/fm-brief.sh:283` (scout rule 6) tell the worker to
  append a bare `needs-decision: {summary of options}` with no key token.
- Both then say, at `bin/fm-brief.sh:406` and `:284`, to close with
  "`resolved: {...}` (add the same `[key=<slug>]` if you opened it with one)".
  The conditional is unreachable for an ordinary worker: nothing in either brief ever teaches
  opening with one, so "if you opened it with one" is always false.

So the premise holds exactly as stated.

### Fold side - eviction is real

- `bin/fm-classify-lib.sh:186` - `_fm_decision_key` returns the literal `default` when no
  `[key=...]` token is present.
- `bin/fm-classify-lib.sh:221-226` - on `needs-decision|blocked`, the fold calls
  `_fm_decision_drop "$open" "$key"` **before** appending the new record. Same key in, prior record out.

Executed against the real library:

```
input:  working: started
        needs-decision: A - which API shape?
        working: continuing on something else
        needs-decision: B - delete the legacy table?
open:   default <TAB> needs-decision <TAB> B - delete the legacy table?
```

Decision A is gone. Appending one bare `resolved: went with option 2` empties the set entirely
(`bin/fm-classify-lib.sh:227-230` drops the key outright), so a single answer closes both.

### What is precisely true, beyond the report's framing

Three sharpenings a port should carry:

1. The *openness* is never lost, only the *identity*. The key `default` stays open holding the
   newest record, so the task never silently reads as "no open decision" from a collision alone.
   The real hazard is the reverse: one bare `resolved:` closes a decision the captain never saw.
2. `needs-decision` and `blocked` share one key namespace (`bin/fm-classify-lib.sh:221`), so a
   blocker overwrites a pending decision and vice versa. Verified:
   `needs-decision: A` then `blocked: B` yields `default <TAB> blocked <TAB> B`.
3. **Downstream, ordinary workers lose the fold entirely.** `bin/fm-decision-hold.sh:143-158`
   wraps the fold in `origin_open_decisions`, and at `:150-156` - for any `kind` other than
   `secondmate` - it returns empty when the *last* status line's verb is `done` or `failed`.
   That is the exact last-event-wins masking `status_open_decisions` was written to prevent
   (`bin/fm-classify-lib.sh:144-152`), reinstated for ship and scout only. Since every scout is
   told to end on `done:` (`bin/fm-brief.sh:295`), the status-fold half of the teardown gate at
   `bin/fm-teardown.sh:1136` is inert by construction for scouts; the gate then rests entirely on
   the agent's own attestation recorded in meta (`bin/fm-decision-hold.sh:311-318`, `:358-366`).
   The gate is not vacuous, but its automatic half is.

Port implication: fixing only the brief vocabulary leaves hazard 3 in place.

---

## C2 - lock-refused read-only mode has zero code enforcement

**Verdict: CONFIRMED.** I could not refute it. One count in report 03 needs correcting.

Every reader of the session lock `state/.lock`, after excluding `.watch.lock`, `.spawn-<id>.lock`,
`.supervise-daemon.lock`, `.watch-cycle-exits.lock`, `.afk-*.lock`, `.guard-watcher-*.lock`,
`.fm-inherited-config.lock`, `.fm-pr-identity-<id>.lock`, and git's own `index.lock` /
`packed-refs.lock`:

| File | Line | Purpose |
| --- | --- | --- |
| `bin/fm-lock.sh` | 14 | defines `LOCK="$STATE/.lock"`; acquires (`:60`) or reports status (`:45-50`) |
| `bin/fm-sessionstart-nudge.sh` | 23, 24 | suppress the session-start nudge when the lock PID is in this process's ancestry |
| `bin/fm-session-start.sh` | 313 | Pi extension check - the lock PID doubles as a same-session identity |

That is **3 files / 4 line-sites**. Report 03 line 13 says "exactly four files" and then lists three;
the file count is 3.

The three named mutators contain no reference to the lock at all. Grepping each for
`lock`, `READ_ONLY`, and `read.only`:

- `bin/fm-send.sh` - no matches.
- `bin/fm-pr-merge.sh` - no matches.
- `bin/fm-merge-local.sh` - no matches.

`bin/fm-spawn.sh` and `bin/fm-teardown.sh` do match, but neither is a session-lock check:
`fm-spawn.sh:90` and `:936` are prose in comments, and `fm-teardown.sh:103-104` sources
`fm-lock-lib.sh` purely for the git `index.lock` staleness proof (`bin/fm-lock-lib.sh:4-14`).
`bin/fm-watch-arm.sh` only touches `.watch.lock` (`:63`) and `.watch-cycle-exits.lock` (`:72`).

Enforcement scope, read directly: `READ_ONLY` is a plain shell variable set at
`bin/fm-session-start.sh:248-250` and it gates exactly three things inside that one process -
detect-only bootstrap (`:267-271`), skipping the wake drain (`:287-292`), and the `--read-only`
flag passed to the rendered supervision prose (`:321-325`, consumed at
`bin/fm-supervision-instructions.sh:118` and `:190`). `bin/fm-guard.sh:29-30` reads
`FM_GUARD_READ_ONLY`, but that is threaded in explicitly by session-start, never re-derived from
the lock. No process outside `fm-session-start.sh` ever learns the session is read-only.

I also checked the layer outside `bin/`, since this repo runs live PreToolUse hooks that demonstrably
gate commands (`fm-cd-pretool-check.sh` blocked a `cd` during this validation). If any hook config
shelled out to `fm-lock.sh status` before a mutating tool, C2 would be refuted by enforcement living
outside the scripts. It does not:
`grep -rn 'fm-lock\|state/\.lock' .claude/ .pi/ .opencode/ .github/ .agents/skills/` returns nothing.
The two policy hooks that do exist (`bin/fm-cd-command-policy.mjs`, `bin/fm-arm-command-policy.mjs`)
enforce cwd and watcher-arm discipline, not lock ownership.

So the claim stands: read-only is a printed banner (`bin/fm-session-start.sh:251-262`) plus prose
the model is asked to obey. Two live sessions are prevented from racing bootstrap's mutating
sweeps and the wake drain, and nothing else.

---

## C3 - OMP session fails `harness_pid` and degrades to read-only PERMANENTLY

**Verdict: SPLIT. CONFIRMED that an OMP session is read-only for its entire life with no recovery
path, and that every subsequent session repeats it. REFUTED that any durable artifact is involved.**

Report 03 line 19 states it as "every session on that harness degrades to read-only forever" and says
nothing about a latch or a cleanup step. On that plain reading - "does not self-clear; no recovery
without changing code" - the claim holds, and my attempt to break it failed. What I *can* refute is the
stronger reading that some artifact gets written and must be removed before recovery: nothing is
written, and the fix needs no cleanup.

Mechanism, confirmed:

- `bin/fm-lock.sh:18` - `HARNESS_RE='claude|codex|opencode|grok|^pi$'`. No `omp`.
- `bin/fm-lock.sh:20-36` - `harness_pid` walks at most 8 ancestors matching `basename $comm`, or
  `args` for bare `node`/`python` (`:29-31`), and returns 1 when nothing matches.
- `bin/fm-lock.sh:52` - on that failure the script prints
  `error: cannot locate harness process in ancestry` and exits 1.
- `bin/fm-session-start.sh:245-250` - any non-zero exit sets `READ_ONLY=1`.

### The confirming half - no recovery path

I looked for one and found none.

- No env override exists. `harness_pid` reads only `ps` output and the hardcoded regex; there is no
  `FM_HARNESS`-style escape hatch anywhere in `bin/fm-lock.sh`.
- Pre-writing the lock file does not help. `bin/fm-lock.sh:52` runs `harness_pid` and exits **before**
  the lock file is even read at `:53`, so a hand-seeded `state/.lock` is never consulted.
- `FM_ROOT_OVERRIDE` / `FM_STATE_OVERRIDE` only relocate the lock path (`:11-14`); they do not touch
  detection.
- The ancestry walk (`:22-34`) can only succeed by accident - if some ancestor within 8 hops happens to
  match, e.g. an OMP session launched from inside a Claude or Codex session. Not a recovery path.

So the only fix is editing `HARNESS_RE` at `bin/fm-lock.sh:18`. Until then the degradation repeats on
every session start, deterministically, forever.

### The refuted half - nothing durable is involved

1. **Nothing is written.** `bin/fm-lock.sh:52` exits before the lock file is written at `:60`.
   No file, no marker, no state to clear.
2. **`READ_ONLY` is a shell variable** (`bin/fm-session-start.sh:248`) living for the lifetime of one
   `fm-session-start.sh` process. It is recomputed from zero on every run.
3. Consequence for a porter: this is a **one-line vocabulary fix with no migration or cleanup step**.
   Do not budget for un-latching anything.

Two further corrections a port should not inherit:

- **The banner lies on this path.** `bin/fm-session-start.sh:254` prints
  "ANOTHER LIVE FIRSTMATE SESSION HOLDS THE FLEET LOCK", which is false when the cause is
  harness-detection failure. `fm-lock.sh` distinguishes the two cases (`:52` vs `:56`) but
  `fm-session-start.sh:246` collapses both to `LOCK_RC != 0`. The real text does still reach the
  operator, echoed via `LOCK_OUT` at `:247` and `:255`.
- **The blast radius is smaller than "read-only" implies**, because of C2: nothing enforces it.
  An OMP-hosted session can still spawn, steer, and merge. The concrete losses are the skipped
  mutating bootstrap sweeps (`:267-271`) and a wake queue that is never drained (`:287-292`).

At the time of this validation, `omp` was unsupported rather than accidentally omitted.
That historical state was superseded by the standard adapter verification recorded in
`data/decisions/2026-08-01-omp-standard-integration.md`; current OMP facts are owned by
`.agents/skills/harness-adapters/SKILL.md`.

---

## C4 - no path reclaims a worktree with unlanded work except explicit `--force`

**Verdict: REFUTED.** Two first-class paths bypass the entire ladder without `--force`, both from
the same three lines, plus one narrower exemption inside the ship path.

### The bypass

`bin/fm-teardown.sh:723-729`:

```
validate_worktree_teardown_safety() {
  [ -d "$WT" ] || return 0
  [ "$FORCE" != "--force" ] || return 0
  case "$KIND" in
    secondmate|scout) return 0 ;;
  esac
```

Everything below it - the uncommitted check (`:731-739`), the not-on-a-remote check (`:741-749`),
the local-only unmerged check (`:751-768`), and `work_is_landed` (`:774-785`, `:457-476`) - is
skipped outright for `scout` and `secondmate`.

### Path 1 - scout (`kind=scout`)

The only non-force gates are at `bin/fm-teardown.sh:1129-1142`: `data/<id>/report.md` must exist
(`:1131`) and `fm-decision-hold.sh verify` must pass (`:1136`). Neither reads the working tree.

Destruction then proceeds at `:1185-1205`: `git checkout --detach` and `git branch -D` (`:1188-1190`),
then `teardown_treehouse_return` (`:1202`), which kills processes in the worktree, hard-resets it, and
returns it to the pool. The post-lock re-check is explicitly withheld from scouts at `:1199`
(`[ "$KIND" != scout ]`), so nothing re-inspects.

Net: a scout worktree holding uncommitted changes *and* unpushed commits is reclaimed with no
`--force`. This is deliberate and documented at `bin/fm-teardown.sh:28-31` ("declared scratch") and in
`AGENTS.md` section 1 rule 3 - but it directly falsifies C4 as written.

### Path 2 - secondmate (`kind=secondmate`)

The only non-force gate is `bin/fm-teardown.sh:1113-1123`, which refuses if any `*.meta` exists in the
child home's `state/`. That is an in-flight-crew check, not a working-tree check.
`validate_firstmate_home_for_removal` (`:945-974`) validates the *shape* of the removal target - the
`.fm-secondmate-home` marker, the id match, operational dirs, no registered descendant home - and never
runs `git status`.

Removal then happens at `:1266-1270` via `remove_firstmate_home`, which either returns the treehouse
lease (`:987`) or `safe_rm_rf`s the directory (`:993`).

Net: a quiesced secondmate home whose own worktree holds uncommitted edits is removed with no
`--force`. The header at `:48-54` describes `--force` as the discard path for *child* work only, which
is consistent with the code and inconsistent with C4.

### Path 3 - narrower, inside the ship path

`bin/fm-teardown.sh:739` filters the dirty test:

```
dirty=$(printf '%s\n' "$dirty_raw" | grep -vE '^\?\? (\.claude/|\.fm-grok-turnend$)' | head -1 || true)
```

Because `git status --porcelain` collapses an untracked directory to a single entry, this exempts
*everything* under `.claude/`, at any depth. Verified on a scratch repo: two untracked files under
`.claude/` produce exactly `?? .claude/`, which the filter removes, leaving the worktree classified
clean. Anything a worker wrote there is discarded without `--force`.

Relatedly, `:731` calls `git status --porcelain` without `--ignored`, so gitignored paths are never
dirt. That is inherent to the "landed" definition rather than a hole, but a port should state it.

### What is true instead

The ladder is complete **only for `kind=ship`**. Within ship it is genuinely strong: dirty refuses
(`:769-773`), unpushed requires `work_is_landed` (`:774-785`), `content_in_default` returns non-zero when
inconclusive so the caller refuses rather than guesses (`:432-433`, `:449`), a broken PR identity binding
disables the content fallback entirely (`:470-473`), and an uninspectable index refuses instead of
proceeding (`:735-737`, `:745-747`). `--force` is the only bypass *within* ship. The claim overreaches by
generalizing that to all worktrees.

---

## Notes on what I could not refute

C1, C2, and C3's substantive half survived the attack.

For C1 I looked for a preserving mechanism (a second consumer reading the raw status stream, a backlog
mirror, an append-only recovery path) and found the opposite - the downstream consumer at
`bin/fm-decision-hold.sh:150-156` weakens it further for exactly the ship and scout tasks C1 is about.

For C2 I searched for indirect enforcement (a wrapper, a sourced guard, an env var derived from the
lock, a harness hook) and found none; `READ_ONLY` never leaves `fm-session-start.sh` except as a
rendering flag.

For C3 I searched specifically for a recovery path and found none, so the operationally meaningful half
of that claim is confirmed. My refutation there is narrow and should be read as narrow: it corrects the
*shape* of the problem (no latch, no cleanup) without softening the *severity*.

Only C4 broke, and it broke cleanly on `bin/fm-teardown.sh:727-729`.
