import numpy as np
import pytest

from dailyvox_study.heads import add_bias, fit_prior_only, fit_ridge_to_prior, one_hot, predict
from dailyvox_study.split import make_split, tier


@pytest.mark.parametrize("n,m,pool,ks,gap", [
    (35, 10, 25, [0, 5, 10, 25], 0),
    (60, 35, 25, [0, 5, 10, 25], 0),
    (100, 35, 65, [0, 5, 10, 25], 40),
    (30, 10, 20, [0, 5, 10], None),
    (40, 15, 25, [0, 5, 10, 25], 0),
    (70, 35, 35, [0, 5, 10, 25], 10),
])
def test_split_arithmetic(n, m, pool, ks, gap):
    sp = make_split(n)
    assert (sp.m, sp.pool, sp.k_available, sp.gap_at_primary) == (m, pool, ks, gap)
    assert sp.test_slice == slice(pool, n)


def test_uncapped_split_e2():
    assert make_split(100, cap=None).m == 75
    assert make_split(60, cap=None).m == 35


def test_recency_slice():
    sp = make_split(70)
    assert sp.last_k(10) == slice(25, 35)
    assert sp.first_k(10) == slice(0, 10)


def test_tiers():
    assert tier(29) == "excluded" and tier(30) == "breadth" and tier(34) == "breadth"
    assert tier(35) == "primary"


@pytest.fixture
def toy():
    rng = np.random.default_rng(0)
    X = rng.normal(size=(25, 6))
    X /= np.linalg.norm(X, axis=1, keepdims=True)
    y = rng.integers(0, 7, size=25)
    W0 = rng.normal(size=(7, 7))
    return add_bias(X), y, W0


def test_k0_is_generic_exactly(toy):
    Xb, y, W0 = toy
    W = fit_ridge_to_prior(Xb[:0], y[:0], W0, 10.0)
    assert W is W0
    assert np.array_equal(predict(Xb, W), predict(Xb, W0))
    assert fit_prior_only(Xb[:0], y[:0], W0, 10.0) is W0


def test_dual_form_equals_primal(toy):
    Xb, y, W0 = toy
    lam = 10.0
    W = fit_ridge_to_prior(Xb, y, W0, lam)
    d = Xb.shape[1]
    primal = np.linalg.solve(Xb.T @ Xb + lam * np.eye(d), Xb.T @ one_hot(y) + lam * W0)
    assert np.allclose(W, primal, atol=1e-10)


def test_prior_only_changes_only_bias(toy):
    Xb, y, W0 = toy
    W = fit_prior_only(Xb, y, W0, 10.0)
    assert np.array_equal(W[:-1], W0[:-1])
    assert not np.array_equal(W[-1], W0[-1])


def test_prior_only_matches_restricted_ridge(toy):
    """Closed form equals a brute-force 1-D minimiser of the bias-only objective."""
    Xb, y, W0 = toy
    lam = 10.0
    W = fit_prior_only(Xb, y, W0, lam)
    Y = one_hot(y)
    for c in range(7):
        base = Xb[:, :-1] @ W0[:-1, c]
        grid = np.linspace(W[-1, c] - 1, W[-1, c] + 1, 200001)
        loss = ((base[None, :] + grid[:, None] - Y[:, c][None, :]) ** 2).sum(1) \
            + lam * (grid - W0[-1, c]) ** 2
        assert abs(grid[np.argmin(loss)] - W[-1, c]) < 1e-4
