# 09 - Escalation, vocabulary, state, and config

Scout assignment 9. Read-only. Sources: `AGENTS.md` sections 1, 2, 9, 12; `docs/configuration.md`; `bin/fm-update.sh`; `bin/fm-ff-lib.sh`; `bin/fm-config-inherit-lib.sh`; `bin/fm-classify-lib.sh`; `bin/fm-teardown.sh`; `bin/fm-brief.sh`; `bin/fm-marker-lib.sh`; `tests/fm-captain-translation-contract.test.sh`; live `state/` inventory.

Adjacent reports relied on and not re-derived: **00** (status-log-vs-current-state, wake vocabulary, self-liveness), **01** and **02** (herdr adapter labels and metadata vocabulary), **04** (brief-side decision-key gap). Cited inline where used.

---

## 0. Headline

1. **The translation rule is enforced as a document, not as behavior - and the document enforcement is the part worth stealing.** `tests/fm-captain-translation-contract.test.sh:27-139` is a CI test that asserts section 9 contains the mapping list verbatim, that eight named skills *point at* section 9, and that **none of them duplicates the mapping list** (`:129-139`). Nothing anywhere inspects an outgoing message. We have three hand-maintained persona copies with no generator (report 00 §0); this single-owner-plus-cross-reference test is the cheapest available fix for exactly that drift.

2. **Vocabulary is compiled into a validation predicate that fails the whole propagation path.** `shared_captain_header_valid` (`bin/fm-config-inherit-lib.sh:158-166`) requires the literal strings `main-authoritative`, `read-only in secondmate homes`, `must not be edited there`, and **`main firstmate`** in the first 12 lines of `data/captain-shared.md`, and `propagate_shared_captain_preferences:280-285` returns error and refuses to propagate when they are absent. A prose-only rename leaves this predicate rejecting every renamed file.

3. **Two of the six reach-immediately triggers have no detector at all.** "Anything destructive, irreversible, or security-sensitive" and "a needed credential or login" (`AGENTS.md:402-403`) appear in `bin/` only as brief text telling the *worker* to stop (`bin/fm-brief.sh:282,404`) and as unrelated domain refusals (`fm-herdr-lab.sh:113`, `fm-teardown.sh`). The only credential probe is bootstrap's one-shot `gh auth status` (`bin/fm-bootstrap.sh:835`). The four verb-shaped triggers are detected in code (`fm-classify-lib.sh:45,101-117`); the two highest-stakes ones are pure model judgment.

4. **Volatile state has no garbage collection.** `bin/fm-teardown.sh:1277` removes exactly five per-task files and nothing else. `.hash-*`, `.count-*`, `.seen-*`, `.hb-surfaced-*`, `.heartbeat-streak` are never deleted by any script (grep for a deletion of those patterns returns empty; only `.stale-*` and `.wedge-escalations-*` are cleared, at `fm-watch.sh:324,367,409,466`). Live evidence: **518 files in `state/`, one live task meta.** For a system whose prime directive is not losing work, the leak is benign - but it means "volatile" here means "unreadable", not "cleaned up".

5. **The donor has our VOLATILE/DURABLE classification but not our commit split, and its durable tier is not committable as-is.** `data/` is gitignored as a whole (`.gitignore:3`, `AGENTS.md:75`), and its durable records embed machine-local absolute paths: `data/secondmates.md` carries `(home: /abs/path; ...)` parsed by `fm-ff-lib.sh:240`, and `data/projects.md` is a local clone registry (`fm-project-mode.sh`). Committing the durable tier is our decision with no donor precedent; it needs a path-scrubbing step the donor never had to write.

---

## 1. Mechanism inventory

### Escalation contract

**E1. The outcome-translation rule and mapping table.**
Every captain-facing message must be rewritten from internal state into outcome, consequence, and next decision, using a fixed noun set and an eleven-row rewrite table. `AGENTS.md:369-390`. Depends on nothing at runtime; the model is the only executor. Depended on by eight skills that defer to it rather than restate it (list in E2). Stated reason (`:369`): "Talk in outcomes, not mechanics."

The full table, verbatim from `AGENTS.md:376-386`:

| Internal label | Required rewrite |
|---|---|
| worktree, checkout, primary checkout, local-main | local copy, isolated copy, or local branch - only if the location matters |
| teardown | cleanup |
| wake, watcher, heartbeat, stale, signal, check | notification, monitoring, waiting too long, or stopped responding |
| hold, gate, ask-user, needs-decision, blocked, paused | the concrete decision, wait, approval, blocker, or external delay |
| done, failed, fix-review, checks-passed, cancelled, validation step, pipeline state | the concrete result, review finding, passing checks, failed check, or stopped validation |
| brief | instructions |
| crewmate | worker - only when naming the helper matters |
| harness, backend, runtime, adapter | worker runtime or tool - only when the tool choice itself blocks work |
| status file, metadata, state, task id, raw path | durable record, local record, or omit unless the captain needs the path to act |
| fail-closed, fails closed, fail loudly, refuses loudly | stops safely when something goes wrong / refuses rather than proceeding / reports the concrete missing requirement |
| fail-open, fails open, passive fail-open, degraded-open | steps aside and lets work continue when the check cannot complete / continues without that optional protection |

Three qualifiers ride with it and matter as much as the rows:

- **A ban list, separate from the table** (`:372`): startup machinery, locks, watchers, polling, crewmates, task ids, briefs, worktrees, checkouts, status/metadata files, teardown, promotion, harness names, runtime backend names, context budgets, delivery-mode names, autonomy flags, wake types, status prefixes, decision holds, pipeline step names, validation-state labels, and compressed safety labels.
- **A deliberate exemption** (`:373`): "Scout and second mate are accepted Firstmate nautical house vocabulary and do not need translation." The house vocabulary is not uniformly banned; two terms are ratified as user-facing.
- **The evidence/chat split** (`:388-390`): private evidence reports keep exact identifiers, paths, status lines, and internal terms; only the chat summary pointing at the report is translated. This is what makes the rule survivable - precision is preserved somewhere.

**E2. The documentation-integrity gate.**
`tests/fm-captain-translation-contract.test.sh` is a static test, run by the repo's own behavior suite (`docs/configuration.md:110-113` wires `.no-mistakes.yaml` `commands.test` to run every `tests/*.test.sh`, mirroring `.github/workflows/ci.yml`). It enforces four distinct things:

- Section 9 still contains the positive contract sentence, the noun requirement, and the mapping-list preamble (`:27-37`).
- The scout/second-mate exemption survives, and specific bad rewrites are *absent* - `scout -> investigation` and `secondmate -> domain supervisor` are asserted **not** to appear (`:39-51`). A negative assertion protecting deliberate vocabulary.
- Nine named high-risk mapping rows are present verbatim (`:73-89`), and five compressed safety labels have concrete plain renderings (`:53-71`).
- Eight skills reference section 9 at their captain-handoff point (`:103-127`), and **zero** of them contain the mapping-list preamble (`:129-139`).

Reason, from the file header (`:1-3`): "Static regression tests for the captain-facing plain-English translation contract owned by AGENTS.md section 9." The word "owned" is the design: one owner, everyone else points.

**E3. The reach-immediately list.**
Six triggers, `AGENTS.md:396-403`: work ready for review with full PR URL; finished investigation findings relayed as findings; gate findings needing a decision under the configured authority; a real blocker or failure after the playbook is exhausted; anything destructive, irreversible, or security-sensitive; a needed credential or login. Plus the suppression half (`:405-409`): never surface automatic fixes, retries, routine progress, or internal supervision mechanics; batch non-urgent updates; plain chat for yes/no, `lavish-axi` only for multi-option or structured reports; always the full `https://...` URL.

Detector coverage is uneven and this is the finding:

| Trigger | Machinery |
|---|---|
| Work ready for review | `done:` verb -> `status_is_captain_relevant` (`fm-classify-lib.sh:101`), plus `fm-pr-check.sh` arming the merge poll |
| Investigation findings | `done:` on a scout task; teardown gate requires `data/<id>/report.md` to exist (`fm-teardown.sh:28-31`) |
| Gate findings needing a decision | `needs-decision:` verb, detected (`fm-classify-lib.sh:45,113`) |
| Real blocker or failure | `blocked:` / `failed:` verbs, detected (same) |
| Destructive / irreversible / security-sensitive | **none.** Only brief text telling the worker to stop (`fm-brief.sh:282,404`) and unrelated local refusals |
| Needed credential or login | **none at runtime.** `gh auth status` once at bootstrap (`fm-bootstrap.sh:835`); `fm-pr-identity.sh:24` defines `credential-*` failure prefixes for one Atlas-specific path |

**E4. The captain-relevant detector (a different filter from E3).**
`status_is_captain_relevant` (`bin/fm-classify-lib.sh:101-117`) decides whether a status event *wakes the supervisor*. `FM_CLASSIFY_CAPTAIN_RE_DEFAULT` (`:45`) is `done:|needs-decision:|blocked:|failed:|PR ready|checks green|ready in branch|merged`. It is verb-aware: `working`, `resolved`, `captain-held`, and `paused` never match, even when their free text contains a token like "merged" (`:40-44` explains the exact false positive: `working: rebased onto merged #76`). The free-text tokens exist only for legacy bare lines.

The architecture worth naming: **E4 decides what reaches the supervisor; E1/E3 decide what reaches the principal.** Two filters, two vocabularies, one deliberately mechanical and one deliberately not. The status stream keeps internal verbs precisely so the mechanical filter can be exact; the translation happens one layer later, at the chat boundary.

**E5. Batching.**
In normal operation batching is model judgment ("Batch non-urgent updates into the next natural reply", `AGENTS.md:406`) with no mechanism. The only mechanical batching lives in the away-mode daemon: `FM_ESCALATE_BATCH_SECS=90` buffers a digest and `FM_MAX_DEFER_SECS=300` caps buffered age before retry plus a wedge alarm (`docs/configuration.md:434-435`). `FM_INJECT_SKIP=heartbeat` (`:433`) force-drops heartbeats from injection entirely. Away mode is out of scope for us per report 00 S7, but the constants record what the donor considered a tolerable escalation latency.

**E6. Pause versus blocked as an escalation-suppression primitive.**
`paused:` is deliberately excluded from the captain-relevant set (`fm-classify-lib.sh:47-57`): it means "stop wedge-nagging this idle pane", not "work to keep surfacing", and it re-surfaces once per `FM_PAUSE_RESURFACE_SECS` (3600s) so a forgotten pause cannot rot invisibly (`:60-67`). Covered in depth by report 00 §A1; listed here because it is the only *suppression* verb in the escalation vocabulary and the translation table maps it away (`AGENTS.md:379`).

### Vocabulary boundary

The question was whether the captain/first-mate framing is prose-only. It is not. It reaches six surfaces, three of which break silently on a partial rename.

**V1. Wire verbs in the status protocol.**
`captain-held` is a status verb written to `state/<id>.status` by `bin/fm-decision-hold.sh:330` (`printf 'captain-held [key=%s]: tracked by %s\n'`) and parsed by `fm-classify-lib.sh:74,107,140`, `fm-watch.sh:944`, and `fm-supervise-daemon.sh:379,1234`. It is one constant (`FM_CLASSIFY_CAPTAIN_HELD_VERB_DEFAULT`) with an env override, so the rename is one line - but every already-written status line in a live `state/` uses the old literal, and the backlog `tasks-axi hold --kind captain` verb (`AGENTS.md:416`) is a separate spelling of the same word in a different tool.

**V2. The inter-agent wire marker (the highest-risk instance).**
`FM_FROMFIRST_LABEL='[fm-from-firstmate]'` (`bin/fm-marker-lib.sh:42`), followed by U+2063 INVISIBLE SEPARATOR (`:46`). Written by `fm-send.sh` when the primary relays work to a secondmate; **taught to the receiving agent by the generated charter text** (`bin/fm-brief.sh:162`). It is a two-sided protocol: the sender prepends the literal, the receiving LLM is told to look for that exact literal, and the semantic difference is total - marked means "answer through the status path", unmarked means "the human is typing, answer conversationally" (`fm-marker-lib.sh:14-23`). Rename one side and marked requests degrade into chat replies that strand unseen, with no error anywhere.

**V3. Generated brief text.**
The scaffold every worker reads is saturated: "You are a crewmate: an autonomous worker agent managed by firstmate" (`fm-brief.sh:254`), "You are a persistent second mate managed by the main firstmate" (`:139`), "A message with NO marker is the captain typing directly into your pane" (`:167`), "Report only true captain-relevant outcomes" (`:171`), plus firstmate-named lifecycle instructions at `:248,274,276,281,283,296,326,332,339`. This is the donor's identity reaching every dispatched agent, and report 04 owns the brief's contents in detail.

**V4. Validation predicates and config keys.**
- `shared_captain_header_valid` requires the literal `main firstmate` in the propagated file's header, or propagation errors (`fm-config-inherit-lib.sh:164`, enforced at `:280-285`). See headline 2.
- Config file names: `config/crew-harness`, `config/crew-dispatch.json`, `config/secondmate-harness`, all in `.gitignore:12-14` and read by `fm-harness.sh` / `fm-spawn.sh`.
- Meta field values: `kind=secondmate` is the liveness selector scanned by `live_secondmate_meta_records` (`fm-ff-lib.sh:257`) and by bootstrap's inheritance discovery (`docs/configuration.md:269`).
- CLI flag `--secondmate` (`fm-spawn.sh:5`).
- Environment variable `FM_CAPTAIN_RE` (`docs/configuration.md:408`), a documented operator-facing knob.
- Home marker file `.fm-secondmate-home` (`fm-ff-lib.sh:27`), whose *contents* are the secondmate id and whose absence fails `validate_secondmate_home` (`:171-179`).

**V5. Backend and workspace labels.**
`printf '%s-Fleet'` (`bin/backends/herdr.sh:156`) and `printf 'Archon-%s'` / bare `Archon` (`:145,149`), plus a jq label matcher `test("^.+-Fleet$")` (`:618`) and a task-id stripper for `2ndmate-*/`, `Archon-*/` prefixes (`:368`). The hometag prefixes are literal `firstmate` and `2ndmate-<id>` (`bin/fm-backend-hometag-lib.sh:16`), and zellij's default session name is literally `firstmate` (`docs/configuration.md:368`). Labels are both written and parsed, so a rename is a two-sided change against live herdr state. Reports **01:223** and **02:299** already catalogue this surface; I am citing rather than re-deriving.

**V6. Names of files, scripts, skills, and functions.**
`bin/fm-crew-state.sh`; skills `stuck-crewmate-recovery`, `secondmate-provisioning`, `updatefirstmate`, `firstmate-orca`, `firstmate-codexapp`, `firstmate-coding-guidelines`; functions `status_is_captain_relevant`, `status_is_paused_or_captain_held`, `scan_captain_relevant_statuses`, `mark_all_captain_relevant_surfaced` (`fm-watch.sh:614`), `crew_absorb_class`, `crew_is_provably_working`, `validate_secondmate_home`, `fm_message_from_firstmate`. Also the `fm-` prefix itself: task window labels `fm-<id>`, branch names `fm/<id>` (`fm-brief.sh:332`), and the `fm-<id>` selector used for nudges (`fm-update.sh:27`).

Verdict on the boundary question: **the rename is a protocol migration, not a find-and-replace.** V1, V2, V4, and V5 are read back by code or by another agent; V3 and V6 are one-directional and safe to rewrite freely.

### State inventory (VOLATILE / DURABLE)

**S1. The classification is already drawn in code, in one line.**
`bin/fm-teardown.sh:1277` is the whole of task-scoped volatile cleanup:

```
rm -f "$STATE/$ID.status" "$STATE/$ID.turn-ended" "$STATE/$ID.meta" "$STATE/$ID.pi-ext.ts" "$STATE/$ID.grok-turnend-token"
```

with a second removal at `:268` for `$id.check.sh`, `$id.pr-poll`, and companions, and `:1091` for a secondmate's child tasks. `data/<id>/` is never touched by teardown. That is the boundary: **`state/` dies with the task, `data/` outlives it.** The header states the intent (`:1-5`): "kill the recorded runtime endpoint, clear volatile state ... the report at `data/<task-id>/report.md` is the work product."

**S2. Full inventory.** Every entry from `AGENTS.md:56-111`, classified, with what writes and what reads it.

| Entry | Class | Written by | Read by |
|---|---|---|---|
| `.env` (`:65`) | DURABLE-local, secret | operator | X-mode bootstrap gate (`docs/configuration.md:275,280`) |
| `config/crew-harness` (`:66`) | DURABLE-local | operator / firstmate | `fm-harness.sh`; inherited by `fm-config-inherit-lib.sh:43` |
| `config/crew-dispatch.json` (`:67`) | DURABLE-local | operator / firstmate | firstmate LLM (rules are natural language, `configuration.md:192-193`); presence enforced by `fm-spawn.sh` (`:194`); inherited |
| `config/secondmate-harness` (`:68`) | DURABLE-local | operator | `fm-harness.sh secondmate-model/-effort`; **not** inherited (`fm-config-inherit-lib.sh:29-32`) |
| `config/backlog-backend` (`:69`) | DURABLE-local | operator | bootstrap + backlog paths; inherited |
| `config/backend` (`:70`) | DURABLE-local | operator | `fm-spawn.sh` backend resolution; **not** inherited (`configuration.md:85`) |
| `config/herdr-presentation-spaces` (`:71`) | DURABLE-local | operator | herdr adapter; inherited |
| `config/cmux-socket-password` (`:72`) | DURABLE-local, secret | operator | cmux adapter (strip) |
| `config/wedge-alarm` (`:73`) | DURABLE-local | operator | `fm-supervise-daemon.sh` (strip with AFK) |
| `config/x-mode.env` (`:74`) | VOLATILE, generated | `fm-bootstrap.sh` (`configuration.md:284`) | watcher process env (strip) |
| `data/backlog.md` (`:76`) | **DURABLE** | `tasks-axi` or hand edit (`.tasks.toml`) | `fm-session-start.sh` digest; `fm-fleet-snapshot.sh`; `fm-backlog-handoff.sh` |
| `data/captain.md` (`:77`) | **DURABLE** | firstmate LLM, inspect-then-update (`configuration.md:117-118`) | `fm-session-start.sh` |
| `data/captain-shared.md` (`:78`) | **DURABLE** | primary LLM | `fm-config-inherit-lib.sh:263`; `fm-session-start.sh` |
| `data/learnings.md` (`:79`) | **DURABLE** | firstmate LLM, lazily created | `fm-session-start.sh` |
| `data/projects.md` (`:80`) | **DURABLE**, machine-local paths | firstmate / `project-management` | `fm-project-mode.sh`, `fm-brief.sh`, `fm-spawn.sh`, `fm-home-seed.sh` |
| `data/secondmates.md` (`:81`) | **DURABLE**, machine-local paths | `fm-home-seed.sh` | `fm-update.sh:72-82`, `fm-ff-lib.sh:234-246` |
| `data/<id>/brief.md` (`:82`) | DURABLE (task input record) | `fm-brief.sh` | `fm-spawn.sh` at launch; survives teardown |
| `data/<id>/project-key` (`:83`) | DURABLE (task input record) | `fm-brief.sh` | `fm-spawn.sh`, `fm-pr-identity.sh`; survives teardown |
| `data/<id>/report.md` (`:84`) | **DURABLE - the deliverable** | the worker | firstmate; teardown gate requires it (`fm-teardown.sh:28-31`) |
| `projects/` (`:85`) | VOLATILE-derivable | `project-management` clone, `fm-fleet-sync.sh` refresh | workers via worktrees; read-only to firstmate (hard rule 1) |
| `state/<id>.status` (`:87`) | VOLATILE | the worker (append-only) | `fm-classify-lib.sh`, `fm-crew-state.sh`, `fm-watch.sh`; removed `:1277` |
| `state/<id>.turn-ended` (`:88`) | VOLATILE | turn-end hooks | `fm-wake-lib.sh`, `fm-watch.sh`; removed `:1277` |
| `state/<id>.grok-turnend-token` (`:89`) | VOLATILE | `fm-spawn.sh` | grok hook; removed `fm-teardown.sh:207,1277` |
| `state/<id>.meta` (`:90`) | VOLATILE | `fm-spawn.sh`; appended by `fm-pr-check.sh`, `fm-x-link.sh` | nearly every script; removed `:1277` |
| `state/<id>.pi-ext.ts` | VOLATILE, **undocumented** | `fm-spawn.sh:1259` | Pi at launch; removed `:1277` |
| `state/<id>.herdr-presentation` (`:91`) | VOLATILE | herdr projection path | never authoritative (`AGENTS.md:91`); removed `fm-teardown.sh:1258` |
| `state/<id>.check.sh` `.check-trust` `.pr-poll` `.pr-poll-registration` (`:92-95`) | VOLATILE | `fm-pr-check.sh`, `fm-check-register.sh` | `fm-watch.sh` dispatch, `fm-check-lib.sh`; removed `:268` |
| `state/.pr-check-quarantine/`, `.pr-check-migration*` (`:96-98`) | VOLATILE, migration scar | `fm-pr-check-migrate.sh` | bootstrap migration gate |
| `state/x-watch.check.sh`, `x-inbox/`, `x-context/`, `x-outbox/`, `x-poll.*` (`:99-103`) | VOLATILE, generated | `fm-bootstrap.sh`, `fm-x-poll.sh` | watcher, `fmx-respond` (strip, report 00 S4) |
| `state/.wake-queue`, `.wake-queue.lock` (`:104,106`) | VOLATILE | `fm-wake-lib.sh` | `fm-wake-drain.sh`, `fm-session-start.sh`, `fm-supervise-daemon.sh` |
| `state/.afk` (`:105`) | VOLATILE | `/afk` skill, `fm-afk-start.sh` | `fm-guard.sh`, `fm-watch.sh`, `fm-turnend-guard.sh` |
| `state/.watch.lock` (`:106`) | VOLATILE | `fm-watch.sh`, `fm-watch-arm.sh` | same, plus `fm-continuity-pretool-check.sh` |
| `state/.hash-* .count-* .stale-* .stale-since-* .paused-* .wedge-escalations-* .seen-* .hb-surfaced-* .last-* .heartbeat-streak` (`:107`) | VOLATILE | `fm-watch.sh` | `fm-watch.sh` only; "never touch" |
| `state/.watch-triage.log` (`:108`) | VOLATILE, disposable | `fm-watch.sh` | nothing; "safe to delete" |
| `state/.last-watcher-beat` (`:109`) | VOLATILE | `fm-watch.sh:811` | `fm-supervision-lib.sh`, `fm-guard.sh`, `fm-watch-arm.sh` (report 00 B1/B2) |
| `state/.subsuper-*`, `.supervise-daemon.*` (`:110`) | VOLATILE | `fm-supervise-daemon.sh` | same (strip with AFK) |
| `state/.lock` | VOLATILE, **not in the §2 tree** | `fm-lock.sh` | session-start lock step (`AGENTS.md:126`) |
| `state/.fm-inherited-config-reread*`, `.fm-inherited-config.lock` | VOLATILE | `fm-config-inherit-lib.sh:447-452` | same lib; generically described at `configuration.md:14` |
| `.no-mistakes/` (`:111`) | VOLATILE, evidence | no-mistakes CLI | no-mistakes; CI rejects tracked entries (`configuration.md:111`) |

**S3. No GC for the marker families.**
Grepping every `bin/*.sh` for a removal of `.hash-`, `.count-`, `.seen-`, or `.hb-surfaced-` returns nothing. Only `.stale-*`, `.stale-since-*`, and `.wedge-escalations-*` are cleared, and only on state transitions inside the watcher (`fm-watch.sh:324,367,409,466`). The live directory confirms the consequence: `ls -A state | wc -l` = **518**, against one `.meta`, one `.status`, one `.turn-ended`. Roughly 300 of those are `.seen-<task-id>` and `.hb-surfaced-<task-id>` markers for tasks torn down weeks ago. Nothing reads them again, and nothing removes them.

**S4. The layout doc is not actually the single owner it claims to be.**
`AGENTS.md:48` says `docs/configuration.md` is "the single owner of the top-level operational-home layout", and `AGENTS.md:56-111` prints the tree. `state/<id>.pi-ext.ts` is written (`fm-spawn.sh:1259`), referenced in the spawn header's placeholder list (`fm-spawn.sh:112`), and removed by teardown (`:1091,1277`), yet appears in **neither** document - grep for `pi-ext` across `AGENTS.md` and `docs/configuration.md` returns nothing. `state/.lock`, `state/.watch-arm-output*`, `state/.watch-cycle-exits`, `state/.term-*`, and `state/.pi-*-extension-loaded` are also live in `state/` and absent from the tree (`.last-*` in the tree covers `.last-check`/`.last-heartbeat` by glob; these are not covered by any glob). The single-owner claim is a discipline, not a checked invariant - there is no test asserting the tree matches reality, unlike the section 9 contract which does have one.

**S5. Home isolation is the substrate under all of it.**
`FM_HOME` selects `data/`, `state/`, `config/`, `projects/` while scripts keep running from the tracked root (`AGENTS.md:49`, `configuration.md:154-155`). `fm-send.sh` refuses to resolve a target unless `FM_HOME` is explicit (`AGENTS.md:51`, `configuration.md:158`) - the one place the multi-home model is enforced rather than assumed. Per-directory overrides `FM_STATE_OVERRIDE` / `FM_DATA_OVERRIDE` / `FM_PROJECTS_OVERRIDE` / `FM_CONFIG_OVERRIDE` exist for tests (`configuration.md:159`).

### Config inheritance

**C1. The declared inheritable set, and primary-authoritative absence mirroring.**
`FM_INHERITABLE_CONFIG="crew-dispatch.json crew-harness backlog-backend herdr-presentation-spaces"` (`fm-config-inherit-lib.sh:43`) is one space-separated list; adding an item there makes every convergence point inherit it (`:27-30`). `propagate_inheritable_config` (`:391-442`) copies a present source item only when contents differ (`cmp -s`, `:409`), and when the source is **absent** it *removes* the destination copy (`:429`) - clearing the primary's value clears it downstream. Header states the reason (`:20-22`): "PRIMARY-AUTHORITATIVE: the primary's value wins and is re-pushed on every convergence."

Convergence points, from the header (`:17-20`): secondmate spawn (`fm-spawn.sh`), the bootstrap secondmate sweep (`fm-bootstrap.sh`), and the mid-session push (`fm-config-push.sh`).

Deliberately excluded: `config/secondmate-harness`, because a secondmate never spawns secondmates (`:29-32`); `config/backend` (`configuration.md:85`); `config/cmux-socket-password` and `config/wedge-alarm` (never in the list).

**C2. The gitignore guard on the destination.**
`destination_allows_inherited_item` (`:103-119`) resolves the destination path, and if it is inside a git work tree, runs `git check-ignore -q` and refuses the copy unless the destination path is ignored. A destination outside any git repo is allowed. This is a real, enforced guard: it prevents the primary from writing a file that would make a secondmate's checkout dirty - which would then be skipped forever by the fast-forward path (see U2 and coupling note 3). Skips are warnings, not failures (`:136-137`).

**C3. The shared captain-preference file is treated as hostile input in both directions.**
`propagate_shared_captain_preferences` (`:263-377`) layers guards that are worth reading as a unit:

- Source and destination must be regular files, not symlinks, with hard-link count 1 (`shared_captain_file_safe_existing:179-183`).
- Source header must contain four required literals within the first 12 lines (`:158-166`), or the whole propagation errors (`:280-285`).
- Destination is written 0600 to a temp file, moved, then `chmod 444` (`copy_shared_captain_file:243-261`, `FM_SHARED_CAPTAIN_MODE="444"` at `:38`) - read-only in the secondmate home by construction, not by instruction.
- A destination that diverged is **quarantined, not overwritten**: hashed, moved aside to `.captain-shared.md.quarantine.<UTC stamp>.<sha256>` with 0600, deduplicated against an existing quarantine artifact of the same hash (`:192-241`), and reported as `SECONDMATE_SYNC: ... quarantined ... drift` (`:364`).
- Any failure path calls `restore_shared_captain_readonly` before returning (`:303,360,370`).

There is deliberately **no shared learnings file** (`:34-35`, and `configuration.md:126`: "There is no shared learnings file by captain decision").

**C4. The re-read nudge for live homes.**
Config is copied while the target agent is already running, so a copy alone would not take effect. `FM_CONFIG_REREAD_*` (`:447-452`) writes a per-home instruction file under the destination's `state/` (chosen specifically so it "never dirties the home", `:446`), with retry staging, a pending cap of 16, a quarantine cap of 16, and a lock. Only allowlisted items are eligible - `fm_config_reread_is_allowlisted_item` (`:462-468`) explicitly excludes `data/captain-shared.md` from ever being inlined into an instruction (`:460-461`). The framing text is fixed (`:456`) and is careful to say the files are "defaults/rules and do not remove your judgment". Spawn and respawn re-read at launch and are deliberately not nudged (`:24-25`).

### Self-update

**U1. The update flow.**
`bin/fm-update.sh` (87 lines) fast-forwards the running repo from `origin` (`:53`), then sweeps live secondmate homes discovered from `state/*.meta` with `kind=secondmate` (`sweep_live_secondmate_metas:68`), then backfills from the `data/secondmates.md` registry for homes with no live meta (`:72-82`). It prints two parseable lines for the caller: `reread-firstmate: yes|no` and `nudge-secondmates: fm-<id>...|none` (`:86-87`). It explicitly does **not** re-read `AGENTS.md` or nudge anyone itself - "those are LLM / tmux actions the skill performs" (`:22-24`).

**U2. The fast-forward guards (the answer to "what stops an update destroying local work").**
All in `ff_target` (`bin/fm-ff-lib.sh:285-373`), one implementation shared by `/updatefirstmate` and the local-HEAD secondmate sync (`:5-11`):

| Condition | Result |
|---|---|
| not a directory / not a git repo | skipped (`:290-297`) |
| cannot determine default branch | skipped (`:300-303`) |
| no origin remote, or fetch failed | skipped (`:307-314`) |
| base commit does not exist locally | skipped (`:320-323`) |
| detached HEAD when not allowed | skipped (`:326-329`) |
| on any branch other than default | skipped (`:330-333`) |
| **working tree dirty** | skipped (`:335-338`) |
| HEAD not an ancestor of base (diverged) | skipped (`:353-356`) |
| otherwise | `git merge --ff-only` (`:360`); a failure there is also just a skip |

Never forces, never merges non-ff, never stashes (`:281-282`). The tracked-files fast-forward cannot disturb `data/`, `state/`, `config/`, `projects/`, `.no-mistakes/` because they are gitignored (`:17-19`) - and `dirty_status` uses `git status --porcelain` (`:225-232`), which does not report ignored paths, so operational state is invisible to the dirty check as well as to the merge. The one tolerated exception is the `.fm-secondmate-home` marker during a one-time upgrade (`:227-228`, `:20-22`).

`primary_head_commit` (`:56-60`) reads the default-branch *ref* rather than HEAD, with the reason stated at `:51-55`: a primary stranded on a feature branch (the worktree tangle) must not propagate that stray branch to the fleet.

**U3. Instruction-change detection drives the re-read.**
`changed_instr` (`:215-223`) diffs exactly three paths between HEAD and base: `AGENTS.md`, `bin`, `.agents/skills`. Reason stated at `:210-214`: "These are the files a running agent actually reads or runs ... Public `skills/` is installer-facing and intentionally not part of this watched instruction surface." That matches `AGENTS.md:449` exactly. A home that advanced without touching those three paths is not nudged on the bootstrap path; `/updatefirstmate` nudges on any advance (`fm-update.sh:59-61`).

**U4. Home validation before touching anything.**
`validate_secondmate_home` (`:122-189`) refuses: filesystem root; the active home; the firstmate repo; any home inside the active home or the repo; any home that is an ancestor of either; a symlinked marker; a missing marker; a marker whose contents name a different id; a home with no `AGENTS.md`; a home with no `bin/`. `validate_operational_dirs` (`:88-120`) additionally requires each of `data/`, `state/`, `config/`, `projects/` to resolve *inside* that home and outside both the active home and the repo. Nine of these eleven checks exist to prevent one home's update from writing into another's operational state.

**U5. What it never touches.**
`AGENTS.md:451` claims the update "never touches anything under `projects/`". Verified structurally rather than by an explicit guard: `fm-update.sh` operates only on `FM_ROOT` and validated secondmate homes, and `projects/` is gitignored in every one of them, so no code path in the update reaches it. There is no assertion enforcing this - it is an emergent property of the gitignore layout, which means a future change to `.gitignore` would silently remove the protection.

---

## 2. Verified versus prose-sourced

### Verified (I read the implementing code)

- E1's table exists at `AGENTS.md:376-386` and is asserted by a CI test at `tests/fm-captain-translation-contract.test.sh:73-89`. Read both.
- E2's four enforcement classes, including the negative assertions (`:39-51`) and the anti-duplication loop (`:129-139`).
- E3's detector gaps: greps for `destructive|irreversible|security-sensitive` and for credential/auth handling across `bin/*.sh` returned only brief text, domain refusals, and bootstrap's one-shot `gh auth status`.
- E4's verb-aware filter and its stated false-positive rationale (`fm-classify-lib.sh:40-44,101-117`).
- V1: `captain-held` written at `fm-decision-hold.sh:330`, parsed at five call sites.
- V2: the marker literal and its two sides (`fm-marker-lib.sh:42-46`, taught at `fm-brief.sh:162`).
- V3: generated brief vocabulary, ~20 literal sites in `fm-brief.sh`.
- V4: the header predicate (`fm-config-inherit-lib.sh:158-166`) and its error path (`:280-285`).
- V5: `-Fleet` / `Archon-` construction and the jq matcher (`bin/backends/herdr.sh:145,149,156,618`). Mechanism cross-checked against reports 01 and 02 rather than re-derived.
- S1: teardown's removal lines (`fm-teardown.sh:268,1091,1258,1277`) and the absence of any `data/<id>/` removal.
- S3: no deletion path for `.hash-*`, `.count-*`, `.seen-*`, `.hb-surfaced-*`; live count of 518 files against 1 live task.
- S4: `pi-ext` absent from both `AGENTS.md` and `docs/configuration.md`; written at `fm-spawn.sh:1259`.
- C1-C4: read `propagate_inheritable_config`, `destination_allows_inherited_item`, `propagate_shared_captain_preferences`, `copy_shared_captain_file`, `quarantine_shared_captain_dest`, and the reread allowlist in full.
- U1-U4: read `fm-update.sh` end to end and `fm-ff-lib.sh:1-373`.

### Prose-sourced (doc or header only, implementation not read)

- The bootstrap side of config inheritance - that the locked bootstrap step runs the same propagation helper and emits `SECONDMATE_SYNC:` / `NUDGE_SECONDMATES:` (`configuration.md:260-268`). I read the library, not `fm-bootstrap.sh`.
- `fm-config-push.sh`'s printed per-home result vocabulary (`configuration.md:266`). Library-side statuses (`pushed|unchanged|skipped|error`) are verified; the script's own output format is not.
- Away-mode batching constants (`configuration.md:434-435`); I did not read `fm-supervise-daemon.sh`.
- The claim that a secondmate home is leased at a detached HEAD so a fast-forward never moves the shared default branch (`fm-update.sh:14-16`, `fm-ff-lib.sh:23-25`). The `allow_detached` parameter exists and is honored (`:326-329`), but I did not read `fm-home-seed.sh` to confirm the lease actually detaches.
- X-mode's entire lifecycle (`configuration.md:272-344`). Out of scope and being stripped.
- `.no-mistakes.yaml` wiring the test suite - I read `configuration.md:110-113` and `bin/fm-lint.sh`'s header, not the yaml.

### Where prose and code disagree

1. **`AGENTS.md:48` / `docs/configuration.md:11` claim single ownership of the layout; the layout is incomplete.** `state/<id>.pi-ext.ts` and `state/.lock` are live, written by tracked scripts, and in neither document. Nothing tests the tree against reality. Contrast this with section 9, whose text *is* tested - the donor knows how to enforce a doc contract and did not apply it here.

2. **`AGENTS.md:405-406` says to batch non-urgent updates; nothing batches in normal mode.** The only batching machinery is in the away-mode daemon. In an ordinary session, "batch" is entirely a model behavior. This is not a defect - it is a correct instruction - but a porter reading the phrase as a mechanism will look for code that does not exist.

3. **`AGENTS.md:451`'s "never touches anything under `projects/`" is true but unguarded.** It follows from gitignore layout, not from an assertion. See U5.

---

## 3. Verdict per mechanism

| Mechanism | Verdict | Why | Already have it? |
|---|---|---|---|
| E1 outcome-translation table | **copy** | Our persona is Themis reporting to Ed; the table is vocabulary-independent once V-terms are swapped, and it is the strongest single artifact in the donor for the problem we already have | **absent** - `~/.claude/commands/Themis.md:35` requires a status shape, not a translation; `pi-themis/extensions/themis.ts:85-91` and `omp-themis/src/main.ts:134-136` enforce only the block's field names |
| E2 single-owner CI doc test | **copy** | Directly targets the three-hand-maintained-copies problem named in report 00 §0; needs no donor runtime | **absent** - no test asserts persona-copy consistency anywhere |
| E3 reach-immediately list | **copy** (with the two gaps filled) | The list is deterministic policy, not model judgment, and our persona currently covers one of six | **partial** - `Themis.md:36` covers only "when a decision is Ed's, stop and ask"; the other five are unstated |
| E3 gap: destructive / credential triggers | **rebuild** | Donor has no detector; if we want these to fire reliably they need to be a worker-side status verb or a tool-call guard, not prose | **partial** - `themis.ts:236-256` already blocks destructive tool calls at runtime, which is a *stronger* primitive than the donor has; it blocks but does not escalate |
| E4 captain-relevant verb filter | **copy** | Deterministic classification, no model judgment - matches our decided constraint; report 00 C2 already recommends the verb vocabulary | **partial** - `In flight` / `Blocked` in the status block map onto `working:` / `blocked:` but point outward, not inward (report 00 §6) |
| E5 batching constants | **strip** | Lives only in the AFK daemon, which report 00 S7 defers | absent |
| E6 paused-vs-blocked suppression | **copy** | Covered by report 00 C2; listed here for the escalation half | absent |
| V1 `captain-held` wire verb | **rebuild** | The mechanism (a verb that closes a keyed decision by transferring it to the backlog) is worth keeping; the literal is donor identity and the backlog side is `tasks-axi --kind captain` | absent |
| V2 from-firstmate marker | **copy** (rename both sides atomically) | We will have Themis relaying to dispatched agents in their own panes; the marked/unmarked distinction is exactly the "is this Ed or is this Themis" problem, and U+2063 is a solved answer | **absent** - no marker distinguishes Themis-relayed instructions from Ed typing into a worker tab |
| V3 generated brief vocabulary | **rebuild** | Report 04 owns the brief; every identity string is donor-specific | partial (report 04) |
| V4 header-validating propagation predicate | **strip** | It exists only to protect the secondmate inheritance model, which we drop (report 00 S5) | absent |
| V5 workspace/tab label vocabulary | **rebuild** | Reports 01:223 and 02:299 own this; labels are parsed as well as written | partial - `Themis.md:49` already mandates `GH#<issue>-<role>` tab labels |
| V6 script / skill / function names | **rebuild** | One-directional; free to rename, but `fm-` appears in branch names and selectors too | n/a |
| S1 teardown-defined volatile boundary | **copy** | It is exactly our decided split, already drawn in one line, and it is what makes restart-proofing possible | **partial** - `Themis.md:98-99` and `themis.ts:75` already say `docs/` is committed knowledge and `.agents/atlas/` is disposable and gitignored; there is no per-task state tier below that |
| S2 per-task volatile records (`meta`, `status`) | **rebuild** | We need the capability; the donor's implementation assumes tmux-era metadata and a `state/<id>` naming scheme. Report 00 R3 proposes GH issue number plus the existing tab label instead | **absent** - `themis.ts:146-148,222-229` persists one session-scoped `themis-state` entry, not per-agent records |
| S3 marker GC | **rebuild** | The donor has no GC at all; we should not port the omission. Anything keyed by task id should be removed when that task ends | absent |
| S4 layout-doc single-owner claim | **copy the discipline, add the test** | The donor proves the discipline works when tested (E2) and drifts when not; cheap to test a directory listing against a documented inventory | absent |
| S5 `FM_HOME` isolation | **strip** | Multi-home isolation exists to serve secondmates, which we drop | absent, and correctly so |
| C1 declared inheritable config set | **strip** | Whole mechanism exists to converge secondmate homes on the primary | **absent** - no multi-home model |
| C2 gitignore guard on destination | **strip** (keep the idea) | Same reason. The transferable idea is: never write a file into a repo where it would show up as dirty; that principle applies to anything we drop into a worker's worktree | absent |
| C3 shared-file quarantine-not-overwrite | **strip** (keep the idea) | Same reason. The idea - on divergence, hash and set aside with a diagnostic rather than clobber - is worth reusing wherever we sync a file we did not author | absent |
| C4 re-read nudge for live agents | **rebuild** | We will still change instructions under a running agent. Donor's implementation assumes `fm-send` into another home; ours would be a herdr `agent prompt`. The valuable part is the rule: a copied file does nothing until the live agent is told to re-read the exact post-write bytes | absent |
| U1 update flow | **strip** | Sweeps secondmate homes; our target is one repo | absent |
| U2 fast-forward guard set | **copy** | Nine skip conditions and `--ff-only`, no force/stash/merge - directly protects "never tear down unlanded work", which report 00 R4 flags as the thing we must not ship without | **absent** - `themis.ts:48` blocks Themis from running `git reset/clean/checkout` at all, which prevents her from destroying work but provides no safe *update* path |
| U3 watched instruction surface | **copy** | Three-path diff deciding whether a running agent must re-read is small, exact, and directly applicable to our persona files | absent |
| U4 home validation | **strip** | Exists for multi-home safety | absent |

---

## 4. Coupling notes

1. **Section 9 and the eight skills are a tested unit.** Changing section 9's wording breaks `tests/fm-captain-translation-contract.test.sh` in two directions: nine mapping rows are asserted present verbatim (`:73-89`), and eight skills are asserted to contain specific referring sentences (`:103-127`). If we port the test, we inherit the requirement that any rewording is a coordinated edit across nine files. That is the point of the test, but a porter who copies section 9's text without the skills will get a red suite.

2. **The from-firstmate marker is bidirectional and fails silently.** `fm-send.sh` prepends `[fm-from-firstmate]` + U+2063; the generated charter (`fm-brief.sh:162`) teaches the receiver that exact literal; `fm_message_from_firstmate` (`fm-marker-lib.sh:53-59`) matches it. Change the literal on one side and nothing errors - marked work quietly becomes a conversational chat reply in a pane nobody reads. `fm-marker-lib.sh:29-36` records that this already happened once with the original ASCII 0x1f separator, which Herdr 0.7.3 stripped before it reached Pi's composer.

3. **The gitignore guard (C2) and the dirty-tree skip (U2) are one system.** `destination_allows_inherited_item` refuses to write a config file that is not gitignored at the destination. If that guard is removed, the written file makes the destination's working tree dirty, `ff_target:335-338` then skips that home on every future update, and it silently stops receiving instruction changes. The two guards look independent and are not.

4. **`state/<id>.meta` is the liveness index for three unrelated subsystems.** `kind=secondmate` in a meta file is what `fm-ff-lib.sh:257` scans to find update targets, what bootstrap scans for inheritance (`configuration.md:269`), and what `fm-update.sh:68` sweeps. Meanwhile teardown deletes that same file (`:1277`). Deleting a meta is therefore also a de-registration, and the `data/secondmates.md` registry exists as the backstop for precisely that window (`fm-update.sh:70-71`).

5. **`data/<id>/report.md` is load-bearing for teardown, not just a deliverable.** `fm-teardown.sh:28-31` refuses to tear down a scout task until the report exists *and* the shared unresolved-decision gate passes. Anything we build that discards a worker's workspace must have an equivalent artifact-exists precondition, or report 00's R4 warning applies directly.

6. **`FM_INHERITABLE_CONFIG` is a single declared list with three consumers.** Adding an item changes spawn, bootstrap, and `fm-config-push.sh` at once (`fm-config-inherit-lib.sh:27-30`), and the reread allowlist derives from the same variable (`:462-468`). The one exclusion that must never be added is `secondmate-harness` (`:29-32`); the one item that must never be inlined into a reread instruction is `captain-shared.md` (`:460-461`). Both are comments, not assertions.

7. **Section 9's "scout" exemption is protected by a negative test.** `:44-49` asserts that `scout -> investigation` and `secondmate -> domain supervisor` do **not** appear in section 9. If we port the test while renaming scout, that assertion inverts. Worth noting because our persona already uses "scout reports" for explorer output (`~/.claude/commands/Themis.md:76`), so the donor's exemption survives our rename intact.

---

## 5. What I could not determine

- **Whether the section 9 test actually runs in CI on every change.** I read `bin/fm-lint.sh`'s header and `docs/configuration.md:110-113`, which say `.no-mistakes.yaml` `commands.test` runs every `tests/*.test.sh` and mirrors `.github/workflows/ci.yml`. I did not open `.no-mistakes.yaml` or `ci.yml` to confirm the glob picks up this file.

- **Whether a secondmate home is genuinely leased at a detached HEAD.** Asserted in two headers (`fm-update.sh:14-16`, `fm-ff-lib.sh:23-25`) and consistent with `allow_detached` existing as a parameter, but `fm-home-seed.sh` is unread. If it is wrong, the claim that a fast-forward "never moves the shared default branch" is wrong too. Low stakes for us since we strip secondmates.

- **How the re-read nudge is actually delivered.** I read the staging, retry, quarantine, and pointer-composition helpers (`fm-config-inherit-lib.sh:447-800`) but not `fm_config_send_reread_nudge` (`:950`) or `fm-send.sh`. I can state the contract - the live agent is told to re-read exact post-write bytes - but not the delivery mechanics or its failure modes.

- **Whether any watcher-marker family is read across sessions.** I proved nothing deletes them; I did not prove nothing reads a marker older than the current watcher process. `.seen-*` and `.hb-surfaced-*` are documented as watcher internals (`AGENTS.md:107`) and are keyed by task id, so a marker for a torn-down task cannot match a live task - but I did not read `fm-watch.sh`'s marker reads to confirm there is no cross-session dependency. Treat "safe to GC" as likely, not proven.

- **What the away-mode escalation digest actually contains.** `FM_ESCALATE_BATCH_SECS` and `FM_MAX_DEFER_SECS` are documented; whether the digest applies section 9's translation before injection is unknown - the AFK skill is asserted by the test to reference section 9 (`:106-109`) but I did not read the daemon's injection text builder.

- **Whether the OMP persona copy diverges from the Pi copy on anything relevant here.** I grepped both for status, state, and escalation handling and they matched line-for-line in shape (`themis.ts:85-91` vs `main.ts:134-136`; `STATE_ENTRY` identical). I did not diff them fully, so "the two runtime copies agree" is a spot check, not a verified claim.
