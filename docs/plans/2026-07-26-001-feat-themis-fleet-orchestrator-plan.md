---
title: Themis Fleet Orchestrator - Plan
type: feat
date: 2026-07-26
topic: themis-fleet-orchestrator
artifact_contract: ce-unified-plan/v1
artifact_readiness: requirements-only
product_contract_source: ce-brainstorm
execution: code
---

# Themis Fleet Orchestrator - Plan

## Goal Capsule

- **Objective:** A new repository holding a herdr-only agent fleet orchestrator operated by the Themis persona, ported from firstmate and stripped during the port. treehouse and no-mistakes stay as external CLI dependencies.
- **Product authority:** Ed. Merge, destructive, and irreversible decisions never delegate.
- **Open blockers:** None. The bridge is Pi and the discovery campaign is approved to run in three waves of three.

---

## Product Contract

### Summary

Build a fleet orchestrator that dispatches workers, reviewers, and explorers into herdr panes, supervises them without polling screen output, and refuses to lose work. The existing `edheltzel/firstmate` fork stays checked out beside it as a read-only donor. A discovery campaign maps the donor subsystem by subsystem first, so the port is driven by evidence rather than by one deeply-read subsystem.

### Problem Frame

Firstmate solves fleet supervision well and carries a large amount of machinery that exists for reasons that no longer apply here. Roughly half its backend surface compensates for terminal multiplexers that cannot answer whether an agent is working: `fm_backend_busy_state` has exactly one real implementation, and every other backend returns `unknown`, which forces a pane-tail regex scraper, pane-hash markers, and a composer/submit-retry layer beneath it. herdr answers that question natively, so the compensation layer is dead weight rather than structure.

The supervision half is the opposite. It is subtle, correct, and hard-won: status files as append-only event logs with a separate deterministic current-state reader, absorb-only-when-provably-working triage, a liveness beacon with a turn-end guard, and validation-run attribution by branch and code identity. That work is worth porting almost verbatim.

The Themis persona today promises heartbeat check-ins for each dispatched agent and has no mechanism behind the promise. There is no beacon, no wake path, no in-flight registry, and no check before terminating an agent. A session can end with agents in flight and nothing will wake it.

### Key Decisions

- **Port and strip into a new repo, with the fork as a read-only donor.** (session-settled: user-directed - chosen over stripping the fork in place and over a thin join layer: stripping in place makes every deletion a permanent merge conflict, and porting the architecture reaches a running system faster than renting state from the external CLIs.)

- **Split volatile runtime state from durable knowledge.** Firstmate makes `data/`, `state/`, `config/`, and `projects/` all home-private and gitignored, which conflates two different things. Locks, liveness beacons, wake queues, and per-task metadata are genuinely volatile and stay local and ignored. Plans, scout reports, decisions, and handoffs are durable repository knowledge and are committed where a future reader finds them. This resolves the tension rather than inheriting firstmate's side of it.

- **herdr is the only session backend.** (session-settled: user-directed - chosen over retaining tmux, zellij, Orca, and cmux: the multiplexers carry no value here, and dropping them removes the compensation layer built for backends that cannot report agent state.) herdr also carries its own verified agent-liveness classifier, so dropping tmux costs no capability.

- **no-mistakes run-step is the authoritative current state, herdr agent status is second.** The two answer different questions: the run-step reports whether the work is validated, herdr reports whether the process is busy. A pane sitting idle while checks are green is finished, not stale.

- **Port enforcement, not assertions.** The campaign's dominant finding, in five independent subsystems: the donor's most important safety rules live in prose that nothing checks. Merge authority is not read by either merge wrapper. The rule that a worker owns its own validation gate responses is asserted and unenforced. Lock-refused read-only mode is a printed banner that three mutating scripts never consult. The stuck-agent recovery playbook has no enforcement and silently depends on briefs being immutable. The keyed-decision protocol teaches ordinary workers only half of itself. Each was a rule the donor's operator was expected to obey, and each held for the donor because one careful model read one careful document. That is not a property we should inherit. Every rule ported from prose must arrive as a check, a refusal, or a test, or arrive explicitly labelled as advisory.

- **Classification stays deterministic.** No model judgment in the current-state path. The attribution rules are subtle enough that re-deriving them per turn produces intermittent wrong answers, which is the worst available failure mode.

- **Pi is the cross-vendor bridge.** (session-settled: user-directed - chosen over the in-process Codex plugin and over a single-vendor campaign: Ed asked for a harness outside Claude Code, and Pi is the most developed non-Claude surface in the ecosystem.) Explorer pools mix families by routing at least one explorer per assignment group through Pi.

- **One persona source, generated mirrors.** The persona exists today in three hand-maintained copies with no generator, and they have already drifted on documentation locations. Adding a supervision contract to three copies by hand guarantees further drift.

### Actors

- A1. Ed. Sole human. Owns merges, destructive actions, irreversible actions, and anything security-sensitive.
- A2. Themis. The orchestrator. Delegates, sequences, validates, and documents. Never writes code.
- A3. Worker. Implements one task in an isolated worktree and ships through the project's delivery mode.
- A4. Reviewer. Reviews a worker's output, including a cross-vendor pass.
- A5. Explorer. Produces a report and never pushes.

### Requirements

**Fleet supervision**

- R1. Every dispatched agent has a durable record binding it to its tracked issue, herdr pane, worktree, and validation run.
- R2. Agents report state by appending event lines to a per-task log. The log is an event history and is never read as current state.
- R3. A deterministic reader reports one agent's current state, reconciling the event log against authoritative sources, with no model judgment in the path.
- R4. Current-state precedence is no-mistakes run-step, then herdr agent status, then the event log, then unknown. A dead pane with no attributed run reports unknown rather than trusting a stale log.
- R4b. Completion is judged from the artifact, never from the session layer's exit signal. A settled or `done` agent state means the turn ended, not that the work succeeded, and a reported agent failure does not mean the work did not complete. Both directions were observed on 2026-07-26: an agent reported `done` after its turn died on an API error having produced nothing, and another reported failure after writing its deliverable in full. Every completion gate reads the product.
- R4a. The herdr layer is trusted only for panes where herdr performs screen detection. For a pane reporting `screen_detection_skipped`, native status is treated as unknown and precedence falls through to the run-step and the event log. Measured 2026-07-26 on herdr 0.7.5: `claude` panes report `false`, `pi` and `omp` panes report `true`. Two of our three target harnesses, including the cross-vendor bridge, are in the skipped set, so this is the common case rather than an edge case.
- R5. A validation run is attributed to an agent only when the run head equals the worktree HEAD or the worktree HEAD is an ancestor of the run head. Branch name alone never attributes.
- R6. A stale or unclassified wake surfaces unless the agent shows positive evidence it is still working.
- R7. A declared external wait is absorbed rather than escalated, and re-surfaces on a bounded cadence so it cannot rot invisibly.
- R8. Wakes arrive by blocking on herdr's native agent state. No screen-output polling and no pane-hash comparison.
- R9. Repeated staleness on an unchanged pane escalates, and past a bound the wake itself carries a demand for deeper inspection.

**Session liveness**

- R10. Themis cannot end a turn while agents are in flight and no live wake mechanism holds the session.
- R11. Supervision status is honest: started, attached, and failed are distinguishable, and none is reported without positive evidence.
- R12. At most one forced turn continuation per turn, so a session can never become un-endable.

**Delivery and safety**

- R13. Workers run in isolated treehouse worktrees, never the primary checkout. A failed isolation assertion stops the task.
- R14. For projects configured for it, no-mistakes owns validation end to end. Themis never answers a gate on a worker's behalf.
- R15. Terminating a ship agent or reclaiming its worktree requires proof that its work landed. A refusal is a stop-and-investigate result.
- R15a. Scout and explorer work is declared scratch and is exempt from the landed-work proof, gated instead on its deliverable existing and its open decisions being resolved. The exemption is safe only because the gate inspects the product: a scout's output is the report file, so requiring the report is the equivalent proof. Any future task kind added to the exempt set must carry its own product check, never inherit the exemption bare.
- R16. Merges require Ed's explicit word, enforced in code at the merge wrapper. The wrapper reads the approval record and the check state and refuses without them; it does not rely on the operator having been told the rule. The donor's wrappers validate URL shape and identity binding and then merge, with no reference to approval, autonomy posture, or check status anywhere in either merge path.
- R17. Killing a supervision process targets one recorded process identity. Broad pattern kills are refused.

**Persona and portability**

- R18. The persona has one source of truth; the Claude Code, Pi, and OMP surfaces are generated from it.
- R19. Vocabulary is Themis-native throughout: Ed, Themis, worker, reviewer, explorer. No captain or first-mate framing anywhere, including in generated agent briefs.
- R20. Durable artifacts are committed repository knowledge. Volatile runtime state is local and ignored.

### Key Flows

- F1. Dispatch
  - **Trigger:** Ed approves a work item, or Themis selects the next unblocked item.
  - **Actors:** A2, A3
  - **Steps:** Resolve the project and delivery mode; take an isolated worktree; write the task brief; launch the agent into a labeled herdr tab; record the join between issue, pane, worktree, and task; start the wake mechanism for that pane.
  - **Covered by:** R1, R8, R13, R19

- F2. Wake and triage
  - **Trigger:** A pane transitions to a waited-for state, or the bounded wait lapses.
  - **Actors:** A2
  - **Steps:** Drain any queued wakes; read current state through the deterministic reader; absorb when the agent is provably working; surface otherwise with the concrete outcome and next decision.
  - **Covered by:** R2, R3, R4, R6, R7, R9

- F3. Land and reclaim
  - **Trigger:** An agent reports a terminal state.
  - **Actors:** A1, A2, A3
  - **Steps:** Confirm the work landed; escalate the merge decision to Ed; reclaim the worktree only after landing is proven; record completion and re-evaluate blocked work.
  - **Covered by:** R14, R15, R16

- F4. Discovery run
  - **Trigger:** Ed approves the campaign and names the cross-vendor bridge.
  - **Actors:** A2, A5
  - **Steps:** Dispatch explorers across the assignment table below; each returns a subsystem report with verified evidence and a per-mechanism verdict; Themis reconciles the reports into the port specification.
  - **Covered by:** R13, R19

### Discovery Campaign

The donor's operating contract enumerates fourteen subsystems, and `docs/` carries roughly twenty supporting files. One subsystem is already mapped. The rest group into eleven assignments.

Each report uses the same shape as the completed one: a mechanism inventory with `file:line` evidence, claims verified against the code separated from claims taken from prose, and a copy / strip / rebuild verdict per mechanism with an "already have it" column checked against the current Themis surfaces.

Assignments are sized by measured source lines so no single explorer is starved or overloaded.

| # | Assignment | Primary sources | Lines | Why it matters |
|---|---|---|---|---|
| 0 | Supervision and wake | `bin/fm-watch.sh`, `fm-classify-lib.sh`, `fm-crew-state.sh`, `fm-supervision-lib.sh` | done | Complete. See the heartbeat dissection. |
| 1 | herdr adapter | `bin/backends/herdr.sh` | 2273 | The only backend we keep. Largest single file in the donor. |
| 2 | herdr verification and gaps | `docs/herdr-backend.md` | 1288 | Records verified CLI facts, container shape, and known gaps we would otherwise rediscover. |
| 3 | Session start and bootstrap | `bin/fm-session-start.sh`, `fm-bootstrap.sh`, `docs/sessionstart-nudge.md` | 1409 | Owns startup ordering, locking, and the recovery digest. |
| 4 | Dispatch, briefs, and recovery | `bin/fm-spawn.sh`, `fm-brief.sh`, `fm-harness.sh`, `fm-dispatch-select.sh`, stuck-agent recovery | 2320 | Where isolation is enforced, where the brief contract lives, and what a restart costs. |
| 5 | no-mistakes integration | run attribution in `fm-crew-state.sh`, `fm-gate-refuse-lib.sh`, `.no-mistakes.yaml` | 764 | A kept dependency and the source of authoritative validation state. |
| 6 | treehouse and worktree isolation | `bin/fm-teardown.sh`, `fm-tangle-lib.sh` | 1335 | A kept dependency, and the source of the unlanded-work refusal we must not lose. |
| 7 | Task lifecycle and delivery modes | `bin/fm-project-mode.sh`, `fm-pr-check.sh`, `fm-pr-merge.sh`, `fm-merge-local.sh`, `fm-pr-lib.sh`, `fm-review-diff.sh` | 1592 | Determines what shipping means per project. |
| 8 | Backlog and work tracking | `.tasks.toml`, `fm-backlog-handoff.sh`, `fm-tasks-axi-lib.sh` | 420 | Decides whether GitHub Issues replace the local backlog. |
| 9 | Escalation, vocabulary, state, and config | donor operating contract, `docs/configuration.md` | 947 | Where the vocabulary strip bites, and the input to the volatile-versus-durable split. |
| 10 | Agent-only skills inventory | `.agents/skills/*` | 1790 | Sixteen skills, eleven of them agent-only; determines which survive as Themis skills. |

Measured total across assignments 1 through 10 is roughly 14,100 lines of shell and markdown. At observed reading and reporting rates that puts the campaign near 1.2M tokens for ten explorers, give or take a third. Assignments 1 and 4 are the heaviest and are the most likely to need a second pass.

Family mixing happens at campaign level, not per assignment: several explorers route through Pi and the rest run native, so the mapping never depends on a single vendor's blind spots.

The campaign runs in three waves of three, with the brief corrected between waves against what the previous wave actually returned. Assignment 8 is small enough to ride with assignment 7.

| Wave | Assignments | Routing | Rationale |
|---|---|---|---|
| 1 | 5 no-mistakes, 2 herdr verification, 6 treehouse and worktree | native, Pi, native | The three kept external dependencies. Highest decision value, and a size and shape range that tests the brief properly. |
| 2 | 1 herdr adapter, 3 session start, 4 dispatch and recovery | Pi, native, native | Core machinery, and the two heaviest assignments. Runs after the brief has survived one wave. |
| 3 | 7 and 8 lifecycle and backlog, 9 escalation and state, 10 skills inventory | Pi, native, Pi | Delivery path, operating contract, and the skill surface that determines what carries over. |

A wave is complete when every report in it passes the same bar: mechanism inventory with `file:line` evidence, code-verified claims separated from prose-sourced claims, and a copy / strip / rebuild verdict per mechanism.

### Scope Boundaries

**Deferred for later**

- Walk-away supervision. The donor's away-mode daemon is roughly 1500 lines and is not needed until the basic supervision loop exists.
- Persistent secondmates and multi-home routing. Assumed out for the first version; see Assumptions.

**Outside this product's identity**

- Non-herdr session backends. Not deferred, rejected.
- Public social presence. The donor's X mode integrates a shared bot and relay; assumed out.
- Captain and first-mate framing, in the contract and in every generated artifact.

### Dependencies and Assumptions

**Dependencies**

- herdr, verified at 0.7.5-preview. `agent wait` returns exit 0 with matched-agent JSON and exit 1 with structured timeout JSON. `agent list` returns fleet state with a monotonic change sequence. Native event subscription requires protocol 16, first shipped at 0.7.3.
- treehouse v2.0.0 as the worktree pool.
- no-mistakes v1.40.3, driven through its agent interface.
- A harness that tracks background tasks and notifies on completion. Verified on Claude Code: a background `agent wait` survived across turns and its exit notified the session.

**Assumptions**

- The strip list beyond the multiplexers is inferred, not instructed. Ed named the multiplexers. Removing public social presence, persistent secondmates, and the captain vocabulary are proposals he has not contradicted. Any of the three can return to scope without disturbing the rest.
- Workers report state by appending event lines. The donor's agents do this because their briefs require it; ours must require it too, or R2 through R7 have nothing to read.

### Outstanding Questions

**Deferred to planning**

- Whether the orchestrator ships as a CLI with a stable contract or as in-repo scripts. A stable contract is what would let Claude Code, Pi, and OMP share one implementation, but the choice does not change any requirement above.
- Whether GitHub Issues replace the local backlog outright or the two coexist. Assignment 7 informs this.
- Where the join record lives and what shape it takes.

### Sources

- `.agents/plans/2026-07-25-heartbeat-dissection-for-themis-persona.md` - the completed assignment 0 report, and the template for the remaining eleven.
- `docs/architecture.md` - the donor's own prose contract for supervision, backends, and delivery.
- `docs/herdr-backend.md` - herdr verification evidence, container shape, and known gaps.
- `bin/fm-crew-state.sh` header - the current-state precedence and run-attribution rules.
- `bin/fm-supervision-lib.sh` - the complete self-liveness predicate.
