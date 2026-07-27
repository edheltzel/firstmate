# Donor map 06: treehouse and worktree isolation

Scout report against `SCOUT-BRIEF.md`. Donor is `firstmate` at `/Users/ed/Developer/Atlas/Themis`.
Every `file:line` below was read. treehouse v2.0.0 was probed read-only (`--help`, `status`, `git worktree list`); nothing was taken, returned, created, or pruned.

## The one paragraph that matters

Firstmate calls `treehouse return --force` **unconditionally** - on every teardown path, including non-force teardown (`bin/fm-teardown.sh:653`, `:678`, `:705`, reached from `:1202`). It never uses treehouse's own prompting return. So **treehouse contributes zero safety to this system.** The only thing standing between a completed agent and destroyed work is firstmate's own landed-work test in `validate_worktree_teardown_safety`. If the port keeps the treehouse dependency but drops or weakens that predicate, the result is not "slightly less safe" - it is a `git reset --hard` plus process kill on every finished task, with no guard at all.

Our persona currently sits on the wrong side of this. `~/.claude/commands/Themis.md:47` says "if the agent has completed its role, Themis will then terminate the agent and its herdr." There is no proof-of-landing precondition anywhere in our stack.

---

## 1. Mechanism inventory

### The landed-work test

**M1. Teardown safety predicate (`validate_worktree_teardown_safety`)**
`bin/fm-teardown.sh:723-787`. The gate that decides whether a worktree may be reclaimed. Returns 0 (pass), 1 (refuse), or 3 (`TEARDOWN_WORKTREE_SAFETY_LOCK_BLOCKED`, retryable after stale-lock cleanup). Depends on `work_is_landed`, `default_branch`, `worktree_safety_blocked_by_lock`. Called from `:1155`, re-called at `:1161` after lock cleanup, and passed by name as a post-cleanup callback at `:1200`. Exists because teardown hard-resets and removes the worktree and kills its processes (header `:7-8`).

**M2. Ordered predicate as executed.** This is the thing to port. Stated with no firstmate nouns:

Short-circuits, in order (`:725-729`):
- `S0` worktree directory does not exist -> pass.
- `S1` force flag set -> pass.
- `S2` task kind is `secondmate` or `scout` -> pass (they have their own gates, M9/M10).

Then:
1. `git -C <wt> status --porcelain`. Command failure -> if a git index lock is present, return 3; else **REFUSE** (`:731-738`).
2. Filter the porcelain output: drop lines matching `^\?\? (\.claude/|\.fm-grok-turnend$)`. Take the first remaining line as `dirty` (`:739`).
3. `git -C <wt> log --oneline HEAD --not --remotes`. Command failure -> lock check or **REFUSE** (`:741-748`). First 5 lines are `unpushed`.
4. **Branch A** - delivery mode is `local-only` *and* `unpushed` is non-empty (`:751-768`):
   - resolve the default branch; unresolvable -> **REFUSE**.
   - `git log --oneline HEAD --not <default>`; failure -> lock check or **REFUSE**.
   - **REFUSE** if `dirty` non-empty OR commits remain unmerged into the local default branch.
   - otherwise pass. **`work_is_landed` is never called on this path.**
5. **Branch B** - `dirty` non-empty (`:769-773`): **REFUSE**.
6. **Branch C** - `unpushed` non-empty (`:774-786`): resolve branch name (`git rev-parse --abbrev-ref HEAD`, literal `HEAD` on failure, cached in `TEARDOWN_WORKTREE_BRANCH_FOR_SAFETY`), then `work_is_landed <branch>`; false -> **REFUSE**.
7. **Branch D - the primary and most common landing proof** - neither dirty nor unpushed: pass (the function simply falls off the end). This is the header's first and headline definition of landed (`:8-10`): the work is **reachable from a remote-tracking branch**, so step 3's `git log HEAD --not --remotes` came back empty. A fork counts as a remote here. Do not let its implicit implementation hide it - the exotic proofs in M4-M8 exist only for the cases this one misses, and a port that implements them while forgetting the empty-`--not --remotes` fast path has inverted the common and rare cases.

**M3. Landing proof ladder (`work_is_landed`)**
`bin/fm-teardown.sh:457-476`. Three regimes selected by `PR_IDENTITY`:
- `atlas-pat`: broker-verified merged PR (M6) -> pass; else default-branch content proof (M5) -> pass with a `LANDED:` note; else **REFUSE**.
- non-empty and not `atlas-pat` (i.e. `invalid-binding`): **REFUSE unconditionally, content fallback explicitly disabled** (`:470-473`).
- empty (the ordinary case): merged-PR proof (M4) -> pass; else content proof (M5).

**M4. Merged-PR proof + containment (`pr_is_merged`)**
`bin/fm-teardown.sh:384-425` (ordinary path `:406-425`). Resolves a PR target, then requires **all** of:
- `gh pr view <target> --json state,headRefOid` succeeds in the worktree (`:412`);
- state is `MERGED`/`merged` (`:416-419`);
- head OID non-empty (`:420`);
- the head commit object is locally present, or fetchable via `refs/pull/<n>/head` (M7);
- local `HEAD` is an ancestor of the PR head (`:423`) **or** every unpushed commit's patch-id is contained in the PR head (M8).

Any failure returns non-zero and the caller falls to the content proof. This is the "squash-merge then delete branch" recognizer named in the header (`:12-15`).

**M5. Default-branch content proof (`content_in_default`)**
`bin/fm-teardown.sh:434-450`. Resolves the default branch name, fetches `+refs/heads/<name>:refs/remotes/origin/<name>` when an `origin` remote exists (fetch failure -> inconclusive), else uses a local `refs/heads/<name>`, else inconclusive. Then `git merge-tree --write-tree <ref> HEAD` and passes **iff the merged tree equals the default branch's tree** - i.e. HEAD introduces nothing the default branch does not already have. Comment `:427-433` states the reason: this isolates branch-only changes so unrelated commits the default branch gained past the merge-base do not count as "added", and a merge conflict is inconclusive so the caller refuses rather than guesses.

**M6. Atlas broker verification (`atlas_broker_verify` + atlas path of `pr_is_merged`)**
`bin/fm-teardown.sh:355-377`, `:386-405`. For `PR_IDENTITY=atlas-pat`, a recorded PR URL is mandatory (absent -> `REFUSED: opted-in Atlas task has no recorded PR`). Verification goes through `bin/fm-pr-identity.sh verify`, retried up to `FM_TEARDOWN_PR_READ_RETRIES` (default 3, clamped to 1..5). Requires `merged=1` and a non-empty `head_sha`, then the same ancestor-or-patch-id containment. Note it does **not** call `ensure_commit_object`, so a head SHA absent locally cannot be fetched on this path.

**M7. PR-discovery fallback (`pr_number_from_branch`, `pr_number_from_target`, `ensure_commit_object`)**
`bin/fm-teardown.sh:286-319`. When no `pr=` was recorded, the PR is discovered from the branch name: `gh-axi pr list --state all --head <branch> --limit 1`, run from the worktree, first leading number parsed out. Requires branch non-empty and not literal `HEAD`. Any failure returns "no PR found" (fail-safe, comment `:283-285`). `pr_number_from_target` accepts either a `.../pull/<n>` URL or a bare leading number. `ensure_commit_object` handles the deleted-branch case: if the head commit is not a local object, derive the PR number, require an `origin` remote, `git fetch --quiet origin refs/pull/<n>/head`, re-check. Exists so a missing `pr=` never by itself falsely refuses landed work (header `:16-21`).

**M8. Patch-id containment (`unpushed_patches_are_in_pr_head`)**
`bin/fm-teardown.sh:328-351`, helper `patch_id_for_commit` `:321-326`. Computes `git patch-id --stable` for every commit in `merge-base(HEAD, pr_head)..pr_head`, requires that set non-empty, requires the unpushed set non-empty, then requires **every** unpushed commit's patch-id to appear in the PR-head set. Any missing patch-id fails the whole check. This is what lets a rebased or re-pushed local branch still prove containment.

**M9. Scout carve-out and its two gates**
`bin/fm-teardown.sh:727-729` (skips M1 entirely) and `:1129-1142`. A scout worktree is declared scratch, but teardown still **refuses** unless both: `data/<id>/report.md` exists (`:1131-1135`), and `bin/fm-decision-hold.sh verify <id>` succeeds (`:1136-1141`). Both are skipped by `--force`. The report is the work product; the decision-hold gate verifies the captain-held unresolved-decision inventory.

**M10. Secondmate carve-out and in-flight refusal**
`bin/fm-teardown.sh:727-729`, `:1103-1127`. A secondmate home skips M1. Instead: `validate_firstmate_home_for_removal` always runs (`:1107`), and without `--force`, **any** `*.meta` file in the home's `state/` refuses teardown (`:1113-1123`). With `--force`, `validate_firstmate_home_children_removal` (`:996-1025`) pre-validates every child removal target recursively before `cleanup_firstmate_home_children` (`:1027-1093`) discards child work, kills child endpoints, and returns child worktrees.

**M11. Local-only landing path** - see M2 branch A. Called out separately because the header describes it as an addition and it is not (finding F3).

### Isolation at spawn

**M12. Spawn isolation assertion (`validate_spawn_worktree`)**
`bin/fm-spawn.sh:916-932`. Refuses to launch unless: the resolved worktree path resolves physically (`cd && pwd -P`), `git rev-parse --show-toplevel` from it resolves physically, **the two are equal** (path is a worktree *root*, not a subdirectory), and **it differs from `PROJ_ABS_REAL`** (the physically-resolved primary checkout, `bin/fm-spawn.sh:833`). Failure is `exit 1` with a message naming the resolved path, the worktree root, and the primary. Called at `:1211` (treehouse path) and `:1116` (Orca path).

What it **would** catch: a pane that never left the primary checkout; a pane sitting in a subdirectory of a worktree; a path that does not resolve; a symlinked primary (both sides are `pwd -P`).

What it would **not** catch, and a porter must know:
- It does not check that the worktree belongs to `PROJ`'s repository. A pool worktree of a *different* project passes.
- It does not check ownership or lease. Another live task's worktree passes.
- A secondmate home passes - it is a real worktree root distinct from the primary.
- It is a one-shot snapshot at spawn. Nothing re-checks afterwards, which is exactly why M15 exists as a separate always-on mechanism.

**M13. Worktree acquisition (typed `treehouse get` + two-read cwd poll)**
`bin/fm-spawn.sh:1164-1212`. Asymmetric with teardown and worth flagging: the *take* is a **text line typed into the agent pane** (`spawn_send_text_line "$WT_TARGET" 'treehouse get'`, `:1165`), not a subprocess. Firstmate then polls the pane's current path up to 60 times at 1s intervals (`:1188-1205`) and infers `WT` from it. Two consecutive reads must agree on the same non-primary physical path before it is accepted (`:1193-1196`); a mismatch becomes the new candidate rather than resetting the wait. Timeout -> `exit 1` (`:1206-1209`). The comment `:1176-1186` states the reason: on some tmux/WSL setups a brand-new pane transiently reports an unrelated stale path that would pass both the primary comparison and M12, silently recording the wrong `worktree=`. The *return*, by contrast, is a direct subprocess (`bin/fm-teardown.sh:653`).

**M14. Ship-brief isolation contract**
`bin/fm-brief.sh:377-382`. Every generated ship brief tells the worker to run `pwd -P` and `git rev-parse --show-toplevel` before anything else, states that **the path check is authoritative** and that `--git-dir`/`--git-common-dir` do not prove you are outside the primary, and to append `blocked: launched in primary checkout, not an isolated worktree` and stop if it fails. This is a second, in-agent enforcement of the same invariant. `AGENTS.md` section 8 requires both this and M12.

### The tangle discriminator

**M15. Primary-checkout tangle classifier (`fm_primary_tangle_branch`)**
`bin/fm-tangle-lib.sh:44-53`. Returns the offending branch name and 0 **iff** the given root is a git work tree, `git symbolic-ref --short HEAD` yields a **named** branch, a default branch resolves, and the current branch differs from it. Silent (return 1) for: not a git work tree, detached HEAD, or already on the default branch.

**Why "is it a linked worktree" is not the discriminator.** Firstmate can dispatch agents to work on itself, so its own operating checkout `FM_ROOT` and every disposable crewmate worktree and treehouse-leased secondmate home are all linked worktrees of one repository (header `:5-8`). Linkedness therefore cannot separate healthy from broken. Branch state can: the primary is healthy on its default branch, and linked worktrees and secondmate homes are healthy at **detached HEAD**, which is how treehouse hands them out. A named non-default branch checked out in the primary means a crewmate branched and committed in the primary instead of its own worktree, stranding it.

Verified empirically. `git worktree list` in this repo:

```
/Users/ed/Developer/Atlas/Themis                        6048b1a [main]
/Users/ed/.treehouse/Firstmate-e6ac15/1/Firstmate       99e7b7a (detached HEAD)
/Users/ed/.treehouse/Firstmate-e6ac15/3/Firstmate       6048b1a [fm/atlas-key-pr-identity-redteam-k6]
...
```

Nine linked worktrees, all detached except one on a named `fm/...` branch. That named-branch linked worktree is a *live task*, and the guard correctly ignores it - because the classifier is only ever called against `FM_ROOT` (`bin/fm-guard.sh:122`, `bin/fm-bootstrap.sh:839`), never swept across the worktree list. The scope of the call site is as load-bearing as the predicate.

**M16. Default-branch resolution (`fm_default_branch`)**
`bin/fm-tangle-lib.sh:22-36`. `origin/HEAD` first, then local `main`, then local `master`, else return 1. **Duplicated verbatim in logic** as `default_branch()` at `bin/fm-teardown.sh:155-169` (hard-coded to `$PROJ` instead of taking a directory argument). Two copies of one rule.

**M17. Tangle alarm surfaces**
`bin/fm-guard.sh:122-140` prints a banner with a repair command on the next mutable fleet action; `bin/fm-bootstrap.sh:837-841` reports the same at session start as a `TANGLE:` line. Both switch to read-only wording with no repair command when another session holds the fleet lock. The guard is a warning only - `FM_GUARD_CONTINUE_LINE` (`bin/fm-guard.sh:31`) states the guarded operation still runs, and teardown calls it as `|| true` (`bin/fm-teardown.sh:119`).

### Treehouse interface and leases

**M17b. Complete treehouse command surface.** `rg -no "treehouse [a-z-]+" bin/ | sort -u` across all of `bin/`, with every remaining token hit read and confirmed to be prose in a comment. Firstmate invokes exactly **four** command forms and no others:

| Invocation | Site | Purpose |
|---|---|---|
| `treehouse get` (typed into the agent pane) | `bin/fm-spawn.sh:1165` | take a disposable task worktree (M13) |
| `treehouse get --lease --lease-holder <id>` | `bin/fm-home-seed.sh:473` | durably lease a persistent home (M19) |
| `treehouse return --force <dir>` | `bin/fm-teardown.sh:653`, `:678`, `:705` | return either kind (M18, M20) |
| `treehouse get --help` | `bin/fm-bootstrap.sh:527` | capability probe (M17c) |

**Firstmate never calls `prune`, `destroy`, `status`, `init`, or `update`.** Verified by negative grep. This is a real gap and not an oversight to replicate blindly: nothing in firstmate ever reclaims a worktree that leaked past teardown, and nothing ever reads treehouse's own view of the pool. It is consistent with the pool/git divergence I observed on this machine (section 5). For reference when deciding what to do about that: treehouse's own `prune` considers a worktree stale only when treehouse manages it, no owner reservation or running process is using it, it has no uncommitted changes, and its HEAD is already merged into the default branch (`treehouse prune --help`), and it is a dry run unless passed `--yes`.

**M17c. Treehouse capability probe and dependency declaration**
`bin/fm-bootstrap.sh:526-527`, `:822-827`. `treehouse_supports_lease()` runs `treehouse get --help` and greps for a `--lease` flag; if the flag is absent, bootstrap reports `MISSING: treehouse` with an install command even though the binary is present (header `:46-47`). Separately, `bin/fm-backend.sh:316-319` declares treehouse a required tool for **every** session backend - `tmux treehouse`, `herdr jq treehouse`, `zellij jq treehouse`, `cmux jq treehouse` - because those backends provide sessions only and treehouse is the worktree provider for all of them (`:309-311`). Orca is the sole exception, since it owns its own worktrees. **This matters for our port specifically: herdr is the backend we keep, and `backends/herdr.sh:10` states outright that under herdr "the worktree provider stays treehouse."** So the treehouse dependency is not optional for us, and a version without `--lease` must be treated as missing.

**M18. Return path (`teardown_treehouse_return`)**
`bin/fm-teardown.sh:647-721`. Always `treehouse return --force <dir>`, run from a `cd_dir` because treehouse resolves the pool from the working directory (comment `:1195-1196`) - the project clone for a task worktree (`:1202`), `FM_ROOT` for a secondmate home (`:987`). Captures stdout+stderr together so non-lock failures stay visible. Return codes: 0 success, 1 hard failure, 2 (`TEARDOWN_TREEHOUSE_LOCK_REFUSED`) lock persisted and not provably stale.

**M19. Lease acquisition for durable homes**
`bin/fm-home-seed.sh:467-484`. Secondmate homes use `treehouse get --lease --lease-holder "$id"`, run from `FM_ROOT`, capturing the printed absolute path. Per `treehouse get --help` (v2.0.0): a leased worktree is durably marked in treehouse's persistent state, is **never handed out by a later get and never removed by prune, even with no process running inside it**, until returned. This is why a durable home needs a lease and a disposable task worktree does not. Rollback returns it (`:640-651`), warning rather than failing if `treehouse` is missing or the return fails, explicitly noting "lease may still be held".

**M20. Lease release on home removal**
`bin/fm-teardown.sh:816-819`, `:976-994`. `firstmate_home_has_treehouse_slot` asks whether the home is a registered git worktree of `FM_ROOT`; if so, teardown **must** return it through treehouse rather than `rm -rf`, and a missing `treehouse` binary is a hard error (`:983-986`). If the return fails, teardown errors with "lease may still be held" and **leaves the home and its state in place** (`:987-990`) rather than hiding a still-held lease. A non-leased home falls through to `safe_rm_rf` (`:993`). Verified against header `:51-54` - the header is accurate here.

**M21. Removal-target validation (`validate_removal_target` and friends)**
`bin/fm-teardown.sh:821-860`, `:885-931`, `:933-943`. Before any `rm -rf`, refuses targets that are empty or `/`, are the active firstmate home or the firstmate repo, or are an ancestor or descendant of either. `validate_firstmate_home_for_removal` (`:945-974`) additionally requires a `.fm-secondmate-home` marker matching the expected id, requires `data`/`state`/`config`/`projects` to resolve inside the home, and refuses when the registry shows a registered *descendant* home. `validate_child_worktree_for_removal` (`:910-931`) additionally requires the target to be a registered git worktree of the recorded project.

**M22. Pool-reuse hygiene**
`bin/fm-teardown.sh:1185-1193`. Before returning, teardown detaches HEAD and deletes the task branch (best-effort), then removes `.claude/settings.local.json`, `.opencode/plugins/fm-turn-end.js`, and `.fm-grok-turnend`. Stated reason (`:1192`): a reused pool worktree must not fire turn-end signals for a dead task. Note these are the same two paths whitelisted out of the dirty check at `:739`.

**M23. Gate-agent refusal chokepoint**
`bin/fm-teardown.sh:117` (`fm_refuse_if_gate_agent`, from `bin/fm-gate-refuse-lib.sh`). Fails closed **before any fleet mutation** so a no-mistakes validation agent can never tear down a worktree. Same helper is sourced by `fm-spawn.sh` and `fm-send.sh`.

### Lock recovery and force

**M24. Stale index-lock recovery on return**
`bin/fm-teardown.sh:588-591`, `:647-721`. Entered **only** on the exact stderr signature `Unable to create '...index.lock': File exists` (`treehouse_return_is_index_lock_error`, a `grep -Eq` on the captured output). Any other failure aborts immediately with no retry (`:659-661`, `:685-688`). On signature match: retry up to `FM_TREEHOUSE_RETURN_LOCK_RETRIES` (default 3) with `FM_TREEHOUSE_RETURN_LOCK_RETRY_WAIT_SECS` (default 1s, falling back to the older `FM_STALE_WORKTREE_LOCK_RETRY_WAIT_SECS` name) between attempts. Retries key off the **error text**, not whether the lock file still exists. If retries exhaust and the lock remains, it is removed and the return retried **only** when `fm_lock_is_provably_stale` says so; otherwise return code 2 and the lock is left alone. Reason stated in header `:60-65`: the lock is usually transient and must never be force-deleted while a live git process might own it - "the fix is patience, not rm."

**M25. Stale-lock proof (`fm_lock_is_provably_stale`)**
`bin/fm-lock-lib.sh`. A lock is provably stale iff: the file still exists, **no live process holds it** (`fm_lock_has_live_holder` checks both the lock file and a companion directory - the worktree - via `lsof`), and its mtime age is at least the caller's threshold (`FM_STALE_WORKTREE_LOCK_AGE_SECS`, default 30s). Verified fail-safe: `fm_lock_has_live_holder` returns 0 ("has a holder") when `lsof` is **missing** (`command -v lsof >/dev/null 2>&1 || return 0`) and on any non-1 `lsof` status; an unreadable mtime returns not-stale. Every uncertainty resolves to "leave it alone". The header's claim on this is accurate.

**M26. Safety-check lock blocking and re-validation**
`bin/fm-teardown.sh:614-643`, `:1154-1166`, `:699-704`. Two separate places re-run the safety checks rather than trusting an earlier pass:
- If safety inspection itself cannot run because of a lock, M1 returns 3; teardown runs `cleanup_stale_lock_for_safety_check` (one wait, then the same staleness proof, then removal only if provable) and **re-runs M1 from scratch** (`:1161`).
- `teardown_treehouse_return` takes a post-cleanup callback (`:648`, invoked `:699-704`); teardown passes `validate_worktree_teardown_safety` by name (`:1200`) whenever the task is not forced and not scout/secondmate. So after a stale lock is removed, the landed-work test runs **again** before the destructive return. This closes the window where removing a lock could reveal state the first check could not see.

**M27. What `--force` actually skips**
Enumerated exhaustively, by call site:

| Skipped by `--force` | Site |
|---|---|
| The entire landed-work test (dirty, unpushed, local-only unmerged, `work_is_landed`) | `:726`, and the outer guard `:1154` |
| The post-stale-lock-cleanup re-validation (callback left empty) | `:1199-1201` |
| Scout report existence check | `:1129` |
| Scout unresolved-decision completion gate | `:1129` |
| Orca inspectable-worktree and worktree-path-match checks | `:1144` |
| Secondmate in-flight-child refusal | `:1113` |

**Not** skipped by `--force`, and this is the boundary that makes it a survivable escape hatch rather than a wildcard:

| Still enforced under `--force` | Site |
|---|---|
| Gate-agent refusal | `:117` |
| PR-check artifact validation (single-link, same-device, mode) | `:1103`, `:210-263` |
| `validate_firstmate_home_for_removal` for secondmates - marker, id match, operational dirs, registered-descendant conflict | `:1107` |
| `validate_firstmate_home_children_removal` recursive pre-validation of every child target | `:1109` |
| All `validate_removal_target` path guards (never the active home, never the firstmate repo, never an ancestor/descendant) | `:821-860` |
| `validate_child_worktree_for_removal` - target must be a registered worktree of the recorded project | `:910-931` |
| Lease release via treehouse for a leased home, including the hard error if `treehouse` is missing | `:982-990` |

So `--force` discards *work*. It never relaxes *path safety*. Port that split exactly.

### Where no reason is stated

The brief asks for the stated reason, or an admission that none exists. I mean this in one specific sense throughout: **why the mechanism exists at all**, not why some implementation detail inside it was written that way.

Carrying **no stated rationale for their existence** anywhere in the code, comments, headers, `docs/architecture.md`, or `AGENTS.md` - only the implementation: **M2** (why this branch order), **M3** (why the ladder runs PR-proof before content rather than the reverse), **M4** and **M8** (the header states *what* they recognize, never why patch-id was chosen over, say, comparing trees), **M12** (the check is required by `AGENTS.md` section 8, but its four specific conditions are unexplained), **M16** (the `origin/HEAD` -> `main` -> `master` order is stated as fact in `docs/architecture.md:116`, never justified), and **M21**. I have not invented reasons for any of them; the Why column below gives the porting rationale against our constraints, which is a different thing from the donor's rationale.

Carrying a stated reason for their existence, cited inline above: M1, M5, M7, M9, M13, M15, M17c, M20, M22, M23, M24, M25, M26.

**M18 and M19 sit between the two** and are worth calling out rather than filing on either side. Neither has a stated reason for *existing* - a return path and a lease acquisition are self-evident - but both have a stated reason for their **exact call shape**, which is the part a porter can get wrong: M18's `cd` before invoking, because treehouse resolves its pool from the working directory (`bin/fm-teardown.sh:1195-1196`), and M19's `--lease`, whose durability semantics are documented by **treehouse's own `get --help`**, not by firstmate. That second one is a dependency-doc citation, not a donor-code citation, and I have treated it as prose-sourced accordingly.

---

## 2. Verified versus prose-sourced

### Verified (code read)

Every mechanism M1-M27 above. Specifically the refusal conditions, the ordered predicate in M2, the three `PR_IDENTITY` regimes, the patch-id containment rule, the `merge-tree` content proof, the `--force` skip/no-skip split, the isolation assertion's four conditions, the tangle classifier's exact silence conditions, the `lsof`-missing fail-safe direction, and the lease-return-failure behavior.

The treehouse command surface (M17b) is verified both positively and negatively: `rg -no "treehouse [a-z-]+" bin/ | sort -u` over all of `bin/`, with each non-command token hit opened and confirmed to be prose in a comment, plus a negative grep for `treehouse (prune|destroy|status|init|update)` returning nothing.

Plus these empirical probes: `treehouse --version` -> `v2.0.0`; `treehouse get --help` lease semantics; `treehouse return --help` (only flag is `--force`); `treehouse prune --help` staleness definition; `git worktree list` confirming linked worktrees sit detached.

### Prose-sourced (not verified against implementation)

- The claim in `bin/fm-teardown.sh:9-11` that "a fork counts as a remote, so upstream-contribution PRs pushed to a fork satisfy this in any mode." Plausible - `--not --remotes` covers all remote-tracking refs - but I did not test a fork-remote configuration.
- All Orca-specific behavior. Orca is a dropped backend; I read the call sites only to establish where the shared checks sit relative to them.
- `bin/fm-pr-identity.sh verify`'s output contract (`merged=`, `head_sha=`). I read the consumer at `:393-394`, not the producer.
- `bin/fm-decision-hold.sh verify`'s semantics. I read the call site at `:1136-1141` only. Assignment 6 does not own it.
- The Herdr presentation-journal retirement logic (`:1208-1265`). Read but not traced into `fm-backend.sh`.
- `worktree_registered_for_project` internals (`:530-548`) - I read the signature and callers, not the body.

### Where prose is wrong or misleading

These are the findings the brief asked for. All four are header-versus-implementation divergences in `bin/fm-teardown.sh`, the file whose header claims to own the landed-work proofs.

**F1 (most serious). The header never mentions the `invalid-binding` refusal.** The header enumerates the landing proofs at `:7-23` and says a `gh` error "falls back to the content check". It does not say that when `PR_IDENTITY` is non-empty and not `atlas-pat`, `work_is_landed:470-473` refuses **unconditionally with the content fallback explicitly disabled** - no PR lookup, no content proof, nothing. That regime is entered whenever `state/<id>.pr-binding` exists but fails `fm_pr_binding_profile`, **or** when `pr_identity=` appears in meta with no binding file (`:133-142`). A porter reading only the header would implement a landed-work test that accepts work this one refuses. It is a fail-safe direction, so it produces false refusals rather than lost work - but it is a refusal condition absent from the document that claims to own them.

**F2. "Uncommitted changes are never landed" (`:24`) is stated flatly and is scoped in code.** `:739` filters `?? .claude/` and `?? .fm-grok-turnend` out of the dirty set before it is evaluated. Narrow and defensible - those are firstmate's own hook droppings, removed at `:1181`/`:1193` - but a port that implements the header sentence literally will refuse teardown on every task that ever wrote a harness settings file. A port that copies the filter without understanding it will whitelist paths that no longer exist in our system.

**F3. local-only is described as an addition and is implemented as a separate path.** Header `:25-27`: "local-only projects **additionally accept** work merged into the local default branch... as a fallback." That reads as a superset. In code (`:751-768`), local-only with unpushed commits takes its own branch and **never calls `work_is_landed` at all**. Consequence: a local-only task whose PR merged remotely, but whose commits are not on the *local* default branch, is **refused** - the merged-PR proof it would have passed is never run. Again fail-safe, but the header's "additionally" is the wrong word and would mislead a port into wiring the two paths as one.

**F4. Two different GitHub CLIs are assumed present.** PR *discovery* uses `gh-axi pr list` (`:289`); PR *verification* uses plain `gh pr view` (`:412`). Neither the header nor `docs/architecture.md` mentions the split. A port that installs only one loses either the discovery fallback or the merged-PR proof, silently, because both failure modes are swallowed into "no PR found" / "fall back to content check".

One accuracy note in the other direction: `docs/architecture.md:106-119` on worktrees and the tangle is **correct in every particular** I checked against code, including the detached-HEAD reasoning and the `origin/HEAD` -> `main` -> `master` resolution order. The teardown header is also accurate on lease-return-failure (M20) and on the stale-lock fail-safe direction (M25).

---

## 3. Verdict per mechanism

"Already have it?" is checked against `~/.claude/commands/Themis.md`, `Atlas/Config/packages/pi-themis/extensions/themis.ts`, and `Atlas/Config/packages/omp-themis/skills/themis-pm/SKILL.md`. I grepped all three for worktree, treehouse, teardown, landed, unlanded, isolat, terminate, kill. Results: the persona mentions worktrees twice (`:65` mandating `/ce-worktree`, `:99` listing worktrees as disposable artifacts) and `:47` authorizing termination on role completion. The pi extension has no lifecycle mechanism at all - `themis.ts:75` mentions worktrees only as gitignored disposable artifacts. The OMP skill says the same at `SKILL.md:27`. The installed `ce-worktree` skill is create-only: its own description is "Set up isolated git worktrees", and its only removal content is bare `git worktree remove` in a troubleshooting section (`ce-worktree/SKILL.md:64`, `:84-86`). There is no `ce-teardown` or equivalent.

Constraint shorthand used in the Why column, from the brief's decided list: **[treehouse-external]** treehouse stays an external CLI dependency, not an internal; **[herdr-only]** herdr is the only session backend kept; **[deterministic]** classification stays deterministic with no model judgment; **[state-split]** volatile runtime state local and gitignored, durable knowledge committed.

| Mechanism | Verdict | Why | Already have it? |
|---|---|---|---|
| M1 teardown safety predicate | **copy** | **[treehouse-external]** - the external CLI is only ever called as `return --force`, so it contributes no safety; the guard must live in our code or nowhere. | **absent** - `Themis.md:47` terminates on role completion with no precondition |
| M2 ordered predicate | **copy** | **[deterministic]** - a fixed branch order is what makes the refusal reproducible instead of a judgment call at teardown time. | **absent** |
| M3 landing proof ladder | **copy** | **[deterministic]** - landing is decided by git and forge facts, never by a model reading the diff. | **absent** |
| M4 merged-PR proof | **copy** | **[deterministic]** - gives a mechanical answer for squash-merge-then-delete, the case where the naive remote check would otherwise force a human judgment call. | **absent** |
| M5 content-in-default proof | **copy** | **[treehouse-external]** - pure `merge-tree`, no donor or CLI context, so it ports whole and covers the no-PR case the external CLI knows nothing about. | **absent** |
| M6 Atlas broker verification | **strip** | Serves firstmate's Atlas PAT identity broker. **No decided constraint drops this**; I am asserting the assumption that we are not porting a PAT-broker identity regime. If we do adopt one, this becomes `rebuild` and F1's refusal path comes with it. | **absent** |
| M7 PR-discovery fallback | **copy** | **[deterministic]** - recovers the PR mechanically when no record exists, instead of escalating "is this landed?" to a person or a model. | **absent** |
| M8 patch-id containment | **copy** | **[deterministic]** - `git patch-id --stable` is an exact equality test, the deterministic alternative to eyeballing whether a rebased branch matches. | **absent** |
| M9 scout report + decision gate | **copy** | **[state-split]** - the worktree is volatile and discardable, the report is the durable knowledge; this gate is what enforces that the durable artifact exists before the volatile one dies. | **partial** - `Themis.md:76-87` requires explorers to produce reports, but nothing gates cleanup on the file existing |
| M10 secondmate carve-out | **rebuild** | **No decided constraint drops delegated sub-orchestrators** - the brief drops backends and vocabulary, not this. Drop the firstmate home-hierarchy container, but the rule inside it is a work-preservation rule: **[state-split]** any in-flight child task record refuses teardown of its owner. If our port ever has an agent owning sub-agents, we need that rule. | **absent** |
| M11 local-only path | **rebuild** | **[deterministic]** - keep a mechanical local-landing proof, but fix F3 so it is a proof inside the ladder rather than a separate refusal path that skips the others. | **absent** |
| M12 spawn isolation assertion | **copy** | **[treehouse-external]** - we cannot trust an external binary's exit status to prove where the agent ended up, so we assert the invariant ourselves in pure git. | **partial** - `Themis.md:65` mandates `/ce-worktree`, so isolation happens; nothing *asserts* it |
| M13 acquisition + cwd poll | **rebuild** | **[herdr-only]** - the two-read poll exists only because the take is typed into a pane. On herdr we should call the external CLI as a subprocess and read its printed path, deleting the inference entirely. | **absent** |
| M14 ship-brief isolation contract | **copy** | **[treehouse-external]** - the worker-side half of M12, and the only check that still runs if the external CLI silently hands back the wrong directory. | **absent** - our worker brief (`Themis.md:64-67`) has no isolation verification step |
| M15 tangle classifier | **copy** | **[treehouse-external]** - the pool and our own checkout are linked worktrees of one repo, so "linked" cannot discriminate; we inherit that exposure the moment we dispatch agents onto our own config repo. | **absent** |
| M16 default-branch resolution | **rebuild** | **[deterministic]** - the resolution order is the rule; port exactly **one** copy, since the donor's two copies can drift and make the same repo classify differently in two places. | **absent** |
| M17 tangle alarm surfaces | **rebuild** | **[state-split]** - keep the alarm reading from local volatile state, drop the fleet-lock read-only wording that assumes firstmate's session lock. | **absent** |
| M17b treehouse command surface | **copy** | **[treehouse-external]** - four invocations is the entire integration contract; anything beyond it is us reaching into the CLI's internals. | **absent** |
| M17c capability probe + dependency | **copy** | **[herdr-only]** - `backends/herdr.sh:10` makes treehouse the worktree provider under the one backend we keep, so a `--lease`-less version must fail startup, not fail at teardown. | **absent** |
| M18 return path | **copy** | **[treehouse-external]** - correct call shape for the kept CLI, including the pool-resolution `cd` that the CLI's own contract requires. | **absent** |
| M19 lease acquisition | **copy** | **[treehouse-external]** - `--lease` is the CLI's own durability primitive; without it a persistent home is prunable out from under us. | **absent** |
| M20 lease release on removal | **copy** | **[treehouse-external]** - returning through the CLI is the only way to release its lease; `rm -rf` leaks a pool slot permanently. | **absent** |
| M21 removal-target validation | **copy** | **[state-split]** - these guards keep destruction confined to volatile task state and never reach the durable repo or the active home. | **absent** |
| M22 pool-reuse hygiene | **rebuild** | **[treehouse-external]** - returning to a shared pool means our hook droppings outlive the task, so we need this; the specific file paths are donor harness files and must be re-derived. | **absent** |
| M23 gate-agent refusal | **rebuild** | **[treehouse-external]** - no-mistakes stays an external CLI, so we need a barrier stopping its agent from tearing down, but the donor's marker detection is specific to firstmate's own gate topology. | **absent** |
| M24 stale-lock retry | **copy** | **[treehouse-external]** - this is error-signature handling for the kept CLI's one known transient failure; without it a lock race becomes a hard teardown failure. | **absent** |
| M25 stale-lock proof | **copy** | **[deterministic]** - `lsof` plus mtime is a mechanical staleness test that resolves every uncertainty to "leave it alone" rather than guessing. | **absent** |
| M26 re-validation after cleanup | **copy** | **[deterministic]** - re-running the same predicate after state changed is what keeps the decision reproducible rather than dependent on when it was evaluated. | **absent** |
| M27 `--force` skip/no-skip split | **copy** | **[state-split]** - force may discard volatile work on explicit authority, but must never be able to reach durable material; that split is the whole safety boundary. | **absent** |

---

## 4. Coupling notes

Things a porter breaks by touching them.

**Ordering is load-bearing in three places.**
1. `fm_refuse_if_gate_agent` at `:117` runs *before* any fleet mutation, before the meta file is even read. Move it later and a gate agent gets a window.
2. `validate_pr_poll_cleanup` at `:1103` runs *before* the secondmate and scout gates. It refuses and preserves state on unsafe artifacts, so it must precede anything destructive.
3. The M1 -> stale-lock-cleanup -> M1-again sequence at `:1154-1166`. The second call is not defensive duplication; the first call could not read the repo.

**The post-cleanup callback is not optional.** `:1200` passes `validate_worktree_teardown_safety` by name into `teardown_treehouse_return`, which invokes it at `:699-704` after removing a stale lock. Drop the callback parameter as "unused indirection" and you delete the re-check on the exact path where state changed underneath you.

**Return codes 2 and 3 are distinct and both meaningful.** `TEARDOWN_TREEHOUSE_LOCK_REFUSED=2` (`:583`) means "lock persisted, not provably stale, left alone" and propagates specially through child cleanup (`:1080-1082`, where it aborts rather than falling through to `rm -rf`). `TEARDOWN_WORKTREE_SAFETY_LOCK_BLOCKED=3` (`:584`) means "retry after cleanup". Collapsing either into a generic 1 turns a careful refusal into either a hang or a deletion.

**The dirty-filter and the hygiene-removal are the same paths.** `:739` whitelists `.claude/` and `.fm-grok-turnend` out of the dirty check; `:1181`/`:1193` delete exactly those. Change one list without the other and either teardown always refuses, or a reused pool worktree fires signals for a dead task.

**`default_branch` exists twice.** `bin/fm-tangle-lib.sh:22-36` (parameterized) and `bin/fm-teardown.sh:155-169` (hard-coded to `$PROJ`). They agree today. A porter who fixes one has not fixed the other.

**The tangle classifier's call sites are part of the mechanism.** `fm_primary_tangle_branch` is only ever invoked against `FM_ROOT` (`fm-guard.sh:122`, `fm-bootstrap.sh:839`). Calling it in a loop over `git worktree list` would flag every live task's worktree - as this repo's own state demonstrates, one linked worktree is currently on `fm/atlas-key-pr-identity-redteam-k6`. The predicate is safe only because of where it is called.

**The guard is advisory and teardown treats it as such.** `"$FM_ROOT/bin/fm-guard.sh" || true` at `:119`. The tangle warning never blocks teardown. If our port wants the tangle to be blocking, that is a deliberate change, not a port.

**Two CLIs, both required.** See F4. `gh-axi` for discovery, `gh` for verification.

**treehouse resolves its pool from the working directory.** Every call is wrapped in a `cd` (`:653`, `:678`, `:705`, and the callers at `:987`/`:1202`/`:1076` choosing `FM_ROOT` vs the project vs the child project). Run `treehouse return` from the wrong directory and it addresses the wrong pool.

---

## 5. What I could not determine

- **Whether the `atlas-pat` regime can be reached in our port at all.** I traced `PR_IDENTITY` resolution and both consumers, but not `fm_pr_binding_profile` in `bin/fm-pr-lib.sh`. I cannot say what makes a binding valid, so I cannot say how easily a port could land in the `invalid-binding` refusal by accident. Worth one follow-up read before implementing F1's fix.
- **treehouse's pool-resolution rule.** `treehouse status` run from the repo root reports "No worktrees in pool" while `git worktree list` shows nine linked worktrees under `~/.treehouse/Firstmate-e6ac15/`. The repo's `origin` is `edheltzel/firstmate` but its directory is now `Themis`, and there is no `treehouse.toml` in the repo or under `~/.treehouse/`. So treehouse's own pool state and git's worktree registry are currently divergent here. I did not determine the cause - it could be the directory rename, the missing config, or normal behavior for worktrees treehouse no longer tracks. **I deliberately did not probe further, since narrowing it would mean taking or pruning a worktree.** Two consequences for the port: a port that assumes `treehouse status` is authoritative for "what worktrees exist" would be wrong on this machine right now; and because firstmate never calls `prune` or `status` (M17b), nothing in the donor would ever have noticed or corrected this.
- **Whether the M6 and M10 scope assumptions hold.** Both `strip`/`rebuild` calls rest on assumptions I am asserting rather than constraints the brief decided: that we are not porting a PAT-broker identity regime (M6), and that our orchestrator will not own persistent delegated sub-orchestrators (M10). Neither is on the decided-drop list. If either assumption is wrong, that verdict needs revisiting before implementation - M10 especially, since its in-flight-children refusal is a work-preservation rule and stripping it would recreate the exact class of bug this whole report exists to prevent.
- **Whether `--force`'s scout carve-out is ever safe in practice.** `--force` skips the decision-hold gate (`:1129`), so forcing a scout teardown discards the unresolved-decision inventory even when the report exists. Whether firstmate considers that acceptable, or simply never does it, is not stated anywhere I read.
- **The fork-as-remote claim** (header `:9-11`). See prose-sourced list.
- **Any behavior of treehouse v2.1.0.** `treehouse status` reported an available upgrade from the installed v2.0.0. All CLI semantics above are v2.0.0.
