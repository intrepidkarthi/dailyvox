"""Exact and resampling statistics used by the per-participant and cohort analyses.

WHY no SciPy: every test the pre-registration names reduces to binomial tails,
sign-flip enumeration, a chi-square survival function with even degrees of
freedom (closed form), and bootstrap percentiles. Implementing them directly
keeps the dependency list short and, more importantly, keeps each formula
readable next to the prereg section it implements.
"""

from __future__ import annotations

import math
from typing import Sequence

import numpy as np

from .protocol import ALPHA, EXACT_ENUMERATION_MAX_N, MONTE_CARLO_DRAWS, SEED


# --- Binomial ---------------------------------------------------------------

def binom_pmf(k: int, n: int, p: float) -> float:
    if k < 0 or k > n:
        return 0.0
    return math.comb(n, k) * (p ** k) * ((1.0 - p) ** (n - k))


def binom_sf(k: int, n: int, p: float) -> float:
    """P(X >= k) for X ~ Binomial(n, p)."""
    if k <= 0:
        return 1.0
    return min(1.0, sum(binom_pmf(i, n, p) for i in range(k, n + 1)))


def binom_cdf(k: int, n: int, p: float) -> float:
    """P(X <= k)."""
    if k < 0:
        return 0.0
    return min(1.0, sum(binom_pmf(i, n, p) for i in range(0, min(k, n) + 1)))


def critical_wins(n: int, alpha: float = ALPHA) -> int | None:
    """k*(N): smallest k with P(X >= k | N, 0.5) <= alpha (prereg section 6.2)."""
    for k in range(0, n + 1):
        if binom_sf(k, n, 0.5) <= alpha + 1e-15:
            return k
    return None


def empirical_chance_threshold(m: int, n_classes: int = 7, alpha: float = ALPHA) -> float:
    """Binomial inverse-survival accuracy threshold for a test set of m (section 7.6)."""
    k = critical_wins_p(m, 1.0 / n_classes, alpha)
    return k / m


def critical_wins_p(n: int, p: float, alpha: float) -> int:
    for k in range(0, n + 1):
        if binom_sf(k, n, p) <= alpha + 1e-15:
            return k
    return n + 1


def clopper_pearson_upper(wins: int, n: int, level: float = 0.95) -> float:
    """One-sided upper bound p_U with P(X <= wins | n, p_U) = 1 - level."""
    if wins >= n:
        return 1.0
    lo, hi = wins / n, 1.0
    for _ in range(200):
        mid = (lo + hi) / 2
        if binom_cdf(wins, n, mid) > 1.0 - level:
            lo = mid
        else:
            hi = mid
    return hi


def mcnemar_one_sided(b: int, c: int) -> float | None:
    """Exact one-sided McNemar: P(Binom(b + c, 0.5) >= c). None when b = c = 0."""
    if b + c == 0:
        return None
    return binom_sf(c, b + c, 0.5)


def fisher_combine(pvalues: Sequence[float]) -> float:
    """Fisher's method. Chi-square(2k) survival has a closed form for even df."""
    k = len(pvalues)
    if k == 0:
        return float("nan")
    x = -2.0 * sum(math.log(max(p, 1e-300)) for p in pvalues)
    half = x / 2.0
    term, total = 1.0, 1.0
    for i in range(1, k):
        term *= half / i
        total += term
    return min(1.0, math.exp(-half) * total)


# --- Sign-flip permutation ---------------------------------------------------

def sign_flip_test(deltas: Sequence[float], seed: int = SEED,
                   max_exact_n: int = EXACT_ENUMERATION_MAX_N,
                   draws: int = MONTE_CARLO_DRAWS) -> dict:
    """One-sided sign-flip permutation test of sum(delta) > 0 (prereg section 6.1).

    p = #{sign patterns s : sum(s * delta) >= observed} / 2^N, enumerated
    exhaustively when N <= max_exact_n (2^20 ~ 1e6 patterns); otherwise a
    seeded Monte Carlo with p = (1 + #) / (draws + 1), and the method says so.
    Ties (delta == 0) are kept: they cannot move under a flip, which is exactly
    why the attainable minimum p is 2^-(N_eff).
    """
    d = np.asarray(deltas, dtype=np.float64)
    n = len(d)
    n_eff = int(np.sum(d != 0))
    if n == 0:
        return {"n": 0, "n_eff": 0, "p": float("nan"), "method": "none", "p_floor": float("nan")}
    observed = float(d.sum())
    tol = 1e-9
    if n <= max_exact_n:
        count = 0
        # enumerate in chunks to bound memory: rows = sign patterns
        chunk = 1 << min(n, 16)
        total = 1 << n
        for start in range(0, total, chunk):
            idx = np.arange(start, min(start + chunk, total), dtype=np.int64)
            bits = ((idx[:, None] >> np.arange(n)) & 1).astype(np.float64)
            sums = (1.0 - 2.0 * bits) @ d
            count += int(np.sum(sums >= observed - tol))
        p = count / total
        method = f"exact enumeration of all 2^{n} = {total} sign patterns"
    else:
        rng = np.random.default_rng(seed)
        count = 0
        remaining = draws
        while remaining > 0:
            b = min(remaining, 20_000)
            signs = rng.choice((-1.0, 1.0), size=(b, n))
            count += int(np.sum(signs @ d >= observed - tol))
            remaining -= b
        p = (1 + count) / (draws + 1)
        method = f"seeded Monte Carlo ({draws} draws, seed {seed}); 2^{n} too many to enumerate"
    return {"n": n, "n_eff": n_eff, "observed_sum": observed, "p": p, "method": method,
            "p_floor": 2.0 ** (-n_eff) if n_eff > 0 else 1.0}


# --- Bootstrap ----------------------------------------------------------------

def bootstrap_means(x: Sequence[float], draws: int, seed: int = SEED) -> np.ndarray:
    a = np.asarray(x, dtype=np.float64)
    rng = np.random.default_rng(seed)
    idx = rng.integers(0, len(a), size=(draws, len(a)))
    return a[idx].mean(axis=1)


def bootstrap_upper(x: Sequence[float], level: float, draws: int, seed: int = SEED) -> float:
    """One-sided upper percentile bound on the mean."""
    if len(x) == 0:
        return float("nan")
    return float(np.quantile(bootstrap_means(x, draws, seed), level))


def _norm_cdf(z: float) -> float:
    return 0.5 * (1.0 + math.erf(z / math.sqrt(2.0)))


def _norm_ppf(q: float) -> float:
    lo, hi = -10.0, 10.0
    for _ in range(200):
        mid = (lo + hi) / 2
        if _norm_cdf(mid) < q:
            lo = mid
        else:
            hi = mid
    return (lo + hi) / 2


def one_sided_intervals(x: Sequence[float], level: float, draws: int,
                        seed: int = SEED) -> dict:
    """One-sided lower bounds on the mean: plain percentile AND BCa (prereg S9).

    BCa acceleration comes from the jackknife, which is noisy at N <= 15, so the
    prereg requires both to be printed.
    """
    a = np.asarray(x, dtype=np.float64)
    n = len(a)
    if n < 2:
        return {"mean": float(a.mean()) if n else float("nan"),
                "percentile_lower": float("nan"), "bca_lower": float("nan")}
    boots = bootstrap_means(a, draws, seed)
    q = 1.0 - level
    pct = float(np.quantile(boots, q))
    mean = float(a.mean())
    prop = float(np.mean(boots < mean))
    if prop <= 0.0 or prop >= 1.0 or np.all(a == a[0]):
        bca = pct
    else:
        z0 = _norm_ppf(prop)
        jack = np.array([np.delete(a, i).mean() for i in range(n)])
        jm = jack.mean()
        num = float(np.sum((jm - jack) ** 3))
        den = float(6.0 * (np.sum((jm - jack) ** 2) ** 1.5))
        acc = num / den if den > 0 else 0.0
        zq = _norm_ppf(q)
        adj = _norm_cdf(z0 + (z0 + zq) / (1 - acc * (z0 + zq)))
        bca = float(np.quantile(boots, min(max(adj, 0.0), 1.0)))
    return {"mean": mean, "percentile_lower": pct, "bca_lower": bca}
