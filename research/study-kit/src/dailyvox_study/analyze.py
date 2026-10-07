"""Per-participant analysis: one export in, one numbers-only result out.

WHY it is shaped this way: in the decentralised design, everything the cohort
analysis will ever need must be computed HERE, on the participant's laptop,
because their text never travels. So this module computes, for one person:

  * the K-curve of the personalised head (prereg section 4.2-4.5),
  * the arms that can be computed from one person's data alone: prior-only
    (section 7.2), recency-matched last-K (section 7.7), and the reference
    lines persistence-full / persistence-frozen / majority-of-K (section 7.4),
  * the discordant pair (b, c) and label-free disagreement d at K = 25
    (sections 6.2, 6.6), so `combine` can run Step 1b and the low-d branch,
  * the same primary quantities at lambda = 1 and lambda = 100 (section 6.6
    fallback branch and E5), so the cohort can apply the lambda branch
    without anyone re-running,
  * a 1000-permutation null at K = 25 (section 7.5), seeded from the
    participant code (F4) so it never depends on who else is in the cohort,
  * descriptive S2/S3/S5/S10/S12 quantities and the E2 uncapped-tail delta.

Arms that need other participants' data (donor, donorPlusPrior, pooledLOPO)
are filled in round 2 from a donors file built out of the other participants'
shared heads (weights.py); in round 1 this module writes this participant's own
heads for that exchange. See DEVIATIONS.md D4.

Every value written is a number, a boolean, null, or one of a few metadata
strings (schema.RESULT_STRING_KEYS). `schema.find_free_text` enforces that,
and `assert_no_leak` checks the serialised bytes against the export's own
text, ids and timestamps before anything is written.
"""

from __future__ import annotations

import hashlib
import math
from datetime import datetime, timezone
from typing import Any, Callable

import numpy as np

from . import __version__
from .heads import SolveCounter, add_bias, fit_prior_only, fit_ridge_to_prior, predict
from .protocol import (
    CANON_LABELS, EMBEDDING_DIM, K_BREADTH, K_GRID, K_PRIMARY, LABEL_INDEX, LAMBDA_ADAPT,
    LAMBDA_SWEEP, MIN_LABELLED_PRIMARY, N_CLASSES, NULL_PERMUTATIONS, RESULT_SCHEMA, SEED,
    embedding_model_string, protocol_hash,
)
from .protocol import DONOR_KS, DONOR_LAMBDAS
from .schema import check_consent, find_free_text
from .split import Split, make_split, tier
from .stats import empirical_chance_threshold
from .weights import build_weights, find_free_text_generic, lam_key, WEIGHTS_STRING_KEYS

NEUTRAL = LABEL_INDEX["neutral"]
DECIMALS = 6


def r6(x: float | None) -> float | None:
    if x is None or (isinstance(x, float) and math.isnan(x)):
        return None
    return round(float(x), DECIMALS)


def fnv1a64(text: str) -> int:
    """FNV-1a 64-bit digest; the prereg's F4 stable per-participant seed source."""
    h = 0xCBF29CE484222325
    for byte in text.encode("utf-8"):
        h ^= byte
        h = (h * 0x100000001B3) & 0xFFFFFFFFFFFFFFFF
    return h


def null_seed(code: str, j: int) -> int:
    return (SEED + 0xB0B0 + fnv1a64(code) + j * 0x9E3779B97F4A7C15) & 0xFFFFFFFFFFFFFFFF


# --- metric helpers ----------------------------------------------------------

def correct_count(pred: np.ndarray, gold: np.ndarray) -> int:
    return int(np.sum(pred == gold))


def macro_f1_present(pred: np.ndarray, gold: np.ndarray) -> float:
    """Macro-F1 over the classes present in this test gold (prereg S2)."""
    f1s = []
    for c in np.unique(gold):
        tp = int(np.sum((pred == c) & (gold == c)))
        fp = int(np.sum((pred == c) & (gold != c)))
        fn = int(np.sum((pred != c) & (gold == c)))
        f1s.append(2 * tp / (2 * tp + fp + fn) if (2 * tp + fp + fn) else 0.0)
    return float(np.mean(f1s))


def neutral_recall(pred: np.ndarray, gold: np.ndarray) -> float | None:
    mask = gold == NEUTRAL
    return float(np.mean(pred[mask] == NEUTRAL)) if mask.any() else None


def collapse_rate(pred: np.ndarray) -> float:
    """Max predicted-class share on the test window (prereg S3)."""
    return float(np.bincount(pred, minlength=N_CLASSES).max() / len(pred))


def distribution(y: np.ndarray) -> np.ndarray:
    return np.bincount(y, minlength=N_CLASSES) / max(len(y), 1)


def total_variation(a: np.ndarray, b: np.ndarray) -> float:
    return 0.5 * float(np.abs(distribution(a) - distribution(b)).sum())


def labelling_stats(y: np.ndarray) -> dict[str, float | int]:
    """S10: entropy (bits), longest same-label run, switch rate."""
    p = distribution(y)
    nz = p[p > 0]
    longest, run = 1, 1
    for i in range(1, len(y)):
        run = run + 1 if y[i] == y[i - 1] else 1
        longest = max(longest, run)
    switches = int(np.sum(y[1:] != y[:-1])) if len(y) > 1 else 0
    return {"entropy_bits": r6(float(-(nz * np.log2(nz)).sum())), "longest_run": longest,
            "switch_rate": r6(switches / (len(y) - 1)) if len(y) > 1 else None}


def majority_label(y: np.ndarray) -> int:
    """argmax of label counts; ties break to the lowest canon index."""
    return int(np.argmax(np.bincount(y, minlength=N_CLASSES)))


# --- core --------------------------------------------------------------------

def arm_predictions(Xb: np.ndarray, y: np.ndarray, sp: Split, W0: np.ndarray, lam: float,
                    counter: SolveCounter | None = None,
                    ks: tuple[int, ...] = K_GRID) -> dict[str, dict[int, np.ndarray]]:
    """Test-tail predictions for every model arm at every available K."""
    test = Xb[sp.test_slice]
    out: dict[str, dict[int, np.ndarray]] = {"personalized": {}, "prior_only": {},
                                             "recency_last_k": {}}
    for k in ks:
        if not sp.available(k):
            continue
        first, last = sp.first_k(k), sp.last_k(k)
        Wp = fit_ridge_to_prior(Xb[first], y[first], W0, lam, counter)
        out["personalized"][k] = predict(test, Wp)
        out["prior_only"][k] = predict(test, fit_prior_only(Xb[first], y[first], W0, lam))
        Wr = Wp if (k == 0 or sp.last_k(k) == first) else \
            fit_ridge_to_prior(Xb[last], y[last], W0, lam, counter)
        out["recency_last_k"][k] = predict(test, Wr)
    return out


def discordance(pred_a: np.ndarray, pred_b: np.ndarray, gold: np.ndarray) -> dict[str, int]:
    """b = only B correct, c = only A correct, d = predictions differ (label-free)."""
    a_ok, b_ok = pred_a == gold, pred_b == gold
    return {"b": int(np.sum(b_ok & ~a_ok)), "c": int(np.sum(a_ok & ~b_ok)),
            "d": int(np.sum(pred_a != pred_b))}


def kkey(k: int) -> str:
    return f"k{k}"


def lambda_block(Xb: np.ndarray, y: np.ndarray, sp: Split, W0: np.ndarray,
                 lam: float) -> dict[str, Any]:
    """The quantities `combine` needs for Steps 1-5 at a given lambda."""
    gold = y[sp.test_slice]
    m = sp.m
    preds = arm_predictions(Xb, y, sp, W0, lam)
    gen = preds["personalized"][0]
    blk: dict[str, Any] = {"acc": {kkey(k): r6(correct_count(p, gold) / m)
                                   for k, p in preds["personalized"].items()},
                           "acc_prior_only": {kkey(k): r6(correct_count(p, gold) / m)
                                              for k, p in preds["prior_only"].items()}}
    for k in (K_BREADTH, K_PRIMARY):
        if k in preds["personalized"]:
            dis = discordance(preds["personalized"][k], gen, gold)
            blk[f"discordance_{kkey(k)}"] = dis
    if K_PRIMARY in preds["personalized"]:
        blk["discordance_vs_prior_only_k25"] = discordance(
            preds["personalized"][K_PRIMARY], preds["prior_only"][K_PRIMARY], gold)
    return blk


def primary_delta_on(Xb: np.ndarray, y: np.ndarray, W0: np.ndarray, sp: Split,
                     name: str) -> dict[str, Any]:
    """Delta-acc(K=25) on an alternative split or subset (E2 uncapped; voice-only)."""
    preds = arm_predictions(Xb, y, sp, W0, LAMBDA_ADAPT, ks=(0, K_PRIMARY))["personalized"]
    g = y[sp.test_slice]
    delta = (correct_count(preds[K_PRIMARY], g) - correct_count(preds[0], g)) / sp.m \
        if K_PRIMARY in preds else None
    return {f"{name}_test_size": sp.m, f"{name}_delta_primary": r6(delta)}


def environment() -> str:
    """F8-style stamp: software versions and OS family only (no host name, no user)."""
    import platform
    import sys

    parts = [f"python {sys.version.split()[0]}", f"numpy {np.__version__}"]
    for mod in ("torch", "sentence_transformers", "transformers"):
        try:
            parts.append(f"{mod} {__import__(mod).__version__}")
        except Exception:  # noqa: BLE001 - absent in tests that stub the embedder
            pass
    parts.append(f"{platform.system()} {platform.machine()}")
    return "; ".join(parts)


def null_arm(Xb: np.ndarray, y: np.ndarray, sp: Split, W0: np.ndarray, code: str,
             observed_net: int | None) -> dict[str, Any]:
    """Within-user label shuffles (embeddings untouched), section 7.5 / F3 / F4."""
    gold_idx = sp.test_slice
    test = Xb[gold_idx]
    gen_pred = predict(test, W0)
    out: dict[str, Any] = {}
    # j = 0: the full null K-curve (the single "rerun the identical pipeline").
    perm0 = np.random.default_rng(null_seed(code, 0)).permutation(len(y))
    y0 = y[perm0]
    curve = {}
    acc0 = correct_count(gen_pred, y0[gold_idx]) / sp.m
    for k in K_GRID:
        if sp.available(k):
            W = fit_ridge_to_prior(Xb[sp.first_k(k)], y0[sp.first_k(k)], W0, LAMBDA_ADAPT)
            curve[kkey(k)] = r6(correct_count(predict(test, W), y0[gold_idx]) / sp.m - acc0)
    out["delta_by_k"] = curve
    if not sp.available(K_PRIMARY):
        out["delta_primary"] = None
        return out
    out["delta_primary"] = curve[kkey(K_PRIMARY)]
    nets: list[int] = []
    for j in range(NULL_PERMUTATIONS):
        perm = np.random.default_rng(null_seed(code, j)).permutation(len(y))
        yj = y[perm]
        W = fit_ridge_to_prior(Xb[:K_PRIMARY], yj[:K_PRIMARY], W0, LAMBDA_ADAPT)
        gj = yj[gold_idx]
        nets.append(correct_count(predict(test, W), gj) - correct_count(gen_pred, gj))
    arr = np.asarray(nets)
    out["n_permutations"] = NULL_PERMUTATIONS
    out["net_primary"] = nets
    out["mean_delta_primary"] = r6(float(arr.mean()) / sp.m)
    out["win_rate_primary"] = r6(float(np.mean(arr > 0)))
    if observed_net is not None:
        out["p_user"] = r6((1 + int(np.sum(arr >= observed_net))) / (NULL_PERMUTATIONS + 1))
    return out


def donor_arms(Xb: np.ndarray, y: np.ndarray, sp: Split, W0: np.ndarray,
               donors: dict[str, Any], pers_by_lambda: dict[str, dict[int, np.ndarray]]
               ) -> dict[str, Any]:
    """Round 2: score the donor heads (built from OTHER people's weights) on this test tail."""
    test, gold = Xb[sp.test_slice], y[sp.test_slice]
    m = sp.m
    out: dict[str, Any] = {"donors_manifest_sha256": donors["manifest_sha256"],
                           "n_donors": donors["n_donors"], "pool_divisor": donors["pool_divisor"]}
    for lam in DONOR_LAMBDAS:
        lk = lam_key(lam)
        heads = {k: np.asarray(v, dtype=np.float64) for k, v in donors["heads"][lk].items()}
        pers = pers_by_lambda[lk]
        blk: dict[str, Any] = {"donor": {}, "donor_plus_prior": {}}
        dpp_pred: dict[int, np.ndarray] = {}
        for k in DONOR_KS:
            if not sp.available(k):
                blk["donor"][kkey(k)] = blk["donor_plus_prior"][kkey(k)] = None
                continue
            Wd = heads[f"donor_k{k}"]
            Wdp = fit_prior_only(Xb[:k], y[:k], Wd, lam)
            dpp_pred[k] = predict(test, Wdp)
            blk["donor"][kkey(k)] = r6(correct_count(predict(test, Wd), gold) / m)
            blk["donor_plus_prior"][kkey(k)] = r6(correct_count(dpp_pred[k], gold) / m)
        pooled_pred = predict(test, heads["pooled_lopo"])
        blk["pooled_lopo"] = r6(correct_count(pooled_pred, gold) / m)
        if K_PRIMARY in dpp_pred:
            dis = discordance(pers[K_PRIMARY], dpp_pred[K_PRIMARY], gold)
            blk["vs_donor_plus_prior_k25"] = dis
            blk["delta_vs_donor_plus_prior"] = r6((dis["c"] - dis["b"]) / m)
            pacc = correct_count(pers[K_PRIMARY], gold)
            blk["delta_vs_pooled_lopo"] = r6((pacc - correct_count(pooled_pred, gold)) / m)
            blk["pooled_lopo_ge_personalized"] = correct_count(pooled_pred, gold) >= pacc
        else:
            blk["vs_donor_plus_prior_k25"] = None
            blk["delta_vs_donor_plus_prior"] = None
            blk["delta_vs_pooled_lopo"] = None
            blk["pooled_lopo_ge_personalized"] = None
        out[lk] = blk
    return out


def analyze(doc: dict[str, Any], raw_bytes: bytes, W0: np.ndarray, head_sha256: str,
            embed: Callable[[list[str]], np.ndarray], donors: dict[str, Any] | None = None
            ) -> tuple[dict[str, Any], dict[str, Any] | None]:
    """Compute the full result for one validated export.

    Returns (result, weights). Round 1 (donors None): weights is this
    participant's head set for the donor step (None if under 30 entries).
    Round 2: the donor arms are scored and weights is None.
    """
    check_consent(doc)
    entries = doc["entries"]
    kept = [e for e in entries if e["text"].strip()]
    n = len(kept)
    y = np.asarray([LABEL_INDEX[e["self_label"]] for e in kept], dtype=np.int64)
    n_typed = sum(1 for e in kept if e["input"] == "typed")
    result: dict[str, Any] = {
        "schema": RESULT_SCHEMA,
        "tool_version": __version__,
        "protocol_hash": protocol_hash(),
        "embedding_model": embedding_model_string(),
        "generic_head_sha256": head_sha256,
        "participant_code": doc["participant_code"],
        "platform": doc["platform"],
        "app_version": doc["app_version"],
        "consent_version": doc["consent_version"],
        "input_sha256": hashlib.sha256(raw_bytes).hexdigest(),
        "synthetic": bool(doc.get("synthetic", False)),
        "n_entries_in_export": len(entries),
        "n_excluded_empty_text": len(entries) - n,
        "n_labelled": n,
        "n_voice": n - n_typed,
        "n_typed": n_typed,
        "label_counts": {lab: int(np.sum(y == i)) for i, lab in enumerate(CANON_LABELS)},
        "k_primary": K_PRIMARY,
        "round": 2 if donors is not None else 1,
        "donor_arms": None,
    }
    t = tier(n)
    result["in_n25"] = t == "primary"
    result["in_n10"] = t in ("primary", "breadth")
    result["status"] = "ok" if t == "primary" else "excluded_too_few"
    if t == "excluded":
        result["note"] = "fewer than 30 labelled entries: not analysed (prereg X4)"
        result["created_at"] = _now()
        return result, None

    sp = make_split(n)
    texts = [e["text"] for e in kept]
    X = embed(texts)
    if X.shape != (n, EMBEDDING_DIM):
        raise RuntimeError("embedding shape mismatch")
    Xb = add_bias(X)
    gold = y[sp.test_slice]
    m = sp.m
    counter = SolveCounter()
    preds = arm_predictions(Xb, y, sp, W0, LAMBDA_ADAPT, counter)
    pers = preds["personalized"]
    gen = pers[0]

    def acc_of(p: np.ndarray) -> float:
        return correct_count(p, gold) / m

    result.update({
        "test_size": m, "pool_size": sp.pool, "gap_primary": sp.gap_at_primary,
        "k_available": sp.k_available,
        "empirical_chance_threshold": r6(empirical_chance_threshold(m)),
    })
    acc = {"generic": r6(acc_of(gen))}
    for k in K_GRID:
        acc[kkey(k)] = r6(acc_of(pers[k])) if k in pers else None
    result["acc"] = acc
    result["arms"] = {arm: {kkey(k): (r6(acc_of(p[k])) if k in p else None) for k in K_GRID}
                      for arm, p in preds.items()}

    pool_y = y[:sp.pool]
    baselines: dict[str, float | None] = {}
    test_idx = np.arange(sp.pool, n)
    baselines["persistence_full"] = r6(float(np.mean(y[test_idx - 1] == gold)))
    baselines["persistence_frozen"] = r6(float(np.mean(gold == y[sp.pool - 1])))
    for k in K_GRID[1:]:
        baselines[f"majority_of_{kkey(k)}"] = (
            r6(float(np.mean(gold == majority_label(y[:k])))) if sp.available(k) else None)
    baselines["majority_of_pool"] = r6(float(np.mean(gold == majority_label(pool_y))))
    baselines["stratified_chance"] = r6(float(distribution(pool_y) @ distribution(gold)))
    result["baselines"] = baselines

    result["macro_f1"] = {kkey(k): (r6(macro_f1_present(pers[k], gold)) if k in pers else None)
                          for k in K_GRID}
    result["test_support"] = {lab: int(np.sum(gold == i)) for i, lab in enumerate(CANON_LABELS)}
    result["neutral_recall"] = {kkey(k): r6(neutral_recall(pers[k], gold)) for k in pers}
    result["collapse_rate"] = {kkey(k): r6(collapse_rate(pers[k])) for k in pers}
    result["prior_drift_tv"] = {kkey(k): r6(total_variation(y[:k], gold))
                                for k in K_GRID[1:] if sp.available(k)}
    result["labelling"] = {"pool": labelling_stats(pool_y), "test": labelling_stats(gold)}

    # Breadth (H4, K = 10) is available to every analysed participant.
    k10 = pers[K_BREADTH]
    dis10 = discordance(k10, gen, gold)
    result["breadth"] = {"delta": r6((dis10["c"] - dis10["b"]) / m),
                         "win": dis10["c"] > dis10["b"], **dis10}

    observed_net = None
    if sp.available(K_PRIMARY):
        p25, po25 = pers[K_PRIMARY], preds["prior_only"][K_PRIMARY]
        dis = discordance(p25, gen, gold)
        dis_po = discordance(p25, po25, gold)
        observed_net = dis["c"] - dis["b"]
        result["delta_primary"] = r6(observed_net / m)
        result["win_primary"] = observed_net > 0
        result["primary"] = {
            **dis,
            "delta_vs_prior_only": r6((dis_po["c"] - dis_po["b"]) / m),
            "b_vs_prior_only": dis_po["b"], "c_vs_prior_only": dis_po["c"],
            "win_vs_prior_only": dis_po["c"] > dis_po["b"],
            "compound_win": observed_net > 0 and dis_po["c"] > dis_po["b"],
            "persistence_full_beats_personalized":
                baselines["persistence_full"] > result["acc"][kkey(K_PRIMARY)],
        }
        result["sensitivity"] = {**primary_delta_on(Xb, y, W0, make_split(n, cap=None), "uncapped")}
        voice = np.asarray([e["input"] == "voice" for e in kept])
        if voice.sum() >= MIN_LABELLED_PRIMARY:
            result["sensitivity"].update(primary_delta_on(
                Xb[voice], y[voice], W0, make_split(int(voice.sum())), "voice_only"))
        else:
            result["sensitivity"].update({"voice_only_test_size": None,
                                          "voice_only_delta_primary": None})
    else:
        result["delta_primary"] = None
        result["win_primary"] = None
        result["primary"] = None

    variants = {}
    for lam in LAMBDA_SWEEP:
        if lam == LAMBDA_ADAPT:
            continue
        variants[f"lambda_{int(lam)}"] = lambda_block(Xb, y, sp, W0, lam)
    result["lambda_variants"] = variants
    d_by_lambda = {}
    for lam in LAMBDA_SWEEP:
        key = f"lambda_{int(lam)}"
        if lam == LAMBDA_ADAPT:
            d_by_lambda[key] = result["primary"]["d"] if result["primary"] else dis10["d"]
        else:
            blk = variants[key]
            d_by_lambda[key] = blk.get("discordance_k25", blk.get("discordance_k10"))["d"]
    result["disagreement_d"] = d_by_lambda

    result["null_arm"] = null_arm(Xb, y, sp, W0, doc["participant_code"], observed_net)
    result["solver"] = {"attempted": counter.attempted, "failed": counter.failed}
    result["environment"] = environment()
    weights = None
    if donors is not None:
        pers_by_lambda = {lam_key(LAMBDA_ADAPT): pers}
        for lam in DONOR_LAMBDAS:
            if lam != LAMBDA_ADAPT:
                pers_by_lambda[lam_key(lam)] = arm_predictions(
                    Xb, y, sp, W0, lam, ks=(K_PRIMARY,) if sp.available(K_PRIMARY) else ()
                )["personalized"]
        result["donor_arms"] = donor_arms(Xb, y, sp, W0, donors, pers_by_lambda)
    else:
        weights = build_weights(Xb, y, sp, W0, {
            "tool_version": __version__, "protocol_hash": result["protocol_hash"],
            "generic_head_sha256": head_sha256, "embedding_model": result["embedding_model"],
            "participant_code": result["participant_code"], "input_sha256": result["input_sha256"],
            "synthetic": result["synthetic"]})
    result["created_at"] = _now()
    return result, weights


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


class LeakError(RuntimeError):
    """The result would carry something from the export other than numbers."""


def assert_no_leak(result: dict[str, Any], doc: dict[str, Any], serialised: str,
                   kind: str = "result") -> None:
    """Refuse to write a result (or weights) file with free text, entry text, ids or timestamps."""
    bad = (find_free_text(result) if kind == "result"
           else find_free_text_generic(result, WEIGHTS_STRING_KEYS))
    if bad:
        raise LeakError(f"result has free-text fields: {bad[:5]}")
    for e in doc.get("entries", []):
        for field in ("id", "created_at"):
            v = e.get(field)
            if isinstance(v, str) and v and v in serialised:
                raise LeakError(f"an entry {field} appears in the result")
        text = e.get("text", "")
        if isinstance(text, str):
            # any 3-word window of the entry text would be a leak
            words = text.split()
            for i in range(max(0, len(words) - 2)):
                frag = " ".join(words[i:i + 3])
                if len(frag) >= 12 and frag in serialised:
                    raise LeakError("entry text appears in the result")
