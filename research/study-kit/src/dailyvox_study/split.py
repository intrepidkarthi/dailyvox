"""The S3 chronological split (prereg section 4.2, Amendment A1).

WHY this rule: once the primary K is fixed at 25, every labelled entry after
the first 25 can be test material, so the test set gets all of it, capped at
35 to bound drift exposure. At the 60-entry recruitment target that gives a
35-entry test set (2.9-point accuracy quantum) instead of the 12 entries the
earlier 20% rule produced, which is what made the gate passable at all.

The test set is the LAST m entries and is byte-identical for every K and every
arm within a participant. Adaptation sets are slices of the pool (the first
n - m entries). A K larger than the pool is reported unavailable, never
extrapolated.
"""

from __future__ import annotations

from dataclasses import dataclass

from .protocol import (
    K_GRID, K_PRIMARY, MIN_LABELLED_ANY, MIN_LABELLED_PRIMARY, TEST_CAP, TEST_FLOOR,
)


def test_size(n: int, cap: int | None = TEST_CAP) -> int:
    """m(n) = min(35, max(10, n - 25)). cap=None gives the E2 uncapped variant."""
    m = max(TEST_FLOOR, n - K_PRIMARY)
    return m if cap is None else min(cap, m)


@dataclass(frozen=True)
class Split:
    n: int
    m: int          # test size
    pool: int       # adaptation pool size = n - m

    @property
    def test_slice(self) -> slice:
        return slice(self.pool, self.n)

    def available(self, k: int) -> bool:
        return k <= self.pool

    @property
    def k_available(self) -> list[int]:
        return [k for k in K_GRID if self.available(k)]

    @property
    def gap_at_primary(self) -> int | None:
        """Entries between the end of the K=25 window and the test tail (X15)."""
        return self.pool - K_PRIMARY if self.available(K_PRIMARY) else None

    def first_k(self, k: int) -> slice:
        return slice(0, k)

    def last_k(self, k: int) -> slice:
        """Recency-matched arm (section 7.7): the K entries just before the test tail."""
        return slice(self.pool - k, self.pool)


def make_split(n: int, cap: int | None = TEST_CAP) -> Split:
    m = test_size(n, cap)
    return Split(n=n, m=m, pool=n - m)


def tier(n: int) -> str:
    """Eligibility tier: 'primary' (in N25), 'breadth' (N10 only) or 'excluded'."""
    if n >= MIN_LABELLED_PRIMARY:
        return "primary"
    if n >= MIN_LABELLED_ANY:
        return "breadth"
    return "excluded"
