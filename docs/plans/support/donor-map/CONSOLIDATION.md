# Themis donor-map consolidation

Date: 2026-07-27.

This is the port specification assembled from reports 00-07, 09, and 10, `SCOUT-BRIEF.md`, `VALIDATION.md`, and the Themis fleet-orchestrator plan.
Report 08 is not present; the plan itself labels assignment 8 as a small companion to assignment 7, but no report file was supplied.

The reports are evidence, not authority.
Where a report cites prose rather than implementation, this document says so.
`VALIDATION.md` is the controlling adversarial correction for the four claims it tested.

## Executive result

The port is not a file-copy exercise.
The durable core is the deterministic supervision model, Herdr's explicit-session and native-state safety, no-mistakes run attribution, Treehouse isolation assertions, and landed-work proof.
The largest risks are not missing ideas but prose-only rules and unresolved target architecture: the join record, the local-versus-GitHub task projection, the exact merge-approval contract, and the authority of the three target harness surfaces.

The most important corrections to carry into implementation are:

- Keyed decisions are not fixed by copying the fold: ordinary ship and scout briefs do not teach keyed opening, and the downstream decision-hold consumer masks the fold after `done` or `failed` for those task kinds (`VALIDATION.md:18-78`).
- Lock-refused read-only mode is enforced only inside `fm-session-start.sh`; the correct count is three files and four line-sites, not four files (`VALIDATION.md:80-130`).
- OMP's `harness_pid` failure has no in-session recovery path, but it does not create a durable latch or cleanup artifact (`VALIDATION.md:132-196`).
- The landed-work ladder is strong for `ship`, but `scout` and `secondmate` bypass it without `--force`, and ship teardown also filters all untracked `.claude/` content (`VALIDATION.md:197-273`).
- The target plan already settles the intended state precedence and scout exemption, but it does not settle the implementation shape for the durable join record, backlog projection, or CLI boundary (`docs/plans/2026-07-26-001-feat-themis-fleet-orchestrator-plan.md:62-124,174-202`).

## 1. Contradictions and corrections

These are disagreements about the same mechanism, not merely different emphasis.
The first citation is the report claim; the second is the conflicting report or validation evidence.

| # | Mechanism | Conflicting evidence | Consolidated finding |
|---|---|---|---|
| C1 | Keyed decision lifecycle | Report 00 calls the fold a sound ~40-line mechanism but says it is unreachable in ordinary work; report 04 marks the brief contract `rebuild` because it only teaches the close side (`00-supervision-and-wake.md:95-103,225-279`; `04-dispatch-briefs-recovery.md:263-266`). `VALIDATION.md` adds that `fm-decision-hold.sh` suppresses the folded decisions for ship/scout after `done` or `failed` (`VALIDATION.md:18-78`). | Rebuild the worker open/close protocol, fold, and downstream consumer together. Do not call this a copy. Test two simultaneous decisions, a blocker plus a decision, and terminal status followed by resolution. |
| C2 | Lock-refused read-only enforcement | Report 03 says the lock is read by “exactly four files,” while validation found three files and four line-sites and confirmed that the three named mutators do not check it (`03-session-start.md:11-21`; `VALIDATION.md:80-130`). | Keep the finding, correct the count, and put the lock check at every mutating chokepoint or in an equivalent runtime guard. A banner and supervision prose are not enforcement. |
| C3 | OMP harness classification | Report 03 treats the omitted `omp` entry in `HARNESS_RE` as a portable-harness defect and a permanent read-only degradation (`03-session-start.md:11-19,193-200`). Validation confirms the no-recovery behavior but says OMP is unsupported by the donor's verified harness list, and that no durable latch exists (`VALIDATION.md:132-196`). | In Themis, OMP is a target bridge and therefore needs an explicit verified adapter entry. Describe the donor issue as unsupported-harness handling plus a misleading banner, not as a stale durable lock. |
| C4 | Scout/secondmate landed-work protection | Report 06's headline frames the teardown ladder as the safety source and report 07 carries landed-work proof forward as a copy (`06-treehouse-isolation.md:16-76,240-279`; `07-lifecycle-and-backlog.md:198-212`). Validation refutes the universal claim: `scout` and `secondmate` bypass the ladder, while ship is the only complete path (`VALIDATION.md:197-273`). | Preserve the plan's explicit split: ship requires landed proof; scout requires the report and decision gate; any future exempt kind must have its own product check (`plan:80-91`). Never generalize ship's proof to every task kind, and never add a bare exemption. |
| C5 | Herdr liveness verdict | Report 03 marks the Herdr liveness probe `copy` and treats `dead/no-agent/live/unknown` as directly reusable (`03-session-start.md:154-160`). Report 02 marks the larger busy/liveness/husk mechanism `rebuild` because 0.7.5 behavior differs by harness and needs a canonical policy (`02-herdr-verification.md:102-107,246-261`). | Copy the three-state fail-safe principle and unknown refusal; rebuild the classifier, screen-detection policy, and husk recovery around current Herdr evidence. This is a copy of a rule, not of the donor implementation. |
| C6 | Treehouse isolation proof | Report 01 says Herdr `foreground_cwd` tracking is a copyable signal that proves entry into the isolated worktree (`01-herdr-adapter.md:83-92,195-202`). Report 06 marks acquisition plus cwd polling `rebuild`, replacing inference with the external CLI's returned path (`06-treehouse-isolation.md:77-119,240-279`). | Keep both checks at different boundaries: Treehouse's returned path is the allocation result; Herdr `foreground_cwd` is the post-launch assertion. Do not use either alone as proof. |
| C7 | Session-start nudge | Report 03 marks the nudge wrapper and silence predicates `copy` and treats a nudge as the execution rail (`03-session-start.md:163-167`). Report 05 marks nudge suppression `strip`, but explicitly says that verdict flips if a nudge is ported (`05-no-mistakes.md:89-99,196-224`). | The reports do not establish a product decision. The plan requires one persona source and three generated surfaces but does not require or reject a nudge (`plan:88-96`). Keep this as a design choice: if startup state is required, port a deterministic nudge and enforce its idempotence; otherwise remove both the nudge and its suppression logic. |
| C8 | Workspace topology | Report 02's mechanism inventory says workspace-per-task is rejected as the durable model and retained only as a disposable projection (`02-herdr-verification.md:43-57`). Its verdict later says to rebuild workspace-per-project/tab-per-task as the decided shape (`02-herdr-verification.md:246-252`). | The verdict and the Themis plan win: reusable workspace-per-project, tab-per-task is the intended volatile runtime topology. The report's inventory sentence is stale or refers to the donor projection and must not be ported literally. |
| C9 | Review authority | Report 05 repeats the donor rule that no-mistakes owns review, fixes, tests, documentation, push, PR, and CI (`05-no-mistakes.md:41-59,224-244`). The same report finds the target persona injects mandatory reviewer and RedTeam passes, and report 07 calls that a direct conflict (`05-no-mistakes.md:187-224`; `07-lifecycle-and-backlog.md:194-212`). | Choose one authority per delivery mode. If no-mistakes is selected, target reviewer prose cannot create a second required gate; encode the ownership boundary in the tool hook and worker contract. |

Other apparent disagreements are not contradictions after scope is separated.
Report 01's event transport and report 02's blocked-event push both rebuild the same Herdr-only path; report 01's label recovery strip and report 02's label-adoption rebuild differ because one is donor production wiring and the other is the capability to recover under authoritative local IDs.

## 2. Verdict ledger

### Source totals

The ten supplied subsystem reports contain 208 source verdict rows.
The count includes report 00's corrected R2 verdict as `copy`, not its original `rebuild` label.

| Source verdict | Count |
|---|---:|
| copy | 94 |
| strip | 35 |
| rebuild | 79 |
| total | 208 |

These are source-row totals, before deduplication.
The ledger below deduplicates overlapping rows into implementation families; report labels in the second column preserve coverage and make the source rows auditable.
`absent`, `partial`, and `present` refer to the “already have it?” column in the reports, not to current implementation in this repository.

### Deduplicated ledger

| Mechanism family | Owning report rows | Consolidated verdict | Already have it? |
|---|---|---|---|
| Append-only task events and separate deterministic current state | 00 C1-C2; 04 B2; 09 E4/S2 | rebuild | partial prose only; no per-task event/state implementation |
| Keyed decisions, captain-held transfer, and completion gate | 00 C3; 04 B3; 09 V1; 07 B4; 10 M4 | rebuild | absent; target decisions are conversational |
| Absorb-only-when-provably-working; paused versus blocked | 00 C4; 04 B4; 09 E6 | copy rule, rebuild integration | absent |
| Worker and supervisor liveness, wake backoff, and stale escalation | 00 C5/C7-C9; 02 M11/M13; 03 M8/M9/M14; 01 M9-M11 | rebuild | heartbeat is prose; no deterministic fleet loop |
| Turn-end guard, loop guard, and tracked wake ownership | 00 C6/R1; 03 M19/M21; 10 M0 | rebuild | hook points exist in Pi/OMP, but no fleet guard |
| Scoped process termination | 00 C10; plan R17 | rebuild | target prose permits termination without identity guard |
| Herdr explicit session, capability/version gates, and readiness | 01 M2; 02 M2-M3 | rebuild | absent |
| Herdr workspace-per-project/tab-per-task topology | 01 M3; 02 M4 | rebuild | tab labels only; no topology or registry |
| Exact endpoint IDs, ownership metadata, label display/search | 01 M3/M12; 02 M5/M7/M12; 09 V5/S2 | rebuild | absent; labels exist but are not ownership proof |
| Seeded-tab and restored-husk create-before-close safety | 01 M3; 02 M6/M11 | copy ordering, rebuild implementation | absent |
| Herdr display metadata | 01 M4; 02 M8 | rebuild | absent |
| Optional presentation projection and away workspace | 00 S7; 01 M5; 02 M14-M15; 10 M1 | strip initially | absent, correctly for initial scope |
| Low-level prompt/send, capture, composer, submit acknowledgement | 01 M8; 02 M9-M10 | rebuild after live facade tests | absent |
| Herdr event subscription, ordering, dedupe, and polling fallback | 01 M10-M11; 02 M13 | rebuild | absent |
| Guarded isolated Herdr lab | 02 M16; 04 B10 | copy | absent |
| Session lock and lock-first startup | 03 M1-M4; M9 | rebuild | absent |
| Detect-only bootstrap, wake-drain skip, and tangle wording | 03 M3/M5-M6 | copy rule, rebuild ownership | absent |
| Context digest, ABSENT semantics, fleet snapshot, and fallback | 03 M11-M13; 10 M2/M13 | rebuild | partial startup context and GitHub tracking prose |
| Startup transport, generated instructions, nudge, and reread suppression | 03 M15-M21; 09 C4/U3; 10 M0 | rebuild pending C7 | three hand-maintained surfaces; no generator |
| Brief generation and status contract | 04 B1-B2; B6; 10 M15 | copy contract, rebuild generator | absent |
| Delivery-mode classification and per-mode ownership | 04 B7; 05 M1/M4; 07 L1-L2 | rebuild | absent |
| no-mistakes project init and version floor | 05 M2-M3 | copy, re-pin | absent |
| no-mistakes worker ownership, gate refusal, read-only calls, and `--yes` rule | 04 B8-B9; 05 M5-M6/M8/M15; 10 M15 | rebuild enforcement, copy semantics | absent; Pi/OMP hooks are the available chokepoint |
| no-mistakes run attribution and CI-green disambiguation | 00 R2; 05 M7/M13-M14; plan R4-R5 | copy semantics, rebuild adapter | absent |
| no-mistakes trusted config, test commands, and out-of-tree evidence | 05 M10-M12 | copy/rebuild according to target commands | absent |
| Harness detection, allowlist, profiles, quota, effort, and consultation | 04 H1-H10; 10 M10 | rebuild Herdr-only adapter | partial host/default prose only |
| Spawn ordering, locks, duplicate launch, brief and metadata publication | 04 C1-C30; 01 M1 | rebuild as a set; copy generic checks | absent |
| Recovery entry conditions, same-worktree relaunch, endpoint ownership, and escalation ladder | 04 R1-R6; 10 M15; plan R15 | rebuild enforcement, copy judgment | heartbeat/termination prose only |
| Treehouse command boundary, lease, return, and pool hygiene | 06 M17b-M22; 01 M7 | copy external CLI contract, rebuild target assertions | `/ce-worktree` prose only |
| Tangle detection, stale-lock proof, retry, and revalidation | 03 M6; 06 M3/M23-M26 | copy deterministic predicates, rebuild scope | absent |
| Landed-work proof and cleanup | 00 R4; 06 M1-M2/M9-M16/M27; 07 L7 | rebuild for task-kind split; copy ship proof | absent |
| Local-only landing and merge route | 07 L6; 06 M10-M11 | rebuild | direct git mutation is blocked, no sanctioned route |
| PR identity, review diff, merge wrapper, readiness, and forge boundary | 07 L4-L9; 09 U2 | rebuild | partial GitHub prose and tool guards |
| Approval, yolo, green checks, and exact-head binding | 07 L3/L5; 05 M14-M15 | rebuild | absent; wrappers do not read approval/yolo/check state |
| Backlog/projection, issues/projects sync, and deterministic reporting | 07 B1-B6; 03 M12-M13; 10 M2/M13 | rebuild | GitHub Projects prose only |
| Skill discovery, owner tests, and mechanics-versus-prose placement | 09 E1-E2/S4; 10 M0/M7 | rebuild enforcement, copy semantic discipline | partial DOX and direct-mutation hooks |
| Durable knowledge versus local volatile runtime boundary | 00 S5; 09 S1-S3; 10 M4/M14; plan R20 | copy principle, rebuild storage | partial docs/disposable path; no per-task volatile tier |
| Vocabulary, marked relay, generated persona source, and labels | 00 S6; 04 H/B vocabulary; 09 V2-V6; plan R18-R19 | rebuild | partial Themis labels and multiple hand-maintained copies |
| Safe update and live-agent reread | 09 U1-U3; 10 M16 | rebuild single-home flow; copy fast-forward guard | absent |
| Dropped surfaces: tmux/zellij/orca/cmux, X, secondmates, Tasks Axi, Orca/Codex Desktop skills | 00 S1-S5; 02 M1/M14-M15; 04 B11/B14/H3; 07 B2/B5; 09 S5/C1/U1/U4; 10 M1/M6/M8-M9/M12 | strip | absent, correctly |

The ledger deliberately retains “copy the rule, rebuild the mechanism” cases.
That distinction is essential for C2, C5, C6, C7, and the no-mistakes ownership boundary.

## 3. Plan gaps

### Findings with no corresponding plan requirement

These are report findings that the requirements plan does not state as a requirement or flow acceptance criterion.

| Gap | Evidence | Why it matters |
|---|---|---|
| Herdr CLI safety details: explicit `--session` on every call, bare pane-id shape, capability/schema gates, event subscribe-before-reconcile, and absolute deadlines | `01-herdr-adapter.md:202-224`; `02-herdr-verification.md:263-299` | These are destructive-routing and lost-wake invariants, but plan R8 only says native waiting and does not name them. |
| Created-versus-adopted workspace authority and create-before-close ordering | `01-herdr-adapter.md:202-207`; `02-herdr-verification.md:50-75` | Without these, a restored husk or seeded default tab can delete the last real workspace. |
| Herdr `screen_detection_skipped` policy and harness matrix | `01-herdr-adapter.md:103-120`; `02-herdr-verification.md:146-179`; plan R4a | R4a exists, but the plan does not require the harness evidence and test matrix needed to keep it current. |
| Composer safety, `agent prompt --wait` busy semantics, and literal-send fallback | `01-herdr-adapter.md:93-120`; `02-herdr-verification.md:89-102` | Plan R8 rejects screen polling but does not specify the safe prompt/submit contract or busy-agent behavior. |
| Bounded recovery ladder, same-worktree relaunch, exact endpoint ownership, and duplicate-launch refusal | `04-dispatch-briefs-recovery.md:183-205,302-333`; `10-skills-inventory.md:109-110` | Plan R15 says landed proof but does not describe what happens before relaunch or how ownership is proven. |
| Brief immutability and status append shape | `04-dispatch-briefs-recovery.md:22-92`; `VALIDATION.md:18-78` | R2 requires events but not the generated brief contract that makes them appear, nor the keyed decision correction. |
| Harness dispatch profiles, quota/effort policy, consultation backstop, and raw-launch restrictions | `04-dispatch-briefs-recovery.md:92-137,209-247` | Plan actors and F1 say launch an agent but do not specify deterministic selection or refusal conditions. |
| Treehouse lease acquisition/release, pool-reuse hygiene, stale-lock proof, and post-cleanup revalidation | `06-treehouse-isolation.md:120-193,280-314` | R13 says isolated worktrees but not the external CLI's lease and return safety contract. |
| Tangle detection and default-branch resolution ownership | `06-treehouse-isolation.md:96-119,280-307`; `07-lifecycle-and-backlog.md:214-226` | These affect whether a dispatch or landing action targets the primary checkout and whether review/teardown agree on the base branch. |
| Exact-head approval binding, merge record-before-merge, and green-state enforcement | `07-lifecycle-and-backlog.md:55-116,214-226` | R16 says approval/check state but does not require provider/repo/number/head-SHA binding or state queries at the wrapper. |
| Durable decision identity, dependency edges, completion attestation, and committed decision text | `07-lifecycle-and-backlog.md:140-160,214-226`; `10-skills-inventory.md:98` | R20 establishes durability but no requirement names decision lifecycle mechanics. |
| Single source and generated Claude/Pi/OMP surfaces, plus drift tests | `09-escalation-state-config.md:283-307`; `10-skills-inventory.md:94-101` | R18 says one source but does not require the generator or a test that blocks drift. |
| Scoped kill identity and no broad pattern kill | `00-supervision-and-wake.md:114-139`; plan R17 only states the outcome | This is a direct work-preservation guard for the persona's termination promise. |
| Skill triggers are not execution evidence; machine-observable rules belong at hooks | `10-skills-inventory.md:8-14,55-69,127-132` | The plan says port enforcement, but does not enumerate trigger dispatch, owner tests, or hook coverage as acceptance criteria. |
| Safe update and reread of changed instructions | `09-escalation-state-config.md:296-307`; `10-skills-inventory.md:108-110` | A single generated source is insufficient when workers are already running. |

### Plan requirements with no report support

These are requirements in the plan for which the campaign provides no direct donor evidence or implementation citation.

| Requirement | Plan citation | Support status |
|---|---|---|
| R4b: completion judged from the product artifact in both “done after no output” and “failed after full output” directions | `plan:71-74` | The reports discuss artifact gates and landed proof, but do not provide the two observed cases or an implementation contract for this exact bidirectional rule. |
| R4a's measured 0.7.5 `screen_detection_skipped` matrix for Claude, Pi, and OMP | `plan:75-77` | Report 02 says the matrix is incomplete and does not test all target harnesses or a full no-mistakes run (`02-herdr-verification.md:301-328`). Treat the plan text as a dated requirement/evidence claim, not donor support. |
| R9's exact repeated-staleness bound and `demand-deep-inspection` wake payload | `plan:82-83` | Report 00 supports an equivalent escalation ladder, but no report ties the target requirement to a new Herdr implementation or acceptance test. |
| R10-R12's exact turn-end continuation behavior: no end without a live wake, honest status, and at most one forced continuation | `plan:85-87` | Report 00 describes the donor guard and loop guard; it does not prove the target harnesses expose the required hooks or background-task lifecycle. |
| R16: merge wrapper reads approval and check state and refuses without them | `plan:92-93` | Report 07 explicitly says the donor wrappers do not do this (`07-lifecycle-and-backlog.md:3,186-193`). This is a new target requirement, not a ported donor mechanism. |
| R18 generated persona source | `plan:96` | Report 00 finds three hand-maintained copies and recommends a generator, but no donor implementation supports generation. |
| R20 committed durable plans, reports, decisions, and handoffs | `plan:97` | Reports identify the donor's gitignored home and recommend a rebuild, but do not specify the target committed schema or atomic write protocol. |
| Herdr-only rejection of every other session backend | `plan:44-49,161-170` | Reports recommend stripping the adapters, but do not provide target-level rejection tests or a complete backend-selection implementation. |
| The CLI-versus-in-repo-scripts boundary | `plan:188-190` | Outstanding question only; no report resolves it. |
| GitHub Issues versus local projection | `plan:189-190`; `07-lifecycle-and-backlog.md:205-212` | Report 07 identifies the decision but explicitly cannot determine Ed's field model or whether Tasks Axi remains. |
| Join-record shape and location | `plan:191-192`; `09-escalation-state-config.md:296-299` | Reports require the capability but leave the schema open. |
| Target resolution of Herdr-only orchestration versus Pi/OMP native-subagent defaults | `plan:196-202`; `10-skills-inventory.md:130-138` | Report 10 identifies the contradiction and says it must be decided first; no evidence resolves it. |

## 4. Prose-only rules and the real checks they need

The dominant campaign finding is that the donor repeatedly documents safety without enforcing it.
The target already has a useful Pi/OMP `tool_call` chokepoint, but that only helps if each rule is translated into a machine-observable predicate.

| Rule currently living in prose | Evidence | Real check |
|---|---|---|
| Lock-refused sessions must not spawn, steer, merge, drain, or repair | `03-session-start.md:41-48`; `VALIDATION.md:80-130` | Every mutating command reads the session lease or receives a signed/unique session capability; refusal is non-zero. Add tests that invoke each mutator with a foreign lock. |
| Only the worker owns no-mistakes `axi run` and `axi respond` | `05-no-mistakes.md:41-59,187-224`; `10-skills-inventory.md:67-69` | A tool hook rejects those commands outside a worker-bound run context and rejects `--yes`; the worker context is bound to task ID and run ID, not a free-form environment variable. |
| A no-mistakes gate agent must not run fleet lifecycle operations | `05-no-mistakes.md:79-97`; `04-dispatch-briefs-recovery.md:138-183` | Detect the gate marker at the first lifecycle entrypoint and fail closed before metadata, Herdr, or Treehouse mutation. Test the bypass only inside the isolated self-test path. |
| Recovery must preserve the same task identity and worktree | `04-dispatch-briefs-recovery.md:183-205,302-333`; `10-skills-inventory.md:109` | A relaunch requires an existing immutable brief, an exact task-to-worktree record, no live owner, and a monotonic attempt counter; a fresh generic spawn is rejected. |
| Termination waits for landed work | `00-supervision-and-wake.md:248-259`; `06-treehouse-isolation.md:16-76`; `VALIDATION.md:197-273` | Teardown runs a task-kind-specific product gate. Ship checks dirty state, remote/PR identity, head ancestry, and landing; scout checks report plus decision gate; every new exempt kind must name its artifact. |
| Merges require Ed's approval, yolo limits, and green checks | `07-lifecycle-and-backlog.md:3,55-116`; `plan:91-93` | Merge wrapper reads an approval record bound to provider/repo/number/head SHA, reads current checks, classifies risk, and refuses red/unknown/destructive operations. |
| Labels identify a task or workspace | `01-herdr-adapter.md:202-207`; `02-herdr-verification.md:62-75`; `04-dispatch-briefs-recovery.md:302-333` | Labels are display/search hints only. Ownership lookup must use exact volatile IDs and a task join record; duplicate or ambiguous IDs fail closed. |
| Workers append machine-readable state and keyed decisions | `00-supervision-and-wake.md:56-113`; `04-dispatch-briefs-recovery.md:22-92`; `VALIDATION.md:18-78` | Generate the brief, validate one-line event syntax at append time, fold the complete log by key, and test multiple open decisions across terminal events. |
| A stale wake is absorbed only with positive working evidence | `00-supervision-and-wake.md:87-113`; `02-herdr-verification.md:102-107` | Current-state reader requires a live Herdr agent status or attributed run; `unknown` surfaces. Add harness-specific tests for `screen_detection_skipped`. |
| The supervisor is alive and a wake is attached | `00-supervision-and-wake.md:114-139`; plan R10-R12 | The arm command must verify the tracked background task and fresh beacon/heartbeat, persist one owner, and make the turn-end hook refuse only once per turn. |
| Startup must be lock-first and read-once | `03-session-start.md:25-89`; `09-escalation-state-config.md:283-307` | A startup integration test records mutation order, emits explicit ABSENT markers, and fails if a mutating sweep runs before the lock or if a digest item is missing. |
| Dispatch must consult harness policy and refuse unknown adapters | `04-dispatch-briefs-recovery.md:92-137`; `10-skills-inventory.md:104` | Resolve profiles in deterministic code, validate an explicit allowlist, and reject unresolved consultation or unsupported launch templates before spawn. |
| Skills load on exact triggers and own their contracts | `10-skills-inventory.md:8-14,55-59,127-132` | Generate a trigger manifest, test every trigger-to-owner mapping, and put observable actions behind hooks/scripts. Phrase-presence tests alone do not count. |
| Durable knowledge must be committed while runtime state stays local | `09-escalation-state-config.md:296-307`; `10-skills-inventory.md:98,108`; `plan:46-49,97` | Path allowlists reject durable writes to ignored state, validate committed artifact locations, and make state cleanup unable to delete repository knowledge. |
| Persona copies stay in sync | `00-supervision-and-wake.md:10-33`; `09-escalation-state-config.md:283-284`; plan R18 | Generate Claude/Pi/OMP surfaces from one source and test byte/hash or schema parity in CI. |
| Updates do not overwrite divergent work and live workers reread exact new bytes | `09-escalation-state-config.md:296-307`; `10-skills-inventory.md:108-110` | Use fast-forward-only plus dirty/diverged refusal, hash the written bytes, and send a Herdr prompt containing the exact path/hash to a live worker. |
| Herdr destructive calls are named and isolated | `02-herdr-verification.md:179-220`; `04-dispatch-briefs-recovery.md:92-137` | Require explicit session/workspace IDs, reject ambient/default destructive calls, and run destructive lab tests only in an isolated named session. |

## 5. What remains unknown

Rank reflects port dependency, not how interesting the question is.
“Unknown” means the report explicitly could not determine it or validation did not test it.

### P0 - answers needed before trusting the first implementation

| Unknown | Source | Why the port depends on it |
|---|---|---|
| Whether no-mistakes v1.40.3 still emits the CI log markers used to distinguish green checks from a still-running CI step | `05-no-mistakes.md:244-252` | A false `ci,running` result changes current-state precedence and can either delay landing or misclassify work. |
| Whether `agent prompt --wait` is safe for a busy agent, pending composer input, trust/menu prompts, completion popups, and every target harness | `01-herdr-adapter.md:225-234`; `02-herdr-verification.md:301-328` | This decides whether the large literal-send/composer state machine can be removed or must be rebuilt. |
| Whether Herdr event payloads match the current event-wait consumer, and whether connect/send time is inside the deadline | `01-herdr-adapter.md:225-234`; `02-herdr-verification.md:301-328` | A mismatch loses wakes; an incomplete deadline makes supervision appear bounded while hanging. |
| Whether Herdr 0.7.5 behavior for duplicate labels, seeded tabs, last-pane cascade, restored shells, pane error JSON, and named-server startup is stable | `01-herdr-adapter.md:225-234`; `02-herdr-verification.md:301-328` | Workspace pruning, husk replacement, error classification, and recovery all depend on these provider semantics. |
| The final join-record schema and authoritative location | `plan:188-192`; `09-escalation-state-config.md:296-299` | R1, recovery, teardown, labels, and reporting cannot be implemented safely without one identity binding. |
| Whether the target uses GitHub Issues as authority, a local projection, or both, and the exact Projects fields | `plan:188-192`; `07-lifecycle-and-backlog.md:228-236` | This determines durable state, dependency edges, status reporting, and restart recovery. |
| Whether orchestration is a stable CLI or in-repo scripts | `plan:188-190` | It controls whether Claude, Pi, and OMP can share one implementation and how hooks call it. |
| Whether Pi/OMP native subagents or the Herdr endpoint model is authoritative | `07-lifecycle-and-backlog.md:228-236`; `10-skills-inventory.md:127-138` | Harness, status, recovery, and cleanup contracts cannot all be correct until ownership of the endpoint model is explicit. |

### P1 - answers needed before hardening safety boundaries

| Unknown | Source | Why it matters |
|---|---|---|
| Whether all target harnesses report `working` during long foreground tools, and whether `screen_detection_skipped` is a stable provider contract | `01-herdr-adapter.md:225-234`; `02-herdr-verification.md:301-328`; plan R4a | Determines whether Herdr native status can outrank the run-step and when it must fall through to `unknown`. |
| Whether a registered Herdr status proves the underlying harness process is alive | `01-herdr-adapter.md:225-234` | A false live result can block safe recovery or cause stale work to be treated as owned. |
| Whether the supervisor needs a separate non-visible Herdr terminal if away mode returns | `02-herdr-verification.md:130-136`; `10-skills-inventory.md:95,134-138` | Affects the first-version boundary and whether deferred supervision can be made restart-proof. |
| Whether the shared no-mistakes daemon is truly multi-home and what `disable_project_settings` and `allow_repo_commands` do in combination | `05-no-mistakes.md:244-252` | A wrong assumption can let a worker restart a shared service or let branch-controlled config choose an unsafe gate agent. |
| What objective risk classifier supports yolo, and whether yolo is wanted at all | `07-lifecycle-and-backlog.md:228-236` | R16 cannot be enforced with a boolean approval unless risk and exact head are typed. |
| Whether GitLab merge support is required and whether `gh-axi pr merge` enforces current checks | `07-lifecycle-and-backlog.md:228-236` | Watch parity is not merge parity; the forge boundary must be explicit. |
| Whether Treehouse v2.1 changes the v2.0.0 command semantics, pool resolution, lease behavior, or return safety | `06-treehouse-isolation.md:307-314` | The kept external dependency is a landing and isolation boundary. |
| Whether the `atlas-pat` identity regime can occur in the port | `06-treehouse-isolation.md:307-314` | Determines whether the report's strip of broker-specific identity checks is safe. |
| Whether the orchestrator can own persistent delegated children in the future | `06-treehouse-isolation.md:307-314`; `07-lifecycle-and-backlog.md:228-236` | Stripping child-home and in-flight-child protections is safe only if the product boundary is real. |

### P2 - answers needed for complete portability and operations

| Unknown | Source | Why it matters |
|---|---|---|
| Whether the harness ancestry depth and the three lock/primary-scope ancestry implementations agree under Herdr | `03-session-start.md:193-200` | A mismatch can make a valid session permanently read-only or trigger a worker nudge in the wrong worktree. |
| What the Pi and OpenCode nudge bodies actually do, and whether the OMP transport can inject startup instructions | `03-session-start.md:193-200` | Needed if C7 chooses the nudge path. |
| Whether fleet-sync and X-mode-like retained sweeps have internal guards | `03-session-start.md:193-200` | Mostly out of initial scope, but important if any clone/update sweep returns. |
| Whether the Treehouse pool status divergence is caused by the renamed repo, missing config, or normal behavior | `06-treehouse-isolation.md:301-307` | Prevents treating the external CLI as authoritative for pool inventory when it is not. |
| Whether scout `--force` is intentionally allowed to skip the decision-hold gate | `06-treehouse-isolation.md:311-312` | Determines whether explicit discard authority can erase unresolved durable decisions. |
| Whether the section-9 and skill tests run in CI and whether the two persona runtime copies truly agree | `09-escalation-state-config.md:330-342` | Phrase-presence and copy drift can create false confidence in the port. |
| Whether visible Codex Desktop companionship and AFK mode return to scope | `10-skills-inventory.md:134-142` | Determines whether stripped skills are deferred or permanently excluded. |
| Whether host harnesses auto-select skills from metadata | `10-skills-inventory.md:134-142` | Controls how much trigger safety must be implemented in code. |
| Whether the missing prior quality-bar report and assignment-8 report are intentional omissions | `01-herdr-adapter.md:225-234`; `02-herdr-verification.md:327`; `05-no-mistakes.md:244-252` | Missing evidence should not silently become a port assumption. |

## 6. Port-order implications

The safe dependency order is:

1. Decide the join-record schema, task projection authority, CLI boundary, and Herdr-versus-native-subagent authority.
2. Build the Herdr wrapper and isolated lab with explicit-session, capability, ID, deadline, and unknown-refusal tests.
3. Build brief generation, event append/fold, run attribution, and task-kind-specific product gates.
4. Add Treehouse allocation/lease/return plus both allocation and foreground-cwd isolation assertions.
5. Add merge and recovery wrappers with exact-head approval, no-mistakes ownership, and landed-work enforcement.
6. Generate persona surfaces and add behavioral drift/trigger tests.

Until those gates exist, a report recommendation is not a completion claim.
