# 0. Headline

- The merge wrappers do **not** enforce the authority they claim to guard: neither reads `yolo`, an approval record, task readiness, or CI state, so the prohibition on unattended/red merges is prose-only (`bin/fm-pr-merge.sh:21-34,163-206`; `bin/fm-merge-local.sh:19-26`).
- `direct-PR` becomes merge-eligible in the lifecycle when the PR is merely opened, while `yolo` prose says autonomous merges must be green; no code connects those statements (`AGENTS.md:266-270,289-294`; `bin/fm-pr-merge.sh:163-206`).
- GitHub Issues cannot replace the donor backlog without rebuilding current-state consumers: session recovery, deterministic reporting, dependency/date readiness, decision holds, completion artifacts, and cross-home routing all read the local Tasks Axi model (`AGENTS.md:411-423`; `bin/fm-fleet-snapshot.sh:1-50`).
- The PR *watch* path supports canonical GitHub and self-hosted GitLab identities, but PR merge, recorded-head lookup, review-diff refresh, Atlas identity, and the teardown PR proof remain GitHub-specific (`bin/fm-pr-lib.sh:78-179`; `bin/fm-pr-merge.sh:21-34`; `bin/fm-review-diff.sh:86-118`).
- Treehouse contributes no landing safety because teardown always returns with `--force`; the port must retain the mode-specific landed-work predicate before either sanctioned merge route is allowed to end in cleanup (`bin/fm-teardown.sh:723-787`, relying on donor report 06 rather than re-reading that implementation).

## 1. Mechanism inventory

### L1 — Deterministic project delivery-mode and autonomy parser

`fm-project-mode.sh` is the sole parser of a registry entry into `no-mistakes|direct-PR|local-only` plus `yolo=on|off`; unknown projects and unknown modes warn and fall back to `no-mistakes off`, so lookup failure adds validation rather than silently removing it (`bin/fm-project-mode.sh:1-58,100-119,128-175`). It depends on the canonical project key in `data/projects.md`, and dispatch/brief generation depends on its output. The same parser also carries Fleet display and Atlas identity tokens, which are unrelated to delivery selection in the target.

### L2 — Three mode-specific ownership contracts

The generated ship instructions assign implementation to the worker in all modes but assign validation/publication differently (`bin/fm-brief.sh:302-366`; `AGENTS.md:253-287`):

| Dimension | `no-mistakes` | `direct-PR` | `local-only` |
| --- | --- | --- | --- |
| Who validates? | The no-mistakes pipeline owns review, fixes, tests, docs, push, PR, and CI. The same worker drives `axi run/respond`; the pipeline applies fixes. | No no-mistakes run and, absent a separately authorized review, no independent validation path. | No pipeline, remote checks, or independent validation path. |
| Who pushes/opens? | no-mistakes pushes and opens the PR. | The worker pushes `fm/<id>` and opens the PR. | Nobody; remote push and PR creation are forbidden. |
| Ready signal | `done: PR <url> checks green` after CI first becomes green. | `done: PR <url>` immediately after opening the PR. | `done: ready in branch fm/<id>` after a clean committed branch is ready. |
| What waits for approval? | The green PR waits for configured merge authority. | The newly opened PR waits for configured merge authority. | The ready branch waits for configured merge authority, then the orchestrator fast-forwards local default. |
| Merge route | `fm-pr-merge.sh` | `fm-pr-merge.sh` | `fm-merge-local.sh` |

I am relying on report 05 for the independently checked no-mistakes ownership and CLI behavior; I did not re-run or inspect the no-mistakes binary in this scout. I independently read the mode branches in `fm-brief.sh` and the lifecycle prose.

The stated reason for separate modes is how a finished change reaches the default branch (`bin/fm-project-mode.sh:47-53`). No implementation rationale is stated for making direct-PR ready before CI.

### L3 — `yolo` authority boundary

The intended boundary is narrow and orthogonal to delivery mode: with `yolo=off`, Ed owns ask-user findings, PR merges, and local-only merge approval; with `yolo=on`, the orchestrator may decide those routine gates, but must still escalate destructive, irreversible, and security-sensitive actions and must never merge a red PR (`AGENTS.md:266-270`; `bin/fm-project-mode.sh:51-54`).

Implementation stops at parsing and persisting the flag. `fm-brief.sh` deliberately discards it because it governs orchestrator behavior (`bin/fm-brief.sh:302-306`), while neither merge wrapper reads it or any approval evidence. The boundary therefore depends entirely on agent compliance. No source states why this was left unenforced.

### L4 — PR-ready recording and static merge watch

`fm-pr-check.sh` canonicalizes a GitHub PR or GitLab MR identity, writes exactly one `pr=` and optional `pr_head=` into task metadata, and atomically publishes a byte-static poll plus private provider-tagged sidecar and registration (`bin/fm-pr-check.sh:1-8,20-39,57-163`; `bin/fm-pr-lib.sh:493-538,657-789`). It exists so merge monitoring can use immutable program bytes while task/forge data remains private data, and so teardown has a PR reference/head after squash merges.

Guard sequence:

1. Validate a path-safe task id and strict canonical forge URL before deriving task paths (`bin/fm-pr-check.sh:20-39`; `bin/fm-pr-lib.sh:61-78,78-179`).
2. Require metadata to be a regular, non-symlink, single-link file (`bin/fm-pr-check.sh:35-40`).
3. Refuse a GitLab watch when `glab` is unavailable, because the otherwise-silent poll would watch nothing forever (`bin/fm-pr-check.sh:42-49`).
4. Run the non-executing legacy-poll migration before writing; the ordinary fleet guard is advisory (`bin/fm-pr-check.sh:51-55`). I read only this call/header, not the migration implementation.
5. Validate Atlas binding/profile/metadata agreement; Atlas identity is GitHub-only, verifies the PR and requires a valid head (`bin/fm-pr-check.sh:65-106`; `bin/fm-pr-lib.sh:414-427`).
6. For ordinary GitHub only, attempt to record `headRefOid`; lookup failure is non-fatal and GitLab records no head (`bin/fm-pr-check.sh:108-115`).
7. Prepare metadata and poll artifacts on the state directory's device with mode `0600`, regular-file/symlink/hardlink checks, exact reconstructed identity, hashes, inode identities, and byte equality with the static poll template (`bin/fm-pr-lib.sh:429-490,493-627,657-727`).
8. Rewrite metadata atomically, re-parse it, and require the parsed provider/URL/host/path/number to match the requested identity (`bin/fm-pr-check.sh:117-153`).
9. Publish data, registration, then runnable check; on any mismatch revoke the final artifacts, and verify the complete registered set after publication (`bin/fm-pr-lib.sh:629-655,729-825`).

These checks prevent path injection, URL/provider ambiguity, symlink/hardlink/cross-device replacement, check-program interpolation, partial publication, identity downgrade, and an unobservable missing GitLab client. They do **not** prove CI green or merge authorization.

### L5 — Sanctioned PR merge route and its actual guards

`fm-pr-merge.sh` is the only sanctioned task-PR merge route and records PR identity through L4 *before* attempting the merge, so even a no-CI or failed merge attempt leaves the landing evidence needed later (`bin/fm-pr-merge.sh:1-10,163-179`; `tests/fm-pr-merge.test.sh:1-10,99-144`). AGENTS forbids calling lower-level merge commands around it (`AGENTS.md:266-270`).

Every wrapper guard, in execution order:

1. Require task id + URL and accept GitHub only; strict URL parsing pins owner, repository, and number (`bin/fm-pr-merge.sh:21-34`). This prevents malformed or GitLab input reaching a GitHub merge call.
2. Reject caller `--repo`/`-R` overrides before recording or merging (`bin/fm-pr-merge.sh:149-160`). This prevents the validated URL and actual merge target from diverging.
3. Require task metadata to exist and not be a symlink (`bin/fm-pr-merge.sh:162-168`). Unlike `fm-pr-check.sh`, this preliminary check does not itself require one hard link, but the called check does.
4. Call `fm-pr-check.sh`, then require metadata to contain the exact canonical `pr=<URL>` (`bin/fm-pr-merge.sh:170-175`). This prevents merging without first committing the teardown/watch identity.
5. Default to squash only when no merge method was supplied (`bin/fm-pr-merge.sh:40-49,177-180`). This prevents accidental multiple defaults, not an unsafe caller-selected method.
6. Revalidate any Atlas binding; metadata that claims an identity without its binding is refused (`bin/fm-pr-merge.sh:181-193`).
7. Atlas path: `merge-assert` requires Ed's authenticated GitHub login, an open PR, and a verified head; the preceding `fm-pr-check` verification also binds repo, task branch, base, head, author, committer, and commit set (`bin/fm-pr-merge.sh:194-203`; `bin/fm-pr-identity.sh:304-387,492-569,632-679,739-750`). The REST merge sends that head SHA, preventing a head-change race.
8. Atlas argument parser allows only merge method, body/subject, delete-branch, and regular non-symlink body files; it rejects conflicting methods, unsupported methods/arguments, and `--auto` (`bin/fm-pr-merge.sh:51-147`).
9. Ordinary path invokes `gh-axi pr merge` with separately derived number/repository and propagates its failure under `set -e` (`bin/fm-pr-merge.sh:205-206`). Any additional non-repository argument is otherwise forwarded, so forge policy is delegated to `gh-axi`/GitHub.

Missing guards are as consequential as present ones: the script does not check task `mode`, `kind`, `yolo`, explicit approval, current worker state, CI/check conclusion, review outcome, or red/green status. The Atlas assertion verifies identity and open state, not CI. The lower-level-command prohibition is also prose-only: neither command-policy script recognizes `fm-pr-merge`, `gh-axi pr merge`, or an approval token (`bin/fm-arm-command-policy.mjs`; `bin/fm-cd-command-policy.mjs`, negative searches).

### L6 — Sanctioned local-only merge route and its actual guards

`fm-merge-local.sh` applies approved authority by fast-forwarding the primary project's default branch to `fm/<id>` (`bin/fm-merge-local.sh:1-12`). Its guards are:

1. Run the ordinary fleet guard, but ignore its failure (`bin/fm-merge-local.sh:19`). This is an advisory surface, not merge authorization.
2. Require a metadata file (`bin/fm-merge-local.sh:20-22`). The id is not path-safety validated and the file is not rejected for being a symlink.
3. Require `mode=local-only` (`bin/fm-merge-local.sh:24-26`). This prevents use as the PR-mode landing route.
4. Require exact branch `fm/<id>` to exist (`bin/fm-merge-local.sh:42-43`).
5. Resolve the default branch as `origin/HEAD`, then local `main`, then local `master` (`bin/fm-merge-local.sh:28-40,45`).
6. Require the primary project copy itself to be on that default branch and clean (`bin/fm-merge-local.sh:47-56`). This prevents writing into a displaced or dirty primary copy.
7. Require default to be an ancestor of the task branch, then invoke `git merge --ff-only` (`bin/fm-merge-local.sh:58-66`). The predicate plus Git's own final check prevents merge commits and divergence.

It does **not** check `kind=ship`, `yolo`, explicit approval, task readiness/status, worker-tree cleanliness, validation, or a landed-work predicate before mutation. Its header says it runs only after Ed approval or `yolo=on` (`:5-10`), but no code implements that claim. There is no colocated `fm-merge-local` test file.

### L7 — Mode-specific cleanup/landing proof

I am relying explicitly on completed report 06's M1-M8/M11/M27 findings rather than re-deriving `fm-teardown.sh`.

For both PR modes, cleanup first refuses a dirty worktree (except two donor hook artifacts) and examines commits not reachable from any remote-tracking ref. No such commits means landed. If commits remain, ordinary tasks require either a merged-PR containment proof or a default-branch content proof; an invalid Atlas binding refuses without content fallback. `no-mistakes` and `direct-PR` have no different teardown predicate (`bin/fm-teardown.sh:723-787`, report 06).

For `local-only`, the normal unpushed-commit path requires a resolvable default branch, no dirty work, and no commits remaining outside the *local* default branch; it deliberately does not call the PR/content proof ladder. Report 06 also established that this is a separate path, not the additive fallback claimed by the teardown header. Because the generic remote-reachability fast path runs first, an erroneously pushed local-only branch can satisfy the generic proof without local merge; the port should make local-default containment unconditional for local-only.

All modes refuse forced cleanup without explicit discard authority at the policy layer (`AGENTS.md:297-300`). Report 06 established that `--force` skips work-preservation proofs but not path-safety guards.

### L8 — Review-diff authority

`fm-review-diff.sh` fetches a remote-backed default branch, uses the local default for local-only projects, and prefers a freshly fetched PR head over a recorded head or local branch (`bin/fm-review-diff.sh:1-14,52-150`). It prevents reviewing a stale pooled default branch or stale recorded PR SHA. It depends on task metadata and `origin`; GitHub pull refs are hard-coded, so a GitLab MR record falls back to the local branch and may lag the MR.

No rationale is stated for duplicating default-branch resolution here and in local merge/teardown rather than using one shared helper.

### L9 — Forge capability boundary

The implementation is provider-tagged, not forge-agnostic:

- URL identity and static merge polling support exactly GitHub.com PRs and GitLab MRs, including nested namespaces and self-hosted GitLab (`bin/fm-pr-lib.sh:78-179`; `bin/fm-pr-poll.sh:1-10,104-223`).
- GitHub polling uses `gh`; GitLab uses `glab`. GitLab's client is mandatory at arm time (`bin/fm-pr-check.sh:42-49`).
- `pr_head` recording is GitHub-only; GitLab omits it because the donor declines to require JSON parsing (`bin/fm-pr-check.sh:57-62,108-115`).
- Atlas host identity is GitHub-only (`bin/fm-pr-check.sh:87-106`; `bin/fm-pr-identity.sh:1-25`).
- Merge is GitHub-only and explicitly refuses GitLab (`bin/fm-pr-merge.sh:21-34`).
- Review refresh uses GitHub's `refs/pull/<n>/head` and `/pull/` URL shape (`bin/fm-review-diff.sh:86-118`).
- Report 06 found teardown PR discovery/verification split between `gh-axi` and `gh`; provider-neutral content containment is the fallback, not provider-neutral merged-MR verification.

A porter must choose either an explicit provider interface or GitHub-only scope; calling this “any forge” would be inaccurate.

### B1 — Local backlog schema, states, retention, and artifacts

`.tasks.toml` selects a markdown backlog at `data/backlog.md`, archives pruned history to `data/done-archive.md`, and keeps ten Done records (`.tasks.toml:1-6`). The contract tracks work items, not workers, in In flight / Queued / Done, with kind/repository/body, blocker edges, structured holds, date gates, priority, and completion links (`AGENTS.md:411-428`; Tasks Axi 0.2.3 read-only `--help` probes).

Tasks Axi `done` records a PR, report, or local note and pruning archives rather than deletes. `ready` returns queued work that is unblocked, unheld, and due now. These CLI behaviors were verified by `--help`; they are not claims about GitHub's inherent capabilities.

### B2 — Tasks Axi compatibility and manual fallback

`fm-tasks-axi-lib.sh` accepts Tasks Axi only when version parsing is at least 0.1.1 *and* feature probes find recoverable `update --archive-body` and atomic multi-id `mv`; current handoff actually requires the 0.2.2-era move capability (`bin/fm-tasks-axi-lib.sh:1-52`; `bin/fm-backlog-handoff.sh:302-304`). Routine backlog writes may fall back to manual markdown when configured or incompatible, but cross-home handoff always requires the CLI (`bin/fm-tasks-axi-lib.sh:54-75`).

This exists to keep a hand-editable fallback while refusing old parsers that can orphan bodies or strand dependency edges.

### B3 — Backlog as deterministic recovery and reporting input

The local backlog is not just a to-do list:

- Session start renders a bounded, body-free listing with blockers and hold metadata, with manual fallback (`bin/fm-session-start.sh:70-82,135-205`).
- The read-only structured snapshot joins backlog records to task metadata, current-state classification, branches, reports, decisions, and project summaries without GitHub/network discovery (`bin/fm-fleet-snapshot.sh:1-50`).
- Lifecycle policy updates it on dispatch, completion, and decision, then re-runs readiness after cleanup/heartbeat (`AGENTS.md:413-423`).
- Teardown emits the exact mode/kind-shaped completion command and a `tasks-axi ready` reminder (`bin/fm-teardown.sh:479-503`).

This network-free execution-control role is what a plain issue list does not currently supply.

### B4 — Durable unresolved-decision lifecycle

`fm-decision-hold.sh` converts an unresolved review/scout decision into stable `<origin>-decision-<key>` Tasks Axi work, verifies its active/durable state, blocks dependent work, and closes it only after recording a bounded decision file and routing it to existing blocked dependents (`bin/fm-decision-hold.sh:1-39,99-203,226-475`). Scout cleanup calls its read-only verification, as established by report 06 M9.

This prevents a completed report or later status event from erasing an unanswered decision. It depends on the backlog's structured hold, blocker edges, task identity, and completion body. The target has no equivalent.

### B5 — Atomic cross-home queue ownership

`fm-backlog-handoff.sh` moves only already-selected queued work to a validated second-orchestrator home. It refuses unsafe/active/done/missing items, noncanonical bodies, unsafe homes/files, and dependency-stranding moves; one multi-id `tasks-axi mv` transaction preserves complete blocks and edges byte-for-byte (`bin/fm-backlog-handoff.sh:1-45,60-189,193-330`).

Its purpose is single ownership: work routed to another home leaves the main queue rather than appearing in two queues (`AGENTS.md:413-415`). It depends on the donor's persistent secondmate-home model; the current Themis target has no such model.

### B6 — GitHub Issues/Projects versus the local backlog

The target already says plans/handoffs become GitHub Projects and issues and labels issue-linked worker tabs `GH#<issue>-<role>` (`~/.claude/commands/Themis.md:49,104-106`; `packages/pi-themis/extensions/themis.ts:76,82`; `packages/omp-themis/src/main.ts:125,132`). That is **prose only**: the Pi/OMP extensions persist only Themis activation state and contain no issue reader, dependency scheduler, decision-hold state machine, completion-artifact recorder, or local projection.

The donor has the inverse gap: none of the local backlog consumers synchronizes from GitHub Issues. GitHub is used for PRs and externally tracked project scope, while Tasks Axi is the private execution queue.

**Evidence-based decision:** do not keep two competing durable backlogs, but do not replace the local execution model with raw Issues either. Use GitHub Issues/Projects as the committed/durable work authority, and rebuild a small local, gitignored execution projection for active dispatch, readiness, decision holds, and network-free recovery. A full replacement is viable only if the porter also replaces every B3/B4 consumer with deterministic GitHub-backed equivalents and defines offline/auth-failure behavior. No such implementation exists today. “Coexist” therefore means authority + projection, not duplicated manual truth.

This conclusion follows the scout brief's decided state split: durable plans/reports/decisions are committed; volatile runtime state stays local. The donor's gitignored markdown backlog mixes those categories, so copying it unchanged would violate the target constraint.

## 2. Verified versus prose-sourced

### Verified — implementing code read or installed CLI probed read-only

- Mode/yolo parsing, canonical-key lookup, and safe fallback (`bin/fm-project-mode.sh`).
- All three mode branches and their exact ready strings (`bin/fm-brief.sh:302-366`).
- Every guard and every listed missing check in both merge wrappers; both files were read in full. Negative searches confirmed neither wrapper reads `yolo`, approval, or CI state.
- PR/MR URL parsing, metadata identity parsing, Atlas binding parsing, private-file checks, poll preparation/publication/revocation, and provider branches (`fm-pr-check.sh`, relevant `fm-pr-lib.sh`, and `fm-pr-poll.sh`).
- Atlas merge assertion checks authenticated Ed identity, open state, and verified head but no CI conclusion (`bin/fm-pr-identity.sh:739-750`).
- `fm-review-diff.sh`'s GitHub pull-ref and `origin` assumptions.
- `.tasks.toml`, Tasks Axi compatibility/manual fallback, and the full backlog-handoff implementation.
- Tasks Axi 0.2.3 command semantics listed in B1/B2 were probed only with `--version`/`--help`; no mutation command was run.
- Decision-hold creation/completion/verification/resolution implementation.
- Session-start and fleet-snapshot dependence on local backlog records.
- Target-side “already have” checks: I read the Claude persona, Pi extension/skill, and OMP extension/skill. They have issue/project prose and mutation hooks, but no delivery-mode, merge-wrapper, local queue, or decision-hold implementation.

### Relied on another report or prose, not independently re-derived

- **Report 05 reliance:** no-mistakes owns review/fixes/tests/docs/push/PR/CI; the worker owns run/respond; `--yes` bypasses ask-user escalation; CI-green and merged are distinct pipeline points. I did not inspect the no-mistakes binary.
- **Report 06 reliance:** the ordered teardown predicate, PR/content/patch-id landing proofs, local-only branch behavior, `--force` split, and unconditional `treehouse return --force`. I intentionally did not re-read those implementation blocks.
- `AGENTS.md` owns the authority policy: what `yolo` may decide, what remains Ed-only, never merge red, only sanctioned merge routes, and explicit discard authority. These are prose rules and are not enforced by the wrappers.
- `fm-pr-check-migrate.sh` behavior is described from its call-site comment/header only; I did not audit the migration implementation.
- The reason for keeping Done history at ten and for using markdown rather than another store is not stated beyond `.tasks.toml`; I have not invented one.

### Prose/implementation mismatches

- `fm-merge-local.sh:5-10` claims it runs only after approval or yolo auto-approval; its implementation reads neither.
- `AGENTS.md:266-270` says autonomous merges are green/approved and red PRs never merge; `fm-pr-merge.sh` performs no such check.
- `AGENTS.md:270` forbids lower-level merge calls, but no command hook enforces use of the wrappers. The target Pi/OMP hooks block direct `git merge` but do not block `gh-axi pr merge` or require a wrapper approval token (`packages/pi-themis/extensions/themis.ts:46-59,236-256`; `packages/omp-themis/src/main.ts:90-103,296-310`).
- Report 06 established that teardown's local-only “additional fallback” prose is inaccurate: the implementation takes a separate branch and skips the normal PR/content proof ladder.
- “Forge support” is broader in PR watching than merging/review/teardown; describing the lifecycle as forge-neutral would be wrong.

## 3. Verdict per mechanism

| Mechanism | Verdict | Why | Already have it? |
| --- | --- | --- | --- |
| L1 mode/yolo parser | **rebuild** | Deterministic selection stays, but the donor parser mixes delivery with Fleet labels and Atlas profiles in a private registry we are not copying as authority. | **absent** — report 05 and target reads found no delivery-mode concept. |
| L2 mode-specific ownership | **rebuild** | Keep the three behaviors and one-owner rigor, but rewrite worker contracts for Themis/Ed and resolve the target's mandatory serial reviewer conflict identified by report 05. | **partial** — worker/reviewer roles exist (`Themis.md:64-74`), no shipping ownership. |
| L3 yolo boundary | **rebuild** | Capability is useful, but prose-only authority is unsafe; enforce approval/risk evidence at the sanctioned merge chokepoints. | **absent** — no autonomy flag; Ed decisions are prose. |
| L4 PR-ready record + poll | **rebuild** | We need merge identity and durable notification, but donor publication targets its watcher/sidecar topology; report 00 recommends a herdr-native supervision rebuild. | **absent**. |
| L5 PR merge route | **rebuild** | Keep canonical URL, repo pinning, record-before-merge, and verified-head guards; drop/re-scope Atlas broker and add mode, approval, and green checks. | **partial** — target hooks can block commands but no wrapper exists. |
| L6 local merge route | **rebuild** | The fast-forward checks are portable, but task metadata/path validation and authority enforcement must be redesigned. | **partial** — direct `git merge` is blocked in Pi/OMP, but no approved route exists. |
| L7 landed-work cleanup proof | **copy** | Per report 06, treehouse supplies no safety; deterministic proof is mandatory. Fix the local-only remote-fast-path edge while porting. | **absent** — report 06 found termination without landing proof. |
| L8 review-diff authority | **rebuild** | Need fresh base/head comparison, but use a provider interface rather than GitHub pull refs and donor metadata. | **absent**. |
| L9 forge adapter boundary | **rebuild** | Decide GitHub-only or explicit GitHub/GitLab adapters; “any forge” is unsupported. | **partial** — target names GitHub Projects only. |
| B1 local backlog data model | **rebuild** | Keep execution states, blockers, holds, dates, and artifacts, but durable authority belongs in committed Issues/Projects and volatile projection stays local. | **partial** — GitHub tracking prose only (`Themis.md:104-106`). |
| B2 Tasks Axi backend/fallback | **strip** | Tasks Axi is not one of the decided retained external CLIs; do not inherit a dual manual/CLI parser unless Ed separately chooses it for the local projection. | **absent**. |
| B3 recovery/reporting projection | **rebuild** | Deterministic, network-free recovery remains necessary, but should consume the new local projection rather than a second durable markdown queue. | **absent** — only persona activation state persists. |
| B4 decision holds | **rebuild** | Keep stable identities, dependency routing, and cleanup gate; store durable decision text with repo work and local execution state as projection. | **absent**. |
| B5 cross-home handoff | **strip** | It exists for donor secondmate homes, which report 00 recommends dropping and the target does not have. If delegated orchestrator homes return, reassess rather than silently losing single ownership. | **absent**. |
| B6 Issues + local projection | **rebuild** | Current target has durable issue intent; donor supplies local execution semantics. One authority plus one projection satisfies both without duplicate truth. | **partial** — issue naming/prose exists, no synchronization or scheduler. |

## 4. Coupling notes

- **Approval must be bound to the exact merge identity.** A boolean “approved” is insufficient if the PR head can move. The generic wrapper records `pr_head` but does not enforce it at merge; only the Atlas path passes a verified SHA. The port should bind approval/green evidence to provider + repo + number + head SHA.
- **Record-before-merge is load-bearing.** `fm-pr-merge.sh` calls `fm-pr-check.sh` even when CI never produced the normal ready signal; report 06's teardown proof consumes that identity. Moving recording after merge recreates the no-CI squash-merge false refusal documented in `tests/fm-pr-merge.test.sh:1-6`.
- **The atomic poll publishes runnable code last.** Data and registration must commit before `<id>.check.sh`; reversing order lets the watcher execute a check with uncommitted identity (`fm-pr-lib.sh:729-789`).
- **Mode and identity must share one project key.** Report 05 and `fm-project-mode.sh:10-16` show that re-deriving a basename can silently select the safe-but-wrong no-mistakes default.
- **`direct-PR` readiness conflicts with autonomous green-only merge.** Either direct-PR must wait for green before `yolo` merge, or the merge wrapper must query and bind green state itself. Today neither happens.
- **Default-branch resolution is duplicated.** Local merge, review diff, tangle, and teardown carry parallel `origin/HEAD -> main -> master` logic. The port needs one owner or landing/review can disagree.
- **GitLab watch parity is not merge parity.** Accepting a GitLab MR in `fm-pr-check` must not imply it can be merged or reviewed freshly by the current wrappers.
- **Backlog and runtime task metadata are complementary.** The backlog tracks intended work/dependencies/decisions; `state/<id>.meta` tracks a live execution endpoint/worktree/mode. Replacing one does not replace the other (`AGENTS.md:90,413-419`; `fm-fleet-snapshot.sh:13-50`).
- **Decision holds couple completion to scheduling.** A hold is both a durable decision record and a blocker edge; closing it unblocks routed work only after the decision text is recorded (`fm-decision-hold.sh:359-475`). Flattening it to an issue comment loses the deterministic ready transition unless the issue adapter recreates that edge.
- **Cross-home moves must move connected dependency sets atomically.** If persistent delegated homes are retained later, copying individual issues/items without dependency closure strands edges (`fm-backlog-handoff.sh:29-44,318-330`).
- **Target mutation hooks are the right chokepoint.** Pi/OMP already block direct git mutation; extend that mechanism to reject raw forge merges and require the sanctioned wrapper, rather than adding another prose rule.

## 5. What I could not determine

- Whether Ed wants `yolo` retained in the new Themis at all. This report establishes the safe boundary and current enforcement gap, not the product decision.
- What objective risk classifier should distinguish “routine” from destructive/irreversible/security-sensitive. The donor provides no deterministic implementation; enforcing `yolo` safely requires either explicit typed risk metadata or retaining an Ed decision for ambiguous cases.
- Whether `gh-axi pr merge` itself refuses red or unmergeable PRs under every repository policy. The wrapper delegates to it, and I did not perform a merge or probe remote policy. The report therefore treats green enforcement as absent from firstmate, not necessarily absent from GitHub branch protection.
- Whether GitLab merge support is desired. The donor watch supports it, but the target prose is GitHub-specific and the merge/review paths do not have parity.
- Whether Tasks Axi should remain as the implementation of the proposed local projection. It has the needed semantics, but the scout brief only decided to retain treehouse and no-mistakes as external CLIs.
- Whether persistent delegated orchestrator homes survive the port. B5 is stripped based on report 00's recommendation and the target's current absence, not an explicit decision in `SCOUT-BRIEF.md`.
- The exact GitHub Projects field model Ed intends. The target says to use `/pm-tools`, but no checked implementation defines status/hold/dependency mapping or synchronization.
