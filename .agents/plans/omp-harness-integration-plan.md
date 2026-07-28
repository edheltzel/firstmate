---
title: OMP staged support plan with Red Team traceability
type: feat
date: 2026-07-27
artifact_contract: ce-unified-plan/v1
artifact_readiness: blocked-by-o6-awaiting-corrected-plan-red-team-no-implementation-authority
product_contract_source: ce-plan-bootstrap
execution: code
---

# OMP staged support plan with Red Team traceability

## Authority and current state

This file is the single canonical owner for the OMP support contract, requirement ledger, architecture map, phases, validation matrix, hard stops, and Definition of Done.

The current artifact state is `O8 historical BLOCK; O9 final corrected-plan validation required`.

The current plan is not implementation authority.

No OMP runtime, dispatch, test, cleanup, supervision, recovery, or support-policy implementation is authorized by this planning revision.

The final plan Red Team task `omp-final-plan-redteam-o6` returned `BLOCK` on 2026-07-27.

The promoted correction task `omp-corrected-plan-redteam-o8` is complete and preserves its historical `BLOCK` report.

The next and only validation task before activation is `omp-final-corrected-plan-redteam-o9`, whose exact report path is `data/omp-final-corrected-plan-redteam-o9/report.md`.

Implementation authority is blocked until `omp-final-corrected-plan-redteam-o9` returns `PASS` with no plan-blocking finding and its decision-hold inventory verifies clean.

A `CONDITIONAL PASS` does not clear implementation authority until every condition is closed and revalidated.

The preserved plan correction commit is `5be5e1436134e3c455a16200deded0fbc9c4a043`.

This revision is a separate documentation correction after that commit.

The roadmap at `.agents/tasks/roadmap.md` is a prose planning manifest, not a Tasks Axi input.

The parseable executable/current tracking artifact is `.agents/tasks/backlog.md`.

The tracked `.agents/tasks/backlog.md` contains only current planning, Red Team, and activation records, and contains no P1-P8 implementation records.

The live firstmate backlog at `data/backlog.md` must not receive new P1-P8 implementation rows before that validation.

The existing live activation identity is `omp-p1-activation-a7`.

The activation task records the captain's implementation authorization dated 2026-07-27, but it must refuse to activate any P1-P8 task unless the corrected-plan Red Team returns `PASS` with no plan-blocking finding.

The current next gate is `omp-final-corrected-plan-redteam-o9`, blocked by the completed historical O8 correction task, while O8 remains a completed `BLOCK` result rather than an activation authorization.

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

The independent O9 Red Team must validate the corrected P0 contract before any future implementation task is activated.

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

The O2, O3, O4, and O6 reports used the dated Firstmate observation `main` at `c6f4424a1923741d45aafffeb5bd4b8d425b55ef`.

The current landed planning baseline observed for this correction is local `main` at `da558ff154d96bb295db2369e839bb48f7f4cf20` on 2026-07-27.

Future evidence must resolve and record the current branch and commit at execution time rather than treating either observation as permanent.

The installed OMP executable is `/Users/ed/.bun/bin/omp`.

The executable resolves to `/Users/ed/.bun/install/global/node_modules/@oh-my-pi/pi-coding-agent/dist/cli.js`.

The package is `@oh-my-pi/pi-coding-agent` version `17.1.5`.

The observed Bun version is `1.3.14`.

The package manifest SHA-256 is `3574ab69ffc6108192110a87e8fa07edae67892fe2519b4d33c917c798c6a405`.

The CLI SHA-256 is `9898943d1ac04994ed2747d0bcce9ce6e736ee0f04d00b51833294ef5d179f3b`.

The installed dependency identity used for the child-marker source claim is `@oh-my-pi/pi-utils@17.1.5`.

The observed `@oh-my-pi/pi-utils/package.json` SHA-256 is `9fc0b3fa23ae85d29b00a7d29980bac044a223ed290a0c3d331735f1e65a9a6a`.

The observed `@oh-my-pi/pi-utils/src/procmgr.ts` SHA-256 is `9f3be50bc702fea1ba8e9c2ba52158c4ab7e155f697fd5f3f6549f1a5b88da58`.

The installed coding-agent manifest pins `@oh-my-pi/pi-utils` to `17.1.5`.

The reproducible identity commands are `command -v omp`, `readlink <resolved-omp>`, `omp --version`, `bun --version`, `shasum -a 256 <coding-agent>/package.json <coding-agent>/dist/cli.js`, `node -p "require('<pi-utils>/package.json').name+'@'+require('<pi-utils>/package.json').version"`, and `shasum -a 256 <pi-utils>/package.json <pi-utils>/src/procmgr.ts`.

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

OMP child-shell source `@oh-my-pi/pi-utils/src/procmgr.ts:38-48` sets both `OMPCODE=1` and `CLAUDECODE=1`.

Host identity must use executable and argv ancestry rather than mixed child markers.

OMP source `src/session/model-controls.ts:470-510` resolves requested thinking through model capability.

The effective `get_state.thinkingLevel` can be `xhigh` when the request says `max`.

OMP source `src/session/agent-session.ts:3051-3057` enforces a runtime continuation cap of eight.

Runtime cap exhaustion logs and returns a normal-looking stop unless the adapter owns a lower visible budget.

OMP source `src/extensibility/extensions/runner.ts:627-667` turns handler throw, timeout, or abort into an error and undefined result.

OMP source `src/session/agent-session.ts:5272-5294` can suppress automatic follow-up resume after interrupt, retry, or an invalid transcript tail.

OMP source `src/modes/rpc/rpc-mode.ts:1026-1034` acknowledges follow-up queueing rather than eventual turn start.

Herdr `0.7.5-preview` directly recognized a running `bun ... omp` process as `agent:"omp", agent_status:"idle"` in a named lab.

That Herdr observation is a narrow positive prerequisite and not full Herdr or Firstmate support evidence.

The current tmux backend recognizes only its known commands and classifies Bun and other unknown wrappers as `unknown`.

Unknown must remain neither alive nor dead for respawn purposes until a proven OMP ancestry classifier exists.

## Activation and operational tracking contract

`omp-p1-activation-a7` is the only activation identity and is an operational gate, not an implementation task.

The captain's 2026-07-27 authorization is recorded on that task as permission to evaluate activation, not permission to bypass its checks.

The gate must fail closed unless the final corrected-plan Red Team report for `omp-final-corrected-plan-redteam-o9` at `data/omp-final-corrected-plan-redteam-o9/report.md` has an exact `PASS` disposition, contains the exact heading `## Plan-blocking findings` followed by `None.`, and has a verified decision-hold inventory.

`CONDITIONAL PASS`, a missing report, an unverified hold, a stale report path, a dirty tracked tree, an unexpected P1-P8 backlog row, or any STOP row keeps activation refused.

The gate must verify that OMP remains absent from verified-harness allowlists, normal dispatch, primary supervision, secondmate routing, recovery classifiers, and Herdr support claims while it evaluates activation.

The gate may add the manifest's first implementation rows only after all fail-closed checks pass and must record the exact task IDs, dependency edges, branch, commit, report path, report hash, authorization identity, activation date, and support fence in one authoritative `data/backlog.md` postimage.

The completed A7 record embeds the complete `omp-activation-receipt.v1` record, and that embedded record is the only activation receipt authority.

The receipt's `postimage_sha256` is calculated after replacing its 64-hex value with `<self>`, which makes the hash non-self-referential and reproducible.

The postimage is validated by Tasks Axi and the receipt schema before one same-directory atomic rename of `data/backlog.md`.

Interruption before the rename preserves the exact preimage, while interruption immediately after the rename leaves the complete postimage authoritative and requires no compensating second-file rollback.

The roadmap is prose and must never be passed to `tasks-axi render`.

The parseable current-record file is `.agents/tasks/backlog.md`, and the live operational backlog is `data/backlog.md`.

The validated Tasks Axi executable is resolved from `PATH` and reports version `0.2.3`.

The non-mutating validation commands are `tasks-axi list --file .agents/tasks/backlog.md`, `tasks-axi show <id> --file .agents/tasks/backlog.md --full`, `tasks-axi ready --file .agents/tasks/backlog.md`, and `git diff --exit-code -- .agents/tasks/backlog.md .agents/tasks/roadmap.md`.

`tasks-axi render` is permitted only on a disposable copy of the parseable backlog when a future tool-version check explicitly requires it, and the validation must still assert a clean Git diff afterward.

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
| REQ-DISC-02 | Audit the complete installed-runtime discovery surface before required extension import, including argv controls (`--config`, `--hook`, `--add-dir`, `--extension`, `--plugin-dir`, `--skills`, `--no-skills`, `--no-rules`, `--profile`, `--cwd`, `--session-dir`, and `--allow-home`), environment variables and roots (`HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `XDG_RUNTIME_DIR`, `OMP_PROFILE`, `PI_PROFILE`, `PI_CONFIG_DIR`, `PI_CODING_AGENT_DIR`, `PI_PACKAGE_DIR`, `PI_CONFIG_FILES`, `PI_SMOL_MODEL`, `PI_SLOW_MODEL`, `PI_PLAN_MODEL`, and `PI_NO_PTY`), package and dependency roots, package lockfiles, project manifests and settings, user/profile configuration, plugins, skills, rules, hooks, add-dir trees, symlink aliases, directory extension manifests, provider and search credentials, bundled built-ins, inline `createAutoresearchExtension` registration, and replacement between preflight and import. | Launcher and extension trust owners; the inventory is generated from the pinned help/source and every unexpected root blocks launch. |
| REQ-ID-01 | Identify the OMP host through resolved executable and argv ancestry. | `bin/fm-harness.sh`, `bin/fm-session-lock-lib.sh`, and `bin/fm-lock.sh`; environment markers are not host authority. |
| REQ-ID-02 | Scrub or override inherited mixed child markers before nested non-OMP Firstmate launches. | Spawn environment owner; mixed-marker and nested-shell tests are required. |
| REQ-EXT-01 | Require canonical path, owner, mode, expected hash, task token, and exact registration set, with a content-bound immutable loading contract. | Generated extension and launcher owner; a preflight hash on a mutable pathname is insufficient, so the loader must use a verified read-only content-addressed staging root or an OMP-side byte-bound loader and prove the imported bytes match. |
| REQ-EXT-02 | Fail before brief or charter delivery on missing, failed, duplicate, unexpected, or replaced mandatory registration. | Startup handshake owner; ready without handshake is failure. |
| REQ-STATE-01 | Verify effective model, provider, and thinking state with `get_state` before work. | Launch gate owner; any mismatch is a typed launch failure or an explicitly approved map that records requested and effective values. |
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
| REQ-MAP-01 | Include secondmate positional parsing, raw launch, generated hook, send, continuity, all cleanup lists, backend liveness, shared lock identity, credential boundaries, and full regression owners. | This plan and `docs/omp-publication-inventory.md` own the inventory; future code changes must update the nearest owner docs. |
| REQ-DOC-01 | Remove stale historical tool paths and inconsistent persistent-supervisor terminology from the plan and future documentation. | Plan and documentation owners; P0 checks current names and P8 checks every published support surface. |
| REQ-REG-01 | Run every existing `tests/*.test.sh`, focused OMP tests, applicable lint, and all supported harness/backend axes. | `.no-mistakes.yaml:22-28` and repository test owner; a shortened list is not sufficient. |
| REQ-LIVE-01 | Require live evidence for worker, watcher, tmux, Herdr, two-home, recovery, and teardown claims. | Evidence ledger owner; skipped, mocked, inferred, or inconclusive rows block promotion. |
| REQ-LINK-01 | Validate each external source link at the pinned commit and classify individually stale links. | Evidence documentation owner; no blanket stale-link claim. |
| REQ-MON-01 | Expose current phase, milestone, scoped completed/total, branch, blockers, next gate, and explicit `needs:human` decisions. | `.agents/tasks/roadmap.md` owner; progress excludes future unscheduled phases. |

| REQ-CRED-01 | Permit only named OMP provider and search credential variables from the task-local credential boundary, preserve them only for the authorized worker process tree, redact names-only evidence, and refuse logging, persistence, or cleanup ambiguity. | `omp-p2-identity-adapter` owns the environment adapter; `omp-p1-discovery-isolation` owns discovery proof; V03, V04, STOP-01, STOP-02, STOP-03, and STOP-10 are required. |

## Architecture and ownership map

The plan assigns each contract to one owning code or documentation surface.

Future task records point to these owners instead of copying their contracts.

| Contract or seam | Current owner | Future OMP owner and required evidence |
| --- | --- | --- |
| Harness identity and verified-name policy | `bin/fm-harness.sh` | Evidence owner `omp-p1-identity-ancestry`; executable implementation owner `omp-p2-identity-adapter`; ancestry, marker, nested-child, PID-reuse, and live argv tests; no allowlist change before P8. |
| Lock identity and holder classification | `bin/fm-session-lock-lib.sh` sourced by `bin/fm-lock.sh`, with `tests/fm-session-lock.test.sh` | Evidence owner `omp-p1-identity-ancestry`; executable implementation owner `omp-p2-identity-adapter`; lock-holder, PID-reuse, concurrent-acquisition, and live owner tests. |
| Backend liveness and unknown-state handling | `bin/fm-backend.sh`, `bin/backends/tmux.sh`, `bin/backends/herdr.sh`, and `bin/fm-crew-state.sh` | `omp-p4-tmux-classifier`, `omp-p5-herdr-parity`, and `omp-p7-recovery`; unknown remains non-dead and every classifier result has live evidence. |
| Dispatch selection and effort validation | `bin/fm-dispatch-select.sh` and `bin/fm-bootstrap.sh` | `omp-p8-policy-publication`; invalid effort and stale profile tests. |
| Ordinary and secondmate launch parsing | `bin/fm-spawn.sh`, including `:449-466` | `omp-p2-experimental-launch` and `omp-p8-policy-publication`; positional, config, raw-launch, and role tests. |
| Raw launch escape hatch | `bin/fm-spawn.sh` raw-launch path | `omp-p1-runtime-pin`; keep it explicitly unverified and test rejection of unsupported adapter routes. |
| Generated worker hook | `bin/fm-spawn.sh:1222-1323` | `omp-p2-extension-handshake`; test generation, mode, token, hash, and cleanup. |
| Worker startup and task brief delivery | Experimental launcher future owner | `omp-p2-experimental-launch`; no brief before handshake and state gate. |
| Role-scoped environment and `FM_HOME` | `docs/configuration.md` plus producing script headers | `omp-p2-experimental-launch` and `omp-p2-identity-adapter`; fresh HOME/XDG/profile, marker scrubbing, descendant, and fail-closed home tests. |
| Send, steer, and settle semantics | `bin/fm-send.sh:194-227` | `omp-p3-rpc-lifecycle`; queue acceptance versus actual turn start tests. |
| Continuation and turn-end enforcement | `bin/fm-turnend-guard.sh`, native integrations, and `docs/turnend-guard.md` | `omp-p3-continuation-followup` and `omp-p6-supervision-continuity`; lower budget and typed failure tests. |
| Pretool blocking and checker spawn | `bin/fm-continuity-pretool-check.sh` and its test | `omp-p6-supervision-continuity`; OMP-native contract required, not a Pi or Claude import. |
| Watcher continuity and successor ordering | `docs/watcher-continuity.md` and watcher arm protocol | `omp-p6-supervision-continuity`; successor-before-wake, lock recheck, retry, and failure evidence. |
| Backend liveness and recovery | `bin/fm-backend.sh`, `bin/backends/tmux.sh`, `bin/backends/herdr.sh`, `bin/fm-crew-state.sh` | `omp-p4-tmux-classifier`, `omp-p5-herdr-parity`, and `omp-p7-recovery`; unknown and dead-owner tests. |
| Two-home ownership | `FM_HOME` layout in `docs/configuration.md`, `bin/fm-lock.sh`, and state metadata | `omp-p7-two-home-isolation`; real separate lock, state, project, extension, watcher, and wake paths. |
| Teardown and residue refusal | `bin/fm-teardown.sh:1069-1091` and `:1181-1277` | `omp-p3-cleanup-live` and `omp-p7-cleanup-complete`; all nested/top-level and dirty/unlanded surfaces. |
| Secondmate lifecycle | `bin/fm-spawn.sh`, bootstrap, secondmate provisioning, and secondmate tests | `omp-p7-recovery` and `omp-p8-policy-publication`; no secondmate claim before P7. |
| Supervision instructions and support docs | `bin/fm-supervision-instructions.sh`, `docs/supervision-protocols/`, `AGENTS.md`, and `harness-adapters` | `omp-p8-policy-publication`; update only after all gates and supported-axis regressions. |
| Regression ownership | `.no-mistakes.yaml:22-28` and every `tests/*.test.sh` | `omp-p3-regression` and `omp-p8-full-validation`; full loop, pinned Bun/TypeScript syntax/type/import/load checks, and dependency hash checks are mandatory. |
| Source and link evidence | OMP evidence record and package manifest | `omp-p1-runtime-pin` and `omp-p8-policy-publication`; pin each link and command. |

Pi and Claude extensions are behavioral references only.

The plan and future documentation must use current Firstmate paths and role names rather than stale historical tool paths or inconsistent persistent-supervisor terminology.

No OMP implementation may import Pi APIs, Pi event types, or fail-open helper behavior without a separate OMP-native equivalence proof.

### OMP identity and environment boundary

The OMP boundary is a task-local adapter contract and is not the Firstmate selector-scrubbing contract.

The adapter may set only `OMP_PROFILE`, `PI_CODING_AGENT_DIR`, `PI_PACKAGE_DIR`, `PI_CONFIG_FILES`, `PI_SMOL_MODEL`, `PI_SLOW_MODEL`, `PI_PLAN_MODEL`, `PI_NO_PTY`, and the explicitly authorized credential variables listed below.

The adapter must unset inherited `PI_PROFILE`, `PI_CONFIG_DIR`, and every unlisted `OMP_*`, `PI_*`, provider, search, hook, and plugin variable before launch.

The allowed provider credential names are `ANTHROPIC_API_KEY`, `ANTHROPIC_OAUTH_TOKEN`, `CLAUDE_CODE_USE_FOUNDRY`, `ANTHROPIC_FOUNDRY_API_KEY`, `ANTHROPIC_CUSTOM_HEADERS`, `CLAUDE_CODE_CLIENT_CERT`, `CLAUDE_CODE_CLIENT_KEY`, `OPENAI_API_KEY`, `GEMINI_API_KEY`, `AZURE_OPENAI_API_KEY`, `GROQ_API_KEY`, `CEREBRAS_API_KEY`, `XAI_API_KEY`, `OPENROUTER_API_KEY`, `KILO_API_KEY`, `MISTRAL_API_KEY`, `ZAI_API_KEY`, `UMANS_AI_CODING_PLAN_API_KEY`, `MINIMAX_API_KEY`, `OPENCODE_API_KEY`, `AI_GATEWAY_API_KEY`, and `WAFER_SERVERLESS_API_KEY`.

The allowed search credential names are `EXA_API_KEY`, `BRAVE_API_KEY`, `PERPLEXITY_API_KEY`, `PERPLEXITY_COOKIES`, `TAVILY_API_KEY`, `TINYFISH_API_KEY`, `FIRECRAWL_API_KEY`, `ANTHROPIC_SEARCH_API_KEY`, and `ANTHROPIC_SEARCH_BASE_URL`.

Credential values may originate only from the task-local secret provider selected by the future owner, are inherited only by the authorized OMP worker descendants, are never printed or serialized, and are unset by the cleanup owner after process termination.

The adapter must refuse an unknown credential name, a credential source outside the task boundary, an environment dump, a log containing a credential value, an ambiguous nested inheritance rule, or cleanup that cannot prove unsetting.

`REQ-CRED-01`, `REQ-DISC-02`, `V03`, `V04`, `STOP-01`, `STOP-02`, `STOP-03`, and the per-phase rollback inventory are the acceptance cross-references for this boundary.

### Immutable extension closure

Discovery closure includes every pinned argv, environment, profile, session, credential, package, dependency, lockfile, project, plugin, skill, rule, hook, add-dir, symlink, bundled built-in, provider, search, and inline source that can affect import or execution.

The closure must include `--plugin-dir`, `PI_PACKAGE_DIR`, `PI_CONFIG_FILES`, `PI_SMOL_MODEL`, `PI_SLOW_MODEL`, `PI_PLAN_MODEL`, provider and search credential names, and the inline `createAutoresearchExtension` path that remains reachable despite `--no-extensions`.

The future loader must resolve entry, transitive, dynamic, lazy, bundled, plugin, and inline imports into a content-addressed read-only staging root before brief delivery.

An unresolved dynamic or lazy import, a mutable source path, a changed byte hash, an unexpected registration, or a missing inline or bundled source is a fail-closed result.

The preflight must bind `STOP-01`, `STOP-02`, `V03`, `V04`, the registration set, the staged path, and every recorded hash in one evidence artifact before the worker can become ready.

## Phased roadmap and task manifest

All task IDs in this section are stable manifest IDs, not live backlog entries.

They become executable Tasks Axi records only after `omp-final-corrected-plan-redteam-o9` passes, its decision-hold inventory verifies clean, and `omp-p1-activation-a7` completes its fail-closed checks.

The manifest state `planned` is not a captain hold.

After activation, ordinary tasks become ready automatically when their `blocked-by` dependencies clear.

Only a genuine product or policy choice may create `needs:human`.

There is no current captain choice in this revision.

| Phase | Milestone | Task ID | Depends on | Parallelism | Current manifest state |
| --- | --- | --- | --- | --- | --- |
| P0 | Landed plan correction | `omp-o5-plan-traceability` | none | serialized | complete in commit set `967b1dc`, `a070dff`, `44a92ce`, `29511e5`, `cd3c826`, `da558ff` |
| P0 | Independent second Red Team | `omp-final-plan-redteam-o6` | `omp-o5-plan-traceability` | serialized | complete 2026-07-27 with `BLOCK`; report path is `data/omp-final-plan-redteam-o6/report.md` |
| P0 | Correct O6 plan-block corrections | `omp-plan-block-corrections-o7` | `omp-final-plan-redteam-o6` | serialized | complete 2026-07-28; no runtime or support change |
| P0 | Promoted O8 correction after historical BLOCK | `omp-corrected-plan-redteam-o8` | `omp-plan-block-corrections-o7` | serialized | complete 2026-07-28; preserved report is `BLOCK` |
| P0 | Independent final corrected-plan validation | `omp-final-corrected-plan-redteam-o9` | `omp-corrected-plan-redteam-o8` | serialized | queued validation; `PASS` with no plan-blocking finding is required |
| P1 | Fail-closed implementation activation | `omp-p1-activation-a7` | `omp-final-corrected-plan-redteam-o9` | serialized | activation gate only; captain authorization `captain-omp-implementation-authorization-2026-07-27` is a separate gate; no P1-P8 implementation record is active now |
| P1 | Runtime identity ledger | `omp-p1-runtime-pin` | `omp-p1-activation-a7` | parallel with P1 peers under disjoint-resource proof | planned |
| P1 | Discovery and flag safety ledger | `omp-p1-discovery-isolation` | `omp-p1-activation-a7` | parallel with P1 peers under disjoint-resource proof | planned |
| P1 | Host ancestry identity ledger | `omp-p1-identity-ancestry` | `omp-p1-activation-a7` | parallel with P1 peers under disjoint-resource proof | planned |
| P2 | Experimental worker launcher | `omp-p2-experimental-launch` | `omp-p1-runtime-pin`, `omp-p1-discovery-isolation`, `omp-p1-identity-ancestry` | serialized | planned |
| P2 | Executable OMP identity and environment adapter | `omp-p2-identity-adapter` | `omp-p1-runtime-pin`, `omp-p1-identity-ancestry` | serialized before supervision or recovery | planned, manifest-only |
| P2 | Mandatory extension handshake | `omp-p2-extension-handshake` | `omp-p2-experimental-launch` | parallel with state gate | planned |
| P2 | Effective thinking state gate | `omp-p2-thinking-state` | `omp-p2-experimental-launch` | parallel with handshake | planned |
| P3 | Native RPC lifecycle adapter | `omp-p3-rpc-lifecycle` | `omp-p2-identity-adapter`, `omp-p2-experimental-launch`, `omp-p2-extension-handshake`, `omp-p2-thinking-state` | serialized | planned |
| P3 | Continuation and follow-up failure semantics | `omp-p3-continuation-followup` | RPC lifecycle | serialized | planned |
| P3 | Real worker normal and abort E2E | `omp-p3-worker-live` | handshake, state, RPC | serialized | planned |
| P3 | Real worker cleanup E2E | `omp-p3-cleanup-live` | worker E2E | serialized | planned |
| P3 | Focused and full regression loop | `omp-p3-regression` | cleanup E2E | serialized | planned |
| P4 | Tmux OMP ancestry and liveness classifier | `omp-p4-tmux-classifier` | `omp-p3-regression` | serialized | planned |
| P4 | Provisional tmux worker evidence | `omp-p4-tmux-provisional` | `omp-p4-tmux-classifier`, `omp-p3-worker-live` | serialized | planned |
| P5 | Herdr lifecycle parity | `omp-p5-herdr-parity` | `omp-p4-tmux-provisional` | serialized | planned |
| P6 | Primary continuity and supervision | `omp-p6-supervision-continuity` | `omp-p5-herdr-parity`, `omp-p2-identity-adapter` | serialized | planned |
| P6 | Startup policy and protocol | `omp-p6-startup-policy` | `omp-p6-supervision-continuity` | serialized | planned |
| P7 | Two-home isolation | `omp-p7-two-home-isolation` | `omp-p6-startup-policy`, `omp-p2-identity-adapter` | serialized | planned |
| P7 | Sole-owner recovery | `omp-p7-recovery` | `omp-p7-two-home-isolation` | serialized | planned |
| P7 | Complete cleanup and refusal matrix | `omp-p7-cleanup-complete` | `omp-p7-recovery` | serialized | planned |
| P8 | Full live and regression verification | `omp-p8-full-validation` | `omp-p7-cleanup-complete` | serialized | planned |
| P8 | First-class policy and documentation publication | `omp-p8-policy-publication` | `omp-p8-full-validation` | serialized | planned |

### P0 - Plan correction and second Red Team gate

Prerequisite: the O2, O3, and O4 reports and preserved plan have been read in full.

`omp-o5-plan-traceability` output the prior canonical plan, prose roadmap, and parseable current-record backlog without implementation entries.

Its deterministic validation is Markdown parsing, link/path checks, Tasks Axi list/show/ready against `.agents/tasks/backlog.md`, and a clean Git diff after validation.

Its live evidence is none because this phase changes documentation only.

Its exit criterion was the clean landed commit sequence and a queued O6 Red Team task blocked on this plan task.

Its prior go gate was O6 `PASS` with no plan-blocking finding, and O6 instead returned `BLOCK`.

Its rollback is documentation-only revert; it cannot change OMP runtime or support state.

`omp-final-plan-redteam-o6` must attack every C01-C25 row, every phase dependency, every task, every evidence requirement, every gate, every rollback, every progress field, and every decision classification.

O6 is serialized before the correction task, and O8, O9, and activation are serialized before any implementation task is added to the live backlog.

The current O6 result is `BLOCK`, so this plan is not an implementation authority.

`omp-plan-block-corrections-o7` owns the correction artifact, `omp-corrected-plan-redteam-o8` owns the promoted correction after its historical BLOCK, and `omp-final-corrected-plan-redteam-o9` owns the independent final re-review of every O6 acceptance criterion.

### P1 - Evidence and launch boundary

Prerequisite: O9 returns `PASS`, `omp-p1-activation-a7` completes, and the manifest is activated without adding OMP to verified policy.

`omp-p1-runtime-pin` records the exact binary, package, version, Bun, hashes, dependency graph, command surface, RPC vector, date, output, and link commits.

`omp-p1-discovery-isolation` proves whether ambient discovery can be excluded without the broken flag combination.

`omp-p1-identity-ancestry` proves host executable and argv identity through mixed markers, nested shells, PID reuse, lock-holder cases, and real child-launch ancestry.

The three P1 evidence tasks may run in parallel only under the disjoint-resource contract below.

Each P1 task receives a unique root named `<task-id>-<run-token>` for `HOME`, `XDG_CONFIG_HOME`, `XDG_DATA_HOME`, `XDG_STATE_HOME`, `XDG_CACHE_HOME`, `XDG_RUNTIME_DIR`, `TMPDIR`, `OMP_PROFILE`, profile, session, socket, log, evidence, and package paths.

Each task unsets `PI_CONFIG_DIR` and `PI_CODING_AGENT_DIR`, uses a task-local content-addressed read-only package copy, and records every process descendant and lock, wake, session, and backend path under its own root.

The simultaneous-run test starts all three P1 tasks at once, resolves every path with `pwd -P` or `realpath`, and fails if any mutable realpath, socket, session, log, evidence, profile, cache, lock, wake, package, or process owner overlaps.

If the simultaneous-run test cannot prove disjoint realpaths, the manifest changes the P1 parallelism field to serialized before any task starts.

P1 deterministic tests cover command parsing, hash mismatch, the complete discovery-root inventory, symlink and manifest aliases, marker precedence, replacement after preflight, dependency hashes, and option-like command names.

P1 live evidence must use the pinned runtime and each task's unique temporary roots.

P1 documentation updates only the evidence ledger and owner pointers.

P1 exits only when discovery is hermetic or the plan records a runtime fix as a blocker, identity is ancestry-based, the package and `pi-utils` identities are pinned, the simultaneous isolation proof passes, and every exact command output is retained.

P1 go requires no `STOP-01` or `STOP-03` condition.

P1 rollback removes each task's temporary evidence, package, profile, cache, socket, session, log, lock, wake, process-descendant, and generated-hook roots through the recorded cleanup command, and leaves all verified lists, dispatch, and supervision unchanged.

`omp-p2-identity-adapter` is the stable executable implementation owner for OMP host identity, lock classification, nested-marker scrubbing, spawn environment, and bootstrap liveness.

It owns `bin/fm-harness.sh`, `bin/fm-lock.sh`, `bin/fm-spawn.sh`, `bin/fm-bootstrap.sh`, their current test owners, and the live evidence artifact for resolved OMP executable and argv ancestry.

It depends on P1 ancestry evidence and the activation gate, and it must complete before P3 lifecycle work or P6 supervision and P7 recovery can become eligible.

Its acceptance includes live host identity without host markers, child-shell marker separation, nested non-OMP launch scrubbing, lock-holder ownership, concurrent acquisition refusal, PID reuse refusal, descendant cleanup, and bootstrap liveness behavior.

Its rollback restores the pre-OMP identity and environment behavior, removes generated test hooks and state, proves no lock or wake residue, and leaves every existing harness allowlist unchanged.

### P2 - Experimental worker implementation boundary

Prerequisite: all P1 tasks pass without a discovery or identity hard stop.

`omp-p2-experimental-launch` is a separately named opt-in command and is not a harness accepted by normal dispatch.

It requires a temporary isolated `FM_HOME`, fresh HOME and XDG trees, a unique OMP profile, empty project root, cleared `PI_CONFIG_DIR` and `PI_CODING_AGENT_DIR`, and a dedicated tmux socket and session.

It refuses the active Firstmate home, repository root, and non-temporary homes.

It uses the pinned absolute executable and never passes `--no-extensions` with an explicit extension.

It runs the complete discovery closure preflight over argv flags, config and environment roots, package and dependency roots, project and user settings, plugin, skill, rule, hook, add-dir, symlink, manifest, and mutable replacement surfaces.

The required extension loader is content-bound: it opens and hashes the intended bytes without following unapproved symlinks, stages them into a task-local content-addressed read-only root or uses an OMP-side byte-bound loader, verifies the same hash immediately before import, and proves the loaded registration set against that hash.

A mutable pathname with only a preflight hash, a directory manifest that can be replaced, or a post-preflight symlink change fails `STOP-01` and `STOP-02`.

`omp-p2-extension-handshake` generates one canonical extension and requires its startup sentinel, task token, canonical path, expected hash, owner, mode, and exact registration set before the brief.

It rejects missing, failed, duplicate, unexpected, path-mismatched, owner-mismatched, mode-mismatched, hash-mismatched, and replaced registration.

`omp-p2-thinking-state` reads `get_state` and rejects an effective model, provider, or thinking level that differs from the request.

P2 deterministic tests cover every handshake and state mismatch, content replacement, package-root substitution, and discovery-root exclusion.

P2 live evidence is limited to a worker process and does not claim primary, secondmate, multi-home, recovery, backend parity, or Herdr support.

P2 documentation records the exact experimental label and keeps OMP absent from all verified policy surfaces.

P2 exits only when no task instructions can reach OMP before both handshake and state gates pass.

P2 go is the minimum experimental implementation gate and does not promote support state.

P2 rollback kills the recorded worker and every process descendant, removes the generated extension and hook, profile/cache/package roots, lock, wake, session, socket, log, and temporary home through the task cleanup path, and records the before/after realpath inventory.

### P3 - Worker lifecycle, failure visibility, and cleanup

Prerequisite: P2 launcher, handshake, and state gates pass.

`omp-p3-rpc-lifecycle` defines OMP-native frame parsing, chunk reassembly, startup timeout, ready negotiation, `agent_start`, streamed messages, `turn_end`, terminal `agent_end`, `get_state`, follow-up, steer, abort, invalid input, process exit, and resume.

Its live acceptance must exercise protocol negotiation, ready, prompt/start, stream, turn-end, terminal agent-end, state, follow-up, steer, abort, abort-and-prompt where supported, malformed input, process exit, and resume, with event order and terminality recorded for each operation.

`omp-p3-continuation-followup` owns a Firstmate continuation budget below eight and persists per-cycle counts.

It tests handler throw, timeout, abort signal, repeated continuation, cap exhaustion, reset after normal completion, reset after abort, abort-plus-follow-up, invalid-tail follow-up, slow streaming, provider or tool error, queued-message suppression, and eventual turn start.

`omp-p3-worker-live` runs multiple real normal turns plus real steer, follow-up, abort, abort-and-prompt, malformed-input, resume, provider-error, tool-error, extension-throw, extension-timeout, dropped-event, duplicate-event, and process-exit paths against a controlled local stream.

The normal path requires streamed output, one `turn_end`, and one terminal `agent_end` with `isTerminal:true`.

Every normal and abnormal path requires exactly one terminal completion signal or one typed visible failure before cleanup.

Missing terminal event, duplicate terminal event, dropped frame, hidden extension error, queued follow-up without turn start, malformed frame accepted as success, and normal-looking stop after error are failures.

`omp-p3-cleanup-live` invokes the real `bin/fm-teardown.sh` task path and inspects process descendants, backend, tmux, extension, generated hook, state, temp, profile, cache, lock, wake, session, socket, log, package, worktree, and isolated-home residue.

`omp-p3-regression` runs focused tests, then `for test_file in tests/*.test.sh; do bash "$test_file"; done`, `bin/fm-lint.sh` when shell files change, and pinned Bun syntax, type, import, and generated-extension load checks against the recorded `@oh-my-pi/pi-coding-agent@17.1.5` and `@oh-my-pi/pi-utils@17.1.5` identities.

P3 deterministic tests may establish parsing and state transitions, but live evidence is mandatory for every REQ-RPC-01 operation, every REQ-RPC-02 abnormal exact-once path, effective state, streamed turns, abort, terminal events, process exit, resume, and real teardown.

P3 exits only when every failure can be distinguished from success and cleanup failure cannot be hidden.

P3 go permits only the experimental worker label.

P3 rollback leaves normal Firstmate dispatch and all supported harnesses unchanged and removes the isolated task artifacts, descendants, generated extension and hook, backend, profile/cache, lock, wake, session, socket, log, package, and temp roots.

### P4 - Provisional tmux worker state

Prerequisite: P3 passes and the activation decision remains scoped to the worker contract.

`omp-p4-tmux-classifier` either proves Bun OMP ancestry and state transitions or retains `unknown` for every unproven wrapper.

It tests running, idle, streaming, interrupted, dead owner with a surviving shell, and unknown-wrapper states.

It must never treat `unknown` as alive or dead for respawn.

`omp-p4-tmux-provisional` re-runs the real worker matrix under the dedicated tmux backend and publishes only the provisional tmux worker label.

P4 deterministic tests cover classifier input and no-respawn-on-unknown.

P4 live evidence covers tmux ready, prompt, stream, abort, exit, and cleanup.

P4 documentation records backend-specific provisional scope and keeps normal dispatch, primary, secondmate, recovery, Herdr, and public support excluded.

P4 exits only when tmux evidence is complete or the provisional state remains blocked.

P4 rollback disables the experimental command and removes its isolated tmux socket/session, OMP and shell descendants, backend logs, task temp, state, profile/cache, package, lock, wake, generated extension/hook, and evidence roots.

### P5 - Herdr backend parity

Prerequisite: P4 provisional tmux evidence passes.

`omp-p5-herdr-parity` starts from the narrow `0.7.5-preview` idle-recognition observation but does not treat it as parity.

Every P5 run uses a unique named lab `fm-lab-omp-p5-<task-id>-<run-token>` provisioned and torn down only by `/Users/ed/Developer/Atlas/Themis/bin/fm-herdr-lab.sh` with the trailing named session argument.

It proves Herdr ready, prompt, stream, follow-up, steer, abort, exit, resume, idle, dead-owner, and cleanup behavior for the pinned OMP runtime.

It proves Firstmate liveness and recovery observe the same owner rather than trusting stale pane text.

P5 deterministic tests cover command ancestry, agent recognition, no-agent after exit, and unknown handling.

P5 live evidence is mandatory for every lifecycle and recovery row because Herdr registration is external runtime state.

P5 documentation updates only the empirical backend record and keeps the state provisional until P8.

P5 exits with parity evidence or a durable blocker that prevents first-class support.

P5 rollback interrupts and tears down only its named Herdr lab, removes its OMP and shell descendants, backend/session/socket/log/evidence/profile/cache/package/lock/wake/temp roots, and leaves tmux provisional scope intact with no Herdr claim.

### P6 - Primary supervision and continuity

Prerequisite: P5 backend parity passes.

`omp-p6-supervision-continuity` defines an OMP-native watcher extension and ownership for pretool checks, turn-end handling, watcher arm, successor readiness, session-lock recheck, bounded retry, single-flight, failed follow-up, hung successor, and typed retry exhaustion.

It does not import Pi or Claude extension APIs or preserve their fail-open behavior.

`omp-p6-startup-policy` adds OMP to any supervision protocol only alongside the mandatory guard and handshake evidence.

Deterministic tests cover successor-before-wake, lock change, retry, checker spawn, pretool failure, turn-end failure, and one visible failure per cycle.

Live evidence covers two consecutive wakes, successor verification, a wake after continuation, and recovery after interrupted or failed follow-up.

P6 documentation updates `docs/watcher-continuity.md`, supervision protocol ownership, and turn-end pointers only after tests pass.

P6 exits with primary supervision evidence or leaves OMP outside primary policy.

P6 rollback removes OMP protocol selection, watcher and continuation state, generated hooks, wake and lock artifacts, task temp, profile/cache/package roots, and process descendants, and leaves existing primary protocols unchanged.

### P7 - Two-home ownership, recovery, and complete cleanup

Prerequisite: P6 supervision passes.

`omp-p7-two-home-isolation` runs two real Firstmate homes sharing the code root with distinct `FM_HOME`, locks, projects, state, extensions, watchers, and wake destinations.

`omp-p7-recovery` kills and restarts worker, primary, and secondmate owners and proves one valid owner, one wake, correct identity, and no respawn of unknown wrappers.

`omp-p7-cleanup-complete` exercises nested worktree hooks and state, top-level hooks and state, task temp, PR poll, generated extension, watcher process, backend process, secondmate-home artifacts, dirty work, unlanded work, and unresolved-decision refusal.

P7 deterministic tests cover path ownership, lock separation, stale markers, duplicate recovery, and refusal behavior.

P7 live evidence is mandatory for process ownership, restart, recovery, and complete teardown.

P7 documentation updates only the nearest ownership and cleanup references.

P7 exits only when no duplicate owner or residue can look like success.

P7 rollback tears down both named isolated homes, every worker/primary/secondmate descendant, locks, wakes, watcher and backend processes, generated extensions/hooks, state, task temp, profile/cache/package roots, project worktrees, and evidence, then restores the prior supported state.

### P8 - First-class verification and policy publication

Prerequisite: P1 through P7 pass with no open hard stop.

`omp-p8-full-validation` runs every required live row, every focused test, every existing `tests/*.test.sh` script, applicable shell lint, and the repository validation owner.

It preserves redacted evidence with exact dates, versions, commands, output, exit status, process ancestry, state, stream, terminal, recovery, and cleanup observations.

It proves current Claude, Codex, OpenCode, Pi, Grok, secondmate, backend autodetection, watcher, recovery, and cleanup behavior is unchanged.

`omp-p8-policy-publication` updates verified allowlists, normal dispatch, primary supervision, secondmate routing, recovery, docs, and support claims atomically only after the full evidence ledger passes.

The publication transaction has one exact tracked-surface inventory owned by `docs/omp-publication-inventory.md`: `bin/fm-session-lock-lib.sh`, `bin/fm-lock.sh`, `bin/fm-harness.sh`, `bin/fm-bootstrap.sh`, `bin/fm-spawn.sh`, `bin/fm-dispatch-select.sh`, `bin/fm-supervision-instructions.sh`, `bin/fm-backend.sh`, `bin/backends/tmux.sh`, `bin/backends/herdr.sh`, `bin/fm-send.sh`, `bin/fm-crew-state.sh`, `bin/fm-teardown.sh`, `bin/fm-home-seed.sh`, `.agents/skills/harness-adapters/SKILL.md`, `.agents/skills/secondmate-provisioning/SKILL.md`, `AGENTS.md`, `README.md`, `CONTRIBUTING.md`, `docs/configuration.md`, `docs/supervision-protocols/omp.md`, `docs/watcher-continuity.md`, `docs/turnend-guard.md`, `docs/omp-publication-inventory.md`, and the applicable current test files.

The inventory is grouped by allowlist and identity, dispatch, supervision, secondmate routing, recovery, cleanup, and public documentation surfaces, and no generated state, extension, hook, cache, socket, or Herdr lab artifact is a publication input.

P8 preflight requires a clean branch, current live Git branch and commit, all P1-P7 evidence, no open STOP row, complete link and path checks, full regression, and a changed-file set equal to the inventory.

Publication is one guarded commit from a disposable staging worktree, or one feature-flag boundary with the same all-or-nothing invariant, and it must not publish any surface independently.

After publication, the invariant check must prove one consistent OMP support state across every listed surface, unchanged support for Claude, Codex, OpenCode, Pi, and Grok, no generated runtime residue, and a recoverable clean revert.

The partial-failure simulation applies each inventory group alone in a disposable clone, runs `bin/fm-omp-publication-check.sh --simulate` after every simulated interruption, requires refusal of every mixed old/new state, and proves `git revert --no-edit <publication-commit>` restores the pre-publication tree and support labels.

P8 deterministic tests cover stale five-harness lists, profile validation, documentation links, the exact publication inventory, per-surface partial-failure refusal, post-publication invariants, recoverable revert, and all existing regression suites.

P8 live evidence requires tmux and Herdr, two homes, recovery, every REQ-RPC-01 operation, every REQ-RPC-02 abnormal exact-once path, continuation, follow-up, effective model/provider/thinking state, and cleanup rows.

P8 exits with first-class verified support only when every live row passes and no decision or hard stop remains.

P8 rollback is a clean revert of the single publication commit in the staging proof before any public or verified policy publication, followed by the post-revert invariant and residue checks.

## Phase and task artifact inventory

The exact current artifact classes, paths, creation owners, cleanup owners, rollback owners, and evidence schemas are owned by `docs/omp-publication-inventory.md` and `.agents/tasks/omp-publication-manifest.json`, and checked by `bin/fm-omp-publication-check.sh`.

The task rows below remain the phase-scoped ownership summary; no row may narrow or replace the exact inventory document.

Every task report must include the complete row for its task ID, with `not created` recorded explicitly for an artifact class that the task did not use.

| Task IDs | Artifact, owner, process, and path inventory | Cleanup and rollback proof |
| --- | --- | --- |
| `omp-o5-plan-traceability`, `omp-final-plan-redteam-o6`, `omp-plan-block-corrections-o7`, `omp-corrected-plan-redteam-o8`, `omp-final-corrected-plan-redteam-o9` | Owner: planning worker; processes: Markdown/link checker, `tasks-axi` 0.2.3 resolved from PATH, Git; paths: `.agents/plans/omp-harness-integration-plan.md`, `.agents/tasks/roadmap.md`, `.agents/tasks/backlog.md`, report paths under `data/`, and a unique disposable validation copy. | No runtime, backend, HOME, profile, cache, lock, wake, extension, hook, or Herdr artifacts are permitted; delete only the disposable copy, assert `git diff --exit-code`, and revert the focused documentation commit if the post-edit DOX or validation pass fails. |
| `omp-p1-activation-a7` | Owner: activation gate; processes: Tasks Axi and the gate validator only; paths: `.agents/tasks/backlog.md`, `data/backlog.md`, corrected-plan report, decision-hold record, current branch/commit, and a unique activation evidence directory. | The default outcome is refusal; no P1-P8 row, runtime process, backend, HOME, profile/cache, package, lock, wake, extension, hook, or Herdr artifact may exist on refusal, and every pre-rename failure leaves the exact preflight backlog bytes unchanged. |
| `omp-p1-runtime-pin`, `omp-p1-discovery-isolation`, `omp-p1-identity-ancestry` | Owner: respective P1 evidence task; processes: pinned OMP, Bun helpers, hash/link/parser commands, and descendants; paths: task-unique `HOME`, all XDG roots, `TMPDIR`, `OMP_PROFILE`, session/socket/log/evidence/package roots, and read-only source copy. | The simultaneous realpath inventory must be empty across tasks; kill only recorded descendants, remove task-local state, profiles, caches, locks, wakes, sessions, sockets, logs, packages, and evidence, and leave the installed runtime and support policy untouched. |
| `omp-p2-experimental-launch`, `omp-p2-identity-adapter`, `omp-p2-extension-handshake`, `omp-p2-thinking-state` | Owner: launcher, identity, handshake, and state tasks; processes: OMP host, shell descendants, helper and checker processes; paths: task `FM_HOME`, `state/<task-id>.*`, generated extension and hook, immutable extension/package root, profile/cache, lock, wake, tmux socket/session, log, and evidence. | Record process descendants before launch, run the real task cleanup path, verify no state or generated hook/extension remains, and restore pre-task identity/launch behavior without changing allowlists or support state. |
| `omp-p3-rpc-lifecycle`, `omp-p3-continuation-followup`, `omp-p3-worker-live`, `omp-p3-cleanup-live`, `omp-p3-regression` | Owner: RPC, continuation, worker, cleanup, and regression tasks; processes: OMP RPC host, provider mock, shell/tool descendants, tmux backend, test runners, Bun/TypeScript validators; paths: task temp, state, profile/cache, immutable package, lock, wake, session/socket, generated extension/hook, worktree, logs, and evidence. | Every operation and abnormal path ends in one completion or typed failure before cleanup; inspect descendants and all roots after `bin/fm-teardown.sh`, preserve dirty/unlanded/refusal behavior, and revert only the focused implementation or test commit in a disposable proof. |
| `omp-p4-tmux-classifier`, `omp-p4-tmux-provisional` | Owner: tmux/backend tasks; processes: dedicated tmux server, Bun OMP host, shell survivor, and backend checker; paths: unique tmux socket/session, task `FM_HOME`, backend metadata, state, lock, wake, profile/cache/package, generated hook/extension, temp, logs, and evidence. | Prove unknown is not respawned, kill the named socket/session and descendants, inspect the survivor shell and every recorded path, remove all task artifacts, and retain only the exact experimental or provisional label. |
| `omp-p5-herdr-parity` | Owner: Herdr parity task; processes: helper-owned Herdr lab, registered OMP agent, pane shell, Bun host, and descendants; paths: `fm-lab-omp-p5-<task-id>-<run-token>`, helper journal, named socket/session, task HOME/XDG/profile/cache/package, state, lock, wake, logs, and evidence. | Use only `fm-herdr-lab.sh` with the trailing named session, interrupt and tear down that named lab, verify `agent_not_found` after exit, inspect descendants and roots, and never touch Herdr's ordinary default session. |
| `omp-p6-supervision-continuity`, `omp-p6-startup-policy` | Owner: OMP-native watcher and startup tasks; processes: primary OMP, watcher child or bounded retry, checker, successor, backend, and provider descendants; paths: primary and task `FM_HOME`, watcher markers, continuation counts, lock, wake queue, generated hooks, profile/cache/package, sessions/sockets, logs, and evidence. | Verify successor-before-wake and lock ownership, then remove watcher/retry processes and every state, lock, wake, generated, temp, profile/cache, package, backend, and log artifact on rollback while leaving existing protocols unchanged. |
| `omp-p7-two-home-isolation`, `omp-p7-recovery`, `omp-p7-cleanup-complete` | Owner: home, recovery, and cleanup tasks; processes: two OMP owners, worker, primary, secondmate, watcher, backend, provider, and all descendants; paths: two distinct `FM_HOME` trees with separate `data`, `state`, `config`, `projects`, `HOME`, XDG, profiles, caches, package roots, locks, wakes, generated extensions/hooks, task temp, logs, sessions, sockets, and evidence. | The two-home realpath and owner ledger must be disjoint, recovery must leave one owner, and teardown must exercise every nested/top-level surface plus dirty, unlanded, and unresolved-decision refusal before both homes and descendants are removed. |
| `omp-p8-full-validation`, `omp-p8-policy-publication` | Owner: validation and publication tasks; processes: all supported harness/backend test runners, OMP live labs, invariant checker, Git; paths: disposable staging clone, exact publication inventory, complete evidence ledger, temporary Herdr lab, and no generated runtime artifacts in the tracked tree. | Run per-surface interruption simulations, prove refusal of mixed policy, commit once only after preflight, run post-publication invariants, revert the single commit in staging, and prove the pre-publication tree, labels, descendants, state, locks, wakes, and labs are restored. |

No task may omit task temp, state, profile/cache, lock, wake, process descendant, generated extension/hook, backend, package, credential boundary, or evidence paths from its report.

Every task has a stable evidence ID, rollback ID, evidence path, rollback path, schema, owner, validation IDs, and exact dependency IDs in `.agents/tasks/omp-manifest.json`.

`bin/fm-omp-plan-check.sh` validates manifest uniqueness, dependency closure, cycle freedom, roadmap parity, plan cross-references, Tasks Axi parsing, and version-pinned non-mutating commands.

`bin/fm-omp-activation.sh` is the non-mutating-by-default O9 PASS gate and the sole guarded single-backlog atomic publication owner for the first corrected implementation phase.

`bin/fm-omp-publication-check.sh` is the V29 inventory and interruption validator and refuses any mixed publication state.

## O8 correction matrix

| Correction ID | Required correction | Stable owner tasks | Mechanical validator or evidence | Rollback and containment |
| --- | --- | --- | --- | --- |
| O8-S0-01 | Assign executable OMP identity, shared session-lock identity, backend liveness, environment adaptation, tests, and rollback ownership. | `omp-p1-identity-ancestry`, `omp-p2-identity-adapter`, `omp-p4-tmux-classifier`, `omp-p7-recovery` | `bin/fm-omp-plan-check.sh`; V03,V04,V26; `tests/fm-session-lock.test.sh` and the mapped backend tests | `omp-rollback-omp-p2-identity-adapter`; STOP-03 and STOP-06 keep support fenced. |
| O8-S0-02 | Enumerate every discovery source and require immutable entry, transitive, dynamic, lazy, bundled, plugin, and inline closure. | `omp-p1-discovery-isolation`, `omp-p2-extension-handshake` | REQ-DISC-02, REQ-EXT-01, V02,V03,V04; `--plugin-dir`, package/config overrides, model/provider/search credentials, and inline autoresearch are explicit | `omp-rollback-omp-p1-discovery-isolation`; STOP-01 and STOP-02 refuse ready or brief delivery. |
| O9-ACT-01 | Encode the already-authorized activation behind a mechanical O9 PASS, decision, clean-tree, preimage, support-fence, and no-premature-row gate. | `omp-p1-activation-a7` | `bin/fm-omp-activation.sh --check --json`; `omp-activation-check.v1`; every refusal condition is covered by `tests/fm-omp-activation.test.sh` | `omp-rollback-omp-p1-activation-a7`; default is refusal and `--activate` alone is never authority. |
| O8-TRACK-01 | Replace prose dependency aliases with exact stable task IDs in a machine-readable graph and a parity-checked roadmap. | All task IDs in `.agents/tasks/omp-manifest.json` | `bin/fm-omp-plan-check.sh --json`; `omp-plan-check.v1`; Tasks Axi 0.2.3 list/show/ready | `omp-rollback-omp-corrected-plan-redteam-o8`; no future task row is executable before O9 and A7. |
| O8-TRACK-02 | Give every task stable validation, evidence, rollback, path, schema, owner, and cross-reference fields. | All task IDs in `.agents/tasks/omp-manifest.json` | Manifest uniqueness and graph checks plus V01-V29, STOP-01 through STOP-12, and plan/roadmap parity | Per-task `omp-rollback-{task_id}` records; missing or ambiguous records block the phase. |
| O8-PUB-01 | Enumerate exact P8 publication and cleanup surfaces and assign creation, cleanup, rollback, and evidence ownership. | `omp-p8-full-validation`, `omp-p8-policy-publication` | `docs/omp-publication-inventory.md`; `bin/fm-omp-publication-check.sh`; V29 and `omp-publication-check.v1` | Per-phase rollback inventories preserve the verified preimage and reject mixed publication state. |
| O8-CRED-01 | Define allowed OMP credential names, source, lifetime, inheritance, redaction, no-log, cleanup, and refusal rules without values. | `omp-p1-discovery-isolation`, `omp-p2-identity-adapter` | REQ-CRED-01; V03,V04; plan environment boundary; names-only evidence | STOP-01, STOP-02, STOP-03, and `omp-rollback-omp-p2-identity-adapter` contain any credential ambiguity. |
| O8-PROV-01 | Treat O7 branch text as historical and derive current branch and commit from live Git state. | `omp-final-corrected-plan-redteam-o9`, `omp-p1-activation-a7` | `git branch --show-current`, `git rev-parse HEAD`, and activation preflight fields | A stale or mismatched preimage refuses activation; no historical branch is authoritative. |

Future Herdr lab artifacts are named and scoped only by the task that owns them, and no ordinary Herdr session is a cleanup target.

## Red Team C01-C25 compliance matrix

The disposition values mean `incorporated` is a concrete plan requirement with a future task and acceptance evidence, `deferred with blocking gate` is intentionally staged but cannot promote support, and `unresolved and plan-blocking` is an active no-go condition.

No row marked incorporated means the runtime behavior has already passed.

| Finding | Disposition | Plan requirement | Owner and task | Deterministic acceptance and live evidence | Exit, containment, and captain field |
| --- | --- | --- | --- | --- | --- |
| C01 | incorporated with executable owner | REQ-ID-01, REQ-ID-02 | Evidence `omp-p1-identity-ancestry`; implementation `omp-p2-identity-adapter`; `fm-harness.sh`, `fm-lock.sh`, `fm-spawn.sh`, `fm-bootstrap.sh` | Mixed `OMPCODE` and `CLAUDECODE`, nested shell, PID reuse, lock-holder, child-launch, and bootstrap-liveness tests plus argv capture. | Failure keeps OMP out of policy; progress shows identity blocker and STOP-03 containment. |
| C02 | incorporated with executable owner | REQ-ID-01 | Evidence `omp-p1-identity-ancestry`; implementation `omp-p2-identity-adapter`; harness and lock owners | Compare the stale marker premise with ancestry-based expected results in deterministic and live tests, including a host with no marker and a child with both markers. | Stale marker logic is removed before supervision or recovery eligibility; no human choice. |
| C03 | incorporated | REQ-EVID-01 | Evidence ledger and launcher; `omp-p1-runtime-pin` | Exact `omp launch --help`, version, package, Bun, and hashes with output and status. | Runtime drift blocks P1; progress shows pinned-runtime blocker. |
| C04 | unresolved and plan-blocking | REQ-DISC-01, REQ-DISC-02 | Launcher and extension trust; `omp-p1-discovery-isolation`, `omp-p2-extension-handshake` | Complete installed-runtime argv/config/environment/package/project/symlink/plugin/skill/rule/hook/add-dir inventory, noext contradiction probe, directory-manifest and alias cases, and content-bound replacement between preflight and import. | Do not implement or claim even experimental work if discovery is not hermetic or loaded bytes are not immutable; STOP-01 and STOP-02 remain active. |
| C05 | incorporated with blocking gate | REQ-DISC-02, REQ-EXT-01 | Extension loader and launcher; `omp-p2-extension-handshake` | Same path, symlink alias, explicit/discovered alias, directory manifest, and replacement/hash tests. | Any alias or replacement failure blocks handshake; progress shows trust blocker. |
| C06 | incorporated | REQ-EXT-01, REQ-EXT-02 | Generated extension and startup; `omp-p2-extension-handshake` | Owner, mode, canonical path, hash, token, exact set, and isolated discovery checks. | No handshake means no brief; rollback removes generated extension. |
| C07 | incorporated | REQ-EXT-02 | Startup gate; `omp-p2-extension-handshake` | Required extension failure while OMP reaches ready must yield pre-brief abort, not ready acceptance. | Ready without handshake is a hard stop; progress shows startup blocker. |
| C08 | incorporated with expanded effective-state gate | REQ-STATE-01 | Launcher state gate; `omp-p2-thinking-state` | `get_state` rejects requested model, provider, or thinking values that differ from effective state, including `max` becoming `xhigh`, unless a separately documented map exists. | Mismatch blocks launch; no human choice is invented. |
| C09 | incorporated with blocking gate | REQ-RPC-01, REQ-LIVE-01 | OMP-native adapter; `omp-p3-rpc-lifecycle`, `omp-p3-worker-live` | Reclassify primitive PASS rows and require integrated extension E2E for each claimed lifecycle behavior. | Primitive evidence cannot promote support; progress shows live-evidence gap. |
| C10 | incorporated | REQ-CONT-01 | Turn-end and continuation owner; `omp-p3-continuation-followup` | Lower budget, reserved counts, throw, timeout, abort, repeated continuation, cap, reset, and one visible failure. | Hidden cap or normal stop blocks; rollback leaves no supervision claim. |
| C11 | incorporated | REQ-FOLLOW-01 | `fm-send.sh`, RPC, watcher; `omp-p3-continuation-followup`, `omp-p6-supervision-continuity` | Abort, provider/tool error, invalid tail, slow stream, queued state, `agent_start`, and eventual turn-start tests. | Queue acknowledgement without turn is failure; progress shows delivery blocker. |
| C12 | incorporated | REQ-RPC-02, REQ-LIVE-01 | Worker completion owner; `omp-p3-worker-live` | Multiple turns, abort, tool/provider error, extension throw/timeout, dropped callback, duplicate event, and process exit. | Missing exact-once signal is typed failure; no cleanup success inferred. |
| C13 | incorporated with blocking gate | REQ-BACKEND-01 | `tmux.sh`, backend owner; `omp-p4-tmux-classifier` | Running, idle, streaming, interrupted, shell-after-owner, dead owner, and unknown wrapper states. | Unknown stays unknown and never respawns; provisional state remains blocked. |
| C14 | deferred with blocking gate | REQ-BACKEND-02 | `herdr.sh`; `omp-p5-herdr-parity` | Preserve versioned idle recognition, then run ready, prompt, stream, follow-up, steer, abort, exit, resume, and recovery. | Narrow positive fact permits no parity claim; captain sees Herdr gate. |
| C15 | incorporated | REQ-SCOPE-01, REQ-BACKEND-02, REQ-DOC-01 | State model and documentation; `omp-p4-tmux-provisional`, `omp-p5-herdr-parity`, `omp-p8-policy-publication` | State transition tests, current-path checks, and docs reject first-class wording during tmux-only phases. | No Herdr evidence means no first-class state; stale paths or terminology block publication. |
| C16 | incorporated | REQ-BACKEND-01, REQ-REC-01 | Backend and recovery owners; `omp-p4-tmux-classifier`, `omp-p7-recovery` | Unknown-is-not-dead, owner process state, successor ordering, and recovery tests. | Conservative unknown remains containment; progress shows recovery gate. |
| C17 | incorporated | REQ-MAP-01 | `fm-spawn.sh:449-466`, raw launch, dispatch; `omp-p2-experimental-launch`, `omp-p8-policy-publication` | Positional parser, home-path ambiguity, raw route, and profile validation tests. | Omitted seam blocks implementation readiness; no public policy. |
| C18 | incorporated | REQ-CLEAN-01, REQ-CLEAN-02 | `fm-teardown.sh`; `omp-p3-cleanup-live`, `omp-p7-cleanup-complete` | All nested/top-level lists, generated artifacts, processes, temp, polls, dirty/unlanded, and unresolved-decision cases. | Any residue or bypass blocks; rollback uses real teardown. |
| C19 | incorporated | REQ-WATCH-01, REQ-MAP-01 | Continuity pretool, turn-end, watcher arm; `omp-p6-supervision-continuity` | OMP-native pretool, successor-before-wake, lock recheck, failed follow-up, hung successor, and retry exhaustion. | No copied Pi/Claude behavior; progress shows continuity gate. |
| C20 | incorporated | REQ-RPC-01, REQ-WATCH-01 | OMP-native extension owner; `omp-p3-rpc-lifecycle`, `omp-p6-supervision-continuity` | API and event equivalence tests plus fail-open-to-typed-failure cases. | Pi imports are prohibited without proof; no support claim. |
| C21 | incorporated | REQ-REG-01 | `.no-mistakes.yaml`, all tests, supported adapters; `omp-p3-regression`, `omp-p8-full-validation` | Complete loop plus continuity, supervision, Pi load/type, Grok cleanup, secondmate, and autodetection axes. | Any existing regression blocks P8; captain sees failing suite. |
| C22 | incorporated | REQ-LIVE-01 | Evidence ledger; all phase tasks and `omp-p8-full-validation` | Every required live row has a command, output, status, and evidence link; skipped/mock/inferred rows fail. | Missing row blocks promotion; no human choice. |
| C23 | incorporated | REQ-CLEAN-01, REQ-CLEAN-02 | Real teardown owner; `omp-p3-cleanup-live`, `omp-p7-cleanup-complete` | Generated worker extension, watcher, state, temp, process, backend, worktree, and refusal behavior. | Fixture-only cleanup is not pass; rollback preserves prior state. |
| C24 | incorporated with stable conformance owner | REQ-SCOPE-01, REQ-MAP-01, REQ-DOC-01, REQ-MON-01 | `omp-plan-block-corrections-o7`, `omp-final-corrected-plan-redteam-o9`, and `omp-p8-policy-publication`; P2-P8 task chain | The conformance owner checks the full phase/task artifact inventory, current-code map, stale terminology/path scan, and live Status/Bearings projections before O9 and again before P8. | Schedule never weakens gates; progress reports the live-derived branch, scoped denominator, blocker, next gate, and explicit `needs:human` options. |
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
| V01 | Pinned binary, package, dependency graph, version, Bun, hashes, launch help | REQ-EVID-01 | `omp-p1-runtime-pin`; evidence owner | Command and hash parser for coding-agent and `@oh-my-pi/pi-utils`. | Exact output and exit status on pinned runtime and dependency source; P1 gate. |
| V02 | Noext plus explicit extension | REQ-DISC-01 | `omp-p1-discovery-isolation`; launcher | Factory-counting fixture. | Real noext and explicit-only probes; any mismatch is STOP-01. |
| V03 | Complete installed-runtime argv/config/environment/package/project/symlink/plugin/skill/rule/hook/add-dir discovery and content-bound TOCTOU | REQ-DISC-02, REQ-EXT-01 | `omp-p1-discovery-isolation`, `omp-p2-extension-handshake`; launcher and trust owner | Pinned help/source-derived root inventory, alias and manifest fixtures, replacement after preflight, and immutable staging or byte-bound loader proof. | Controlled temporary runtime with every root isolated, unexpected-root refusal, and same-hash loaded-byte proof; P1/P2 gate. |
| V04 | Host versus child markers, nested shell, PID reuse, lock holder, spawn environment, and bootstrap liveness | REQ-ID-01, REQ-ID-02 | Evidence `omp-p1-identity-ancestry`; implementation `omp-p2-identity-adapter`; harness, lock, spawn, and bootstrap owners | Synthetic ancestry, marker, lock, descendant, and environment cases. | Real argv and process ancestry capture, nested child scrub, lock-holder proof, PID-reuse refusal, and liveness result; P2 gate before P6/P7. |
| V05 | Duplicate explicit paths and aliases | REQ-EXT-01 | `omp-p2-extension-handshake`; extension owner | Same path, symlink, discovered alias, and manifest fixtures. | Real canonical path and hash binding; P2 gate. |
| V06 | Missing mandatory extension | REQ-EXT-02 | `omp-p2-extension-handshake`; startup | Missing registration fixture. | OMP must abort before brief even if ready; STOP-02. |
| V07 | Failed mandatory extension while OMP reaches ready | REQ-EXT-02 | `omp-p2-extension-handshake`; startup | Throw, timeout, and import-error fixtures. | Real ready-plus-failure probe must fail closed; STOP-02. |
| V08 | Effective model, provider, and thinking downgrade | REQ-STATE-01 | `omp-p2-thinking-state`; launcher | Requested/effective state mismatch fixtures for model, provider, and every supported thinking level. | Real `get_state` before brief with requested/effective comparison; P2 gate. |
| V09 | Framed RPC chunks, every operation, malformed input, timeout, exit, and resume | REQ-RPC-01, REQ-RPC-02 | `omp-p3-rpc-lifecycle`; RPC owner | Chunk reassembly, ready negotiation, prompt/start, stream, turn-end, terminal end, state, follow-up, steer, abort, abort-and-prompt, malformed frame, timeout, process exit, and resume fixtures. | Live evidence for every operation, event order, terminality, malformed input, process exit, and resumed state; P3 gate. |
| V10 | Multiple normal streamed turns and integrated lifecycle | REQ-RPC-01, REQ-LIVE-01 | `omp-p3-worker-live`; worker owner | Event-order and multiple-turn fixtures. | Live prompt/start, stream, turn-end, terminal agent end, get_state, follow-up, steer, resume, and exact-once completion across multiple turns; P3 gate. |
| V11 | Missing, dropped, or duplicate terminal event | REQ-RPC-02 | `omp-p3-worker-live`; RPC owner | Dropped frame, missing terminal, duplicate terminal, and duplicate callback fixtures. | Real process and stream probes produce one typed failure per missing/drop case and never normal success. |
| V12 | Abort, abort-and-prompt, provider/tool error, extension throw/timeout, malformed input, and process loss | REQ-RPC-02, REQ-LIVE-01 | `omp-p3-worker-live`; worker owner | Abort/error/throw/timeout and process-loss fixtures. | Live slow/failing stream, abort acknowledgement, replacement delivery where supported, terminal or typed process failure, and no hidden normal stop. |
| V13 | Continuation throw, timeout, abort, repeated run, cap, and reset | REQ-CONT-01 | `omp-p3-continuation-followup`; turn-end owner | All failure and reset fixtures. | Real supervised cycle with lower budget and one visible failure. |
| V14 | Follow-up after idle, stream, interrupt, invalid tail, provider/tool error, queue suppression | REQ-FOLLOW-01 | `omp-p3-continuation-followup`; send owner | Queue and state-transition fixtures. | Real `agent_start` and eventual turn or durable delivery failure. |
| V15 | Worker exact-once completion across every normal and abnormal path | REQ-RPC-02 | `omp-p3-worker-live`; completion owner | Callback count fixtures for normal, abort, abort-and-prompt, provider/tool error, extension throw/timeout, malformed input, dropped/duplicate event, and process exit. | Multiple real turns and every abnormal path; exactly one signal or one typed failure per path, with no duplicate signal and no cleanup inferred from missing completion. |
| V16 | Tmux running, idle, streaming, interrupted, dead owner, shell survivor, unknown wrapper | REQ-BACKEND-01 | `omp-p4-tmux-classifier`; tmux owner | Classifier fixtures. | Real Bun ancestry and no-respawn unknown behavior. |
| V17 | Herdr ready, prompt, stream, follow-up, steer, abort, exit, resume, idle, dead owner | REQ-BACKEND-02 | `omp-p5-herdr-parity`; Herdr owner | Recognition and command fixtures. | Pinned Herdr live lab for every lifecycle row. |
| V18 | Successor before wake and lock ownership | REQ-WATCH-01 | `omp-p6-supervision-continuity`; watcher owner | Single-flight, lock-change, retry, and hung successor fixtures. | Real two-wake continuity E2E. |
| V19 | Two homes with separate locks, state, project, extension, watcher, and wake | REQ-HOME-01 | `omp-p7-two-home-isolation`; home owner | Path and lock fixtures. | Two real homes under shared code root. |
| V20 | Worker, primary, and secondmate restart with sole owner | REQ-REC-01 | `omp-p7-recovery`; recovery owner | Stale marker and duplicate recovery fixtures. | Real kill/restart and one-owner proof. |
| V21 | Complete cleanup of every nested and top-level surface | REQ-CLEAN-01 | `omp-p3-cleanup-live`, `omp-p7-cleanup-complete`; teardown owner | Inventory and missing-residue fixtures. | Real `fm-teardown.sh` and process/path inspection. |
| V22 | Dirty, unlanded, and unresolved-decision cleanup refusal | REQ-CLEAN-02 | `omp-p7-cleanup-complete`; teardown and decision owner | Refusal fixtures. | Real refusal and no bypass. |
| V23 | Existing harness, secondmate, backend, watcher, recovery, cleanup, Bun/TypeScript, and dependency regression | REQ-REG-01 | `omp-p3-regression`, `omp-p8-full-validation`; repository owner | All targeted suites, full `tests/*.test.sh` loop, pinned Bun syntax/type/import/load checks, and package/source hash checks. | Every existing test, applicable lint, OMP-native validation, and repository validation owner. |
| V24 | Evidence redaction and link pinning | REQ-LINK-01, REQ-LIVE-01 | `omp-p1-runtime-pin`, `omp-p8-full-validation`; evidence owner | Redaction and URL parser. | Dated exact command/output artifact with credentials removed. |
| V25 | Promotion wording and state transitions | REQ-SCOPE-01 | `omp-p4-tmux-provisional`, `omp-p8-policy-publication`; docs owner | Stale five-harness and state-label tests. | Review every user and agent surface before publication. |
| V26 | Current-code owner and artifact-map completeness | REQ-MAP-01 | `omp-plan-block-corrections-o7`, `omp-final-corrected-plan-redteam-o9`, `omp-p8-policy-publication`; plan owner | `git ls-files`, exact owner table, and path checks cover secondmate positional parsing, raw launch, generated hook, send, continuity, every teardown list, package/type/load validation, and full regression. | Live-derived path inventory matches the current tree, missing or stale owner paths block O9 and P8, and the artifact/rollback rows exist for every task. |
| V27 | Stale path and terminology closure | REQ-DOC-01 | `omp-plan-block-corrections-o7`, `omp-final-corrected-plan-redteam-o9`, `omp-p8-policy-publication`; documentation owner | `legacy_prefix=$(printf 't%s' 'h-'); legacy_role=$(printf 'Ar%s' 'chon'); rg -n "(^|[^[:alnum:]_])$legacy_prefix|persistent[[:space:]]+supervisor|$legacy_role" .agents/plans/omp-harness-integration-plan.md .agents/tasks/roadmap.md .agents/tasks/backlog.md` plus Markdown/link/path checks, with each intentional historical reference classified. | No stale current-surface reference remains, and any individually stale external link is pinned or labeled before publication. |
| V28 | Live Status and Bearings monitoring projection | REQ-MON-01 | `omp-plan-block-corrections-o7`, `omp-final-corrected-plan-redteam-o9`, `omp-p8-policy-publication`; reporting owner | Fixture cases for manifest-only, active, blocked, and genuine decision records run through `bin/fm-fleet-snapshot.sh --json`, `bin/fm-bearings-snapshot.sh --json`, `tests/fm-status-report.test.sh`, and `tests/fm-bearings-snapshot.test.sh`. | Actual projections show phase, milestone, scoped completed/total, live Git branch, blockers with STOP/owner/containment, next gate, and `needs:human` options only for a genuine decision, without future rows inflating the denominator. |
| V29 | Guarded P8 publication transaction and partial-failure recovery | REQ-SCOPE-01, REQ-DOC-01, REQ-REG-01 | `omp-p8-policy-publication`; publication owner | Disposable-clone simulation interrupts after each exact inventory group, runs invariant checks, performs one-commit publication, and proves a clean `git revert`. | Every partial state is refused, the complete publication has one commit or flag boundary, post-publication invariants pass, and the recoverable revert restores the prior support state and all artifact inventories. |

## Hard stops

The following stops are immediate and retain the current BLOCK verdict.

| Stop | Trigger | Requirement and task | Consequence and containment |
| --- | --- | --- | --- |
| STOP-01 | Noext still drops explicit extensions, the complete discovery surface is not inventoried, or loaded bytes are mutable or replaceable between preflight and import. | REQ-DISC-01, REQ-DISC-02, REQ-EXT-01; `omp-p1-discovery-isolation`, `omp-p2-extension-handshake` | Stop all implementation; keep experimental and first-class states unavailable. |
| STOP-02 | Mandatory extension can fail, be missing, duplicated, unexpected, or replaced while OMP reaches ready or accepts work. | REQ-EXT-02; `omp-p2-extension-handshake` | Abort before brief and retain no support claim. |
| STOP-03 | Host identity or lock ownership depends on mixed child markers, an unverified wrapper, or an unowned ancestry path. | REQ-ID-01, REQ-ID-02; `omp-p1-identity-ancestry`, `omp-p2-identity-adapter` | Stop identity, lock, supervision, and recovery work; do not add OMP to policy. |
| STOP-04 | Effective model, provider, or thinking differs from requested policy without explicit reject or map. | REQ-STATE-01; `omp-p2-thinking-state` | Reject launch and record mismatch. |
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
| Plan execution drift | A prose plan can omit a seam or activate tasks early. | Stable manifest, dependency graph, phase-scoped progress, O9 validation before activation. | `.agents/tasks/roadmap.md`; progress and blocker fields. |
| Activation drift | O8 completion or captain authorization could be mistaken for implementation permission. | Existing `omp-p1-activation-a7` checks corrected-plan O9 `PASS`, no plan-blocking finding, verified hold, clean diff, and no premature P1-P8 row. | Activation gate; refusal is the safe result and reports the failing check. |
| Mutable extension trust | A canonical path and preflight hash can still be replaced before import. | Content-addressed read-only staging or OMP-side byte-bound loading, immediate pre-import hash proof, and startup registration handshake. | `omp-p1-discovery-isolation`, `omp-p2-extension-handshake`; STOP-01 and STOP-02. |
| Monitoring drift | Prose progress can disagree with Status or Bearings output or use a historical branch. | V28 fixture projections and live Git branch derivation from `git symbolic-ref` or `git rev-parse`. | `omp-plan-block-corrections-o7`, `omp-final-corrected-plan-redteam-o9`; REQ-MON-01. |

## Captain-facing tracking contract

Status and Bearings must report the current phase and milestone rather than a percentage over the entire future program.

The scoped denominator is the number of tasks in the current active phase after manifest activation.

Future phases do not inflate the denominator.

A task counts complete only when its acceptance evidence path and exit criterion are recorded.

A blocked task reports the stop ID, evidence gap, owner, and containment state.

The active branch is derived at read time from `git branch --show-current` or `git rev-parse --abbrev-ref HEAD`, and no historical branch string is authoritative.

The O7 correction branch name is historical provenance only; future Status and Bearings records must derive the active value from live Git state.

The next gate is `omp-final-corrected-plan-redteam-o9` with explicit `PASS` and no plan-blocking finding required.

The current blocker is the preserved O8 `BLOCK` result and the required independent O9 validation, not an implementation failure.

The current `needs:human` list is empty because the captain authorization is already recorded and the remaining gate is evidence-based rather than a product choice.

When a genuine choice appears later, the task record must use a stable key, list at least two concrete options, state the consequence of each, and record the recommendation.

No ordinary task receives a captain hold merely because it is future work.

After O9 passes and activation completes, Tasks Axi `blocked-by` edges control readiness and only genuine decisions use structured holds.

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

The `.agents/tasks` roadmap contains stable future IDs as prose, while the parseable backlog contains no executable P1-P8 implementation rows until O9 passes and activation completes.

The live firstmate backlog contains no newly activated P1-P8 implementation task before O9 validation and activation.

Markdown, link/path, non-mutating Tasks Axi list/show/ready, clean-diff, and documentation validation pass.

The branch is rebased onto current `main`, contains focused commits, and is clean.

No OMP runtime support is implemented or claimed.
