# Native session-start adapters

AGENTS.md section 3 is the authoritative behavioral contract for session start.
The tracked native adapters inject one instruction and never run the digest, acquire the lock, perform bootstrap work, drain notifications, or arm supervision themselves.
The payload starts with U+2063 and the stable `FIRSTMATE_OP:` label, carries the current `session-start` protocol kind, and retains exactly ``Run `bin/fm-session-start.sh` now, exactly once, before executing any other instructions.`` as its body.
The Ahoy skill owns the rule that this marked operational input is never a captain-authored session boundary, including its narrow legacy compatibility cases.

## Shared wrapper and safety

`bin/fm-sessionstart-nudge.sh` is the single command every harness adapter invokes.
It sources `bin/fm-gate-refuse-lib.sh` and stays silent for a no-mistakes gate agent identified by `NO_MISTAKES_GATE` or a `.no-mistakes/repos/*.git` git-common-dir.
It shares `bin/fm-primary-scope-lib.sh` with `bin/fm-turnend-guard.sh`, so the hooks use one primary-detection owner.
The Guard Predicates section of [`turnend-guard.md`](turnend-guard.md#guard-predicates) owns marker validation, plain-checkout detection, and required Firstmate-shaped paths.

The nudge payload starts with U+2063 and the stable `FIRSTMATE_OP: ` label, carries the current `session-start` protocol kind, and retains exactly ``Run `bin/fm-session-start.sh` now, exactly once, before executing any other instructions.`` as its body.
The Ahoy skill owns the rule that this marked operational input is never a captain-authored session boundary, including its narrow legacy compatibility cases, and its own step 0 helm check is the fallback that protects a nudge-tier harness whose first command is a skill.

Before printing, the nudge wrapper reads `state/.lock` and walks at most eight parents from its own pid in its own separate, hard-coded loop, independent of `bin/fm-lock.sh`'s ancestry walk (`fm_harness_ancestry_pid()` in `bin/fm-session-lock-lib.sh`, which now walks up to sixteen parents and can extend past a claude-named match to a still-more-ancestral one) and of Pi's `lockOwnership()`.
If the lock names a live pid in that ancestry, session start already ran in this harness session and the wrapper stays silent.
Every ordinary transport path in both wrappers exits 0, including malformed state and adapter errors, because a Claude SessionStart exit 2 blocks session initialization.
The run wrapper's internal `--pi-prerequisite` mode uses silent exit 3 only for an intentional gate or scope stand-down, letting Pi distinguish ineligibility from an eligible empty native result without changing any harness hook's exit contract.
A lock another session holds and a truncated digest therefore surface as digest text, while broken GitHub auth surfaces through the deferred network result inline or as a wake; none becomes a refusal to open the session.

## Harness transports

| Harness | Tracked transport | Current compatibility |
| --- | --- | --- |
| Claude | `.claude/settings.json` registers `SessionStart` for `startup`, `resume`, and `clear`, excludes `compact`, and invokes the wrapper through `CLAUDE_PROJECT_DIR`. | Native stdout context injection is supported. |
| Codex | `.codex/hooks.json` anchors to the hook process working directory, verifies a Firstmate-shaped hook-bearing root, and executes the wrapper. | Native stdout context injection is supported. |
| OpenCode | `.opencode/plugins/fm-primary-sessionstart-nudge.js` listens for `session.created`, runs once per session id, and calls `client.session.promptAsync` only when the wrapper prints a nudge. | Interactive TUI delivery is supported; headless `opencode run` is intentionally fail-open because the process can exit before the queued turn. |
| Pi / pi-signed | `.pi/extensions/fm-primary-turnend-guard.ts` handles `session_start` reasons `startup`, `new`, and `resume`, then injects the wrapper output with `pi.sendMessage`. | The custom message reaches model context without racing an initial positional prompt. |
| OMP | The same tracked Pi-compatible extension is loaded through an explicit `-e` path and uses its `session_start` handler. | The compatible message transport is supported without claiming Pi auto-discovery. |
| Grok | `.grok/hooks/fm-primary-sessionstart-nudge.json` registers a project `SessionStart` hook and invokes the wrapper through inline-defaulted `${GROK_WORKSPACE_ROOT:-}`. | The project hook runs when the checkout is trusted, but Grok currently discards hook stdout from model context, so this path is intentionally fail-open. |

The OpenCode nudge runs only on `session.created`.
The watcher-arm and turn-end plugins run later on `session.idle`, and the guard lets the watcher coordinator act first, so the plugins do not race for one lifecycle event.

Grok's guaranteed-loading alternative is a global token-guarded hook like the pattern used by `bin/fm-spawn.sh`.
That alternative expands trust and writes outside this repository, so Firstmate never installs it or grants folder trust automatically.

## Regression coverage

`tests/fm-sessionstart-nudge.test.sh` proves the nudge wrapper's silence for both gate signals, an unmarked linked worktree, a missing state directory, and an already-owned lock, plus its exact U+2063 `FIRSTMATE_OP:`-prefixed, `session-start`-typed one-line output.
It separately proves the run wrapper's silence for the gate environment and an unmarked linked worktree, including the internal Pi prerequisite's explicit silent stand-down.
It proves the run wrapper's source routing end to end against a real `fm-session-start.sh`, including completion-gated `--reemit` selection, resume delegation, Pi CLI continuation classification, an unrecognized source falling through to the full digest, and bounded loud delivery of an oversized Pi digest.
The same portable suite proves provider exclusion until settlement, exactly-one execution and context delivery, interruption, process-tree retirement, two rapid replacements, stale completion, eligible empty output, spawn error, wrapper timeout output, truncation, ineligible stand-down, and compaction cancellation through the extension's public event surface.
`tests/fm-session-start.test.sh` proves the runtime bound through the forced pure-Bash fallback: a TERM-resistant digest that exceeds its budget is force-killed with its grandchild, still emits its completed stages, names the incomplete stage and every stage it never reached, leaves no completion proof, and exits 0.
`tests/fm-pi-primary-live-e2e.test.sh` and `tests/fm-opencode-primary-live-e2e.test.sh` exercise native startup paths with first-message and later-message Ahoy regressions.
`tests/fm-cursor-primary.test.sh` proves the Cursor adapter over real processes: `sessionStart` emits the whole digest as `additional_context` with a caller-supplied `--source`, stays silent in a child worktree, lets the run wrapper stand down on the Cursor-delivered duplicate, and keeps `preCompact` unregistered so the deferred surface cannot be reintroduced unnoticed.
`FM_CURSOR_PRIMARY_LIVE_E2E=1 tests/fm-cursor-primary-live-e2e.test.sh` proves the injected digest actually reaches model context in a real cursor-agent session.
`tests/fm-sessionstart-hook-live-e2e.test.sh` is the opt-in live guard for the Claude, Codex exec, and Pi run-tier adapters; it confirms each installed adapter in that suite invokes the run wrapper and delivers its output into context.
It verifies context-preserving reopen sources for those adapters and context-reset delivery wherever their tracked TUI surface is reachable.
Its separate `FM_PI_SESSIONSTART_RACE_LIVE_E2E=1` mode uses real Pi with an offline deterministic provider and a barrier-controlled `/new` digest, proving both an immediate prompt and a completed-before-prompt control make their first provider call with exactly one native startup context and no manual execution.
Cursor uses the separate primary live guard named above because its source-free `sessionStart` and stop-hook park are validated together.
`tests/fm-sessionstart-instruction-refresh-live-e2e.test.sh` is the separate opt-in real-Pi guard for a post-start AGENTS.md update followed by compaction.
`tests/fm-turnend-guard.test.sh`, `tests/fm-pi-watch-extension.test.sh`, and `tests/fm-daemon.test.sh` cover marked guard, monitoring, and away-mode delivery.

[`verification/supervision.md`](verification/supervision.md#native-session-start-delivery) records the active version-scoped transport evidence.
