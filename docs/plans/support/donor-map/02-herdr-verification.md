<!-- markdownlint-disable MD013 -->

# Donor map 02: Herdr verification and gaps

Assignment: Herdr verification against `docs/herdr-backend.md`, `bin/backends/herdr.sh`, related implementation owners, and the installed read-only Herdr CLI.

Verification date: 2026-07-25.

Installed binary observed without mutation:

```text
herdr 0.7.5-preview.2026-07-21-0f10e1453a7f
client protocol 17
server protocol 17
```

No pane, tab, workspace, session, process, or repository state was created, closed, renamed, focused, sent input, or otherwise changed during verification.
The only live Herdr operations were help, status/schema/list/get/current, and pane-read probes against the existing session.

## 1. Mechanism inventory

### M1. Runtime auto-detection and backend selection

- **What it does:** The donor chooses Herdr when `HERDR_ENV=1` and no stronger explicit selection wins; nested tmux wins before Herdr. It emits a notice because Herdr is marked experimental.
- **Where:** `bin/fm-backend.sh:94-158`, `bin/fm-backend.sh:261-267`; described at `docs/herdr-backend.md:25-30` and `docs/herdr-backend.md:105-117`.
- **Dependencies / dependents:** Depends on runtime environment markers and the generic backend resolver. Spawn and all generic session operations depend on the selected backend.
- **Why it exists:** The donor supports several interchangeable session backends and must infer the current multiplexer when no configuration exists. Our decided design keeps only Herdr, so the selection mechanism itself no longer has a reason to exist.

### M2. Tool, version, protocol, and schema capability gates

- **What it does:** The adapter requires `herdr` and `jq`, rejects client protocol below 14, separately requires protocol 16 plus schema methods for events and workspace movement, and capability-gates display metadata from the schema.
- **Where:** `bin/backends/herdr.sh:79-91`, `bin/backends/herdr.sh:181-220`, `bin/backends/herdr.sh:243-276`, `bin/backends/herdr.sh:599-766`, `bin/backends/herdr.sh:2037-2069`.
- **Dependencies / dependents:** Depends on `herdr status --json`, `herdr api schema --json`, `jq`, and optionally `python3`. Server startup, metadata, projected-space ordering, and event waits depend on these gates.
- **Why it exists:** Herdr preview releases changed protocol surfaces repeatedly, so the adapter refuses unknown core versions and degrades optional surfaces rather than assuming methods remain present.

### M3. Explicit named-session routing and headless server readiness

- **What it does:** Every adapter CLI call sets `HERDR_SESSION` and appends `--session <name>`. Before topology or pane operations, the adapter checks server status, starts a headless named server if needed, and polls for readiness for up to ten seconds.
- **Where:** `bin/backends/herdr.sh:174-179`, `bin/backends/herdr.sh:277-282`, `bin/backends/herdr.sh:767-786`.
- **Dependencies / dependents:** Depends on the Herdr CLI and named-session semantics. Every workspace, tab, pane, agent, metadata, capture, send, kill, and recovery operation depends on this wrapper.
- **Why it exists:** Historical verification found that `HERDR_SESSION` alone could silently target another running server. Explicit `--session` is the routing authority; the environment variable is retained only as redundant context.

### M4. Workspace-per-project / tab-per-task container shape

- **What it does:** Ordinary workers for one project share one reusable `<Fleet display name>-Fleet` workspace, with one `fm-<task-id>` tab and one pane per task. Different projects use different workspaces; a persistent supervisor uses an `Archon-<id>` workspace.
- **Where:** `bin/backends/herdr.sh:138-160`, `bin/backends/herdr.sh:788-818`, `bin/backends/herdr.sh:899-958`, `bin/backends/herdr.sh:1093-1167`; decision and rationale at `docs/herdr-backend.md:125-190`.
- **Dependencies / dependents:** Depends on the project registry parser (`bin/fm-project-mode.sh --fleet`), task kind, project path/key, and Herdr workspace/tab APIs. Spawn, list-live recovery, metadata, and human navigation depend on the resolved label.
- **Why it exists:** A workspace separates projects in Herdr's spaces view, while a tab per task keeps all tasks for one project visible in one tab bar. The donor explicitly rejected durable workspace-per-task because it loses that compact project view. The default-off presentation projection is not authority and does not change this ownership decision.

#### Container-shape decision to inherit

The decision is sound and is more specific than “use Herdr”:

1. **Workspace per project** gives project-level separation in the spaces sidebar.
2. **Tab per task** gives task-level switching inside one project without multiplying durable workspaces.
3. **One pane per task tab** preserves one operational endpoint per task.
4. **Workspace per task is rejected as the durable model.** It is retained only as a default-off disposable visual projection in the donor, with flat fallback and no recovery authority.
5. The donor calls the workspace “persistent,” but its own teardown semantics mean it exists only while at least one task tab remains; the accurate term is **reusable per-project workspace while nonempty**.

### M5. Label-based find/adopt and duplicate-tab prevention

- **What it does:** Workspace lookup chooses the first workspace whose label matches the resolved project label. Task creation lists tabs in that workspace and refuses a same-labeled live/unknown tab; a confirmed dead or agent-free restored husk is replaced.
- **Where:** `bin/backends/herdr.sh:788-818`, `bin/backends/herdr.sh:982-1072`, `bin/backends/herdr.sh:1093-1167`.
- **Dependencies / dependents:** Depends on mutable Herdr labels, `workspace list`, `tab list`, `pane list/get`, and `agent get`. Spawn idempotency and restart recovery depend on the result.
- **Why it exists:** Herdr does not historically enforce label uniqueness, and restored layouts may contain a tab with no live agent. The adapter therefore implements its own duplicate and husk policy.

### M6. Seeded-default-tab pruning with created-versus-adopted authority

- **What it does:** A fresh `workspace create` response yields a seeded tab id. Only that same-call id can be pruned, only after the real task tab exists, and only after rechecking tab count, label `1`, pane id, and non-working agent status. An adopted workspace never carries prune authority.
- **Where:** `bin/backends/herdr.sh:842-956`, called from `bin/backends/herdr.sh:1093-1167` and `bin/backends/herdr.sh:1169-1286`.
- **Dependencies / dependents:** Depends on exact response-derived ids, tab/pane lists, `agent get`, and `pane close`. Fresh workspace convergence depends on it.
- **Why it exists:** A former label heuristic adopted and closed a user-owned live pane. The structural created-versus-adopted gate prevents a mutable label from authorizing deletion, and create-before-close avoids Herdr deleting the workspace when its last tab closes.

### M7. Endpoint and metadata contract

- **What it does:** The operational target is `<session>:<pane-id>`, split only at the first colon because a pane id itself is `workspace:pane`. Task metadata separately records session, workspace, tab, and pane ids. Day-to-day operations use the parsed pane target.
- **Where:** `docs/herdr-backend.md:357-370`; target parser and callers at `bin/backends/herdr.sh:1378-1410`.
- **Dependencies / dependents:** Depends on local volatile task metadata and Herdr's bare pane id shape. Capture, send, busy, kill, recovery, and supervisor targeting depend on it.
- **Why it exists:** Generic donor selectors were shaped like tmux targets. Prefixing the bare Herdr pane id with the named session lets one string address both server and pane while preserving exact ids.

### M8. Best-effort display metadata

- **What it does:** After task creation, the adapter reads the schema once, reports pane title/tokens and workspace tokens when methods exist, and swallows every metadata failure. It does not claim agent lifecycle authority.
- **Where:** `bin/backends/herdr.sh:214-276`; described at `docs/herdr-backend.md:45-102`.
- **Dependencies / dependents:** Depends on `pane.report_metadata`, `workspace.report_metadata`, and deterministic task/project/harness fields. Only Herdr display presentation depends on it; task lifecycle does not.
- **Why it exists:** It makes Herdr panes/workspaces understandable without coupling task creation to optional preview metadata surfaces.

### M9. Low-level command, literal input, key send, and submit acknowledgement

- **What it does:** Fixed spawn commands use `pane run`; ordinary steers type once with `pane send-text`, then send Enter repeatedly without retyping until native `agent get` observes a submit-active transition or a conservative composer fallback settles the outcome. Key aliases are normalized before `pane send-keys`.
- **Where:** `bin/backends/herdr.sh:1412-1459`, `bin/backends/herdr.sh:1729-1822`, `bin/backends/herdr.sh:1836-1957`.
- **Dependencies / dependents:** Depends on `pane run`, `pane send-text`, `pane send-keys`, `agent get`, timing budgets, and the composer classifier. Spawn commands, steering, and away-mode injection depend on it.
- **Why it exists:** `send-text` does not historically submit, autocomplete can consume the first Enter, and an unverified Enter previously left commands typed but unsent. The adapter requires acknowledgement without retyping and risking duplicate delivery.

### M10. Bounded capture and structural composer safety

- **What it does:** Capture currently asks Herdr for at least 200 lines and trims locally. Composer state scans ANSI-preserving output for the bottom-most supported composer shape, strips dim/dark placeholder styling, and returns deterministic `empty`, `pending`, or `unknown`.
- **Where:** `bin/backends/herdr.sh:1462-1479`, `bin/backends/herdr.sh:1486-1727`, with shared content policy in `bin/fm-composer-lib.sh`.
- **Dependencies / dependents:** Depends on `pane read --source recent --format ansi`, ANSI styling conventions, agent identity for Pi, and the shared classifier. Safe injection and fallback submit acknowledgement depend on it.
- **Why it exists:** Earlier delta-based and plain-text checks confused popup expansion and ghost suggestions with successful submission. The structural classifier prevents overwriting pending input or repeatedly redelivering a message.

### M11. Native agent state, busy classification, liveness, and restored-husk handling

- **What it does:** `agent get` maps `working` to busy, `idle/done/blocked` to watcher-idle, and unknown shapes to unknown. A separate pane/agent classifier distinguishes `dead`, `no-agent`, `live`, and `unknown`; liveness and duplicate-tab recovery reuse that deterministic classification.
- **Where:** `bin/backends/herdr.sh:982-1072`, `bin/backends/herdr.sh:1836-1957`.
- **Dependencies / dependents:** Depends on `pane get`, `agent get`, exact error codes, and shared caller-side regex corroboration. Stale suppression, startup supervisor recovery, duplicate prevention, and submit confirmation depend on these verdicts.
- **Why it exists:** Pane presence alone cannot distinguish a live agent from a restored bare shell. Deterministic native state is stronger than process-name guessing, while `unknown` must never authorize destructive recovery.

### M12. Label-scoped live recovery and exact-pane teardown

- **What it does:** Recovery finds the resolved project workspace, lists only `fm-` tabs, resolves each tab's pane, and returns session-prefixed endpoints. Teardown closes only the task pane; it never closes a workspace by label.
- **Where:** `bin/backends/herdr.sh:1959-2017`, `bin/backends/herdr.sh:1824-1827`.
- **Dependencies / dependents:** Depends on the workspace-label owner, tab/pane lists, and exact recorded ids. Recovery, orphan discovery, and cleanup depend on it.
- **Why it exists:** Stored ids are the fast path, but label-scoped discovery handles missing or differently configured session state. Exact-pane close limits destructive authority.

### M13. Native blocked-state event push with polling fallback

- **What it does:** The adapter capability-gates `events.subscribe`, opens one bounded AF_UNIX subscription to `pane.agent_status_changed`, normalizes every event, immediately surfaces a fresh `blocked` edge, clears dedupe on `working`, and falls back to polling on any capability or runtime failure.
- **Where:** `bin/backends/herdr.sh:2019-2260`, wire reader `bin/backends/herdr-eventwait.py:1-142`, deterministic policy `bin/fm-transition-lib.sh:1-112`; rationale at `docs/herdr-backend.md:1183-1225`.
- **Dependencies / dependents:** Depends on protocol 16+, current schema, Python, the session socket, the transition policy, and local dedupe markers. Supervision latency depends on it; correctness does not, because polling remains active.
- **Why it exists:** Native push reduces a human-blocked wait from the stale polling horizon to sub-second latency without making event delivery a single point of failure.

### M14. Optional disposable presentation workspaces and raw workspace ordering

- **What it does:** A default-off flag may create a one-task workspace with a random visible token, verify exact topology and focus, order it after its owning project using raw `workspace.move`, and quarantine ambiguous or stale projections instead of adopting or deleting them.
- **Where:** `bin/backends/herdr.sh:284-766`, `bin/backends/herdr.sh:1169-1377`, raw mover `bin/backends/herdr-workspace-move.py:1-114`; described at `docs/herdr-backend.md:191-328`.
- **Dependencies / dependents:** Depends on local projection journals, secure per-session locks, protocol 16 schema, Python, raw AF_UNIX access, exact focus snapshots, and the ordinary task endpoint. It is presentation-only; no task authority depends on it.
- **Why it exists:** It offers visually separate temporary spaces while preserving workspace-per-project as the durable model. Its complexity exists almost entirely to ensure that a visual convenience cannot acquire lifecycle authority.

### M15. Separate non-visible Herdr terminal for away-mode supervision

- **What it does:** When the host lacks a native tracked background mechanism, the donor creates a dedicated `--no-focus` workspace, runs the away daemon there, records its exact pane, and later closes only that pane. It never splits the active operator tab.
- **Where:** `bin/fm-afk-launch.sh:1-24`, `bin/fm-afk-launch.sh:179-250`, `bin/fm-afk-launch.sh:289-409`; described at `docs/herdr-backend.md:1226-1265`.
- **Dependencies / dependents:** Depends on the Herdr adapter, daemon lifecycle, local away-mode records, and exact supervisor target. Away-mode escalation delivery depends on it for hosts without native background jobs.
- **Why it exists:** Splitting the active pane visibly changes its geometry, and detached shell children may be reaped. A dedicated workspace provides a tracked terminal without disturbing the active tab.

### M16. Guarded, isolated Herdr verification sessions

- **What it does:** The lab helper accepts only `fm-lab-*` names, appends explicit `--session`, forbids lifecycle calls through the generic runner, rechecks that a destructive target is non-default, and verifies the default-session snapshot before and after stop/delete.
- **Where:** `bin/fm-herdr-lab.sh:1-25`, `bin/fm-herdr-lab.sh:28-154`, `bin/fm-herdr-lab.sh:171-280`.
- **Dependencies / dependents:** Depends on Herdr session listing, exact session names, `jq`, and a temporary tripwire record. Real Herdr tests and safe provider investigation depend on it.
- **Why it exists:** Earlier cleanup routed to and killed the live default server. The helper makes destructive verification explicit-by-name and independently tripwired.

## 2. Verified versus prose-sourced

### Verified stale or misleading claims

These are the highest-value findings.

1. **The small-`--lines` bug is stale on the installed 0.7.5 preview.**
   - Donor claim: `docs/herdr-backend.md:536-548` says `pane read --lines N` returns no bytes when `N` is smaller than the viewport. `docs/herdr-backend.md:383` presents the workaround as current.
   - Adapter inheritance: `bin/backends/herdr.sh:1462-1479` still forces a minimum 200-line fetch and trims locally.
   - Live 0.7.5 evidence: the existing pane reported a 30-row viewport. Reads with `--lines 5`, `15`, `20`, and `24` all returned non-empty output. A second probe returned exactly 5 lines for `--lines 5`, 30 for `--lines 200`, and the 5-line result byte-matched the tail of the 200-line result.
   - Consequence: the historical bug was real for 0.7.1, but the present-tense documentation is wrong for 0.7.5. The workaround is now compatibility baggage and should not be inherited without a version-scoped regression test.

2. **The broad “`agent.get` reads idle during a foreground tool call” gap is stale for the installed 0.7.5 preview and the live Claude integration.**
   - Donor claim: `docs/herdr-backend.md:550-562` says a model waiting on its own long foreground tool reads `idle` or `blocked`, requiring rendered busy-text corroboration.
   - Adapter behavior: `bin/backends/herdr.sh:1836-1876` still maps native state normally; caller-side corroboration remains defense in depth.
   - Live 0.7.5 evidence: `herdr agent get` returned `working` during a tool call. During a separate three-second foreground command, four samples at 0.5-second intervals all returned `working` while the subprocess remained alive.
   - Consequence: do not inherit the statement as a universal provider fact. Keep fallback corroboration until other supported harnesses and truly long validation commands are tested, but document it as a historical compatibility guard, not a current verified 0.7.5 defect.

3. **The session-targeting section contradicts its implementation.**
   - Misleading prose: `docs/herdr-backend.md:612` says `HERDR_SESSION=<name>` is the adapter's normal selection method for non-destructive operations.
   - Current code: `bin/backends/herdr.sh:174-179` sets the environment variable **and always appends `--session <name>` for every adapter call**, destructive or not. The same document corrects itself at `docs/herdr-backend.md:622`.
   - Live evidence: 0.7.5 top-level help still exposes global `--session`; trailing `--session default` worked for read-only `pane current`, `pane read`, and `agent get` probes.
   - Consequence: inherit “explicit flag on every call,” not “environment for normal calls, flag for destructive calls.”

4. **“Persistent per-project workspace” overstates the actual lifecycle.**
   - Prose: heading and text at `docs/herdr-backend.md:182-189` call the workspace persistent and created once per session.
   - Same document's caveat: `docs/herdr-backend.md:351-353` says closing the final task tab removes the workspace and the next spawn recreates it.
   - Code: `bin/backends/herdr.sh:1824-1827` closes the task's pane only; it does not preserve a keeper tab.
   - Consequence: the inherited decision should be named “reusable workspace per project while nonempty.” No durable identity should assume the workspace survives an idle fleet.

5. **The low-level submit path is not stale code, but it is now a supersedable design.**
   - Prose and code agree: `docs/herdr-backend.md:65-71` intentionally keeps `pane run` / `pane send-text` / `pane send-keys`; `bin/backends/herdr.sh:1412-1459` and `bin/backends/herdr.sh:1729-1822` implement that choice.
   - Live 0.7.5 evidence: `herdr agent --help` exposes `start`, atomic `prompt`, server-owned `wait`, and logical agent `send-keys`; `agent prompt --wait` documents state-change and settled-state acknowledgement.
   - Consequence: this is not a factual mismatch, but copying the old submit/composer machinery would ignore a current first-class API that did not exist when most incidents were diagnosed. Re-evaluate the control path before porting.

### Current CLI facts and evidence

The table covers every row in the donor's “Verified CLI facts” table (`docs/herdr-backend.md:372-392`) plus current surfaces that materially affect inheritance.

| Fact | Verification status | Evidence |
| --- | --- | --- |
| Client/protocol gate uses `herdr status --json` and `.client.protocol` | **Verified current** | Live status reported client/server protocol 17; `bin/backends/herdr.sh:192-212` reads `.client.protocol` and enforces the floor. |
| Headless server must be started and polled before topology calls | **Adapter verified; provider cause prose-sourced** | `bin/backends/herdr.sh:767-786` implements status → background `server` → bounded poll. A read-only session could not re-test the historical “socket calls do not auto-start” behavior without starting a server. |
| Duplicate task labels require adapter-side checking | **Adapter verified; provider uniqueness prose-sourced** | `bin/backends/herdr.sh:1093-1167` lists and classifies same-labeled tabs. Creating duplicate tabs was prohibited, so 0.7.5 uniqueness behavior was not re-tested. |
| `pane send-text` sends literal, unsubmitted text | **Surface and adapter verified; unsubmitted behavior prose-sourced** | Live help says “Send literal text”; `bin/backends/herdr.sh:1421-1428` uses it as unsubmitted input. No input was sent during this scout. |
| `pane run` types and submits one command | **Surface and adapter verified; atomic effect prose-sourced** | Live help says “Run a command in a pane”; `bin/backends/herdr.sh:1412-1419` uses it for fixed spawn commands. No pane command was run. |
| `pane send-keys` accepts Enter/Escape/Ctrl-C aliases | **Partly verified current** | Live 0.7.5 help says `esc` is canonical and `escape` accepted. `bin/backends/herdr.sh:1431-1459` normalizes Enter, Escape, and Ctrl-C. Ctrl-C aliases/interrupt behavior were not re-driven. |
| Submit confirmation can read `agent get` state after Enter | **Verified current mechanism** | Live `agent get` returned current structured status; `bin/backends/herdr.sh:1794-1822` polls through `bin/backends/herdr.sh:1836-1957`. End-to-end sending was not performed. |
| Small bounded `pane read --lines N` is broken | **Disproved on current 0.7.5** | A 30-row existing pane returned exact non-empty 5-line output and it matched the tail of a 200-line read. Historical workaround remains at `bin/backends/herdr.sh:1462-1479`. |
| ANSI capture exists and accepts `--format ansi` | **Verified current surface** | Live `pane read --help` lists `text`/`ansi`; adapter uses it at `bin/backends/herdr.sh:1472-1479`. Preservation of each harness's dim/truecolor semantics is historical evidence, not re-tested. |
| Native busy state is `agent get` → `agent_status` | **Verified current** | Live status was `working` during the active turn and across four samples during a three-second tool command. Mapping lives at `bin/backends/herdr.sh:1836-1876`. |
| `pane close` removes the task endpoint and cascades when it is the last pane | **Adapter close verified; cascade prose-sourced** | `bin/backends/herdr.sh:1824-1827` closes only the pane. Closing anything was prohibited, so 0.7.5 cascade behavior was not re-tested. |
| Fresh `workspace create` returns seeded tab/root pane ids used for exact prune | **Adapter verified; response shape historical** | Exact-id threading/prune is implemented at `bin/backends/herdr.sh:842-956` and `bin/backends/herdr.sh:1093-1167`. Creating a workspace was prohibited. |
| `workspace.move` is schema-only with integer `insert_index` | **Verified current** | Live protocol-17 schema requires `workspace_id` and integer `insert_index`; `herdr workspace --help` still has no `move` subcommand. Adapter gate/mover: `bin/backends/herdr.sh:599-766`, `bin/backends/herdr-workspace-move.py:1-114`. |
| Closing a non-focused final projection pane can steal focus | **Adapter mitigation verified; provider bug prose-sourced for 0.7.4** | Focus-preserving cleanup exists in `bin/backends/herdr.sh:480-597` and projected teardown uses it. Destructive reproduction was prohibited, so 0.7.5 behavior is unknown. |
| Recovery lists `fm-` tabs inside the resolved workspace | **Verified current code** | `bin/backends/herdr.sh:2006-2017` performs label-scoped tab and pane discovery. |
| `workspace create --no-focus` and `tab create --no-focus` are supported | **Verified current surface and code** | Live help lists both flags; `bin/backends/herdr.sh:899-956` and `bin/backends/herdr.sh:1093-1167` pass them. First-workspace and steady-state focus behavior was not mutated/re-tested. |
| Destructive cleanup must use explicit named `session stop/delete`, never ambient `server stop` | **Verified current interface and donor guard** | Live help requires a positional session name for stop/delete; top-level help shows global `--session`. `bin/fm-herdr-lab.sh:1-25` and `bin/fm-herdr-lab.sh:109-154` enforce the rule. Historical ambient misrouting was not re-created. |
| Pane/workspace display metadata methods still exist | **Verified current** | Live protocol-17 schema exactly matched the documented required fields; current help exposes both `pane report-metadata` and `workspace report-metadata`. Adapter implementation: `bin/backends/herdr.sh:243-276`. |
| Native event subscription still exists | **Verified current schema and code** | Live schema contains `events.subscribe` and `pane.agent_status_changed`; request parameters require `subscriptions`. Reader and policy: `bin/backends/herdr-eventwait.py:1-142`, `bin/backends/herdr.sh:2037-2260`. There is still no `herdr events` CLI command. |
| Herdr 0.7.5 has an agent lifecycle facade | **Verified current** | Live help exposes `agent start`, `prompt`, `wait`, `get`, `read`, `send-keys`, etc. `agent prompt --wait` documents acknowledgement semantics. Donor intentionally does not use it. |
| Herdr CLI pane ids are bare, while donor task targets are session-prefixed | **Verified current** | Live `pane current` returned bare `w1B:p1F`; adapter parser at `bin/backends/herdr.sh:1378-1383` turns `default:w1B:p1F` into session `default` plus the original bare pane id. |

### Verified implementation claims

- Workspace naming is genuinely centralized in `fm_backend_herdr_workspace_label`; create/find/list-live receive the resolved label rather than re-deriving it (`bin/backends/herdr.sh:138-160`, `bin/backends/herdr.sh:788-818`, `bin/backends/herdr.sh:937-958`, `bin/backends/herdr.sh:2006-2017`).
- Metadata is genuinely best-effort and lifecycle-neutral; all schema/report failures are swallowed and no agent authority call is made (`bin/backends/herdr.sh:243-276`).
- Adopted workspaces cannot authorize default-tab pruning because only a same-call create response populates the seeded-tab id (`bin/backends/herdr.sh:842-956`).
- A same-labeled restored husk is created-over-before-close and only `dead`/`no-agent` can authorize replacement; `live`/`unknown` refuse (`bin/backends/herdr.sh:982-1167`).
- Submit types text once and retries Enter only, never text (`bin/backends/herdr.sh:1794-1822`).
- Unknown native state never authorizes destructive liveness recovery (`bin/backends/herdr.sh:982-1072`).
- Event push is a latency optimization, not an authority replacement: capability failures return to polling and the normalized transition policy remains deterministic (`bin/backends/herdr.sh:2037-2260`, `bin/fm-transition-lib.sh:1-112`).
- Optional presentation journals/tokens do not select send, capture, kill, or recovery endpoints; ambiguous states fall back flat or refuse duplicates (`bin/backends/herdr.sh:1169-1377`).
- Away-mode terminal cleanup closes an exact recorded pane, not a matching label or broad workspace sweep (`bin/fm-afk-launch.sh:179-250`, `bin/fm-afk-launch.sh:357-409`).
- The lab helper independently blocks default-session destructive calls and checks the default session before/after (`bin/fm-herdr-lab.sh:1-25`, `bin/fm-herdr-lab.sh:81-154`, `bin/fm-herdr-lab.sh:220-280`).

### Prose-sourced or historical claims not reverified on 0.7.5

The following remain useful evidence, but they must not be presented as current live verification:

- Bare socket calls do not auto-start a stopped server (`docs/herdr-backend.md:377`).
- Workspace and tab labels are non-unique in current Herdr (`docs/herdr-backend.md:165-171`, `docs/herdr-backend.md:378`).
- `send-text` never submits, `pane run` always submits atomically, and Ctrl-C aliases immediately interrupt foreground work (`docs/herdr-backend.md:379-381`).
- Closing a tab's only pane closes the tab; closing a workspace's last tab removes the workspace (`docs/herdr-backend.md:386-387`).
- `workspace create` still returns the exact seeded tab/root-pane shape used by the prune (`docs/herdr-backend.md:332-340`).
- `--no-focus` still cannot prevent focus on the first workspace in an empty session and steady-state creates remain focus-neutral (`docs/herdr-backend.md:153-163`).
- Herdr 0.7.5 still steals focus when a non-focused projected workspace's last pane closes (`docs/herdr-backend.md:248-255`).
- Named-session restart still preserves workspace/tab/pane ids while replacing agents with shells (`docs/herdr-backend.md:631-661`).
- ANSI capture still preserves every supported harness's ghost styling exactly as 0.7.3 did (`docs/herdr-backend.md:963-1053`, `docs/herdr-backend.md:1137-1181`).
- `tput cols` remains stale when called inside a Herdr-launched script (`docs/herdr-backend.md:933-936`).
- The open OpenCode 1.18.4 busy-queued Enter behavior still reproduces on Herdr 0.7.5 (`docs/herdr-backend.md:1288`).

## 3. Verdict per mechanism

“Already have it?” was checked against all three specified current surfaces:

- Claude persona: `~/.claude/commands/Themis.md:40-49`.
- Pi package: `../Config/packages/pi-themis/extensions/themis.ts:69-82`.
- OMP package: `../Config/packages/omp-themis/src/main.ts:110-125` and `../Config/packages/omp-themis/skills/themis-pm/SKILL.md:13-22`.

| Mechanism | Verdict | Why | Already have it? |
| --- | --- | --- | --- |
| M1 runtime auto-detection / backend selection | **strip** | Herdr is the only retained session backend, so multi-backend precedence, experimental notices, and tmux fallback serve dropped backends. | **partial** — Pi/OMP merely “prefer Herdr when already inside `HERDR_ENV`” (`pi-themis/extensions/themis.ts:77-78`; `omp-themis/src/main.ts:120-121`); none implements session operations. |
| M2 version/protocol/capability gates | **rebuild** | Preview drift remains real, but a Herdr-only implementation should pin current required capabilities rather than preserve a generic backend floor and several legacy compatibility branches. | **absent** — all three surfaces mention Herdr but perform no version, protocol, schema, or tool gate. |
| M3 explicit session wrapper / server readiness | **copy** | Explicit `--session` on every call is a verified safety invariant independent of the dropped backends; the bounded headless-server readiness loop is also Herdr-native. | **absent** — no shared Herdr CLI wrapper or server lifecycle owner exists in the three surfaces. |
| M4 workspace-per-project / tab-per-task | **rebuild** | Keep the decided shape, but replace donor labels/persona vocabulary and integrate it with the new durable project/task model. Describe workspaces as reusable while nonempty. | **partial** — Claude requires one labeled tab per agent (`~/.claude/commands/Themis.md:47-49`); Pi/OMP also require tab labels (`pi-themis/extensions/themis.ts:82`; `omp-themis/src/main.ts:125`). None defines workspace-per-project, one-pane-per-task, or reuse. |
| M5 label adoption / duplicate prevention | **rebuild** | Duplicate prevention is required, but first-match adoption of a mutable user-owned label is too weak for the new implementation. Prefer exact volatile ids plus explicit ownership metadata/tokens, with labels display-only. | **absent** — none of the three tracks Herdr ids, ownership, duplicates, or recovery. |
| M6 seeded-default-tab prune | **copy** | The created-versus-adopted authority and create-before-close ordering encode a real destructive incident and remain valid if the current create/cascade behavior is reverified first. | **absent** — the current Themis surfaces issue only generic tab-label guidance. |
| M7 endpoint/meta contract | **rebuild** | Volatile runtime state stays local by decision, but a Herdr-only system should store explicit `session/workspace/tab/pane` fields directly instead of preserving a generic tmux-shaped `window=` target. | **absent** — no task endpoint state exists in the persona, Pi package, or OMP package. |
| M8 display metadata | **rebuild** | Best-effort capability gating is good, but `source firstmate`, `fm_*` tokens, Fleet/Archon labels, and donor task descriptions conflict with the new persona vocabulary and project model. | **absent** — tab naming exists, but neither Pi nor OMP reports Herdr pane/workspace metadata. |
| M9 low-level send/submit acknowledgement | **rebuild** | The capability is required, but 0.7.5's `agent prompt --wait` should be evaluated before porting the manual Enter/composer state machine and its open OpenCode bug. Retain low-level keys only for dialogs/interrupts that the facade cannot express. | **absent** — all three describe orchestration but implement no Herdr prompt/send acknowledgement. |
| M10 capture/composer safety | **rebuild** | Inspection and safe injection may remain necessary, but the 200-line workaround is stale on 0.7.5 and the structural classifier is coupled to donor away-mode injection. Keep only behavior demanded after testing the agent facade. | **absent** — no pane capture or composer classifier exists. |
| M11 busy/liveness/husk handling | **rebuild** | Deterministic liveness is explicitly retained, but current 0.7.5 reports working during tool calls and offers richer agent commands; preserve fail-safe `unknown` and husk classification without blindly copying historical fallback assumptions. | **partial** — Claude prose promises heartbeat check-ins (`~/.claude/commands/Themis.md:47`), but none has deterministic Herdr liveness, error-code classification, or restored-husk recovery. |
| M12 list-live recovery / exact-pane teardown | **rebuild** | Recovery and exact cleanup are required, but mutable label discovery should be a fallback under authoritative local ids, not the primary ownership signal. | **absent** — no Herdr endpoint registry or cleanup implementation exists. |
| M13 native blocked-event push | **rebuild** | Keep deterministic status policy and polling fallback, but a Herdr-only system can remove the generic backend abstraction and wire the native stream directly to the new supervision loop. | **absent** — no current Themis surface subscribes to Herdr events. |
| M14 optional presentation workspaces / raw move | **strip** | The decided durable model is workspace-per-project/tab-per-task. The default-off projection adds raw-socket code, locks, journals, focus workarounds, orphan spaces, and manual cleanup without task authority. | **absent** — none of the three implements projected spaces or raw workspace ordering. |
| M15 separate away-daemon workspace | **strip** | It serves the donor's away-mode daemon, which is not present in the inspected Themis surfaces and is not among the explicitly retained external dependencies. Reintroduce only if a future supervision design independently requires it. | **absent** — no away-mode daemon or terminal lifecycle exists in the persona, Pi, or OMP packages. |
| M16 guarded Herdr lab | **copy** | Safe isolated verification remains essential for the only retained backend; explicit named destructive calls and a default-session tripwire directly prevent a proven loss incident. | **absent** — no equivalent lab/session safety helper exists in the three inspected surfaces. |

## 4. Coupling notes

1. **Do not copy `bin/backends/herdr.sh` as a standalone adapter.** It sources `bin/fm-composer-lib.sh` and `bin/fm-transition-lib.sh`, calls the project registry parser, and is dispatched through `bin/fm-backend.sh`. Its return vocabularies (`empty/pending/unknown/send-failed`, `busy/idle/unknown`, `dead/no-agent/live/unknown`) are shared contracts, not local implementation details.

2. **Container creation and seeded-tab prune must remain in one authority chain.** `workspace_ensure` must communicate whether it created or adopted the workspace and the exact seeded tab id. Re-deriving prune eligibility from label or shape repeats the 2026-07-02 self-kill.

3. **Create-before-close is required in two places.** Both seeded-tab pruning and restored-husk replacement rely on another real tab existing before close, because the provider historically removes an empty workspace.

4. **Labels are presentation, not ownership.** The donor violates this partially by adopting the first matching workspace label. Its projection subsystem is more conservative: tokens and labels are correlation only and never authorize destructive action. The port should apply that stricter rule to ordinary project workspaces too.

5. **Session ids and pane ids have different shapes.** Herdr CLI takes bare pane ids such as `w1B:p1F`; donor task targets prefix a session (`default:w1B:p1F`). Passing the prefixed form directly to `herdr pane get` is wrong. Always parse on the first colon and pass the remainder intact.

6. **Explicit `--session` belongs on every CLI call.** The historical environment-only misrouting was destructive. Do not preserve the document's normal-versus-destructive wording split.

7. **The “persistent workspace” has no keeper.** Exact-pane teardown can delete the last task tab and therefore the workspace. Any local record must tolerate recreation and id changes after a fully idle project.

8. **Submit and composer logic are one coupled safety system.** The pre-injection affirmative-empty check, type-once rule, Enter-only retry, native state acknowledgement, and fallback composer read prevent opposite failure modes: overwriting pending input versus silently leaving a message unsent. Replacing one piece requires end-to-end tests for both directions.

9. **The 0.7.5 agent facade may collapse several donor mechanisms, but not automatically.** `agent prompt --wait` could replace much of literal-send/Enter polling; it does not by itself prove how to handle trust dialogs, slash completion, interrupts, half-typed human input, or a supervisor pane that is not a registered agent. Those cases need explicit design and tests.

10. **Busy state and liveness are not the same predicate.** An idle/blocked registered agent is alive. A pane with no registered agent is a restored husk. Unknown must never be converted to dead.

11. **Event push never replaces polling.** The subscriber is edge-triggered, has no previous-state field, and can fail at schema, socket, subscribe, or runtime stages. Subscribe-before-level-reconcile plus permanent polling prevents the connection gap from losing a blocked state.

12. **Blocked-event policy is coupled to task kind and pause semantics outside the adapter.** `bin/fm-watch.sh` excludes persistent supervisor endpoints from the fast path and applies declared-pause rules. Copying only the socket reader would change behavior.

13. **Workspace movement has no CLI in 0.7.5.** The donor's optional ordering reaches a private-looking but schema-published socket method through Python. Keeping projection means inheriting raw protocol, socket resolution, response validation, focus snapshots, and per-session locking as one unit.

14. **Projection journals deliberately do not authorize cleanup.** This makes crashes safe but guarantees orphan visual spaces and manual cleanup. Any attempt to “improve cleanup” by matching labels/tokens would reverse the safety model.

15. **Away-mode terminal launch depends on exact supervisor routing.** The daemon pane must receive `FM_SUPERVISOR_TARGET` for the original operator pane; otherwise it injects into itself. Closing must use the exact recorded pane, not enumerate similarly labeled workspaces.

16. **The lab helper is the owner of destructive verification.** Its validation, explicit named calls, and before/after default-session tripwire must not be split among ad hoc test scripts.

17. **Current Themis surfaces disagree with the donor's container assumptions.** Claude says agents occupy their own tabs but also allows up to four agents as splits in a 2x2 tab (`~/.claude/commands/Themis.md:47`); Pi/OMP prefer their native subagents and only optionally use Herdr (`pi-themis/extensions/themis.ts:77-82`, `omp-themis/src/main.ts:120-125`). The inherited workspace-per-project/tab-per-task decision requires one new canonical implementation contract; prose in three packages is not sufficient.

18. **Vocabulary must be rewritten, not merely copied.** `firstmate`, captain, crewmate, Fleet, and Archon appear in adapter labels, metadata sources/tokens, comments, journals, and daemon messages. The scout brief explicitly drops that vocabulary while retaining Themis reporting to Ed.

## 5. What you could not determine

1. **Whether 0.7.5 fixed the non-focused last-pane focus steal.** Reproduction requires creating and closing workspaces/panes, which the assignment prohibited. The adapter still carries focus snapshot/restore logic based on 0.7.4 evidence.

2. **Whether 0.7.5 still permits duplicate workspace/tab labels.** Verifying this requires creating duplicate topology. The adapter assumes non-uniqueness and protects task tabs, but ordinary workspace lookup still adopts the first matching label.

3. **Whether 0.7.5 still seeds `workspace create` with the exact response shape expected by the prune, and whether closing the final pane still cascades through tab/workspace deletion.** Both require mutation. They must be reverified before copying M6.

4. **Whether `--no-focus` behavior is unchanged, including the unavoidable first-workspace focus.** Help confirms the flags exist, not their runtime effect.

5. **Whether named-session stop/restart still preserves workspace/tab/pane ids and restores agent-free shells.** The historical evidence is strong, but a current test requires stopping and restarting a session.

6. **Whether all supported harnesses now report `working` throughout long foreground tools.** The live 0.7.5 probe disproved the broad old claim for the current Claude integration, but it did not test Pi, OMP, OpenCode, Codex, Grok, or a full no-mistakes run.

7. **Whether OpenCode 1.18.4's busy-queued Enter bug remains on 0.7.5.** The current pane was Claude and no input was allowed. Treat the gap as open until an isolated lab test proves otherwise.

8. **Whether ANSI ghost styling remains stable for every harness.** `--format ansi` exists, but validating ghost/real-input distinction requires driving composers and capturing their styled output.

9. **Whether the `tput cols` discrepancy remains in 0.7.5.** Reproduction requires launching a script into a pane, which was prohibited.

10. **Whether the defensive `dead`-but-still-listed husk path can occur on a real current binary.** The document itself says it has only unit coverage and has never been reproduced against Herdr.

11. **Whether `agent prompt --wait` fully replaces the donor's submit state machine for all supported agents.** Help establishes the API and acknowledgement contract, but no prompt was sent. Trust dialogs, autocomplete, existing working turns, and pending human input need isolated behavioral tests.

12. **Whether display metadata survives a server restart in 0.7.5.** The current schema matches, but restart behavior was not probed.

13. **The referenced quality-bar report was not present at `.agents/plans/2026-07-25-heartbeat-dissection-for-themis-persona.md` in this repository.** This report follows the required scout shape directly from `docs/plans/support/donor-map/SCOUT-BRIEF.md`.

## Consolidated known gaps and unresolved bugs

For port planning, this is the complete actionable set found in the donor document, including intentional limitations and stale entries:

| Gap / limitation | Current assessment | Port implication |
| --- | --- | --- |
| Small `pane read --lines N` returns empty | **Stale on installed 0.7.5** | Do not copy the 200-line workaround without a compatibility test. |
| `agent.get` reports idle during foreground tools | **Stale for current 0.7.5 Claude probe; unverified across all harnesses** | Keep conservative fallback until a harness matrix passes; rewrite the doc claim. |
| Matching workspace labels can silently adopt a user-owned workspace | **Open design hazard** | Rebuild ownership around exact local ids/explicit metadata; keep labels display-only. |
| Structural composer detection has no native cursor/composer-state primitive | **Open** (`docs/herdr-backend.md:598-606`) | Prefer 0.7.5 agent facade; retain a conservative classifier only where unavoidable. |
| Ghost detection depends on ANSI dim/dark styling surviving capture | **Open fail-safe dependency** (`docs/herdr-backend.md:1279-1281`) | Degradation must defer and alert, never treat styled text loss as empty. |
| A submit-active transition could start and finish between polling samples | **Residual race** (`docs/herdr-backend.md:1067-1080`) | Evaluate `agent prompt --wait`; if manual polling remains, preserve type-once and bounded uncertainty. |
| OpenCode busy-queued Enter is reported as pending although accepted | **Explicitly open** (`docs/herdr-backend.md:1288`) | Block low-level submit port until fixed or bypassed via agent facade. |
| Persistent supervisor death is not detected mid-session | **Not implemented** (`docs/herdr-backend.md:1285-1287`) | Add a deterministic periodic liveness path if persistent supervisors remain in the new design. |
| `dead` husk branch lacks real-binary reproduction | **Coverage gap** (`docs/herdr-backend.md:659-661`, `docs/herdr-backend.md:1276-1278`) | Keep fail-safe classification, but label the branch defensive rather than empirically verified. |
| Projection crashes/renames can leave stale spaces; no cross-home cleanup; manual UI cleanup only | **Intentional unresolved limitation** (`docs/herdr-backend.md:269-276`) | Strip the optional projection rather than inherit its orphan-management burden. |
| 0.7.4 last-pane projection cleanup can steal focus | **Mitigated, not reverified on 0.7.5** (`docs/herdr-backend.md:248-257`) | Irrelevant if projection is stripped; otherwise retain exact snapshot/restore until current verification. |
| First workspace may focus despite `--no-focus` | **Historical provider limitation, current status unknown** (`docs/herdr-backend.md:153-163`) | Treat first topology creation as focus-affecting until current isolated evidence says otherwise. |
| Herdr-launched scripts may see stale `tput cols` | **Historical test-harness sharp edge** (`docs/herdr-backend.md:933-936`) | Avoid terminal-width-dependent synthetic composer fixtures; current provider status unknown. |
| Herdr has no CLI for `workspace.move` or event subscribe | **Still current in 0.7.5** | Raw socket code is required only if projection/event streaming is kept; events are worth rebuilding, projection is not. |
| Herdr-specific status-line flash for wedge alarms is absent | **Intentional UI limitation** (`docs/herdr-backend.md:917-918`) | Use backend-independent alerting; do not recreate tmux cosmetics. |
