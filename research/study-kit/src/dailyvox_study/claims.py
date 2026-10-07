"""The pre-written outcome sentences (prereg section 6.4, the claim map).

WHY this is code and not prose: the pre-registration fixes, before any data
exists, which sentence gets published for each pattern of results, so that
nobody can choose wording after seeing the numbers. Encoding the map as a
function of the test outcomes makes the choice mechanical. The sentences are
copied from preregistration-FINAL-draft.md section 6.4 (v2.1) with only the
blanks filled; the precedence order is the one registered there.

One registered rule matters specially here: the donor arms exist only after the
two-round weights exchange (weights.py). Until every analysed participant's
round-2 result is in, Step 4 (H3b) is unrunnable for the cohort, and the
prereg's own rule for that case (section 7.3, "Enforcement") is that claim-map
row 3 fires in place of rows 1 and 2. See DEVIATIONS.md D4.
"""

from __future__ import annotations

from dataclasses import dataclass, field

INTERPRETIVE_RULE = ("This is consistent with spoken-register adaptation and is not a "
                     "person-specificity claim (prereg section 3.1).")

FAILURE_CLAUSE = (
    "A gate miss at N25 <= 7 is recorded as underpowered, not falsified: on the mixed "
    "Tier-1/Tier-2 cohort of split-and-power.md section 5.3, under a true +10 pt per-user "
    "lift, the primary test has power 0.39-0.64 at N25 = 5-8 and the win-rate gate has power "
    "0.15-0.39; the homogeneous all-Tier-1 cohort is better powered above N=5 (permutation "
    ".825 at N=8 and .920 at N=10, against .640 and .683 mixed), while at N=5 the two cohorts "
    "coincide and the printed .386-vs-.393 difference is Monte-Carlo noise, not a real "
    "difference, so this clause is conservative in the direction that matters.")

ROWS = {
    "1": ("A head adapted on a person's own 25 entries beats the generic head for a significant "
          "majority of participants, and the lift is explained neither by label-prior refitting "
          "nor by shared spoken-register adaptation."),
    "2": ("A head adapted on a person's own 25 entries beats the generic head for a significant "
          "majority of participants, not explained by label-prior refitting, but a head fitted on "
          "other participants' entries performs at least as well; we report this as "
          "spoken-register domain adaptation, not personalization."),
    "3": ("A head adapted on a person's own 25 entries beats the generic head for a significant "
          "majority of participants, not explained by label-prior refitting; we cannot separate "
          "personalization from shared spoken-register adaptation at this cohort size, and the "
          "point estimate and interval for personalized - donorPlusPrior are reported in the "
          "abstract."),
    "4": ("Adapting on a participant's own entries improves accuracy for a significant majority, "
          "but we cannot distinguish this from the head learning each participant's label base "
          "rates. " + INTERPRETIVE_RULE + " The personalized - donorPlusPrior point estimate, "
          "interval and section 7.3 verdict are reported beside it and carry no alpha."),
    "4b": ("Mixed: the mean per-user lift at K=25 is positive in this cohort (Step 1, p = {p1}), "
           "but the per-user discordant-pair evidence combined across participants does not "
           "reach alpha (Step 1b, p = {p1b}). We report both, make no majority claim, and treat "
           "the result as inconclusive about whether the lift is carried by more than one or two "
           "participants; the per-user p-vector and the leave-one-out recomputation are "
           "published in full. " + INTERPRETIVE_RULE),
    "5": ("Mean per-user lift at K=25 is positive in this cohort. (Step 2 not passed; no majority "
          "claim. The compound win-rate is printed as a bare count with no threshold and no "
          "p-value. " + INTERPRETIVE_RULE + " The section 7.3 donor-gate verdict is reported "
          "beside it.)"),
    "6": "Underpowered, not falsified. " + FAILURE_CLAUSE + " " + INTERPRETIVE_RULE,
    "7": ("Inconclusive: the pre-registered primary did not reject at N25 = {n25}, where power "
          "under a +10 pt truth is 0.83-0.92 on an all-Tier-1 cohort (permutation; .825 at "
          "N25 = 8, .920 at N25 = 10) and 0.64-0.70 on the mixed Tier-1/Tier-2 cohort of "
          "split-and-power.md section 5.3 (permutation; .640 / .648 / .683 / .701 at N25 = "
          "8 / 9 / 10 / 11). The win-rate gate on that same mixed cohort runs .355 / .254 / "
          ".178 / .338 over N25 = 8-11, non-monotone, which is the sawtooth. We treat this as "
          "underpowered rather than falsifying, and report the per-user curves. "
          + INTERPRETIVE_RULE),
    "8": ("Evidence against the twin thesis at K=25 in this cohort: the data bound the per-user "
          "win probability below 0.70 and the mean per-user lift below +6 points."),
    "9": ("Inconclusive by construction: with {ties} of {n25} participants at an exact tie and "
          "N_eff = {neff}, no sign-flip pattern could have reached alpha at any effect size. "
          "Reported with tie counts; the case-series rung and Step 1b apply."),
    "10": ("Case series only. No population claim is made. Step 1b (per-user McNemar combined by "
           "Fisher) is reported with its per-user p-vector and leave-one-out recomputation."),
    "12": ("The generic head does not clear chance on spoken diary; adaptation on a person's own "
           "entries recovers {points} points over chance."),
    "13": ("The deployment recommendation is a shared spoken-register head, not per-user "
           "adaptation."),
    "14": "...observed only among warm-recruited participants.",
    "15": ("The previous-entry persistence baseline (persistence-full) beats the personalized "
           "head at K=25 for a majority of participants."),
    "d0": ("The K=25 L2-to-generic refit at lambda = {lam} does not change predictions on this "
           "population; the personalization question is not resolvable with this adaptation "
           "mechanism."),
    "recency": "The rising segment of the curve is reported as recency, not volume.",
    "closing": ("Results pattern not in the registered claim map: reported as inconclusive, and "
                "the omission is disclosed as a pre-registration defect."),
}


@dataclass
class ClaimInput:
    n25: int
    neff: int
    ties: int
    low_d_branch: bool
    s1_reject: bool
    s1b_reject: bool
    s2_pass: bool
    s3_reject: bool
    s4_runnable: bool
    inferiority_met: bool
    p1: float | None
    p1b: float | None
    sub_chance: bool
    sub_chance_points: float | None
    persistence_majority: bool
    d_zero_majority: bool
    active_lambda: float
    h3_vs_compound_disagree: bool
    strata_given: bool
    stranger_won: bool | None
    recency_wins: bool
    s4_verdict: str = "unrunnable"        # retained | withdrawn | cannot_separate | unrunnable
    s4_unrunnable_reason: str | None = None
    pooled_majority: bool | None = None   # row 13 trigger; None = not evaluable


@dataclass
class Claim:
    row: str
    headline: str
    qualifiers: list[str] = field(default_factory=list)
    notes: list[str] = field(default_factory=list)


def _fmt_p(p: float | None) -> str:
    return "n/a" if p is None else f"{p:.4g}"


def select_claim(ci: ClaimInput) -> Claim:
    """Apply the section 6.4 precedence rule and return the published wording."""
    if ci.n25 <= 4:
        claim = Claim("10", ROWS["10"])
    elif ci.neff < 5:
        claim = Claim("9", ROWS["9"].format(ties=ci.ties, n25=ci.n25, neff=ci.neff))
    elif ci.s1_reject:
        if not ci.s1b_reject:
            claim = Claim("4b", ROWS["4b"].format(p1=_fmt_p(ci.p1), p1b=_fmt_p(ci.p1b)))
        elif not ci.s2_pass:
            claim = Claim("5", ROWS["5"])
        elif not ci.s3_reject:
            claim = Claim("4", ROWS["4"])
        elif not ci.s4_runnable:
            claim = Claim("3", ROWS["3"])
            claim.notes.append(
                "Step 4 (H3b) is unrunnable for this set of results ("
                + (ci.s4_unrunnable_reason or "no donor arms") + "); per prereg section 7.3 "
                "'Enforcement', claim-map row 3 fires.")
        elif ci.s4_verdict == "retained":
            claim = Claim("1", ROWS["1"])
        elif ci.s4_verdict == "withdrawn":
            claim = Claim("2", ROWS["2"])
        else:
            claim = Claim("3", ROWS["3"])
    else:
        if ci.inferiority_met:
            claim = Claim("8", ROWS["8"])
        elif ci.n25 <= 7:
            claim = Claim("6", ROWS["6"])
        else:
            claim = Claim("7", ROWS["7"].format(n25=ci.n25))
    if ci.low_d_branch:
        claim.notes.append("Median d <= 2 branch (prereg section 6.6): rows are read with "
                           "Step 1b in place of Step 1; the Delta-acc permutation is descriptive.")
    if ci.sub_chance:
        pts = "___" if ci.sub_chance_points is None else f"{ci.sub_chance_points:+.1f}"
        claim.notes.append("Row 12 headline replacement applies (majority-class replaces K=0 as "
                           "the reference line; H1/H2 annotated as measured against a sub-chance "
                           "comparator).")
        claim.headline = ROWS["12"].format(points=pts) + " [Statistical verdict of row " \
            + claim.row + ": " + claim.headline + "]"
    if ci.h3_vs_compound_disagree:
        claim.qualifiers.append("Row 11: H3 and the compound win-rate disagree; the H3 wording "
                                "governs and the compound is a descriptive count only.")
    if claim.row in ("4", "4b", "5"):
        claim.qualifiers.append(f"Section 7.3 donor-gate verdict (carries no alpha here): "
                                f"{ci.s4_verdict.replace('_', ' ')}.")
    if ci.pooled_majority is None:
        claim.qualifiers.append("Row 13: not evaluable (no round-2 pooledLOPO arm for this set of "
                                "results).")
    elif ci.pooled_majority:
        claim.qualifiers.append("Row 13 (abstract): " + ROWS["13"])
    if ci.strata_given and ci.stranger_won is False:
        claim.qualifiers.append("Row 14: " + ROWS["14"])
    if ci.persistence_majority:
        claim.qualifiers.append("Row 15 (abstract): " + ROWS["15"])
    claim.qualifiers.append("Row 16: withdrawals are not visible to this tool; the researcher "
                            "must state them from the enrolment ledger.")
    if ci.d_zero_majority:
        claim.qualifiers.append("Section 6.6 registered finding: "
                                + ROWS["d0"].format(lam=f"{ci.active_lambda:g}"))
    if ci.recency_wins:
        claim.qualifiers.append("Section 7.7: " + ROWS["recency"])
    return claim
