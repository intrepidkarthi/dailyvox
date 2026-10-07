# Deviations from the Experiment B pre-registration

**Reference document:** `preregistration-FINAL-draft.md` (v2.1, 2026-08-04) in the private DailyVoxTwin repository, `docs/research-affect/expB-prereg/deliverables/`, with `harness-fix-spec.md` (F-numbers) and `consent-v2.md` (EXPB-CONSENT-2.1).

**Implementation:** `dailyvox-study` 0.1.0, protocol hash printed by `dailyvox-study --version` and stamped in every result file.

**Purpose of this file:** the pre-registration was written for a researcher-held design: participants send their diary export to one researcher, who runs a Swift harness over Apple `NLEmbedding` on one macOS machine. This tool implements the same protocol for a decentralised design in which each participant runs the analysis on their own laptop and shares only a numbers-only result file. Some changes are forced by that design or by moving to open, cross-platform components. Every one is listed below so the protocol can be re-registered with the changes stated rather than discovered. Nothing here was chosen after seeing participant data: no real export has been processed by this tool.

Status labels: **FORCED** (the decentralised or open-component design makes the registered text impossible as written), **ADAPTED** (registered intent kept, mechanism changed), **CLARIFIED** (the prereg left a choice open; the choice made is stated), **PI DECISION** (needs a signature before registration).

---

## D1. Features: Apple NLEmbedding replaced by an open, pinned model (FORCED)

- **Prereg:** section 4.5 ("Features: Apple `NLEmbedding.sentenceEmbedding(.english)` (512-d), computed once, on one harness machine (macOS)"), F7, F8, P10.
- **Now:** `sentence-transformers/all-MiniLM-L6-v2` (Apache-2.0), pinned to Hugging Face revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`, 384 dimensions, L2-normalised by the model, CPU only, one thread, seed 42, unique texts embedded in sorted order with batch size 32.
- **Why:** `NLEmbedding` exists only on Apple platforms. Android participants and non-Mac laptops could not run it, and in the decentralised design there is no single harness machine.
- **Consequences:**
  - Feature dimension 384 instead of 512. The section 4.5 argument that lambda = 10 shrinks hard toward the prior (unit-norm rows, 25 rows against lambda I) still holds because the vectors are unit-norm.
  - Embeddings are computed on each participant's own machine. On one machine re-runs are byte-identical (tested). Across machines, maths libraries can differ in the last floating-point bit; accuracies are discrete, so this can, rarely, flip a single test prediction. Each result carries an `environment` line (Python, NumPy, torch, sentence-transformers, transformers versions, OS family and CPU architecture) in place of the F8 harness stamp. The per-participant `NLEmbedding` revision note in section 4.5 is replaced by this line.
  - All numbers in the prereg derived from NLEmbedding runs (Experiment A register gap, smoke-test behaviour in `sensitivity.md`) are not evidence about this feature space.

## D2. Generic training data: missing ship-train.json replaced by pinned GoEmotions (FORCED)

- **Prereg:** section 4.6 (F9, "`ship-train.json` is absent from the worktree"), section 7.1, P4, X6.
- **Now:** GoEmotions (Demszky et al. 2020, Apache-2.0) raw TSVs from `google-research/google-research` at commit `7951440944924ac61b6e2f9a2a3c715834005c40`, each file SHA-256-verified (hashes in `protocol.py`). Recipe, following the documented Experiment A "R2" recipe (`R2-shipgate-memo.md`): train + dev splits; official `ekman_mapping.json` plus neutral, which maps onto the 7-class canon exactly; keep rows whose labels all map to one canon class; drop rows under 5 words; drop exact duplicate texts; cap 800 rows per class by seeded sample. Result: 48,836 rows read, 4,335 multi-class dropped, 5,623 too short, 10 duplicates, **5,029 rows kept** (joy 800, sadness 800, anger 800, fear 537, surprise 800, disgust 492, neutral 800). Off-canon rows: zero by construction (the code asserts the mapping covers exactly the canon).
- **Generic lambda:** chosen from {1, 10, 100, 1000} by accuracy on a seeded 90/10 split inside these rows, as section 4.5 specifies. Validation accuracy 0.495 / 0.499 / 0.475 / 0.366; **lambda = 10**.
- **Hash pinning, strengthened:** rather than each laptop refitting the head, the fitted head is shipped with the tool (`data/generic_head_v1.json`) and its weights SHA-256 `4e41f31191be15a04a4981907600b6ea0bd59216793e3f663ef422e69e3b1ef2` is pinned. Every participant therefore uses byte-identical K = 0 weights. Anyone can rebuild it (`dailyvox-study build-generic-head`); `selfcheck` rebuilds it and checks the predictions match.
- **Consequences:** the K = 0 head is neither Experiment A's shipped H2 artefact nor the never-restored `ship-train.json` head. The section 7.1 sentence ("the K = 0 head is this harness's own one-vs-rest ridge ... it is not Experiment A's shipped H2 artifact") stays true and should name GoEmotions explicitly. The R2 memo reports 4,622 rows (disgust 289, fear 333) and 5,930 short rows dropped, against 5,029 rows and 5,623 here, with an identical multi-class count (4,335). The R2 filter script was not available, so the difference (most likely the word-count rule) cannot be reconciled and is disclosed.

## D3. Who runs the scoring: the pre-freeze interlock cannot be enforced (FORCED)

- **Prereg:** section 0.4 (permitted pre-freeze operations), section 6.6 (disagreement probe as "the first act AFTER D_freeze ... the last act before unblinding"), section 10.5, F6 exit 20/22, P8 (`testScoringPathRefusesRealExportBeforeFreeze`).
- **Now:** each participant runs the full scoring on their own export, whenever they choose. The tool cannot refuse to score a real export before the freeze, because the participant is entitled to run it. What is enforced: `combine` refuses to pool real (non-synthetic) result files unless `--freeze-date` is given and has passed, with exit code 22. That is a procedural guard, not a cryptographic one: anyone can pass the flag.
- **Consequences:**
  1. **Participant-side unblinding.** A participant who runs the tool mid-study sees their own accuracy curve and could, consciously or not, label differently afterwards. Mitigation: participants are told to run the tool once, after labelling ends (README, STUDENT-GUIDE); the terminal prints counts only, not accuracies. Not eliminated: the numbers are in the file.
  2. **Researcher-side blinding.** Result files arrive by hand over weeks. A researcher who opens them before the freeze sees outcomes. Mitigation to register: result files are collected unopened into a folder and pooled only after `D_freeze`; the file receipt ledger (X13) records SHA-256 at receipt.
  3. **The label-free disagreement probe (section 6.6) is no longer separable from outcomes:** `d` travels in the same file as the accuracies. Mitigation: the lambda fallback branch and the low-`d` branch are applied by `combine` as a deterministic function of `d` alone, with no human step, so knowing outcomes cannot change which branch is taken. The prereg's requirement that the probe log be committed before unblinding becomes "the `combine` code that applies the branch is committed and hashed before the freeze".
  4. **Result-file integrity rests on trust.** A participant could edit their result file. `input_sha256` lets a participant prove later which export produced it, but the researcher cannot verify it without the export, which by design they never receive. Disclose as a limitation.

## D4. Cross-participant arms cannot be computed: donor, donorPlusPrior, pooledLOPO (FORCED)

- **Prereg:** section 7.3 (donor, `donorPlusPrior`, `pooledLOPO`), section 3.1 H3b, section 6.1 Step 4, section 6.4 rows 1, 2, 3 and 13, section 3.3 S6, F2b, F16.2, and `consent-v2.md` section 3b and section 11 ("how well a model of everyone-but-you did").
- **Now:** these arms fit a head on other participants' entries and score it on this participant's test tail. In the decentralised design no machine ever holds two participants' rows, so none of them can be computed. **Step 4 (H3b) is unrunnable for the whole cohort.**
- **Registered rule applied:** section 7.3, "Enforcement", already says that if Step 4 is ever unrunnable for the whole cohort, "claim-map row 3 fires". `combine` implements exactly that: whenever Steps 1, 1b, 2 and 3 all reject, the published sentence is row 3 ("we cannot separate personalization from shared spoken-register adaptation at this cohort size"). Rows 1 and 2 are unreachable. Row 13 is printed as "not evaluable". The section 7.3 donor-gate verdict is printed as "unrunnable".
- **Consequence for Step 5 (H4):** the fixed sequence stops at the first step that does not reject, and an unrunnable Step 4 stops it. H4 is therefore always computed but never carries alpha. **PI DECISION:** either accept this, or re-register the sequence as H1, 1b, H2, H3, H4 with H3b dropped from the confirmatory tier. The second option keeps H4 confirmatory at no cost to familywise error, because H3b never runs.
- **Consequence for the title claim:** the words "a model of *you*" (section 3.1) are not licensable in this design, because H3b is what licenses them. The strongest available claim is row 3's.
- **Possible future route, not implemented:** each participant could share sufficient statistics of their adaptation-window rows (`X'X`, a 385 x 385 matrix, and `X'Y`, 385 x 7) and the cross-participant ridge heads could be assembled from those without text. These matrices are derived from text embeddings and carry far more information than accuracies; they would need their own consent clause, a privacy analysis (embedding inversion), and ideally secure aggregation. Recorded so the option is not lost.

## D5. Consent stamp, eligibility checks and multiple exports (ADAPTED)

- **X1 (section 6.7):** the admissible consent version changes from `EXPB-CONSENT-2.1` to `3.0`, the result-file-only consent (see CONSENT-CHANGES.md). The tool fails closed with a named `ConsentMismatch` error and exit code 3; it never silently skips a file. The protocol stamp `EXPB-KCURVE-1.0` is replaced by `protocol_hash`, the SHA-256 of a canonical JSON of every frozen constant; `combine` refuses mixed hashes.
- **X2** (`consentAcceptedAt` must precede the first entry): **not checkable**, because export schema v1 carries no consent-acceptance timestamp. Recommend adding `consent_accepted_at` to export schema v2, after which this check is one line.
- **X3** (participant id vs file name): replaced by the participant code inside the file; `combine` refuses two files with the same code.
- **X13** (multiple exports: analyse the last one received on or before `D_freeze`): `combine` refuses duplicate codes or duplicate export hashes and lists the files. The researcher then keeps the last file received on or before `D_freeze` according to the receipt ledger. The choice is made from the ledger, not by the tool.
- **X8 (P0):** `combine --p0 CODE` excludes the developer from every confirmatory test.

## D6. Degenerate rows and off-canon labels (ADAPTED)

- **X7 / F7 (zero-vector embeddings):** MiniLM never returns an all-zero vector for non-empty text, so the NLEmbedding failure mode does not exist. The analogous case, an entry whose text is empty or whitespace, is excluded before the chronological split and counted (`n_excluded_empty_text`), keeping n, pool and m consistent as section 6.7 requires. The ">5% halt" is not implemented as a halt; the count is reported for X14 handling by the researcher.
- **X6 / F1 (off-canon labels):** export schema v1 permits only the 7 canon labels, so an off-canon label makes the export invalid (exit 2, with the entry number) instead of being dropped and counted. Nothing is ever coerced to another class.

## D7. Typed entries and Android participants (ADAPTED; changes the population)

- **Prereg:** section 4.1 ("Participants journal by voice"), section 2.1 and section 7.3 (the study is about spoken diary register), `consent-v2.md` section 13(c) ("I journal on an iPhone").
- **Now:** the export includes typed entries (`input: "typed"`, for "I can't talk right now" moments), and participants may use iPhone or Android.
- **Consequences:** the register mix is no longer purely spoken, and Android's speech recogniser produces transcripts with different punctuation and capitalisation from iOS. Both are reported, descriptively: per-participant voice and typed counts, typed share overall and per platform, a per-platform breakdown of every headline quantity, the correlation of typed share with Delta-acc, and a **voice-only sensitivity** (Delta-acc at K = 25 recomputed on voice entries only, when a participant has at least 35 of them), subject to the section 3.4 directional rule. No platform or input-mode test carries alpha. **PI DECISION:** whether typed entries belong in the primary analysis or only in a sensitivity analysis. The current default keeps them in, because excluding them would change which entries form each person's chronological test tail.

## D8. Permutation null details (ADAPTED)

- **Prereg:** section 7.5, F3, F4, `--null-permutations 1000`.
- **Now:** labels shuffled within user (all n entries), embeddings untouched, identical split and lambda. Seeds per (participant, permutation index j) from `SEED + 0xB0B0 + FNV-1a-64(participant_code) + j * 0x9E3779B97F4A7C15` (mod 2^64), feeding NumPy's PCG64 generator rather than the Swift `SeededRNG`. Same property as F4: a participant's null never depends on who else is in the cohort. P = 1000 permutations are run at K = 25; the full null K-curve is computed for permutation 0 only. Per-user p = (1 + #{null >= observed}) / 1001 and the cohort null win-rate distribution are reported, never displacing the binomial primary.
- **Health check:** on real data, null Delta is reported next to prior-only Delta (section 7.5) and not gated. On synthetic data `selfcheck` gates on "no lift": mean null Delta between -6 and +2 points and null win-rate below one half. The band is asymmetric because with shuffled labels the pool and test tail are drawn without replacement from one fixed set of labels, so a head that learns the pool's label frequencies is slightly below chance on the tail. A small negative null is the expected signature; the prereg's "must sit near 0" phrasing (F3.3, synthetic branch) should say "must show no positive lift".

## D9. Statistics: choices the prereg left open (CLARIFIED)

- **Sign-flip test (section 6.1):** statistic is the sum of per-person Delta; p counts patterns with sum >= observed (tolerance 1e-9 for floating point). Exhaustive enumeration up to N25 = 20 (2^20 patterns); above that a seeded Monte Carlo with 200,000 draws and p = (1 + #) / (draws + 1), labelled as such in the report. The prereg says "enumerate all 2^N" without a size limit; at the N the funnel can deliver (N <= 15) the tool always enumerates.
- **Step 1b (section 6.2):** participants with b = c = 0 have an undefined McNemar p; they are left out of the Fisher combination and counted, which is the reading section 6.4's low-d paragraph implies ("Step 1b is undefined for a participant only when b = c = 0; the count of such participants is printed"). Leave-one-out combined p is printed for every participant.
- **Low-d branch (section 6.6):** "median d >= 3" vs "median d <= 2" leaves a median of 2.5 unassigned. The tool treats any median above 2 as the standard branch. The median is taken over N25 at the active lambda.
- **Lambda branch (section 6.6):** applied mechanically from the cohort medians of `d` at lambda = 10 and lambda = 1 (both computed by every participant). If triggered, all Step 1 to 5 quantities are read from the lambda = 1 block. The "probe is re-run once" becomes "the lambda = 1 quantities are already in each file".
- **Inferiority criterion (section 6.3, row 8):** Clopper-Pearson one-sided upper 95% bound by bisection on the binomial CDF (verified against the prereg's trigger table), one-sided upper 95% percentile bootstrap (10,000 draws, seed 42) on mean Delta-acc, and N_eff >= 5.
- **S9 intervals:** one-sided 90% lower bounds, both percentile and BCa (jackknife acceleration), 10,000 bootstrap draws, seed 42. K_half's bootstrap histogram uses 2,000 resamples of N25 users. K_half is reported as undefined when mean Delta(25) <= 0.
- **Row 12 (sub-chance generic):** "per-user majority-class baseline" is operationalised as the majority class of the adaptation pool scored on the test tail (no test gold used). The blank in "recovers ___ points over chance" is filled with the cohort mean of (accuracy at K = 25 minus that participant's empirical-chance threshold), in points.
- **Stratified dummy (section 7.6):** reported as its exact expected accuracy, the dot product of the pool and test label distributions, rather than a sampled dummy.
- **Compound win (section 3.2):** count always printed; exact p and k* printed only when Steps 1 and 2 both rejected, as registered.
- **Ties in argmax:** broken toward the lowest canon index (joy, sadness, anger, fear, surprise, disgust, neutral), deterministically.

## D10. Quantities the export v1 does not carry (FORCED, partly fixable)

| Prereg item | Status in this tool | Fix |
|---|---|---|
| S11 label-rate diagnostics, K-23 (`recordingsTotal`, `recordingsLabeled` per ISO week) | not computable; section 15.4's honest sentence applies ("skip rate is unmeasurable by construction ...") | add both integers per week to export schema v2 |
| E1 intensity (1-3) | not analysed | add `intensity` per entry to export schema v2 |
| Section 4.1 exposure covariate (install date, pre-enrolment entries, prior exposure to mood surfaces) | not computable | enrolment questionnaire or export v2 fields |
| Section 5.3 recruitment strata, row 14 | only if the researcher passes `--strata` | enrolment ledger |
| X2 consent-before-participation | not checkable | `consent_accepted_at` in export v2 |
| Row 16 withdrawal effect | not visible to the tool | researcher states it from the ledger |
| F12 Cholesky failure counter | implemented as a solver-failure counter (the dual solve can fail the same way) | none needed |

## D11. Timing of post-hoc exhibits (ADAPTED)

- **Prereg:** section 3.4 E5 and section 4.5: the real-data lambda sweep is "permitted only after the claim-bearing run has executed and its output is committed", banner-marked.
- **Now:** every participant computes Delta-acc(K = 25) at lambda = 1 and 100 in the same run (both are needed anyway for the section 6.6 branch). `combine` prints the sweep under the banner "POST-HOC, NOT CLAIM-BEARING" after the claim-bearing results. The numbers exist at the same moment as the primary; the banner and the report order are what keep them non-claim-bearing.

## D12. Implementation notes that are NOT deviations

- Personal head: the closed form `(X'X + lambda I) W = X'Y + lambda W_generic` is solved in its equivalent dual form `W = W_generic + X' (X X' + lambda I_K)^-1 (Y - X W_generic)`, which is the same solution (tested against the primal to 1e-10) and solves a K x K system. The bias column is penalised, as in the Swift harness. At K = 0 the generic array itself is returned, so K = 0 is bitwise the generic head (tested).
- Prior-only arm: the section 7.2 closed form, verified against a brute-force one-dimensional minimiser.
- Split S3, K grid {0, 5, 10, 25}, lambda_adapt = 10, seed 42, alpha = 0.05 one-sided, ties as losses, exact k* table (tested against the section 6.2 table), empirical-chance thresholds (tested against section 7.6: 40.0%, 35.0%, 28.6%), macro-F1 over classes present in the test tail, persistence-full and persistence-frozen, majority-of-K, recency-matched last-K with the section 7.7 sentence, E2 uncapped tail, E3 Tier-1-only, E3b pooled net entries, X15 gap strata: all as registered.
- Claim-map sentences are copied from section 6.4 with only the blanks filled, and the section 6.4 precedence order is implemented and tested.

## Open items for the PI before re-registration

1. D4: keep H4 behind an unrunnable H3b (H4 never carries alpha), or re-register the sequence without H3b.
2. D4: accept that the title claim is capped at claim-map row 3 in this design, or plan the sufficient-statistics extension with its own consent.
3. D7: typed entries in the primary analysis (current default) or in a sensitivity only.
4. D3: register the collection procedure that replaces the software interlock (unopened results folder, receipt ledger with hashes, single pooled run after `D_freeze`).
5. D10: decide which export v2 fields to add before enrolment (consent timestamp, intensity, per-week counters).
6. Lambda provenance (section 4.5 P13): lambda = 10 is still unswept on any data in this feature space. A synthetic sweep should be run and recorded before the freeze, as section 4.5 already requires.
7. Power (section 6.5, P11): every power figure in the prereg was computed for the old feature space and design and should be recomputed or explicitly carried over.
