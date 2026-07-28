# OMP staged support - prose planning roadmap

This file is the committed prose roadmap for the OMP work and is not a Tasks Axi input.

The canonical contract is `.agents/plans/omp-harness-integration-plan.md`.

The machine-readable task contract is `.agents/tasks/omp-manifest.json`.

`bin/fm-omp-plan-check.sh --json` is the non-mutating validator for task IDs, dependency closure, cycles, roadmap parity, plan cross-references, stable evidence IDs, rollback IDs, and Tasks Axi parsing.

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

`bin/fm-omp-activation.sh` is non-mutating by default and owns the guarded atomic backlog publication used only after every refusal condition passes.

The activation control records use stable schemas: `omp-captain-authorization.v1`, `omp-decision-inventory.v1`, `omp-stop-ledger.v1`, `omp-activation-preflight.v1`, and `omp-activation-receipt.v1`.

The preflight binds the corrected-plan report hash, tracked and live backlog byte hashes, live branch, live commit, clean tree, empty decision and STOP sets, and the unchanged support fence.

The only support labels available before final P8 publication are `experimental worker-only` and `provisional tmux worker`.

The exact experimental result label is `experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support`.

The validated Tasks Axi executable is resolved from `PATH` and reports version `0.2.3`.

The exact publication and cleanup classes are owned by `docs/omp-publication-inventory.md` and `.agents/tasks/omp-publication-manifest.json`, and checked by `bin/fm-omp-publication-check.sh`.

Non-mutating checks are `tasks-axi list --file .agents/tasks/backlog.md`, `tasks-axi show <id> --file .agents/tasks/backlog.md --full`, `tasks-axi ready --file .agents/tasks/backlog.md`, and `git diff --exit-code -- .agents/tasks/backlog.md .agents/tasks/roadmap.md`.

`tasks-axi render` is allowed only on a disposable copy of `.agents/tasks/backlog.md` for an explicit tool-compatibility probe, never on this roadmap.

## Stable task manifest

`State` is a planning state until activation and does not mean that a task is held for a captain decision.

`Evidence` points to the acceptance rows in the canonical plan.

`needs:human` is `none` for every current row because O4 found no unresolved captain choice.

| Phase | Milestone | Task ID | Dependencies | State | Evidence and acceptance pointer | Plan section |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Landed plan traceability correction | `omp-o5-plan-traceability` | none | complete in `967b1dc`, `a070dff`, `44a92ce`, `29511e5`, `cd3c826`, `da558ff` | `omp-evidence-omp-o5-plan-traceability`; V26,V27; `omp-rollback-omp-o5-plan-traceability` | P0 |
| P0 | Independent second Red Team | `omp-final-plan-redteam-o6` | `omp-o5-plan-traceability` | complete 2026-07-27 with `BLOCK` | `omp-evidence-omp-final-plan-redteam-o6`; V26,V27,V28; `omp-rollback-omp-final-plan-redteam-o6` | P0 |
| P0 | Correct O6 plan-block corrections | `omp-plan-block-corrections-o7` | `omp-final-plan-redteam-o6` | current planning/tracking correction | `omp-evidence-omp-plan-block-corrections-o7`; V26,V27,V28; `omp-rollback-omp-plan-block-corrections-o7` | P0 |
| P0 | Corrected-plan Red Team | `omp-corrected-plan-redteam-o8` | `omp-plan-block-corrections-o7` | queued validation | `omp-evidence-omp-corrected-plan-redteam-o8`; V26,V27,V28,V29; `omp-rollback-omp-corrected-plan-redteam-o8` | P0 |
| P1 | Fail-closed implementation activation | `omp-p1-activation-a7` | `omp-corrected-plan-redteam-o8` | queued, blocked until O8 `PASS` and authorization `captain-omp-implementation-authorization-2026-07-27` | `omp-evidence-omp-p1-activation-a7`; V26,V27,V28,V29; `omp-rollback-omp-p1-activation-a7` | P1 |
| P1 | Runtime identity ledger | `omp-p1-runtime-pin` | `omp-p1-activation-a7` | planned, manifest-only | `omp-evidence-omp-p1-runtime-pin`; V01,V03,V26; `omp-rollback-omp-p1-runtime-pin` | P1 |
| P1 | Discovery and flag safety ledger | `omp-p1-discovery-isolation` | `omp-p1-activation-a7` | planned, manifest-only | `omp-evidence-omp-p1-discovery-isolation`; V02,V03,V04,V26; `omp-rollback-omp-p1-discovery-isolation` | P1 |
| P1 | Host ancestry identity ledger | `omp-p1-identity-ancestry` | `omp-p1-activation-a7` | planned, manifest-only | `omp-evidence-omp-p1-identity-ancestry`; V03,V04,V26; `omp-rollback-omp-p1-identity-ancestry` | P1 |
| P2 | Experimental worker launcher | `omp-p2-experimental-launch` | `omp-p1-runtime-pin`, `omp-p1-discovery-isolation`, `omp-p1-identity-ancestry` | planned, manifest-only | `omp-evidence-omp-p2-experimental-launch`; V05-V10; `omp-rollback-omp-p2-experimental-launch` | P2 |
| P2 | Executable OMP identity and environment adapter | `omp-p2-identity-adapter` | `omp-p1-runtime-pin`, `omp-p1-identity-ancestry` | planned, manifest-only; blocks P6/P7 eligibility | `omp-evidence-omp-p2-identity-adapter`; V03,V04,V05,V11; `omp-rollback-omp-p2-identity-adapter` | P2 |
| P2 | Mandatory extension handshake | `omp-p2-extension-handshake` | `omp-p2-experimental-launch` | planned, manifest-only | `omp-evidence-omp-p2-extension-handshake`; V05,V06,V12,V13; `omp-rollback-omp-p2-extension-handshake` | P2 |
| P2 | Effective thinking-state gate | `omp-p2-thinking-state` | `omp-p2-experimental-launch` | planned, manifest-only | `omp-evidence-omp-p2-thinking-state`; V05,V06,V14; `omp-rollback-omp-p2-thinking-state` | P2 |
| P3 | Native RPC lifecycle adapter | `omp-p3-rpc-lifecycle` | `omp-p2-identity-adapter`, `omp-p2-experimental-launch`, `omp-p2-extension-handshake`, `omp-p2-thinking-state` | planned, manifest-only | `omp-evidence-omp-p3-rpc-lifecycle`; V15,V16,V17; `omp-rollback-omp-p3-rpc-lifecycle` | P3 |
| P3 | Continuation and follow-up failure semantics | `omp-p3-continuation-followup` | `omp-p3-rpc-lifecycle` | planned, manifest-only | `omp-evidence-omp-p3-continuation-followup`; V18,V19; `omp-rollback-omp-p3-continuation-followup` | P3 |
| P3 | Real worker normal and abort E2E | `omp-p3-worker-live` | `omp-p2-extension-handshake`, `omp-p2-thinking-state`, `omp-p3-continuation-followup` | planned, manifest-only | `omp-evidence-omp-p3-worker-live`; V20,V21; `omp-rollback-omp-p3-worker-live` | P3 |
| P3 | Real worker cleanup E2E | `omp-p3-cleanup-live` | `omp-p3-worker-live` | planned, manifest-only | `omp-evidence-omp-p3-cleanup-live`; V22,V23; `omp-rollback-omp-p3-cleanup-live` | P3 |
| P3 | Focused and full regression loop | `omp-p3-regression` | `omp-p3-cleanup-live` | planned, manifest-only | `omp-evidence-omp-p3-regression`; V24,V25; `omp-rollback-omp-p3-regression` | P3 |
| P4 | Tmux OMP ancestry and liveness classifier | `omp-p4-tmux-classifier` | `omp-p3-regression` | planned, manifest-only | `omp-evidence-omp-p4-tmux-classifier`; V26; `omp-rollback-omp-p4-tmux-classifier` | P4 |
| P4 | Provisional tmux worker evidence | `omp-p4-tmux-provisional` | `omp-p4-tmux-classifier`, `omp-p3-worker-live` | planned, manifest-only | `omp-evidence-omp-p4-tmux-provisional`; V26,V27; `omp-rollback-omp-p4-tmux-provisional` | P4 |
| P5 | Herdr lifecycle parity | `omp-p5-herdr-parity` | `omp-p4-tmux-provisional` | planned, manifest-only | `omp-evidence-omp-p5-herdr-parity`; V26,V27; `omp-rollback-omp-p5-herdr-parity` | P5 |
| P6 | Primary continuity and supervision | `omp-p6-supervision-continuity` | `omp-p5-herdr-parity`, `omp-p2-identity-adapter` | planned, manifest-only | `omp-evidence-omp-p6-supervision-continuity`; V26,V27; `omp-rollback-omp-p6-supervision-continuity` | P6 |
| P6 | Startup policy and supervision protocol | `omp-p6-startup-policy` | `omp-p6-supervision-continuity` | planned, manifest-only | `omp-evidence-omp-p6-startup-policy`; V26,V27; `omp-rollback-omp-p6-startup-policy` | P6 |
| P7 | Two-home isolation | `omp-p7-two-home-isolation` | `omp-p6-startup-policy`, `omp-p2-identity-adapter` | planned, manifest-only | `omp-evidence-omp-p7-two-home-isolation`; V26,V27; `omp-rollback-omp-p7-two-home-isolation` | P7 |
| P7 | Sole-owner recovery | `omp-p7-recovery` | `omp-p7-two-home-isolation` | planned, manifest-only | `omp-evidence-omp-p7-recovery`; V26,V27; `omp-rollback-omp-p7-recovery` | P7 |
| P7 | Complete cleanup and refusal matrix | `omp-p7-cleanup-complete` | `omp-p7-recovery` | planned, manifest-only | `omp-evidence-omp-p7-cleanup-complete`; V29; `omp-rollback-omp-p7-cleanup-complete` | P7 |
| P8 | Full live and repository verification | `omp-p8-full-validation` | `omp-p7-cleanup-complete` | planned, manifest-only | `omp-evidence-omp-p8-full-validation`; V01-V29; `omp-rollback-omp-p8-full-validation` | P8 |
| P8 | First-class policy and documentation publication | `omp-p8-policy-publication` | `omp-p8-full-validation` | planned, manifest-only | `omp-evidence-omp-p8-policy-publication`; V29; `omp-rollback-omp-p8-policy-publication` | P8 |

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

- `tasks-axi --version`
- `tasks-axi list --file .agents/tasks/backlog.md`
- `tasks-axi show omp-p1-activation-a7 --file .agents/tasks/backlog.md --full`
- `tasks-axi ready --file .agents/tasks/backlog.md`
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
