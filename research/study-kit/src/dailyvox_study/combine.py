"""Cohort analysis over result files (prereg section 6, plus the descriptive tier).

WHY it refuses so much: in the decentralised design anyone can run `combine`,
and result files arrive by hand. The integrity of the pooled answer depends
on four refusals, each of which fails loudly and lists the offending files:

  * duplicates: the same participant_code twice, or the same export bytes
    (input_sha256) twice, would double-count a person;
  * mixed protocol_hash / tool_version / embedding_model / generic head:
    numbers computed under different protocols are not the same quantity;
  * mixing synthetic and real results;
  * real results before the data freeze (exit code 22, the prereg's own
    interlock number): pooled real outcomes must not be seen before the
    freeze date is declared.

The tests follow the fixed sequence in prereg section 6.1: Step 1 exact
sign-flip on per-person Delta-acc at K=25; Step 1b per-user McNemar combined
by Fisher; Step 2 win-rate with ties = losses against exact k*(N25); Step 3
personalized vs prior-only; Step 4 (H3b) is unrunnable here (DEVIATIONS D4);
Step 5 win-rate at K=10 over N10. Everything else is descriptive.
"""

from __future__ import annotations

import json
import statistics
from collections import Counter, defaultdict
from dataclasses import dataclass
from datetime import date
from pathlib import Path
from typing import Any, Iterable

import numpy as np

from .claims import ClaimInput, select_claim
from .protocol import (
    ALPHA, BOOTSTRAP_DRAWS, FALLBACK_D_MIN, GAP_SENSITIVITY_MAX, INFERIORITY_DELTA,
    INFERIORITY_WIN_PROB, K_BREADTH, K_GRID, K_PRIMARY, LAMBDA_ADAPT, LAMBDA_FALLBACK,
    LAMBDA_SWEEP, LOW_D_THRESHOLD, MIN_LABELLED_ANY, TEST_CAP,
)
from .schema import ResultError, validate_result
from .stats import (
    binom_sf, bootstrap_upper, clopper_pearson_upper, critical_wins, fisher_combine,
    mcnemar_one_sided, one_sided_intervals, sign_flip_test,
)

FREEZE_EXIT = 22


class CombineError(RuntimeError):
    """The set of result files cannot be pooled; the message lists why."""


class FreezeInterlock(RuntimeError):
    """Real results may not be pooled before the declared data freeze."""


def collect_paths(inputs: Iterable[str]) -> list[Path]:
    paths: list[Path] = []
    for item in inputs:
        p = Path(item)
        if p.is_dir():
            paths.extend(sorted(x for x in p.glob("*.json") if x.is_file()))
        elif p.is_file():
            paths.append(p)
        else:
            raise CombineError(f"not a file or directory: {item}")
    if not paths:
        raise CombineError("no result files found")
    return paths


def load_results(paths: list[Path]) -> list[tuple[Path, dict[str, Any]]]:
    out, errors = [], []
    for p in paths:
        try:
            doc = json.loads(p.read_text("utf-8"))
            validate_result(doc, str(p))
            out.append((p, doc))
        except (json.JSONDecodeError, ResultError, UnicodeDecodeError) as exc:
            errors.append(f"{p}: {exc}")
    if errors:
        raise CombineError("invalid result files:\n  - " + "\n  - ".join(errors))
    return out


def check_cohort(results: list[tuple[Path, dict[str, Any]]]) -> None:
    problems: list[str] = []
    for key, label in (("participant_code", "participant_code"),
                       ("input_sha256", "input_sha256 (same export file)")):
        groups: dict[str, list[str]] = defaultdict(list)
        for p, d in results:
            groups[d[key]].append(str(p))
        for value, files in sorted(groups.items()):
            if len(files) > 1:
                problems.append(f"duplicate {label} {value[:16]}: " + ", ".join(files))
    for key in ("protocol_hash", "tool_version", "embedding_model", "generic_head_sha256",
                "synthetic"):
        groups = defaultdict(list)
        for p, d in results:
            groups[str(d.get(key))].append(str(p))
        if len(groups) > 1:
            detail = "; ".join(f"{v[:20]} <- {', '.join(f)}" for v, f in sorted(groups.items()))
            problems.append(f"mixed {key}: {detail}")
    if problems:
        raise CombineError("refusing to combine:\n  - " + "\n  - ".join(problems))


def check_freeze(results: list[tuple[Path, dict[str, Any]]], freeze_date: str | None,
                 today: date | None = None) -> None:
    if all(d.get("synthetic") for _, d in results):
        return
    today = today or date.today()
    if not freeze_date:
        raise FreezeInterlock("these are real (non-synthetic) results. The pre-registration "
                              "forbids pooling outcomes before the data freeze. Re-run with "
                              "--freeze-date YYYY-MM-DD (the registered D_freeze).")
    try:
        fd = date.fromisoformat(freeze_date)
    except ValueError as exc:
        raise FreezeInterlock(f"--freeze-date {freeze_date!r} is not YYYY-MM-DD") from exc
    if fd > today:
        raise FreezeInterlock(f"the data freeze ({fd}) has not passed yet (today is {today}).")


# --- per-participant accessors for the active lambda ----------------------------

@dataclass
class Person:
    code: str
    platform: str
    m: int
    n: int
    n_typed: int
    acc_generic: float
    acc25: float
    acc10: float
    acc_po25: float
    b: int
    c: int
    d: int
    b10: int
    c10: int
    b_po: int
    c_po: int
    in_n25: bool
    doc: dict[str, Any]

    @property
    def delta1(self) -> float:
        return (self.c - self.b) / self.m

    @property
    def delta3(self) -> float:
        return (self.c_po - self.b_po) / self.m

    @property
    def delta10(self) -> float:
        return (self.c10 - self.b10) / self.m


def person(doc: dict[str, Any], lam_key: str | None) -> Person:
    """Read the primary quantities at lambda_adapt (lam_key None) or a variant."""
    in25 = bool(doc.get("in_n25"))
    m = doc["test_size"]
    if lam_key is None:
        prim = doc.get("primary") or {}
        acc = doc["acc"]
        acc25, acc10 = acc.get("k25"), acc.get("k10")
        acc_po25 = doc["arms"]["prior_only"].get("k25")
        b, c, d = prim.get("b", 0), prim.get("c", 0), prim.get("d", 0)
        b10, c10 = doc["breadth"]["b"], doc["breadth"]["c"]
        b_po, c_po = prim.get("b_vs_prior_only", 0), prim.get("c_vs_prior_only", 0)
    else:
        blk = doc["lambda_variants"][lam_key]
        acc25, acc10 = blk["acc"].get("k25"), blk["acc"].get("k10")
        acc_po25 = blk["acc_prior_only"].get("k25")
        d25 = blk.get("discordance_k25") or {}
        b, c, d = d25.get("b", 0), d25.get("c", 0), d25.get("d", 0)
        b10, c10 = blk["discordance_k10"]["b"], blk["discordance_k10"]["c"]
        po = blk.get("discordance_vs_prior_only_k25") or {}
        b_po, c_po = po.get("b", 0), po.get("c", 0)
    return Person(code=doc["participant_code"], platform=doc["platform"], m=m,
                  n=doc["n_labelled"], n_typed=doc["n_typed"],
                  acc_generic=doc["acc"]["generic"], acc25=acc25 if acc25 is not None else float("nan"),
                  acc10=acc10, acc_po25=acc_po25 if acc_po25 is not None else float("nan"),
                  b=b, c=c, d=d, b10=b10, c10=c10, b_po=b_po, c_po=c_po, in_n25=in25, doc=doc)


def wtl(values: Iterable[float]) -> dict[str, int]:
    v = list(values)
    return {"wins": sum(1 for x in v if x > 0), "ties": sum(1 for x in v if x == 0),
            "losses": sum(1 for x in v if x < 0)}


def _mean(xs: list[float]) -> float | None:
    return float(np.mean(xs)) if xs else None


def _median(xs: list[float]) -> float | None:
    return float(statistics.median(xs)) if xs else None


def step1b(people: list[Person]) -> dict[str, Any]:
    pvec = {p.code: mcnemar_one_sided(p.b, p.c) for p in people}
    defined = [v for v in pvec.values() if v is not None]
    combined = fisher_combine(defined) if defined else None
    loo = {}
    for code in pvec:
        rest = [v for k, v in pvec.items() if k != code and v is not None]
        loo[code] = fisher_combine(rest) if rest else None
    return {"p": combined, "per_user_p": pvec, "undefined_b_eq_c_eq_0": len(pvec) - len(defined),
            "leave_one_out_p": loo, "reject": combined is not None and combined <= ALPHA,
            "note": "exact per user, conservative after Fisher combination on discrete p-values"}


def k_half(curve_by_user: list[dict[int, float]]) -> int | None:
    means = {k: _mean([u[k] for u in curve_by_user if k in u]) for k in (5, 10, 25)}
    if means[25] is None or means[25] <= 0:
        return None
    for k in (5, 10, 25):
        if means[k] is not None and means[k] >= 0.5 * means[25]:
            return k
    return None


def analyse_cohort(results: list[dict[str, Any]], p0_codes: set[str] | None = None,
                   strata: dict[str, str] | None = None) -> dict[str, Any]:
    p0_codes = p0_codes or set()
    strata = strata or {}
    rep: dict[str, Any] = {}
    first = results[0]
    rep["header"] = {k: first.get(k) for k in ("tool_version", "protocol_hash", "embedding_model",
                                                "generic_head_sha256", "synthetic")}
    rep["header"]["files"] = len(results)
    rep["header"]["p0_excluded"] = sorted(c for c in p0_codes
                                          if any(r["participant_code"] == c for r in results))
    non_p0 = [r for r in results if r["participant_code"] not in p0_codes]
    nc = [r for r in non_p0 if r["n_labelled"] >= MIN_LABELLED_ANY]
    n10_docs = [r for r in non_p0 if r.get("in_n10")]
    n25_docs = [r for r in non_p0 if r.get("in_n25") and r["status"] == "ok"]
    status_counts = Counter(r["status"] for r in results)
    rep["cohort"] = {"files": len(results), "status": dict(status_counts), "N_c": len(nc),
                     "N10": len(n10_docs), "N25": len(n25_docs),
                     "excluded_under_30": sum(1 for r in non_p0 if r["n_labelled"] < MIN_LABELLED_ANY)}

    # --- section 6.6 lambda branch, decided on label-free d only -----------------
    d10 = [r["disagreement_d"]["lambda_10"] for r in n25_docs]
    d1 = [r["disagreement_d"]["lambda_1"] for r in n25_docs]
    med10, med1 = _median(d10), _median(d1)
    switch = med10 is not None and med10 <= LOW_D_THRESHOLD and med1 >= FALLBACK_D_MIN
    lam_key = f"lambda_{int(LAMBDA_FALLBACK)}" if switch else None
    active_lambda = LAMBDA_FALLBACK if switch else LAMBDA_ADAPT
    people25 = [person(r, lam_key) for r in n25_docs]
    people10 = [person(r, lam_key) for r in n10_docs]
    d_active = [p.d for p in people25]
    med_active = _median(d_active)
    low_d = med_active is not None and med_active <= LOW_D_THRESHOLD
    d_zero_majority = bool(people25) and sum(1 for x in d_active if x == 0) > len(people25) / 2
    rep["disagreement"] = {
        "median_d_by_lambda": {f"lambda_{int(l)}": _median([r["disagreement_d"][f"lambda_{int(l)}"]
                                                             for r in n25_docs]) for l in LAMBDA_SWEEP},
        "lambda_switched_to_fallback": switch, "active_lambda": active_lambda,
        "median_d_active": med_active, "low_d_branch": low_d,
        "d_zero_for_majority": d_zero_majority,
    }

    n25 = len(people25)
    # --- Step 1 ---------------------------------------------------------------
    deltas1 = [p.delta1 for p in people25]
    s1 = sign_flip_test(deltas1) if people25 else {"n": 0, "n_eff": 0, "p": None, "method": "none"}
    ties1 = sum(1 for x in deltas1 if x == 0)
    neff1 = n25 - ties1
    s1_reject = bool(people25) and s1["p"] <= ALPHA and neff1 >= 5
    # --- Step 1b --------------------------------------------------------------
    s1b = step1b(people25) if people25 else {"p": None, "reject": False, "per_user_p": {},
                                              "undefined_b_eq_c_eq_0": 0, "leave_one_out_p": {}}
    # --- Step 2 ---------------------------------------------------------------
    w1 = wtl(deltas1)
    kstar25 = critical_wins(n25) if n25 else None
    s2_pass = kstar25 is not None and w1["wins"] >= kstar25
    s2_p = binom_sf(w1["wins"], n25, 0.5) if n25 else None
    # --- Step 3 ---------------------------------------------------------------
    deltas3 = [p.delta3 for p in people25]
    s3 = sign_flip_test(deltas3) if people25 else {"p": None, "n_eff": 0}
    s3_reject = bool(people25) and s3["p"] <= ALPHA and s3["n_eff"] >= 5
    # --- Step 5 ---------------------------------------------------------------
    deltas10 = [p.delta10 for p in people10]
    w10 = wtl(deltas10)
    kstar10 = critical_wins(len(people10)) if people10 else None
    s5_pass = kstar10 is not None and w10["wins"] >= kstar10

    # Primary statistic for the sequence: Step 1, or Step 1b in the low-d branch.
    if low_d:
        neff_rows = n25 - s1b["undefined_b_eq_c_eq_0"]
        primary_reject = s1b["reject"]
    else:
        neff_rows = neff1
        primary_reject = s1_reject
    seq: list[dict[str, Any]] = []
    stopped_at = None
    by_construction = n25 <= 4 or neff_rows < 5

    def record(step: str, test: str, outcome: str, carries_alpha: bool) -> None:
        seq.append({"step": step, "test": test, "outcome": outcome, "carries_alpha": carries_alpha})

    if by_construction:
        record("1", "H1 sign-flip", "INCONCLUSIVE-BY-CONSTRUCTION" if n25 > 4 else "not run (N25 <= 4)", False)
        record("1b", "Step 1b McNemar+Fisher (only confirmatory test available)",
               "reject" if s1b["reject"] else "not rejected", True)
        stopped_at = "1"
    else:
        steps = []
        if low_d:
            steps.append(("1b", "Step 1b McNemar+Fisher (primary, median d <= 2)", s1b["reject"]))
            steps.append(("1", "H1 sign-flip (descriptive in this branch)", s1_reject))
        else:
            steps.append(("1", "H1 sign-flip on Delta-acc(K=25)", s1_reject))
            steps.append(("1b", "Step 1b McNemar+Fisher", s1b["reject"]))
        steps += [("2", "H2 win-rate (ties = losses)", s2_pass),
                  ("3", "H3 personalized vs prior-only", s3_reject),
                  ("4", "H3b personalized vs donorPlusPrior", None),
                  ("5", "H4 win-rate at K=10 over N10", s5_pass)]
        alive = True
        for step, test, ok in steps:
            if low_d and step == "1":
                record(step, test, "reject" if ok else "not rejected", False)
                continue
            if not alive:
                record(step, test, "computed, no alpha (sequence stopped)" if ok is not None
                       else "UNRUNNABLE (DEVIATIONS D4)", False)
                continue
            if ok is None:
                record(step, test, "UNRUNNABLE (DEVIATIONS D4): sequence stops here", False)
                alive, stopped_at = False, step
                continue
            record(step, test, "reject" if ok else "not rejected", True)
            if not ok:
                alive, stopped_at = False, step

    rep["steps"] = {
        "step1": {**s1, "ties": ties1, "n_eff": neff1, "reject": s1_reject,
                  "mean_delta": _mean(deltas1), "per_user_delta": {p.code: p.delta1 for p in people25}},
        "step1b": s1b,
        "step2": {**w1, "n25": n25, "k_star": kstar25, "pass": s2_pass, "exact_p": s2_p},
        "step3": {**s3, "ties": sum(1 for x in deltas3 if x == 0), "reject": s3_reject,
                  "mean_delta": _mean(deltas3)},
        "step4": {"runnable": False, "verdict": "unrunnable",
                  "reason": "donorPlusPrior needs other participants' rows (DEVIATIONS D4)"},
        "step5": {**w10, "n10": len(people10), "k_star": kstar10, "pass": s5_pass,
                  "exact_p": binom_sf(w10["wins"], len(people10), 0.5) if people10 else None},
        "sequence": seq, "stopped_at": stopped_at,
    }

    # --- compound (section 3.2 printing rule) -------------------------------------
    compound_wins = sum(1 for p in people25 if p.c > p.b and p.c_po > p.b_po)
    comp = {"wins": compound_wins, "ties_or_losses": n25 - compound_wins, "n25": n25}
    if s1_reject and s2_pass:
        comp["k_star"] = kstar25
        comp["exact_p_description_only"] = binom_sf(compound_wins, n25, 0.5) if n25 else None
    else:
        comp["threshold"] = "no threshold (fixed sequence stopped before Step 2 rejected)"
    rep["compound"] = comp

    # --- inferiority criterion (section 6.3) ----------------------------------------
    cp_upper = clopper_pearson_upper(w1["wins"], n25) if n25 else None
    boot_upper = bootstrap_upper(deltas1, 0.95, BOOTSTRAP_DRAWS) if deltas1 else None
    inferiority = (n25 >= 5 and cp_upper is not None and cp_upper < INFERIORITY_WIN_PROB
                   and boot_upper is not None and boot_upper < INFERIORITY_DELTA and neff1 >= 5)
    rep["inferiority"] = {"clopper_pearson_upper": cp_upper, "bootstrap_upper_mean_delta": boot_upper,
                          "met": inferiority}

    # --- row 12 sub-chance check ------------------------------------------------------
    below_chance = sum(1 for p in people25 if p.acc_generic < p.doc["empirical_chance_threshold"])
    mean_gen = _mean([p.acc_generic for p in people25])
    mean_maj = _mean([p.doc["baselines"]["majority_of_pool"] for p in people25])
    sub_chance = bool(people25) and (below_chance > n25 / 2 or (mean_gen or 0) < (mean_maj or 0))
    over_chance = _mean([100 * (p.acc25 - p.doc["empirical_chance_threshold"]) for p in people25])
    rep["sub_chance"] = {"n_generic_below_empirical_chance": below_chance,
                         "mean_acc_generic": mean_gen, "mean_acc_majority_of_pool": mean_maj,
                         "triggered": sub_chance,
                         "mean_points_over_empirical_chance_k25": over_chance}

    persistence_majority = bool(people25) and sum(
        1 for p in people25 if p.doc["primary"]["persistence_full_beats_personalized"]) > n25 / 2
    h3_vs_compound = bool(people25) and (s3_reject != (kstar25 is not None and compound_wins >= kstar25))
    stranger_won = None
    if strata:
        strangers = [p for p in people25 if strata.get(p.code) == "stranger"]
        stranger_won = any(p.delta1 > 0 for p in strangers)

    # --- section 7.7 recency arm --------------------------------------------------------
    rec = {}
    for k in (5, 10):
        diffs = [r["arms"]["personalized"][f"k{k}"] - r["arms"]["recency_last_k"][f"k{k}"]
                 for r in n10_docs if r["arms"]["personalized"].get(f"k{k}") is not None]
        rec[f"k{k}"] = {"n": len(diffs), "mean_first_minus_last": _mean(diffs),
                        **({"interval_90": one_sided_intervals(diffs, 0.90, BOOTSTRAP_DRAWS)}
                           if len(diffs) >= 2 else {})}
    recency_wins = all(rec[f"k{k}"]["mean_first_minus_last"] is not None
                       and rec[f"k{k}"]["mean_first_minus_last"] <= 0 for k in (5, 10))
    rep["recency"] = {**rec, "last_k_ge_first_k_at_5_and_10": recency_wins}

    claim = select_claim(ClaimInput(
        n25=n25, neff=neff_rows, ties=ties1 if not low_d else s1b["undefined_b_eq_c_eq_0"],
        low_d_branch=low_d, s1_reject=primary_reject,
        # In the low-d branch Step 1b IS the primary, so there is no separate co-primary row.
        s1b_reject=s1b["reject"] if not low_d else True,
        s2_pass=s2_pass, s3_reject=s3_reject, s4_runnable=False, inferiority_met=inferiority,
        p1=s1.get("p"), p1b=s1b.get("p"), sub_chance=sub_chance, sub_chance_points=over_chance,
        persistence_majority=persistence_majority, d_zero_majority=d_zero_majority,
        active_lambda=active_lambda, h3_vs_compound_disagree=h3_vs_compound,
        strata_given=bool(strata), stranger_won=stranger_won, recency_wins=recency_wins))
    rep["claim"] = {"row": claim.row, "headline": claim.headline, "qualifiers": claim.qualifiers,
                    "notes": claim.notes + ["Section 7.3 donor-gate verdict: unrunnable in the "
                                            "result-file-only design (DEVIATIONS D4)."]}

    rep["descriptive"] = descriptive(n25_docs, n10_docs, people25)
    rep["null"] = null_summary(n25_docs, people25, w1["wins"])
    rep["platforms"] = platform_breakdown(non_p0, people25)
    rep["sensitivity"] = sensitivity(people25)
    return rep


def descriptive(n25_docs, n10_docs, people25) -> dict[str, Any]:
    """S1, S2, S3, S4, S5, S7, S9, S10, S12: no inferential claims."""
    out: dict[str, Any] = {}
    curve = {}
    users_curve: list[dict[int, float]] = []
    for r in n10_docs:
        u = {}
        for k in K_GRID[1:]:
            a = r["acc"].get(f"k{k}")
            if a is not None:
                u[k] = a - r["acc"]["generic"]
        users_curve.append(u)
    for k in K_GRID[1:]:
        vals = [u[k] for u in users_curve if k in u]
        entry: dict[str, Any] = {"eligible_n": len(vals), "mean_delta": _mean(vals), **wtl(vals)}
        if len(vals) >= 2:
            entry["interval_90"] = one_sided_intervals(vals, 0.90, BOOTSTRAP_DRAWS)
        curve[f"k{k}"] = entry
    out["curve"] = curve
    # S9 K_half with its bootstrap histogram over N25 users
    u25 = [u for u, r in zip(users_curve, n10_docs) if r.get("in_n25")]
    kh = k_half(u25)
    hist: Counter = Counter()
    if u25:
        rng = np.random.default_rng(42)
        for _ in range(2000):
            sample = [u25[i] for i in rng.integers(0, len(u25), len(u25))]
            hist[str(k_half(sample) or "not attained")] += 1
    out["k_half"] = {"value": kh, "bootstrap_histogram": dict(hist)}
    # S4 win/tie/loss per K per comparator
    arms = {}
    for k in K_GRID[1:]:
        row = {}
        for comp in ("prior_only", "recency_last_k"):
            vals = [r["arms"]["personalized"][f"k{k}"] - r["arms"][comp][f"k{k}"]
                    for r in n10_docs if r["arms"]["personalized"].get(f"k{k}") is not None]
            row[f"vs_{comp}"] = wtl(vals)
        row["vs_generic"] = wtl([u[k] for u in users_curve if k in u])
        arms[f"k{k}"] = row
    out["wtl_by_comparator"] = arms
    # S2/S3/S5
    def avg(path_fn, docs):
        vals = [path_fn(r) for r in docs]
        vals = [v for v in vals if v is not None]
        return _mean(vals)
    out["macro_f1_mean"] = {f"k{k}": avg(lambda r, k=k: r["macro_f1"].get(f"k{k}"), n10_docs)
                            for k in K_GRID}
    out["neutral_recall_mean"] = {f"k{k}": avg(lambda r, k=k: r["neutral_recall"].get(f"k{k}"), n10_docs)
                                  for k in K_GRID}
    out["collapse_rate_mean"] = {f"k{k}": avg(lambda r, k=k: r["collapse_rate"].get(f"k{k}"), n10_docs)
                                 for k in K_GRID}
    out["prior_drift_tv_mean"] = {f"k{k}": avg(lambda r, k=k: r["prior_drift_tv"].get(f"k{k}"), n10_docs)
                                  for k in K_GRID[1:]}
    out["test_support_total"] = dict(sum((Counter(r["test_support"]) for r in n10_docs), Counter()))
    # references
    refs = {}
    for name in ("persistence_full", "persistence_frozen", "majority_of_k25", "majority_of_pool",
                 "stratified_chance"):
        refs[name] = avg(lambda r, n=name: r["baselines"].get(n), n25_docs)
    refs["acc_generic"] = _mean([p.acc_generic for p in people25])
    refs["acc_k25"] = _mean([p.acc25 for p in people25])
    out["reference_lines_mean_n25"] = refs
    out["empirical_chance_by_m"] = {f"m{r['test_size']}": r["empirical_chance_threshold"]
                                    for r in n10_docs}
    out["labelling"] = {w: {s: avg(lambda r, w=w, s=s: r["labelling"][w][s], n10_docs)
                            for s in ("entropy_bits", "longest_run", "switch_rate")}
                        for w in ("pool", "test")}
    out["gap_primary"] = {p.code: p.doc["gap_primary"] for p in people25}
    out["solver_failures"] = sum(r["solver"]["failed"] for r in n10_docs)
    out["solver_attempts"] = sum(r["solver"]["attempted"] for r in n10_docs)
    out["lambda_sweep_post_hoc"] = {
        f"lambda_{int(l)}": _mean([
            (r["delta_primary"] if l == LAMBDA_ADAPT else
             ((r["lambda_variants"][f"lambda_{int(l)}"]["discordance_k25"]["c"]
               - r["lambda_variants"][f"lambda_{int(l)}"]["discordance_k25"]["b"]) / r["test_size"]))
            for r in n25_docs]) for l in LAMBDA_SWEEP}
    return out


def null_summary(n25_docs, people25, observed_wins: int) -> dict[str, Any]:
    """Section 7.5: the null as a diagnostic, never displacing the binomial primary."""
    if not n25_docs:
        return {}
    nets = np.array([r["null_arm"]["net_primary"] for r in n25_docs])        # (N, P)
    null_wins = (nets > 0).sum(axis=0)
    mean_null = _mean([r["null_arm"]["mean_delta_primary"] for r in n25_docs])
    mean_null0 = _mean([r["null_arm"]["delta_primary"] for r in n25_docs])
    mean_prior = _mean([p.acc_po25 - p.acc_generic for p in people25])
    return {
        "mean_null_delta_primary_over_permutations": mean_null,
        "mean_null_delta_primary_first_permutation": mean_null0,
        "mean_prior_only_delta_primary": mean_prior,
        "null_win_rate_mean": float(null_wins.mean() / len(n25_docs)),
        "observed_win_count": observed_wins,
        "observed_win_percentile_vs_null": float(np.mean(null_wins < observed_wins)),
        "per_user_p": {r["participant_code"]: r["null_arm"].get("p_user") for r in n25_docs},
        "n_permutations": int(nets.shape[1]),
    }


def platform_breakdown(non_p0, people25) -> dict[str, Any]:
    out: dict[str, Any] = {}
    for plat in sorted({r["platform"] for r in non_p0}):
        docs = [r for r in non_p0 if r["platform"] == plat]
        ps = [p for p in people25 if p.platform == plat]
        total = sum(r["n_labelled"] for r in docs)
        out[plat] = {
            "files": len(docs), "N25": len(ps), "N10": sum(1 for r in docs if r.get("in_n10")),
            "typed_share": (sum(r["n_typed"] for r in docs) / total) if total else None,
            "mean_acc_generic": _mean([p.acc_generic for p in ps]),
            "mean_acc_k25": _mean([p.acc25 for p in ps]),
            "mean_delta_primary": _mean([p.delta1 for p in ps]), **wtl([p.delta1 for p in ps]),
        }
    total = sum(r["n_labelled"] for r in non_p0)
    shares = [r["n_typed"] / r["n_labelled"] for r in non_p0 if r["n_labelled"]]
    out["all"] = {"typed_share": (sum(r["n_typed"] for r in non_p0) / total) if total else None,
                  "voice_share": (sum(r["n_voice"] for r in non_p0) / total) if total else None,
                  "per_person_typed_share_min": min(shares) if shares else None,
                  "per_person_typed_share_median": _median(shares),
                  "per_person_typed_share_max": max(shares) if shares else None}
    if len(people25) >= 3:
        x = np.array([p.n_typed / p.n for p in people25])
        yv = np.array([p.delta1 for p in people25])
        out["all"]["corr_typed_share_vs_delta"] = (float(np.corrcoef(x, yv)[0, 1])
                                                   if x.std() > 0 and yv.std() > 0 else None)
    return out


def sensitivity(people25: list[Person]) -> dict[str, Any]:
    """E2, E3, E3b, X15: subject to the section 3.4 directional rule."""
    def flip(ps, fn):
        if not ps:
            return {"n": 0, "p": None}
        r = sign_flip_test([fn(p) for p in ps])
        return {"n": r["n"], "n_eff": r["n_eff"], "p": r["p"], "mean": _mean([fn(p) for p in ps])}
    out = {
        "E2_uncapped_tail": flip(people25, lambda p: p.doc["sensitivity"]["uncapped_delta_primary"]),
        "voice_only_entries": flip(
            [p for p in people25 if p.doc["sensitivity"].get("voice_only_delta_primary") is not None],
            lambda p: p.doc["sensitivity"]["voice_only_delta_primary"]),
        "E3_tier1_only": flip([p for p in people25 if p.m == TEST_CAP], lambda p: p.delta1),
        "E3b_pooled_net_entries": flip(people25, lambda p: float(p.c - p.b)),
        "X15_gap_le_25": flip([p for p in people25 if p.doc["gap_primary"] <= GAP_SENSITIVITY_MAX],
                              lambda p: p.delta1),
        "X15_gap_eq_0": flip([p for p in people25 if p.doc["gap_primary"] == 0], lambda p: p.delta1),
    }
    out["directional_rule"] = ("A declared sensitivity analysis can only weaken, never "
                               "strengthen, the primary conclusion (prereg section 3.4).")
    return out
