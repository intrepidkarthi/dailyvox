"""Linear emotion heads: the generic ridge head and its two adaptations.

WHY ridge, and why "ridge-to-generic": the pre-registration (section 4.5)
fixes a one-vs-rest ridge over [embedding, 1] with one-hot 0/1 targets. The
personal head is the same model refitted on a participant's first K entries,
pulled towards the generic head instead of towards zero:

    W_user = argmin ||X W - Y||^2 + lambda ||W - W_generic||^2

which has the closed form (X'X + lambda I) W = X'Y + lambda W_generic. With no
rows the solution IS W_generic, so K = 0 equals the generic head exactly; the
code returns the generic array itself at K = 0 (no solve), and a test checks it.

Implementation note: with K <= 25 rows and 385 columns we use the equivalent
dual form W = W0 + X' (X X' + lambda I_K)^-1 (Y - X W0) (push-through
identity), which solves a K x K system instead of a 385 x 385 one. That is
what makes 1000 permutation-null refits per participant cheap.

The prior-only arm (section 7.2) frees only the bias row:
    b_c = [sum_r (y_rc - g_c . x_r) + lambda g_c[bias]] / (K + lambda)
so it can learn base rates and nothing else.
"""

from __future__ import annotations

import numpy as np

from .protocol import N_CLASSES


def add_bias(X: np.ndarray) -> np.ndarray:
    """Append the constant-1 bias column the heads are fitted over."""
    return np.hstack([X, np.ones((X.shape[0], 1), dtype=np.float64)])


def one_hot(y: np.ndarray, n_classes: int = N_CLASSES) -> np.ndarray:
    Y = np.zeros((len(y), n_classes), dtype=np.float64)
    Y[np.arange(len(y)), y] = 1.0
    return Y


def fit_ridge(Xb: np.ndarray, y: np.ndarray, lam: float) -> np.ndarray:
    """Plain one-vs-rest ridge (prior zero), used for the generic head. Shape (d+1, C)."""
    d = Xb.shape[1]
    gram = Xb.T @ Xb + lam * np.eye(d)
    return np.linalg.solve(gram, Xb.T @ one_hot(y))


class SolveCounter:
    """Counts failed solves (prereg F12): a failed refit falls back to the prior."""

    def __init__(self) -> None:
        self.attempted = 0
        self.failed = 0


def fit_ridge_to_prior(Xb: np.ndarray, y: np.ndarray, W0: np.ndarray, lam: float,
                       counter: SolveCounter | None = None) -> np.ndarray:
    """Ridge-to-generic refit. K = 0 returns W0 itself (bitwise identical)."""
    if Xb.shape[0] == 0:
        return W0
    if counter is not None:
        counter.attempted += 1
    R = one_hot(y, W0.shape[1]) - Xb @ W0
    G = Xb @ Xb.T + lam * np.eye(Xb.shape[0])
    try:
        A = np.linalg.solve(G, R)
    except np.linalg.LinAlgError:
        if counter is not None:
            counter.failed += 1
        return W0
    return W0 + Xb.T @ A


def fit_prior_only(Xb: np.ndarray, y: np.ndarray, W0: np.ndarray, lam: float) -> np.ndarray:
    """Bias-slot-only refit (R1 mechanism (i)). K = 0 returns W0 itself."""
    if Xb.shape[0] == 0:
        return W0
    k = Xb.shape[0]
    feature_scores = Xb[:, :-1] @ W0[:-1, :]          # g_c . x_r without bias
    num = (one_hot(y, W0.shape[1]) - feature_scores).sum(axis=0) + lam * W0[-1, :]
    W = W0.copy()
    W[-1, :] = num / (k + lam)
    return W


def predict(Xb: np.ndarray, W: np.ndarray) -> np.ndarray:
    """Argmax class; ties break to the lowest canon index (deterministic)."""
    return np.argmax(Xb @ W, axis=1)
