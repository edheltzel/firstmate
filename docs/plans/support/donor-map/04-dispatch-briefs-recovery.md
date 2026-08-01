# Donor map 04: dispatch, briefs, and stuck-agent recovery

Scout report against `SCOUT-BRIEF.md`. Donor is `firstmate` at `/Users/ed/Developer/Atlas/Themis`.
Read-only throughout. `bin/fm-spawn.sh` was never executed. Every `file:line` below was read in this session.

Worktree isolation and the teardown refusal rules are owned by `docs/plans/support/donor-map/06-treehouse-isolation.md`. This report references its M12 (spawn isolation assertion) and M13 (`treehouse get` path) rather than re-deriving them, and adds only what the brief and dispatch layers contribute on top.

---

## 0. Headline

- **The brief is the wire protocol, not documentation.** `bin/fm-brief.sh:115` compiles the absolute status-file path into the brief at scaffold time, and `:392` pins the six state verbs that `bin/fm-classify-lib.sh:45`'s regex matches. Port supervision without porting the brief and you get a supervisor polling a file nothing ever writes - the assignment's hypothesis is confirmed, with one correction in the next bullet.
- **Ship and scout workers are told to close keyed events they were never taught to open.** `bin/fm-brief.sh:406` (ship) and `:284` (scout) say "add the same `[key=<slug>]` if you opened it with one"; only the secondmate charter at `:177` teaches opening one. The fold in `bin/fm-classify-lib.sh:210-234` is kind-agnostic, so every crewmate `needs-decision:` lands on key `default` and **a second open decision silently evicts the first** from the open set (`_fm_decision_drop`, `:189-204`). The mechanism that exists to stop decisions from being masked is unreachable for the two task kinds that generate almost all decisions.
- **There is no general duplicate-launch protection.** `bin/fm-spawn.sh:938-971` refuses to launch when an existing endpoint for the task id is alive, and its body is backend-generic (`fm_backend_agent_alive`, `:966`) - but it is called from exactly one site, `:1004`, inside three nested conditions: herdr backend, the optional `config/herdr-presentation-spaces` flag present, and a pre-existing presentation journal. I checked the backend adapters too: their "duplicate check" comments (`bin/backends/zellij.sh:312-315`, `bin/backends/cmux.sh:82-84`) are *label-uniqueness* checks, not liveness, and the only other live-agent refusal (`bin/backends/herdr.sh:1300-1302`) sits on the same presentation path. So on tmux, zellij, cmux, orca, and default herdr, nothing stops a second agent being spawned onto a task that already has a live one. The per-task lock at `:439-444` is released at process exit, so it serializes concurrent spawns only.
- **The recovery playbook is 49 lines of prose with zero enforcement, and its central work-preservation rule depends on the brief being immutable.** `.agents/skills/stuck-crewmate-recovery/SKILL.md:32-35` requires relaunch into the *existing* worktree with the same brief plus a progress note. That only holds because `bin/fm-brief.sh:106` refuses to overwrite and `bin/fm-spawn.sh:821` requires the brief to exist. A port that regenerates briefs on relaunch breaks both ends at once.
- **`quota-balanced` can only ever discriminate between claude and codex, and the ceiling is upstream.** `bin/fm-dispatch-select.sh:174-178` hardcodes general-window ids for those two and returns `[]` for everything else, so a `pi`, `grok`, or `opencode` candidate drops out and the selector takes its logged `fallback: true` branch (`:210-214`). A live read of `quota-axi --json` on this machine shows why that is mostly not firstmate's fault: pi and opencode are not providers at all, and grok is a provider with zero windows. Port the selector; treat the vendor table as the extension point rather than rewriting the logic.

---

## 1. Mechanism inventory

### A. The brief contract

**B1. Brief scaffold generator and its three variants**
`bin/fm-brief.sh`, whole file, dispatched by `KIND` at `:86-87` and branched at `:117` (secondmate), `:252` (scout), `:369` (ship). Writes exactly one file, `data/<task-id>/brief.md`, under the active `FM_HOME`. Refuses to overwrite an existing brief (`:106`). Depends on `fm-marker-lib.sh` and `fm-classify-lib.sh` (sourced `:71-74`) and, for ship only, `bin/fm-project-mode.sh` (`:305`, `:308`). Everything downstream depends on it: `fm-spawn.sh:821` will not launch without the file, and the launch template `cat`s it as the agent's opening prompt (`fm-spawn.sh:488-511`).

Header `:2-8` states the reason: firstmate fills the `{TASK}` placeholder afterward and may adjust sections when a task genuinely deviates. `AGENTS.md` section 11 calls the scaffold "a safety contract, not a suggestion."

**B2. Status-append protocol - the actual wire between worker and supervisor**
`bin/fm-brief.sh:390-402` (ship), `:271-280` (scout), `:171-180` (secondmate). Four parts, all load-bearing:

1. *The command form.* `echo "{state}: {one short line}" >> <path>` - append-only, one line, verb-colon-note.
2. *The path.* Not discovered by the worker; compiled in at scaffold time. `STATUS_FILE=$(shell_quote "$STATE/$ID.status")` at `:115`, interpolated into each brief. The worker is never told how to derive it and never needs `FM_HOME`.
3. *The verb set.* `working, needs-decision, blocked, <paused-verb>, done, failed` (`:392`, `:273`, `:173`). The paused verb is not a literal - it is `PAUSED_VERB` resolved at `:75` from `FM_CLASSIFY_PAUSED_VERB`, defaulting to `FM_CLASSIFY_PAUSED_VERB_DEFAULT` in `fm-classify-lib.sh:58`. One definition, two readers (brief and watcher), so the vocabulary cannot drift.
4. *The sparseness rule.* "Each append wakes firstmate, so report sparingly" (`:393`, `:274`). Stated as the reason, not a style preference: every line is a wake event.

Consumed by `bin/fm-classify-lib.sh` - `FM_CLASSIFY_CAPTAIN_RE_DEFAULT` at `:45` is `done:|needs-decision:|blocked:|failed:|PR ready|checks green|ready in branch|merged`. Note what is absent: `working:` and the paused verb are deliberately excluded (comment `:40-44` and `:53-55`) so a nonterminal line never escalates.

**B3. Keyed open/resolved contract, and its partial delivery**
Grammar owned by `bin/fm-classify-lib.sh:143-189`: an optional `[key=<slug>]` token sits between the verb and the colon; `_fm_decision_key` (`:175-188`) returns `default` when absent and rejects a slug containing anything outside `[A-Za-z0-9._-]`. Two folds consume it: `status_open_decisions` (`:210-234`) for needs-decision/blocked, and `_fm_status_open_activities_stream` (`:246-270`) for working/paused phases. Both are pure reads of a status file with **no task-kind discrimination**.

The reason is stated at `:145-152`: read last-event-wins, a later unrelated terminal line silently masks a still-open decision. Keys are the fix.

The brief only half-delivers it. The secondmate charter teaches the full cycle - open with `working [key=<work-slug>]:`, reuse the key on the terminal event, and append `resolved [key=...]` when a phase ends without another reportable state (`:177-179`). The ship (`:406`) and scout (`:284`) briefs teach only the closing half. Consequence, from `_fm_decision_drop` (`:189-204`) plus the re-add at `:224-227`: two unkeyed `needs-decision:` lines both resolve to key `default`, the second drops the first's record, and the first decision disappears from the durable open set.

**B4. Declared-external-wait split (`paused:` vs `blocked:`)**
`bin/fm-brief.sh:399-402` (ship), `:277-280` (scout), `:174` (secondmate). Defined by consequence, not by mood: `paused:` means firstmate "leaves your idle pane alone and rechecks it on a long cadence instead of treating it as a possible wedge"; `blocked:` means stuck and needing help. Backed by `fm-classify-lib.sh:47-57`, which states the same contract from the reader's side and explains why the paused verb is kept out of the captain-relevant set. This is the only thing that keeps a legitimately idle worker from being escalated as a wedge.

**B5. Ship-brief worktree-isolation self-assertion**
`bin/fm-brief.sh:380-382`. The worker runs `pwd -P` and `git rev-parse --show-toplevel`, both must resolve to the disposable task worktree; `:381` explicitly states the path check is authoritative and that `--git-dir`/`--git-common-dir` do not prove you are outside the primary checkout. On failure the worker must stop **before branching or committing** and append `blocked: launched in primary checkout, not an isolated worktree`.

This is the second of two layers. The first is `validate_spawn_worktree` (report 06, M12, `fm-spawn.sh:916-932`), which runs host-side before launch. `AGENTS.md` section 8 requires both: "The spawn assertion and generated ship brief must both enforce that project work starts in an isolated disposable worktree." Scout briefs do **not** carry it (verified: absent from the `:253-297` heredoc) - a scout worktree is declared scratch, so the failure mode it guards against is not present.

**B6. Commit discipline and the clean-tree-at-done clause**
`bin/fm-brief.sh:242-250`, shared verbatim by ship and scout (interpolated at `:411` and `:289`). Four lines are workflow advice; the fifth is a safety interlock: "Never report `done` with a dirty working tree: uncommitted work is not landed work, and firstmate cleanup will refuse it" (`:248`). That refusal is report 06's M2 branch B (`fm-teardown.sh:769-773`). The brief is the only place a worker learns the teardown predicate exists.

**B7. Delivery-mode shaping of setup, rule 1, and definition of done**
`bin/fm-brief.sh:302-367`. Mode comes from `bin/fm-project-mode.sh "$REPO"` (`:304-306`), yolo is read and deliberately discarded (`:303`: yolo governs firstmate's approval behavior, not the worker's instructions). Three shapes:

- `direct-PR` (`:317-329`): rule 1 forbids pushing the default branch and merging any PR; done is "push your branch and open a PR with gh-axi, then append `done: PR {url}`"; explicitly "Do NOT run /no-mistakes."
- `local-only` (`:330-342`): rule 1 forbids any remote push and any PR; requires the branch stay a clean fast-forward onto the default branch; done is `done: ready in branch fm/<id>`.
- `no-mistakes`, the default (`:343-366`): adds a `no-mistakes doctor` / `init` setup step; done is `done: {summary}`, after which firstmate instructs the worker to run `/no-mistakes`; the terminal event is `done: PR {url} checks green` at the CI-ready return point, explicitly "do not wait for it to keep monitoring in the background until merge" (`:363`).

Those three done-strings are read back by `AGENTS.md` section 7, and the substrings `checks green` and `ready in branch` are literal alternatives in `fm-classify-lib.sh:45`.

**B8. no-mistakes gate-driving rules embedded in the ship brief**
`bin/fm-brief.sh:354-361`. Three rules the worker must follow inside a pipeline run: do not hand-edit, commit, or fix findings while a run is active (the pipeline applies every fix); ask-user findings escalate to firstmate rather than being answered; avoid `--yes`. The brief defers all mechanics to no-mistakes' own version-matched help (`:355`) rather than restating flags.

**B9. Shared-daemon protection**
`bin/fm-brief.sh:407-409` (ship), `:285-287` (scout). "Never stop, restart, or update the shared `no-mistakes` daemon - it is one instance serving every lane/home, so restarting it kills other lanes' in-flight pipeline runs." On any daemon error the worker appends `blocked:` and stops. The reason is stated, and it is cross-tenant: a single worker's cleanup instinct can destroy unrelated work.

**B10. Herdr lifecycle declaration - a gate that is loud in both states**
`bin/fm-brief.sh:210-240`. With `--herdr-lab`, a six-point hard contract routing every lifecycle action through `bin/fm-herdr-lab.sh` with a named non-`default` session, an EXIT trap installed before provisioning, and a forbidden-command list (`:226`). Without it, the brief carries an explicit "NOT ENABLED" section (`:233-239`) stating the scaffold cannot inspect the `{TASK}` text filled in later and instructing the agent to stop and regenerate rather than add Herdr commands by hand.

The design note at header `:26-28` is the interesting part: the flag must be explicit *because* `{TASK}` is filled after scaffolding and the repo string cannot identify this repo. The absent branch is not a default - it is a declaration, so an omitted contract can never be silent.

**B11. Project-key sidecar - deterministic identity propagation**
`bin/fm-brief.sh:208` writes the caller-supplied repo name verbatim to `data/<id>/project-key`. Read back by `fm-spawn.sh:853-858` as the default project key. Reason, stated at `fm-brief.sh:199-207`: the registry key can differ from the clone-directory basename, and without the sidecar `fm-spawn` would re-derive a basename and silently fall through to `no-mistakes` mode plus the wrong herdr Fleet workspace. One manual naming, two consumers, no drift.

**B12. Project-memory section**
`bin/fm-brief.sh:413-418`, ship only. Has the worker run `bin/fm-ensure-agents-md.sh .` when a project `AGENTS.md`/`CLAUDE.md` exists or durable knowledge was produced, records only widely-useful knowledge, prefers pointers over copied detail, and adds the `## Maintaining this file` self-governance section when missing. Explicitly proportionate: skip for trivial tasks (`:418`). This exists because firstmate itself may never write a project's `AGENTS.md` (`AGENTS.md` section 6) - the brief is the only channel.

**B13. Scout scratch-and-report contract**
`bin/fm-brief.sh:261-266` and `:291-297`. "The worktree is your laboratory... all of it is discarded at teardown. The report is the only thing that survives, so anything worth keeping must be in it." Rule 1 forbids pushing and PRs entirely (`:268`); rule 2 permits writing outside the worktree only for the report and the status file (`:269`). Done requires passing `decision-hold-lifecycle`'s shared completion gate (`:294`) before appending `done:`. A promotion hint at `:296` tells the scout to say so in the report if work should ship, without authorizing it.

**B14. Secondmate charter: marked return channel and idle-by-default**
`bin/fm-brief.sh:138-188`. Two mechanisms worth separating from the vocabulary around them:

- *Marked return channel* (`:159-167`). An incoming message tagged with `FM_FROMFIRST_LABEL` followed by U+2063 INVISIBLE SEPARATOR is a relayed request whose answer must go to the status path, not the chat; an unmarked message is direct human intervention and stays conversational. `bin/fm-marker-lib.sh:42-47` defines `FM_FROMFIRST_LABEL='[fm-from-firstmate]'`, `FM_FROMFIRST_SEPARATOR=$'\xE2\x81\xA3'`, and their concatenation. The untypability comes from U+2063 (`fm-marker-lib.sh:28-31, :50-51`), not from the label text.
- *Idle-by-default* (`:183-187`). "An empty queue is a healthy resting state, not a cue to invent work: never spawn a survey, audit, or any self-directed 'find work' task on your own initiative." Restated twice (`:155-157` and `:186`).

### B. Harness and runtime dispatch

**H1. Own-harness detection, two layers**
`bin/fm-harness.sh:30-65`. Layer 1 is environment markers: `CLAUDECODE=1` -> claude, `PI_CODING_AGENT=true` -> pi, `GROK_AGENT=1` -> grok (`:32-37`). Layer 2 walks up to eight parent processes matching `ps -o comm=` against `*claude*`, `*codex*`, `*opencode*`, `*grok*`, and exact `pi`; for a bare `node`/`python` it re-matches against `ps -o args=` (`:39-63`). Falls through to `unknown`. Note the asymmetry: **codex and opencode have no environment marker** and are detectable only by ancestry. The header at `:22` asks that each newly verified marker be recorded there.

**H2. Crew-harness resolution - no allowlist**
`bin/fm-harness.sh:69-73`. Reads `config/crew-harness`, strips all whitespace with `tr -d '[:space:]'`, and echoes it. Empty or the literal `default` mirrors `detect_own`. There is **no validation against the verified list here** - any string passes through.

**H3. Secondmate harness/model/effort line**
`bin/fm-harness.sh:78-137`. `secondmate_line` takes the first non-empty, non-comment, whitespace-trimmed line of `config/secondmate-harness`; `secondmate_field` splits it into `<harness> [<model>] [<effort>]`. `resolve_secondmate` falls back `config/secondmate-harness` -> `config/crew-harness` -> own. Model and effort are gated: they resolve to empty unless the harness token itself is present and not `default` (`:126`, `:135`), so a harness-only file behaves exactly as before the knob existed. Header `:19-20` states the reason model/effort live only here: `config/crew-harness` stays a bare adapter name and is never parsed for a model.

Re-resolved on every spawn (`fm-spawn.sh:535-537`, `:561-575`), which is what makes a secondmate's pin survive recovery, `/updatefirstmate`, and restarts.

**H4. Verified-harness enforcement is emergent from `launch_template`**
At the time of this scout, `bin/fm-spawn.sh:475-514` defined launch commands for claude, codex, opencode, pi, and grok, returning 1 for anything else (`:512`). That return was the only allowlist in the system: `:546` and `:551` turned it into `exit 1`. Both messages named the escape hatch ("pass a raw launch command to use an unverified adapter"). OMP was verified later; current adapter facts are owned by `.agents/skills/harness-adapters/SKILL.md`.

Precision matters here. `AGENTS.md` section 4 says "If configured harness data names an unverified adapter, report it and fall back only to a verified adapter rather than launching it." The *script* refuses; it does not fall back. Reading the sentence as an instruction to the agent layer (refuse at the script, then the agent picks a verified adapter) reconciles them. The porting risk is structural rather than contradictory: because the guard is "does a template exist," adding a template for an unverified adapter deletes the guard with no separate allowlist to update.

**H5. Raw-launch escape hatch**
`bin/fm-spawn.sh:516-524`. Any non-flag argument containing whitespace is treated as a literal launch command. The harness name is recovered for metadata by taking the first word that is not a `VAR=value` prefix (`:521-523`). Two later gates constrain it: opted-in PR identity refuses raw launches outright (`:878-881`), and the secondmate model/effort tokens apply only when no explicit harness or raw command was supplied (`:561`).

**H6. Dispatch-consultation backstop**
`bin/fm-spawn.sh:539-542` (single) and `:390-392` (batch). When `config/crew-dispatch.json` exists, a crewmate or scout spawn with no explicit harness is refused: "config/crew-dispatch.json is active - pass an explicit harness resolved from the dispatch rules (the consultation backstop, so the rules are never silently skipped)." Secondmate spawns are exempt (`:535`).

The mechanism is presence-gated, and `docs/configuration.md:228-229` states the consequence deliberately: because the gate is file-presence, *every* fallback path - no rule matched, validation error, missing `jq` - still has to pass an explicit harness until the file is fixed or removed. It forces the agent to have looked, without the shell needing to understand what it looked at.

**H7. Dispatch profile resolution (`fm-dispatch-select.sh`)**
`bin/fm-dispatch-select.sh:102-135`. Accepts a full rule object with `use`, a single profile object, or an ordered profile array (`:102-108`), normalizes to an array, and emits one compact JSON profile carrying `harness` plus `model`/`effort` when they are strings (`clean`, `:115-118`). With no `select`, or an unrecognized one, it logs and prints the first element (`:130-136`).

The critical scoping fact is stated in `docs/configuration.md:193`: "The shell scripts do not match those rules; firstmate chooses the best matching rule with judgment." Rule matching against natural-language `when` clauses is agent judgment. `fm-dispatch-select.sh` only picks among the profiles inside an already-chosen rule. `.agents/skills/harness-adapters/SKILL.md:92` reinforces it: "Do not make the shell scripts parse or match natural-language dispatch rules."

**H8. `quota-balanced` selector**
`bin/fm-dispatch-select.sh:138-234`. Runs `quota-axi --json` (or a `--quota-json` fixture), takes per candidate vendor the minimum `percentRemaining` across that vendor's *general* windows only, excluding `kind == "model"` windows (`:186-190`), and picks the higher minimum. Ties break to the lowest array index (`:203-204`). A stale-but-cached candidate wins over a fresh one only when its minimum is at least `STALE_CLEAR_MARGIN` (default 20) higher (`:218-220`). Every failure mode - `quota-axi` missing, non-zero exit, unparseable JSON, unreadable fixture, no usable candidate - logs to stderr and prints the first array element (`:139-164`, `:210-214`, `:225-229`). Header `:26-27` states the invariant: "quota trouble never blocks dispatch."

`general_ids` (`:174-178`) knows `five_hour`/`seven_day` for claude and `five_hour`/`weekly` for codex, and returns `[]` for everything else, which makes `candidate_metric` emit `empty` (`:183-184`). A rule whose `use` array contains only pi, grok, or opencode profiles therefore always takes the fallback branch.

A read-only `quota-axi --json` on this machine (2026-07-26) shows what the vendor table is up against. Providers reported: `claude` (`five_hour`, `seven_day`, `model:fable`), `codex` (`five_hour`, `model:codex_bengalfox:5h`), `cursor` (no windows), `copilot` (`chat`, `completions`, `premium_interactions`), `grok` (no windows). **pi and opencode are not providers at all**, and grok reports nothing, so `general_ids` returning `[]` for them is not an oversight - there is no data to balance. Two further observations from the same read: codex currently exposes no `weekly` window, so its minimum rests on `five_hour` alone; and claude's `state.status` is `stale` while codex's is `fresh`, which is exactly the branch at `:218-220` - claude's min of 51 does not clear codex's fresh 99 by the 20-point margin, so codex wins. The `model:` exclusion at `:188` is also doing real work here: both vendors carry a model-scoped window that would otherwise skew the minimum.

**H9. Effort vocabulary and the omit-rather-than-guess rule**
Two stages. `bin/fm-spawn.sh:214-217` validates `--effort` against a closed set - `low|medium|high|xhigh|max` - and exits 1 otherwise. Then `effort_flag_for_harness` (`:608-643`) maps it per adapter and **emits nothing when the harness does not accept that value**: claude gets `--effort` for all five; codex gets `-c model_reasoning_effort="..."` for low..xhigh and drops `max`; grok gets `--reasoning-effort` for low..high and drops `xhigh` and `max`; pi gets `--thinking` for all five; opencode gets no effort flag at all. Each case carries its verified-version rationale inline (`:614-616`, `:620-623`, `:627-628`, `:633-635`). The requested value is still recorded in meta (`docs/configuration.md:222`, `harness-adapters/SKILL.md:112-113`).

`model_flag_for_harness` (`:598-606`) is the asymmetric counterpart: it passes any non-empty, non-`default` model straight through for all five adapters with no validation. A typo'd model reaches the CLI and fails at launch.

**H10. Effort-choice policy**
`.agents/skills/harness-adapters/SKILL.md:93-100`. Precedence: explicit per-task captain instruction, then any applicable standing dispatch profile or secondmate pin, then a generic fallback - `low` for well-understood bounded work, `xhigh` for ambiguous investigation or design, intermediate levels proportional to complexity, uncertainty, blast radius, or open-ended reasoning. Two hard rules: cap at the adapter's highest supported non-`max` level rather than silently omitting an intended effort (`:99`), and never select `max` from the fallback - only on explicit captain preference (`:100`). `AGENTS.md` section 4 adds "Do not add model-specific versions of that policy." This is prose in a skill; no code enforces it.

### C. Spawn fail-closed validations, in execution order

`bin/fm-spawn.sh`. Ordered as the script reaches them. Everything below aborts the launch.

| # | Check | Line | Refuses when |
|---|---|---|---|
| 1 | `fm_refuse_if_gate_agent` | `:155` | The caller is a no-mistakes gate agent. Placed before any fleet mutation and before argument parsing; comment `:153-154` states the reason. |
| 2 | Flag well-formedness | `:204-209` | A trailing `--flag` has no value, or `--harness`/`--model`/`--effort`/`--backend`/`--project-key` was passed empty. |
| 3 | `--project-key` vs `--secondmate` | `:213` | Both present. Rejected rather than ignored (`:210-212`: a secondmate's identity is its home). |
| 4 | Effort vocabulary | `:214-217` | `--effort` outside `low\|medium\|high\|xhigh\|max`. |
| 5 | `fm_backend_validate_spawn` | `:231` | The resolved backend is unknown or not spawn-capable. |
| 6 | `fm_backend_source` | `:232` | The backend adapter cannot be loaded. |
| 7 | Backend/kind compatibility | `:233-240` | `orca` or `cmux` with `--secondmate`. |
| 8 | `fm_backend_orca_runtime_check` | `:241-243` | Orca runtime unavailable. |
| 9 | Batch: `--project-key` | `:389` | Passed to a batch (heterogeneous clones where key equals basename). |
| 10 | Batch: dispatch backstop | `:390-392` | `config/crew-dispatch.json` exists and no shared `--harness`. |
| 11 | Batch: pair syntax | `:415` | An argument is not `id=repo`. Sets `rc=2` and continues rather than aborting the batch. |
| 12 | Batch: `--secondmate` | `:426` | Batch mode with `--secondmate`. |
| 13 | `fm_task_id_creation_valid` | `:438` | Malformed task id. Exits 2. |
| 14 | Per-task spawn lock | `:439-444` | Another spawn is concurrently creating the same id. Held from before backend creation through metadata publication (header `:66-68`). |
| 15 | Dispatch backstop (single) | `:539-542` | No explicit harness while `config/crew-dispatch.json` exists, for ship/scout. |
| 16 | `launch_template` lookup | `:546`, `:551` | No template for the resolved harness - the unverified-adapter guard (H4). |
| 17 | Secondmate home identity | `:653`, `:682-724` | Home missing; is `/`; is the active firstmate home; is the firstmate repo; is inside either; is an ancestor of either; lacks the `.fm-secondmate-home` marker; the marker names a different secondmate id; lacks `AGENTS.md`; lacks `bin/`. Ten separate refusals. |
| 18 | Secondmate project containment | `:735-755` | A named project directory does not resolve inside the secondmate home, is not a directory, or resolves inside the active firstmate home or the firstmate repo. |
| 19 | Home resolution | `:771` | No firstmate home supplied or registered for the id. |
| 20 | Secondmate inheritance lock | `:795-804` | State dir uncreatable, lock unresolvable, or lock unacquirable. |
| 21 | Brief exists | `:821` | `data/<id>/brief.md` (or a secondmate `data/charter.md`) is absent. |
| 22 | PR identity profile valid | `:873-876` | `fm-project-mode.sh --pr-identity` fails. "refusing to create a worker". |
| 23 | Raw launch vs PR identity | `:878-881` | A raw launch command with an opted-in PR identity. |
| 24 | PR identity preflight | `:882-886` | Broker preflight fails. Message states "no worker/backend was created". |
| 25 | Binding shape | `:891-895` | Preflight returned a binding whose identity, repo, branch (`fm/<id>`), or base is unsafe. |
| 26 | Duplicate-launch guard | `:938-971`, called `:1004` | An existing endpoint for the id is alive or uninspectable. See the scope caveat below. |
| 27 | `validate_spawn_worktree` (orca) | `:1116` | The orca-created path is not an isolated worktree root. Report 06, M12. |
| 28 | `treehouse get` timeout | `:1206-1209` | The pane did not settle into a non-primary path within 60 polls. Requires two consecutive agreeing reads (`:1193-1196`). Report 06, M13. |
| 29 | `validate_spawn_worktree` (treehouse) | `:1211` | Same four conditions as #27, for every non-orca ship/scout spawn. |
| 30 | Metadata publication | `:1399-1401` | `state/<id>.meta` cannot be written. |

Ordering properties worth preserving: the gate-agent refusal is first, before parsing; argument validation completes before any I/O; the PR-identity preflight is explicitly host-owned and runs *before* any backend or worktree mutation (`:862-864`), so its failure leaves nothing to clean up; the worktree isolation assertion runs after worktree allocation but before the agent is launched into it.

**Coverage check on the isolation assertion.** `validate_spawn_worktree` has exactly two call sites. `:1116` covers orca. `:1211` sits inside `if [ "$KIND" != secondmate ] && [ "$BACKEND" != orca ]` (`:1164`), the same guard that issues `treehouse get`. Every ship/scout spawn therefore passes through one of the two. Secondmate spawns skip it correctly - a secondmate home is a firstmate home, not a worktree, and validation #17-18 covers it instead. No gap.

**Scope caveat on the duplicate-launch guard.** `herdr_projection_existing_meta_allows_flat` (`:938-971`) is backend-generic in its body: it reads the backend and target from meta, special-cases herdr pane state (`:946-964`), and otherwise calls `fm_backend_agent_alive` (`:966`), refusing on any state other than positively dead. Its single call site `:1004` is nested inside `BACKEND = herdr` (`:989`), `KIND != secondmate && -f "$CONFIG/herdr-presentation-spaces"` (`:999`), and "a presentation journal already exists" (`:1000`). Its stderr strings ("refusing duplicate launch while its herdr presentation journal is quarantined") confirm it was written for that path.

I extended the check into the backend layer rather than leaving it inferred. Every "duplicate check" in the adapters is about *label collision*, not a live agent: `bin/backends/zellij.sh:312-315` ("Zellij does NOT enforce tab-name uniqueness itself... so the duplicate check is ours") and `bin/backends/cmux.sh:82-84` ("NO title uniqueness enforcement for workspaces OR surfaces/tabs... The duplicate check below is ours"). The only other refusal that inspects agent liveness is `fm_backend_herdr_projection_recovery_allows_flat` (`bin/backends/herdr.sh:1300-1302`, "a live or unknown pane refuses a duplicate launch"), called from `fm-spawn.sh:1007-1008` on the same presentation branch. `fm_backend_agent_alive` itself (`bin/fm-backend.sh:721`) is a plain liveness reader with no refusal semantics, deliberately returning `dead` only on a confident read so "a momentary read glitch can never duplicate a" worker (`:719`). Conclusion, verified rather than inferred: **no general duplicate-launch precondition exists**, and the capability that would provide one is already written and needs only to be lifted out of the herdr branch.

### D. Stuck-agent recovery

**R1. Dead-endpoint reconciliation for an ordinary direct report**
`.agents/skills/stuck-crewmate-recovery/SKILL.md:19-35`. Scoped to `kind=ship` and `kind=scout`; `kind=secondmate` routes to `secondmate-provisioning` (`:21-22`). Entry conditions are enumerated in `AGENTS.md` section 13 and repeated at `SKILL.md:14`: digest reports the endpoint dead or metadata has no window, stale wake, looping pane, repeated confusion, a question the brief already answers, unresponsive worker, or a failed steer.

**R2. Presence is not proof - the authoritative-run rule**
`SKILL.md:24-26`. "Treat the digest's endpoint result as a presence signal, not proof that the task's work or validation run is gone." Read targeted current state with `bin/fm-crew-state.sh <id>` before deciding to relaunch. A no-mistakes run matched to the crew's branch and current code **remains authoritative even when the endpoint is dead** - handle a terminal or parked run through the normal lifecycle and keep supervising an active one instead of creating a duplicate worker. This is the single strongest anti-duplication rule in the subsystem, and it is prose.

**R3. Evidence gathering, bounded to this home's records**
`SKILL.md:28-31`. Inspect only the task's recorded backend and worktree inventory: `treehouse status` for treehouse-backed tmux/herdr/zellij/cmux tasks, recorded `orca_worktree_id=` and `terminal=` for orca. "Do not sweep another home's endpoints or infer ownership from a matching window label." `AGENTS.md` section 5 states the same boundary. The harness for the target is read from `harness=` in `state/<id>.meta` (`SKILL.md:18`).

**R4. Work preservation during relaunch**
`SKILL.md:32-35`, the part that actually prevents work loss. Four requirements before relaunch: prove no live agent still owns the recorded task; prove the existing worktree remains available; preserve its uncommitted changes and commits; keep the same task identity and relaunch the recorded harness *in that existing worktree* with the same brief plus a concise progress note. Then the prohibition and its reason: "Do not use a fresh generic spawn while the recorded worktree is unaccounted for, because allocating another worktree can split one task across two copies." Terminal fallback at `:35`: if worktree or ownership cannot be reconciled safely, leave all state intact and report failed or blocked with the conflicting evidence.

**R5. Live-endpoint escalation ladder**
`SKILL.md:37-49`. Five ordered steps: peek the pane; answer a brief-answered question in one line via `fm-send.sh`; interrupt with the adapter's interrupt key and redirect with one corrective line; exit and relaunch with the same brief plus a `progress so far` note; on a second failed relaunch write `failed` to the backlog and report the plain failure, preserved work, and consequence under `AGENTS.md` section 9's translation rules.

Two judgment calls are stated explicitly. Wedging is defined (`:46`: "looping, unresponsive, repeating the same obstacle, or truly dead"), and one non-symptom is called out: "A low context reading is not wedging; modern harnesses auto-compact and keep going" (`:47`). Relaunch is characterized as cheap precisely because "the worktree and commits persist" (`:48`) - the same invariant R4 protects.

**R6. Bounded pane capture (`fm-peek.sh`)**
`bin/fm-peek.sh`, 25 lines. Resolves an exact task id, a legacy `fm-<id>` label via `state/<id>.meta`, or an explicit backend target through `fm_backend_resolve_selector` (`:19`), determines the backend and expected label from the selector (`:22-23`), and calls `fm_backend_capture` with a default of 40 lines (`:20`, `:25`). Header and implementation agree. One side effect the header does not mention: `:16` runs `bin/fm-guard.sh || true`, so a diagnostic peek also triggers the watcher-liveness guard.

---

## 2. Verified versus prose-sourced

### Verified - I read the implementing code

- The brief compiles the status path in at scaffold time and the worker never derives it (`fm-brief.sh:115` and its interpolation into all three variants).
- The six-verb set appears in all three brief variants, and the paused verb is a shared constant rather than a literal (`fm-brief.sh:75`, `:173`, `:273`, `:392`; `fm-classify-lib.sh:58`).
- `FM_CLASSIFY_CAPTAIN_RE_DEFAULT` contains `done:|needs-decision:|blocked:|failed:` plus the free-text tokens `PR ready`, `checks green`, `ready in branch`, `merged`, and excludes `working:` and `paused:` (`fm-classify-lib.sh:45`).
- The keyed-fold parsers are pure single-file reads with no task-kind discrimination (`fm-classify-lib.sh:175-188`, `:210-234`, `:246-270`).
- Ship and scout briefs teach closing a key but never opening one; only the secondmate charter teaches opening (`fm-brief.sh:406`, `:284` vs `:177-179`).
- `fm-brief.sh` refuses to overwrite an existing brief (`:106`), and `fm-spawn.sh` refuses to launch without one (`:821`).
- The `--herdr-lab`-absent branch emits a loud declaration rather than nothing (`fm-brief.sh:233-239`).
- The project-key sidecar is written by brief and read by spawn with the documented precedence (`fm-brief.sh:208`; `fm-spawn.sh:850-859`).
- `resolve_crew` performs no allowlist validation (`fm-harness.sh:69-73`).
- The only verified-adapter allowlist is `launch_template`'s case statement (`fm-spawn.sh:475-514`), enforced at `:546` and `:551`.
- Environment-marker detection exists for claude, pi, and grok only; codex and opencode rely on process ancestry (`fm-harness.sh:32-63`).
- Secondmate model/effort tokens resolve to empty unless the harness token is present and not `default` (`fm-harness.sh:123-137`).
- `fm-dispatch-select.sh` resolves an already-matched rule and never matches `when` clauses (`:102-135`; no matching code exists in the file).
- `general_ids` covers claude and codex only, and any other harness produces `empty` (`fm-dispatch-select.sh:174-184`).
- Every `quota-balanced` failure path degrades to the first array element with a stderr log (`:139-164`, `:210-214`, `:225-229`).
- Effort is validated against a closed vocabulary then per-harness filtered with omission rather than substitution (`fm-spawn.sh:214-217`, `:608-643`).
- Model is passed through with no validation for all five adapters (`fm-spawn.sh:598-606`).
- All 30 spawn refusals in section 1C, at the lines given.
- `validate_spawn_worktree` has exactly two call sites and together they cover every ship/scout spawn (`fm-spawn.sh:1116`, `:1164`, `:1211`).
- The duplicate-launch guard is called from exactly one site inside three nested conditions (`fm-spawn.sh:938-971`, `:989`, `:999-1004`), and no backend adapter supplies a general substitute - the adapters' duplicate checks are label-uniqueness only (`bin/backends/zellij.sh:312-315`, `bin/backends/cmux.sh:82-84`), and the one other liveness-based refusal is on the same presentation path (`bin/backends/herdr.sh:1300-1302`).
- `fm_backend_agent_alive` is a liveness reader with no refusal semantics, returning `dead` only on a confident read (`bin/fm-backend.sh:700`, `:719-726`).
- `quota-axi` on this machine reports providers claude, codex, cursor, copilot, and grok; pi and opencode are absent and grok has zero windows (live read, 2026-07-26).
- `fm_refuse_if_gate_agent` runs before argument parsing and before any mutation (`fm-spawn.sh:155`).
- `fm-peek.sh`'s header matches its implementation, and it additionally runs the watcher guard (`:16`).
- `FM_FROMFIRST_LABEL` is `[fm-from-firstmate]` and the untypability derives from the appended U+2063 (`fm-marker-lib.sh:42-47`).

### Prose-sourced - read in a doc, header, or skill; implementation not independently checked

- The effort-choice fallback policy: `low` for bounded work, `xhigh` for ambiguity, never `max` from the fallback (`harness-adapters/SKILL.md:93-100`). No code implements it; it is a rule for the agent.
- The per-adapter verified-version claims in the launch-profile-axes table (Claude Code 2.1.196, codex-cli 0.142.1, grok 0.2.99, Pi 0.80.6, opencode 1.17.6) (`harness-adapters/SKILL.md:106-110`). I read the flag mapping in `fm-spawn.sh` and confirmed it matches the table, but did not re-run any CLI.
- Bootstrap's `jq` validation of `config/crew-dispatch.json` and the `CREW_DISPATCH: invalid ...` diagnostic wording (`docs/configuration.md:226-227`). I did not read `fm-bootstrap.sh`.
- The entire `stuck-crewmate-recovery` playbook. It is a skill document; nothing in `bin/` enforces any of it, which is itself a verified fact - I checked, and no script references the skill or its steps.
- `fm-project-mode.sh`'s behavior on an unknown key (falls back to `no-mistakes` and warns visibly). Asserted by `fm-spawn.sh:841-842` and `fm-brief.sh` header; I did not read that script.
- `fm_backend_agent_alive`, `fm_backend_validate_spawn`, `fm_backend_capture`, and the treehouse-backed backend adapters generally. I read their call sites, not `bin/fm-backend.sh` or `bin/backends/*`.
- `bin/fm-herdr-lab.sh`'s refuse-default re-checks and fleet-state tripwire, described in the generated Herdr contract (`fm-brief.sh:224`, `:227-228`).

### Where prose and code disagree

**AGENTS.md section 11 over-claims the keyed contract.** It says "Status appends are sparse supervisor-actionable events, not routine progress; `bin/fm-classify-lib.sh` owns keyed open and resolved semantics." The library does own the semantics, and the sparseness rule does reach every brief - but the *opening* half of the keyed protocol is delivered only to secondmates. Ship and scout workers, which produce the overwhelming majority of decisions and phase changes, are instructed only in the closing half. Verified against `fm-brief.sh:406`, `:284`, `:177-179` and the kind-agnostic folds at `fm-classify-lib.sh:210-234`, `:246-270`.

**`fm-spawn.sh` header `:98-99` is accurate; the header's neighbors set an expectation the duplicate-launch guard does not meet.** The isolation claim ("Ship/scout spawns refuse to launch unless the resolved task path is a real git worktree root distinct from the primary project checkout") is fully implemented. But header `:52` describes the presentation path as allowing a flat launch "only after duplicate-agent risk is independently absent," which reads as though duplicate-agent risk is assessed generally. It is assessed only on that path.

**`AGENTS.md` section 4's fallback wording versus the script's refusal** is reconcilable rather than wrong - see H4 - but a porter reading only section 4 would expect the script to substitute a verified adapter. It exits instead.

---

## 3. Verdict per mechanism

Our side, checked for this column: the Themis persona at `/Users/ed/.claude/commands/Themis.md` (symlink to `Atlas/Config/claude/.claude/commands/Themis.md`), the Pi extension at `/Users/ed/Developer/Atlas/Config/packages/pi-themis/extensions/themis.ts`, and the OMP package at `/Users/ed/Developer/Atlas/Config/packages/omp-themis/` including `skills/themis-pm/SKILL.md`.

| Mechanism | Verdict | Why | Already have it? |
|---|---|---|---|
| B1 brief scaffold generator | **copy** | Deterministic generation with no model judgment; it is the only thing that makes workers emit the events supervision reads. | **absent** - `Themis.md:62-87` describes brief *content* per role in prose ("bake the required commands into each agent's brief") but there is no generator and no file contract. |
| B2 status-append protocol | **copy** | The wire protocol. Volatile per-task status stays local and gitignored, exactly the decided constraint. Reword the surrounding prose, keep the verbs and the append form byte-stable. | **absent** - `Themis.md:35` has agents report to Themis conversationally; `pi-themis/extensions/themis.ts:85-86` defines a per-turn status *block* for Ed, not a machine-readable worker event stream. |
| B3 keyed open/resolved contract | **rebuild** | We want the capability - concurrent decisions must not mask each other - but the donor's brief only half-teaches it, so copying the brief text propagates the defect. Build the full open/close cycle into whatever instructions our workers get. | **absent** - no decision-tracking mechanism on our side at any of the three surfaces. |
| B4 paused vs blocked split | **copy** | Deterministic classification, no model judgment, and it is the only thing preventing a legitimately idle worker being escalated as wedged. | **absent** - `Themis.md:47` describes heartbeat check-ins to "prevent stales" with no notion of a declared wait. |
| B5 ship-brief isolation self-assertion | **copy** | Second layer over report 06's M12; costs nothing and catches the case where host-side allocation succeeded but the agent landed elsewhere. | **partial** - `Themis.md:65` mandates `/ce-worktree`, so isolation is attempted; nothing has the worker assert it. Same finding report 06 records for M12. |
| B6 commit discipline + clean-tree-at-done | **copy** | Directly couples to report 06's teardown predicate: the worker must know that a dirty tree blocks cleanup, or it reports done into a refusal. | **absent** - no commit-discipline or clean-tree requirement in the persona, Pi extension, or OMP skill. |
| B7 delivery-mode shaping | **rebuild** | We keep no-mistakes as an external CLI dependency, so the no-mistakes branch survives; the three-mode registry lookup assumes `data/projects.md`, which we do not have. Keep the shape, re-source the mode. | **partial** - `Themis.md:70-71` mandates review tooling per role but does not vary the definition of done by delivery path; no local-only or direct-PR distinction exists. |
| B8 no-mistakes gate-driving rules | **copy** | no-mistakes stays an external CLI dependency, and these three rules (do not hand-fix during a run, escalate ask-user, avoid `--yes`) are what keep a worker from duplicating pipeline ownership. | **absent** - `no-mistakes` is available as a skill on our side but nothing tells a dispatched worker how to behave inside a run. |
| B9 shared-daemon protection | **copy** | Cross-tenant safety for a dependency we are keeping. One worker restarting the daemon kills other lanes' in-flight runs. | **absent**. |
| B10 herdr lab declaration gate | **copy** | herdr is our only session backend, so a worker driving herdr lifecycle against the live fleet is now a *more* likely failure, not less. The both-branches-loud design is the transferable idea. | **absent** - `Themis.md:47-49` has Themis drive herdr directly and terminate agents and their herdr; no isolation contract for a worker that touches herdr itself. |
| B11 project-key sidecar | **strip** | Exists to reconcile `data/projects.md` registry keys with clone-directory basenames under firstmate's `projects/` layout, which we drop. | **absent**, correctly. |
| B12 project-memory section | **copy** | Matches our DOX contract almost exactly, including "pointers over copied detail." Cheap to port, and it is the only channel by which durable project knowledge reaches a repo when the coordinator never writes code. | **partial** - `Themis.md:95-102` and `omp-themis/skills/themis-pm/SKILL.md` give Themis full DOX ownership, but nothing instructs a *worker* to update the nearest `AGENTS.md` in its own pass. |
| B13 scout scratch-and-report contract | **copy** | Our explorer role is exactly this, and the "report is the only thing that survives" framing is what makes discarding the worktree safe. | **partial** - `Themis.md:76-87` specifies explorer report *content* in detail, but never states that the worktree is scratch or that the report is the sole survivor. |
| B14 secondmate charter | **strip** | A persistent isolated firstmate home is a second-tier delegation architecture we are not porting. | **absent**, correctly. The marked-return-channel idea (U+2063) is worth remembering separately if we ever add durable sub-coordinators. |
| H1 own-harness detection | **copy** | Generally useful and config-free; pure env markers plus process ancestry. The unknown-fallthrough is the right default. | **absent** - `Themis.md:53` says "whatever agent harness Themis is running in" is the default, but nothing detects it; the bridge check-in asks Ed instead. |
| H2 crew-harness resolution | **rebuild** | We want a configured default worker harness, but the donor's version reads `config/crew-harness` under `FM_HOME` and validates nothing. Keep the resolution chain, add the allowlist the donor lacks. | **partial** - `Themis.md:53-58` establishes host-harness-as-default plus a session-confirmed bridge, which is the same decision made conversationally rather than from config. |
| H3 secondmate harness/model/effort pin | **strip** | Serves the secondmate architecture we are dropping. | **absent**, correctly. |
| H4 verified-harness allowlist | **rebuild** | We need the guard, but "a launch template exists" is the wrong enforcement point - it deletes itself the moment someone adds a template. Make the allowlist explicit and separate from the template table. | **absent** - `Themis.md:55-58` names claude/pi/omp/codex as bridge options but has no verified list and no refusal path. |
| H5 raw-launch escape hatch | **copy** | Necessary for verifying a new adapter, and the donor already constrains it (refused under an opted-in PR identity, ignored for config-driven model/effort). | **absent**. |
| H6 dispatch-consultation backstop | **copy** | The best idea in this subsystem: a shell that cannot understand the rules still guarantees the agent consulted them, by refusing an unresolved harness whenever the rule file exists. Deterministic, model-judgment-free, and portable to any config format. | **absent** - `Themis.md:54-57` requires the bridge check-in "once per session, before the first dispatch," but nothing enforces it; a forgetful session dispatches anyway. |
| H7 dispatch profile resolution | **copy** | Small, self-contained, and it encodes the right split: natural-language matching is agent judgment, profile selection is deterministic code. Matches our decided constraint that classification stays deterministic. | **absent**. |
| H8 quota-balanced selector | **copy** | The logic is sound and the never-block-dispatch invariant matches our constraint that dispatch stays deterministic; the claude/codex-only ceiling turned out to be upstream (`quota-axi` does not track pi or opencode and reports no grok windows), so `general_ids` is an extension point to widen when the data exists, not a defect to rebuild around. | **absent**. |
| H9 effort vocabulary + per-harness mapping | **copy** | Deterministic, evidence-dated per adapter, and the omit-rather-than-guess rule is exactly right. Port the model-flag asymmetry as a fix, not a copy. | **absent** - no model or effort axis is expressed anywhere on our side. |
| H10 effort-choice policy | **copy** | Harness-agnostic prose that transfers verbatim once the captain noun is reworded. Its "do not add model-specific versions" clause is what keeps it from rotting. | **absent**. |
| C1-C30 spawn fail-closed validations | **rebuild** (as a set) | We need the discipline and the ordering. Roughly a third of the individual checks (#3, #7, #8, #17-20, #22-25) serve secondmates, orca/cmux, or the PR-identity broker, all of which we drop; the rest are general. | **absent** - `Themis.md` has no dispatch preconditions at all. |
| C1 gate-agent refusal (`:155`) | **rebuild** | Same capability - a validation agent must never spawn a worker - but the donor's predicate reads no-mistakes gate state we would re-source. Its *placement* (first line of executable code) is the copyable part. | **absent**. |
| C14 per-task spawn lock (`:439-444`) | **copy** | Volatile local state, gitignored, deterministic. Serializes concurrent same-id spawns across backends. | **absent**. |
| C26 duplicate-launch guard (`:938-971`) | **copy** (with the call site moved) | Verified that no general precondition exists anywhere in the donor, and the donor's body is already backend-generic - so this is a one-line promotion out of the herdr branch, not a rewrite. | **absent** - and `Themis.md:47` makes it more urgent: Themis "will then terminate the agent and its herdr" on a heartbeat judgment, with no check that the agent is the one recorded. |
| C21 brief-exists precondition (`:821`) | **copy** | One line, and it is half of what makes recovery-by-relaunch safe (see R4). | **absent**. |
| C30 metadata publication (`:1399-1401`) | **copy** | A launched agent with no durable record is unrecoverable; refusing the spawn is correct. | **absent** - no per-task durable record exists on our side. |
| R1 recovery entry conditions | **copy** | The trigger list (dead endpoint, no window, stale, looping, brief-answered question, unresponsive, failed steer) is harness-agnostic and complete. | **partial** - `Themis.md:47` has "a heartbeat check-in for each agent to prevent stales" - the trigger exists, the taxonomy does not. |
| R2 authoritative-run-outranks-dead-endpoint | **rebuild** | The principle is essential and general: a live external process matched to the work outranks a dead pane. The donor's instance reads no-mistakes run state via `fm-crew-state.sh`; we keep no-mistakes but would re-source the read. | **absent**. |
| R3 home-scoped evidence gathering | **copy** | "Never sweep a shared endpoint namespace for matching names" matters more under herdr-only, where all our agents share one server and tab labels are the tempting shortcut. | **absent** - `Themis.md:49` mandates `GH#<issue>-<role>` tab labels, which is exactly the matching-label inference this rule forbids as ownership proof. Labels are fine for humans, not for ownership. |
| R4 work preservation during relaunch | **copy** | The core anti-work-loss rule and it depends on nothing we dropped: prove no live owner, keep the same identity, relaunch into the *existing* worktree, never a fresh generic spawn while the worktree is unaccounted for. | **absent** - and directly contradicted by `Themis.md:47`'s terminate-on-completion-judgment, which report 06 already flags. |
| R5 live-endpoint escalation ladder | **copy** | Five ordered steps, cheapest first, with wedging defined and low-context explicitly excluded as a symptom. Harness-agnostic once the interrupt key comes from an adapter table. | **absent**. |
| R6 bounded pane capture | **copy** | Cheap diagnosis without dumping an entire pane; step 1 of the ladder depends on it. Under herdr-only this collapses to one backend. | **partial** - `Themis.md:47` says to "read their output" via the herdr CLI; the herdr skill provides pane reads, but nothing bounds them or resolves a task id to an endpoint. |

---

## 4. Coupling notes

**The brief and the classifier are one artifact split across two files.** `fm-brief.sh` writes the verbs; `fm-classify-lib.sh:45` matches them. Neither file mentions the other. Changing `done:` to `complete:` in the brief compiles cleanly, passes every test that only reads one file, and silently stops the supervisor seeing completions. The same applies to the free-text tokens: `checks green` and `ready in branch` appear both as literal brief output (`fm-brief.sh:363`, `:338`) and as regex alternatives (`fm-classify-lib.sh:45`). The paused verb is the one axis already done right - one constant, two readers.

**The status file path is a three-way contract.** `fm-brief.sh:115` writes `$STATE/$ID.status` into the brief; the watcher and daemon read the same path from their own `FM_HOME` resolution; teardown removes it. A port that lets workers discover their own status path, or that moves the file, breaks all three at once with no compile error.

**Brief immutability is load-bearing for recovery.** `fm-brief.sh:106` refuses to overwrite; `fm-spawn.sh:821` refuses to launch without one. Together they are what makes `SKILL.md:45`'s "relaunch with the same brief plus a `progress so far` note appended" work: the brief is a stable, appendable artifact that survives the agent. Making briefs regenerable on relaunch looks like a simplification and quietly deletes the recovery path's foundation.

**The project-key sidecar links brief generation to spawn identity.** `fm-brief.sh:208` writes it, `fm-spawn.sh:853-858` reads it, and if it is missing the spawn silently falls back to the clone basename - which resolves the wrong delivery mode and the wrong herdr Fleet workspace without erroring. The failure is silent by design (basename is correct in the common case), which makes it exactly the kind of coupling a porter drops as redundant.

**The dispatch backstop is presence-gated, not content-gated, on purpose.** `fm-spawn.sh:539` tests only `-f "$CONFIG/crew-dispatch.json"`. Do not "improve" this into a validity check: `docs/configuration.md:228-229` states that the presence gate is what forces every degraded path - unmatched rule, invalid JSON, missing `jq` - to still pass an explicit harness. A validity gate would turn a broken rules file into a silent bypass.

**`--herdr-lab` cannot be inferred and both branches must stay loud.** The scaffold runs before `{TASK}` is filled (`fm-brief.sh:26-28`), so no amount of cleverness lets the generator detect a Herdr-driving task. The unguarded branch's declaration text *is* the mechanism. Replacing it with silence, or with a runtime check, removes the only thing that surfaces the omission.

**Effort validation happens twice and the two stages are not interchangeable.** `fm-spawn.sh:214-217` rejects an out-of-vocabulary value outright; `:608-643` silently omits an in-vocabulary value the target adapter cannot accept. Collapsing them into one check either rejects legitimate cross-harness efforts or passes known-bad flags. The recorded-but-unflagged case (`effort=max` in meta, no flag emitted for grok) is deliberate traceability, not a bug.

**Two isolation layers, and only one of them is in this subsystem.** Report 06's M12 is host-side and runs before launch; B5 is agent-side and runs after. `AGENTS.md` section 8 requires both. They fail differently - M12 catches a bad allocation, B5 catches an agent that ended up somewhere else - so neither substitutes for the other.

**`fm-peek.sh` runs the watcher guard.** `:16` calls `fm-guard.sh || true`. Diagnosis is not side-effect-free. A port that treats peek as a pure read and calls it in a tight loop will hammer the guard.

**Ordering inside `fm-spawn.sh` is a safety property, not incidental.** Three cases: the gate-agent refusal precedes argument parsing so a forbidden caller cannot get far enough to mutate anything; the PR-identity preflight precedes all backend and worktree mutation (`:862-864`) so its failure leaves nothing to unwind; the per-task lock spans backend creation through metadata publication (header `:66-68`) so a crash cannot leave a live agent with no durable record. Reordering any of the three for readability breaks the property.

---

## 5. What I could not determine

- **Whether the missing keyed-open instruction for ship/scout briefs is a known gap or an oversight.** I found no comment, doc, or commit message addressing it. The consequence is verified; the intent is not. It is possible someone decided crewmate tasks are single-decision by design, but nothing in the code or docs says so, and `fm-brief.sh:406`'s conditional phrasing ("if you opened it with one") reads like it expects an opening instruction to exist somewhere.
- **How firstmate actually chooses among dispatch rules at intake.** `docs/configuration.md:193` says the agent matches natural-language `when` clauses "with judgment." I found no worked example beyond `docs/examples/crew-dispatch.json`, which I did not read. The quality of that judgment is unobservable from code, so I cannot say whether the profile system works well in practice or is mostly unused.
- **Whether `quota-axi` tracks pi, opencode, or a populated grok on any machine.** I resolved the local case with a read-only `quota-axi --json` (see H8): pi and opencode are absent from the provider list and grok reports zero windows here. What I cannot tell is whether grok's empty window set reflects an unauthenticated local account or a genuine upstream gap, and whether pi/opencode support is planned. That distinction decides whether widening `general_ids` is worth doing now or later.
- **The exact behavior of `fm-project-mode.sh` on an unknown key.** Two headers assert "falls back to no-mistakes and is visibly warned." I did not read the script, so both the fallback and the warning are prose-sourced. This matters for B7's rebuild: if the warning is silent in some path, a mis-keyed project ships through the wrong pipeline quietly.
- **Whether anything enforces the recovery playbook.** I checked that no script under `bin/` references `stuck-crewmate-recovery` or its steps, so it is prose. What I could not determine is whether the *harness-adapters* skill's interrupt and exit tables - which the playbook depends on at `SKILL.md:16` - are themselves accurate for all five adapters, since verifying them means driving live agents.
- **How much of the ship brief's no-mistakes section (B8) is still current.** `fm-brief.sh:355` deliberately defers to no-mistakes' own version-matched help rather than restating mechanics, which is good design but means I cannot check the brief against the tool. Report 05 covers no-mistakes; cross-read it before porting B8.
