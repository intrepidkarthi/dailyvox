import math

import pytest

from dailyvox_study.stats import (
    binom_sf, clopper_pearson_upper, critical_wins, empirical_chance_threshold, fisher_combine,
    mcnemar_one_sided, one_sided_intervals, sign_flip_test,
)


@pytest.mark.parametrize("deltas,expected", [
    ([1, 2, 3], 1 / 8),            # only the all-plus pattern reaches 6
    ([1, -1], 3 / 4),              # sums {2, 0, 0, -2} >= 0
    ([3, -1, 2], 2 / 8),           # observed 4: patterns giving 4 and 6
    ([0.1, 0.0, 0.2], 2 / 8),      # a tie cannot move: floor is 2^-(N_eff) = 1/4
    ([-1, -2], 1.0),               # observed is the minimum
    ([1 / 35, 2 / 35, -1 / 10], 5 / 8),  # mixed test sizes: obs = -1/70; 5 of 8 sums >= obs
])
def test_sign_flip_exact_hand_cases(deltas, expected):
    r = sign_flip_test(deltas)
    assert math.isclose(r["p"], expected)
    assert r["method"].startswith("exact")


def test_sign_flip_floor_and_neff():
    r = sign_flip_test([0.1, 0.2, 0.0, 0.0, 0.3])
    assert r["n_eff"] == 3 and math.isclose(r["p_floor"], 1 / 8) and math.isclose(r["p"], 1 / 8)


def test_sign_flip_monte_carlo_when_large():
    r = sign_flip_test([0.05] * 25)
    assert "Monte Carlo" in r["method"]
    assert r["p"] < 0.001


def test_critical_values_match_prereg_table():
    # prereg section 6.2: N -> k*
    table = {5: 5, 6: 6, 7: 7, 8: 7, 9: 8, 10: 9, 11: 9, 12: 10, 13: 10, 14: 11, 15: 12}
    for n, k in table.items():
        assert critical_wins(n) == k, n
    assert critical_wins(3) is None and critical_wins(4) is None
    assert math.isclose(binom_sf(7, 8, 0.5), 0.03515625)


def test_inferiority_trigger_table():
    # prereg section 6.3: clause (a) fires at <=1/5, <=1/6, <=2/7, <=2/8, <=4/10, <=5/13, <=6/15
    for wins, n in [(1, 5), (1, 6), (2, 7), (2, 8), (4, 10), (5, 13), (6, 15)]:
        assert clopper_pearson_upper(wins, n) < 0.70
        assert clopper_pearson_upper(wins + 1, n) >= 0.70


def test_empirical_chance_thresholds():
    # prereg section 7.6: m=10 -> 40.0%, m=20 -> 35.0%, m=35 -> 28.6%
    assert math.isclose(empirical_chance_threshold(10), 0.40)
    assert math.isclose(empirical_chance_threshold(20), 0.35)
    assert math.isclose(round(empirical_chance_threshold(35), 3), 0.286)


def test_mcnemar_and_fisher():
    assert mcnemar_one_sided(0, 0) is None
    assert math.isclose(mcnemar_one_sided(0, 5), 1 / 32)
    assert math.isclose(mcnemar_one_sided(1, 1), 0.75)
    # prereg section 6.2: three users each at p = 0.05 combine to p ~ 0.006
    assert 0.005 < fisher_combine([0.05, 0.05, 0.05]) < 0.007
    assert math.isclose(fisher_combine([1.0]), 1.0)


def test_intervals_shape():
    iv = one_sided_intervals([0.1, 0.05, 0.08, 0.12, -0.02], 0.90, 2000)
    assert iv["percentile_lower"] < iv["mean"]
