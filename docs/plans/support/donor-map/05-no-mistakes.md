# Donor map 05 — no-mistakes integration

Scout report. Read-only pass over firstmate's no-mistakes interface. Per the assignment, `bin/fm-crew-state.sh`'s role as the supervision current-state oracle (run-step precedence, branch-plus-code-identity attribution) is out of scope and is only referenced where the no-mistakes *call surface* is inseparable from it.

Environment probed: `no-mistakes v1.40.3 (d873960)` at `/Users/ed/.no-mistakes/bin/no-mistakes`, symlinked from `~/.local/bin/no-mistakes`. All probes were `--help`, `--version`, and `strings` on the binary — no state change.

**Note on the assignment's scope pointer:** the referenced prior report `.agents/plans/2026-07-25-heartbeat-dissection-for-themis-persona.md` did not exist on disk during this scout. A repo-wide `find` for `*heartbeat-dissection*` returned nothing. I could not read it, so I deliberately kept my treatment of run-step precedence thin and flagged in §5 what may therefore be duplicated or missing.

---

## 1. Mechanism inventory

### M1 — Delivery-mode classification (`no-mistakes` | `direct-PR` | `local-only`)

The single parser that decides whether a project is gated at all. `bin/fm-project-mode.sh` reads a bracket token off a `data/projects.md` registry line and emits `"<mode> <yolo>"`.

- Where: `bin/fm-project-mode.sh:47-58` (header contract), `:100` (awk defaults), `:115-119` (bracket-token validation), `:135-136` (unknown project), `:174-175` (unknown mode).
- Depends on: `data/projects.md` existing and being parseable. Nothing else.
- Depended on by: `bin/fm-brief.sh:304-306` (brief shape), `bin/fm-spawn.sh` (records `mode=` into task meta, `:321`), `bin/fm-teardown.sh:153`, `bin/fm-home-seed.sh:772`.
- Why: stated at `:55-58` — an unknown/missing project or unknown mode **falls back to `no-mistakes off` and warns to stderr, so a typo never silently drops the gate**. Fail-closed toward more validation, not less.

### M2 — Project initialization as a no-mistakes project

A project only becomes gated by running `no-mistakes init` inside its clone, which creates a local bare gate repo, installs a post-receive hook, and adds a `no-mistakes` git remote.

- Where (prose owner): `.agents/skills/project-management/SKILL.md:56-58, 70-80`.
- Where (only code path that actually runs it): `bin/fm-home-seed.sh:770-790`, `initialize_no_mistakes_project`.
- Depends on: an `origin` remote (`no-mistakes init --help`: "Run this from inside a git repository that has an `origin` remote"), the `no-mistakes` binary on PATH, and the daemon.
- Depended on by: every `no-mistakes`-mode ship task.
- Why: the code carries a guard the prose does not. `fm-home-seed.sh:775-781` treats **presence of the `no-mistakes` git remote as the idempotent "already initialized" test**, and refuses with an error when the clone was not created by this seed pass (`created != 1`) — firstmate will not mutate a preexisting clone to initialize it. That is a project-write-boundary defense, not a convenience check.

### M3 — Version floor at bootstrap

`no-mistakes` older than 1.31.2 is reported as `MISSING:` at session start, blocking dispatch.

- Where: `bin/fm-bootstrap.sh:522-546` (`NO_MISTAKES_MIN_{MAJOR,MINOR,PATCH}` = 1/31/2, `no_mistakes_compatible`), `:829-830` (emit `MISSING:`), `:514` (membership in `COMMON_TOOLS`), `:486` (install command).
- Depends on: `no-mistakes --version` output shape.
- Depended on by: AGENTS.md §3's "do not dispatch until the required tools are present".
- Why: header at `:48-49` states an incompatible installed version reports MISSING like an absent one. The reason for *this* floor specifically is not stated anywhere I found.

### M4 — Worker-side no-mistakes contract, embedded in the generated brief

The mode-specific "Definition of done" block. For `no-mistakes` mode the brief instructs the worker to run `no-mistakes doctor` / `init` at setup, to drive gates rather than implement fixes, to escalate ask-user findings, to avoid `--yes`, and to stop at CI-green.

- Where: `bin/fm-brief.sh:343-366` (the `*)` case), plus shared rule 7 at `:285-287` (scout) and `:407-408` (ship).
- Depends on: M1 for the mode; the installed no-mistakes binary being self-documenting (`:355` explicitly delegates mechanics to `no-mistakes axi run --help` and the `help` lines in each `axi` response rather than restating flags).
- Depended on by: M5 (ownership), M7 (the exact `done:` string the oracle parses).
- Why: `:355` states the reason for the delegation — the binary's own help is "version-matched to the installed binary", so the brief cannot rot against a CLI upgrade. `:285-287`/`:407-408` state the daemon reason: one shared daemon serves every lane and home, so a restart kills other lanes' in-flight runs; a daemon error is a `blocked:` escalation, never a self-service restart.

### M5 — Ownership boundary: the worker owns every `axi run` / `axi respond`

- Where (prose): `AGENTS.md:276-277`, restated worker-side at `bin/fm-brief.sh:354-361`.
- Where (code): **nowhere.** An exhaustive grep across `bin/`, `.agents/`, `skills/`, `docs/`, and `AGENTS.md` for `axi run|axi respond|axi abort` finds only prose. The only `axi` invocations firstmate's own scripts make are `axi status` and `axi logs --step ci --run <id>`, both from `bin/fm-crew-state.sh` (`:458`, `:339`), both read-only.
- Depends on: agent compliance.
- Depended on by: the pipeline's single-driver assumption; `AGENTS.md:286` treats a worker that hand-edits/commits/aborts/restarts mid-run as "duplicating pipeline ownership".
- Why: not stated as a rationale beyond the ownership assertion itself. The adjacent verified constraint is that `axi run` without `--yes` **blocks synchronously** for the entire pipeline (`axi run --help`: "blocks until the first approval gate, CI-ready point, or final outcome"), so the process that started the run is the only one holding the return channel.

### M6 — Firstmate's read-only no-mistakes call surface

Three commands, all bounded, all in the crew worktree, all failure-tolerant.

- Where: `bin/fm-crew-state.sh:210-223` (`nm_run` wrapper), `:458` (`axi status`), `:382` (`runs --limit 200`), `:339` (`axi logs --step ci --run <id>`).
- Mechanics: `nm_run` `cd`s into the worktree, applies a 10 s timeout (`NM_TIMEOUT`, `:71-72`), discards stderr, and `|| true`s the exit status so a hung or absent CLI can never fail the oracle. Timeout portability is handled by a three-way probe at `:211-215`: `timeout`, else `gtimeout`, else a hand-rolled `perl` fork/setpgrp/alarm implementation, else no call at all.
- Output parsing: TOON scalars via `sed` (`nm_field`, `:227-229`), findings count via a `findings[N]` regex (`:231-233`), gate step rows via a comma-split regex on `awaiting_approval|fix_review` (`:234-245`).
- Depends on: `no-mistakes` on PATH (`:457` guards with `command -v`), and TOON output shape.
- Depended on by: the whole supervision loop, via `bin/fm-classify-lib.sh:321, 331` and `bin/fm-watch.sh:127, 900`.
- Why: stated at `:210` ("never fails the script") and `:455-456` (scouts and secondmates never drive a validation of their own worktree, so the lookup is skipped entirely for `kind != ship`).

### M7 — CI-green-versus-merged disambiguation via the ci step log tail

The highest-value and most fragile piece of the interface. For a repo where merge is left to a human, no-mistakes' `ci` step — and therefore top-level `status`/`outcome` — stays `running` for the whole CI-monitor phase, long after every GitHub check is green; it only reaches `outcome=passed` once the PR is merged or closed. `axi status`'s `steps[]` table renders both situations identically as `ci,running,...`.

- Where: `bin/fm-crew-state.sh:320-349` (`nm_ci_checks_state` + the incident header), `:295-318` (`nm_ci_step_status` / `nm_effective_ci_step_status`), `:545-559` (the `working -> done` override), `:563-578` (the corroborating status-log path via `log_reports_ci_ready`, `:287-293`).
- Mechanism: read the ci step's log tail via `axi logs`, grep for the **last** occurrence of a fixed marker set, and map green markers (`CI checks passed`, `no CI checks reported - still monitoring`) to `green`, red/pending markers to `not-ready`. Green flips supervision state from `working` to `done` with detail `checks green: PR ready for review (still monitoring for merge/close)`.
- Depends on: literal English log strings emitted by the no-mistakes ci step. This is a text contract against another program's log output, with no schema.
- Depended on by: `AGENTS.md:287` ("the worker reports the PR when CI first becomes green rather than waiting for merge monitoring to finish") and the whole "don't leave a green PR sitting" property.
- Why: stated at `:320-334` — this is the root cause of the "PR #252 incident (2026-07)", verified by the author against 360+ real run logs under `~/.no-mistakes/logs/*/ci.log`.

### M8 — Gate-agent fleet-lifecycle refusal (capability removal)

The hazard: a no-mistakes gate agent runs inside a firstmate checkout with a free shell, auto-loads firstmate's `AGENTS.md`, adopts the captain identity, sees crew "in flight", and reaches for `fm-spawn.sh`/`fm-send.sh`/`fm-teardown.sh`. Those entrypoints self-locate their home and never knew a gate context existed.

- Where: `bin/fm-gate-refuse-lib.sh:1-102`. Exit code constant `FM_GATE_REFUSE_EXIT=3` at `:64`. Detection `fm_is_gate_agent` at `:69-88`. Hard-exit wrapper `fm_refuse_if_gate_agent` at `:94-102`.
- Two independent signals, either refuses:
  1. `NO_MISTAKES_GATE` **set** (`:74` uses `${NO_MISTAKES_GATE+x}`, so an empty value still fires) — the durable env marker no-mistakes stamps into every gate agent; covers a relocated `NM_HOME`.
  2. `git rev-parse --git-common-dir` resolving under `*/.no-mistakes/repos/*.git` (`:78-86`) — the unspoofable backstop, derived from the checkout's real filesystem location. Its stated limit: the literal-path match only fires for the default `NM_HOME` (`~/.no-mistakes`).
- Call sites: `bin/fm-spawn.sh:149-155`, `bin/fm-send.sh:41-45`, `bin/fm-teardown.sh:105-117` — all source the lib at the top and call the refusal **before any fleet mutation**.
- Escape hatch: `FM_GATE_REFUSE_BYPASS=1` (`:71`) makes the guard a no-op. Exported by `tests/lib.sh:35` and `tests/herdr-test-safety.sh:11`, because firstmate's own suite runs *from* a gate worktree during its own validation and would otherwise refuse. `tests/fm-gate-refuse.test.sh` strips it explicitly (`env -u FM_GATE_REFUSE_BYPASS`, `:164, :240, :328`).
- Why: header `:6-17` — no-mistakes owns the *authority*-removal half (neutralize project instructions, stamp the env marker); this is the *capability*-removal half, "an enforceable script refusal, not a prose rule the neutralized agent would never read." It deliberately layers above no-mistakes' separately-shipping HEAD-continuity guard.

### M9 — Session-start nudge soft-suppression

Distinct from M8 and easy to mistake for a copy of it.

- Where: `bin/fm-sessionstart-nudge.sh:13-18`. It calls `fm_is_gate_agent "$FM_ROOT"` and on a positive reading does `exit 0` — **silent success**, not exit 3.
- Why: not stated in the file. The behavior is asserted by `tests/fm-sessionstart-nudge.test.sh:49, 64` ("gate env nudge" / "gate common-dir nudge" both `expect_silent_zero`). Structurally: a gate agent must not be nudged into running firstmate's session-start, but a *refusal* there would be noise, not safety, since the nudge mutates nothing.
- Also note the anchored form: `fm_is_gate_agent "$FM_ROOT"` passes an explicit anchor, while the three lifecycle entrypoints use the default `.` (current worktree). The optional-anchor parameter at `:69` exists for this caller.

### M10 — Trusted default-branch config authority (`disable_project_settings`)

The claim in `.no-mistakes.yaml:6-9` is that the setting is "Trusted-only: a pushed branch cannot turn this off, so it is honored only from the default-branch copy of this file." This is a **no-mistakes-side** mechanism; firstmate only supplies the config value.

- Where (firstmate's part): `.no-mistakes.yaml:10`, one line.
- Where (the enforcing implementation): the no-mistakes binary. Verified by symbol and message extraction from `/Users/ed/.no-mistakes/bin/no-mistakes` (v1.40.3):
  - Struct field `DisableProjectSettings` with tag `yaml:"disable_project_settings"`, alongside `AllowRepoCommands` / `yaml:"allow_repo_commands"`.
  - Functions `internal/daemon.loadTrustedRepoConfig` and `internal/daemon.assertGateTrustedConfigReadable`.
  - Fail-closed error strings, all prefixed `cannot evaluate disable_project_settings:` — "trusted default-branch commit %s is not readable", "trusted default-branch tree at %s is not readable", "trusted `.no-mistakes.yaml` at %s is present but unparseable", "…present but not readable", "repository has no known default branch to read trusted config from", and "failed to fetch or resolve trusted default branch %q (**refusing to run without reading the trusted config**)".
  - Default-branch sourcing of the *other* keys too: "repo commands/agent loaded from default branch, not pushed branch"; "trusted repo config: not present on default branch"; "trusted repo config: parse failed; commands/agent from pushed branch will be disabled"; "failed to fetch default branch into worktree; trusted config disabled (commands/agent from pushed branch will be dropped)".
  - The opt-out to that opt-out is itself trusted: "`allow_repo_commands` is enabled on the default branch: honoring commands/agent from pushed branch."
- **Hard dependency the firstmate comment does not mention:** setting `disable_project_settings` constrains which gate agent may run. The binary carries the refusal "gate agent %q does not neutralize the target repository's project agent-instruction files (AGENTS.md/CLAUDE.md); refusing to launch it in the target checkout. Only codex and claude have a verified neutralization knob (and only when it is not overridden by `agent_args_override`); set 'agent' to codex or claude in `~/.no-mistakes/config.yaml`."
- Why: `.no-mistakes.yaml:3-9` and `docs/architecture.md:121-127` — firstmate's own gate runs agents inside a checkout that contains the fleet-captain identity, so gate execution needs an authority boundary separate from ordinary worktree isolation.

### M11 — Lint/test command pinning for local == CI parity

- Where: `.no-mistakes.yaml:26-28` (`commands.lint: 'bin/fm-lint.sh'`, `commands.test: <inline tmux-guarded loop over tests/*.test.sh>`), implementation in `bin/fm-lint.sh:1-76`.
- Mechanism: `fm-lint.sh` is the single owner of the lint definition — file set, config, and a pinned ShellCheck version (`REQUIRED_SHELLCHECK=0.11.0`, `:42`) that it *asserts* against the resolved binary (`:64-68`) and exposes to CI via `--required-version` (`:49-52`). CI installs that exact version and runs the same script.
- Why: stated at `.no-mistakes.yaml:15-21` and `fm-lint.sh:11-26` — without a configured `commands.lint`, the gate's lint step never ran the deterministic `shellcheck bin/*.sh bin/backends/*.sh tests/*.sh` that CI runs, so info-level findings (e.g. SC2015) reached CI un-surfaced. Parity is asserted by `tests/fm-lint.test.sh`.
- Note the trust interaction with M10: because `commands` are loaded from the default branch unless `allow_repo_commands` is enabled there, a branch that edits `commands.lint` does not change what its own validation runs.

### M12 — Test evidence kept out of the repo

- Where: `.no-mistakes.yaml:31-33` (`test.evidence.store_in_repo: false`). Schema confirmed in the binary (`yaml:"evidence"`, `yaml:"store_in_repo"`).
- Why: stated at `:30` — "Keep test evidence out of this repo; it stays in a temp dir instead."

### M13 — Validation-state → supervision-state mapping

The deterministic table that turns a no-mistakes run into one of firstmate's seven supervision states.

- Where: `bin/fm-crew-state.sh:512-544` (full `axi status` path), `:496-502` (coarse `runs`-list path).
- Mapping (full path): `outcome=passed` → `done` ("PR merged/closed"); `outcome=checks-passed` → `done`; `outcome=failed|cancelled` → `failed`; any gate signal (`awaiting_agent`, `status=awaiting_approval|fix_review`, a `gate:` block) → `parked` with gate name and finding count, plus an `(ask-user: captain decision)` suffix when the TOON contains `ask-user` (`:532-534`); `status=ci|running|fixing` → `working`; `completed` → `done`.
- Depends on: M6's parsing, and on no-mistakes' status vocabulary.
- Depended on by: `AGENTS.md:284-285` and the escalation loop at `AGENTS.md:279-282`.
- Why: `AGENTS.md:284` states the reason — judge validation by the current-code-matched run step, not by shell liveness or the last status event.

### M14 — Mode-differentiated PR-ready signal

`no-mistakes` mode reports `done: PR <url> checks green`; `direct-PR` reports `done: PR <url>`.

- Where: emitted per-mode by `bin/fm-brief.sh:363` vs `:310`/`:313`; consumed by `bin/fm-crew-state.sh:287-293` (`log_reports_ci_ready`, which pattern-matches `*PR*"checks green"*`) and by `AGENTS.md:290-291`.
- Depends on: the brief and the oracle agreeing on a literal string. They are in two different files with no shared constant.
- Why: `fm-crew-state.sh:563-578` — the status-log claim of CI-green is used to *corroborate* the ci-log read (M7), so a green PR is surfaced even when the log-tail check is inconclusive, but is suppressed when the ci step is actively `fixing`.

### M15 — `--yes` prohibition

- Where: `bin/fm-brief.sh:361` ("Avoid `--yes`: the captain, not you, owns the ask-user decisions it would silently auto-resolve"), `AGENTS.md:281` ("forbid `--yes`").
- Why: confirmed exactly by the binary's own help. `axi run --help`: "With `--yes` it auto-resolves every gate (fixing actionable findings — **including ask-user findings, with no escalation** — then accepting the result)". `axi respond --help` carries the same flag with "auto-resolve every subsequent gate".
- Enforcement: prose only. No code inspects the worker's command line.

---

## 2. Verified versus prose-sourced

### Verified — I read the implementing code or probed the installed binary

1. Firstmate's own scripts invoke exactly three no-mistakes read commands — `axi status`, `axi logs --step ci --run <id>`, and top-level `runs --limit N` — all from `bin/fm-crew-state.sh` (`:458`, `:339`, `:382`). *(exhaustive grep for `axi run|axi respond|axi abort` across `bin/`, `.agents/`, `skills/`, `docs/`, `AGENTS.md`)*
2. Firstmate's scripts make exactly two state-changing no-mistakes calls: `no-mistakes --version` (`bin/fm-bootstrap.sh:533`, read-only in effect) and `no-mistakes init && no-mistakes doctor` (`bin/fm-home-seed.sh:786`, secondmate seeding only, guarded by remote-presence and created-by-us checks at `:775-781`).
3. The gate refusal fires on either signal and exits 3 (`bin/fm-gate-refuse-lib.sh:64, 74, 78-86, 94-102`), is wired into exactly `fm-spawn.sh:155`, `fm-send.sh:45`, `fm-teardown.sh:117`, and is bypassed by `FM_GATE_REFUSE_BYPASS=1` (`:71`).
4. The refusal is tested end-to-end, not just at the library level: `tests/fm-gate-refuse.test.sh` asserts refuse-on-marker, refuse-on-path-with-marker-unset, and no-regression for each of `fm-spawn`, `fm-send`, `fm-teardown` (`:200`, `:274`, `:358`), plus library-level cases including the empty-value marker (`:113`).
5. `fm-sessionstart-nudge.sh` uses the *detection* function with an explicit anchor and exits **0 silently**, not 3 (`:18`), asserted by `tests/fm-sessionstart-nudge.test.sh:49, 64`.
6. `disable_project_settings` is a real no-mistakes schema key evaluated from the **fetched default-branch tree**, and evaluation is fail-closed: the binary contains `loadTrustedRepoConfig`, `assertGateTrustedConfigReadable`, and six distinct `cannot evaluate disable_project_settings: …` errors including "refusing to run without reading the trusted config". *(symbol/string extraction from the v1.40.3 binary)*
7. The same default-branch trust covers `commands` and `agent`: "repo commands/agent loaded from default branch, not pushed branch"; a parse failure disables them rather than honoring the pushed copy; `allow_repo_commands` on the default branch is the only way to honor a pushed branch's commands. *(same source)*
8. Setting `disable_project_settings` constrains the gate agent: no-mistakes refuses to launch a gate agent with no verified AGENTS.md/CLAUDE.md neutralization knob, and only `codex` and `claude` have one. *(binary string, quoted in M10)*
9. `--yes` auto-resolves ask-user findings **with no escalation** — the brief's prohibition is grounded in the CLI's documented behavior, not folklore. *(`no-mistakes axi run --help`)*
10. `--intent` is **required to start a new run** on v1.40.3. *(`no-mistakes axi run --help`)*
11. `axi respond` takes `--action approve|fix|skip` (required), `--step`, `--findings <id,...>`, `--instructions`, `--add-finding`, `-y`. This matches `AGENTS.md:280`'s required decision shape field-for-field. *(`no-mistakes axi respond --help`)*
12. `AGENTS.md:285`'s state mapping is exactly what `bin/fm-crew-state.sh:512-544` implements. Prose and code agree.
13. `no-mistakes runs` is a top-level command, not an `axi` subcommand. *(`no-mistakes --help`)*
14. Unknown project or unknown mode falls back to `no-mistakes off` with a stderr warning (`bin/fm-project-mode.sh:135-136, 174-175`).
15. Delivery mode `no-mistakes` is the default when a registry line carries no bracket token (`bin/fm-project-mode.sh:19, 100`).
16. `bin/fm-lint.sh` hard-fails on a ShellCheck version mismatch (`:64-68`) — the CI-parity claim is enforced, not aspirational.
17. `.no-mistakes.yaml` is asserted by firstmate's own suite to parse and set `disable_project_settings: true` (`tests/fm-gate-refuse.test.sh:388`).
18. The ci-log-tail disambiguation reads a fixed set of English log markers and takes the **last** match (`bin/fm-crew-state.sh:341-348`), overriding `working` → `done` at `:550-553`.
19. Our side (all four named artifacts read in full): no no-mistakes integration, no delivery-mode concept, no dependency version check, no PR-ready signal, no CI or lint definition, and no deterministic state machine over any external tool's output. What exists is a persona-state flag, a model-authored per-turn status shape, a voice-oriented extractor for it, and a real tool-blocking hook with path allowlist and bash denylist. Pointers in the M3/M5/M8/M11/M13/M15 verdict cells above.

### Prose-sourced — asserted in a doc, comment, or header I did not independently check

1. **The ownership boundary is prose-only.** `AGENTS.md:276-277` and `fm-brief.sh:354-361` assert it; no code enforces it. See the correction below.
2. The shared-daemon prohibition (`fm-brief.sh:285-287, 407-408`) — that one daemon instance serves every lane and home and a restart kills other lanes' in-flight runs. Plausible and consistent with the single-socket strings in the binary, but I did not verify the daemon's multi-home behavior.
3. The relocated-`NM_HOME` limitation of signal 2 (`fm-gate-refuse-lib.sh:26-29`). The literal-path match is verified; that a relocated `NM_HOME` is therefore uncovered follows from the code but I did not test a relocated home.
4. That no-mistakes' HEAD-continuity guard is the adversarial/residual backstop layered *below* this refusal (`fm-gate-refuse-lib.sh:37-38, 52-53`). I found no HEAD-continuity implementation to check.
5. That the threat model is a *confused-not-adversarial* gate agent, which justifies `FM_GATE_REFUSE_BYPASS` not weakening the boundary (`fm-gate-refuse-lib.sh:46-54`). This is a judgment about attacker capability, not a checkable fact.
6. The claim at `fm-crew-state.sh:350-357` that bare `axi status` "reports the active-or-most-recent run for the CURRENT branch when one exists" and otherwise falls back to another branch's run "purely as informational display". The header calls this "verified empirically" by its author; I did not reproduce it.
7. The PR #252 log-marker inventory (`fm-crew-state.sh:326-334`), stated as verified against 360+ real ci logs on v1.32.2. I verified the *code* that greps for those markers; I did not verify that no-mistakes v1.40.3 still emits the same strings. See §4.
8. The rationale for the `>= 1.31.2` version floor (`fm-bootstrap.sh:522-524`). The constant is verified; no file states *why* that version.
9. `project-management/SKILL.md:56-58`'s remote requirements per mode. The `origin`-remote requirement for `no-mistakes` mode is corroborated by `no-mistakes init --help`; the direct-PR/local-only distinctions are prose.

### Where prose was wrong or stale

- **`fm-crew-state.sh:361` is stale.** It states, "Verified against the real installed CLI (v1.32.2): the `axi` surface exposes only abort/logs/respond/run/status." On the installed v1.40.3, `axi` exposes **abort, logs, respond, run, status, and `sync`**. The load-bearing part of the claim — that there is no runs-listing subcommand under `axi`, so the old code path was dead — still holds. But the enumeration is a version-pinned fact stated as a general one, and a porter reading it will assume a smaller surface than exists.
- **`.no-mistakes.yaml:4-5` lists an incomplete step set.** It names "review/fix/document/test/lint/pr/rebase/ci"; the binary's own `Valid steps:` string is "intent, rebase, review, test, document, lint, push, pr, ci". `intent` and `push` are missing, and there is no `fix` step (fixing is a *status*, not a step). Harmless as a comment; misleading as a spec.
- **`.no-mistakes.yaml`'s trusted-only comment is correct but incomplete.** It says a pushed branch cannot turn `disable_project_settings` off. Verified. What it omits is that the same trust boundary applies to `commands` — so the `commands.lint`/`commands.test` pins immediately below it are *also* default-branch-only, and a branch cannot change its own lint/test commands either. That is arguably the more useful half of the guarantee for a porter, and it is nowhere in the repo's prose.
- **`AGENTS.md:280`'s "exact response command" is now under-specified.** It requires firstmate to name "the decision key, step, action, affected finding IDs, instructions where needed, and exact response command" — that maps cleanly onto `axi respond`'s flags. But `AGENTS.md` and `fm-brief.sh` never mention `--intent`, which v1.40.3 makes **required to start a run**. The brief's delegation to `axi run --help` (`fm-brief.sh:355`) is what saves it: a worker that reads the help gets the flag. A port that hard-codes the command instead of delegating will break here.

---

## 3. Verdict per mechanism

| Mechanism | Verdict | Why | Already have it? |
|---|---|---|---|
| M1 Delivery-mode classification | **rebuild** | Classification stays deterministic and we keep no-mistakes as an external CLI, so we need the three-way mode with the same fail-toward-gated default — but the donor's registry-line parser assumes `data/projects.md` and the fleet-display/`+yolo` tokens we are not porting. | **absent** — no delivery-mode concept anywhere on our side. `Themis.md` mentions a PR only at `:69`; `pi-themis`/`omp-themis` have no mode notion. |
| M2 Project initialization | **copy** | no-mistakes stays an external CLI dependency, and the init procedure plus the "refuse to mutate a preexisting clone" guard are CLI-shaped, not fleet-shaped. | **absent** — no `no-mistakes` reference in `Themis.md`, `pi-themis/extensions/themis.ts`, or either `themis-pm/SKILL.md`. |
| M3 Version floor at bootstrap | **copy** | no-mistakes and treehouse stay external CLI dependencies on `$PATH`; a version floor is how a decided external dependency stays honest across upgrades. Re-pin the floor to the version we actually target. | **absent** — checked: neither `package.json` declares a runtime dependency or a script, no `.github/workflows/` exists in `Atlas/Config`, and neither extension probes a binary. The nearest thing is a prose availability check (`Themis.md:110`, "confirm `codegraph` (MCP + CLI) is available") with no version comparison. |
| M4 Worker brief no-mistakes contract | **rebuild** | We keep no-mistakes but drop the fleet-captain identity, and the donor's brief is generated by `fm-brief.sh` around a crewmate/captain frame. The *content* is portable; the generator is not. | **partial** — `Themis.md:64-67` defines a Worker role with mandatory commands (`/ce-worktree`, `/ce-work`, `/codegraph`), which is the same slot. It has no validation-gate contract in it. |
| M5 Ownership boundary (worker owns run/respond) | **rebuild** | Verified as **asserted only**, and the brief warns this class of rule "will be violated by our port". Deterministic enforcement is the decided posture everywhere else in this subsystem; a sentence is not it. | **partial** — the *rule* is absent, but the *enforcement mechanism* already exists and is the obvious home for it: both extensions register a `tool_call` hook that returns `{block, reason}` (`themis.ts:236-256`, `main.ts:296-310`) with a bash denylist (`themis.ts:46-59`, `main.ts:90-103`). Neither denylist mentions `no-mistakes`, so today a Themis session could run `axi respond` unimpeded. |
| M6 Read-only call surface (`axi status`/`logs`/`runs`) | **copy** | Deterministic classification with no model judgment; bounded, side-effect-free, and independent of every dropped backend. The three-way timeout probe is worth keeping verbatim on macOS. | **absent** — no no-mistakes calls on our side at all. |
| M7 CI-green-vs-merged log-tail disambiguation | **copy** | This is the single most expensive-to-rediscover fact in the subsystem (it cost a production incident) and it is orthogonal to everything we dropped. Copy it *and* re-verify the markers against our installed version. | **absent.** |
| M8 Gate-agent fleet-lifecycle refusal | **rebuild** | The *hazard* survives the port only if our repo still carries agent-orchestration instructions a gate agent could adopt — which it does. Signal 1 (`NO_MISTAKES_GATE`) is generic and copyable; the three call sites are firstmate lifecycle entrypoints the persona drop removes. | **partial** — gate-context detection itself is absent (grepped both extensions for `NO_MISTAKES` case-insensitively: no hits). But the *pattern* — an enforceable block at a chokepoint rather than a prose rule — is already implemented in both extensions' `tool_call` hooks and denylists (same pointers as M5), including a git-mutation denylist (`themis.ts:48`, `main.ts:92`). Port the signals into that hook rather than building a new guard layer. |
| M9 Session-start nudge soft-suppression | **strip** | *Verdict rests on an assumption not in the decided set:* that we are not porting firstmate's session-start nudge. Nothing in the decided constraints drops it. If we do port a nudge, this flips to `copy` — and the detect-and-no-op-vs-detect-and-refuse distinction becomes load-bearing. | **absent** — neither extension registers a session-start nudge; the `session_start` hooks (`themis.ts:222-229`, `main.ts:282-289`) only restore persona state. |
| M10 Trusted default-branch config authority | **copy** | It is no-mistakes' own behavior, and we keep no-mistakes — so we get it for free by shipping the one-line config. Copy the setting; rewrite the comment to state the verified boundary and the codex/claude gate-agent constraint. | **absent** — no `.no-mistakes.yaml` in any of our packages. |
| M11 Lint/test command pinning | **rebuild** | The pattern is constraint-neutral and worth keeping, but the donor's `commands.test` hard-requires `tmux` on `$PATH` (`.no-mistakes.yaml:28`) and tmux is a decided drop, so the value cannot be copied. Keep the single-owner-script shape; write our own commands. | **absent** — checked: no `.github/workflows/` in `Atlas/Config`, no `scripts` block in either `package.json`, and no lint/test recipe in the `justfile` (recipes are all stow/manifest provisioning). `Atlas/Config/tests/` does hold `install-skills.test.sh`, `lavish-project-removal.test.sh`, and `tests/omp/`, so there is a suite to pin — just no runner and no gate to pin it to yet. |
| M12 Test evidence out of repo | **copy** | Two lines, no firstmate coupling, and consistent with the decided rule that volatile artifacts stay out of the tree. | **absent.** |
| M13 Validation-state → supervision-state mapping | **copy** | Classification stays deterministic with no model judgment in any current-state path — this table *is* that guarantee for the validation surface, and its vocabulary is pure no-mistakes. | **partial**, and the partial is the problem. Our side has a status vocabulary and a status extractor, but both are model-authored prose: the per-turn shape `Phase/Completed/In flight/Blocked/Next` is dictated in the injected system prompt (`themis.ts:85-91`, `main.ts:134-140`), and `extractSpokenStatus` (`themis.ts:105-123`, `main.ts:164-181`) regexes Themis's *own last assistant message* for that shape — for voice output, not supervision. The only persisted state is the persona flag `ThemisState {active, item, startedAt}` (`themis.ts:10-14, 144-148`, `main.ts:10-14, 205-207`). So there is a status surface to hang this on, but it is exactly the model-judgment path the decided constraint rules out; the mapping must land beside it, not inside it. |
| M14 Mode-differentiated PR-ready signal | **rebuild** | Classification stays deterministic — and "is this PR ready" currently rides on an untyped string a model was asked to type into a log, matched by regex in a second file. Keep the distinction, give the signal one typed owner. | **absent** — no PR-ready signal of any kind; `Themis.md:69` mentions a PR only as a reviewer's input. |
| M15 `--yes` prohibition | **copy** | The persona is Themis reporting to Ed, and `--yes` verifiably auto-resolves ask-user findings *with no escalation* — it silently removes Ed from the decisions the persona exists to route to him. | **absent** — checked both denylists (`themis.ts:46-59`, `main.ts:90-103`); neither mentions `no-mistakes`, so nothing today would stop a `--yes` run. |

**Cross-cutting "already have it" finding.** Our side has *zero* no-mistakes integration. Grep for `no-mistakes|axi ` (and separately, case-insensitively, for `NO_MISTAKES`) across `~/.claude/commands/Themis.md` (→ `Atlas/Config/claude/.claude/commands/Themis.md`), `Atlas/Config/packages/pi-themis/**`, and `Atlas/Config/packages/omp-themis/**` returns nothing. I then read all four artifacts in full — `Themis.md`, `pi-themis/extensions/themis.ts`, `pi-themis/skills/themis-pm/SKILL.md`, `omp-themis/src/main.ts` (plus `omp-themis/skills/themis-pm/SKILL.md` and both `package.json`s) — because several `absent` cells assert something a `no-mistakes` grep could never have shown. Everything in this subsystem is a net addition.

**The most useful thing our side already has is the wrong-shaped ancestor of two donor mechanisms.** Both extensions implement deterministic, non-prose capability removal at a tool chokepoint: a `tool_call` hook returning `{block, reason}`, a path allowlist restricting writes to markdown and `.agents/**`, and a bash denylist over git mutation, dependency changes, `rm -rf`, in-place shell edits, and non-markdown redirection (`themis.ts:40-59, 236-256`; `main.ts:60-103, 296-310`, which additionally guards `ast_edit` and mutating `lsp` actions). That is precisely the pattern `fm-gate-refuse-lib.sh:14-17` argues for — "an enforceable script refusal, not a prose rule the neutralized agent would never read" — already built, already load-bearing, and pointed at a different target. M5, M8, and M15 should all land in that hook rather than as new prose or a new guard layer.

There is also a **direct conflict** worth surfacing before the port, not after. `Themis.md:69-74` defines a Reviewer role that MUST run `/pr-review-toolkit:review-pr`, `/ce-code-review`, a cross-vendor adversarial pass, and `ce-testing-reviewer` on a worker's PR; `Themis.md:42` requires RedTeam adversarial validation of every claim; and both extensions inject "Use RedTeam/adversarial validation for material claims before accepting completion" into the system prompt every turn (`themis.ts:73`, `main.ts:117`). The donor's operating contract forbids exactly this shape when no-mistakes is the delivery path — `AGENTS.md:255-259`: "The selected delivery path owns its own rigor. When no-mistakes is selected, no-mistakes alone owns review, fixes, tests, documentation, push, PR, and CI; otherwise follow the faster path without adding an independent reviewer. Never hold work outside no-mistakes for a manual clean verdict, stack serial manual reviews, or infer authority for one from security, architecture, or risk alone." Adopting M1 without resolving this leaves two contradictory review authorities in the same repo, one of them injected on every turn. This is a decision for Ed, not something a porter should silently pick.

---

## 4. Coupling notes

**Text contracts against another program's output.** Three separate places parse no-mistakes output with regex against no schema: TOON scalar/table parsing (`fm-crew-state.sh:227-245`), ci-log English markers (`:341-348`), and run-list row parsing (`:380-418`). All three break silently on a no-mistakes output change — `nm_run` swallows stderr and returns empty (`:210-223`), so a broken parse degrades to "no run attributed" and falls through to the pane/log path rather than erroring. That is deliberate resilience, and it is also why a regression here is invisible until someone notices a PR sitting green. **Any port must re-verify the ci-log markers against the version it ships against** — the donor's list was verified on v1.32.2 and the installed binary is v1.40.3.

**The literal `checks green` string spans two files with no shared constant.** `fm-brief.sh:363` writes it into the worker's instructions; `fm-crew-state.sh:290` pattern-matches it. Change one and the corroboration path (M14/M7) silently stops corroborating. Give it one owner in the port.

**`fm_is_gate_agent` has two callers with two different contracts.** The three lifecycle entrypoints call `fm_refuse_if_gate_agent` (hard `exit 3`); `fm-sessionstart-nudge.sh:18` calls the bare predicate and exits 0. A porter who "simplifies" these into one helper will either make the nudge noisy or make the lifecycle guard non-fatal. The header at `fm-gate-refuse-lib.sh:58-60` states the reason the refusal is an exit rather than a return: there is no safe way to continue a fleet mutation from a gate context.

**`FM_GATE_REFUSE_BYPASS` looks like a hole and is load-bearing.** Without it, firstmate's own test suite cannot run under its own gate, because the gate runs the suite *from* a gate worktree — both signals fire. Removing it does not harden anything; it breaks self-validation. Any port that keeps M8 and has a self-validating test suite inherits this exact problem.

**`disable_project_settings` constrains the gate agent choice.** Per M10, no-mistakes refuses to launch a gate agent lacking a verified AGENTS.md/CLAUDE.md neutralization knob — only `codex` and `claude`, and only when `agent_args_override` does not override it. If our port configures a different gate agent in `~/.no-mistakes/config.yaml` while keeping `disable_project_settings: true`, the pipeline fails before the first step. This is not mentioned anywhere in firstmate's docs.

**`commands` are default-branch-only.** Because the trusted-config boundary covers `commands` as well as `disable_project_settings` (M10 §7), a branch cannot change what its own validation runs. Practical consequence for the port: the first commit that introduces `commands.lint` gets validated *without* it. Only after it lands on the default branch does the gate start using it.

**Mode resolution and identity must not drift.** `fm-project-mode.sh` is keyed on the registry **key**, not the clone directory basename (`:11-16`), and `fm-spawn.sh:12-17` warns that re-deriving a basename "silently falls through to no-mistakes". Falling through to *more* validation is the safe direction, but a port that resolves mode from a path instead of an explicit key will gate projects it did not mean to gate.

**Scouts and secondmates deliberately skip the lookup.** `fm-crew-state.sh:455-457` guards the entire no-mistakes path behind `KIND = ship`. If a port lets an investigation task reach the run lookup, it will attribute some other branch's run to a task that has none.

---

## 5. What I could not determine

- **Whether the assignment's scope carve-out actually landed.** The referenced prior report does not exist at the given path or anywhere in the repo. I kept my run-step precedence coverage thin on that assumption; if that report was never written, M13's mapping table and M6's attribution guard may be the only record of them and should be re-checked for completeness.
- **Whether no-mistakes v1.40.3 still emits the ci-log markers M7 greps for.** I read the grep and the incident header; I did not run a pipeline or read a real `~/.no-mistakes/logs/*/ci.log`. Confirming this requires either an actual run or reading log files that may not exist on this machine. This is the single highest-risk unverified item in the port.
- **The exact semantics of `disable_project_settings` beyond the trust boundary.** I verified where the value is read from and that reading is fail-closed. I did *not* verify what neutralization it performs on the gate agent (which flag it passes to codex/claude, whether it also suppresses skills or MCP config). That behavior is inside the binary with no string I could pin it to.
- **`allow_repo_commands` interaction with `disable_project_settings`.** Both are trusted-config keys and the "commands/agent" phrasing groups them, but I could not determine whether enabling `allow_repo_commands` would also let a pushed branch supply an `agent` that lacks a neutralization knob.
- **The `>= 1.31.2` floor's rationale.** No file states it, and I did not diff no-mistakes release notes.
- **Whether the shared-daemon claim is true.** `fm-brief.sh:285-287` asserts one instance serves every lane and home. The binary has a single IPC socket string and a `--force` refusal when active runs are in progress, which is consistent — but I did not verify the multi-home claim, and it drives a hard "never restart it" rule that a port would inherit blind.
- **Whether `fm-crew-state.sh`'s `axi sync` omission matters.** v1.40.3 adds `axi sync` (and top-level `no-mistakes sync`) for guarded branch synchronization, with a substantial set of divergence/custody messages in the binary. Firstmate uses neither. I could not determine whether that is a deliberate choice, a gap predating the subcommand, or something the worker-side `/no-mistakes` skill handles on its own.
