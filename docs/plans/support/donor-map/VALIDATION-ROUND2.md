# Round 2 validation: adversarial review of CONSOLIDATION.md

Date: 2026-07-29.

The preserved synthesis reports four verifier inputs, one per target. Claims marked **[verified here]** were re-checked directly against source by the reviewer, not taken from an unavailable verifier report.

Standing caveat: all four verifiers are Claude, while the consolidation was authored by codex. Agreement among them is worth less than it looks, and anything that survives untouched deserves one non-Claude pass.

---

## Summary

| Target | Consolidation's claim | Result |
|---|---|---|
| Contradictions | Nine cross-report contradictions | C6 is a real interface boundary, C2 is clerical, C8 is scope-separated, and C9 has a narrower residue. C1, C3, C4, C5, and C7 need claim-level qualification rather than categorical disposition. |
| Verdict ledger | 208 rows, 94/35/79 | **Exact** [verified here]. But unusable as a sizing basis, and its coverage claim is false for 22 rows. |
| C9 review authority | Genuine conflict needing a decision | **Headline refuted.** Reviewer role is dispatch-conditional, not per-task. A narrow real residue survives in the RedTeam half. |
| Plan gaps | 15 uncovered findings, 12 unsupported requirements | Direction 1 mostly right. Direction 2 framed wrong: **zero of twelve** are invented and unsupported. |

The consolidation is a useful decision inventory but must not be read as an attestation because the verifier chain is unavailable and several claims require narrower scope.

---

## 1. Contradictions: one of nine

C6 contains a genuine interface choice, but the complete disposable-worktree design remains undecided.

**C6, treehouse isolation proof.** Report 01 says copy the donor's two-read pane poll for the worktree path, while report 06 says call the CLI as a subprocess and read its printed path. The narrow observation that `treehouse get --lease` prints the absolute path on stdout is supported [verified here]. It supports subprocess acquisition, but does not decide whether disposable work should use `--lease` or who releases that lease.

Caveat on the consolidation's proposed resolution for C6: the donor's actual post-launch assertion is `validate_spawn_worktree` in `bin/fm-spawn.sh`, which is pure git and reads no pane state. Herdr `foreground_cwd` is useful provider evidence but is not the sole isolation proof.

The remaining classifications need scope discipline. C2 is clerical, C8 separates workspace-per-task from workspace-per-project [verified here], and the broad C9 Reviewer conflict does not survive. C1, C3, C4, C5, and C7 retain useful findings, but the preserved evidence does not justify calling each a pure scope artifact.

**Contradiction the consolidation missed.** Report 03 describes the liveness probe in secondmate terms, while report 02 ties the same classifier to ordinary duplicate-launch refusal. This needs a row-level correction before porting; a porter should not infer that the classifier is secondmate-only.

---

## 2. Ledger: exact, and unusable as a sizing basis

The arithmetic reproduces exactly [verified here]. Report 00 contributes 21 rows and uses table headings rather than cell values as verdicts, so no pattern match that works on the other nine works on it; adding those 21 and moving R2 from rebuild to copy yields 94/35/79/208 precisely.

**Two accounting decisions are load-bearing and only one is disclosed.** Report 00's R2 correction is documented. Report 03's M21 reads `copy for Claude/Pi, rebuild for OMP` and is assigned wholly to rebuild; without that choice the total is 207, double-counted it is 209.

**Granularity is incompatible between reports** [verified here], which makes the distribution unusable as a sizing basis:

- Report 04 files all thirty spawn fail-closed validations as **one** row.
- Report 00 files the 1,509-line AFK daemon as **one** row.
- Report 06 uses several rows across the Treehouse command surface, lease lifecycle, and removal-target validation.

These rows count source-table units, not comparable units of work, and no causal claim about why a report has more copies is established.

**Correction to a claim made around this document:** the raw ledger is not rebuild-heavy. Copy (94) beats rebuild (79). Any rebuild-heavy characterization must be limited to the deduplicated family view and must not be used as a sizing claim.

**Three defects to fix before this is treated as a port manifest:**

1. Twenty-two source rows are cited in no family. The genuinely absent ones are the reach-immediately escalation contract, three whole skills, and report 00's task registry, which is the port's task-identity model.
2. Five source rows carry contradictory verdicts across two families. A porter reading one drops the mechanism; reading the other, rebuilds it.
3. One family files the 1,509-line walk-away supervision daemon under "presentation projection."

---

## 3. C9: headline refuted, residue real

The Reviewer role is **conditional on dispatch**, not mandated per task [verified here]. The cited persona wording defines a type of dispatched agent and does not require a Reviewer for every Worker. Its PR-scoped definition does not naturally apply to local-only work.

C9's citations are also wrong: the donor rule it quotes is not in the range it cites, and it credits two reports where report 07 merely defers to report 05.

**What is real.** The Claude surface contains a broad RedTeam completion clause [verified here], while the Pi and OMP surfaces use different adversarial-validation wording. The durable issue is persona parity and whether model-judgment review may run inside a no-mistakes-owned completion path.

**The decision, narrowly posed:** in a no-mistakes project, may Themis run a model-judgment pass on a green PR before reporting it? Scout work sits inside the donor's own knowledge-only carve-out. Reviewer dispatch and non-no-mistakes modes are not in dispute.

The R3 and R4b requirements do not by themselves place RedTeam inside the current-state reader. The unresolved boundary is the no-mistakes ownership rule versus the broad Claude completion clause.

**Not a decision, a reconciliation:** `omp-themis/src/main.ts:116` injects "you run the final gate after merging their work," present in one of three persona surfaces and in no plan requirement [verified here].

---

## 4. Plan gaps: Direction 1 holds, Direction 2 does not

**Direction 1.** The listed safety findings are plausible implementation gaps, but the preserved material does not provide a scoring method for calling them the five most expensive or ranking one as highest cost.

The scoped-kill gap is a false unsupported-requirement classification, since R17 already states both halves [verified here]. R18 already requires one generated source, so the remaining gap is executable generation and drift testing.

**Direction 2 needs a mapping rather than a total.** Several flagged requirements are target requirements intentionally exceeding donor behavior, while others are observation-backed, user-directed, or deferred questions. The preserved validation does not identify each requirement's category, so the zero-of-twelve conclusion is not independently auditable.

The plan may intentionally exceed the donor, but that does not remove the need for per-requirement provenance.

**One real defect does survive, and it is cheap.** The plan does not mark provenance per requirement. A reader cannot distinguish donor-derived from live-observation from user-directed without reconstructing it. One tag per requirement closes it.

---

## Actions arising

1. Tag every plan requirement with provenance: donor-derived, observation-backed, user-directed, or deferred.
2. Decide disposable Treehouse lease ownership and test acquisition, release, and pure-git isolation assertions.
3. Name the 22 uncited source rows and five contradictory rows before using the ledger as a port manifest.
4. Correct the liveness-family ownership and report-03 scope wording.
5. Put the narrow C9 residue to the principal and reconcile the OMP-only final-gate injection against the other persona surfaces.
