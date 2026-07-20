# OMP Harness Integration - Tasks Axi Roadmap

This roadmap is the human-readable presentation of the OMP harness integration work.
The executable task records live in `.agent/tasks/backlog.md` and are owned by Tasks Axi, not by this document.
The revised plan at `.agents/plans/omp-harness-integration-plan.md` is the authority for every full contract detail; this roadmap only maps and points into it.

## Purpose

This roadmap maps the plan's ten implementation units U0 through U9 onto ten executable Tasks Axi backlog items.
Each backlog item carries its owning unit, goal, requirement IDs, acceptance examples, live-matrix scenarios, file surfaces, completion and verification evidence, and stop conditions.
The backlog encodes the plan's unit dependency graph as `blocked-by` edges so the ready queue always reflects what may start next.

## Canonical commands

Every backlog mutation and query must pass the backlog file explicitly with `--file .agent/tasks/backlog.md`.

- List every task: `tasks-axi list --file .agent/tasks/backlog.md`.
- Show one task in full: `tasks-axi show omp-u5-primary-extensions --full --file .agent/tasks/backlog.md`.
- Show what is unblocked and may start now: `tasks-axi ready --file .agent/tasks/backlog.md`.
- Normalize and re-render the backlog: `tasks-axi render --file .agent/tasks/backlog.md`.
- Start a unit when its blockers have cleared: `tasks-axi start omp-u0-early-detection-correctness --file .agent/tasks/backlog.md`.
- Close a shipped unit with its PR: `tasks-axi done omp-u2-identity-config --pr <url> --file .agent/tasks/backlog.md`.
- Close the U1 scout with its report: `tasks-axi done omp-u1-verification-ledger --report <path> --file .agent/tasks/backlog.md`.

## Phase order and dependency graph

The graph is acyclic because every edge points from a higher-numbered unit to lower-numbered units only.
U0 and U1 start in parallel because neither has a blocker.

| Unit | Task ID | Kind | Blocked by |
| --- | --- | --- | --- |
| U0 | omp-u0-early-detection-correctness | ship | (none) |
| U1 | omp-u1-verification-ledger | scout | (none) |
| U2 | omp-u2-identity-config | ship | U0, U1 |
| U3 | omp-u3-launch-profiles | ship | U1, U2 |
| U4 | omp-u4-worker-completion-extension | ship | U1, U3 |
| U5 | omp-u5-primary-extensions | ship | U1, U2, U3, U4 |
| U6 | omp-u6-startup-supervision | ship | U5 |
| U7 | omp-u7-liveness-controls | ship | U1, U3, U5, U6 |
| U8 | omp-u8-cleanup-recovery-trust | ship | U4, U5, U6, U7 |
| U9 | omp-u9-publish-and-gate | ship | U2, U3, U4, U5, U6, U7, U8 |

The linear critical path runs U1 then U2 then U3 then U4 then U5 then U6 then U7 then U8 then U9.
U0 is a self-contained early milestone that can land at any point before U9 and is not on the U1-through-U9 activation path.

## Early milestone versus first-class activation boundary

U0 is the captain's approved early-correctness milestone that fixes OMP misdetection and the option-safe `basename` crash and keeps non-OMP children under an OMP primary detecting as themselves.
U0 must not add `omp` to any first-class supervision allowlist, so a detected `omp` primary routes to the existing fail-safe unknown supervision fallback until the full adapter lands.
First-class OMP activation begins only when U1 through U9 supply the complete supervision, lifecycle, recovery, and verification contracts.
U6 is the unit that adds `omp` to the supervision allowlist, and only alongside its guard extension, so detection never outruns supervision.

## Requirement-to-task matrix

Every requirement R1 through R39 in the plan maps to at least one owning unit, exactly as the plan's unit Requirement tags represent it.

| Requirement | Owning unit(s) |
| --- | --- |
| R1 | U0 |
| R2 | U0 |
| R3 | U2 |
| R4 | U0 |
| R5 | U2 |
| R6 | U1, U3 |
| R7 | U3 |
| R8 | U1, U3 |
| R9 | U3 |
| R10 | U3 |
| R11 | U1, U4 |
| R12 | U4, U8 |
| R13 | U1, U4 |
| R14 | U1, U3, U4, U7 |
| R15 | U5, U6, U8 |
| R16 | U5, U6 |
| R17 | U5, U6 |
| R18 | U5, U6 |
| R19 | U4, U5, U6, U8 |
| R20 | U5, U6, U8 |
| R21 | U1, U7 |
| R22 | U1, U7 |
| R23 | U1, U7 |
| R24 | U1, U5, U7 |
| R25 | U4, U8 |
| R26 | U6, U7, U8 |
| R27 | U9 |
| R28 | U6, U9 |
| R29 | U9 |
| R30 | U0, U2, U3, U4, U5, U6, U7, U8, U9 |
| R31 | U0 |
| R32 | U0 |
| R33 | U1, U3 |
| R34 | U3 |
| R35 | U4, U8 |
| R36 | U5 |
| R37 | U5, U8 |
| R38 | U1, U7 |
| R39 | U9 |

The plan's U1 Requirement tag deliberately excludes R12 and R15 through R20, which are firstmate guarantees proven by U4 through U8 rather than OMP primitives the spike can observe.

## Acceptance-example ownership

Every acceptance example AE1 through AE42 is owned by at least one unit, and U9 re-runs the full AE1 through AE42 set as the final gate.
AE16 is the existing-harness regression example that every unit re-verifies.

| Unit | Acceptance examples |
| --- | --- |
| U0 | AE1, AE2, AE3, AE4, AE16, AE22, AE23, AE24 |
| U1 | AE5, AE6, AE7, AE8, AE9, AE10, AE11, AE12, AE13, AE14, AE17, AE18, AE19, AE20, AE21, AE22, AE31, AE32, AE37, AE38, AE39, AE42 |
| U2 | AE1, AE2, AE3, AE4, AE16, AE22 |
| U3 | AE5, AE16, AE17, AE18, AE39, AE40, AE41 |
| U4 | AE6, AE15, AE16, AE19, AE31, AE32, AE33 |
| U5 | AE7, AE8, AE9, AE10, AE11, AE12, AE16, AE17, AE21, AE25, AE26, AE27, AE28, AE29, AE30 |
| U6 | AE7, AE8, AE10, AE11, AE12, AE16, AE28, AE29 |
| U7 | AE13, AE14, AE16, AE20, AE21, AE28, AE36, AE38 |
| U8 | AE12, AE15, AE16, AE20, AE21, AE33, AE34, AE35, AE36 |
| U9 | AE1 through AE42 (the full acceptance set) |

## Live-matrix ownership

The plan's forty-row live verification matrix is produced by U1 as evidence and exercised across the units below, then re-run in full by U9.

| Unit | Live-matrix scenarios |
| --- | --- |
| U0 | Row 26 (non-OMP child detects as its own harness) |
| U1 | Produces the whole pre-merge live matrix; mandatory rows are native per-turn completion, primary stop, pre-tool blocking, idle and streaming follow-up, countable continuation, and Herdr hosting and classification, plus abnormal-completion (row 30), multi-turn (row 31), and N-consecutive-run behavior |
| U2 | Row 26 |
| U3 | Rows 2, 17, 39, 40 |
| U4 | Rows 6, 18, 19, 25, 30, 31, 32 |
| U5 | Rows 5, 8, 9, 10, 11, 12, 13, 22, 23, 27, 28, 29, 36, 37, 38 |
| U6 | Rows 1, 8, 9, 12, 13, 27, 28 |
| U7 | Rows 14, 15, 20, 21, 22, 27, 35 |
| U8 | Rows 5, 24, 25, 32, 33, 34, 35 |
| U9 | The full pre-merge live ledger, rows 1 through 40, with each corruption-sensitive row passing at least 20 consecutive runs |

## Stop conditions

The plan's stop conditions bound every unit and are reproduced there in full; the load-bearing ones for this task map are summarized here.

- OMP must expose native per-turn completion, primary stop, pre-tool block, idle-and-streaming follow-up, and a countable continuation mechanism, or U1 blocks the program.
- Herdr must be pre-verified in U1 to host and classify an OMP or Bun agent before Herdr parity is claimed, or Herdr support is a blocker or an explicitly staged tmux-first deferral.
- A named OMP launch must resolve the executable from a trusted absolute path, verify its provenance, and confirm a supported version before extensions load.
- An OMP primary extension must resolve its own `FM_HOME` fail-closed and never fall back to the shared code root.
- The turn-end guard must not recurse indefinitely or exhaust OMP continuations silently, and it may end loudly with a visible failure after its bounded allowance.
- The pre-merge live evidence must be sanitized of captured credentials before it is handed off and attached.
- Existing Claude, Codex, OpenCode, Pi, and Grok behavior and tests must remain unchanged.

## Evidence handoff

U1 produces one sanitized durable live-evidence artifact in which argv is redacted allowlist-style and captured environment values are redacted to variable names, with defined storage, access, and retention.
The implementation executor hands that sanitized artifact to the supervising firstmate session before repository validation begins.
U9 attaches the artifact as durable validation evidence only after redaction has passed.

## Release exit criteria

U9 declares OMP supported only after code, live evidence, documentation, and regressions agree.
`omp` is added to verified adapter lists only after U0 through U8 acceptance and every required live row passes, with each corruption-sensitive row passing at least 20 consecutive runs.
Targeted tests, repository lint, the no-mistakes pipeline, and CI must pass, and the final diff review must confirm no stale five-harness lists and no rename of the Herdr `Themis-<secondmate-id>` workspace label.
Documentation may call OMP verified only when both CI and the pre-merge live ledger pass and redaction is confirmed.

## Authority

The revised plan at `.agents/plans/omp-harness-integration-plan.md` is the single authority for full requirement text, acceptance examples, the complete live matrix, component design, and the Definition of Done.
This roadmap and the `.agent/tasks/backlog.md` records are a navigation and dispatch surface over that plan, not a second source of truth.
