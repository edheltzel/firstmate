# Independent review of `VALIDATION-ROUND2.md`

Date: 2026-07-29.

## Bottom line

The synthesis materially improves `CONSOLIDATION.md`, especially on C8, the verdict arithmetic, the conditional Reviewer role, R17, and the OMP-only final-gate text.
It is not reliable enough to serve as a final validation record without revision.
Its largest weakness is not vendor identity by itself but missing auditability: the four verifier reports are unavailable, no finding is attributed to a specific verifier, and several categorical conclusions are stronger than the evidence reproduced in the synthesis.

Of the nine distinct claims carrying `[verified here]`, five pass, three pass only with qualifications, and one fails literally.
The convention is therefore useful as a pointer to claims worth checking, but not as an attestation that the whole marked sentence has been independently established.

## 1. Relay fidelity

The relay cannot be audited as presented.
`VALIDATION-ROUND2.md:3-5` calls the inputs “four independent verifiers, one per target” and then speaks of their “agreement.”
“One per target” means each target received one scoped verifier, not four independent replications of the same claim.
Without the reports, prompts, model versions, or per-finding attribution, a reader cannot distinguish verifier consensus, a single verifier’s judgment, and the orchestrator’s synthesis.
The standing caveat is honest, but it does not compensate for the missing chain of evidence.

The synthesis also hardens several judgments:

- “C6 is the only genuine either/or” is categorical (`VALIDATION-ROUND2.md:24`), but the evidence reproduced there verifies a Treehouse interface fact, not the complete disposable-worktree design.
- C1, C5, and C7 are declared “scope artifacts” without any local argument (`VALIDATION-ROUND2.md:30`). C8 is demonstrated; those three are not.
- “The five most expensive uncovered findings are all real,” “the recovery ladder is the highest cost,” and “more urgent for us” are unscored cost and priority judgments (`VALIDATION-ROUND2.md:78`) made immediately after the document rejects row counts as a sizing basis (`VALIDATION-ROUND2.md:42-50`).
- “Zero of twelve” is defensible as a rejection of the consolidation’s category, but the synthesis gives only category totals, not a requirement-to-category mapping (`VALIDATION-ROUND2.md:82`). A reader must reconstruct which four are citation misses, which two are observations, which two are product decisions, and which four are open questions.

The strongest relay corrections are sound:

- C8 is not a contradiction. Report 02 expressly distinguishes reusable workspace-per-project/tab-per-task authority from an optional workspace-per-task projection (`02-herdr-verification.md:43-58,123-128`).
- The Reviewer language defines a type of dispatched agent; it does not require one Reviewer per Worker (`~/.claude/commands/Themis.md:62-74`).
- The scoped-kill “gap” is false because R17 already requires one recorded identity and refuses broad pattern kills (`docs/plans/2026-07-26-001-feat-themis-fleet-orchestrator-plan.md:91`; `CONSOLIDATION.md:72-73,131-132`).

## 2. Audit of every `[verified here]` claim

### 2.1 Verdict totals — pass, with a disclosed policy dependency

The 208-row total and 94/35/79 split reproduce exactly.
Report 00 contributes 11 copy, 7 strip, and 3 rebuild rows after moving R2 to copy (`00-supervision-and-wake.md:217-279`).
The remaining verdict tables reproduce the stated total (`01-herdr-adapter.md:189-200`; `02-herdr-verification.md:246-261`; `03-session-start.md:147-167`; `04-dispatch-briefs-recovery.md:263-298`; `05-no-mistakes.md:200-214`; `06-treehouse-isolation.md:248-276`; `07-lifecycle-and-backlog.md:198-212`; `09-escalation-state-config.md:283-308`; `10-skills-inventory.md:94-110`).

“Exact” is still exact only under the orchestrator’s counting rule.
Report 03 M21 is explicitly mixed — copy for Claude/Pi and rebuild for OMP (`03-session-start.md:167`) — but is counted wholly as rebuild.
The synthesis discloses that choice at `VALIDATION-ROUND2.md:40`, so the arithmetic is reproducible, not neutral.

### 2.2 C6 and Treehouse stdout — qualified

The narrow CLI claim is correct.
The installed v2.0.0 help states that `treehouse get --lease` prints only the absolute path to stdout and sends banners to stderr; report 06 records the same lease semantics (`06-treehouse-isolation.md:139-143`).
Report 06 also correctly observes that the donor’s ordinary acquisition types `treehouse get` into a pane and infers the path through two agreeing reads (`06-treehouse-isolation.md:90-94`), while the pure-git post-acquisition assertion is `validate_spawn_worktree` (`06-treehouse-isolation.md:79-88`).

The marked conclusion “Report 06 wins” is broader than that evidence.
`--lease` is documented in report 06 as the durable-home acquisition path, while ordinary disposable work currently uses non-lease `treehouse get` (`06-treehouse-isolation.md:122-140`).
Changing ordinary acquisition to `--lease` changes ownership and release semantics; the synthesis does not show that those semantics were tested or designed.
Report 06 recommends subprocess acquisition (`06-treehouse-isolation.md:259-260`), but the verified help text alone does not prove that the durable lease form is the correct disposable-task replacement.
Action 2 should therefore require a lease/release lifecycle decision and an integration test, not merely substitute stdout for the pane poll.

### 2.3 C8 workspace topology — pass

The “manufactured” assessment is supported.
Report 02 says ordinary workers share a reusable workspace per project, with one tab per task, and separately says workspace-per-task survives only as a default-off disposable projection (`02-herdr-verification.md:43-58,123-128`).
Those are different scopes, not opposing durable designs.

### 2.4 Incompatible verdict granularity — qualified

The general claim is correct, but one of its examples is overstated.
Report 04 places all thirty spawn checks in one aggregate verdict and then separately repeats five selected checks as their own rows (`04-dispatch-briefs-recovery.md:287-292`).
Report 00 places the 1,509-line AFK daemon in one strip row (`00-supervision-and-wake.md:240-246`).
Those facts establish incompatible granularity.

“Report 06 spends six rows on a single treehouse lease contract” is not accurate as written.
The apparent six-row run includes the complete Treehouse command surface, capability/dependency probing, generic return, lease acquisition, lease release, and removal-target validation (`06-treehouse-isolation.md:265-270`).
Removal-target validation is a distinct destructive-safety mechanism, and the command-surface row includes non-lease task acquisition.
The conclusion survives; the supporting characterization should be narrowed.
The further claim that reports 04 and 06 supply half the copies “purely” because of granularity (`VALIDATION-ROUND2.md:48`) is causal speculation, not a verified count.

### 2.5 “Rebuild-heavy” characterization — qualified

The count claim is correct: the deduplicated ledger has 40 families, 18 with the exact verdict `rebuild`, and one with the exact verdict `copy` (`CONSOLIDATION.md:64-107`).
The preserved validation's phrase-absence check is not a durable finding after reconciliation because the phrase was present in the preserved validation itself.
The durable correction is that raw source-row totals are not rebuild-heavy, while a deduplicated family view may use that characterization only with an explicit definition.
This is another reason `[verified here]` must be scoped to an exact clause rather than read as a whole-sentence guarantee.

### 2.6 Reviewer dispatch is conditional — pass

The Claude persona says every dispatched agent has one of three types and then defines a Reviewer as an agent that reviews a Worker’s PR (`~/.claude/commands/Themis.md:62-74`).
It does not require a Reviewer to be dispatched for every Worker, and the PR-scoped definition does not naturally apply to local-only work.
The synthesis correctly refutes the broad C9 Reviewer headline.

### 2.7 RedTeam is unconditional — qualified by surface

The Claude persona does impose an unconditional completion check: it requires RedTeam validation of every claim before marking work done (`~/.claude/commands/Themis.md:40-43`).
That supports a real residue.

The synthesis overgeneralizes from that one surface when it says “the persona’s RedTeam clause is unconditional” (`VALIDATION-ROUND2.md:66`).
The Pi surface says only to use adversarial validation for “material claims before accepting completion” (`../Config/packages/pi-themis/extensions/themis.ts:73`), and OMP says the same without requiring RedTeam, fresh validators, or one validator per claim (`../Config/packages/omp-themis/src/main.ts:117`).
Calling the clause part of the “landing path” also supplies sequencing not present in those lines.
The real issue is twofold: Claude’s broad completion rule may conflict with no-mistakes ownership, and the three persona surfaces already drift.

The proposed R3/R4b “underlying seam” is not established.
R3 excludes model judgment from the deterministic current-state reader, while R4b requires the completion gate to inspect the product (`docs/plans/2026-07-26-001-feat-themis-fleet-orchestrator-plan.md:68-70`).
A product check can be deterministic, and a later RedTeam review can sit outside current-state classification.
Neither requirement says that RedTeam must be inside the current-state path.
The actual unresolved boundary is R14’s no-mistakes ownership versus Claude’s broad RedTeam completion rule (`docs/plans/2026-07-26-001-feat-themis-fleet-orchestrator-plan.md:87`; `~/.claude/commands/Themis.md:42`).

### 2.8 OMP-only final-gate injection — pass

OMP alone says, “Subagents do not run project-wide gates; you run the final gate after merging their work” (`../Config/packages/omp-themis/src/main.ts:116`).
The corresponding Pi contract contains no such rule, and the plan requires generated parity but contains no post-merge final-gate requirement (`docs/plans/2026-07-26-001-feat-themis-fleet-orchestrator-plan.md:95`).
Action 6 follows.
The reconciliation should clarify whether “merging their work” means integrating subagent changes locally or merging a PR; the current wording is ambiguous against R16’s human merge authority.

### 2.9 R17 scoped kill — pass

R17 states both required halves in one sentence: target one recorded process identity and refuse broad pattern kills (`docs/plans/2026-07-26-001-feat-themis-fleet-orchestrator-plan.md:91`).
The consolidation also already cites R17 in its ledger (`CONSOLIDATION.md:72-73`).
The synthesis is right that the later “gap” row contradicts the consolidation’s own ledger (`CONSOLIDATION.md:131-132`).

## 3. Self-serving structure

The self-criticism is partly real and partly protective.
It is real insofar as `VALIDATION-ROUND2.md:18` identifies a plausible incentive failure: asking for counts can make a model force fuzzy material into countable categories.
That explains pressure behind “nine contradictions,” 208 verdict rows, and 15/12 plan-gap counts.

It is protective in four ways:

1. No original consolidation prompt is attached, so the claimed causal link cannot be checked.
2. The explanation does not cover non-numeric overclaims such as C9’s mandatory Reviewer reading.
3. The synthesis repeats the same behavior with “one of nine,” “zero of twelve,” “five most expensive,” “highest cost,” and “18 of 40,” often without confidence or a mapping from source claims to conclusions (`VALIDATION-ROUND2.md:13-18,50,78-84`).
4. Blaming the dispatch frames the orchestrator as the source of the bias and the source of its cure, while the raw verifier reports remain unavailable.

The concession therefore does useful work as a process warning, but it does not make the nine-to-one verdict more objective.
That verdict needs a per-C-number evidence table showing verifier wording, orchestrator disposition, confidence, and any remaining uncertainty.

## 4. Review of the six actions

1. **Provenance tags — follows, but the taxonomy is incomplete.** The plan does need provenance labels. The synthesis itself distinguishes donor evidence, live observation, user direction, negative donor evidence, and deferred questions (`VALIDATION-ROUND2.md:82-86`). Three tags do not cover all five categories, and a tag without a citation does not repair bad evidence.
2. **C6 stdout acquisition — only partially follows.** The direction is plausible, but ordinary disposable acquisition versus durable `--lease` semantics remains unresolved. Require lifecycle ownership, release behavior, and a pure-git isolation assertion in the acceptance criteria.
3. **Reconcile 22 uncited rows — follows.** The action is warranted by `VALIDATION-ROUND2.md:54`, but the synthesis must list the 22 rows. Fixing citations also does not cure incompatible granularity.
4. **Resolve five contradictory verdicts — follows.** The action is warranted by `VALIDATION-ROUND2.md:55`, but it is not actionable until the five rows and both conflicting families are named. It should also state how mixed verdicts such as report 03 M21 are represented.
5. **Put narrow C9 to the principal — follows after reframing.** Ask whether Claude’s broad RedTeam completion rule is permitted outside the no-mistakes-owned validation path and what parity the Pi/OMP surfaces should have. Do not present the unproven R3/R4b conflict or assume the RedTeam pass occurs only after a PR is green.
6. **Reconcile the OMP-only final gate — follows.** This is a concrete, source-backed drift defect.

## 5. Material omissions

The synthesis misses several things a reader needs before acting:

- **The verifier artifacts themselves.** Publish the four reports or include claim-level extracts with verifier identity, exact wording, confidence, and orchestrator disposition.
- **A fixed evidence snapshot.** The live Treehouse binary and the three persona surfaces can change. Record version, commit or file hash, command, and date for every `[verified here]` assertion.
- **A defined marker scope.** State whether `[verified here]` covers the immediately preceding clause, the sentence, or the paragraph. The C6 and RedTeam markers currently blur that boundary.
- **The missed liveness contradiction has no action.** Report 03 says the donor applies the real agent probe only to secondmates (`03-session-start.md:154`), while report 02 ties the same classifier to ordinary duplicate prevention and husk recovery (`02-herdr-verification.md:102-107`). The synthesis identifies this at `VALIDATION-ROUND2.md:32` but never tells the porter to correct report 03 or the ledger.
- **No action repairs ledger granularity.** Actions 3 and 4 repair coverage and conflicts, not the row-unit mismatch that makes 94/35/79 unsuitable for sizing.
- **No action removes known false plan-gap rows or adds the missing persona drift test.** The synthesis correctly says R17 is already covered and R18 already requires generation (`VALIDATION-ROUND2.md:80`), but the action list does not require correcting those rows or adding parity enforcement.
- **No action fixes the admitted C9 citations.** `VALIDATION-ROUND2.md:64` says they are wrong, but none of the six actions replaces them.
- **The actionable defects are not enumerated.** “22 rows” and “five rows” are counts without identifiers, repeating the count-first failure the synthesis criticizes.

## Final assessment

This is a useful adversarial correction, not a trustworthy final validation.
Its sound core is substantial: C8 is manufactured, the source totals reproduce, the Reviewer role is dispatch-conditional, R17 was already present, and the OMP final-gate sentence is real drift.
Its credibility convention fails because one marker is literally false and three more cover broader conclusions than the rechecked evidence supports.
The next revision should attach the verifier chain when available, narrow every marker to an exact claim, replace count-only defects with named rows, and separate deterministic state classification from optional model-judgment review.

## Verification record

The preserved `REVIEW-PI.md` input and its referenced validation input were read completely on 2026-07-29.
Current target ownership was checked in `docs/plans/2026-07-26-001-feat-themis-fleet-orchestrator-plan.md:68-97`.
Current implementation references were checked with `rg -n "final gate|R17|R18|validate_spawn_worktree|foreground_cwd" docs bin omp-themis pi-themis` where those paths exist in this checkout.
