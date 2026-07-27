# OMP staged support - Tasks Axi planning manifest

This file is the committed Tasks Axi-compatible planning manifest for the OMP work.

The canonical contract is `.agents/plans/omp-harness-integration-plan.md`.

The plan owns the full requirement, architecture, evidence, validation, hard-stop, and decision text.

This manifest owns stable task IDs, phase order, dependencies, activation state, acceptance pointers, and captain-facing progress fields.

The current artifact state is `pending second Red Team validation`.

The second Red Team task is `omp-final-plan-redteam-o6`.

No implementation authority exists until O6 returns `PASS` with no plan-blocking finding and its decision-hold inventory verifies clean.

No OMP runtime support is implemented by this branch.

## Activation boundary

The live firstmate backlog at `data/backlog.md` must not receive any new P1-P8 implementation task from this manifest before O6 passes.

The tracked `.agents/tasks/backlog.md` intentionally contains only the completed prior plan-correction record and no future implementation rows.

The rows below are manifest-only records and are not executable backlog entries yet.

After O6 passes, a deliberate activation step may add the rows to the live backlog with the listed `blocked-by` edges.

Activation must not add OMP to verified allowlists, normal dispatch, primary supervision, secondmates, recovery, or Herdr claims.

The only support labels available before final P8 publication are `experimental worker-only` and `provisional tmux worker`.

The exact experimental result label is `experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support`.

## Stable task manifest

`State` is a planning state until activation and does not mean that a task is held for a captain decision.

`Evidence` points to the acceptance rows in the canonical plan.

`needs:human` is `none` for every current row because O4 found no unresolved captain choice.

| Phase | Milestone | Task ID | Dependencies | State | Evidence and acceptance pointer | Plan section |
| --- | --- | --- | --- | --- | --- | --- |
| P0 | Plan traceability correction | `omp-o5-plan-traceability` | none | complete in `a070dff` | C01-C25 compliance matrix, V01-V25 validation matrix, STOP-01 through STOP-12, clean docs checks | P0 |
| P0 | Independent second Red Team | `omp-final-plan-redteam-o6` | `omp-o5-plan-traceability` | queued in live backlog, no implementation | Every C01-C25 row, every task, dependency, gate, rollback, evidence row, progress field, and decision classification | P0 |
| P1 | Runtime identity ledger | `omp-p1-runtime-pin` | O6 PASS | planned, manifest-only | REQ-EVID-01, REQ-LINK-01, V01, V24 | P1 |
| P1 | Discovery and flag safety ledger | `omp-p1-discovery-isolation` | O6 PASS | planned, manifest-only | REQ-DISC-01, REQ-DISC-02, V02, V03, STOP-01 | P1 |
| P1 | Host ancestry identity ledger | `omp-p1-identity-ancestry` | O6 PASS | planned, manifest-only | REQ-ID-01, REQ-ID-02, V04, STOP-03 | P1 |
| P2 | Experimental worker launcher | `omp-p2-experimental-launch` | all P1 tasks | planned, manifest-only | REQ-SCOPE-01, REQ-DISC-01, V02, V03, P2 worker-only contract | P2 |
| P2 | Mandatory extension handshake | `omp-p2-extension-handshake` | `omp-p2-experimental-launch` | planned, manifest-only | REQ-EXT-01, REQ-EXT-02, V05, V06, V07, STOP-02 | P2 |
| P2 | Effective thinking-state gate | `omp-p2-thinking-state` | `omp-p2-experimental-launch` | planned, manifest-only | REQ-STATE-01, V08, STOP-04 | P2 |
| P3 | Native RPC lifecycle adapter | `omp-p3-rpc-lifecycle` | `omp-p1-runtime-pin`, `omp-p1-identity-ancestry`, `omp-p2-experimental-launch` | planned, manifest-only | REQ-RPC-01, REQ-RPC-02, V09, V10, V11, V12 | P3 |
| P3 | Continuation and follow-up failure semantics | `omp-p3-continuation-followup` | `omp-p3-rpc-lifecycle` | planned, manifest-only | REQ-CONT-01, REQ-FOLLOW-01, V13, V14, STOP-05 | P3 |
| P3 | Real worker normal and abort E2E | `omp-p3-worker-live` | `omp-p2-extension-handshake`, `omp-p2-thinking-state`, `omp-p3-continuation-followup` | planned, manifest-only | REQ-RPC-02, REQ-LIVE-01, V10, V12, V15 | P3 |
| P3 | Real worker cleanup E2E | `omp-p3-cleanup-live` | `omp-p3-worker-live` | planned, manifest-only | REQ-CLEAN-01, REQ-CLEAN-02, V21, V22, STOP-09 | P3 |
| P3 | Focused and full regression loop | `omp-p3-regression` | `omp-p3-cleanup-live` | planned, manifest-only | REQ-REG-01, V23, full `tests/*.test.sh` loop, applicable lint | P3 |
| P4 | Tmux OMP ancestry and liveness classifier | `omp-p4-tmux-classifier` | `omp-p3-regression` | planned, manifest-only | REQ-BACKEND-01, V16, STOP-06 | P4 |
| P4 | Provisional tmux worker evidence | `omp-p4-tmux-provisional` | `omp-p4-tmux-classifier`, `omp-p3-worker-live` | planned, manifest-only | REQ-SCOPE-01, REQ-LIVE-01, V16, V25, provisional label | P4 |
| P5 | Herdr lifecycle parity | `omp-p5-herdr-parity` | `omp-p4-tmux-provisional` | planned, manifest-only | REQ-BACKEND-02, V17, STOP-06, STOP-08 | P5 |
| P6 | Primary continuity and supervision | `omp-p6-supervision-continuity` | `omp-p5-herdr-parity` | planned, manifest-only | REQ-WATCH-01, V18, STOP-05 | P6 |
| P6 | Startup policy and supervision protocol | `omp-p6-startup-policy` | `omp-p6-supervision-continuity` | planned, manifest-only | REQ-EXT-02, REQ-SCOPE-01, V18, V25 | P6 |
| P7 | Two-home isolation | `omp-p7-two-home-isolation` | `omp-p6-startup-policy` | planned, manifest-only | REQ-HOME-01, V19, STOP-07 | P7 |
| P7 | Sole-owner recovery | `omp-p7-recovery` | `omp-p7-two-home-isolation` | planned, manifest-only | REQ-REC-01, V20, STOP-06, STOP-07 | P7 |
| P7 | Complete cleanup and refusal matrix | `omp-p7-cleanup-complete` | `omp-p7-recovery` | planned, manifest-only | REQ-CLEAN-01, REQ-CLEAN-02, V21, V22, STOP-09 | P7 |
| P8 | Full live and repository verification | `omp-p8-full-validation` | all P7 tasks | planned, manifest-only | REQ-REG-01, REQ-LIVE-01, V17-V25, STOP-10, STOP-11, STOP-12 | P8 |
| P8 | First-class policy and documentation publication | `omp-p8-policy-publication` | `omp-p8-full-validation` and no open stop | planned, manifest-only | REQ-SCOPE-01, REQ-MAP-01, REQ-DOC-01, V25, all C01-C25, final Definition of Done | P8 |

## Phase and dependency rules

P0 is serialized because independent Red Team validation must inspect the plan and manifest before any implementation task exists in the live backlog.

P1 evidence tasks may run in parallel after O6 passes because runtime identity, discovery isolation, and host ancestry are separate evidence ledgers.

P2 launch, handshake, and state work is serialized at the brief-delivery gate, although handshake and state fixtures may run in parallel after launcher preflight.

P3 lifecycle and failure semantics must precede real worker E2E, and real worker E2E must precede cleanup and the full regression loop.

P4 is serialized after P3 because tmux liveness cannot be claimed from a fixture-only worker result.

P5 is serialized after provisional tmux evidence because Herdr parity requires the same native lifecycle contract and the same pinned runtime.

P6 supervision is serialized after backend parity because a watcher cannot claim liveness or successor ownership on an unverified backend.

P7 is serialized after supervision because multi-home recovery depends on the actual watcher and lock ownership contract.

P8 is serialized after every prior phase and has no bypass for a partial matrix.

After activation, Tasks Axi `blocked-by` edges provide readiness automatically.

Ordinary future tasks are not captain-held by default.

Only a real policy, product, destructive, or security decision may create a structured `needs:human` hold.

The current `needs:human` set is empty.

## Progress contract

Status and Bearings report one active phase at a time and do not calculate progress over all future manifest rows.

The current scoped denominator is the number of activated tasks in the active phase.

Manifest-only rows are excluded from the completed/total denominator until activation.

A task is complete only when its evidence artifact, acceptance rows, exit criterion, and rollback or containment result are recorded.

A task is blocked only with its requirement or STOP ID, owner, missing evidence, and containment action.

The captain-facing status fields are `phase`, `milestone`, `completed/total scoped tasks`, `branch`, `blockers`, `next gate`, and `needs:human` decisions with explicit options.

The active branch for this planning revision is `fm/omp-first-class-support-o5`.

The next gate is `omp-final-plan-redteam-o6` with required result `PASS`.

The current blocker is independent plan validation, not an implementation failure.

## Support-state reporting

P1 through P3 may report only the exact experimental worker label after their gates pass.

P4 may report only the provisional tmux worker label after its live matrix passes.

P5 through P7 may report backend, supervision, or recovery evidence only as gated internal evidence, never as public or verified support.

P8 is the only phase that may publish first-class verified support.

OMP remains absent from verified-harness allowlists, normal dispatch profiles, primary supervision selection, secondmate routing, recovery classifiers, and Herdr support claims until P8 publication.

## Red Team handoff checklist

O6 must verify the plan's pinned command surface and hashes against the O2 and O4 evidence.

O6 must verify that the noext contradiction is unresolved and remains a hard stop until a future runtime or hermeticity proof clears it.

O6 must verify every C01-C25 disposition has a requirement, owner, task, evidence row, gate, containment action, and captain field.

O6 must verify all five convergent weaknesses map to concrete tasks and acceptance evidence.

O6 must verify all twelve STOP rows prevent false success or premature support.

O6 must verify the current-code map includes secondmate positional parsing, raw launch, generated hook, send, continuity, all cleanup lists, and full regression ownership.

O6 must verify the manifest has no default captain holds and no newly activated P1-P8 implementation rows in `.agents/tasks/backlog.md` or `data/backlog.md`.

O6 must verify the full regression loop and live evidence requirements are explicit.

O6 must verify no captain choice is invented where the evidence-based BLOCK is sufficient.

## Tasks Axi commands

Use the explicit tracked manifest path for local artifact validation.

- `npx -y tasks-axi list --file .agents/tasks/backlog.md`
- `npx -y tasks-axi ready --file .agents/tasks/backlog.md`
- `npx -y tasks-axi render --file .agents/tasks/backlog.md`

The current `ready` result must contain zero implementation tasks because the manifest is awaiting O6.

Do not run `tasks-axi add` for any P1-P8 ID until O6 passes and the activation decision is recorded.

When activation is authorized, add the rows with the dependency IDs in this manifest and verify `ready` exposes only the first unblocked ordinary tasks.

## Handoff definition

This manifest is ready for O6 only when its plan pointer, stable IDs, dependencies, evidence rows, state labels, progress fields, and activation boundary are internally consistent.

The branch handoff must state that no OMP runtime support was implemented.

The branch handoff must state that `5be5e14` remains preserved and the new plan correction is separate.

The worktree must be clean and the commits must remain a local fast-forward candidate.
