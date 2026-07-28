# OMP staged support - prose planning roadmap

This file is the committed prose roadmap for the OMP work and is not a Tasks Axi input.

The canonical contract is `.agents/plans/omp-harness-integration-plan.md`.

The plan owns the full requirement, architecture, evidence, validation, hard-stop, and decision text.

This roadmap owns stable task IDs, phase order, dependencies, activation state, acceptance pointers, artifact inventories, and captain-facing progress fields.

Executable and current task records live in `.agents/tasks/backlog.md` and the live firstmate backlog at `data/backlog.md`.

Never pass this prose roadmap to `tasks-axi render`.

The current artifact state is `O6 BLOCK; corrected-plan Red Team required`.

The completed second Red Team task is `omp-final-plan-redteam-o6`, whose 2026-07-27 report disposition is `BLOCK`.

The next validation task is `omp-corrected-plan-redteam-o8`.

No implementation authority exists until O8 returns `PASS` with no plan-blocking finding, its decision-hold inventory verifies clean, and `omp-p1-activation-a7` completes its fail-closed checks.

No OMP runtime support is implemented by this branch.

## Activation boundary

The live firstmate backlog at `data/backlog.md` must not receive any new P1-P8 implementation task from this roadmap before O8 passes and activation completes.

The tracked `.agents/tasks/backlog.md` contains current O6, O7, O8, and activation records, plus the completed prior plan-correction record, and no future P1-P8 implementation rows.

The rows below are manifest-only records and are not executable backlog entries yet.

After O8 passes, the decision-hold inventory verifies clean, and the captain's 2026-07-27 authorization is confirmed, `omp-p1-activation-a7` may add the rows to the live backlog with the listed `blocked-by` edges.

Activation must not add OMP to verified allowlists, normal dispatch, primary supervision, secondmates, recovery, or Herdr claims.

The activation gate must refuse on `BLOCK`, `CONDITIONAL PASS`, a missing report, a stale report hash, an unverified decision hold, an unexpected P1-P8 row, a dirty tracked tree, or any open STOP row.

The only support labels available before final P8 publication are `experimental worker-only` and `provisional tmux worker`.

The exact experimental result label is `experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support`.

The tested Tasks Axi executable is `/opt/homebrew/bin/tasks-axi` version `0.2.3`.

Non-mutating checks are `/opt/homebrew/bin/tasks-axi list --file .agents/tasks/backlog.md`, `/opt/homebrew/bin/tasks-axi show <id> --file .agents/tasks/backlog.md --full`, `/opt/homebrew/bin/tasks-axi ready --file .agents/tasks/backlog.md`, and `git diff --exit-code -- .agents/tasks/backlog.md .agents/tasks/roadmap.md`.

`tasks-axi render` is allowed only on a disposable copy of `.agents/tasks/backlog.md` for an explicit tool-compatibility probe, never on this roadmap.

## Stable task manifest

`State` is a planning state until activation and does not mean that a task is held for a captain decision.

`Evidence` points to the acceptance rows in the canonical plan.

`needs:human` is `none` for every current row because O4 found no unresolved captain choice.

| Phase | Milestone | Task ID | Dependencies | State | Evidence and acceptance pointer | Plan section |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Landed plan traceability correction | `omp-o5-plan-traceability` | none | complete in `967b1dc`, `a070dff`, `44a92ce`, `29511e5`, `cd3c826`, `da558ff` | C01-C25 compliance matrix, V01-V25 validation matrix, STOP-01 through STOP-12, and clean docs checks | P0 |
| P0 | Independent second Red Team | `omp-final-plan-redteam-o6` | `omp-o5-plan-traceability` | complete 2026-07-27 with `BLOCK` | `data/omp-final-plan-redteam-o6/report.md`, every C01-C25 row, every task, dependency, gate, rollback, evidence row, progress field, and decision classification | P0 |
| P0 | Correct O6 plan-block corrections | `omp-plan-block-corrections-o7` | `omp-final-plan-redteam-o6` | current planning/tracking correction | O6 S0/S1 mandatory corrections, artifact inventory, current-code map, and no runtime/support changes | P0 |
| P0 | Corrected-plan Red Team | `omp-corrected-plan-redteam-o8` | `omp-plan-block-corrections-o7` | queued validation | Every O6 correction, V26-V29, activation gate, and no premature implementation row | P0 |
| P1 | Fail-closed implementation activation | `omp-p1-activation-a7` | `omp-corrected-plan-redteam-o8` and captain authorization 2026-07-27 | queued, blocked until O8 `PASS` | Refuse unless O8 is `PASS` with no plan-blocking finding, the hold verifies, the tree is clean, and no P1-P8 task is active | P1 |
| P1 | Runtime identity ledger | `omp-p1-runtime-pin` | `omp-p1-activation-a7` | planned, manifest-only | REQ-EVID-01, REQ-LINK-01, V01, V24, dependency hashes | P1 |
| P1 | Discovery and flag safety ledger | `omp-p1-discovery-isolation` | `omp-p1-activation-a7` | planned, manifest-only | REQ-DISC-01, REQ-DISC-02, V02, V03, STOP-01, immutable loading contract | P1 |
| P1 | Host ancestry identity ledger | `omp-p1-identity-ancestry` | `omp-p1-activation-a7` | planned, manifest-only | REQ-ID-01, REQ-ID-02, V04, STOP-03 | P1 |
| P2 | Experimental worker launcher | `omp-p2-experimental-launch` | all P1 tasks | planned, manifest-only | REQ-SCOPE-01, REQ-DISC-01, V02, V03, P2 worker-only contract | P2 |
| P2 | Executable OMP identity and environment adapter | `omp-p2-identity-adapter` | `omp-p1-runtime-pin`, `omp-p1-identity-ancestry`, and `omp-p1-activation-a7` | planned, manifest-only; blocks P6/P7 eligibility | REQ-ID-01, REQ-ID-02, V04, STOP-03; owns harness, lock, spawn environment, and bootstrap liveness implementation | P2 |
| P2 | Mandatory extension handshake | `omp-p2-extension-handshake` | `omp-p2-experimental-launch` | planned, manifest-only | REQ-EXT-01, REQ-EXT-02, V05, V06, V07, STOP-02 | P2 |
| P2 | Effective thinking-state gate | `omp-p2-thinking-state` | `omp-p2-experimental-launch` | planned, manifest-only | REQ-STATE-01, V08, STOP-04 | P2 |
| P3 | Native RPC lifecycle adapter | `omp-p3-rpc-lifecycle` | `omp-p2-identity-adapter`, `omp-p2-experimental-launch`, and handshake preflight | planned, manifest-only | REQ-RPC-01, REQ-RPC-02, V09, V10, V11, V12 | P3 |
| P3 | Continuation and follow-up failure semantics | `omp-p3-continuation-followup` | `omp-p3-rpc-lifecycle` | planned, manifest-only | REQ-CONT-01, REQ-FOLLOW-01, V13, V14, STOP-05 | P3 |
| P3 | Real worker normal and abort E2E | `omp-p3-worker-live` | `omp-p2-extension-handshake`, `omp-p2-thinking-state`, `omp-p3-continuation-followup` | planned, manifest-only | REQ-RPC-02, REQ-LIVE-01, V10, V12, V15 | P3 |
| P3 | Real worker cleanup E2E | `omp-p3-cleanup-live` | `omp-p3-worker-live` | planned, manifest-only | REQ-CLEAN-01, REQ-CLEAN-02, V21, V22, STOP-09 | P3 |
| P3 | Focused and full regression loop | `omp-p3-regression` | `omp-p3-cleanup-live` | planned, manifest-only | REQ-REG-01, V23, full `tests/*.test.sh` loop, applicable lint, pinned Bun/TypeScript and dependency checks | P3 |
| P4 | Tmux OMP ancestry and liveness classifier | `omp-p4-tmux-classifier` | `omp-p3-regression` | planned, manifest-only | REQ-BACKEND-01, V16, STOP-06 | P4 |
| P4 | Provisional tmux worker evidence | `omp-p4-tmux-provisional` | `omp-p4-tmux-classifier`, `omp-p3-worker-live` | planned, manifest-only | REQ-SCOPE-01, REQ-LIVE-01, V16, V25, provisional label | P4 |
| P5 | Herdr lifecycle parity | `omp-p5-herdr-parity` | `omp-p4-tmux-provisional` | planned, manifest-only | REQ-BACKEND-02, V17, STOP-06, STOP-08 | P5 |
| P6 | Primary continuity and supervision | `omp-p6-supervision-continuity` | `omp-p5-herdr-parity` and `omp-p2-identity-adapter` | planned, manifest-only | REQ-WATCH-01, V18, STOP-05; identity owner must be complete first | P6 |
| P6 | Startup policy and supervision protocol | `omp-p6-startup-policy` | `omp-p6-supervision-continuity` | planned, manifest-only | REQ-EXT-02, REQ-SCOPE-01, V18, V25 | P6 |
| P7 | Two-home isolation | `omp-p7-two-home-isolation` | `omp-p6-startup-policy` and `omp-p2-identity-adapter` | planned, manifest-only | REQ-HOME-01, V19, STOP-07; identity owner must be complete first | P7 |
| P7 | Sole-owner recovery | `omp-p7-recovery` | `omp-p7-two-home-isolation` | planned, manifest-only | REQ-REC-01, V20, STOP-06, STOP-07 | P7 |
| P7 | Complete cleanup and refusal matrix | `omp-p7-cleanup-complete` | `omp-p7-recovery` | planned, manifest-only | REQ-CLEAN-01, REQ-CLEAN-02, V21, V22, STOP-09 | P7 |
| P8 | Full live and repository verification | `omp-p8-full-validation` | all P7 tasks | planned, manifest-only | REQ-REG-01, REQ-LIVE-01, V17-V29, STOP-10, STOP-11, STOP-12 | P8 |
| P8 | First-class policy and documentation publication | `omp-p8-policy-publication` | `omp-p8-full-validation` and no open stop | planned, manifest-only | REQ-SCOPE-01, REQ-MAP-01, REQ-DOC-01, REQ-MON-01, V25-V29, all C01-C25, exact inventory and revert proof | P8 |

## Phase and dependency rules

P0 is serialized because independent Red Team validation must inspect the plan, parseable backlog, and activation contract before any implementation task exists in the live backlog.

P1 evidence tasks may run in parallel only after activation and only when each task has unique HOME, XDG, profile, cache, socket, session, token, log, evidence, package, lock, wake, process, and backend roots.

The simultaneous P1 test must prove disjoint mutable realpaths and independent outputs, or the manifest serializes P1 before dispatch.

P2 launch, handshake, and state work is serialized at the brief-delivery gate, although handshake and state fixtures may run in parallel after launcher preflight.

P3 lifecycle and failure semantics must precede real worker E2E, and real worker E2E must precede cleanup and the full regression loop.

P4 is serialized after P3 because tmux liveness cannot be claimed from a fixture-only worker result.

P5 is serialized after provisional tmux evidence because Herdr parity requires the same native lifecycle contract and the same pinned runtime.

P6 supervision is serialized after backend parity because a watcher cannot claim liveness or successor ownership on an unverified backend.

P7 is serialized after supervision because multi-home recovery depends on the actual watcher and lock ownership contract.

P8 is serialized after every prior phase and has no bypass for a partial matrix or a partial publication transaction.

After activation, Tasks Axi `blocked-by` edges provide readiness automatically.

Ordinary future tasks are not captain-held by default.

Only a real policy, product, destructive, or security decision may create a structured `needs:human` hold.

The current `needs:human` set is empty because the captain's implementation authorization is already recorded and no product choice is open.

## Progress contract

Status and Bearings report one active phase at a time and do not calculate progress over all future manifest rows.

The current scoped denominator is the number of activated tasks in the active phase.

Manifest-only rows are excluded from the completed/total denominator until activation.

A task is complete only when its evidence artifact, acceptance rows, exit criterion, and rollback or containment result are recorded.

A task is blocked only with its requirement or STOP ID, owner, missing evidence, and containment action.

The captain-facing status fields are `phase`, `milestone`, `completed/total scoped tasks`, `branch`, `blockers`, `next gate`, and `needs:human` decisions with explicit options.

The active branch is derived from live Git state with `git branch --show-current` or `git rev-parse --abbrev-ref HEAD`.

The branch named in a historical plan or task body is never used as current reporting evidence.

The next gate is `omp-corrected-plan-redteam-o8` with required result `PASS` and no plan-blocking finding.

The current blocker is the O6 `BLOCK` result and required correction review, not an implementation failure.

## Support-state reporting

P1 through P3 may report only the exact experimental worker label after their gates pass.

P4 may report only the provisional tmux worker label after its live matrix passes.

P5 through P7 may report backend, supervision, or recovery evidence only as gated internal evidence, never as public or verified support.

P8 is the only phase that may publish first-class verified support.

OMP remains absent from verified-harness allowlists, normal dispatch profiles, primary supervision selection, secondmate routing, recovery classifiers, and Herdr support claims until P8 publication.

## Red Team handoff checklist

O8 must verify the plan's pinned command surface, hashes, and `@oh-my-pi/pi-utils` identity against the O2, O3, O4, and O6 evidence.

O8 must verify that the noext contradiction is unresolved and remains a hard stop until a future runtime or hermeticity proof clears it.

O8 must verify every C01-C25 disposition has a requirement, owner, task, evidence row, gate, containment action, and captain field.

O8 must verify all five convergent weaknesses map to concrete tasks and acceptance evidence.

O8 must verify all twelve STOP rows prevent false success or premature support.

O8 must verify the current-code map includes secondmate positional parsing, raw launch, generated hook, send, continuity, all cleanup lists, complete artifact inventories, and full regression ownership.

O8 must verify the parseable backlog has no default captain holds and no newly activated P1-P8 implementation rows in `.agents/tasks/backlog.md` or `data/backlog.md`.

O8 must verify the full regression loop, live evidence, effective-state, Bun/TypeScript, dependency-pin, monitoring, and publication-transaction requirements are explicit.

O8 must verify no captain choice is invented where the evidence-based BLOCK is sufficient, while preserving the recorded 2026-07-27 authorization behind activation.

## Tasks Axi commands

Use the explicit parseable tracked backlog path for local artifact validation.

- `/opt/homebrew/bin/tasks-axi --version`
- `/opt/homebrew/bin/tasks-axi list --file .agents/tasks/backlog.md`
- `/opt/homebrew/bin/tasks-axi show omp-p1-activation-a7 --file .agents/tasks/backlog.md --full`
- `/opt/homebrew/bin/tasks-axi ready --file .agents/tasks/backlog.md`
- `git diff --exit-code -- .agents/tasks/backlog.md .agents/tasks/roadmap.md`

The current `ready` result must contain no P1-P8 implementation task because the roadmap is awaiting O8 and activation.

Do not run `tasks-axi add` for any P1-P8 ID until O8 passes and the activation decision is recorded by `omp-p1-activation-a7`.

When activation is authorized, add the rows with the dependency IDs in this roadmap and verify `ready` exposes only the first unblocked ordinary tasks.

Never run `tasks-axi render` against this roadmap, and if a disposable backlog render is needed for a tool-compatibility probe, assert a clean Git diff on the tracked files afterward.

## Handoff definition

This roadmap and its parseable backlog are ready for O8 only when the plan pointer, stable IDs, dependencies, evidence rows, state labels, progress fields, artifact inventories, monitoring projections, and activation boundary are internally consistent.

The branch handoff must state that no OMP runtime support was implemented.

The branch handoff must state that `5be5e1436134e3c455a16200deded0fbc9c4a043` remains preserved and the new plan correction is separate.

The worktree must be clean and the commits must remain a local fast-forward candidate.
