# Deviations from the Experiment B pre-registration

**Reference document:** `preregistration-FINAL-draft.md` (v2.1, 2026-08-04) in the private DailyVoxTwin repository, `docs/research-affect/expB-prereg/deliverables/`, with `harness-fix-spec.md` (F-numbers) and `consent-v2.md` (EXPB-CONSENT-2.1).

**Implementation:** `dailyvox-study` 0.2.0, protocol hash printed by `dailyvox-study --version` and stamped in every result file.

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

## D4. Cross-participant arms rebuilt from shared heads: donor, donorPlusPrior, pooledLOPO (ADAPTED, two-round design)

- **Prereg:** section 7.3 (donor, `donorPlusPrior`, `pooledLOPO`), section 3.1 H3b, section 6.1 Step 4, section 6.4 rows 1, 2, 3 and 13, section 3.3 S6, F2b, F16.2, and `consent-v2.md` section 3b and section 11 ("how well a model of everyone-but-you did").
- **The problem:** these arms fit a head on other participants' entries and score it on this participant's test tail. In the decentralised design no machine ever holds two participants' rows.
- **Resolution (tool 0.2.0, chosen by Karthik): two rounds of weight sharing, no text shared.**
  1. *Round 1.* `run` also writes `weights.json`: the participant's own ridge heads (385 x 7 numbers each), fitted on their adaptation pool only. These are the K = 5, 10, 25 heads on the first min(K, pool) rows (exactly the rows F2b's donor rule draws from each donor), plus heads on the whole pool at lambda / d for d in {1, 2, 4, 8, 16, 32}. Both sets are written for lambda = 10 and the registered fallback lambda = 1. The participant chooses whether to send it.
  2. *Coordinator.* `donors` builds, for each participant P, heads computed only from the OTHER non-P0 participants' weights (leave-P-out; P0 excluded per section 7.3 (d)).
  3. *Round 2.* `run --donors` scores those heads on P's own fixed test tail. donorPlusPrior is P's own bias-only refit (section 7.2 closed form) on top of the donor head, done locally, exactly as section 7.3 defines it. The donors file carries P's round-1 `input_sha256` and round 2 refuses any other export, so data cannot be swapped between rounds.
- **How the heads stand in for row-level refits (the residual difference).** The prereg fits each arm on pooled ROWS. Here the coordinator only has HEADS, so the arms use the standard divide-and-conquer ridge approximation. If each person's Gram matrix X'X is similar, the mean of D people's heads fitted at mu approximates the ridge fit on all their rows pooled at D x mu.
  - **donor** (prereg: exactly K rows round-robin over other participants in sorted-id order, lambda) becomes the **mean of all other participants' K-row heads at lambda**. Each donor contributes about K / D rows' worth, so volume is matched in expectation, not row for row. Averaging over all donors also removes the arbitrariness of which donor rows the round-robin happens to pick.
  - **pooledLOPO** (prereg: one refit on all other participants' pool rows, lambda) becomes the **mean of the others' pool heads fitted at lambda / d**, where d is the shipped divisor closest in log2 to the number of others (D = 9 gives d = 8; d is capped at 32, so cohorts above about 45 lose accuracy).
  - The coordinator also asked whether a plain "pooled mean of heads" at lambda would do. Measured, it does not. On the synthetic register-only cohort its test predictions agree with the true pooled refit only 41% of the time at lambda = 10, against 85% for lambda / d. The lambda / d rule is therefore used.
- **Measured fidelity** (selfcheck, synthetic cohorts of 10, lambda = 10; agreement = share of test-tail predictions identical to the exact row-level refit):

  | Cohort | donor agreement | donor acc exact / heads | pooledLOPO agreement | pooledLOPO acc exact / heads |
  |---|---|---|---|---|
  | personal-signal (private cues) | 0.805 | 0.241 / 0.232 | 0.872 | 0.236 / 0.236 |
  | register-only (shared cues) | 0.753 | 0.291 / 0.296 | 0.850 | 0.872 / 0.725 |

  **Consequence:** donor and donorPlusPrior track the prereg arms closely in accuracy, so H3b's contrast is essentially preserved. pooledLOPO from heads is **weaker** than the true pooled refit when the shared signal is strong (0.725 vs 0.872 above). So `personalized - pooledLOPO` is biased in favour of the personal head, and **claim-map row 13 fires less often than it would centrally.** This bias runs in the direction that flatters the study's thesis, so it must be stated in the paper beside row 13. Row 13 still fired 10 of 10 on the register-only synthetic cohort.
- **Demonstrated on synthetic data** (selfcheck, cohorts of 10, every participant n >= 35):

  | Cohort | Step 1 (personal vs generic) | H3b mean(personal - donorPlusPrior) | H3b p | Verdict | Claim row |
  |---|---|---|---|---|---|
  | personal-signal | +11.9 pts | +8.4 pts | 0.0020 | retained | 1 |
  | register-only | +8.0 pts | +0.7 pts (upper 95% +2.9) | 0.30 | cannot separate | 4b, with row 13 firing |

- **Registered rules now active:** Step 4 runs with the section 7.3 three-way verdict (retained if the sign-flip p <= 0.05 with N_eff(H3b) >= 5; withdrawn if the upper 95% bootstrap bound on the mean is below +2 pts; otherwise cannot separate). The verdict is computed and printed on every run and carries alpha only when Steps 1 to 3 rejected. Rows 1, 2, 3 and 13 are reachable, Step 5 (H4) can carry alpha again, and the words "a model of *you*" are licensable again under section 3.1's rule.
- **When Step 4 is still unrunnable:** if any analysed result lacks round-2 arms, or there are only round-1 results, `combine` keeps Step 4 unrunnable, names the missing participants, and applies the section 7.3 "Enforcement" rule (claim-map row 3). Round-2 results from different donors builds (different manifest hashes) are refused outright.
- **Remaining differences from the central design:**
  1. **Donor pool membership** is the set of people who sent weights, frozen by the donors manifest hash. Under the central design it was the scored cohort. Someone who sends weights but no round-2 result still sits in everyone's donor pool. Register: the donors build happens once, after `D_freeze`, from the weights of the frozen cohort.
  2. **Withdrawal (X10)** now means deleting that person's weights, rebuilding the donors, and every remaining participant re-running round 2. After the claim-bearing run, X10 window (iii) applies unchanged.
  3. **Minimum cohort:** the donors step refuses fewer than 3 non-P0 participants with weights. That is stricter than the prereg's N10 >= 2, so that no donors file ever contains a single other person's head.
  4. **Volume matching** is in expectation (above), not exact.
- **Privacy:** see CONSENT-CHANGES.md section 3. In dual form a ridge head is W0 plus a label-weighted sum of the person's own entry embeddings, so weights are derived from the journal and carry some information about it.

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

1. D4: accept the two-round weights design as the registered implementation of section 7.3. That means donor = mean of others' K heads, pooledLOPO = mean of others' pool heads at lambda / d, the donor pool frozen by the manifest, and the minimum of 3 participants. Also register the pooledLOPO bias disclosure beside claim-map row 13.
2. D4: decide whether weights sharing is required for enrolment or optional. If optional, anyone who declines makes Step 4 unrunnable for the whole cohort, which falls back to row 3. Requiring it makes the consent's refusal path "this study cannot take you", as in 2.1's section 3b.
3. D7: typed entries in the primary analysis (current default) or in a sensitivity only.
4. D3: register the collection procedure that replaces the software interlock (unopened results folder, receipt ledger with hashes, single pooled run after `D_freeze`).
5. D10: decide which export v2 fields to add before enrolment (consent timestamp, intensity, per-week counters).
6. Lambda provenance (section 4.5 P13): lambda = 10 is still unswept on any data in this feature space. A synthetic sweep should be run and recorded before the freeze, as section 4.5 already requires.
7. Power (section 6.5, P11): every power figure in the prereg was computed for the old feature space and design and should be recomputed or explicitly carried over.
