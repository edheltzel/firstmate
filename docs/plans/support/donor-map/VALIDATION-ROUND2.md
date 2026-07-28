# Round 2 validation: adversarial review of CONSOLIDATION.md

Four independent verifiers, one per target. Claims marked **[verified here]** were re-checked directly against source by the orchestrator, not taken from a verifier.

Standing caveat: all four verifiers are Claude, while the consolidation was authored by codex. Agreement among them is worth less than it looks, and anything that survives untouched deserves one non-Claude pass.

---

## Summary

| Target | Consolidation's claim | Result |
|---|---|---|
| Contradictions | Nine cross-report contradictions | **One real** (C6). One clerical, two miscited, four scope artifacts, one manufactured. Plus one contradiction missed. |
| Verdict ledger | 208 rows, 94/35/79 | **Exact** [verified here]. But unusable as a sizing basis, and its coverage claim is false for 22 rows. |
| C9 review authority | Genuine conflict needing a decision | **Headline refuted.** Reviewer role is dispatch-conditional, not per-task. A narrow real residue survives in the RedTeam half. |
| Plan gaps | 15 uncovered findings, 12 unsupported requirements | Direction 1 mostly right. Direction 2 framed wrong: **zero of twelve** are invented and unsupported. |

The consolidation is a good decision inventory and a poor evidence document. Every place it over-claimed is a place the orchestrator asked it for a number, which is an error in the dispatch, not only in the work.

---

## 1. Contradictions: one of nine

C6 is the only genuine either/or, and it is now decidable rather than arguable.

**C6, treehouse isolation proof.** Report 01 says copy the donor's two-read pane poll for the worktree path; report 06 says call the CLI as a subprocess and read its printed path. Both cannot be built. **Report 06 wins** [verified here]: `treehouse get --lease` on the live v2.0.0 binary "prints only the worktree's absolute path to stdout (all banners go to stderr)." The donor's poll exists solely because it types `treehouse get` into a pane instead of calling it as a subprocess.

Caveat on the consolidation's proposed resolution for C6: it assigns `foreground_cwd` a "post-launch assertion" role neither report proposes. The donor's actual post-launch assertion is `validate_spawn_worktree` in `bin/fm-spawn.sh`, which is pure git and reads no pane state.

The other eight: C2 is real but clerical (a numeral, where both sources agree on substance). C3 and C4 blame reports for claims those reports never made; in C4's case report 06 documents the scout/secondmate carve-out three times before its verdict table, so it was never wrong. C1, C5, C7 and C9 are scope artifacts. C8 is manufactured from conflating workspace-per-*task* with workspace-per-*project* [verified here].

**Contradiction the consolidation missed.** Report 03 claims the liveness probe is applied only to secondmates. That vocabulary belongs to `fm_backend_herdr_pane_agent_state`, which already gates ordinary-task duplicate-launch refusal. Report 02 is correct. Port consequence: a porter following report 03 would rebuild something copyable.

---

## 2. Ledger: exact, and unusable as a sizing basis

The arithmetic reproduces exactly [verified here]. Report 00 contributes 21 rows and uses table headings rather than cell values as verdicts, so no pattern match that works on the other nine works on it; adding those 21 and moving R2 from rebuild to copy yields 94/35/79/208 precisely.

**Two accounting decisions are load-bearing and only one is disclosed.** Report 00's R2 correction is documented. Report 03's M21 reads `copy for Claude/Pi, rebuild for OMP` and is assigned wholly to rebuild; without that choice the total is 207, double-counted it is 209.

**Granularity is incompatible between reports** [verified here], which is what makes the distribution unusable:

- Report 04 files all thirty spawn fail-closed validations as **one** row.
- Report 00 files the 1,509-line AFK daemon as **one** row.
- Report 06 spends **six** rows on a single treehouse lease contract.

Reports 04 and 06 supply half the copies purely because they decomposed finest. These count table rows, not units of work.

**Correction to a claim made around this document:** the raw ledger is not rebuild-heavy. Copy (94) beats rebuild (79). Rebuild-heaviness appears only after deduplication, where 18 of 40 families are pure rebuild and one is pure copy. The phrase does not appear anywhere in `docs/plans/` [verified here].

**Three defects to fix before this is treated as a port manifest:**

1. Twenty-two source rows are cited in no family. The genuinely absent ones are the reach-immediately escalation contract, three whole skills, and report 00's task registry, which is the port's task-identity model.
2. Five source rows carry contradictory verdicts across two families. A porter reading one drops the mechanism; reading the other, rebuilds it.
3. One family files the 1,509-line walk-away supervision daemon under "presentation projection."

---

## 3. C9: headline refuted, residue real

The Reviewer role is **conditional on dispatch**, not mandated per task [verified here]. The persona reads "Every agent you dispatch is one of three types," a typology with mandatory commands inside a reviewer's brief if a reviewer is dispatched. Nothing requires that every worker get one, and the role is PR-scoped by definition so it cannot arise in local-only mode.

C9's citations are also wrong: the donor rule it quotes is not in the range it cites, and it credits two reports where report 07 merely defers to report 05.

**What is real.** The persona's RedTeam clause is unconditional and sits in the landing path [verified here]: "Confirm completion through the RedTeam skill... let them try to break the result **before you mark it done**." The donor's orchestrator relays the pipeline's verdict; Themis re-verifies before relaying. Both still wait on the principal to merge.

**The decision, narrowly posed:** in a no-mistakes project, may Themis run a model-judgment pass on a green PR before reporting it? Scout work sits inside the donor's own knowledge-only carve-out. Reviewer dispatch and non-no-mistakes modes are not in dispute.

**Underlying seam nobody had named:** R3 requires no model judgment in the current-state path; R4b requires reading the product; RedTeam is model judgment. Whether a completion gate may be model judgment at all, or must be a deterministic artifact check, is unresolved between two requirements that were both added late.

**Not a decision, a reconciliation:** `omp-themis/src/main.ts:116` injects "you run the final gate after merging their work," present in one of three persona surfaces and in no plan requirement [verified here].

---

## 4. Plan gaps: Direction 1 holds, Direction 2 does not

**Direction 1.** The five most expensive uncovered findings are all real gaps: herdr CLI safety invariants, workspace lifecycle authority, the recovery ladder and duplicate-launch refusal, brief immutability, and the treehouse lease contract. The recovery ladder is the highest cost, and more urgent for us than the donor because the persona terminates agents on a heartbeat judgment with no check that the agent is the recorded one.

Errors found: the scoped-kill gap is flatly wrong, since R17 already states both halves verbatim [verified here], and the consolidation's own ledger cites R17 as covering it, so section 3 contradicts section 2. The generated-persona gap misstates its reason, since R18 does require generation and only the drift test is missing.

**Direction 2 is framed wrong.** Of twelve requirements flagged as unsupported, none are invented. Four are supported with the citation missed, including R16, which exists precisely because report 07 found the donor does not do it. Two are observation-backed rather than donor-backed, which is a different thing. Two are user-directed product decisions where demanding donor support is a category error. Four are not requirements at all but explicitly deferred open questions, and one of those four is a Direction-1 finding misfiled.

**The structural complaint does not survive.** A plan that could contain only donor-traceable requirements could never exceed its donor, which is what its central decision commits it to doing.

**One real defect does survive, and it is cheap.** The plan does not mark provenance per requirement. A reader cannot distinguish donor-derived from live-observation from user-directed without reconstructing it. One tag per requirement closes it.

---

## Actions arising

1. Tag every plan requirement with provenance: donor-derived, observation-backed, or user-directed.
2. Fold C6's resolution in: acquire the worktree path from the CLI's stdout, not from a pane poll.
3. Reconcile the ledger's 22 uncited rows before anyone ports from it, starting with the task registry and the escalation contract.
4. Resolve the five source rows carrying contradictory verdicts across families.
5. Put the narrow C9 residue to the principal; do not put C9 as written.
6. Reconcile the OMP-only final-gate injection against the other two persona surfaces.
