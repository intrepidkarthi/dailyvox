"""Drive the full two-round flow on a set of exports (used by selfcheck and tests).

WHY in one place: the two-round protocol has three actors (participant,
coordinator, participant again). Simulating all of them through the same
public functions the CLI uses is the only honest end-to-end check, and the
selfcheck needs it for two contrasting synthetic cohorts.

`approximation_check` additionally measures, on synthetic data where the rows
ARE available, how closely the head-built donor and pooledLOPO heads match the
pre-registration's row-level refits. That number is what DEVIATIONS.md D4 cites.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any

import numpy as np

from .combine import analyse_cohort, check_cohort, load_results
from .generic import GenericHead
from .heads import add_bias, fit_ridge_to_prior, predict
from .pipeline import run_export_full
from .protocol import K_PRIMARY, LABEL_INDEX, LAMBDA_ADAPT
from .split import make_split
from .weights import build_donors, choose_divisor, load_weights, write_donors


def run_two_round(exports: list[Path], head: GenericHead, work: Path,
                  p0: set[str] | None = None) -> dict[str, Any]:
    r1_dir, w_dir, d_dir, r2_dir = (work / s for s in ("round1", "weights", "donors", "round2"))
    for d in (r1_dir, w_dir, r2_dir):
        d.mkdir(parents=True, exist_ok=True)
    codes: dict[Path, str] = {}
    for p in exports:
        out = run_export_full(p, head=head)
        code = out.result["participant_code"]
        codes[p] = code
        (r1_dir / f"result-{code}.json").write_text(out.text, "utf-8")
        if out.weights_text is not None:
            (w_dir / f"weights-{code}.json").write_text(out.weights_text, "utf-8")
    donors, manifest = build_donors(load_weights([w_dir]), p0)
    write_donors(d_dir, donors, manifest)
    for p, code in codes.items():
        dpath = d_dir / f"donors-{code}.json"
        if dpath.exists():
            out = run_export_full(p, head=head, donors_path=dpath)
        else:                       # under 30 entries: no weights, so no round 2 for them
            out = run_export_full(p, head=head)
        (r2_dir / f"result-{code}.json").write_text(out.text, "utf-8")
    loaded = load_results(sorted(r2_dir.glob("*.json")))
    check_cohort(loaded)
    rep = analyse_cohort([d for _, d in loaded], p0)
    return {"report": rep, "manifest": manifest, "dirs": {"round1": r1_dir, "weights": w_dir,
                                                          "donors": d_dir, "round2": r2_dir}}


def approximation_check(exports: list[Path], head: GenericHead, embed) -> dict[str, float]:
    """Prediction agreement of head-built donor / pooledLOPO with exact row-level refits."""
    people = []
    for p in exports:
        doc = json.loads(p.read_text("utf-8"))
        ents = [e for e in doc["entries"] if e["text"].strip()]
        if len(ents) < 35:
            continue
        Xb = add_bias(embed([e["text"] for e in ents]))
        y = np.array([LABEL_INDEX[e["self_label"]] for e in ents])
        people.append((Xb, y, make_split(len(y))))
    W0, lam = head.W, LAMBDA_ADAPT
    agree_d, agree_p, acc = [], [], {"donor_exact": [], "donor_heads": [],
                                     "pooled_exact": [], "pooled_heads": []}
    for i, (X, y, sp) in enumerate(people):
        others = [j for j in range(len(people)) if j != i]
        # exact donor: K rows round-robin over others in order, oldest first (prereg F2b)
        rows, ptr = [], {j: 0 for j in others}
        while len(rows) < K_PRIMARY:
            for j in others:
                if len(rows) < K_PRIMARY and ptr[j] < min(K_PRIMARY, people[j][2].pool):
                    rows.append((j, ptr[j]))
                    ptr[j] += 1
        Wd = fit_ridge_to_prior(np.array([people[j][0][r] for j, r in rows]),
                                np.array([people[j][1][r] for j, r in rows]), W0, lam)
        Wd_h = np.mean([fit_ridge_to_prior(people[j][0][:25], people[j][1][:25], W0, lam)
                        for j in others], axis=0)
        Xp = np.vstack([people[j][0][:people[j][2].pool] for j in others])
        yp = np.concatenate([people[j][1][:people[j][2].pool] for j in others])
        Wp = fit_ridge_to_prior(Xp, yp, W0, lam)
        div = choose_divisor(len(others))
        Wp_h = np.mean([fit_ridge_to_prior(people[j][0][:people[j][2].pool],
                                           people[j][1][:people[j][2].pool], W0, lam / div)
                        for j in others], axis=0)
        T, g = X[sp.test_slice], y[sp.test_slice]
        pd, pdh, pp, pph = (predict(T, W) for W in (Wd, Wd_h, Wp, Wp_h))
        agree_d.append(np.mean(pd == pdh))
        agree_p.append(np.mean(pp == pph))
        for k, pr in (("donor_exact", pd), ("donor_heads", pdh), ("pooled_exact", pp),
                      ("pooled_heads", pph)):
            acc[k].append(np.mean(pr == g))
    return {"donor_agreement": float(np.mean(agree_d)), "pooled_agreement": float(np.mean(agree_p)),
            **{f"acc_{k}": float(np.mean(v)) for k, v in acc.items()}}
