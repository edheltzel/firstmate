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
| `omp-evidence-and-rollback` | OMP evidence and rollback records | `data/omp-evidence/{task_id}.json`, `data/omp-rollback/{task_id}.json` | task owner from manifest | task owner from manifest | task owner from manifest | `omp-evidence.v1`, `omp-rollback.v1` |
| `omp-activation-records` | Activation transaction records | `data/omp-activation-preflight.json`, `data/backlog.md` | `bin/fm-omp-activation.sh` | `omp-p1-activation-a7` | `omp-p1-activation-a7` | `omp-activation-preflight.v1`, `omp-activation-receipt.v1` |

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
