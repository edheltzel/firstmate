# OMP Experimental Worker Spike - Planning Roadmap

This roadmap is the planning and dispatch map for the corrected OMP work.

The full contract is owned by `.agents/plans/omp-harness-integration-plan.md`.

The executable task records are owned by Tasks Axi in `.agents/tasks/backlog.md`.

This roadmap does not authorize implementation and does not claim OMP support.

## Current decision

The Red Team disposition is BLOCK for first-class or verified OMP support.

The only eventual implementation scope is an explicitly opt-in experimental tmux worker under an isolated temporary `FM_HOME`.

The experimental label is exactly `experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support`.

OMP remains absent from every verified-harness allowlist, normal dispatch profile, primary-supervisor protocol, secondmate path, recovery or liveness claim, and Herdr support claim.

This branch is planning-only because the captain narrowed the current work to documentation and tracking.

Commit `5be5e14` is the preserved, separate plan-correction commit.

No worker launcher, extension, test, cleanup integration, or support policy is implemented by the planning phase.

Every future implementation task is held with a captain hold until a new explicit authorization clears this branch's planning-only boundary.

## Authority and evidence baseline

The plan is the single owner for exact requirements, acceptance examples, S0 gates, hard stops, current-code surfaces, and the Definition of Done.

The plan records the revalidated runtime as `/Users/ed/.bun/bin/omp` resolving to `/Users/ed/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js`.

The pinned package is `@oh-my-pi/pi-coding-agent` version `17.1.5` with Bun `1.3.14` observed.

The pinned package manifest SHA-256 is `3574ab69ffc6108192110a87e8fa07edae67892fe2519b4d33c917c798c6a405`.

The pinned CLI SHA-256 is `9898943d1ac04994ed2747d0bcce9ce6e736ee0f04d00b51833294ef5d179f3b`.

The current command surface includes `omp launch [MESSAGES...] [FLAGS...]` and `omp launch --help` exits zero.

The broken `--no-extensions` plus explicit `-e` combination is prohibited because current OMP suppresses the explicit extension in that combination.

Host identity must use the resolved executable and argv ancestry because OMP child shells set mixed `OMPCODE=1` and `CLAUDECODE=1` markers that are not host identity.

The startup handshake must precede every task brief and must fail closed on missing, failed, duplicate, unexpected, replaced, path-mismatched, owner-mismatched, mode-mismatched, or hash-mismatched registration.

The effective thinking level must be read from OMP state and must match the requested policy before work starts.

Every future live claim must distinguish per-turn completion from terminal task completion and queue acknowledgement from actual follow-up delivery.

Every future failure path must make continuation exhaustion, follow-up suppression, missing terminal events, hidden extension failures, and cleanup failures visibly non-successful.

## Phase graph

The graph is intentionally linear through the experimental spike and stops at a fresh Red Team reassessment.

First-class work is a separate deferred branch that cannot start merely because the spike succeeds.

| Phase | Task ID | Kind | Dependency | Current state |
| --- | --- | --- | --- | --- |
| P0 | `omp-o5-plan-correction` | docs | none | Done in `5be5e14` |
| P1 | `omp-o5-spike-preflight` | scout | P0 | Captain-held |
| P2 | `omp-o5-spike-launch-isolation` | ship | P1 | Captain-held |
| P3 | `omp-o5-spike-handshake-state` | ship | P2 | Captain-held |
| P4 | `omp-o5-spike-live-lifecycle` | ship | P3 | Captain-held |
| P5 | `omp-o5-spike-cleanup-evidence` | ship | P4 | Captain-held |
| P6 | `omp-o5-redteam-reassessment` | scout | P5 | Captain-held |
| P7 | `omp-o5-firstclass-gates` | scout | P6 plus fresh authorization | Captain-held and blocked |
| P8 | `omp-o5-firstclass-integration` | ship | P7 plus every S0 gate | Captain-held and blocked |

P0 records the corrected plan only and contains no runtime or repository implementation.

P1 establishes a dated preflight ledger before any worker code is allowed.

P2 creates the opt-in launcher and isolated runtime boundary without adding OMP to normal Firstmate dispatch.

P3 makes extension registration and effective thinking state hard gates before the brief is delivered.

P4 proves one real normal streamed turn and one real abort or error path with fail-visible lifecycle semantics.

P5 proves real Firstmate task cleanup and records exact verification evidence.

P6 reopens the Red Team review and may leave first-class support blocked even if the worker spike passes.

P7 is a new evidence-only review of every first-class S0 gate and is not implied by P6 passing.

P8 is the only phase that could eventually change verified policy, and it requires a separate authorization after P7.

## Phase contracts

### P1 - Experimental spike preflight ledger

Re-run `command -v omp`, `readlink /Users/ed/.bun/bin/omp`, `omp --version`, `bun --version`, and package and CLI `shasum -a 256` checks.

Capture `omp launch --help` including its zero exit status and exact launch syntax.

Audit project, user, profile, plugin, `PI_CONFIG_DIR`, and `PI_CODING_AGENT_DIR` discovery inputs before choosing a launch vector.

Prove that ambient extension discovery is excluded without relying on the broken `--no-extensions` and explicit-extension combination.

Capture host executable and argv ancestry separately from child-shell marker values.

Stop with `blocked:` if discovery cannot be excluded, identity depends on mixed markers, or the pinned runtime has drifted without a new decision.

### P2 - Experimental worker launch and isolation

Use a separately named explicit opt-in entry point that is not an accepted harness name or normal dispatch profile.

Require an explicit temporary `FM_HOME` and refuse the active Firstmate home, repository root, and non-temporary homes.

Use only a dedicated tmux socket and task-specific tmux session.

Create fresh HOME, XDG config, data, state, cache, OMP profile, and empty project-root inputs.

Clear `PI_CONFIG_DIR` and `PI_CODING_AGENT_DIR` and preflight all discovery roots.

Use the pinned absolute executable and never pass the contradicted no-extensions flag combination.

Keep the path worker-only with no primary, secondmate, multi-home, recovery, or Herdr mode.

Stop if any launch path broadens those boundaries or accepts a normal Firstmate dispatch route.

### P3 - Handshake and effective state gate

Generate one canonical extension with restrictive directory and file modes.

Bind the handshake to the canonical path, expected content hash, task token, owner, mode, and exact registration set.

Require the extension handshake before any task instructions or worker brief are sent.

Reject missing, failed, duplicate, unexpected, replaced, path-mismatched, owner-mismatched, mode-mismatched, and hash-mismatched registration.

Query OMP state and verify the effective model and thinking level against the requested values.

Reject silent thinking downgrades such as requested `max` resolving to `xhigh`.

Stop if OMP reaches ready or accepts work after a required extension failure.

### P4 - Real normal and abort or error lifecycle

Run one real normal streamed RPC turn against a local unauthenticated mock OpenAI-compatible stream.

Require streamed assistant output, one `turn_end`, and one terminal `agent_end` with `isTerminal:true`.

Run one real abort or error turn against a deliberately slow or failing stream after the stream has started.

Require an abort acknowledgement plus a terminal event or typed process failure before cleanup.

Treat acknowledgements as queue acceptance rather than proof of follow-up start or completion.

Treat missing terminal events, duplicate turn signals, hidden extension errors, suppressed follow-ups, and normal-looking stops after errors as failures.

Keep continuation budget, follow-up delivery, terminal events, and visible failure semantics as future first-class gates rather than inferred spike support.

### P5 - Real cleanup and evidence

Record experimental task metadata before launch, including temporary root, generated extension, tmux socket, session, and isolated run root.

Invoke the real `bin/fm-teardown.sh` task path for both normal and abort or error outcomes.

Prove cleanup of generated extension, state, temporary files, RPC logs, process, tmux session, tmux socket, OMP profile, and isolated HOME.

Do not invoke normal dispatch, secondmate-home cleanup, watcher recovery, PR cleanup, or Herdr operations.

Record the date, exact versions, exact commands, exact output, exit statuses, redacted argv, handshake, thinking state, streams, terminal events, and cleanup assertions.

Run focused deterministic tests for every implemented contract, then the complete `for test_file in tests/*.test.sh; do bash "$test_file"; done` loop and `bin/fm-lint.sh` when shell files change.

Stop if any cleanup failure can look like success or if evidence is skipped, mocked, inferred, or inconclusive.

### P6 - Fresh Red Team reassessment

Compare the complete evidence record against every hard stop and S0 gate in the plan.

Preserve the experimental label even when all bounded worker checks pass.

Do not add OMP to any allowlist, profile, protocol, secondmate path, recovery classifier, or Herdr claim as part of reassessment.

Record unresolved evidence as a typed block rather than weakening a gate.

### P7 and P8 - Deferred first-class track

Require a new captain authorization before beginning any first-class gate work.

Reprove discovery isolation, host identity, extension startup, RPC lifecycle, continuation budget, follow-up delivery, backend semantics, two-home ownership, recovery, cleanup, and regression coverage.

Keep the runtime cap of eight distinct from a lower Firstmate continuation budget and surface every exhaustion or handler failure visibly.

Prove tmux and Herdr lifecycle behavior before either backend is called supported.

Prove primary, persistent secondmate, two-home, recovery, and complete cleanup ownership before any first-class allowlist change.

Update every owning documentation and test surface atomically only after all gates pass.

Run the full test loop, applicable shell lint, repository validation owner, and required live repetition matrix.

Never call OMP verified from a partial spike, a primitive runtime observation, a mocked transport, or a single successful turn.

## Tracking operations

Use the explicit backlog path for every query or mutation.

- `npx -y tasks-axi list --file .agents/tasks/backlog.md`
- `npx -y tasks-axi show omp-o5-spike-handshake-state --full --file .agents/tasks/backlog.md`
- `npx -y tasks-axi ready --file .agents/tasks/backlog.md`
- `npx -y tasks-axi list --state held --file .agents/tasks/backlog.md`
- `npx -y tasks-axi render --file .agents/tasks/backlog.md`

The ready queue must remain empty while this planning-only branch is active.

Each future task must be started only after its dependency evidence and captain hold are explicitly cleared.

Each completed task must record its durable report or review artifact before the next dependent task is considered.

## Handoff criteria

The branch is ready for guarded local fast-forward review only when the plan and roadmap commits are focused, the worktree is clean, and no implementation artifact remains.

The handoff must state that commit `5be5e14` remains preserved and that no OMP support was implemented.

The next worker must begin by reading the plan, this roadmap, the corresponding full backlog task, and the preserved reports before any implementation authorization is considered.
