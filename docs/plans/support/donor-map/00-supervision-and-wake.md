# Heartbeat and check-in dissection: firstmate -> Themis persona

Date: 2026-07-25
Subject repo: `/Users/ed/Developer/Atlas/Themis` (fork of `kunchenguid/firstmate`)
Target: `/Users/ed/.claude/commands/Themis.md` (the persona contract)
Status: analysis only, nothing edited

---

## 0. Two premise corrections before anything else

**The fork already exists.** `/Users/ed/Developer/Atlas/Themis` has `origin = edheltzel/firstmate`, `upstream = kunchenguid/firstmate` (push DISABLED), and real divergence: `fm/atlas-key-pr-identity-redteam-k6`, `local/pre-upstream-reconnect-20260718`, and the Atlas PR-broker commit series on `main`. There is no fork decision left to make. The open question is what to keep in it.

**The rename never reached the contract.** `CLAUDE.md` is a symlink to `AGENTS.md`, and that file still opens with "You are the first mate. The user is the captain." The repo is called Themis; the persona inside it is still Firstmate. These are two different artifacts and it matters here, because there are two "Themis" things in play:

| Artifact | Path | Role here |
|---|---|---|
| Themis **repo** | `/Users/ed/Developer/Atlas/Themis` | the **donor** - 10k+ lines of supervision machinery |
| Themis **persona** | `/Users/ed/.claude/commands/Themis.md` | the **target** - what you want to integrate into |

The persona exists in **three hand-maintained copies**, not one source with generated mirrors (no generator, no "derived from" marker in any of them):

| Copy | Path | Enforcement |
|---|---|---|
| Claude Code | `~/.claude/commands/Themis.md` | prose only |
| Pi | `Config/packages/pi-themis/` (`extensions/themis.ts` + `skills/themis-pm/SKILL.md`) | **real runtime guards** |
| OMP | `Config/packages/omp-themis/` (`src/main.ts` + `skills/themis-pm/SKILL.md`) | runtime guards |

Anything added below lands in three places until someone builds a generator. That is a cost worth naming up front.

**The gap this analysis is actually filling.** Persona line 47 already says: *"Themis will do a heartbeat check-in for each agent to prevent stales, if the agent has completed its role, Themis will then terminate the agent and its herdr."* That is a promise with no mechanism behind it. Today there is no beacon, no queue, no guard, and no turn-end backstop, so Themis can end a turn with N agents in flight and nothing will ever wake her. That is the hole.

---

## 1. The machinery splits in two, and they are genuinely different

Firstmate solves two problems people usually conflate:

- **(A) Is each worker still alive and doing something?** Classification, staleness, escalation.
- **(B) Is my own supervision loop still running at all?** Liveness of the supervisor itself.

Half B is the more novel piece and the more portable one. Most write-ups skip it. It is also the half Themis is missing entirely.

### A stated judgment: "check-in" here means inbound, not outbound

Persona line 47 reads as an outbound ping - Themis pokes each agent to ask if it is alive. Firstmate does the opposite, and I think firstmate is right: **liveness is inbound-only**. Workers emit status; the supervisor detects and classifies. Nothing is ever polled by messaging it.

The reason is §2's absorb rule. Prompting a working agent to ask whether it is working costs it a turn, pollutes its context, and produces exactly the noise the absorb machinery exists to suppress. Firstmate does keep an outbound leg, but it is for **direction, not liveness**: `bin/fm-send.sh` steers a worker with short single-line messages (herdr equivalent: `agent prompt` / `agent send-keys`). Steering and sensing are separate channels.

So the recommendation below reinterprets line 47 rather than implementing it literally. Flagging that as a judgment call, not a silent substitution.

---

## 2. Part A: tracking the other agents

### A1. Status files are append-only event logs, never current state

`state/<id>.status` holds lines shaped `<verb>[key=<slug>]: <note>`.

The reasoning is in `bin/fm-crew-state.sh:4-13`: crews append only wake-worthy transitions and append **nothing** when they silently resume. So `tail -1` of that log reports the last *event*, not the current *state*. After a decision is resolved and the worker resumes, the log's last line stays stale forever.

Verb vocabulary (`bin/fm-classify-lib.sh:45,58,73-74`):

| Verb | Meaning | Class |
|---|---|---|
| `working:` | progress note | non-terminal, no-verb path |
| `paused:` | declared wait on a **known external** dependency | absorbed on a long cadence |
| `blocked:` | stuck, supervisor action needed | captain-relevant |
| `needs-decision:` | gate finding awaiting a call | captain-relevant |
| `done:` / `failed:` | terminal | captain-relevant |
| `resolved:` / `captain-held:` | closes a keyed decision | non-terminal |

The `paused:` vs `blocked:` split is the sharpest idea in the vocabulary: an idle pane that declared a pause is *expected* to be idle, so it is not a wedge suspect. But it still re-surfaces once every `FM_PAUSE_RESURFACE_SECS` (3600s default) so a forgotten pause cannot rot invisibly.

### A2. A separate, cheap, deterministic current-state oracle

`bin/fm-crew-state.sh <id>` emits exactly one parseable line:

```
state: <working|parked|done|blocked|paused|failed|unknown> · source: <run-step|pane|status-log|none> · <detail>
```

Precedence (header, lines 21-48): an attributed validation run-step wins, then the pane busy signal, then the status log, then `unknown`. Attribution requires branch **and** code identity to match, so a historical run on a reused branch cannot be credited to current work.

The rule that makes it trustworthy: a dead endpoint with no attributed run reports `unknown`, never "trust the stale log." No heuristics, no LLM anywhere in the path.

### A3. Keyed decision folding

`status_open_decisions` (`bin/fm-classify-lib.sh:210-234`) folds the *whole* log into the set of decisions still open. `needs-decision`/`blocked` opens a key; only `resolved`/`captain-held` carrying that key closes it. A bare line uses key `default`.

This fixes a real failure: read last-event-wins, and a later unrelated `done:` silently masks a still-open decision. Roughly 40 lines of pure logic, no dependencies.

**Correction, from assignment 04.** The library is sound but the mechanism is unreachable in practice for the task kinds that matter. Only the secondmate charter teaches a worker to *open* a keyed decision; the ship and scout briefs instruct only the closing half. So every ordinary worker's `needs-decision:` lands on key `default`, and a second open decision silently evicts the first from the open set. The masking this fold exists to prevent still happens, for the two task kinds that generate almost all decisions. Port the fold and the brief together, or the fold is decoration.

### A4. Absorb-only-when-provably-working

The core anti-noise rule, and simultaneously the anti-miss rule (`bin/fm-classify-lib.sh:318-357`). A no-verb signal or a stale pane is absorbed **only** on positive evidence the crew is still working. Absent that evidence it surfaces. The default is to wake, not to suppress.

Escalation ladder for a stale pane:

1. first sighting -> surface once
2. provably working -> absorb, but start a wedge timer
3. past `FM_STALE_ESCALATE_SECS` (240s) -> surface with an escalation count
4. at `FM_WEDGE_DEMAND_INSPECT_COUNT` -> add a `demand-deep-inspection` marker to the wake payload, so repetition alone cannot be shrugged off as routine

### A5. Wake vocabulary and heartbeat backoff

Four wake kinds: `signal:`, `stale:`, `check:`, `heartbeat`.

The `heartbeat` backstop is a full-fleet rescan with exponential backoff: base 600s, `base * 2^streak`, capped at 7200s, and **reset to base on any real wake** (`bin/fm-watch.sh:107-108, 1112-1115`). An idle fleet decays to a 2-hour poll; a busy one stays responsive.

---

## 3. Part B: keeping its own session alive

This is the half worth stealing wholesale.

| # | Mechanism | Where | What it does |
|---|---|---|---|
| B1 | **Liveness beacon** | `fm-watch.sh:811` | `touch state/.last-watcher-beat` every poll cycle, including while absorbing benign wakes |
| B2 | **The predicate** | `fm-supervision-lib.sh` (65 lines, entire file) | unhealthy == in-flight work exists **AND** no beacon within grace (300s default) |
| B3 | **Pull guard** | `fm-guard.sh` | warns whenever any other fleet command happens to run |
| B4 | **Push guard** | `fm-turnend-guard.sh` | harness Stop hook, exit 2 + stderr banner blocks the turn from ending blind |
| B5 | **Verified arm** | `fm-watch-arm.sh` | forks the watcher, then confirms process alive **and** beacon fresh before reporting success |
| B6 | **Singleton + self-eviction** | `fm-watch.sh:805-807` | every cycle, if the lock no longer names this pid, stand down so the rightful singleton continues alone |
| B7 | **Durable queue** | `state/.wake-queue` | actionable wakes written **before** detector state advances, so a missed process exit is recoverable |

Three details in this half are worth more than the code around them:

**Honest status vocabulary.** The arm wrapper prints exactly one of `started pid=N (beacon fresh)`, `attached pid=N (beacon <age>s)`, or `FAILED - <reason>`, and exits non-zero on failure. It never reports healthy off a stale beacon or a dead/reused pid (`fm-watch-arm.sh:20-40`). A supervisor that lies about its own health is worse than no supervisor.

**The background-task rule, learned the hard way.** From `fm-watch-arm.sh:11-14`: never fire the watcher with a shell `&` inside another call, because that backgrounded child is reaped when the call returns, leaving no watcher running and a false "already running" reading off the dying process. The comment records that this exact mistake silently took supervision down for about 30 minutes. The fix is that the **harness's own tracked background task is the arm mechanism**, and its completion is the wake. `docs/supervision-protocols/claude.md` states it plainly: *"Claude Code's background task completion is the wake mechanism."*

**Loop-guarded blocking.** The Stop hook checks `stop_hook_active` and always allows the stop when the current attempt was already forced this turn (`fm-turnend-guard.sh:29-37, 63-64`). At most one forced continuation per turn, so the session can never wedge un-endable, while still nagging again next turn if the problem persists.

There is also a PreToolUse seatbelt (`fm-arm-pretool-check.sh`) that denies backgrounding, piping, or bundling the arm command, and a hard rule against `pkill -f bin/fm-watch.sh` because that pattern matches every sibling home's watcher.

---

## 4. Part C: what the multiplexer layer actually costs

I tested the assumption rather than accepting it.

**`fm_backend_busy_state` (`bin/fm-backend.sh:614-622`) has exactly one real implementation.** herdr. Every other backend returns the literal string `unknown`:

```bash
case "$backend" in
  herdr) fm_backend_herdr_busy_state "$@" ;;
  *) printf 'unknown' ;;
esac
```

That `unknown` is the cue that forces the pane-tail regex path (`fm-watch.sh:119`):

```
FM_BUSY_REGEX = 'esc (to )?interrupt|Working\.\.\.|Ctrl\+c:cancel'
```

So the screen-scraping regex, the pane-hash change detection, the `.hash-*`/`.count-*`/`.seen-*` marker files, the composer-emptiness classifier, and the submit-retry core all exist to compensate for backends that cannot answer "is this agent working." That compensation layer **is** the complexity you are reacting to. Drop the non-herdr backends and it becomes dead weight, not load-bearing structure.

**One correction to the obvious worry.** Dropping tmux does *not* cost you the verified agent-liveness classifier. herdr has its own (`fm_backend_agent_alive` dispatch at `bin/fm-backend.sh:721-729` routes to `fm_backend_herdr_agent_alive`, documented under "Agent liveness probe reuses the husk classifier"). Same for composer state (`:642`). The strip is clean: tmux is the *reference* implementation, not the *only* one.

---

## 5. Part D: herdr already does the hard part natively

Verified live against herdr 0.7.5-preview just now, read-only:

**Whole-fleet state in one call.** `herdr agent list` returns JSON per agent with `agent_status` (`idle|working|blocked|done|unknown`), `pane_id`, `tab_id`, `workspace_id`, and a monotonic `state_change_seq`. Firstmate-spawned panes even carry `tokens: {fm_harness, fm_project, fm_task}`.

**A native blocking wait.** `herdr agent wait <target> --until blocked --until done --until idle --timeout <ms>`:

| Outcome | Exit | Stdout |
|---|---|---|
| matched | `0` | full matched-agent JSON |
| timed out | `1` | `{"error":{"code":"timeout","message":"timed out waiting for agent status"}}` |

Honest exit codes, no parsing needed to branch.

**What this collapses.** For a herdr-only Themis:

- `fm-watch.sh` (1144 lines of poll loop) -> `herdr agent wait` run as a Claude Code background Bash task
- `fm-watch-arm.sh` (489 lines) -> mostly unnecessary; the harness already tracks the background task and re-invokes on completion, which is the entire arm contract
- `.hash-*` / `.count-*` / `.seen-*` marker machinery -> `state_change_seq`

**The background-task path is verified, not assumed.** This matters because §3 quotes the incident where exactly this class of assumption silently killed supervision for 30 minutes, so I tested it rather than reasoning about it. I started `herdr agent wait w34:p2 --until working --timeout 75000` as a tracked background Bash task in Claude Code, kept working through several unrelated turns, and the harness delivered a completion notification mid-turn carrying exit code 1 and the structured timeout JSON. The process survived across turns, was tracked by the harness rather than reaped, and its exit re-invoked the session.

That is the entire `fm-watch-arm.sh` contract - fork, survive, notify on exit - already provided by the harness plus the herdr CLI, with no bash watcher, no beacon file, and no lock.

**The one honest constraint.** `agent wait` takes a single `<TARGET>`. Firstmate ran one watcher over the whole fleet; Themis would need either N concurrent background waits (one per dispatched agent) or a cadenced `agent list` poll. With the persona's 2x2-grid-per-tab cap the agent count stays small, so N background waits is viable, but this is the one real design decision the port has to make rather than inherit.

---

## 6. What Themis already has

You asked what we already do this way. I read all three persona copies. Summary: **the persona layer is well built, the supervision layer does not exist.**

`pi-themis/extensions/themis.ts` (263 lines) is the most developed copy and already implements real enforcement that the Claude Code prose version only asks for:

| Capability | Where | Note |
|---|---|---|
| Persona injection per turn | `themis.ts:231-234` (`before_agent_start`) | appends the contract to the system prompt |
| **"Never program" as a hard guard** | `themis.ts:236-256` (`tool_call`) | blocks `write`/`edit` outside `.md`/`.agents/**`; blocks git mutation, dependency changes, `rm -rf`, in-place sed/perl one-liners |
| Session-persistent state | `themis.ts:146-148, 222-229` | survives restart via `appendEntry` |
| Voice status | `themis.ts:125-141` | Echo on :8888 |
| **Per-turn status shape** | `themis.ts:85-91` | `Phase / Completed / In flight / Blocked / Next` |
| `GH#<issue>-<role>` tab labels | all three copies | already mandatory |

Two observations that change the recommendations:

**1. The status vocabulary already exists, but points the wrong way.** `Phase / Completed / In flight / Blocked / Next` is Themis reporting upward to Ed. What is missing is the same discipline pointing *inward*: workers reporting to Themis. C1/C2 below are not a new invention, they are the existing shape turned around. The `In flight` and `Blocked` fields map almost directly onto firstmate's `working:` and `blocked:`.

**2. There is already a turn-end hook, and it does not guard anything.** `themis.ts:258-262` registers `agent_end`, but it only speaks a status line. That is precisely where C6 belongs on Pi, and it means the turn-end guard is an **extension to existing code**, not new plumbing. Claude Code has no equivalent today and would need a Stop hook in settings.

What is absent everywhere: any wake mechanism, any liveness beacon, any in-flight registry, any staleness classification, and any check before terminating an agent.

---

## 7. Copy / strip / rebuild

### COPY - high value, low coupling

| # | Mechanism | Why | Already have? |
|---|---|---|---|
| C1 | **Append-only event log + separate current-state reader** | the single idea that makes the whole thing restart-proof | **partial** - status shape exists, points outward not inward (§6) |
| C2 | **Status verb vocabulary** incl. the `paused:` vs `blocked:` split | distinguishes "expected idle" from "wedged" | **partial** - `In flight`/`Blocked` already map onto `working:`/`blocked:` |
| C3 | **Keyed decision fold** (`[key=slug]`) | stops a later `done:` masking an open decision | absent; ~40 lines, no dependencies |
| C4 | **Absorb-only-when-provably-working** | default-to-wake, not default-to-suppress | absent; needs C1's oracle, which herdr supplies free |
| C5 | **Self-liveness predicate** (in-flight work + stale beacon) | 65 lines, the whole of half B's contract | absent |
| C6 | **Turn-end guard with loop-guard** | the only thing that stops a blind turn-end | **hook point exists** on Pi (`agent_end`, `themis.ts:258`), guards nothing; Claude Code needs a new Stop hook |
| C7 | **Honest arm vocabulary** (`started`/`attached`/`FAILED`, never healthy off a stale beacon) | a lying supervisor is worse than none | absent; a discipline, not code |
| C8 | **Heartbeat exponential backoff with reset on real wake** | idle fleets go quiet, busy ones stay sharp | absent |
| C9 | **Durable queue written before state advances** | survives a missed process exit | absent |
| C10 | **Scoped kill only, never `pkill -f`** | directly relevant: persona line 47 has Themis terminating agents | absent, and currently unguarded |

### STRIP

| # | Component | Note |
|---|---|---|
| S1 | tmux / zellij / orca / cmux adapters | ~1450 lines across adapters plus their docs |
| S2 | `FM_BUSY_REGEX` pane-tail scraping and pane-hash markers | dead once herdr's native state is the only source (see §4) |
| S3 | Shared 4-backend composer/submit-retry abstraction | keep only herdr's own branch |
| S4 | X mode | entire Twitter/relay layer, `fm-x-*.sh`, inbox/outbox/context state |
| S5 | Secondmate homes and cross-home projection | Themis has no isolated-home model |
| S6 | `captain`/`first mate`/`crewmate` vocabulary | replace with Ed / Themis / worker-reviewer-explorer |
| S7 | AFK daemon (`fm-supervise-daemon.sh`, 1509 lines) | optional, defer; only needed if you want walk-away supervision later |

### REBUILD - needs new design, do not port

| # | Thing | Firstmate's version | Themis needs |
|---|---|---|---|
| R1 | The watcher | 1144-line bash poll loop | `herdr agent wait` per agent as a background Bash task (**mechanism verified**, §5). On Pi this extends `themis.ts`; on Claude Code it is a background Bash call |
| R2 | ~~Current-state authority~~ | ~~no-mistakes run-step attribution~~ | **REVERSED 2026-07-25 - see correction below** |
| R3 | Task registry | `state/<id>.meta` + treehouse worktrees | GH issue number + the persona's existing `GH#<issue>-<role>` tab label |
| R4 | Termination gate | fail-closed teardown, refuses on unlanded work (AGENTS.md hard rule 3) | **must be rebuilt before line 47's "terminate the agent" is safe** |

R4 is the one I would not ship without. The persona currently authorizes terminating a completed agent and its herdr tab with no equivalent of firstmate's unlanded-work refusal. That will eventually destroy work.

### Correction: R2 reverses to COPY once no-mistakes is kept

I originally marked the no-mistakes run-step oracle as REBUILD, reasoning that Themis workers use `/ce-work` and `pr-review-toolkit` rather than no-mistakes. Ed has since confirmed no-mistakes stays in. That flips the verdict, and it changes the design rather than just a table cell.

The two sources answer **different questions**:

| Source | Answers | Blind to |
|---|---|---|
| herdr `agent_status` | is the agent *process* busy right now | whether the work is any good |
| no-mistakes run-step | is the *work* validated, parked on a gate, or failed | whether the agent is alive |

Firstmate makes the run-step authoritative and the pane signal the fallback (`fm-crew-state.sh:21-48`), and that ordering is correct: a pane sitting idle while CI is green is `done`, not `stale`, and a busy pane during a failed run is not progress.

What makes this the most copyable single function in the repo is the attribution rule, which is subtler than it looks (`fm-crew-state.sh:415-450`). A run is credited to a crew only when the run head equals the worktree HEAD, or the worktree HEAD is an **ancestor** of the run head (pipeline fix commits legitimately advanced the run). Local work that moved past the run head, or a rewritten/diverged branch tip, invalidates attribution. Branch name alone is explicitly not enough, because a reused branch would inherit a stale historical run.

There is one more wrinkle worth copying verbatim: during the `ci` step, `axi status` cannot distinguish "still waiting on checks" from "checks green, waiting on merge" - both report `ci,running`. Firstmate reads the ci step log tail to break the tie (`nm_ci_checks_state`, `:335`), so a green PR is never misread as still-validating.

**Revised layering for our version:** no-mistakes run-step first (authoritative), herdr `agent_status` second (replacing the pane-tail regex, which is a strict upgrade), status log third, `unknown` last. That keeps §4's strip intact while restoring the part of the oracle that actually carries the validation semantics.

---

## 8. Recommended minimum viable slice

If you want the smallest thing that closes the actual hole:

1. **C1 + C2** - workers append `<verb>: <note>` status lines to a known path. Convention only, no code. Reuse the vocabulary already in the per-turn status block rather than inventing a second one.
2. **R1** - on each dispatch, start `herdr agent wait <pane> --until blocked --until done --until idle` as a background task. Its completion is the wake. Verified working (§5).
3. **C4** - on wake, read `herdr agent get <pane>`; surface unless it reports `working`.
4. **C5 + C6** - a turn-end guard that refuses to end the turn when dispatched agents exist and no wait task is live. On Pi, extend the existing `agent_end` handler; on Claude Code, add a Stop hook.
5. **R4** - before terminating any agent, verify its work landed.

No bash watcher, no beacon file, no lock, no queue. Steps 2 and 4 give you half B; steps 1 and 3 give you half A. C3, C8, C9, C10 are worth adding second.

Cost note: steps 1, 3, and 5 are prose and land in three files (§0). Steps 2 and 4 are code and land in `themis.ts`, the OMP equivalent, and Claude Code settings. A generator for the persona text would pay for itself here.

---

## 9. Evidence index

- `bin/fm-classify-lib.sh` - verb vocabulary, keyed decision fold, provably-working predicate
- `bin/fm-crew-state.sh:1-51` - current-state oracle contract and precedence
- `bin/fm-supervision-lib.sh` - the entire self-liveness predicate, 65 lines
- `bin/fm-watch.sh:107-119, 746-830, 1110-1143` - cadence constants, singleton, beacon, backoff
- `bin/fm-watch-arm.sh:1-75` - verified arm contract and the shell-`&` incident note
- `bin/fm-turnend-guard.sh` - push guard and loop-guard
- `bin/fm-backend.sh:604-729` - busy-state, composer, target-exists, agent-alive dispatch
- `bin/fm-transition-lib.sh:70-103` - single-owner status -> action policy table
- `docs/architecture.md:9-104` - the prose contract for all of the above
- `docs/supervision-protocols/claude.md` - the Claude background-task wake protocol

Persona side:

- `~/.claude/commands/Themis.md` - the Claude Code persona; line 47 is the unbacked promise
- `Config/packages/pi-themis/extensions/themis.ts` - the only copy with real runtime enforcement
- `Config/packages/{pi,omp}-themis/skills/themis-pm/SKILL.md` - the two skill mirrors

Live probes against herdr 0.7.5-preview, 2026-07-25:

- `herdr agent list` - whole-fleet JSON with `agent_status` and `state_change_seq`
- `herdr agent wait <t> --until <s> --timeout <ms>` - exit 0 on match with agent JSON, exit 1 on timeout with error JSON
- the same command as a tracked Claude Code background task - survived across turns, notified on exit
