# Donor map 03: session start and bootstrap

Scout report against `SCOUT-BRIEF.md`. Donor is `firstmate` at `/Users/ed/Developer/Atlas/Themis`.

Primary sources read: `bin/fm-session-start.sh` (whole file), `bin/fm-bootstrap.sh` (header + gating + secondmate liveness), `bin/fm-lock.sh` (whole file), `bin/fm-sessionstart-nudge.sh` (whole file), `bin/fm-primary-scope-lib.sh`, `bin/fm-supervision-instructions.sh`, `bin/fm-guard.sh`, `bin/fm-wake-drain.sh`, `bin/fm-backend.sh`, `bin/backends/herdr.sh`, `docs/sessionstart-nudge.md`, `AGENTS.md` section 3, plus the tracked hook wiring in `.claude/settings.json`, `.codex/hooks.json`, `.grok/hooks/`. Nothing was executed that mutates state; the only commands run were reads, `git show` against a local branch, and `jq` over tracked JSON.

Prior reports 02, 05, 06 and the heartbeat dissection were checked for overlap. The heartbeat report is **not** on the current checkout — it lives on the local branch `docs/themis-heartbeat-dissection` (commit `dbc932a`) and I read it via `git show`. Report 05 was correct that it is absent from the working tree.

---

## 0. Headline

1. **Lock-refused read-only mode has zero code enforcement.** `state/.lock` is read by exactly four files (`bin/fm-lock.sh:14`, `bin/fm-sessionstart-nudge.sh:23`, `bin/fm-session-start.sh:313`, and nothing else). `fm-spawn.sh`, `fm-send.sh`, `fm-pr-merge.sh`, `fm-merge-local.sh`, and `fm-watch-arm.sh` never check it. Read-only mode is a banner printed at `bin/fm-session-start.sh:251-262` plus prose the model is asked to obey. Two live sessions are prevented from racing *bootstrap's sweeps and the wake drain* and nothing else.

2. **The sweep gating is compositional, not intrinsic.** `bin/fm-bootstrap.sh` never reads the lock; the five mutating sweeps are gated only by `FM_BOOTSTRAP_DETECT_ONLY` (`bin/fm-bootstrap.sh:808`, `:858`), which `bin/fm-session-start.sh:268` sets on the refused path. Direct invocation of `fm-bootstrap.sh` is a *documented supported path* (`bin/fm-session-start.sh:18-20`, and the `install` subcommand at `:788`), so an unlocked mutating run is sanctioned, not an oversight. Port the flag, but put the lock check inside the sweep owner.

3. **The sweep order is documented wrong in two places, and the real order carries a data dependency.** Both `bin/fm-bootstrap.sh:70` and `AGENTS.md` section 3 list orders that contradict the code at `:858-863` (actual: liveness, sync, x-mode, fleet-sync). It matters: `secondmate_sync` reads `SECONDMATE_RESPAWNED_IDS` (`:346`, `:371`) which only `secondmate_liveness_sweep` sets (`:445`, `:467`), to suppress a redundant re-read nudge to an agent that just relaunched.

4. **`bin/fm-lock.sh:18` hardcodes `HARNESS_RE='claude|codex|opencode|grok|^pi$'`.** Any harness outside that list fails `harness_pid()` and exits 1 at `:52` — "cannot locate harness process in ancestry" — which `fm-session-start.sh:249` treats identically to a refusal, so **every** session on that harness degrades to read-only forever. OMP is not in the list and we ship an OMP Themis package. This is a `rebuild`, not a `copy`.

5. **A fresh clone can never be nudged into running session start.** `fm_primary_scope_matches` requires `[ -d "$state" ]` (`bin/fm-primary-scope-lib.sh:32`), `state/` is gitignored (`.gitignore:2`) and untracked (`git ls-files state/` is empty), and the first thing that creates it is `bin/fm-lock.sh:15` — inside the command the nudge exists to trigger. The wrapper silently exits 0; `docs/sessionstart-nudge.md:108` shows the missing-state-dir silence is deliberately tested, so this is by design, but the porter must supply a first-run path.

---

## 1. Mechanism inventory

### The lock

**M1. Session lock: harness-ancestry PID file.**
`bin/fm-lock.sh:20-36` walks at most 8 parents from `$$` looking for a process whose `comm` basename or (for bare `node`/`python`) whose `args` match `HARNESS_RE`, and writes that PID to `state/.lock` (`:60`). Acquisition succeeds if the file is absent, names this same PID, or names a PID that fails `holder_alive` (`:38-43`, `kill -0` **plus** a harness-name recheck, so a recycled PID belonging to an unrelated process is treated as stale). Depends on: `ps`, the hardcoded harness list. Depended on by: `fm-session-start.sh:245`, `fm-sessionstart-nudge.sh:23-34`, `fm-session-start.sh:313` (Pi extension check). Why: stated at `:3-5` — record the *agent* process PID, which outlives the session, rather than the transient subshell PID of one tool call.

**M2. Lock-first ordering.**
`bin/fm-session-start.sh:243-263` runs `fm-lock.sh` as step 1 and sets `READ_ONLY=1` on any non-zero exit. Why: stated verbatim at `:51-57` — the *previous* documented order was bootstrap-then-lock, which let a second concurrent session fast-forward secondmate homes, write X-mode artifacts, and fetch/fast-forward every project clone before discovering it did not own the lock. This is the one ordering constraint in the whole script with a stated, non-obvious rationale.

**M3. Detect-only gate on the five mutating sweeps.**
`bin/fm-bootstrap.sh:808-810` (legacy PR-check migration) and `:858-863` (`secondmate_liveness_sweep`, `secondmate_sync`, `x_mode_setup`, `fleet_sync`) are the only two `FM_BOOTSTRAP_DETECT_ONLY` guards. Everything between `:812` and `:856` — backend validation, tool detection, treehouse/no-mistakes/tasks-axi version gates, `gh auth status`, the tangle check, crew-dispatch validation — runs unconditionally in both modes. Set by `fm-session-start.sh:268`. Why: stated at `bin/fm-bootstrap.sh:69-79` and `fm-session-start.sh:20-23` — an opt-in additive flag rather than a fork of bootstrap, so the standalone callers (`/updatefirstmate`, the afk daemon, tests) keep unchanged behavior.

Note the PR-check migration is deliberately placed **before** tool detection, not with the other three. Reason stated at `:804-807`: it pauses an identity-matched watcher and neutralizes legacy runnable PR checks before any later bootstrap mutation can leave old artifacts armed.

**M4. Read-only mode as a printed contract.**
Three surfaces, all advisory: the banner at `fm-session-start.sh:251-262`; the `NEXT STEP` block at `:391-397`; and one line inside the emitted supervision block at `fm-supervision-instructions.sh:190-194` (`- Lock: read-only; do not drain, arm, spawn, steer, merge, or repair fleet state here.`), with the watcher-repair line replaced at `:118-121`. Depends on: nothing enforcing it. Depended on by: model compliance only.

**M5. Wake-queue drain skip + read-only guard.**
`fm-session-start.sh:287-292`: on the refused path the queue is counted but never touched, and `fm-guard.sh` is invoked with `FM_GUARD_READ_ONLY=1` (`bin/fm-guard.sh:29-30`) so the tangle and watcher-liveness alarms still print without repair commands. On the locked path `fm-wake-drain.sh` runs and calls `fm-guard.sh` itself after emptying the queue (`bin/fm-wake-drain.sh:25-27`), so the alarms land in the same place either way. Why the drain is skipped: stated at `fm-session-start.sh:282-285` — another session may be actively draining it. The drain is genuinely mutating: it `mv`s the queue aside under a lock and truncates it (`bin/fm-wake-drain.sh:45`, `:56-57`).

**M6. Tangle-check wording switch.**
`bin/fm-bootstrap.sh:839-847`. The detection (`fm_primary_tangle_branch`) runs in both modes; only the remediation text differs — detect-only says "leave restore work to the session holding the fleet lock" (`:843`), locked mode prints the actual `git checkout` command (`:845`). This is the one place a read-only session's *output* is modified rather than the action skipped, and it is the correct pattern: detect always, prescribe only when you own the mutation.

### Bootstrap sweeps

**M7. Secondmate liveness sweep.**
`bin/fm-bootstrap.sh:412-479`. For every `state/*.meta` with `kind=secondmate` and a recorded `window=`, run `fm_backend_agent_alive` and act only on a confident `dead`: kill the stale endpoint (`:465`), then respawn via `FM_SPAWN_NO_GUARD=1 fm-spawn.sh <id> --secondmate` (`:466`). `unknown` is never acted on. Why: stated at `:413-442` with dated evidence (2026-07-07: every secondmate in the fleet was a dead `zsh` shell, invisible to every existing check, because the digest's endpoint read is pane-presence only and the watcher deliberately exempts secondmates from stale detection). Asymmetry argument stated at `:429-433`: a false-dead spins up a duplicate supervisor; a false-alive merely leaves the bug for one more sweep.

**M8. Agent-liveness probe (`fm_backend_agent_alive`).**
`bin/fm-backend.sh:721-729`, dispatching to `fm_backend_tmux_agent_alive` or `fm_backend_herdr_agent_alive` (`bin/backends/herdr.sh:1040-1048`). The herdr path reuses the husk classifier `fm_backend_herdr_pane_agent_state` (`bin/backends/herdr.sh:982-1014`): `pane get` error `pane_not_found` → `dead`; `agent get` error `agent_not_found` → `no-agent`; an `agent_status` of `working|idle|done|blocked` → `live`; everything else → `unknown`. `dead` and `no-agent` both collapse to `dead` for liveness. zellij, orca, cmux always return `unknown` (`fm-backend.sh:727`). Report 02 M11 covers the classifier itself; the session-start-specific parts are M7 above and M9 below.

**M9. Harness allowlist downgrade inside the liveness sweep.**
`bin/fm-bootstrap.sh:457-460`: if the meta's `harness=` is not one of `claude|codex|opencode|pi|grok`, a `dead` verdict is rewritten to `unknown`. So the respawn path is gated **twice** — once on the backend having a verified classifier, once on the harness being a verified adapter. No stated reason at the code site; it is consistent with the never-respawn-on-doubt argument at `:429-433`.

**M10. Liveness → sync data dependency.**
`secondmate_liveness_sweep` accumulates `SECONDMATE_RESPAWNED_IDS` (`:445`, `:467`); `secondmate_sync`'s inherited-config re-read path reads it (`:346`, `:371`) and sets `reread_skip_pending=1` for a just-respawned id, because a respawn already re-reads at launch (reason stated at `:342-343`). This is a hard ordering invariant between two sweeps that the header and `AGENTS.md` both describe in the wrong order.

### The digest

**M11. Context digest with ABSENT semantics.**
`bin/fm-session-start.sh:327-333`, using `print_file_or_absent` (`:121-133`). Prints the full contents of `data/projects.md`, `data/secondmates.md`, `data/captain.md`, `data/captain-shared.md`, `data/learnings.md`, distinguishing three states: contents, `(present, empty)`, and `ABSENT`. Why: stated at `:116-120` — absence is semantically meaningful per file (`captain.md` absent means use built-in defaults; `projects.md` absent means rebuild from the clones) and must never be confused with an empty-but-present file.

**M12. Fleet-state digest.**
`bin/fm-session-start.sh:335-387`. Four parts: the compact backlog listing; a `state/*.meta` walk that prints the raw meta, one endpoint-liveness line, and a bounded status tail; an orphan-status pass (`:370-380`, status logs with no matching meta); and the `state/.afk` flag. The status tail is explicitly labeled wake-EVENT history with the full log path (`:213-217`) — the same status-is-not-state distinction the heartbeat report covers as A1.

**M13. Backlog compaction with backend fallback.**
`bin/fm-session-start.sh:139-211`. When compatible `tasks-axi` is available, ask it for identity fields plus `blocked_by,hold_kind,hold_reason` and never body (`:181`); on non-zero exit, print the error *and* fall back to awk title-line rendering (`:186-188`); in manual mode or with an incompatible binary, use awk directly. The awk path only recognizes the three headings `In flight`, `Queued`, `Done` (`:146-148`) and prints a truncation count. Why: stated at `:70-82` — keep title-line hold/blocked metadata visible while indented bodies stay out of the startup digest.

**M14. Endpoint liveness is presence-only, by design.**
`bin/fm-session-start.sh:348-359` calls `fm_backend_target_exists`, not `fm_backend_agent_alive`. Why: stated in `AGENTS.md` section 3 step 5 — a fast bounded presence check, with `bin/fm-crew-state.sh` as the deeper read when actual current state matters. This is exactly the gap M7 exists to close for secondmates, and it remains open for ordinary crewmates.

**M15. Supervision-instructions emission.**
`bin/fm-session-start.sh:321-325` invokes `fm-supervision-instructions.sh` with `--harness/--read-only/--afk/--x-mode`. That script selects `docs/supervision-protocols/<harness>.md` (`:84-85`), falls back to `unknown.md` for an unrecognized harness or a missing file (`:85`, `:87`), and renders it with four placeholder substitutions (`:106-115`). The script never arms supervision (`fm-session-start.sh:44-45`, `:409`). Its position — after the wake queue, before context — is asserted in `AGENTS.md` section 3 step 6; no rationale is stated at the code site, and the script header's own ordering list omits this step entirely (see §2).

**M16. Pi extension-loaded check.**
`bin/fm-session-start.sh:231-239` + `:308-320`. Only on a Pi primary: compare a marker file's recorded version against a fresh `shasum` of the tracked extension **and** the marker's recorded PID against `state/.lock`'s PID. Both extensions must pass or a `PI_WATCH_EXTENSION` line prints. This is the only place outside `fm-lock.sh` that reads the lock for a purpose other than the nudge, and it is a neat trick: the lock PID doubles as "same session" identity.

**M17. Re-read suppression.**
`bin/fm-session-start.sh:419-432`. A closing block instructing the agent not to re-read the five context files, `state/*.meta`, `data/backlog.md`, or `state/*.status`, with four named exceptions (ABSENT, unparseable, older status history, targeted inspect-before-write). Why: stated at `:11-12` and `:428` — every one of those reads is unconditional at every session start, so they belong in a script rather than N agent turns; re-reading defeats the point.

**M18. Always-exit-0 reporting contract.**
`bin/fm-session-start.sh:434`, rationale at `:86-88`: a lock refusal is a loud inline banner, never a non-zero exit, because a non-zero exit would make an agent skip the rest of the digest.

### The nudge

**M19. Nudge wrapper and its three silence predicates.**
`bin/fm-sessionstart-nudge.sh` prints exactly one line (`:38`) and exits 0 on every path (rationale at `:4-5`: Claude `SessionStart` exit 2 blocks session initialization). It stays silent when (a) `fm_is_gate_agent` matches a no-mistakes gate agent (`:18`), (b) `fm_primary_scope_matches` fails (`:19`), or (c) the lock names a live PID within 8 parents of this process (`:21-37`), meaning session start already ran in this harness session.

**M20. Primary-scope predicate.**
`bin/fm-primary-scope-lib.sh:23-33`. Primary means: a valid `.fm-secondmate-home` marker **or** `git-dir == git-common-dir` (a plain checkout, never a linked task worktree), plus `AGENTS.md`, plus `bin/`, plus an existing state dir. Shared with `bin/fm-turnend-guard.sh` so the two hooks cannot drift (stated in `docs/sessionstart-nudge.md:11`).

**M21. Harness transports.**
Tracked wiring verified directly: Claude registers the wrapper on `startup|resume|clear` via `CLAUDE_PROJECT_DIR` in `.claude/settings.json`; Codex runs it from `.codex/hooks.json` behind five defensive checks (payload non-empty, `jq` present, `pwd -P` root has `bin/fm-sessionstart-nudge.sh`, `AGENTS.md`, and a self-referencing `.codex/hooks.json`); Grok invokes it through `${GROK_WORKSPACE_ROOT:-}` with an inline default so an unset variable exits 0. OpenCode and Pi go through JS/TS plugins (`docs/sessionstart-nudge.md:24-25`), not read.

---

## 2. Verified versus prose-sourced

### Verified (code read)

- Lock is acquired first and its result selects detect-only bootstrap. `fm-session-start.sh:245-249`, `:267-271`.
- Exactly five sweeps are behind `FM_BOOTSTRAP_DETECT_ONLY`, at two sites. `fm-bootstrap.sh:808-810`, `:858-863`.
- `fm-bootstrap.sh` never reads `state/.lock`. Grep over `bin/` returns only `fm-lock.sh:14`, `fm-sessionstart-nudge.sh:23-24`, `fm-session-start.sh:313`.
- No mutating command checks the lock. `fm-spawn.sh`, `fm-send.sh`, `fm-pr-merge.sh`, `fm-merge-local.sh`, `fm-watch-arm.sh` contain no reference to `fm-lock` or `state/.lock`. (`fm-teardown.sh` matches `fm-lock` but sources `fm-lock-lib.sh` for git `index.lock` staleness — unrelated to the session lock.)
- The read-only path leaves the wake queue untouched and still runs the guard advisorily. `fm-session-start.sh:287-292`.
- The tangle check runs in both modes with different remediation wording. `fm-bootstrap.sh:839-847`.
- The liveness sweep respawns only on a confident `dead`, kills before respawning, and downgrades `dead` to `unknown` for an unverified harness. `fm-bootstrap.sh:456-476`.
- `secondmate_sync` consumes `SECONDMATE_RESPAWNED_IDS` set by the liveness sweep. `fm-bootstrap.sh:346`, `:371` ← `:445`, `:467`.
- The herdr agent-alive probe reads `2>&1` deliberately because real herdr writes error JSON to stderr. `bin/backends/herdr.sh:984-992`.
- Endpoint liveness in the digest is `fm_backend_target_exists` (presence), not the agent probe. `fm-session-start.sh:352`.
- The digest distinguishes contents / `(present, empty)` / `ABSENT`. `fm-session-start.sh:121-133`.
- The backlog listing falls back to awk on `tasks-axi` failure and prints the failure. `fm-session-start.sh:183-189`.
- The supervision block is rendered from `docs/supervision-protocols/<harness>.md` with `unknown.md` as a double fallback. `fm-supervision-instructions.sh:11`, `:84-87`.
- The nudge wrapper's three silence predicates and unconditional exit 0. `fm-sessionstart-nudge.sh:18-19`, `:21-39`.
- Primary scope requires an existing state dir; `state/` is gitignored and untracked. `fm-primary-scope-lib.sh:32`, `.gitignore:2`, empty `git ls-files state/`.
- Claude, Codex, and Grok transports invoke the wrapper as documented. `.claude/settings.json`, `.codex/hooks.json`, `.grok/hooks/fm-primary-sessionstart-nudge.json`.

### Prose-sourced (not independently checked)

- OpenCode's `session.created` plugin and Pi's `session_start` extension invoke the wrapper. `docs/sessionstart-nudge.md:24-25`. I read the Claude/Codex/Grok JSON but not the JS/TS plugin bodies.
- Grok's hook fires but its stdout does not reach model context, and OpenCode headless is fail-open. `docs/sessionstart-nudge.md:26`, `:84`, `:68-71`. The 2026-07-17 empirical section is the primary evidence; I did not re-run any harness.
- Test coverage claims: `tests/fm-sessionstart-nudge.test.sh` proves silence for both gate signals, an unmarked linked worktree, a missing state directory, and an already-owned lock. `docs/sessionstart-nudge.md:108-110`. Not run.
- The 2026-07-07 dead-secondmate incident that motivated M7. `fm-bootstrap.sh:419-421`. A dated comment; no artifact checked.
- `fm_backend_tmux_agent_alive`'s bare-shell classifier. `bin/backends/tmux.sh:139-157` header only; tmux is dropped so I did not read the body.

### Where the prose is wrong

**Sweep order.** `bin/fm-bootstrap.sh:70` lists the five as *"PR-check migration, secondmate_sync, secondmate_liveness_sweep, x_mode_setup, fleet_sync"*. `AGENTS.md` section 3 step 2 lists them as *"non-executing legacy PR-check migration, fleet sync, the local secondmate fast-forward sweep, the secondmate liveness sweep, and X-mode artifact writes"*. `fm-session-start.sh:30-33` gives a third order. The code (`:808`, `:858-863`) is: PR-check migration (early, before tool detection), then liveness, sync, x-mode, fleet-sync. Two of the three prose orders put sync before liveness, which is the exact inversion of the `SECONDMATE_RESPAWNED_IDS` dependency.

**The script header's ordering list is missing a step.** `fm-session-start.sh:25-45` enumerates six steps: lock, bootstrap, wake-drain, context digest, fleet digest, closing reminder. The implementation emits the supervision-instructions block between wake-drain and context (`:302-325`), and the file's own inline section comments are consequently mislabeled — `:302` and `:327` are both `--- 4.`. `AGENTS.md` section 3 gets this right ("after the wake queue and before context"), so here the always-loaded contract is more accurate than the script header the contract points to as its single owner.

**"The lock genuinely gates them" needs qualifying.** The claim as written in `AGENTS.md` section 3 ("run only when this session actually holds the lock from step 1") is true of the composed `fm-session-start.sh` path and only that path. `fm-bootstrap.sh` invoked directly mutates regardless — and direct invocation is explicitly sanctioned by `fm-session-start.sh:18-20` and by bootstrap's own `install` subcommand. So: not a false contract, but a contract whose enforcement lives one level above the code that would need to honor it.

---

## 3. Verdict per mechanism

Our side: Themis persona at `~/.claude/commands/Themis.md` (symlink to `Config/claude/.claude/commands/Themis.md`), Pi extension at `Config/packages/pi-themis/extensions/themis.ts`, OMP package at `Config/packages/omp-themis/src/main.ts`.

| Mechanism | Verdict | Why | Already have it? |
|---|---|---|---|
| M1 Session lock (harness-ancestry PID) | **rebuild** | The concept is required — multiple harnesses means concurrent sessions are likely — but `HARNESS_RE` at `fm-lock.sh:18` omits OMP, and we ship an OMP package. A hardcoded allowlist that silently degrades an unlisted harness to permanent read-only is not portable. | **absent** — no lock, no concurrency notion anywhere in the persona or either extension. |
| M2 Lock-first ordering | **copy** | The stated hazard (a second session fast-forwarding clones and secondmate homes before discovering it lost the lock) applies unchanged once we keep any mutating startup sweep. | **absent** — `Themis.md:108-110` "First Action" is read-docs-and-confirm-codegraph, with no state acquisition. |
| M3 Detect-only gate | **copy**, moved inward | The additive-flag design is right; the lock check belongs inside the sweep owner, not only in the composing script. Volatile runtime state stays local per decided constraint, so the sweeps that touch it must self-gate. | **absent**. |
| M4 Read-only mode as printed contract | **rebuild** | Prose-only enforcement is the weakest link in the donor and we already own the missing primitive. Make it a real guard. | **partial** — `themis.ts:236-256` and `omp-themis/src/main.ts:300-306` already block tool calls at the harness level. That is exactly the enforcement shape read-only mode needs; it is currently wired to persona rules, not to a lock. |
| M5 Wake-drain skip + read-only guard | **copy** | The queue is durable, gitignored volatile state; skipping the drain when another session owns it is correct and cheap. | **absent** — no wake queue on our side (heartbeat report §2 covers the queue itself). |
| M6 Tangle-check wording switch | **copy** | Detect always, prescribe only when you own the mutation. Generalizable and free. | **absent**. |
| M7 Secondmate liveness sweep | **strip** | Secondmates are not being ported. Strip the sweep. | n/a |
| M8 Agent-liveness probe (herdr path) | **copy** | herdr is the only session backend we keep, and this is the deterministic "is a real agent there" predicate. `dead`/`no-agent` → dead, `live` → alive, everything else → unknown-and-never-acted-on. Generalizes beyond secondmates: it is the correct probe for *any* spawned agent, and the donor only ever applies it to secondmates. | **partial** — report 02 rates M11 `rebuild` against herdr 0.7.5. `Themis.md:47` promises "a heartbeat check-in for each agent to prevent stales" with no deterministic predicate behind it. |
| M9 Harness-allowlist downgrade | **rebuild** | The rule outlives its sweep: M7 is stripped, but "never convert an unverified reading into a licence to act" applies to every place we probe a spawned agent (M8, M14). Right instinct, wrong list — same OMP omission as M1. Derive the list from our verified adapters. | **absent**. |
| M10 Liveness → sync ordering invariant | **strip** | Exists only to serve the secondmate sweeps. | n/a |
| M11 Context digest + ABSENT semantics | **rebuild** | The three-state distinction is worth copying verbatim. The *contents* are firstmate's own private registry (`projects.md`, `secondmates.md`, `captain.md`, `learnings.md`) and mostly duplicate what our stack already reads at startup. | **partial** — the Claude side already injects dynamic context at `SessionStart` (`~/.claude/hooks/LoadContext.hook.ts`, `RecallStart.ts`), and Recall covers durable knowledge. What is missing is the ABSENT-vs-empty distinction and a project registry. |
| M12 Fleet-state digest | **rebuild** | We want the capability (one bounded read of what is in flight) but every input is firstmate-private state we are redesigning: `state/*.meta`, `.status`, `.afk`. Rebuild over live herdr state plus the board. | **absent** — `Themis.md:35` requires an end-of-turn status update composed from memory, not from a reconciled read. |
| M13 Backlog compaction + fallback | **rebuild** | The fallback-and-say-so pattern is worth keeping; the backend is not — we track work via `/pm-tools` and GitHub Projects, not `tasks-axi` over `data/backlog.md`. | **partial** — `Themis.md:104-106` owns issue/project tracking via `/pm-tools`; there is no startup listing. |
| M14 Presence-only endpoint read | **copy**, with the gap closed | Fast bounded liveness at startup is right. But the donor leaves ordinary crewmates on presence-only forever; since we keep herdr and M8 is cheap there, use the real probe. | **absent**. |
| M15 Supervision-instructions emission | **rebuild** | The per-harness-file rendering with an `unknown.md` fallback is a good pattern and directly matches our three-harness split. The *content* assumes firstmate's watcher, which the heartbeat report treats separately. | **partial** — three hand-maintained persona copies with no generator (heartbeat report §0); this is the generator-shaped hole. |
| M16 Pi extension-loaded check | **copy** (pattern) | Version-hash plus lock-PID identity is a cheap, correct "is my extension actually loaded in *this* session" check, and we run a Pi extension. | **absent** — `themis.ts:222-229` restores persona state on `session_start` but never verifies it loaded. |
| M17 Re-read suppression | **copy** | Costs nothing, saves a full turn of redundant reads, and the four stated exceptions are exactly right. | **absent**. |
| M18 Always-exit-0 | **copy** | A startup digest that exits non-zero gets its output skipped. Applies to any harness. | **absent**. |
| M19 Nudge wrapper + silence predicates | **copy** | This is the only thing that makes a startup contract actually run rather than hoping the model remembers. Idempotence via lock-in-ancestry is the key idea. | **partial** — the transport exists and is proven on our Claude side (`~/.claude/settings.json` `SessionStart` runs `LoadContext.hook.ts` and injects stdout into context); no Themis-specific nudge is registered. |
| M20 Primary-scope predicate | **rebuild** | We need *a* "am I in the right place" predicate, but ours is not a firstmate home — no `state/`, no secondmate marker. The linked-worktree exclusion (`git-dir != git-common-dir`) is the part worth keeping, since our workers run in worktrees. | **absent**. |
| M21 Harness transports | **copy** for Claude/Pi, **rebuild** for OMP | Claude and Pi transports are verified and we run both. Grok and OpenCode are not our harnesses. OMP has no donor transport at all — that is new work. | **partial** — Claude `SessionStart` proven; Pi `session_start` handler exists in `themis.ts:222`; OMP has a `session_start` handler at `omp-themis/src/main.ts:282` but nothing that injects a startup instruction. |

---

## 4. Coupling notes

**The lock's value is almost entirely in what it gates, and it gates very little.** If you port M1 without also porting the enforcement, you have added a file and a banner. Either put the check inside every mutating entry point, or wire it to the `tool_call` blocker we already have in `themis.ts:236-256`. Do not port the prose form.

**`FM_BOOTSTRAP_DETECT_ONLY` is a two-site guard, and both sites matter.** Porting only `:858-863` leaves the PR-check migration (`:808`) mutating on the read-only path. Its early position before tool detection is deliberate (`:804-807`).

**The liveness sweep must run before the sync sweep.** `SECONDMATE_RESPAWNED_IDS` (`:445`/`:467` → `:346`/`:371`). If a porter reads either the bootstrap header or `AGENTS.md` and implements that order, a just-respawned agent gets a redundant re-read instruction and may consume a retry-queue slot (`:374-379`). We are stripping secondmates, so this is a caution about trusting the headers generally, not a live risk.

**`fm_backend_agent_alive` returning `unknown` must never license an action.** Stated at `fm-backend.sh:717-720` and again at `herdr.sh:1038-1039`. The same three-state value is consumed by `fm_backend_herdr_tab_is_husk` (`herdr.sh:1021-1026`) for tab replacement, so weakening `unknown` at the classifier breaks spawn safety too, not just liveness. Report 02 §4 covers the spawn side.

**`fm-guard.sh` is called from two places on two different paths** — directly by `fm-session-start.sh:291` in read-only mode, and by `fm-wake-drain.sh:26` after the queue is emptied on the locked path. The comment at `fm-wake-drain.sh:21-24` explains the ordering: guard runs *after* the drain so it never re-prints a queued-wakes notice for records that run just consumed. A porter who moves the guard call earlier reintroduces a duplicate alarm.

**`fm-primary-scope-lib.sh` is shared with `fm-turnend-guard.sh`** (`docs/sessionstart-nudge.md:11`). Changing the predicate changes both hooks. The looks-redundant-but-is-not check is `git-dir == git-common-dir`: it exists to keep the nudge from firing inside a linked task worktree, where a spawned worker would otherwise be told to run the orchestrator's session start.

**The nudge's lock-in-ancestry check is the idempotence mechanism, not an optimization.** `fm-sessionstart-nudge.sh:29-34` walks 8 parents, matching `fm-lock.sh`'s depth and (per `docs/sessionstart-nudge.md:14`) Pi's `lockOwnership()`. Three independent implementations of the same ancestry walk. Any port should have one owner.

**Every nudge path exits 0 deliberately** (`fm-sessionstart-nudge.sh:5`): Claude `SessionStart` exit 2 blocks session initialization. A porter adding a `set -e` or an error exit turns a silent no-op into an unstartable session.

**The digest's own output is a contract.** `fm-session-start.sh:419-432` tells the agent not to re-read what was printed. If a port changes what the digest prints without changing that block, the agent is instructed not to re-read something it never got.

---

## 5. What I could not determine

- **Whether read-only mode has ever actually held in practice.** There is no test, log, or artifact I found showing a second session behaving read-only. The mechanism is unenforced, so compliance is unobservable from the code.
- **Whether `harness_pid()`'s 8-parent walk is sufficient under herdr.** `fm-lock.sh:22` walks 8 levels; I did not measure real ancestry depth for a harness launched inside a herdr pane. If herdr adds shell layers, acquisition could fail and silently produce a permanent read-only session — same failure mode as headline 4, different cause. Worth measuring before porting the constant.
- **What the OpenCode and Pi nudge plugin bodies actually do.** I verified the Claude/Codex/Grok JSON directly but not `.opencode/plugins/fm-primary-sessionstart-nudge.js` or the Pi `.ts` extension. Pi matters to us; that read should happen before porting M21.
- **Whether `fleet_sync` and `x_mode_setup` have their own internal guards.** I verified they sit behind the detect-only gate but did not read their bodies (`:154-186`, `:619-700`). Both are being dropped or rebuilt, so I deprioritized them; if fleet-sync's guarded-refresh path is being ported for clone management, it needs its own pass.
- **The bare-shell classifier for tmux** (`bin/backends/tmux.sh:157`). tmux is dropped, so I read the header only. If any part of the herdr probe is ever reused against a non-herdr backend, that body is the reference implementation.
- **Whether the three ancestry-walk implementations agree.** `fm-lock.sh:20-36`, `fm-sessionstart-nudge.sh:21-35`, and Pi's `lockOwnership()` are documented as matching at depth 8, but they differ in what they match on (`fm-lock.sh` matches harness names; the nudge matches a specific PID). I did not read Pi's.
