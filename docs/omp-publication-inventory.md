# OMP publication and cleanup inventory

This document is the exact publication inventory for the corrected OMP plan.

The plan owns the policy decision, while this document owns the current artifact classes, paths, lifecycle owners, and evidence schemas.

The machine-readable parity contract is `.agents/tasks/omp-publication-manifest.json`.

No row grants runtime support or changes a verified allowlist.

| Inventory ID | Artifact class | Exact tracked or generated paths | Creation owner | Cleanup owner | Rollback owner | Evidence and rollback schemas |
| --- | --- | --- | --- | --- | --- | --- |
| `shared-lock-identity` | Shared identity and lock implementation | `bin/fm-session-lock-lib.sh`, `bin/fm-lock.sh`, `tests/fm-session-lock.test.sh` | lock owner | lock owner | `omp-p2-identity-adapter` | `omp-evidence.v1`, `omp-rollback.v1` |
| `backend-liveness` | Backend liveness and recovery seams | `bin/fm-backend.sh`, `bin/backends/tmux.sh`, `bin/backends/herdr.sh`, `bin/fm-crew-state.sh` | backend owner | recovery owner | `omp-p7-recovery` | `omp-evidence.v1`, `omp-rollback.v1` |
| `pi-worker-hooks` | Pi worker hooks | `state/{task}.pi-ext`, `projects/{project}/.pi/settings.json`, `projects/{project}/.pi/extensions/` | Pi hook owner | `bin/fm-teardown.sh` | `omp-p8-policy-publication` | `omp-evidence.v1`, `omp-rollback.v1` |
| `grok-authentication` | Grok worker hooks and authentication | `state/{task}.grok-token`, `state/{task}.grok-token.pointer`, `projects/{project}/.grok/` | Grok hook owner | `bin/fm-teardown.sh` | `omp-p8-policy-publication` | `omp-evidence.v1`, `omp-rollback.v1` |
| `global-worktree-hooks` | Global and worktree hook publication | `~/.config/grok/hooks/`, `projects/{project}/.claude/settings.local.json`, `projects/{project}/.opencode/plugins/` | hook publication owner | `bin/fm-teardown.sh` | `omp-p8-policy-publication` | `omp-evidence.v1`, `omp-rollback.v1` |
| `pr-check-publication` | PR check and merge-watch artifacts | `state/{task}.check.sh`, `state/{task}.check-trust`, `state/{task}.pr-poll`, `state/{task}.pr-poll-registration`, `state/{task}.pr-publication`, `state/{task}.pr-binding`, `state/.pr-check-quarantine/`, `state/.pr-check-migration.log` | PR check owner | `bin/fm-teardown.sh` | `omp-p8-policy-publication` | `omp-evidence.v1`, `omp-rollback.v1` |
| `herdr-presentation-journal` | Herdr presentation journal | `state/{task}.herdr-presentation` | Herdr presentation owner | `bin/fm-teardown.sh` | `omp-p5-herdr-parity` | `omp-evidence.v1`, `omp-rollback.v1` |
| `transition-and-task-temp` | Transition and task temporary state | `state/{task}.backend-transition`, `state/{task}.task-temp`, `state/{task}.turn-ended`, `state/{task}.grok-turnend-token` | task lifecycle owner | `bin/fm-teardown.sh` | `omp-p3-cleanup-live` | `omp-evidence.v1`, `omp-rollback.v1` |
| `omp-contract-and-monitoring` | Current watcher, continuity, monitoring, task-contract, runtime-pin, and regression surfaces | See the exact tracked-path bindings below | `omp-p6-supervision-continuity` | `omp-p6-supervision-continuity` | `omp-p6-supervision-continuity` | `omp-evidence.v1`, `omp-rollback.v1` |
| `omp-native-watcher-continuity` | Future OMP-native watcher, successor, retry, generated-hook, and continuity surfaces | See the exact future-path bindings below; these paths are not current runtime support | `omp-p6-supervision-continuity` | `omp-p6-supervision-continuity` | `omp-p6-supervision-continuity` | `omp-evidence.v1`, `omp-rollback.v1` |
| `omp-evidence-and-rollback` | OMP evidence and rollback records | `data/omp-evidence/{task_id}.json`, `data/omp-rollback/{task_id}.json` | task owner from manifest | task owner from manifest | task owner from manifest | `omp-evidence.v1`, `omp-rollback.v1` |
| `omp-activation-records` | Activation transaction records | `data/omp-activation-preflight.json`, `data/backlog.md` | `bin/fm-omp-activation.sh` | `omp-p1-activation-a7` | `omp-p1-activation-a7` | `omp-activation-preflight.v1`, `omp-activation-receipt.v1` |

<!-- omp-publication-tracked-path: `.agents/plans/omp-harness-integration-plan.md` -->
<!-- omp-publication-tracked-path: `.agents/tasks/backlog.md` -->
<!-- omp-publication-tracked-path: `.agents/tasks/omp-manifest.json` -->
<!-- omp-publication-tracked-path: `.agents/tasks/omp-runtime-pin.json` -->
<!-- omp-publication-tracked-path: `.agents/tasks/roadmap.md` -->
<!-- omp-publication-tracked-path: `bin/backends/herdr.sh` -->
<!-- omp-publication-tracked-path: `bin/backends/tmux.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-backend.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-bearings-snapshot.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-check-register.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-continuity-command-policy.mjs` -->
<!-- omp-publication-tracked-path: `bin/fm-continuity-pretool-check.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-crew-state.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-fleet-snapshot.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-lock.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-omp-activation.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-omp-monitor-check.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-omp-plan-check.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-omp-publication-check.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-omp-runtime-pin-check.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-omp-task-parity-check.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-pr-check-migrate.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-pr-check.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-pr-lib.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-session-lock-lib.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-spawn.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-teardown.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-turnend-guard.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-wake-drain.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-wake-lib.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-watch-arm.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-watch-checkpoint.sh` -->
<!-- omp-publication-tracked-path: `bin/fm-watch.sh` -->
<!-- omp-publication-tracked-path: `docs/omp-publication-inventory.md` -->
<!-- omp-publication-tracked-path: `tests/fm-bearings-snapshot.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-continuity-pretool-check.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-fleet-snapshot-view.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-omp-activation.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-omp-monitor-check.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-omp-plan-check.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-omp-publication-check.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-omp-runtime-pin-check.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-omp-task-parity-check.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-session-lock.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-turnend-guard.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-wake-queue.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-watch-checkpoint.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-watch-triage.test.sh` -->
<!-- omp-publication-tracked-path: `tests/fm-watcher-lock.test.sh` -->
<!-- omp-publication-future-path: `bin/fm-omp-watcher.sh` owner=omp-p6-supervision-continuity schema=omp-omp-watcher.v1 -->
<!-- omp-publication-future-path: `bin/fm-omp-continuity.sh` owner=omp-p6-supervision-continuity schema=omp-omp-continuity.v1 -->
<!-- omp-publication-future-path: `tests/fm-omp-watcher.test.sh` owner=omp-p6-supervision-continuity schema=omp-omp-watcher-test.v1 -->
<!-- omp-publication-future-path: `tests/fm-omp-continuity.test.sh` owner=omp-p6-supervision-continuity schema=omp-omp-continuity-test.v1 -->
<!-- omp-publication-future-path: `docs/omp-watcher-continuity.md` owner=omp-p6-supervision-continuity schema=omp-omp-watcher-doc.v1 -->
<!-- omp-publication-future-path: `state/{task}.omp-watcher.json` owner=omp-p6-supervision-continuity schema=omp-omp-watcher-state.v1 -->
<!-- omp-publication-future-path: `state/{task}.omp-lock` owner=omp-p6-supervision-continuity schema=omp-omp-lock.v1 -->
<!-- omp-publication-future-path: `state/{task}.omp-wake` owner=omp-p6-supervision-continuity schema=omp-omp-wake.v1 -->
<!-- omp-publication-future-path: `state/{task}.omp-turn-end` owner=omp-p6-supervision-continuity schema=omp-omp-turn-end.v1 -->
<!-- omp-publication-future-path: `state/{task}.omp-successor` owner=omp-p6-supervision-continuity schema=omp-omp-successor.v1 -->
<!-- omp-publication-future-path: `state/{task}.omp-retry` owner=omp-p6-supervision-continuity schema=omp-omp-retry.v1 -->
<!-- omp-publication-future-path: `state/{task}.omp-generated-hook` owner=omp-p6-supervision-continuity schema=omp-omp-generated-hook.v1 -->
## Atomic publication invariant

Publication is one transaction owned by `bin/fm-omp-activation.sh --activate` for the first corrected phase and by the P8 publication task for later policy changes.

The authoritative activation commit unit is one complete `data/backlog.md` postimage.

The completed A7 record embeds the complete `omp-activation-receipt.v1` record, including preimage hash, normalized postimage hash, O9 report identity and hash, authorization identity, exact task and dependency records, activation date, and support fence.

The postimage hash is computed from the postimage after replacing the receipt's 64-hex `postimage_sha256` value with the literal `<self>` placeholder, so the hash is not self-referential.

The transaction must validate the complete postimage with Tasks Axi and the receipt schema before replacing `data/backlog.md` with one same-directory atomic rename.

An interruption before the rename leaves the verified preimage unchanged, and an interruption immediately after the rename leaves the complete verified postimage authoritative.

There is no separate activation receipt authority or receipt projection.

`bin/fm-omp-publication-check.sh` is the executable V29 inventory and interruption validator.

Every evidence record must contain the task ID, evidence ID, exact command, exit status, observed state, redacted environment names, and report hash.

Every rollback record must contain the task ID, rollback ID, preimage hash, postimage hash when present, owner, cleanup command, and result.

Credential values are never written to these records.
