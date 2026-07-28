# Backlog

## Done
- [x] omp-final-plan-redteam-o6 - Red Team the final phased OMP integration plan and tracking roadmap (repo: AgentThemis) (kind: scout) (priority: 0) (reported 2026-07-27) blocked-by: omp-first-class-support-o5
  Report: data/omp-final-plan-redteam-o6/report.md.
  Disposition: BLOCK.
  O6 completion does not authorize implementation and is not sufficient to unblock `omp-p1-activation-a7`.
- [x] omp-o5-plan-traceability - OMP plan traceability correction (repo: Agent-Themis) (kind: docs) (priority: 0) (done 2026-07-27)
  Completed planning artifact: closed the C01-C25 Red Team traceability gaps and staged the validated prose roadmap without implementation tasks.
  Ordered landed planning commits: 967b1dc723f44d4cd234e5acb26a435d9fd32d6b, a070dff48181b8bc70d876b7d7b6d808fff8e85d, 44a92ce6f900b8720ea4c6fecdc83e25c39a0414, 29511e55de9cc525a0ffd03ed8951b88389926e2, cd3c82632e9c33d68cceea8bbd4028163872bfac, da558ff154d96bb295db2369e839bb48f7f4cf20.
  The preserved predecessor is 5be5e1436134e3c455a16200deded0fbc9c4a043.
  Implementation remains blocked pending corrected-plan Red Team PASS and activation gate completion.
- [x] omp-plan-block-corrections-o7 - Correct OMP plan after final Red Team BLOCK (repo: AgentThemis) (kind: ship) (priority: 0) (done 2026-07-28)
  Planning and operational-tracking correction only.
  No OMP runtime support, verified allowlist, normal dispatch, P1-P8 activation, supervision, recovery, or Herdr behavior is changed.
  The canonical plan and prose roadmap own the complete correction contract.
  The machine-readable manifest is `.agents/tasks/omp-manifest.json` and exact plan/roadmap parity is checked by `bin/fm-omp-plan-check.sh --json`.
  The exact publication and cleanup inventory is `docs/omp-publication-inventory.md` and its V29 validator is `bin/fm-omp-publication-check.sh`.
  OMP identity, lock, backend liveness, and environment adaptation are assigned to `omp-p1-identity-ancestry`, `omp-p2-identity-adapter`, `omp-p4-tmux-classifier`, and `omp-p7-recovery`.
  The OMP environment boundary permits only the named profile, package, config, model, and credential variables in the canonical plan and rejects unknown or unredacted values.
  Immutable extension closure includes plugin directories, package/config file overrides, model/provider/search sources, bundled and lazy imports, and inline `createAutoresearchExtension`.
  `bin/fm-omp-activation.sh` is the mechanical, fail-safe, non-mutating-by-default O9 PASS dependency and owns the authoritative single-backlog publication if every gate passes.

- [x] omp-corrected-plan-redteam-o8 - Complete promoted O8 correction after historical BLOCK (repo: AgentThemis) (kind: ship) (priority: 0) (done 2026-07-28) blocked-by: omp-plan-block-corrections-o7
  Historical report: data/omp-corrected-plan-redteam-o8/report.md.
  Historical disposition: BLOCK.
  The O8 correction work is complete in this promoted ship task, but O8 remains a historical BLOCK review and can never authorize activation.
  O9 is the distinct independent final validation gate.

## Queued
- [ ] omp-final-corrected-plan-redteam-o9 - Final Red Team validation of corrected OMP plan (repo: AgentThemis) (kind: scout) (priority: 0) (since 2026-07-28) blocked-by: omp-corrected-plan-redteam-o8
  Validate the corrected plan and transaction gate independently after the promoted O8 correction work.
  Return PASS, CONDITIONAL PASS, or BLOCK with no runtime implementation and no support-policy change.
  The exact activation report is data/omp-final-corrected-plan-redteam-o9/report.md.
- [ ] omp-p1-activation-a7 - Activate OMP Phase 1 only after final corrected-plan PASS (repo: AgentThemis) (kind: ops) (priority: 0) (since 2026-07-28) blocked-by: omp-final-corrected-plan-redteam-o9
  Captain implementation authorization is recorded on 2026-07-27.
  Activation must refuse unless O9 returns PASS with no plan-blocking finding, its decision-hold inventory verifies clean, the tracked tree is clean, and no P1-P8 task is already active.
  Activation must preserve experimental-only labeling and must not add OMP to verified allowlists, normal dispatch, primary supervision, secondmate routing, recovery, or Herdr claims.
  The exact validator is `bin/fm-omp-activation.sh --check --json` and its default result is refusal unless the O9 report, report hash, decision inventory, STOP ledger, clean-tree preimage, branch/commit preimage, and backlog byte preimage all match.
  The O9 report must contain `## Plan-blocking findings` followed by `None.`; any finding or missing attestation refuses activation.
  A successful activation embeds the complete omp-activation-receipt.v1 record in the completed A7 backlog record and publishes only the three manifest P1 rows through one authoritative backlog rename.
  The embedded receipt is authoritative; no separate receipt file is required or authoritative.
  Until that validator returns PASS, `omp-p1-activation-a7` remains blocked and no implementation task may be activated.
