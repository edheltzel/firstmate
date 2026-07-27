---
title: OMP staged support plan with Red Team traceability
type: feat
date: 2026-07-27
artifact_contract: ce-unified-plan/v1
artifact_readiness: pending-second-red-team-no-implementation-authority
product_contract_source: ce-plan-bootstrap
execution: code
---

# OMP staged support plan with Red Team traceability

## Authority and current state

This file is the single canonical owner for the OMP support contract, requirement ledger, architecture map, phases, validation matrix, hard stops, and Definition of Done.

The current artifact state is `pending second Red Team validation`.

The current plan is not implementation authority.

No OMP runtime, dispatch, test, cleanup, supervision, recovery, or support-policy implementation is authorized by this planning revision.

The second Red Team task is `omp-final-plan-redteam-o6`.

Implementation authority is blocked until that task returns `PASS` with no plan-blocking finding and its decision-hold inventory verifies clean.

A `CONDITIONAL PASS` does not clear implementation authority until every condition is closed and revalidated.

The preserved plan correction commit is `5be5e14`.

This revision is a separate documentation correction after that commit.

The committed tracking manifest is `.agents/tasks/roadmap.md`.

The tracked `.agents/tasks/backlog.md` contains no future implementation tasks until the second Red Team validates this plan and manifest.

The live firstmate backlog at `data/backlog.md` must not receive OMP implementation tasks before that validation.

The external task `omp-final-plan-redteam-o6` remains the only next validation gate and is already blocked on `omp-first-class-support-o5` in the live backlog.

## Support-state model

OMP uses three named support states that must never be collapsed into one label.

| State | What it permits | What it excludes |
| --- | --- | --- |
| Experimental worker-only | One explicit opt-in worker under a temporary isolated `FM_HOME` and a dedicated tmux session. | Verified allowlists, normal dispatch, primary supervision, secondmates, multi-home recovery, backend parity, Herdr support, and public support claims. |
| Provisional tmux worker | A bounded internal tmux worker path after the experimental evidence and a fresh Red Team gate pass. | Verified-harness allowlists, ordinary dispatch defaults, primary supervision, secondmates, multi-home recovery, Herdr parity, and public support claims. |
| First-class verified | OMP may enter verified-harness policy only after all required live and regression gates pass. | Nothing in the first-class contract may be waived because a worker spike or one backend passes. |

The experimental state is the only state that may be considered before the second Red Team approves the plan.

The provisional state still does not authorize normal Firstmate dispatch or a public claim.

The first-class state requires tmux and Herdr lifecycle parity, primary supervision, persistent secondmate ownership, multi-home recovery, complete cleanup, documentation, and the full regression loop.

Every user-facing or agent-facing result from the experimental state must carry exactly `experimental tmux worker; unverified; no primary, secondmate, recovery, or Herdr support`.

No state transition may occur on fixture-only, mocked, inferred, skipped, or inconclusive evidence.

## Scope fence and transitions

The current branch performs only plan and tracking work.

Phase P0 produces the canonical plan and a Red Team-ready tracking manifest.

The O6 Red Team must validate P0 before any future implementation task is activated.

The experimental worker sequence is P1 through P3.

The provisional tmux sequence is P4.

Backend parity is P5.

Primary supervision is P6.

Two-home ownership and recovery are P7.

First-class verification and policy publication are P8.

A phase may run only when its prerequisite phase has passed and its own go gate is explicit.

A phase failure leaves OMP in the prior support state and records a typed blocker.

No phase may weaken a Red Team S0 gate to preserve schedule.

## Pinned evidence baseline

The evidence reports were read in full before this revision.

The preserved incomplete plan is `fm/checkpoint-incomplete-omp-plan-c3:.agents/plans/omp-harness-integration-plan.md` at commit `4a0f3b2`.

The current Firstmate baseline used by the reports is `main` at `c6f4424a1923741d45aafffeb5bd4b8d425b55ef`.

The installed OMP executable is `/Users/ed/.bun/bin/omp`.

The executable resolves to `/Users/ed/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js`.

The package is `@oh-my-pi/pi-coding-agent` version `17.1.5`.

The observed Bun version is `1.3.14`.

The package manifest SHA-256 is `3574ab69ffc6108192110a87e8fa07edae67892fe2519b4d33c917c798c6a405`.

The CLI SHA-256 is `9898943d1ac04994ed2747d0bcce9ce6e736ee0f04d00b51833294ef5d179f3b`.

The reproducible identity commands are `command -v omp`, `readlink /Users/ed/.bun/bin/omp`, `omp --version`, `bun --version`, and `shasum -a 256 <package>/package.json <package>/dist/cli.js`.

The installed command surface includes `omp launch [MESSAGES...] [FLAGS]`.

The exact command `omp launch --help` returns usage and exit status zero on the pinned binary.

The relevant launch flags include `--model`, `--profile`, `--cwd`, `--mode`, `--no-session`, `--thinking`, `--extension`, `--no-extensions`, `--no-skills`, `--no-rules`, `--auto-approve`, and `--approval-mode`.

The prior claim that `omp launch` does not exist is false for the pinned runtime and must not reappear.

The direct RPC probe used `omp --mode rpc --no-session --no-skills --no-rules` with isolated HOME, XDG directories, profile, and project roots.

The direct probe with `--no-extensions --extension <path>` did not load the explicit extension.

The direct probe with `--extension <path>` loaded the factory, notification, and session-start markers before ready.

Installed source `src/main.ts:1103-1112` clears explicit extension paths when `parsed.noExtensions` is set.

Installed source `src/main.ts:1187-1195` skips CLI extension-root injection when that flag is set.

The `--no-extensions` plus explicit extension combination is therefore prohibited.

An isolated profile or HOME alone is not proof that project `.omp` settings, directory manifests, symlink aliases, or replacement between preflight and import are excluded.

The OMP host was observed as `bun /Users/ed/.bun/bin/omp ...` and did not export `OMPCODE` or `CLAUDECODE`.

OMP child-shell source `pi-utils/src/procmgr.ts:38-48` sets both `OMPCODE=1` and `CLAUDECODE=1`.

Host identity must use executable and argv ancestry rather than mixed child markers.

OMP source `src/model/model-controls.ts:470-510` resolves requested thinking through model capability.

The effective `get_state.thinkingLevel` can be `xhigh` when the request says `max`.

OMP source `src/session/agent-session.ts:3051-3057` enforces a runtime continuation cap of eight.

Runtime cap exhaustion logs and returns a normal-looking stop unless the adapter owns a lower visible budget.

OMP source `src/extensibility/extensions/runner.ts:627-667` turns handler throw, timeout, or abort into an error and undefined result.

OMP source `src/session/agent-session.ts:5272-5294` can suppress automatic follow-up resume after interrupt, retry, or an invalid transcript tail.

OMP source `src/rpc/rpc-mode.ts:1026-1034` acknowledges follow-up queueing rather than eventual turn start.

Herdr `0.7.5-preview` directly recognized a running `bun ... omp` process as `agent:"omp", agent_status:"idle"` in a named lab.

That Herdr observation is a narrow positive prerequisite and not full Herdr or Firstmate support evidence.

The current tmux backend recognizes only its known commands and classifies Bun and other unknown wrappers as `unknown`.

Unknown must remain neither alive nor dead for respawn purposes until a proven OMP ancestry classifier exists.

## Evidence classes and missing evidence

Direct evidence is an observation from the pinned executable, current source, or a real Firstmate path with an exact command and output.

Source evidence is a current installed or repository source-path observation that still requires an integration test before it becomes a support claim.

Inference is a design consequence derived from direct or source evidence and must not be labeled as a pass.

Missing live evidence is an explicit gate and is never silently filled by a fixture or primitive RPC observation.

| Evidence item | Class | Current conclusion | Still required |
| --- | --- | --- | --- |
| Binary, package, version, Bun, hashes, and launch help | Direct | Pinned identity is reproducible. | Re-run in the future task environment before loading extensions. |
| No-extensions contradiction | Direct plus source | The documented flag combination is unsafe. | Runtime fix or complete hermetic discovery exclusion and replacement test. |
| Host argv and child markers | Direct plus source | Host and child identity are distinct. | Firstmate ancestry, nested shell, PID reuse, and lock-holder tests. |
| Thinking resolution | Source plus direct state requirement | Requested level is not proof of effective level. | Live `get_state` check before brief delivery. |
| Continuation cap and follow-up suppression | Source | Native behavior can look successful while work is not delivered. | Integrated lower-budget, failure-visible continuation and follow-up E2E. |
| Extension loader error continuation | Source plus direct probe | Ready is not extension health. | Startup handshake and fail-closed launcher E2E. |
| Herdr OMP idle recognition | Direct narrow lab observation | Recognition exists for version and idle state. | Full Herdr lifecycle, liveness, recovery, and ownership E2E. |
| Current Firstmate seams | Source | Several dispatch, continuity, and cleanup owners were omitted from the previous plan. | Phase tasks must touch and test every mapped owner. |
| Primitive RPC rows | Direct primitive observation | They are not Firstmate integration evidence. | Worker, watcher, backend, recovery, and teardown evidence. |

## Requirement ledger

The requirement IDs below are the stable join keys used by the phase manifest, compliance matrix, validation matrix, and future task records.

| ID | Requirement | Owner and evidence rule |
| --- | --- | --- |
| REQ-SCOPE-01 | Keep experimental, provisional tmux, and first-class verified support as separate named states with exact exclusions. | This plan owns the state model; every result label and policy update must point here. |
| REQ-EVID-01 | Pin binary, package, version, Bun, hashes, launch help, RPC vector, date, commands, and output. | Evidence ledger owner; direct output is required before each runtime-dependent phase. |
| REQ-DISC-01 | Do not use the contradicted no-extensions plus explicit-extension vector. | Launcher owner; ambient discovery must be excluded before import or the phase blocks. |
| REQ-DISC-02 | Audit project, profile, user, plugin, symlink, manifest, and replacement inputs before required extension import. | Launcher and extension trust owners; hermetic negative tests are required. |
| REQ-ID-01 | Identify the OMP host through resolved executable and argv ancestry. | `bin/fm-harness.sh` and `bin/fm-lock.sh` future owner; environment markers are not host authority. |
| REQ-ID-02 | Scrub or override inherited mixed child markers before nested non-OMP Firstmate launches. | Spawn environment owner; mixed-marker and nested-shell tests are required. |
| REQ-EXT-01 | Require canonical path, owner, mode, expected hash, task token, and exact registration set. | Generated extension and launcher owner; replacement and alias tests are required. |
| REQ-EXT-02 | Fail before brief or charter delivery on missing, failed, duplicate, unexpected, or replaced mandatory registration. | Startup handshake owner; ready without handshake is failure. |
| REQ-STATE-01 | Verify effective model and thinking state with `get_state` before work. | Launch gate owner; mismatch is a typed launch failure or explicitly approved map. |
| REQ-RPC-01 | Define frame parsing, chunk reassembly, startup timeout, ready, start, stream, turn-end, terminal agent-end, state, follow-up, steer, abort, invalid input, exit, and resume semantics. | OMP-native RPC adapter owner; primitive observations are insufficient. |
| REQ-RPC-02 | Treat missing terminal events, duplicate events, process loss, and malformed frames as typed visible failures. | RPC adapter and test owner; no normal-looking stop may hide a failure. |
| REQ-CONT-01 | Own a continuation budget below eight with per-cycle counts, reset rules, and one visible failure for throw, timeout, abort, or exhaustion. | Turn-end and supervision owner; live and deterministic cases are required. |
| REQ-FOLLOW-01 | Prove eventual follow-up turn start after idle, streaming, interrupt, provider or tool error, invalid tail, and queue suppression. | Send and RPC owners; queue acknowledgement is not delivery evidence. |
| REQ-WATCH-01 | Restore continuity by proving successor readiness and lock ownership before wake, with bounded retry and typed failure. | `docs/watcher-continuity.md`, watcher arm, pretool, and turn-end owners. |
| REQ-BACKEND-01 | Preserve unknown-is-not-dead and prove OMP ancestry/liveness for tmux states. | `bin/backends/tmux.sh` and `bin/fm-backend.sh`; unknown must not respawn. |
| REQ-BACKEND-02 | Prove Herdr ready, prompt, stream, follow-up, steer, abort, exit, resume, idle, and dead-owner behavior before parity. | `bin/backends/herdr.sh` and Herdr live evidence owner. |
| REQ-HOME-01 | Prove two real isolated homes have separate locks, state, projects, extensions, watchers, and wake destinations. | `FM_HOME` and lock owners; real two-home E2E is required. |
| REQ-REC-01 | Prove restart and recovery preserve one owner and never duplicate wake or respawn unknown. | `fm-crew-state.sh`, bootstrap, backend, and recovery owners. |
| REQ-CLEAN-01 | Enumerate and clean nested hooks/state, top-level hooks/state, temp, PR poll, extension, watcher, backend, and secondmate-home artifacts. | `bin/fm-teardown.sh` owner; real generated artifacts are required. |
| REQ-CLEAN-02 | Preserve dirty, unlanded, and unresolved-decision refusal and make cleanup failure visible. | Teardown and decision-hold owners; refusal tests are mandatory. |
| REQ-MAP-01 | Include secondmate positional parsing, raw launch, generated hook, send, continuity, all cleanup lists, and full regression owners. | This plan owns the inventory; future code changes must update the nearest owner docs. |
| REQ-REG-01 | Run every existing `tests/*.test.sh`, focused OMP tests, applicable lint, and all supported harness/backend axes. | `.no-mistakes.yaml:22-28` and repository test owner; a shortened list is not sufficient. |
| REQ-LIVE-01 | Require live evidence for worker, watcher, tmux, Herdr, two-home, recovery, and teardown claims. | Evidence ledger owner; skipped, mocked, inferred, or inconclusive rows block promotion. |
| REQ-LINK-01 | Validate each external source link at the pinned commit and classify individually stale links. | Evidence documentation owner; no blanket stale-link claim. |
| REQ-MON-01 | Expose current phase, milestone, scoped completed/total, branch, blockers, next gate, and explicit `needs:human` decisions. | `.agents/tasks/roadmap.md` owner; progress excludes future unscheduled phases. |

## Architecture and ownership map

The plan assigns each contract to one owning code or documentation surface.

Future task records point to these owners instead of copying their contracts.

| Contract or seam | Current owner | Future OMP owner and required evidence |
| --- | --- | --- |
| Harness identity and verified-name policy | `bin/fm-harness.sh` | `omp-p1-identity-ancestry`; ancestry and marker tests; no allowlist change before P8. |
| Lock identity and holder classification | `bin/fm-lock.sh` | `omp-p1-identity-ancestry`; lock-holder and PID-reuse tests. |
| Dispatch selection and effort validation | `bin/fm-dispatch-select.sh` and `bin/fm-bootstrap.sh` | `omp-p8-policy-publication`; invalid effort and stale profile tests. |
| Ordinary and secondmate launch parsing | `bin/fm-spawn.sh`, including `:449-466` | `omp-p2-experimental-launch` and `omp-p8-policy-publication`; positional, config, and role tests. |
| Raw launch escape hatch | `bin/fm-spawn.sh` raw-launch path | `omp-p1-runtime-pin`; keep it explicitly unverified and test rejection of unsupported adapter routes. |
| Generated worker hook | `bin/fm-spawn.sh:1222-1323` | `omp-p2-extension-handshake`; test generation, mode, token, hash, and cleanup. |
| Worker startup and task brief delivery | Experimental launcher future owner | `omp-p2-experimental-launch`; no brief before handshake and state gate. |
| Role-scoped environment and `FM_HOME` | `docs/configuration.md` plus producing script headers | `omp-p2-experimental-launch`; fresh HOME/XDG/profile and fail-closed home tests. |
| Send, steer, and settle semantics | `bin/fm-send.sh:194-227` | `omp-p3-rpc-lifecycle`; queue acceptance versus actual turn start tests. |
| Continuation and turn-end enforcement | `bin/fm-turnend-guard.sh`, native integrations, and `docs/turnend-guard.md` | `omp-p3-continuation-followup` and `omp-p6-supervision-continuity`; lower budget and typed failure tests. |
| Pretool blocking and checker spawn | `bin/fm-continuity-pretool-check.sh` and its test | `omp-p6-supervision-continuity`; OMP-native contract required, not a Pi or Claude import. |
| Watcher continuity and successor ordering | `docs/watcher-continuity.md` and watcher arm protocol | `omp-p6-supervision-continuity`; successor-before-wake, lock recheck, retry, and failure evidence. |
| Backend liveness and recovery | `bin/fm-backend.sh`, `bin/backends/tmux.sh`, `bin/backends/herdr.sh`, `bin/fm-crew-state.sh` | `omp-p4-tmux-classifier`, `omp-p5-herdr-parity`, and `omp-p7-recovery`; unknown and dead-owner tests. |
| Two-home ownership | `FM_HOME` layout in `docs/configuration.md`, `bin/fm-lock.sh`, and state metadata | `omp-p7-two-home-isolation`; real separate lock, state, project, extension, watcher, and wake paths. |
| Teardown and residue refusal | `bin/fm-teardown.sh:1069-1091` and `:1181-1277` | `omp-p3-cleanup-live` and `omp-p7-cleanup-complete`; all nested/top-level and dirty/unlanded surfaces. |
| Secondmate lifecycle | `bin/fm-spawn.sh`, bootstrap, secondmate provisioning, and secondmate tests | `omp-p7-recovery` and `omp-p8-policy-publication`; no secondmate claim before P7. |
| Supervision instructions and support docs | `bin/fm-supervision-instructions.sh`, `docs/supervision-protocols/`, `AGENTS.md`, and `harness-adapters` | `omp-p8-policy-publication`; update only after all gates and supported-axis regressions. |
| Regression ownership | `.no-mistakes.yaml:22-28` and every `tests/*.test.sh` | `omp-p3-regression` and `omp-p8-full-validation`; full loop is mandatory. |
| Source and link evidence | OMP evidence record and package manifest | `omp-p1-runtime-pin` and `omp-p8-policy-publication`; pin each link and command. |

Pi and Claude extensions are behavioral references only.

No OMP implementation may import Pi APIs, Pi event types, or fail-open helper behavior without a separate OMP-native equivalence proof.

## Phased roadmap and task manifest

All task IDs in this section are stable manifest IDs, not live backlog entries.

They become executable Tasks Axi records only after `omp-final-plan-redteam-o6` passes and the manifest is deliberately activated.

The manifest state `planned` is not a captain hold.

After activation, ordinary tasks become ready automatically when their `blocked-by` dependencies clear.

Only a genuine product or policy choice may create `needs:human`.

There is no current captain choice in this revision.

| Phase | Milestone | Task ID | Depends on | Parallelism | Current manifest state |
| --- | --- | --- | --- | --- | --- |
| P0 | Plan correction and validation | `omp-o5-plan-traceability` | none | serialized | complete in this revision |
| P0 | Independent second Red Team | `omp-final-plan-redteam-o6` | `omp-o5-plan-traceability` | serialized | queued in live backlog, no implementation |
| P1 | Runtime identity ledger | `omp-p1-runtime-pin` | O6 PASS | parallel with P1 peers | planned |
| P1 | Discovery and flag safety ledger | `omp-p1-discovery-isolation` | O6 PASS | parallel with P1 peers | planned |
| P1 | Host ancestry identity ledger | `omp-p1-identity-ancestry` | O6 PASS | parallel with P1 peers | planned |
| P2 | Experimental worker launcher | `omp-p2-experimental-launch` | all P1 tasks | serialized | planned |
| P2 | Mandatory extension handshake | `omp-p2-extension-handshake` | launcher preflight | parallel with state gate | planned |
| P2 | Effective thinking state gate | `omp-p2-thinking-state` | launcher preflight | parallel with handshake | planned |
| P3 | Native RPC lifecycle adapter | `omp-p3-rpc-lifecycle` | P1 identity and launcher | parallel with cleanup design | planned |
| P3 | Continuation and follow-up failure semantics | `omp-p3-continuation-followup` | RPC lifecycle | serialized | planned |
| P3 | Real worker normal and abort E2E | `omp-p3-worker-live` | handshake, state, RPC | serialized | planned |
| P3 | Real worker cleanup E2E | `omp-p3-cleanup-live` | worker E2E | serialized | planned |
| P3 | Focused and full regression loop | `omp-p3-regression` | cleanup E2E | serialized | planned |
| P4 | Tmux OMP ancestry and liveness classifier | `omp-p4-tmux-classifier` | P3 regression | serialized | planned |
| P4 | Provisional tmux worker evidence | `omp-p4-tmux-provisional` | classifier and all P3 tasks | serialized | planned |
| P5 | Herdr lifecycle parity | `omp-p5-herdr-parity` | provisional tmux evidence | serialized | planned |
| P6 | Primary continuity and supervision | `omp-p6-supervision-continuity` | Herdr parity | serialized | planned |
| P6 | Startup policy and protocol | `omp-p6-startup-policy` | continuity | serialized | planned |
| P7 | Two-home isolation | `omp-p7-two-home-isolation` | startup policy | serialized | planned |
| P7 | Sole-owner recovery | `omp-p7-recovery` | two-home isolation | serialized | planned |
| P7 | Complete cleanup and refusal matrix | `omp-p7-cleanup-complete` | recovery | serialized | planned |
| P8 | Full live and regression verification | `omp-p8-full-validation` | all P7 tasks | serialized | planned |
| P8 | First-class policy and documentation publication | `omp-p8-policy-publication` | full validation and no open stops | serialized | planned |

### P0 - Plan correction and second Red Team gate

Prerequisite: the O2, O3, and O4 reports and preserved plan have been read in full.

`omp-o5-plan-traceability` outputs this canonical plan, the manifest roadmap, and a Tasks Axi artifact with no implementation entries.

Its deterministic validation is Markdown parsing, link/path checks, Tasks Axi render, and `ready` showing no implementation work.

Its live evidence is none because this phase changes documentation only.

Its exit criterion is a clean focused commit and a queued O6 Red Team task blocked on this plan task.

Its go gate is O6 `PASS` with no plan-blocking finding.

Its rollback is documentation-only revert; it cannot change OMP runtime or support state.

`omp-final-plan-redteam-o6` must attack every C01-C25 row, every phase dependency, every task, every evidence requirement, every gate, every rollback, every progress field, and every decision classification.

O6 is serialized before P1 and before any implementation task is added to the live backlog.

### P1 - Evidence and launch boundary

Prerequisite: O6 passes and the manifest is activated without adding OMP to verified policy.

`omp-p1-runtime-pin` records the exact binary, package, version, Bun, hashes, command surface, RPC vector, date, output, and link commits.

`omp-p1-discovery-isolation` proves whether ambient discovery can be excluded without the broken flag combination.

`omp-p1-identity-ancestry` proves host executable and argv identity through mixed markers, nested shells, PID reuse, and lock-holder cases.

The three P1 tasks may run in parallel because they use separate evidence ledgers.

P1 deterministic tests cover command parsing, hash mismatch, discovery-root inventory, symlink and manifest aliases, marker precedence, and option-like command names.

P1 live evidence must use the pinned runtime and a controlled temporary home.

P1 documentation updates only the evidence ledger and owner pointers.

P1 exits only when discovery is hermetic or the plan records a runtime fix as a blocker, identity is ancestry-based, and every exact command output is retained.

P1 go requires no `STOP-01` or `STOP-03` condition.

P1 rollback removes the temporary evidence root and leaves all verified lists, dispatch, and supervision unchanged.

### P2 - Experimental worker implementation boundary

Prerequisite: all P1 tasks pass without a discovery or identity hard stop.

`omp-p2-experimental-launch` is a separately named opt-in command and is not a harness accepted by normal dispatch.

It requires a temporary isolated `FM_HOME`, fresh HOME and XDG trees, a unique OMP profile, empty project root, cleared `PI_CONFIG_DIR` and `PI_CODING_AGENT_DIR`, and a dedicated tmux socket and session.

It refuses the active Firstmate home, repository root, and non-temporary homes.

It uses the pinned absolute executable and never passes `--no-extensions` with an explicit extension.

`omp-p2-extension-handshake` generates one canonical extension and requires its startup sentinel, task token, canonical path, expected hash, owner, mode, and exact registration set before the brief.

It rejects missing, failed, duplicate, unexpected, path-mismatched, owner-mismatched, mode-mismatched, hash-mismatched, and replaced registration.

`omp-p2-thinking-state` reads `get_state` and rejects an effective thinking level that differs from the request.

P2 deterministic tests cover every handshake and state mismatch.

P2 live evidence is limited to a worker process and does not claim primary, secondmate, multi-home, recovery, backend parity, or Herdr support.

P2 documentation records the exact experimental label and keeps OMP absent from all verified policy surfaces.

P2 exits only when no task instructions can reach OMP before both handshake and state gates pass.

P2 go is the minimum experimental implementation gate and does not promote support state.

P2 rollback kills the recorded tmux session and removes the generated extension and temporary home through the task cleanup path.

### P3 - Worker lifecycle, failure visibility, and cleanup

Prerequisite: P2 launcher, handshake, and state gates pass.

`omp-p3-rpc-lifecycle` defines OMP-native frame parsing, chunk reassembly, startup timeout, ready negotiation, `agent_start`, streamed messages, `turn_end`, terminal `agent_end`, `get_state`, follow-up, steer, abort, invalid input, process exit, and resume.

`omp-p3-continuation-followup` owns a Firstmate continuation budget below eight and persists per-cycle counts.

It tests handler throw, timeout, abort signal, repeated continuation, cap exhaustion, reset after normal completion, reset after abort, abort-plus-follow-up, invalid-tail follow-up, slow streaming, provider or tool error, queued-message suppression, and eventual turn start.

`omp-p3-worker-live` runs one real normal streamed turn and one real abort or error path against a controlled local stream.

The normal path requires streamed output, one `turn_end`, and one terminal `agent_end` with `isTerminal:true`.

The failure path requires an abort acknowledgement plus a terminal event or typed process failure before cleanup.

Missing terminal event, duplicate terminal event, dropped frame, hidden extension error, queued follow-up without turn start, and normal-looking stop after error are failures.

`omp-p3-cleanup-live` invokes the real `bin/fm-teardown.sh` task path and inspects process, tmux, extension, state, temp, profile, and isolated-home residue.

`omp-p3-regression` runs focused tests, then `for test_file in tests/*.test.sh; do bash "$test_file"; done`, and `bin/fm-lint.sh` when shell files change.

P3 deterministic tests may establish parsing and state transitions, but live evidence is mandatory for streamed turns, abort, terminal events, process exit, and real teardown.

P3 exits only when every failure can be distinguished from success and cleanup failure cannot be hidden.

P3 go permits only the experimental worker label.

P3 rollback leaves normal Firstmate dispatch and all supported harnesses unchanged and removes the isolated task artifacts.

### P4 - Provisional tmux worker state

Prerequisite: P3 passes and the O6 decision remains scoped to the worker contract.

`omp-p4-tmux-classifier` either proves Bun OMP ancestry and state transitions or retains `unknown` for every unproven wrapper.

It tests running, idle, streaming, interrupted, dead owner with a surviving shell, and unknown-wrapper states.

It must never treat `unknown` as alive or dead for respawn.

`omp-p4-tmux-provisional` re-runs the real worker matrix under the dedicated tmux backend and publishes only the provisional tmux worker label.

P4 deterministic tests cover classifier input and no-respawn-on-unknown.

P4 live evidence covers tmux ready, prompt, stream, abort, exit, and cleanup.

P4 documentation records backend-specific provisional scope and keeps normal dispatch, primary, secondmate, recovery, Herdr, and public support excluded.

P4 exits only when tmux evidence is complete or the provisional state remains blocked.

P4 rollback disables the experimental command and removes only its isolated artifacts.

### P5 - Herdr backend parity

Prerequisite: P4 provisional tmux evidence passes.

`omp-p5-herdr-parity` starts from the narrow `0.7.5-preview` idle-recognition observation but does not treat it as parity.

It proves Herdr ready, prompt, stream, follow-up, steer, abort, exit, resume, idle, dead-owner, and cleanup behavior for the pinned OMP runtime.

It proves Firstmate liveness and recovery observe the same owner rather than trusting stale pane text.

P5 deterministic tests cover command ancestry, agent recognition, no-agent after exit, and unknown handling.

P5 live evidence is mandatory for every lifecycle and recovery row because Herdr registration is external runtime state.

P5 documentation updates only the empirical backend record and keeps the state provisional until P8.

P5 exits with parity evidence or a durable blocker that prevents first-class support.

P5 rollback leaves tmux provisional scope intact and makes no Herdr claim.

### P6 - Primary supervision and continuity

Prerequisite: P5 backend parity passes.

`omp-p6-supervision-continuity` defines an OMP-native watcher extension and ownership for pretool checks, turn-end handling, watcher arm, successor readiness, session-lock recheck, bounded retry, single-flight, failed follow-up, hung successor, and typed retry exhaustion.

It does not import Pi or Claude extension APIs or preserve their fail-open behavior.

`omp-p6-startup-policy` adds OMP to any supervision protocol only alongside the mandatory guard and handshake evidence.

Deterministic tests cover successor-before-wake, lock change, retry, checker spawn, pretool failure, turn-end failure, and one visible failure per cycle.

Live evidence covers two consecutive wakes, successor verification, a wake after continuation, and recovery after interrupted or failed follow-up.

P6 documentation updates `docs/watcher-continuity.md`, supervision protocol ownership, and turn-end pointers only after tests pass.

P6 exits with primary supervision evidence or leaves OMP outside primary policy.

P6 rollback removes OMP protocol selection and leaves existing primary protocols unchanged.

### P7 - Two-home ownership, recovery, and complete cleanup

Prerequisite: P6 supervision passes.

`omp-p7-two-home-isolation` runs two real Firstmate homes sharing the code root with distinct `FM_HOME`, locks, projects, state, extensions, watchers, and wake destinations.

`omp-p7-recovery` kills and restarts worker, primary, and secondmate owners and proves one valid owner, one wake, correct identity, and no respawn of unknown wrappers.

`omp-p7-cleanup-complete` exercises nested worktree hooks and state, top-level hooks and state, task temp, PR poll, generated extension, watcher process, backend process, secondmate-home artifacts, dirty work, unlanded work, and unresolved-decision refusal.

P7 deterministic tests cover path ownership, lock separation, stale markers, duplicate recovery, and refusal behavior.

P7 live evidence is mandatory for process ownership, restart, recovery, and complete teardown.

P7 documentation updates only the nearest ownership and cleanup references.

P7 exits only when no duplicate owner or residue can look like success.

P7 rollback tears down both isolated homes and restores the prior supported state.

### P8 - First-class verification and policy publication

Prerequisite: P1 through P7 pass with no open hard stop.

`omp-p8-full-validation` runs every required live row, every focused test, every existing `tests/*.test.sh` script, applicable shell lint, and the repository validation owner.

It preserves redacted evidence with exact dates, versions, commands, output, exit status, process ancestry, state, stream, terminal, recovery, and cleanup observations.

It proves current Claude, Codex, OpenCode, Pi, Grok, secondmate, backend autodetection, watcher, recovery, and cleanup behavior is unchanged.

`omp-p8-policy-publication` updates verified allowlists, normal dispatch, primary supervision, secondmate routing, recovery, docs, and support claims atomically only after the full evidence ledger passes.

P8 deterministic tests cover stale five-harness lists, profile validation, documentation links, and all existing regression suites.

P8 live evidence requires tmux and Herdr, two homes, recovery, terminal, continuation, follow-up, and cleanup rows.

P8 exits with first-class verified support only when every live row passes and no decision or hard stop remains.

P8 rollback is a clean revert before any public or verified policy publication.

## Red Team C01-C25 compliance matrix

The disposition values mean `incorporated` is a concrete plan requirement with a future task and acceptance evidence, `deferred with blocking gate` is intentionally staged but cannot promote support, and `unresolved and plan-blocking` is an active no-go condition.

No row marked incorporated means the runtime behavior has already passed.

| Finding | Disposition | Plan requirement | Owner and task | Deterministic acceptance and live evidence | Exit, containment, and captain field |
| --- | --- | --- | --- | --- | --- |
| C01 | incorporated | REQ-ID-01, REQ-ID-02 | `fm-harness.sh`, `fm-lock.sh`; `omp-p1-identity-ancestry` | Mixed `OMPCODE` and `CLAUDECODE`, nested shell, PID reuse, and lock-holder tests plus argv capture. | Failure keeps OMP out of policy; progress shows identity blocker. |
| C02 | incorporated | REQ-ID-01 | Harness and lock owners; `omp-p1-identity-ancestry` | Compare current O3 marker premise with ancestry-based expected result in deterministic tests. | Stale marker logic is removed before implementation; no human choice. |
| C03 | incorporated | REQ-EVID-01 | Evidence ledger and launcher; `omp-p1-runtime-pin` | Exact `omp launch --help`, version, package, Bun, and hashes with output and status. | Runtime drift blocks P1; progress shows pinned-runtime blocker. |
| C04 | unresolved and plan-blocking | REQ-DISC-01, REQ-DISC-02 | Launcher and extension trust; `omp-p1-discovery-isolation` | Factory probe for noext, project settings, manifests, symlinks, aliases, and replacement between preflight and import. | Do not implement or claim even experimental work if discovery is not hermetic; no human choice. |
| C05 | incorporated with blocking gate | REQ-DISC-02, REQ-EXT-01 | Extension loader and launcher; `omp-p2-extension-handshake` | Same path, symlink alias, explicit/discovered alias, directory manifest, and replacement/hash tests. | Any alias or replacement failure blocks handshake; progress shows trust blocker. |
| C06 | incorporated | REQ-EXT-01, REQ-EXT-02 | Generated extension and startup; `omp-p2-extension-handshake` | Owner, mode, canonical path, hash, token, exact set, and isolated discovery checks. | No handshake means no brief; rollback removes generated extension. |
| C07 | incorporated | REQ-EXT-02 | Startup gate; `omp-p2-extension-handshake` | Required extension failure while OMP reaches ready must yield pre-brief abort, not ready acceptance. | Ready without handshake is a hard stop; progress shows startup blocker. |
| C08 | incorporated | REQ-STATE-01 | Launcher state gate; `omp-p2-thinking-state` | `get_state` rejects requested `max` becoming `xhigh` unless a separately documented map exists. | Mismatch blocks launch; no human choice is invented. |
| C09 | incorporated with blocking gate | REQ-RPC-01, REQ-LIVE-01 | OMP-native adapter; `omp-p3-rpc-lifecycle`, `omp-p3-worker-live` | Reclassify primitive PASS rows and require integrated extension E2E for each claimed lifecycle behavior. | Primitive evidence cannot promote support; progress shows live-evidence gap. |
| C10 | incorporated | REQ-CONT-01 | Turn-end and continuation owner; `omp-p3-continuation-followup` | Lower budget, reserved counts, throw, timeout, abort, repeated continuation, cap, reset, and one visible failure. | Hidden cap or normal stop blocks; rollback leaves no supervision claim. |
| C11 | incorporated | REQ-FOLLOW-01 | `fm-send.sh`, RPC, watcher; `omp-p3-continuation-followup`, `omp-p6-supervision-continuity` | Abort, provider/tool error, invalid tail, slow stream, queued state, `agent_start`, and eventual turn-start tests. | Queue acknowledgement without turn is failure; progress shows delivery blocker. |
| C12 | incorporated | REQ-RPC-02, REQ-LIVE-01 | Worker completion owner; `omp-p3-worker-live` | Multiple turns, abort, tool/provider error, extension throw/timeout, dropped callback, duplicate event, and process exit. | Missing exact-once signal is typed failure; no cleanup success inferred. |
| C13 | incorporated with blocking gate | REQ-BACKEND-01 | `tmux.sh`, backend owner; `omp-p4-tmux-classifier` | Running, idle, streaming, interrupted, shell-after-owner, dead owner, and unknown wrapper states. | Unknown stays unknown and never respawns; provisional state remains blocked. |
| C14 | deferred with blocking gate | REQ-BACKEND-02 | `herdr.sh`; `omp-p5-herdr-parity` | Preserve versioned idle recognition, then run ready, prompt, stream, follow-up, steer, abort, exit, resume, and recovery. | Narrow positive fact permits no parity claim; captain sees Herdr gate. |
| C15 | incorporated | REQ-SCOPE-01, REQ-BACKEND-02 | State model; `omp-p4-tmux-provisional`, `omp-p5-herdr-parity`, `omp-p8-policy-publication` | State transition tests and docs reject first-class wording during tmux-only phases. | No Herdr evidence means no first-class state; no human choice. |
| C16 | incorporated | REQ-BACKEND-01, REQ-REC-01 | Backend and recovery owners; `omp-p4-tmux-classifier`, `omp-p7-recovery` | Unknown-is-not-dead, owner process state, successor ordering, and recovery tests. | Conservative unknown remains containment; progress shows recovery gate. |
| C17 | incorporated | REQ-MAP-01 | `fm-spawn.sh:449-466`, raw launch, dispatch; `omp-p2-experimental-launch`, `omp-p8-policy-publication` | Positional parser, home-path ambiguity, raw route, and profile validation tests. | Omitted seam blocks implementation readiness; no public policy. |
| C18 | incorporated | REQ-CLEAN-01, REQ-CLEAN-02 | `fm-teardown.sh`; `omp-p3-cleanup-live`, `omp-p7-cleanup-complete` | All nested/top-level lists, generated artifacts, processes, temp, polls, dirty/unlanded, and unresolved-decision cases. | Any residue or bypass blocks; rollback uses real teardown. |
| C19 | incorporated | REQ-WATCH-01, REQ-MAP-01 | Continuity pretool, turn-end, watcher arm; `omp-p6-supervision-continuity` | OMP-native pretool, successor-before-wake, lock recheck, failed follow-up, hung successor, and retry exhaustion. | No copied Pi/Claude behavior; progress shows continuity gate. |
| C20 | incorporated | REQ-RPC-01, REQ-WATCH-01 | OMP-native extension owner; `omp-p3-rpc-lifecycle`, `omp-p6-supervision-continuity` | API and event equivalence tests plus fail-open-to-typed-failure cases. | Pi imports are prohibited without proof; no support claim. |
| C21 | incorporated | REQ-REG-01 | `.no-mistakes.yaml`, all tests, supported adapters; `omp-p3-regression`, `omp-p8-full-validation` | Complete loop plus continuity, supervision, Pi load/type, Grok cleanup, secondmate, and autodetection axes. | Any existing regression blocks P8; captain sees failing suite. |
| C22 | incorporated | REQ-LIVE-01 | Evidence ledger; all phase tasks and `omp-p8-full-validation` | Every required live row has a command, output, status, and evidence link; skipped/mock/inferred rows fail. | Missing row blocks promotion; no human choice. |
| C23 | incorporated | REQ-CLEAN-01, REQ-CLEAN-02 | Real teardown owner; `omp-p3-cleanup-live`, `omp-p7-cleanup-complete` | Generated worker extension, watcher, state, temp, process, backend, worktree, and refusal behavior. | Fixture-only cleanup is not pass; rollback preserves prior state. |
| C24 | incorporated | REQ-SCOPE-01 | Phase owners; P2-P8 task chain | Worker slice precedes provisional tmux, parity, supervision, recovery, multi-home, and final verification. | Schedule never weakens gates; progress reports current scoped phase. |
| C25 | incorporated | REQ-LINK-01 | Evidence documentation; `omp-p1-runtime-pin`, `omp-p8-policy-publication` | Validate each package/source link at a pinned commit and classify only that link. | Unverified link blocks the affected claim, not unrelated evidence. |

## Convergent weakness traceability

| Weakness | Requirement and task | Acceptance evidence | Gate and containment |
| --- | --- | --- | --- |
| Extension flag and trust failure | REQ-DISC-01, REQ-DISC-02, REQ-EXT-01, REQ-EXT-02; P1 and P2 tasks | Noext factory probe, discovery-root audit, hash/path/owner/mode, replacement, and handshake tests. | STOP-01 and STOP-02; no brief and no state transition. |
| Primitive versus integration category error | REQ-RPC-01, REQ-LIVE-01; P3 through P8 tasks | Integrated extension, worker, watcher, backend, recovery, and teardown E2E for every claimed row. | Primitive rows remain evidence-only; no promotion. |
| Continuation and wake failure visibility | REQ-CONT-01, REQ-FOLLOW-01, REQ-WATCH-01; P3 and P6 tasks | Throw, timeout, abort, hidden cap, interrupted follow-up, invalid tail, successor, and typed failure cases. | STOP-05; prior state remains active and visible. |
| Backend and home ownership | REQ-BACKEND-01, REQ-BACKEND-02, REQ-HOME-01, REQ-REC-01; P4, P5, P7 tasks | Tmux and Herdr lifecycle, two homes, owner restart, lock and wake separation, and no duplicate owner. | STOP-06 and STOP-07; no recovery or parity claim. |
| Current-code omissions | REQ-MAP-01, REQ-CLEAN-01, REQ-REG-01; all phase owners | Parser, raw launch, generated hook, send, continuity, cleanup, secondmate, and full test-loop coverage. | Missing seam blocks task activation and P8. |

## Validation matrix

Every row has a deterministic component and a required live component when the claim crosses a process, backend, ownership, or cleanup boundary.

| Row | Scenario and path | Requirement | Task and owner | Deterministic evidence | Required live evidence and pass gate |
| --- | --- | --- | --- | --- | --- |
| V01 | Pinned binary, package, version, Bun, hashes, launch help | REQ-EVID-01 | `omp-p1-runtime-pin`; evidence owner | Command and hash parser. | Exact output and exit status on pinned runtime; P1 gate. |
| V02 | Noext plus explicit extension | REQ-DISC-01 | `omp-p1-discovery-isolation`; launcher | Factory-counting fixture. | Real noext and explicit-only probes; any mismatch is STOP-01. |
| V03 | Project, profile, user, plugin, symlink, manifest, and TOCTOU discovery | REQ-DISC-02 | `omp-p1-discovery-isolation`; launcher | Root inventory and alias fixtures. | Controlled temporary runtime and replacement probe; P1 gate. |
| V04 | Host versus child markers, nested shell, PID reuse, lock holder | REQ-ID-01, REQ-ID-02 | `omp-p1-identity-ancestry`; harness and lock | Synthetic ancestry and marker cases. | Real argv and process ancestry capture; P1 gate. |
| V05 | Duplicate explicit paths and aliases | REQ-EXT-01 | `omp-p2-extension-handshake`; extension owner | Same path, symlink, discovered alias, and manifest fixtures. | Real canonical path and hash binding; P2 gate. |
| V06 | Missing mandatory extension | REQ-EXT-02 | `omp-p2-extension-handshake`; startup | Missing registration fixture. | OMP must abort before brief even if ready; STOP-02. |
| V07 | Failed mandatory extension while OMP reaches ready | REQ-EXT-02 | `omp-p2-extension-handshake`; startup | Throw, timeout, and import-error fixtures. | Real ready-plus-failure probe must fail closed; STOP-02. |
| V08 | Effective thinking downgrade | REQ-STATE-01 | `omp-p2-thinking-state`; launcher | State mismatch fixture. | Real `get_state` before brief; P2 gate. |
| V09 | Framed RPC chunks and malformed input | REQ-RPC-01, REQ-RPC-02 | `omp-p3-rpc-lifecycle`; RPC owner | Chunk reassembly, invalid frame, timeout, and process-exit fixtures. | Real stream and exit capture; P3 gate. |
| V10 | Normal streamed turn | REQ-RPC-01, REQ-LIVE-01 | `omp-p3-worker-live`; worker owner | Event-order fixture. | One real streamed turn, one `turn_end`, terminal agent end; P3 gate. |
| V11 | Missing or duplicate terminal event | REQ-RPC-02 | `omp-p3-worker-live`; RPC owner | Dropped and duplicate event fixtures. | Real process and stream probe; no normal success. |
| V12 | Abort and provider or tool error | REQ-RPC-02, REQ-LIVE-01 | `omp-p3-worker-live`; worker owner | Abort and error fixtures. | Real slow or failing stream, abort acknowledgement, terminal or typed process failure. |
| V13 | Continuation throw, timeout, abort, repeated run, cap, and reset | REQ-CONT-01 | `omp-p3-continuation-followup`; turn-end owner | All failure and reset fixtures. | Real supervised cycle with lower budget and one visible failure. |
| V14 | Follow-up after idle, stream, interrupt, invalid tail, provider/tool error, queue suppression | REQ-FOLLOW-01 | `omp-p3-continuation-followup`; send owner | Queue and state-transition fixtures. | Real `agent_start` and eventual turn or durable delivery failure. |
| V15 | Worker exact-once completion across normal, abort, error, drop, duplicate, and process exit | REQ-RPC-02 | `omp-p3-worker-live`; completion owner | Callback count fixtures. | Multiple real turns and abnormal paths; one signal or typed failure. |
| V16 | Tmux running, idle, streaming, interrupted, dead owner, shell survivor, unknown wrapper | REQ-BACKEND-01 | `omp-p4-tmux-classifier`; tmux owner | Classifier fixtures. | Real Bun ancestry and no-respawn unknown behavior. |
| V17 | Herdr ready, prompt, stream, follow-up, steer, abort, exit, resume, idle, dead owner | REQ-BACKEND-02 | `omp-p5-herdr-parity`; Herdr owner | Recognition and command fixtures. | Pinned Herdr live lab for every lifecycle row. |
| V18 | Successor before wake and lock ownership | REQ-WATCH-01 | `omp-p6-supervision-continuity`; watcher owner | Single-flight, lock-change, retry, and hung successor fixtures. | Real two-wake continuity E2E. |
| V19 | Two homes with separate locks, state, project, extension, watcher, and wake | REQ-HOME-01 | `omp-p7-two-home-isolation`; home owner | Path and lock fixtures. | Two real homes under shared code root. |
| V20 | Worker, primary, and secondmate restart with sole owner | REQ-REC-01 | `omp-p7-recovery`; recovery owner | Stale marker and duplicate recovery fixtures. | Real kill/restart and one-owner proof. |
| V21 | Complete cleanup of every nested and top-level surface | REQ-CLEAN-01 | `omp-p3-cleanup-live`, `omp-p7-cleanup-complete`; teardown owner | Inventory and missing-residue fixtures. | Real `fm-teardown.sh` and process/path inspection. |
| V22 | Dirty, unlanded, and unresolved-decision cleanup refusal | REQ-CLEAN-02 | `omp-p7-cleanup-complete`; teardown and decision owner | Refusal fixtures. | Real refusal and no bypass. |
| V23 | Existing harness, secondmate, backend, watcher, recovery, and cleanup regression | REQ-REG-01 | `omp-p3-regression`, `omp-p8-full-validation`; repository owner | All targeted suites. | Every `tests/*.test.sh`, applicable lint, and repository validation owner. |
| V24 | Evidence redaction and link pinning | REQ-LINK-01, REQ-LIVE-01 | `omp-p1-runtime-pin`, `omp-p8-full-validation`; evidence owner | Redaction and URL parser. | Dated exact command/output artifact with credentials removed. |
| V25 | Promotion wording and state transitions | REQ-SCOPE-01 | `omp-p4-tmux-provisional`, `omp-p8-policy-publication`; docs owner | Stale five-harness and state-label tests. | Review every user and agent surface before publication. |

## Hard stops

The following stops are immediate and retain the current BLOCK verdict.

| Stop | Trigger | Requirement and task | Consequence and containment |
| --- | --- | --- | --- |
| STOP-01 | Noext still drops explicit extensions or ambient discovery cannot be excluded before import. | REQ-DISC-01, REQ-DISC-02; `omp-p1-discovery-isolation` | Stop all implementation; keep experimental and first-class states unavailable. |
| STOP-02 | Mandatory extension can fail while OMP reaches ready or accepts work. | REQ-EXT-02; `omp-p2-extension-handshake` | Abort before brief and retain no support claim. |
| STOP-03 | Host identity depends on mixed child markers. | REQ-ID-01, REQ-ID-02; `omp-p1-identity-ancestry` | Stop identity and lock work; do not add OMP to policy. |
| STOP-04 | Effective thinking differs from requested policy without explicit reject or map. | REQ-STATE-01; `omp-p2-thinking-state` | Reject launch and record mismatch. |
| STOP-05 | Continuation, follow-up, frame, terminal, or watcher failure looks like success. | REQ-RPC-02, REQ-CONT-01, REQ-FOLLOW-01, REQ-WATCH-01; P3 and P6 | Surface typed failure, stop promotion, and retain prior state. |
| STOP-06 | Tmux unknown is treated as alive or dead, Herdr loses a running agent, or recovery duplicates owners. | REQ-BACKEND-01, REQ-BACKEND-02, REQ-REC-01; P4, P5, P7 | No respawn or parity claim; preserve fail-safe unknown. |
| STOP-07 | Two homes share lock, state, extension, watcher, project, or wake destination. | REQ-HOME-01; `omp-p7-two-home-isolation` | Stop multi-home and recovery; tear down isolated homes. |
| STOP-08 | Full tmux and Herdr lifecycle or resume evidence is absent while first-class support is claimed. | REQ-BACKEND-02, REQ-LIVE-01; P5 and P8 | Keep provisional or experimental label and block policy publication. |
| STOP-09 | Teardown leaves generated artifacts, process, temp, worktree, or bypasses refusal. | REQ-CLEAN-01, REQ-CLEAN-02; P3 and P7 | Stop cleanup promotion and preserve dirty or unlanded safeguards. |
| STOP-10 | Existing supported-harness, secondmate, watcher, recovery, cleanup, or full-loop regression appears. | REQ-REG-01; P3 and P8 | Revert or contain the OMP change and keep prior support state. |
| STOP-11 | Skipped, mocked, inferred, or inconclusive evidence is labeled verified. | REQ-LIVE-01; `omp-p8-full-validation` | Correct the ledger and block all promotion. |
| STOP-12 | A source or package link is called stale without individual pinned validation. | REQ-LINK-01; P1 and P8 | Remove the claim or pin the link before publication. |

## Decision and risk register

No captain choice remains unresolved in this correction.

The O4 report explicitly recommends an evidence-based BLOCK with a bounded provisional slice and no invented product-choice fork.

The O6 Red Team is an evidence gate, not a product decision.

The future requirement for a new explicit implementation authorization is a lifecycle boundary, not a current `needs:human` choice.

| Risk | Evidence | Mitigation | Owner and status field |
| --- | --- | --- | --- |
| Runtime drift | Direct `launch` behavior contradicted the prior record. | Re-pin every runtime-dependent phase and block on hash or command drift. | `omp-p1-runtime-pin`; progress blocker. |
| Ambient extension execution | Noext flag is contradicted and loader continues after errors. | Hermetic discovery audit, immutable extension identity, handshake, and no brief before pass. | `omp-p1-discovery-isolation`, `omp-p2-extension-handshake`; hard stop. |
| Mixed process identity | Child shells carry both markers while host does not. | Executable and argv ancestry, marker scrub, PID and lock-holder tests. | `omp-p1-identity-ancestry`; hard stop. |
| Hidden lifecycle failure | Continuation cap and follow-up suppression can look normal. | Lower budget, eventual-start proof, typed failure, terminal events. | `omp-p3-continuation-followup`, `omp-p6-supervision-continuity`; hard stop. |
| Backend ownership | Tmux marks Bun unknown and Herdr evidence is narrow. | Preserve unknown, prove both backends live, require sole-owner recovery. | P4, P5, P7; backend gate. |
| Plan execution drift | A prose plan can omit a seam or activate tasks early. | Stable manifest, dependency graph, phase-scoped progress, O6 validation before activation. | `.agents/tasks/roadmap.md`; progress and blocker fields. |

## Captain-facing tracking contract

Status and Bearings must report the current phase and milestone rather than a percentage over the entire future program.

The scoped denominator is the number of tasks in the current active phase after manifest activation.

Future phases do not inflate the denominator.

A task counts complete only when its acceptance evidence path and exit criterion are recorded.

A blocked task reports the stop ID, evidence gap, owner, and containment state.

The active branch is `fm/omp-first-class-support-o5` until a later phase is separately dispatched.

The next gate is `omp-final-plan-redteam-o6` with explicit `PASS` required.

The current blocker is pending independent validation and is not an implementation failure.

The current `needs:human` list is empty.

When a genuine choice appears later, the task record must use a stable key, list at least two concrete options, state the consequence of each, and record the recommendation.

No ordinary task receives a captain hold merely because it is future work.

After O6 passes, Tasks Axi `blocked-by` edges control readiness and only genuine decisions use structured holds.

## Verification and evidence handoff

Every phase evidence artifact records the date, exact runtime identity, exact command tokens, expected result, observed result, exit status, backend, process ancestry, and redacted environment names.

The evidence artifact must distinguish direct, source, inference, and missing-live evidence.

Credentials and private content must be removed before handoff.

Every live claim links to its command and exact output.

Every documentation link is checked at the pinned commit before publication.

The final validation record must state that OMP was absent from verified allowlists, normal dispatch, primary supervision, secondmate routing, recovery, and Herdr claims until P8.

## Commit and Definition of Done

The plan correction is committed separately from the preserved plan commit and from any future implementation.

The tracking correction is a focused documentation commit separate from runtime changes.

No implementation code or implementation test is added in this task.

The O6 Red Team task can reproduce every C01-C25 mapping through a requirement, owner, stable task, acceptance evidence, exit gate, containment action, and captain field.

The `.agents/tasks` manifest contains stable future IDs but no executable implementation rows until O6 passes.

The live firstmate backlog contains no OMP implementation task before O6 validation.

Markdown, link/path, Tasks Axi parse and render, and documentation validation pass.

The branch is rebased onto current `main`, contains focused commits, and is clean.

No OMP runtime support is implemented or claimed.
