# Backlog

## In flight
## Queued
- [ ] omp-u0-early-detection-correctness - U0: early OMP detection-correctness milestone (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U0 - Land the early detection-correctness milestone.
  Goal: Fix OMP misdetection and the option-safe basename crash, and keep non-OMP children under an OMP primary detecting as themselves, without activating first-class OMP supervision.

  Requirements: R1, R2, R4, R30, R31, R32.
  Acceptance examples: AE1, AE2, AE3, AE4, AE16, AE22, AE23, AE24.
  Live-matrix scenarios: row 26 (a non-OMP child of an OMP primary detects as its own harness).

  File surfaces:
  - bin/fm-harness.sh
  - bin/fm-lock.sh
  - bin/fm-spawn.sh
  - tests/fm-omp-harness.test.sh (new)
  - tests/fm-secondmate-harness.test.sh
  - tests/fm-bootstrap.test.sh

  Completion and verification:
  - An OMP primary detects as omp, both basename sites tolerate option-like command names, a non-OMP child under an OMP primary detects as its own harness, and omp is absent from every first-class supervision allowlist.
  - Run bash tests/fm-omp-harness.test.sh, tests/fm-secondmate-harness.test.sh, and tests/fm-bootstrap.test.sh.

  Stop conditions and captain-settled constraints:
  - Captain rollout decision (early-correctness fix, later activation): do not add omp to any first-class supervision allowlist in this milestone.
  - Captain mixed-support decision: scrub inherited OMP markers unconditionally for every non-OMP child, so Claude, Codex, and Grok children retain their own identity.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U0) for full contract detail.
- [ ] omp-u1-verification-ledger - U1: isolated OMP verification ledger (repo: Agent-Themis) (kind: scout) (since 2026-07-20)
  Owning unit: U1 - Establish the isolated OMP verification ledger.
  Goal: Replace remaining OMP assumptions with dated, reproducible observations before permanent policy is written.

  Requirements: R6, R8, R11, R13, R14, R21, R22, R23, R24, R33, R38.
  Acceptance examples: AE5, AE6, AE7, AE8, AE9, AE10, AE11, AE12, AE13, AE14, AE17, AE18, AE19, AE20, AE21, AE22, AE31, AE32, AE37, AE38, AE39, AE42.
  Live-matrix scenarios: U1 produces the evidence for the whole pre-merge live matrix; its mandatory rows are native per-turn completion, primary stop, pre-tool blocking, idle and streaming follow-up, countable continuation, and Herdr hosting and classification of an OMP or Bun agent, and it establishes the abnormal-completion (row 30), multi-turn (row 31), and N-consecutive-run behaviors.

  File surfaces:
  - Temporary ledger and captures outside the project worktree, produced as the sanitized artifact defined in R39 and never committed with raw secrets.

  Completion and verification:
  - Every policy-shaping OMP behavior has reproducible live evidence or a safe fallback defined in the plan, including Herdr hosting pre-verification and N-consecutive-run confirmation of the corruption-sensitive behaviors.
  - The uncommitted ledger contains no unmarked inference and no unredacted credential, every failed hard-contract observation blocks implementation, and the project worktree remains clean after the spike.

  Stop conditions and captain-settled constraints:
  - Absence of any native contract required by the supervision requirements is a blocker, and terminal scraping must not substitute for lifecycle truth.
  - Herdr's inability to host or classify an OMP or Bun agent is a blocker or an explicitly staged tmux-first deferral, never an assumed pass.
  - This is a proof-only scout unit that produces evidence and changes no permanent harness allowlist or policy documentation.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U1) for full contract detail.
- [ ] omp-u2-identity-config - U2: OMP identity and option-safe session ownership blocked-by: omp-u0-early-detection-correctness blocked-by: omp-u1-verification-ledger (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U2 - Add OMP identity and option-safe session ownership.
  Goal: Complete OMP identity and configuration handling on top of U0's early fix, so every validator and configuration surface accepts omp before any OMP-specific launch or supervision policy runs.

  Requirements: R3, R5, R30.
  Acceptance examples: AE1, AE2, AE3, AE4, AE16, AE22.
  Live-matrix scenarios: row 26 (a non-OMP child of an OMP primary detects as its own harness).

  File surfaces:
  - bin/fm-harness.sh
  - bin/fm-lock.sh
  - bin/fm-bootstrap.sh
  - tests/fm-omp-harness.test.sh
  - tests/fm-bootstrap.test.sh
  - tests/fm-session-start.test.sh
  - tests/fm-secondmate-harness.test.sh
  - tests/fm-spawn-dispatch-profile.test.sh

  Completion and verification:
  - OMP identity is complete across every validator and configuration surface on top of U0's early fix, under dual markers, nearest-ancestry authority, ancestry fallback, and option-like command names.
  - Run bash tests/fm-omp-harness.test.sh, tests/fm-bootstrap.test.sh, tests/fm-session-start.test.sh, tests/fm-secondmate-harness.test.sh, and tests/fm-spawn-dispatch-profile.test.sh.

  Stop conditions and captain-settled constraints:
  - Build on U0's precedence, nearest-ancestry, option-safe basename, and marker scrub rather than reintroducing an unconditional OMPCODE-first rule.
  - Do not add omp to the supervision allowlist in this unit, which is owned by U6 under the rollout constraint.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U2) for full contract detail.
- [ ] omp-u3-launch-profiles - U3: verified OMP launch profiles and effort mapping blocked-by: omp-u1-verification-ledger blocked-by: omp-u2-identity-config (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U3 - Add verified OMP launch profiles and effort mapping.
  Goal: Launch OMP workers and secondmates with the intended model, reasoning, approval policy, extensions, brief, verified executable provenance and version, and a role-scoped environment.

  Requirements: R6, R7, R8, R9, R10, R14, R30, R33, R34.
  Acceptance examples: AE5, AE16, AE17, AE18, AE39, AE40, AE41.
  Live-matrix scenarios: row 2 (each effort value), row 17 (raw launch while invalid adapter rejected), row 39 (provenance and cleared-base environment), row 40 (live secondmate launch confirms model, reasoning, approval, extensions, charter).

  File surfaces:
  - bin/fm-spawn.sh
  - bin/fm-bootstrap.sh
  - tests/fm-omp-harness.test.sh
  - tests/fm-spawn-batch.test.sh
  - tests/fm-spawn-dispatch-profile.test.sh
  - tests/fm-secondmate-harness.test.sh

  Completion and verification:
  - Task and secondmate launches preserve the intended model, effort, approval, extensions, and brief, and enforce executable provenance, a supported-version gate, and a role-scoped environment.
  - A dispatch-profile test proves an invalid OMP effort is rejected rather than accepted through the validator's else-true default, a full environment diff proves a non-role provider key is absent from the launched process, and a live secondmate launch confirms the effective settings.

  Stop conditions and captain-settled constraints:
  - Resolve the executable from a configured absolute path with a committed supported-version checksum baseline, and keep the raw-launch escape hatch for isolated verification only.
  - Construct the child environment from a cleared base reconciled with the deliberate GOTMPDIR export rather than prepending to the inherited environment.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U3) for full contract detail.
- [ ] omp-u4-worker-completion-extension - U4: OMP task completion extension blocked-by: omp-u1-verification-ledger blocked-by: omp-u3-launch-profiles (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U4 - Implement the OMP task completion extension.
  Goal: Signal worker turn completion once per turn through OMP's native lifecycle API, with the generated extension permission-locked, integrity-checked, and discovery-isolated.

  Requirements: R11, R12, R13, R14, R19, R25, R30, R35.
  Acceptance examples: AE6, AE15, AE16, AE19, AE31, AE32, AE33.
  Live-matrix scenarios: row 6 (completion exactly once), rows 18 and 19 (worker launch, completion, residue-free teardown), row 25 (teardown residue-free), row 30 (abnormal-turn completion), row 31 (multi-turn per-turn signalling), row 32 (hostile-checkout augmentation prevented).

  File surfaces:
  - bin/fm-spawn.sh
  - bin/fm-teardown.sh
  - bin/omp-extensions/lib/pi-family.ts (only if U1 proves safe shared imports)
  - Shared Pi and OMP behavioral fixture tests, added regardless whenever a helper is extracted.
  - tests/fm-omp-harness.test.sh
  - tests/fm-omp-worker-live-e2e.test.sh (new)
  - tests/fm-teardown.test.sh

  Completion and verification:
  - Worker completion emits one signal per completed turn with per-turn binding, the generated extension is permission-locked and integrity-checked, hostile-checkout augmentation is prevented, and cleanup is proven.
  - A live multi-turn worker proves one signal per turn, and a live worker whose turn ends abnormally proves the completion event fires exactly once or its absence is surfaced.

  Stop conditions and captain-settled constraints:
  - KTD16: the in-process extension is the default worker-completion mechanism, and U1 may confirm a lower-trust out-of-process hook alternative.
  - Write the generated extension with restrictive permissions mirroring the Grok worker hook umask 077, adopt its token-match guard, and give any extracted helper its own behavioral fixture with a genuine second consumer or name it OMP-specific.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U4) for full contract detail.
- [ ] omp-u5-primary-extensions - U5: hardened OMP primary extensions blocked-by: omp-u1-verification-ledger blocked-by: omp-u2-identity-config blocked-by: omp-u3-launch-profiles blocked-by: omp-u4-worker-completion-extension (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U5 - Implement hardened OMP primary extensions.
  Goal: Give primary OMP sessions native watcher delivery with extension-owned continuity, pre-tool blocking, bounded turn-end enforcement, fail-visible error handling, and fail-closed home resolution.

  Requirements: R15, R16, R17, R18, R19, R20, R24, R30, R36, R37.
  Acceptance examples: AE7, AE8, AE9, AE10, AE11, AE12, AE16, AE17, AE21, AE25, AE26, AE27, AE28, AE29, AE30, AE44, AE45.
  Live-matrix scenarios: row 5 (discovery disabled or isolated before import), rows 8 and 9 (stop continuation and repeated-failure), rows 10 and 11 (pre-tool blocks), rows 12 and 13 (idle and streaming wake), row 22 (two-home isolation), row 23 (double-load recovery), rows 27 and 28 (consecutive wakes and wake-after-continuation), row 29 (continuation-allowance exhaustion), row 36 (idle async failure recorded to the per-cycle exit log), row 37 (checker-spawn failure blocks), row 38 (FM_HOME unset refused), row 42 (successor launched and verified before the wake), row 43 (typed continuity-restoration failure at the retry limit).

  File surfaces:
  - bin/omp-extensions/fm-primary-omp-watch.ts (new)
  - bin/omp-extensions/fm-primary-turnend-guard.ts (new)
  - bin/omp-extensions/lib/pi-family.ts (only when created by U4)
  - tests/fm-omp-watch-extension.test.sh (new)
  - tests/fm-omp-primary-types.test.sh (new)
  - tests/fm-arm-pretool-check.test.sh
  - tests/fm-cd-pretool-check.test.sh
  - tests/fm-turnend-guard.test.sh

  Completion and verification:
  - Watcher delivery with extension-owned continuity, pre-tool blocking, bounded turn-end enforcement, fail-visible error handling, the per-cycle exit log, and the fail-closed FM_HOME guard pass fixture and live tests, including consecutive wakes and a wake after a continuation.
  - A continuity fixture blocks prompt delivery to prove the singleton successor launches and session-lock ownership is rechecked before the wake, proves single-flight, and hangs each successor arm to prove the bounded fallback delivers the typed continuity-restoration failure.
  - Fixtures prove a wake-delivery, child-spawn, and pre-tool-checker-spawn failure each surface as typed watcher failures rather than failing open, that a failed follow-up never cancels continuity restoration, and that the extension refuses to resolve against the shared code root when FM_HOME is unset.

  Stop conditions and captain-settled constraints:
  - Implement the landed watcher-continuity contract per docs/watcher-continuity.md rather than a shallow one-follow-up port: successor before wake, session-lock recheck, bounded exponential retry, single-flight, and a typed continuity-restoration failure at the retry limit.
  - Disable or isolate ambient discovery before any discovered extension executes its default export at import, and treat the self-written hash as a staleness diagnostic rather than integrity.
  - The turn may end loudly with a visible failure after the bounded continuation allowance is spent rather than recursing or ending silently blind.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U5) for full contract detail.
- [ ] omp-u6-startup-supervision - U6: OMP startup diagnostics and supervision instructions blocked-by: omp-u5-primary-extensions (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U6 - Wire OMP startup diagnostics and supervision instructions.
  Goal: Make session startup prove the expected OMP extensions are loaded and emit the correct OMP operating protocol, adding omp to the supervision allowlist only once its guard extension exists.

  Requirements: R15, R16, R17, R18, R19, R20, R26, R28, R30.
  Acceptance examples: AE7, AE8, AE10, AE11, AE12, AE16, AE28, AE29.
  Live-matrix scenarios: row 1 (primary startup with dual markers), rows 8 and 9 (stop continuation and repeated failure), rows 12 and 13 (idle and streaming wake), rows 27 and 28 (consecutive wakes and wake-after-continuation).

  File surfaces:
  - bin/fm-session-start.sh
  - bin/fm-supervision-instructions.sh
  - docs/supervision-protocols/omp.md (new)
  - docs/turnend-guard.md
  - tests/fm-session-start.test.sh
  - tests/fm-supervision-instructions.test.sh

  Completion and verification:
  - Startup diagnostics and supervision instructions prove the correct OMP extensions are loaded and usable, omp is added to the supervision allowlist only alongside its guard extension, and two consecutive live wakes with a rearm pass.
  - The captain-facing primary launch contract is documented in docs/supervision-protocols/omp.md, and a live primary OMP session passes startup, receives two consecutive wakes with a full rearm between them, and exits cleanly.

  Stop conditions and captain-settled constraints:
  - Honor the rollout constraint that detection-activation never precedes the guard extension.
  - Because OMP loads the tracked primary extensions outside its discovery roots with discovery disabled, the captain must launch the primary with explicit extension flags for both primary extensions, as there is no plain-launch auto-discovery fallback.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U6) for full contract detail.
- [ ] omp-u7-liveness-controls - U7: OMP liveness, TUI fallback, and lifecycle controls blocked-by: omp-u1-verification-ledger blocked-by: omp-u3-launch-profiles blocked-by: omp-u5-primary-extensions blocked-by: omp-u6-startup-supervision (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U7 - Add OMP liveness, TUI fallback, and lifecycle controls.
  Goal: Classify and control live OMP sessions correctly under tmux and Herdr, distinguishing a live wrapper from a dead one, without making TUI text the primary truth source.

  Requirements: R14, R21, R22, R23, R24, R26, R30, R38.
  Acceptance examples: AE13, AE14, AE16, AE20, AE21, AE28, AE36, AE38, AE43.
  Live-matrix scenarios: rows 14 and 15 (tmux and Herdr busy, idle, interrupt, exit, resume), row 20 (secondmate routed work), row 21 (forced recovery no second owner), row 22 (two-home isolation under the shared-code-root topology), row 27 (two consecutive response wakes), row 35 (confident-dead secondmate respawned once), row 41 (landed Herdr workspace contract unchanged).

  File surfaces:
  - bin/fm-backend.sh
  - bin/fm-composer-lib.sh
  - bin/backends/tmux.sh
  - bin/backends/herdr.sh
  - bin/fm-send.sh (when U1 demonstrates generic submission is insufficient)
  - tests/fm-backend-tmux-smoke.test.sh
  - tests/fm-backend-herdr-smoke.test.sh
  - tests/fm-send-settle.test.sh (when submission behavior changes)
  - tests/fm-omp-primary-live-e2e.test.sh (new)

  Completion and verification:
  - tmux and Herdr classify and control OMP sessions correctly, including a live-versus-dead wrapper distinction and confident-dead respawn, with two-home isolation proven under the production shared-code-root topology.
  - OMP spawns route through the landed per-project Herdr workspace contract without change: an ordinary OMP worker lands in its project's <Fleet display name>-Fleet workspace resolved by bin/fm-project-mode.sh --fleet, an OMP secondmate in Archon-<secondmate-id>, and an OMP primary supervisor is Themis.
  - A Herdr regression check proves the OMP work leaves that landed workspace contract unchanged: primary supervisor Themis, secondmate supervisor Archon-<secondmate-id> failing closed to a bare Archon, and per-project ordinary-worker <Fleet display name>-Fleet workspaces.

  Stop conditions and captain-settled constraints:
  - Consume U1's Herdr hosting and classification pre-verification, treating a failure as a blocker or the explicitly staged tmux-first deferral rather than proceeding to parity.
  - An over-conservative unknown classification must not prevent confident true-death detection and respawn.
  - The OMP work must not disturb the landed Herdr workspace contract: primary supervisor Themis, secondmate supervisor Archon-<secondmate-id>, and per-project ordinary-worker <Fleet display name>-Fleet workspaces.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U7) for full contract detail.
- [ ] omp-u8-cleanup-recovery-trust - U8: OMP cleanup, recovery, and extension trust hardening blocked-by: omp-u4-worker-completion-extension blocked-by: omp-u5-primary-extensions blocked-by: omp-u6-startup-supervision blocked-by: omp-u7-liveness-controls (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U8 - Complete OMP cleanup, recovery, and extension trust hardening.
  Goal: Remove every OMP-owned runtime artifact safely and recover across all four R26 modes without duplicate children, stale markers, never-respawned dead owners, or project contamination.

  Requirements: R12, R15, R19, R20, R25, R26, R30, R35, R37.
  Acceptance examples: AE12, AE15, AE16, AE20, AE21, AE33, AE34, AE35, AE36.
  Live-matrix scenarios: row 5 (discovery disabled or isolated), row 24 (staleness-marker validation and discovery isolation), row 25 (teardown residue-free), row 32 (hostile-checkout augmentation prevented), row 33 (primary-restart recovery), row 34 (worker-exit recovery), row 35 (secondmate-restart confident-dead respawn).

  File surfaces:
  - bin/fm-teardown.sh
  - bin/fm-session-start.sh
  - bin/fm-spawn.sh
  - bin/omp-extensions/fm-primary-omp-watch.ts
  - bin/omp-extensions/fm-primary-turnend-guard.ts
  - tests/fm-teardown.test.sh
  - tests/fm-session-start.test.sh
  - tests/fm-omp-watch-extension.test.sh
  - tests/fm-omp-primary-live-e2e.test.sh

  Completion and verification:
  - Stale-marker recovery, all four R26 recovery modes, and teardown leave one valid primary integration and no task-owned residue.
  - Primary-restart, worker-exit, and secondmate-restart recovery each preserve one live owner and correct identity, the confident-dead case respawns exactly once, and profile and project injection attempts are disabled or isolated including for a worker in a hostile project checkout.

  Stop conditions and captain-settled constraints:
  - Treat the loaded marker as a staleness diagnostic rather than tamper integrity, and disable or isolate discovery rather than rejecting it after import.
  - Edit both the top-level and nested secondmate hardcoded removal lists so neither generated artifact is missed.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U8) for full contract detail.
- [ ] omp-u9-publish-and-gate - U9: publish verified OMP adapter policy and run the full gate blocked-by: omp-u2-identity-config blocked-by: omp-u3-launch-profiles blocked-by: omp-u4-worker-completion-extension blocked-by: omp-u5-primary-extensions blocked-by: omp-u6-startup-supervision blocked-by: omp-u7-liveness-controls blocked-by: omp-u8-cleanup-recovery-trust blocked-by: omp-u0-early-detection-correctness (repo: Agent-Themis) (kind: ship) (since 2026-07-20)
  Owning unit: U9 - Publish verified adapter policy and run the full gate.
  Goal: Declare OMP supported only after code, live evidence, documentation, and regressions agree.

  Requirements: R27, R28, R29, R30, R39.
  Acceptance examples: AE1 through AE45 (the full acceptance set).
  Live-matrix scenarios: the full pre-merge live ledger (rows 1 through 43), with each corruption-sensitive row passing at least 20 consecutive runs.

  File surfaces:
  - AGENTS.md
  - .agents/skills/harness-adapters/SKILL.md
  - docs/configuration.md
  - docs/supervision-protocols/omp.md
  - docs/turnend-guard.md
  - CONTRIBUTING.md (only if its verified-harness or test guidance requires an update)
  - All targeted test files from U0 and U2 through U8.

  Completion and verification:
  - omp is added to verified adapter lists only after U0 through U8 acceptance and every required live row passes, with each corruption-sensitive row across at least 20 consecutive runs.
  - The single sanitized durable evidence artifact is redacted, handed off, and attached, targeted tests, repository lint, the no-mistakes pipeline, and CI pass, and the final diff review confirms no stale five-harness lists and no disturbance of the landed Herdr workspace contract: primary supervisor Themis, secondmate supervisor Archon-<secondmate-id>, and per-project ordinary-worker <Fleet display name>-Fleet workspaces.

  Stop conditions and captain-settled constraints:
  - Documentation may call OMP verified only when both CI and the pre-merge live ledger pass and redaction is confirmed.
  - The clean-cutover must not disturb the landed Herdr workspace contract, the primary supervisor workspace Themis, the secondmate supervisor workspaces Archon-<secondmate-id>, and the per-project ordinary-worker <Fleet display name>-Fleet workspaces, which are unrelated repo terminology.

  Authority: see .agents/plans/omp-harness-integration-plan.md (U9) for full contract detail.
## Done
