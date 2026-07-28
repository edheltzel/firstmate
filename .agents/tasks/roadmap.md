# OMP staged support - prose planning roadmap

This file is the committed prose roadmap for the OMP work and is not a Tasks Axi input.

The canonical contract is `.agents/plans/omp-harness-integration-plan.md`.

The machine-readable task contract is `.agents/tasks/omp-manifest.json`.

`bin/fm-omp-plan-check.sh --json` is the non-mutating validator for task IDs, dependency closure, cycles, roadmap parity, plan cross-references, stable evidence IDs, rollback IDs, and Tasks Axi parsing.

The plan owns the full requirement, architecture, evidence, validation, hard-stop, and decision text.

This roadmap owns stable task IDs, phase order, dependencies, activation state, acceptance pointers, artifact inventories, and captain-facing progress fields.

Executable and current task records live in `.agents/tasks/backlog.md` and the live firstmate backlog at `data/backlog.md`.

Never pass this prose roadmap to `tasks-axi render`.

The current artifact state is `O8 historical BLOCK; O9 historical BLOCK; O10 final authority validation required`.

The completed second Red Team task is `omp-final-plan-redteam-o6`, whose 2026-07-27 report disposition is `BLOCK`.

The promoted O8 correction task is complete and preserves its historical `BLOCK` report at `data/omp-corrected-plan-redteam-o8/report.md`.

The next and only validation task before activation is `omp-final-authority-redteam-o10`.

Its exact report path is `data/omp-final-authority-redteam-o10/report.md`.

O8 and O9 are preserved historical `BLOCK` reviews and cannot authorize activation. No implementation authority exists until O10 returns exact `PASS` with `## Plan-blocking findings` followed by exactly `None.`, its decision-hold inventory verifies clean, and `omp-p1-activation-a7` completes its fail-closed checks.

No OMP runtime support is implemented by this branch.

## Activation boundary

The live firstmate backlog at `data/backlog.md` must not receive any new P1-P8 implementation task from this roadmap before O10 passes and activation completes.

The tracked `.agents/tasks/backlog.md` contains completed O6, O7, O8, and historical O9 records, queued O10 and activation records, plus the completed prior plan-correction record, and no future P1-P8 implementation rows.

The rows below are manifest-only records and are not executable backlog entries yet.

After O10 passes, the decision-hold inventory verifies clean, and the captain's 2026-07-27 authorization is confirmed, `omp-p1-activation-a7` may add the rows to the live backlog with the listed `blocked-by` edges.

Activation must not add OMP to verified allowlists, normal dispatch, primary supervision, secondmates, recovery, or Herdr claims.

The activation gate must refuse on `BLOCK`, `CONDITIONAL PASS`, a missing report, a stale report hash, an unverified decision hold, an unexpected P1-P8 row, a dirty tracked tree, or any open STOP row.

`bin/fm-omp-activation.sh` is non-mutating by default and owns the guarded single-backlog atomic publication used only after every refusal condition passes.

The activation control records use stable schemas: `omp-captain-authorization.v1`, `omp-decision-inventory.v1`, `omp-stop-ledger.v1`, `omp-activation-preflight.v1`, and the embedded `omp-activation-receipt.v1`.

The preflight binds the corrected-plan report hash, tracked and live backlog byte hashes, live branch, live commit, clean tree, empty decision and STOP sets, and the unchanged support fence.

The embedded receipt is the sole activation authority and records the preimage hash, normalized non-self-referential postimage hash, O10 report identity and hash, authorization identity, completed A7 ID, exact activated task and dependency records, activation date, and support fence.

The gate requires the O10 report's exact `PASS` disposition and `## Plan-blocking findings` / `None.` attestation, then validates the complete backlog postimage with Tasks Axi and the receipt schema before one same-directory atomic rename of `data/backlog.md`.

Pre-publication interruption leaves the exact backlog preimage unchanged, while interruption immediately after the rename leaves the complete receipt-bearing postimage authoritative.

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
| P0 | Correct O6 plan-block corrections | `omp-plan-block-corrections-o7` | `omp-final-plan-redteam-o6` | complete 2026-07-28; no runtime or support change | `omp-evidence-omp-plan-block-corrections-o7`; V26,V27,V28; `omp-rollback-omp-plan-block-corrections-o7` | P0 |
| P0 | Promoted O8 correction after historical BLOCK | `omp-corrected-plan-redteam-o8` | `omp-plan-block-corrections-o7` | complete 2026-07-28; historical report `BLOCK` | `omp-evidence-omp-corrected-plan-redteam-o8`; V26,V27,V28,V29; `omp-rollback-omp-corrected-plan-redteam-o8` | P0 |
| P0 | Historical final corrected-plan validation | `omp-final-corrected-plan-redteam-o9` | `omp-corrected-plan-redteam-o8` | complete 2026-07-28; preserved `BLOCK`; never activation authority | `omp-evidence-omp-final-corrected-plan-redteam-o9`; V26,V27,V28,V29; `omp-rollback-omp-final-corrected-plan-redteam-o9` | P0 |
| P0 | Independent final authority Red Team | `omp-final-authority-redteam-o10` | `omp-final-corrected-plan-redteam-o9` | queued, exact O10 `PASS` and `None.` required | `omp-evidence-omp-final-authority-redteam-o10`; V26,V27,V28,V29; `omp-rollback-omp-final-authority-redteam-o10` | P0 |
| P1 | Fail-closed implementation activation | `omp-p1-activation-a7` | `omp-final-authority-redteam-o10` | queued, blocked until O10 `PASS` and authorization `captain-omp-implementation-authorization-2026-07-27` | `omp-evidence-omp-p1-activation-a7`; V26,V27,V28,V29; `omp-rollback-omp-p1-activation-a7` | P1 |
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

The next gate is `omp-final-authority-redteam-o10` with required result `PASS` and no plan-blocking finding. O9 remains historical `BLOCK` evidence.

The current blocker is the preserved O8/O9 `BLOCK` evidence and required O10 validation, not an implementation failure.

## Support-state reporting

P1 through P3 may report only the exact experimental worker label after their gates pass.

P4 may report only the provisional tmux worker label after its live matrix passes.

P5 through P7 may report backend, supervision, or recovery evidence only as gated internal evidence, never as public or verified support.

P8 is the only phase that may publish first-class verified support.

OMP remains absent from verified-harness allowlists, normal dispatch profiles, primary supervision selection, secondmate routing, recovery classifiers, and Herdr support claims until P8 publication.

## Red Team handoff checklist

O10 must verify the plan's pinned command surface, hashes, and `@oh-my-pi/pi-utils` identity against the O2, O3, O4, O6, O8, and O9 evidence.

O10 must verify that the noext contradiction is unresolved and remains a hard stop until a future runtime or hermeticity proof clears it.

O10 must verify every C01-C25 disposition has a requirement, owner, task, evidence row, gate, containment action, and captain field.

O10 must verify all five convergent weaknesses map to concrete tasks and acceptance evidence.

O10 must verify all twelve STOP rows prevent false success or premature support.

O10 must verify the current-code map includes secondmate positional parsing, raw launch, generated hook, send, continuity, all cleanup lists, complete artifact inventories, and full regression ownership.

O10 must verify the parseable backlog has no default captain holds and no newly activated P1-P8 implementation rows in `.agents/tasks/backlog.md` or `data/backlog.md`.

O10 must verify the full regression loop, live evidence, effective-state, Bun/TypeScript, dependency-pin, monitoring, and publication-transaction requirements are explicit.

O10 must verify no captain choice is invented where the evidence-based BLOCK is sufficient, while preserving the recorded 2026-07-27 authorization behind activation.

## Tasks Axi commands

Use the explicit parseable tracked backlog path for local artifact validation.

- `tasks-axi --version`
- `tasks-axi list --file .agents/tasks/backlog.md`
- `tasks-axi show omp-p1-activation-a7 --file .agents/tasks/backlog.md --full`
- `tasks-axi ready --file .agents/tasks/backlog.md`
- `git diff --exit-code -- .agents/tasks/backlog.md .agents/tasks/roadmap.md`

The current `ready` result must contain no P1-P8 implementation task because the roadmap is awaiting O10 and activation.

Do not run `tasks-axi add` for any P1-P8 ID until O10 passes and the activation decision is recorded by `omp-p1-activation-a7`.

When activation is authorized, add the rows with the dependency IDs in this roadmap and verify `ready` exposes only the first unblocked ordinary tasks.

Never run `tasks-axi render` against this roadmap, and if a disposable backlog render is needed for a tool-compatibility probe, assert a clean Git diff on the tracked files afterward.

## Handoff definition

This roadmap and its parseable backlog are ready for O10 only when the plan pointer, stable IDs, dependencies, evidence rows, state labels, progress fields, artifact inventories, monitoring projections, and activation boundary are internally consistent.

The branch handoff must state that no OMP runtime support was implemented.

The branch handoff must state that `5be5e1436134e3c455a16200deded0fbc9c4a043` remains preserved and the new plan correction is separate.

The worktree must be clean and the commits must remain a local fast-forward candidate.
<!-- omp-task-contract-v1 -->
<!-- omp-task-row: {"phase":"P0","milestone":"Plan traceability","id":"omp-o5-plan-traceability","title":"OMP plan traceability","depends_on":[],"validation_ids":["V26","V27"],"evidence_ids":["omp-evidence-omp-o5-plan-traceability"],"rollback_id":"omp-rollback-omp-o5-plan-traceability","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"captain","state":"complete","blocked_by_stop_ids":[],"validation_owners":{"V26":"captain","V27":"captain"},"evidence_owners":{"omp-evidence-omp-o5-plan-traceability":"captain"},"rollback_owner":"captain","artifact_owners":{"evidence":"captain","rollback":"captain"}} -->
<!-- omp-task-row: {"phase":"P0","milestone":"Independent O6 red team","id":"omp-final-plan-redteam-o6","title":"Final OMP plan red team","depends_on":["omp-o5-plan-traceability"],"validation_ids":["V26","V27","V28"],"evidence_ids":["omp-evidence-omp-final-plan-redteam-o6"],"rollback_id":"omp-rollback-omp-final-plan-redteam-o6","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"red-team","state":"complete","blocked_by_stop_ids":[],"validation_owners":{"V26":"red-team","V27":"red-team","V28":"red-team"},"evidence_owners":{"omp-evidence-omp-final-plan-redteam-o6":"red-team"},"rollback_owner":"red-team","artifact_owners":{"evidence":"red-team","rollback":"red-team"}} -->
<!-- omp-task-row: {"phase":"P0","milestone":"O6 correction","id":"omp-plan-block-corrections-o7","title":"Correct OMP plan blockers","depends_on":["omp-final-plan-redteam-o6"],"validation_ids":["V26","V27","V28"],"evidence_ids":["omp-evidence-omp-plan-block-corrections-o7"],"rollback_id":"omp-rollback-omp-plan-block-corrections-o7","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"plan-owner","state":"complete","blocked_by_stop_ids":[],"validation_owners":{"V26":"plan-owner","V27":"plan-owner","V28":"plan-owner"},"evidence_owners":{"omp-evidence-omp-plan-block-corrections-o7":"plan-owner"},"rollback_owner":"plan-owner","artifact_owners":{"evidence":"plan-owner","rollback":"plan-owner"}} -->
<!-- omp-task-row: {"phase":"P0","milestone":"O8 correction","id":"omp-corrected-plan-redteam-o8","title":"Complete promoted O8 correction after historical BLOCK","depends_on":["omp-plan-block-corrections-o7"],"validation_ids":["V26","V27","V28","V29"],"evidence_ids":["omp-evidence-omp-corrected-plan-redteam-o8"],"rollback_id":"omp-rollback-omp-corrected-plan-redteam-o8","report_path":"data/omp-corrected-plan-redteam-o8/report.md","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"promotion-worker","state":"complete","disposition":"BLOCK","blocked_by_stop_ids":[],"validation_owners":{"V26":"promotion-worker","V27":"promotion-worker","V28":"promotion-worker","V29":"promotion-worker"},"evidence_owners":{"omp-evidence-omp-corrected-plan-redteam-o8":"promotion-worker"},"rollback_owner":"promotion-worker","artifact_owners":{"evidence":"promotion-worker","rollback":"promotion-worker"}} -->
<!-- omp-task-row: {"phase":"P0","milestone":"Independent final corrected-plan validation","id":"omp-final-corrected-plan-redteam-o9","title":"Historical O9 Red Team BLOCK preserved after correction","depends_on":["omp-corrected-plan-redteam-o8"],"validation_ids":["V26","V27","V28","V29"],"evidence_ids":["omp-evidence-omp-final-corrected-plan-redteam-o9"],"rollback_id":"omp-rollback-omp-final-corrected-plan-redteam-o9","report_path":"data/omp-final-corrected-plan-redteam-o9/report.md","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"red-team","state":"complete","disposition":"BLOCK","blocked_by_stop_ids":[],"validation_owners":{"V26":"red-team","V27":"red-team","V28":"red-team","V29":"red-team"},"evidence_owners":{"omp-evidence-omp-final-corrected-plan-redteam-o9":"red-team"},"rollback_owner":"red-team","artifact_owners":{"evidence":"red-team","rollback":"red-team"}} -->
<!-- omp-task-row: {"phase":"P0","milestone":"Independent final authority Red Team","id":"omp-final-authority-redteam-o10","title":"Final authority validation after O9 correction","depends_on":["omp-final-corrected-plan-redteam-o9"],"validation_ids":["V26","V27","V28","V29"],"evidence_ids":["omp-evidence-omp-final-authority-redteam-o10"],"rollback_id":"omp-rollback-omp-final-authority-redteam-o10","report_path":"data/omp-final-authority-redteam-o10/report.md","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"red-team","state":"queued","blocked_by_stop_ids":[],"validation_owners":{"V26":"red-team","V27":"red-team","V28":"red-team","V29":"red-team"},"evidence_owners":{"omp-evidence-omp-final-authority-redteam-o10":"red-team"},"rollback_owner":"red-team","artifact_owners":{"evidence":"red-team","rollback":"red-team"}} -->
<!-- omp-task-row: {"phase":"P1","milestone":"Activation authority","id":"omp-p1-activation-a7","title":"Activate OMP Phase 1","depends_on":["omp-final-authority-redteam-o10"],"validation_ids":["V26","V27","V28","V29"],"evidence_ids":["omp-evidence-omp-p1-activation-a7"],"rollback_id":"omp-rollback-omp-p1-activation-a7","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"captain","state":"blocked","blocked_by_stop_ids":["STOP-01","STOP-02","STOP-03","STOP-04","STOP-05","STOP-06","STOP-07","STOP-08","STOP-09","STOP-10","STOP-11","STOP-12"],"validation_owners":{"V26":"captain","V27":"captain","V28":"captain","V29":"captain"},"evidence_owners":{"omp-evidence-omp-p1-activation-a7":"captain"},"rollback_owner":"captain","artifact_owners":{"evidence":"captain","rollback":"captain"}} -->
<!-- omp-task-row: {"phase":"P1","milestone":"Runtime pin","id":"omp-p1-runtime-pin","title":"Pin OMP and Bun runtime","depends_on":["omp-p1-activation-a7"],"validation_ids":["V01","V03","V26"],"evidence_ids":["omp-evidence-omp-p1-runtime-pin"],"rollback_id":"omp-rollback-omp-p1-runtime-pin","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P1 runtime owner","state":"planned","blocked_by_stop_ids":["STOP-01","STOP-02"],"validation_owners":{"V01":"P1 runtime owner","V03":"P1 runtime owner","V26":"P1 runtime owner"},"evidence_owners":{"omp-evidence-omp-p1-runtime-pin":"P1 runtime owner"},"rollback_owner":"P1 runtime owner","artifact_owners":{"evidence":"P1 runtime owner","rollback":"P1 runtime owner"}} -->
<!-- omp-task-row: {"phase":"P1","milestone":"Discovery closure","id":"omp-p1-discovery-isolation","title":"Discover and isolate OMP extension closure","depends_on":["omp-p1-activation-a7"],"validation_ids":["V02","V03","V04","V26"],"evidence_ids":["omp-evidence-omp-p1-discovery-isolation"],"rollback_id":"omp-rollback-omp-p1-discovery-isolation","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P1 discovery owner","state":"planned","blocked_by_stop_ids":["STOP-01","STOP-02"],"validation_owners":{"V02":"P1 discovery owner","V03":"P1 discovery owner","V04":"P1 discovery owner","V26":"P1 discovery owner"},"evidence_owners":{"omp-evidence-omp-p1-discovery-isolation":"P1 discovery owner"},"rollback_owner":"P1 discovery owner","artifact_owners":{"evidence":"P1 discovery owner","rollback":"P1 discovery owner"}} -->
<!-- omp-task-row: {"phase":"P1","milestone":"Identity and ancestry","id":"omp-p1-identity-ancestry","title":"Prove OMP identity and process ancestry","depends_on":["omp-p1-activation-a7"],"validation_ids":["V03","V04","V26"],"evidence_ids":["omp-evidence-omp-p1-identity-ancestry"],"rollback_id":"omp-rollback-omp-p1-identity-ancestry","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P1 identity owner","state":"planned","blocked_by_stop_ids":["STOP-03"],"validation_owners":{"V03":"P1 identity owner","V04":"P1 identity owner","V26":"P1 identity owner"},"evidence_owners":{"omp-evidence-omp-p1-identity-ancestry":"P1 identity owner"},"rollback_owner":"P1 identity owner","artifact_owners":{"evidence":"P1 identity owner","rollback":"P1 identity owner"}} -->
<!-- omp-task-row: {"phase":"P2","milestone":"Experimental launch","id":"omp-p2-experimental-launch","title":"Launch isolated experimental OMP worker","depends_on":["omp-p1-runtime-pin","omp-p1-discovery-isolation","omp-p1-identity-ancestry"],"validation_ids":["V05","V06","V07","V08","V09","V10"],"evidence_ids":["omp-evidence-omp-p2-experimental-launch"],"rollback_id":"omp-rollback-omp-p2-experimental-launch","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P2 launch owner","state":"planned","blocked_by_stop_ids":["STOP-04","STOP-05"],"validation_owners":{"V05":"P2 launch owner","V06":"P2 launch owner","V07":"P2 launch owner","V08":"P2 launch owner","V09":"P2 launch owner","V10":"P2 launch owner"},"evidence_owners":{"omp-evidence-omp-p2-experimental-launch":"P2 launch owner"},"rollback_owner":"P2 launch owner","artifact_owners":{"evidence":"P2 launch owner","rollback":"P2 launch owner"}} -->
<!-- omp-task-row: {"phase":"P2","milestone":"Identity adapter","id":"omp-p2-identity-adapter","title":"Adapt OMP identity at the worker boundary","depends_on":["omp-p1-runtime-pin","omp-p1-identity-ancestry"],"validation_ids":["V03","V04","V05","V11"],"evidence_ids":["omp-evidence-omp-p2-identity-adapter"],"rollback_id":"omp-rollback-omp-p2-identity-adapter","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P2 identity adapter owner","state":"planned","blocked_by_stop_ids":["STOP-03","STOP-06"],"validation_owners":{"V03":"P2 identity adapter owner","V04":"P2 identity adapter owner","V05":"P2 identity adapter owner","V11":"P2 identity adapter owner"},"evidence_owners":{"omp-evidence-omp-p2-identity-adapter":"P2 identity adapter owner"},"rollback_owner":"P2 identity adapter owner","artifact_owners":{"evidence":"P2 identity adapter owner","rollback":"P2 identity adapter owner"}} -->
<!-- omp-task-row: {"phase":"P2","milestone":"Extension handshake","id":"omp-p2-extension-handshake","title":"Prove extension registration and handshake","depends_on":["omp-p2-experimental-launch"],"validation_ids":["V05","V06","V12","V13"],"evidence_ids":["omp-evidence-omp-p2-extension-handshake"],"rollback_id":"omp-rollback-omp-p2-extension-handshake","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P2 extension owner","state":"planned","blocked_by_stop_ids":["STOP-01","STOP-02","STOP-07"],"validation_owners":{"V05":"P2 extension owner","V06":"P2 extension owner","V12":"P2 extension owner","V13":"P2 extension owner"},"evidence_owners":{"omp-evidence-omp-p2-extension-handshake":"P2 extension owner"},"rollback_owner":"P2 extension owner","artifact_owners":{"evidence":"P2 extension owner","rollback":"P2 extension owner"}} -->
<!-- omp-task-row: {"phase":"P2","milestone":"Effective state","id":"omp-p2-thinking-state","title":"Validate effective model and thinking state","depends_on":["omp-p2-experimental-launch"],"validation_ids":["V05","V06","V14"],"evidence_ids":["omp-evidence-omp-p2-thinking-state"],"rollback_id":"omp-rollback-omp-p2-thinking-state","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P2 state owner","state":"planned","blocked_by_stop_ids":["STOP-08"],"validation_owners":{"V05":"P2 state owner","V06":"P2 state owner","V14":"P2 state owner"},"evidence_owners":{"omp-evidence-omp-p2-thinking-state":"P2 state owner"},"rollback_owner":"P2 state owner","artifact_owners":{"evidence":"P2 state owner","rollback":"P2 state owner"}} -->
<!-- omp-task-row: {"phase":"P3","milestone":"RPC lifecycle","id":"omp-p3-rpc-lifecycle","title":"Validate live RPC lifecycle","depends_on":["omp-p2-identity-adapter","omp-p2-experimental-launch","omp-p2-extension-handshake","omp-p2-thinking-state"],"validation_ids":["V15","V16","V17"],"evidence_ids":["omp-evidence-omp-p3-rpc-lifecycle"],"rollback_id":"omp-rollback-omp-p3-rpc-lifecycle","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P3 RPC owner","state":"planned","blocked_by_stop_ids":["STOP-04","STOP-08"],"validation_owners":{"V15":"P3 RPC owner","V16":"P3 RPC owner","V17":"P3 RPC owner"},"evidence_owners":{"omp-evidence-omp-p3-rpc-lifecycle":"P3 RPC owner"},"rollback_owner":"P3 RPC owner","artifact_owners":{"evidence":"P3 RPC owner","rollback":"P3 RPC owner"}} -->
<!-- omp-task-row: {"phase":"P3","milestone":"RPC continuation","id":"omp-p3-continuation-followup","title":"Validate continuation and follow-up RPC","depends_on":["omp-p3-rpc-lifecycle"],"validation_ids":["V18","V19"],"evidence_ids":["omp-evidence-omp-p3-continuation-followup"],"rollback_id":"omp-rollback-omp-p3-continuation-followup","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P3 continuation owner","state":"planned","blocked_by_stop_ids":["STOP-08"],"validation_owners":{"V18":"P3 continuation owner","V19":"P3 continuation owner"},"evidence_owners":{"omp-evidence-omp-p3-continuation-followup":"P3 continuation owner"},"rollback_owner":"P3 continuation owner","artifact_owners":{"evidence":"P3 continuation owner","rollback":"P3 continuation owner"}} -->
<!-- omp-task-row: {"phase":"P3","milestone":"Live worker","id":"omp-p3-worker-live","title":"Validate a live OMP worker","depends_on":["omp-p2-extension-handshake","omp-p2-thinking-state","omp-p3-continuation-followup"],"validation_ids":["V20","V21"],"evidence_ids":["omp-evidence-omp-p3-worker-live"],"rollback_id":"omp-rollback-omp-p3-worker-live","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P3 worker owner","state":"planned","blocked_by_stop_ids":["STOP-04","STOP-05","STOP-09"],"validation_owners":{"V20":"P3 worker owner","V21":"P3 worker owner"},"evidence_owners":{"omp-evidence-omp-p3-worker-live":"P3 worker owner"},"rollback_owner":"P3 worker owner","artifact_owners":{"evidence":"P3 worker owner","rollback":"P3 worker owner"}} -->
<!-- omp-task-row: {"phase":"P3","milestone":"Live cleanup","id":"omp-p3-cleanup-live","title":"Validate live cleanup and teardown","depends_on":["omp-p3-worker-live"],"validation_ids":["V22","V23"],"evidence_ids":["omp-evidence-omp-p3-cleanup-live"],"rollback_id":"omp-rollback-omp-p3-cleanup-live","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P3 cleanup owner","state":"planned","blocked_by_stop_ids":["STOP-10"],"validation_owners":{"V22":"P3 cleanup owner","V23":"P3 cleanup owner"},"evidence_owners":{"omp-evidence-omp-p3-cleanup-live":"P3 cleanup owner"},"rollback_owner":"P3 cleanup owner","artifact_owners":{"evidence":"P3 cleanup owner","rollback":"P3 cleanup owner"}} -->
<!-- omp-task-row: {"phase":"P3","milestone":"Regression lifecycle","id":"omp-p3-regression","title":"Run lifecycle regression coverage","depends_on":["omp-p3-cleanup-live"],"validation_ids":["V24","V25"],"evidence_ids":["omp-evidence-omp-p3-regression"],"rollback_id":"omp-rollback-omp-p3-regression","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P3 regression owner","state":"planned","blocked_by_stop_ids":["STOP-10","STOP-11"],"validation_owners":{"V24":"P3 regression owner","V25":"P3 regression owner"},"evidence_owners":{"omp-evidence-omp-p3-regression":"P3 regression owner"},"rollback_owner":"P3 regression owner","artifact_owners":{"evidence":"P3 regression owner","rollback":"P3 regression owner"}} -->
<!-- omp-task-row: {"phase":"P4","milestone":"Dispatch classification","id":"omp-p4-tmux-classifier","title":"Classify the experimental tmux worker","depends_on":["omp-p3-regression"],"validation_ids":["V26"],"evidence_ids":["omp-evidence-omp-p4-tmux-classifier"],"rollback_id":"omp-rollback-omp-p4-tmux-classifier","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P4 classifier owner","state":"planned","blocked_by_stop_ids":["STOP-04","STOP-05","STOP-12"],"validation_owners":{"V26":"P4 classifier owner"},"evidence_owners":{"omp-evidence-omp-p4-tmux-classifier":"P4 classifier owner"},"rollback_owner":"P4 classifier owner","artifact_owners":{"evidence":"P4 classifier owner","rollback":"P4 classifier owner"}} -->
<!-- omp-task-row: {"phase":"P4","milestone":"Provisional dispatch","id":"omp-p4-tmux-provisional","title":"Enable provisional experimental dispatch","depends_on":["omp-p4-tmux-classifier","omp-p3-worker-live"],"validation_ids":["V26","V27"],"evidence_ids":["omp-evidence-omp-p4-tmux-provisional"],"rollback_id":"omp-rollback-omp-p4-tmux-provisional","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P4 dispatch owner","state":"planned","blocked_by_stop_ids":["STOP-12"],"validation_owners":{"V26":"P4 dispatch owner","V27":"P4 dispatch owner"},"evidence_owners":{"omp-evidence-omp-p4-tmux-provisional":"P4 dispatch owner"},"rollback_owner":"P4 dispatch owner","artifact_owners":{"evidence":"P4 dispatch owner","rollback":"P4 dispatch owner"}} -->
<!-- omp-task-row: {"phase":"P5","milestone":"Herdr parity","id":"omp-p5-herdr-parity","title":"Prove Herdr parity boundary","depends_on":["omp-p4-tmux-provisional"],"validation_ids":["V26","V27"],"evidence_ids":["omp-evidence-omp-p5-herdr-parity"],"rollback_id":"omp-rollback-omp-p5-herdr-parity","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P5 Herdr owner","state":"planned","blocked_by_stop_ids":["STOP-12"],"validation_owners":{"V26":"P5 Herdr owner","V27":"P5 Herdr owner"},"evidence_owners":{"omp-evidence-omp-p5-herdr-parity":"P5 Herdr owner"},"rollback_owner":"P5 Herdr owner","artifact_owners":{"evidence":"P5 Herdr owner","rollback":"P5 Herdr owner"}} -->
<!-- omp-task-row: {"phase":"P6","milestone":"Supervision continuity","id":"omp-p6-supervision-continuity","title":"Validate supervision continuity","depends_on":["omp-p5-herdr-parity","omp-p2-identity-adapter"],"validation_ids":["V26","V27"],"evidence_ids":["omp-evidence-omp-p6-supervision-continuity"],"rollback_id":"omp-rollback-omp-p6-supervision-continuity","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P6 supervision owner","state":"planned","blocked_by_stop_ids":["STOP-04","STOP-12"],"validation_owners":{"V26":"P6 supervision owner","V27":"P6 supervision owner"},"evidence_owners":{"omp-evidence-omp-p6-supervision-continuity":"P6 supervision owner"},"rollback_owner":"P6 supervision owner","artifact_owners":{"evidence":"P6 supervision owner","rollback":"P6 supervision owner"}} -->
<!-- omp-task-row: {"phase":"P6","milestone":"Startup policy","id":"omp-p6-startup-policy","title":"Validate startup policy fencing","depends_on":["omp-p6-supervision-continuity"],"validation_ids":["V26","V27"],"evidence_ids":["omp-evidence-omp-p6-startup-policy"],"rollback_id":"omp-rollback-omp-p6-startup-policy","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P6 startup owner","state":"planned","blocked_by_stop_ids":["STOP-12"],"validation_owners":{"V26":"P6 startup owner","V27":"P6 startup owner"},"evidence_owners":{"omp-evidence-omp-p6-startup-policy":"P6 startup owner"},"rollback_owner":"P6 startup owner","artifact_owners":{"evidence":"P6 startup owner","rollback":"P6 startup owner"}} -->
<!-- omp-task-row: {"phase":"P7","milestone":"Two-home isolation","id":"omp-p7-two-home-isolation","title":"Validate isolated Firstmate homes","depends_on":["omp-p6-startup-policy","omp-p2-identity-adapter"],"validation_ids":["V26","V27"],"evidence_ids":["omp-evidence-omp-p7-two-home-isolation"],"rollback_id":"omp-rollback-omp-p7-two-home-isolation","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P7 isolation owner","state":"planned","blocked_by_stop_ids":["STOP-12"],"validation_owners":{"V26":"P7 isolation owner","V27":"P7 isolation owner"},"evidence_owners":{"omp-evidence-omp-p7-two-home-isolation":"P7 isolation owner"},"rollback_owner":"P7 isolation owner","artifact_owners":{"evidence":"P7 isolation owner","rollback":"P7 isolation owner"}} -->
<!-- omp-task-row: {"phase":"P7","milestone":"Recovery","id":"omp-p7-recovery","title":"Validate recovery and lock ownership","depends_on":["omp-p7-two-home-isolation"],"validation_ids":["V26","V27"],"evidence_ids":["omp-evidence-omp-p7-recovery"],"rollback_id":"omp-rollback-omp-p7-recovery","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P7 recovery owner","state":"planned","blocked_by_stop_ids":["STOP-03","STOP-12"],"validation_owners":{"V26":"P7 recovery owner","V27":"P7 recovery owner"},"evidence_owners":{"omp-evidence-omp-p7-recovery":"P7 recovery owner"},"rollback_owner":"P7 recovery owner","artifact_owners":{"evidence":"P7 recovery owner","rollback":"P7 recovery owner"}} -->
<!-- omp-task-row: {"phase":"P7","milestone":"Cleanup complete","id":"omp-p7-cleanup-complete","title":"Prove all publication cleanup","depends_on":["omp-p7-recovery"],"validation_ids":["V29"],"evidence_ids":["omp-evidence-omp-p7-cleanup-complete"],"rollback_id":"omp-rollback-omp-p7-cleanup-complete","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P7 cleanup owner","state":"planned","blocked_by_stop_ids":["STOP-10","STOP-11"],"validation_owners":{"V29":"P7 cleanup owner"},"evidence_owners":{"omp-evidence-omp-p7-cleanup-complete":"P7 cleanup owner"},"rollback_owner":"P7 cleanup owner","artifact_owners":{"evidence":"P7 cleanup owner","rollback":"P7 cleanup owner"}} -->
<!-- omp-task-row: {"phase":"P8","milestone":"Full validation","id":"omp-p8-full-validation","title":"Run complete OMP validation matrix","depends_on":["omp-p7-cleanup-complete"],"validation_ids":["V01","V02","V03","V04","V05","V06","V07","V08","V09","V10","V11","V12","V13","V14","V15","V16","V17","V18","V19","V20","V21","V22","V23","V24","V25","V26","V27","V28","V29"],"evidence_ids":["omp-evidence-omp-p8-full-validation"],"rollback_id":"omp-rollback-omp-p8-full-validation","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P8 validation owner","state":"planned","blocked_by_stop_ids":["STOP-01","STOP-02","STOP-03","STOP-04","STOP-05","STOP-06","STOP-07","STOP-08","STOP-09","STOP-10","STOP-11","STOP-12"],"validation_owners":{"V01":"P8 validation owner","V02":"P8 validation owner","V03":"P8 validation owner","V04":"P8 validation owner","V05":"P8 validation owner","V06":"P8 validation owner","V07":"P8 validation owner","V08":"P8 validation owner","V09":"P8 validation owner","V10":"P8 validation owner","V11":"P8 validation owner","V12":"P8 validation owner","V13":"P8 validation owner","V14":"P8 validation owner","V15":"P8 validation owner","V16":"P8 validation owner","V17":"P8 validation owner","V18":"P8 validation owner","V19":"P8 validation owner","V20":"P8 validation owner","V21":"P8 validation owner","V22":"P8 validation owner","V23":"P8 validation owner","V24":"P8 validation owner","V25":"P8 validation owner","V26":"P8 validation owner","V27":"P8 validation owner","V28":"P8 validation owner","V29":"P8 validation owner"},"evidence_owners":{"omp-evidence-omp-p8-full-validation":"P8 validation owner"},"rollback_owner":"P8 validation owner","artifact_owners":{"evidence":"P8 validation owner","rollback":"P8 validation owner"}} -->
<!-- omp-task-row: {"phase":"P8","milestone":"Atomic publication","id":"omp-p8-policy-publication","title":"Publish policy and evidence atomically","depends_on":["omp-p8-full-validation"],"validation_ids":["V29"],"evidence_ids":["omp-evidence-omp-p8-policy-publication"],"rollback_id":"omp-rollback-omp-p8-policy-publication","artifact_paths":{"evidence":"data/omp-evidence/{task_id}.json","rollback":"data/omp-rollback/{task_id}.json"},"artifact_schemas":{"evidence":"omp-evidence.v1","rollback":"omp-rollback.v1"},"owner":"P8 publication owner","state":"planned","blocked_by_stop_ids":["STOP-10","STOP-11","STOP-12"],"validation_owners":{"V29":"P8 publication owner"},"evidence_owners":{"omp-evidence-omp-p8-policy-publication":"P8 publication owner"},"rollback_owner":"P8 publication owner","artifact_owners":{"evidence":"P8 publication owner","rollback":"P8 publication owner"}} -->
<!-- omp-task-contract-end -->
<!-- omp-task-contract-sha256: bd7b2ec1abd663adfc128bd7fdf422f2b9de7ad70c18f95da191236d1c7d039c -->
