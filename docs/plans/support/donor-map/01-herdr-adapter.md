<!-- markdownlint-disable MD013 -->

# Donor map 01: Herdr adapter code

## 0. Headline

- Strip the entire optional presentation-space subsystem: it occupies roughly 800 lines, has no task authority, and exists only to decorate the donor's dropped layout model (`bin/backends/herdr.sh:284-766`, `bin/backends/herdr.sh:1169-1377`).
- Do not port the forced 200-line pane-read workaround: both plain and ANSI capture still compensate for a small-`--lines` defect disproved on 0.7.5 (`bin/backends/herdr.sh:1462-1480`).
- The claimed recovery contract is partly dead code: `fm_backend_herdr_resolve_bare_selector` and `fm_backend_herdr_list_live` have no production caller, while the generic selector fallback is hard-wired to tmux (`bin/backends/herdr.sh:1966-2017`, `bin/fm-backend.sh:473-512`).
- Native busy truth is not consistent across harnesses or consumers: the adapter reports only `working` as busy, the watcher trusts native `idle`, two other consumers regex-corroborate it, and a live 0.7.5 Pi probe remained `idle` with no regex match throughout a foreground tool call (`bin/backends/herdr.sh:1836-1876`, `bin/fm-watch.sh:185-201`, `bin/fm-crew-state.sh:151-191`).
- Keep native event push, but rebuild it directly for Herdr: the subscribe-before-reconcile and poll fallback are sound, while the donor's generic backend dispatch, first-backend/session selection, and nominal timeout that excludes connect/send time are avoidable baggage (`bin/backends/herdr.sh:2037-2273`, `bin/backends/herdr-eventwait.py:39-98`, `bin/fm-watch.sh:641-718`).

## 1. Mechanism inventory

### M1. Actual adapter boundary and function partition

**What it does.** `herdr.sh` has no explicit export declaration; every function carries the `fm_backend_herdr_` prefix, including private helpers. The real boundary is therefore the production call graph, not the name.

**Where.** The generic dispatch surface is in `bin/fm-backend.sh:517-800`; direct spawn use is in `bin/fm-spawn.sh:937-1160`; direct away-mode and teardown use is in `bin/fm-afk-launch.sh:179-401` and `bin/fm-teardown.sh:1222-1272`.

**Function partition verified from production references:**

- **Generic backend-contract entry points:** `fm_backend_herdr_capture`, `fm_backend_herdr_send_key`, `fm_backend_herdr_send_text_submit`, `fm_backend_herdr_kill`, `fm_backend_herdr_busy_state`, `fm_backend_herdr_composer_state`, `fm_backend_herdr_agent_alive`, `fm_backend_herdr_events_capable`, `fm_backend_herdr_wait_transition`, `fm_backend_herdr_commit_transition`, and `fm_backend_herdr_clear_transition` (`bin/fm-backend.sh:517-800`). `fm_backend_target_exists` additionally reaches through the abstraction and calls `fm_backend_herdr_cli` directly (`bin/fm-backend.sh:649-681`).
- **Spawn-contract entry points called directly:** `fm_backend_herdr_workspace_label`, `fm_backend_herdr_session`, `fm_backend_herdr_container_ensure`, `fm_backend_herdr_create_task`, `fm_backend_herdr_send_text_line`, `fm_backend_herdr_current_path`, and `fm_backend_herdr_send_literal`; `fm_backend_herdr_send_key` is shared with generic dispatch (`bin/fm-spawn.sh:991-1160`).
- **Cross-script Herdr utilities, public only because donor scripts bypass generic dispatch:** `fm_backend_herdr_cli`, `fm_backend_herdr_server_ensure`, `fm_backend_herdr_parse_target`, and `fm_backend_herdr_pane_agent_state`. The optional projection additionally exposes `fm_backend_herdr_projection_journal_path`, `fm_backend_herdr_projection_journal_create`, `fm_backend_herdr_projection_workspace_label`, `fm_backend_herdr_presentation_session_lock_path`, `fm_backend_herdr_projection_close_pane_focus_preserving`, `fm_backend_herdr_projection_order_best_effort`, `fm_backend_herdr_projection_create_task`, `fm_backend_herdr_projection_cleanup_exact`, `fm_backend_herdr_projection_recovery_allows_flat`, and `fm_backend_herdr_projection_endpoint_matches_journal` (`bin/fm-spawn.sh:937-1050`, `bin/fm-afk-launch.sh:179-401`, `bin/fm-teardown.sh:1222-1257`).
- **Implemented but not production-called:** `fm_backend_herdr_resolve_bare_selector` and `fm_backend_herdr_list_live` (`bin/backends/herdr.sh:1966-2017`). Their only non-document references are tests; the generic selector's no-metadata fallback explicitly calls the tmux resolver (`bin/fm-backend.sh:473-512`).
- **Internal helpers:** `fm_backend_herdr_tool_check`, `fm_backend_herdr_version_check`, `fm_backend_herdr_metadata_capable`, `fm_backend_herdr_task_description`, `fm_backend_herdr_report_metadata`; `fm_backend_herdr_workspace_find`, `fm_backend_herdr_workspace_prune_seeded_default_tab`, `fm_backend_herdr_workspace_ensure`; `fm_backend_herdr_tab_is_husk`; `fm_backend_herdr_target_ready`, `fm_backend_herdr_normalize_key`; `fm_backend_herdr_capture_ansi`, `fm_backend_herdr_strip_ansi`, `fm_backend_herdr_pi_separator_row`, `fm_backend_herdr_pi_composer_find`, `fm_backend_herdr_agent_identity_raw`; `fm_backend_herdr_classify_agent_status`, `fm_backend_herdr_classify_submit_agent_status`, `fm_backend_herdr_agent_status_raw`, `fm_backend_herdr_submit_confirm_budget`, `fm_backend_herdr_wait_for_working`; `fm_backend_herdr_pane_for_tab`; and `fm_backend_herdr_socket_path`, `fm_backend_herdr_normalize_event`, `fm_backend_herdr_event_reader_cmd`, `fm_backend_herdr_escalation_marker`, and `fm_backend_herdr_apply_transition`. Projection-only internals are `fm_backend_herdr_projection_id`, `fm_backend_herdr_projection_journal_token`, `fm_backend_herdr_projection_concise_task_label`, `fm_backend_herdr_presentation_lock_namespace`, `fm_backend_herdr_presentation_lock_namespace_mode`, `fm_backend_herdr_presentation_lock_namespace_uid`, `fm_backend_herdr_presentation_lock_namespace_valid`, `fm_backend_herdr_presentation_session_socket_path`, `fm_backend_herdr_projection_focus_snapshot`, and `fm_backend_herdr_projection_focus_restore` (`bin/backends/herdr.sh:284-766`).

**Dependencies / dependents.** The file sources `bin/fm-composer-lib.sh` and `bin/fm-transition-lib.sh` at `bin/backends/herdr.sh:61-75`. Spawn, send, teardown, supervision, away-mode injection, and tests depend on different subsets.

**Why it exists.** The header says the file was extracted as one arm of a multi-session-provider abstraction (`bin/backends/herdr.sh:1-51`; `bin/fm-backend.sh:1-49`). There is no stated reason for the adapter to lack an explicit public/private split.

### M2. CLI routing, tool/version gate, and server readiness

**What it does.** Every session-scoped Herdr command sets `HERDR_SESSION` and appends `--session`; core startup requires `herdr`, `jq`, and client protocol 14+, then starts a headless server and polls for at most ten seconds if the named server is not already running.

**Where.** `bin/backends/herdr.sh:174-212`, `bin/backends/herdr.sh:767-786`.

**Dependencies / dependents.** Depends on `herdr status --json`, `jq`, and the Herdr CLI's global session flag. All topology and pane operations depend on it. The event path adds Python and schema gates separately under M10.

**Why it exists.** The source records historical silent misrouting when only `HERDR_SESSION` was set and historical lack of socket auto-start (`bin/backends/herdr.sh:160-179`, `bin/backends/herdr.sh:767-772`).

### M3. Project workspace, task tab, and seeded-tab authority

**What it does.** The donor resolves a project/supervisor display label, finds or creates one workspace, captures the exact seeded default-tab id only from the same create response, creates the real task tab, and only then may prune that exact seeded tab. A same-labelled restored husk is replaced create-before-close; live or unknown panes refuse replacement.

**Where.** Labels: `bin/backends/herdr.sh:138-158`; workspace find/ensure/prune: `bin/backends/herdr.sh:788-980`; pane/husk classification and task creation: `bin/backends/herdr.sh:982-1167`.

**Dependencies / dependents.** Depends on the project registry parser, `workspace list/create`, `tab list/create/close`, `pane list/get/close`, `agent get`, exact response ids, and global variables populated by `workspace_ensure`. Spawn and restart idempotency depend on the complete sequence.

**Why it exists.** The source documents a live incident in which label-based pruning closed an operator-owned pane, plus Herdr's restored agent-free shells and last-tab workspace cascade (`bin/backends/herdr.sh:808-897`, `bin/backends/herdr.sh:1055-1091`).

### M4. Best-effort Herdr display metadata

**What it does.** After creating a task pane, the adapter reads the schema, independently gates pane/workspace metadata methods, and reports display-only title/tokens while swallowing all failures.

**Where.** `bin/backends/herdr.sh:214-276`.

**Dependencies / dependents.** Depends on the current schema and `pane.report_metadata` / `workspace.report_metadata`. Nothing authoritative depends on success.

**Why it exists.** The comments state it exists to make tasks legible without changing Herdr's agent identity or lifecycle owner (`bin/backends/herdr.sh:233-242`).

### M5. Optional presentation-space projection

**What it does.** A default-off mode creates one disposable workspace per task, journals a random non-authoritative token, serializes workspace ordering through a machine-private lock, calls raw `workspace.move`, snapshots/restores focus, and quarantines ambiguous cleanup.

**Where.** Token/journal/lock/focus/order: `bin/backends/herdr.sh:284-766`; projected create/recovery/correlation: `bin/backends/herdr.sh:1169-1377`.

**Dependencies / dependents.** Depends on state journals, `/tmp` locks, Python raw-socket movement, exact focus and topology responses, and dedicated spawn/teardown branches (`bin/fm-spawn.sh:937-1047`, `bin/fm-teardown.sh:1222-1257`). Operational send, capture, liveness, and recovery do not depend on it.

**Why it exists.** The header calls it a visual projection and explicitly denies it task authority (`bin/backends/herdr.sh:16-31`). Its safety complexity compensates for optional visual separation and historical focus movement.

### M6. Generic target and operation shims

**What it does.** The adapter packs session plus bare pane id into `<session>:<workspace:pane>`, reparses that string before each operation, maps generic key spellings to Herdr names, and exposes separate `send_text_line`, `send_literal`, `send_key`, `capture`, and `kill` operations matching the other backend arms.

**Where.** `bin/backends/herdr.sh:1378-1480`, `bin/backends/herdr.sh:1824-1827`; generic case wrappers at `bin/fm-backend.sh:517-646`.

**Dependencies / dependents.** Depends on a donor metadata field named `window=` and a shared cross-backend operation vocabulary. Spawn, send, peek, watcher, and teardown depend on those shapes.

**Why it exists.** The file says the target is deliberately parallel to the tmux adapter and the operation methods mirror tmux sequences (`bin/backends/herdr.sh:32-45`, `bin/backends/herdr.sh:1412-1461`).

### M7. Treehouse foreground-path tracking

**What it does.** Spawn polls `pane get`'s live `foreground_cwd`, not creation-time `cwd`, to detect when `treehouse get` has entered the isolated worktree.

**Where.** `bin/backends/herdr.sh:1390-1410`; caller loop begins at `bin/fm-spawn.sh:1167-1177`.

**Dependencies / dependents.** Depends on Herdr's `foreground_cwd` and the retained external Treehouse CLI. Spawn isolation verification depends on it.

**Why it exists.** The source records that `.result.pane.cwd` remains frozen at pane creation and would make the worktree-discovery poll never converge (`bin/backends/herdr.sh:1390-1401`).

### M8. Capture, composer safety, and low-level submit acknowledgement

**What it does.** Plain/ANSI pane capture feeds a harness-specific structural composer classifier for bordered, bare Claude/Codex, and Pi separator-delimited composers. Low-level send types once, retries only Enter, and confirms an idle-baseline submission by polling `agent get` for `working`/`blocked`; non-idle baselines fall back to composer state.

**Where.** Capture and composer: `bin/backends/herdr.sh:1462-1731`; submit and native confirmation: `bin/backends/herdr.sh:1733-1822`, `bin/backends/herdr.sh:1845-1957`.

**Dependencies / dependents.** Depends on ANSI styling, `bin/fm-composer-lib.sh`, harness glyphs/layouts, `pane send-text`, `pane send-keys`, and sampled native status. Steering and away-mode injection depend on the resulting `empty|pending|unknown|send-failed` vocabulary.

**Why it exists.** The comments cite swallowed Enter, completion popups, dynamic ghost suggestions, and redelivery incidents (`bin/backends/herdr.sh:1490-1556`, `bin/backends/herdr.sh:1733-1792`). Herdr 0.7.5 now exposes `agent prompt --wait`, so the reason for retaining this entire low-level path must be re-established rather than inherited.

### M9. Native busy and agent-liveness classifiers

**What it does.** Busy classification maps native `working` to `busy`, and `idle|done|blocked` to watcher-idle; malformed reads become `unknown`. Agent liveness is separate: exact `pane_not_found` is `dead`, exact `agent_not_found` after a matching pane response is `no-agent`, any registered known status is `live`, and everything else is `unknown`; public liveness maps those to `dead|alive|unknown`.

**Where.** Pane/liveness: `bin/backends/herdr.sh:982-1053`; busy: `bin/backends/herdr.sh:1836-1876`.

**Dependencies / dependents.** Depends only on structured `pane get` / `agent get` JSON and exact error codes. Duplicate-tab replacement, supervisor respawn, watcher stale suppression, crew-state classification, and away-mode injection consume the verdicts.

**Why it exists.** Pane presence cannot distinguish a registered idle agent from a restored bare shell. `unknown` deliberately never licenses destructive replacement (`bin/backends/herdr.sh:953-1053`).

**Corroboration actually implemented:**

- The adapter itself does **not** corroborate either classifier with an OS process or rendered pane text.
- `fm-crew-state.sh` trusts only native `busy`; native `idle` and `unknown` both fall through to the last-six-lines busy regex (`bin/fm-crew-state.sh:151-191`).
- The away-mode daemon does the same for both task and supervisor panes (`bin/fm-supervise-daemon.sh:551-605`).
- The ordinary watcher instead trusts native `idle` outright and regex-checks only `unknown` (`bin/fm-watch.sh:185-201`).
- The liveness path never regex- or process-corroborates a `live` result; any registered known Herdr status is treated as a live agent (`bin/backends/herdr.sh:982-1053`).

### M10. Native event transport and bounded wait

**What it does.** A Python AF_UNIX reader opens one subscription for all selected panes, waits for `subscription_started`, projects each `pane.agent_status_changed` event as four tab-separated fields, and exits cleanly at the deadline. Bash starts that reader behind a FIFO, waits for acknowledgement, performs a subscribe-before-level-reconcile, then consumes edges until a fresh actionable transition or timeout.

**Where.** Reader: `bin/backends/herdr-eventwait.py:1-142`; capability and Bash wait: `bin/backends/herdr.sh:2037-2273`.

**Capability gates.** The fast path requires `herdr`, `jq`, Python unless a reader override is configured, client protocol 16+, a schema containing both literal strings `events.subscribe` and `pane.agent_status_changed`, an unambiguous session socket, at least one parseable pane target, a reader command, FIFO creation, and an exact `@subscribed` acknowledgement (`bin/backends/herdr.sh:2053-2076`, `bin/backends/herdr.sh:2162-2218`). The schema test is presence-only string matching; wire-shape drift is caught at runtime, not structurally proven by the gate.

**Return/failure contract.** Return `0` means a fresh actionable record, `1` means the reader consumed the full event budget cleanly, and `2` means the path was unusable. Connect/send/subscribe/early-close/read failures all reach `2`, causing the caller to sleep the same poll budget (`bin/backends/herdr.sh:2162-2273`, `bin/backends/herdr-eventwait.py:22-37`).

**Bound caveat.** The stream deadline begins only after socket connect and `sendall`; those operations each inherit a five-second socket timeout. Therefore `timeout_secs` bounds the acknowledgement/stream phase, not total wall time (`bin/backends/herdr-eventwait.py:39-98`).

**Dependencies / dependents.** Depends on Herdr protocol/schema/socket, Python, FIFO/process support, transition policy, and local marker files. The watcher uses it only as the terminal wait of an otherwise permanent polling loop (`bin/fm-watch.sh:641-718`).

**Why it exists.** It shortens human-blocked detection from stale polling latency to an event edge without making push delivery authoritative (`bin/backends/herdr.sh:2019-2035`).

### M11. Deterministic transition policy, dedupe, and fail-closed polling

**What it does.** Both level reads and event edges normalize to five tab-separated fields. `blocked` is actionable, `working` clears the per-pane escalation marker, `idle|done` defer, and unknown statuses fall back. The marker is committed only after the watcher has enqueued the wake; reconnect reconciliation catches panes already blocked during a subscription gap.

**Where.** Shared shape/policy: `bin/fm-transition-lib.sh:1-112`; adapter marker and apply/commit/clear: `bin/backends/herdr.sh:2078-2160`; watcher handling: `bin/fm-watch.sh:641-743`.

**Dependencies / dependents.** Depends on local volatile marker state and deterministic status values. The watcher excludes persistent supervisor endpoints, memoizes capability per backend/session, handles only the first backend/session group, and disables push for the process after three runtime failures while polling remains active (`bin/fm-watch.sh:148-159`, `bin/fm-watch.sh:653-718`).

**Why it exists.** Herdr events carry only the new state and are edge-triggered; subscribe-before-reconcile plus marker-backed level reconciliation prevents a connection gap or reconnect from losing or repeatedly redelivering a blocked state (`bin/backends/herdr.sh:2078-2160`, `bin/backends/herdr.sh:2219-2240`).

### M12. Label-scoped recovery and bare-selector search

**What it does.** One helper searches all running Herdr sessions for a tab label; another lists `fm-` task tabs under the first matching workspace label and emits generic `<session>:<pane>\t<label>` records.

**Where.** `bin/backends/herdr.sh:1966-2017`.

**Dependencies / dependents.** Depends on mutable labels and full session/tab/pane enumeration. Only tests depend on these functions in the current production tree.

**Why it exists.** Comments say it mirrors tmux's bare-selector and recovery inventory contracts and avoids trusting stored ids after restart (`bin/backends/herdr.sh:1966-2005`). The production dispatcher does not wire those contracts for Herdr.

## 2. Verified versus prose-sourced

### Verified from implementation and read-only probes

- The public/private partition above was verified by searching every production reference to every function defined in `bin/backends/herdr.sh`; the prefix alone does not identify the contract.
- `resolve_bare_selector` and `list_live` are not production-reachable. Tests call `list_live`, but `bin/fm-backend.sh:473-512` routes the generic no-metadata fallback only to tmux.
- The projection system is non-authoritative in code: normal capture/send/kill/liveness/event functions never read its journal; its callers are isolated spawn/teardown branches.
- Created-versus-adopted prune authority is real: only the same `workspace create` response populates `FM_BACKEND_HERDR_WS_SEEDED_TAB_ID`, and `create_task` receives that exact id (`bin/backends/herdr.sh:899-980`, `bin/backends/herdr.sh:1093-1167`).
- Unknown liveness never authorizes husk replacement. A replacement task tab is created before any confirmed husk is closed (`bin/backends/herdr.sh:982-1167`).
- Both capture functions still force `fetch >= 200` and trim locally (`bin/backends/herdr.sh:1462-1480`). A read-only 0.7.5 probe in this scout returned five non-empty lines from a 64-row pane using `--lines 5`, corroborating report 02's stale-workaround finding.
- Busy corroboration is consumer-dependent, not an adapter property: crew-state and daemon corroborate every non-`busy` verdict; watcher does not (`bin/fm-crew-state.sh:151-191`, `bin/fm-supervise-daemon.sh:551-605`, `bin/fm-watch.sh:185-201`).
- The installed `0.7.5-preview.2026-07-21-0f10e1453a7f` reported protocol 17. Its live schema contains `events.subscribe` and `pane.agent_status_changed`; the adapter's gate requires protocol 16 and literal presence of both strings (`bin/backends/herdr.sh:2053-2076`).
- A current focused Pi pane remained native `idle` with `screen_detection_skipped=true` in six samples across a three-second foreground tool command; four additional samples found neither native busy nor the configured rendered busy regex. This narrows report 02's conclusion: the historical broad defect is stale for its tested Claude integration, not for the current Pi integration.
- Current `herdr agent prompt --help` exposes atomic prompt submission plus `--wait`, `--until`, and `--timeout`; it also warns that an already-working agent's current turn may satisfy the wait. This confirms a replacement candidate, not drop-in equivalence.
- Event push cannot suppress polling: clean timeout means the reader already consumed the poll interval; any unusable result sleeps that interval, and after three failures the watcher disables push until restart (`bin/fm-watch.sh:641-718`).

### Prose-sourced or not independently exercised

- The source's claim that `HERDR_SESSION` alone can silently route to the wrong server comes from comments/historical verification (`bin/backends/herdr.sh:160-179`). This scout verified the explicit flag remains accepted, not the old failure.
- The claim that a stopped Herdr server does not auto-start for socket operations was not exercised because starting/stopping sessions was prohibited (`bin/backends/herdr.sh:767-772`).
- Duplicate workspace/tab labels, workspace-create response shape, last-tab cascade deletion, and restored agent-free shells were not mutated or reproduced. Their defensive code was verified; current provider behavior remains prose/historical evidence.
- The exact error-stream claim that Herdr writes business-error JSON to stderr was not induced against 0.7.5 because querying missing resources was unnecessary and potentially confused live-state analysis (`bin/backends/herdr.sh:982-1008`).
- The raw event subscriber was not connected during this scout. Its code, tests, current schema surface, and fallback path were read; live delivery timing was not re-measured.
- No prompt, key, or text was sent. `agent prompt --wait` behavior, low-level Enter swallowing, popup selection, and current harness composer shapes therefore remain unexercised.
- The liveness comment calls a registered Herdr agent a confirmed live process, but the implementation does not verify an OS process (`bin/backends/herdr.sh:1040-1053`). Whether Herdr can retain a stale registration with a known status could not be determined read-only.

## 3. Verdict per mechanism

The “Already have it?” column was checked against `~/.claude/commands/Themis.md:45-49`, `../Config/packages/pi-themis/extensions/themis.ts:69-82`, `../Config/packages/omp-themis/src/main.ts:110-125`, and `../Config/packages/omp-themis/skills/themis-pm/SKILL.md:13-22`. Those surfaces contain orchestration prose and tab-label guidance, not a session adapter.

| Mechanism | Verdict | Why | Already have it? |
| --- | --- | --- | --- |
| M1 adapter boundary / function partition | **rebuild** | Herdr-only code needs an explicit small public API; remove generic case dispatch and stop exposing internals merely because other donor scripts reach through it. | **absent** — the current Themis surfaces implement no Herdr API boundary. |
| M2 CLI routing / capability / readiness | **copy** | Explicit `--session`, fail-loud core gates, and bounded server readiness are genuinely Herdr-specific safety, independent of dropped backends. Raise the protocol/capability baseline after current tests. | **absent** — current surfaces only mention `HERDR_ENV` preference. |
| M3 workspace/tab/husk lifecycle | **rebuild** | Keep workspace-per-project, tab-per-task, exact created-id prune authority, create-before-close, and fail-safe unknown; replace donor Fleet/Archon labels and first-match mutable-label ownership. | **partial** — all three surfaces require agent tab labels, but none owns workspace reuse, ids, duplicate prevention, or husks. |
| M4 display metadata | **rebuild** | Metadata is useful Herdr-native presentation, but donor source names/tokens and task vocabulary must be replaced; keep it best-effort and non-authoritative. | **absent**. |
| M5 optional presentation projection | **strip** | It is default-off visual convenience with no lifecycle authority and imports raw movement, locks, focus restoration, journals, and cleanup branches we do not need. | **absent**. |
| M6 generic target/operation shims | **strip** | Separate stored Herdr ids make the tmux-shaped `window=` target parser unnecessary; direct Herdr commands eliminate backend case wrappers and generic key normalization. | **absent** — there is no current endpoint model to preserve. |
| M7 Treehouse foreground-path tracking | **copy** | Treehouse remains by decision, and `foreground_cwd` is the Herdr-specific signal that proves entry into its isolated worktree. | **absent**. |
| M8 capture/composer/low-level submit | **rebuild** | Strip the 200-line workaround and evaluate `agent prompt --wait` before retaining 250+ lines of TUI-shape and Enter-retry logic; keep conservative capture/composer checks only for cases the agent facade cannot cover. | **absent**. |
| M9 busy and liveness classification | **rebuild** | Deterministic classification stays, but native state differs by harness and current consumers disagree; define one canonical policy and retain `unknown` refusal. | **absent** for deterministic Herdr state; current persona heartbeat prose is not an implementation. |
| M10 native event transport / bounded wait | **rebuild** | Keep direct AF_UNIX subscription, acknowledgement, subscribe-before-reconcile, and explicit return classes; remove backend dispatch and make total wall time genuinely bounded. | **absent**. |
| M11 transition policy / dedupe / poll fallback | **copy** | Deterministic `blocked`/`working` policy, commit-after-enqueue, level reconciliation, and permanent polling are backend-independent correctness mechanisms still needed with Herdr alone. Rename vocabulary without weakening ordering. | **absent**. |
| M12 label recovery / bare selector | **strip** | The donor does not production-wire these functions, and mutable display labels must not become ownership in the new endpoint registry. Rebuild recovery later from exact local ids plus read-only Herdr inventory if required. | **absent**. |

## 4. Coupling notes

1. **Do not copy `herdr.sh` alone.** Composer decisions live in `bin/fm-composer-lib.sh`; transition shape/policy lives in `bin/fm-transition-lib.sh`; event fallback and marker commit ordering live in `bin/fm-watch.sh`.
2. **Created-versus-adopted authority is a same-process channel.** `workspace_ensure` sets globals, so wrapping it in command substitution discards the authority signal (`bin/backends/herdr.sh:899-980`). A port should return a typed result such as `{workspace_id, created, seeded_tab_id}` instead.
3. **Create-before-close is not cosmetic.** It protects both default-tab pruning and restored-husk replacement from last-tab workspace deletion (`bin/backends/herdr.sh:842-897`, `bin/backends/herdr.sh:1055-1167`).
4. **Exact ids and labels have different jobs.** Labels are useful display/search hints; they are unsafe ownership authority. The donor's ordinary `workspace_find` still adopts the first matching mutable label (`bin/backends/herdr.sh:788-818`).
5. **Herdr pane ids already contain a colon.** If a composite target survives, it must split only once. Prefer storing `session`, `workspace_id`, `tab_id`, and `pane_id` separately and passing bare pane ids to Herdr.
6. **Treehouse and Herdr spawn are coupled through foreground cwd.** Replacing low-level spawn commands must preserve the point at which `foreground_cwd` proves that Treehouse entered the isolated copy.
7. **Low-level send is one safety system, not independent helpers.** Pre-send composer emptiness, type-once, Enter-only retry, native turn-start confirmation, and uncertainty handling prevent opposite duplication/loss modes. Replace the entire chain or retain it coherently.
8. **`agent prompt --wait` has an already-working caveat.** The current help says an existing active turn may satisfy the wait. A port must define whether prompting a busy agent is queued, rejected, or allowed before adopting it as acknowledgement.
9. **Busy and liveness are separate predicates.** A blocked or idle registered agent is alive but not generating. A no-agent pane is a husk. `unknown` must not be collapsed into dead.
10. **The current busy fallback is not canonical.** Watcher, crew-state, and daemon apply different corroboration rules. Herdr-only porting is the opportunity to define one classifier per purpose rather than one `busy` token with consumer-specific reinterpretation.
11. **Pi currently defeats both native and rendered busy checks during tool execution.** `screen_detection_skipped=true` plus no footer regex means corroboration does not make Pi safe by itself. Tool/run ownership needs an independent deterministic signal if it affects stale suppression.
12. **Event subscribe and level reconcile must keep their order.** Subscribe first, then read current levels, then drain buffered edges. Reversing it opens a lost-edge gap (`bin/backends/herdr.sh:2199-2240`).
13. **Dedupe commit must remain after durable enqueue.** The adapter returns an actionable record without touching the marker; the watcher appends the wake and only then commits (`bin/fm-watch.sh:728-743`).
14. **Runtime failure does not end supervision.** Return `2` sleeps the normal poll interval, and three failures disable only push for the current watcher process (`bin/fm-watch.sh:695-718`).
15. **The current event timeout is not a total deadline.** Connect and send occur before `start = time.monotonic()` (`bin/backends/herdr-eventwait.py:65-98`). Move the absolute deadline before socket creation and apply remaining time to every operation.
16. **The event capability gate is intentionally shallow.** Literal method/event names can survive incompatible parameter or payload changes. Keep runtime validation and fallback even if the schema check becomes structural.
17. **One connection currently covers only the first backend/session group.** That complexity exists for a mixed-backend home (`bin/fm-watch.sh:653-672`). With Herdr only, group directly by named Herdr session or enforce one session.
18. **Projection removal crosses files.** Strip adapter helpers together with `fm-spawn.sh` projection branches, `fm-teardown.sh` journal/focus cleanup, configuration, Python workspace mover, and projection state. Leaving only half creates dead locks/journals or cleanup paths.
19. **The present Themis surfaces are prose, not infrastructure.** Claude says agents may share a tab in a 2x2 split while all surfaces require explicit tab labels (`~/.claude/commands/Themis.md:45-49`); Pi/OMP prefer native subagents (`../Config/packages/pi-themis/extensions/themis.ts:77-82`, `../Config/packages/omp-themis/src/main.ts:120-125`). The new adapter needs one canonical topology contract rather than inheriting those descriptions as implementation.
20. **Vocabulary is entangled in code.** Workspace labels, metadata source/tokens, projection paths, reader ids, temp prefixes, comments, and wake text contain `firstmate`, Fleet, Archon, captain, and crew terms. Copy verdicts mean mechanism and ordering, not byte-for-byte strings.

## 5. What you could not determine

1. Whether 0.7.5 still permits duplicate labels, returns the seeded tab/root-pane shape, cascades last-pane closure through tab/workspace removal, or restores agent-free shells. All require forbidden mutations.
2. Whether `agent prompt --wait` safely handles a busy agent, trust/menu prompts, pending human composer text, completion popups, or every supported harness. No input was sent.
3. Whether the raw event stream currently emits exactly the payload shape consumed by `herdr-eventwait.py`. The schema surface exists, but no live subscription was opened.
4. Whether 0.7.5 still writes `pane_not_found` / `agent_not_found` JSON to stderr exactly as 0.7.1 did.
5. Whether a known registered Herdr status always proves the underlying harness process is alive. The adapter does not perform process corroboration.
6. Whether Pi's `idle` during tool execution is an intentional provider contract or a Herdr detection gap. The live samples establish the observed result, not its owner.
7. Which non-Pi harnesses still need regex corroboration. Report 02 disproved the broad old claim for Claude; this scout found the opposite for Pi, but did not run a harness matrix.
8. Whether the composer classifier's current ANSI/glyph assumptions still hold for Claude, Codex, Grok, and Pi. No composer was driven.
9. Whether a stopped named server still requires explicit headless startup. Stopping or starting sessions was prohibited.
10. The referenced quality-bar report was not present at `.agents/plans/2026-07-25-heartbeat-dissection-for-themis-persona.md`; this report follows `SCOUT-BRIEF.md` directly.
