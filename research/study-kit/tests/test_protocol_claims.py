import json
from importlib import resources

from dailyvox_study.claims import ClaimInput, select_claim
from dailyvox_study.generic import PINNED_GENERIC_HEAD_SHA256, packaged_head
from dailyvox_study.protocol import frozen_constants, protocol_hash


def test_protocol_hash_is_stable_and_covers_constants():
    h = protocol_hash()
    assert len(h) == 64 and h == protocol_hash()
    c = frozen_constants()
    assert c["k_grid"] == [0, 5, 10, 25] and c["lambda_adapt"] == 10.0 and c["seed"] == 42
    assert c["embedding"]["revision"] and c["generic_data"]["commit"]


def test_packaged_head_matches_protocol_and_pin():
    """Editing a frozen constant without rebuilding and re-pinning the head fails here."""
    doc = json.loads(resources.files("dailyvox_study.data").joinpath("generic_head_v1.json")
                     .read_text("utf-8"))
    assert doc["protocol_hash"] == protocol_hash()
    head = packaged_head()
    assert head is not None and head.sha256 == PINNED_GENERIC_HEAD_SHA256
    assert head.W.shape == (385, 7)


def base(**kw):
    d = dict(n25=8, neff=8, ties=0, low_d_branch=False, s1_reject=True, s1b_reject=True,
             s2_pass=True, s3_reject=True, s4_runnable=False, inferiority_met=False, p1=0.01,
             p1b=0.01, sub_chance=False, sub_chance_points=None, persistence_majority=False,
             d_zero_majority=False, active_lambda=10.0, h3_vs_compound_disagree=False,
             strata_given=False, stranger_won=None, recency_wins=False)
    d.update(kw)
    return ClaimInput(**d)


def test_claim_rows_precedence():
    assert select_claim(base(n25=4, neff=2)).row == "10"
    assert select_claim(base(neff=4, ties=4)).row == "9"
    assert select_claim(base()).row == "3"          # Step 4 unrunnable -> row 3
    assert select_claim(base(s3_reject=False)).row == "4"
    assert select_claim(base(s2_pass=False)).row == "5"
    assert select_claim(base(s1b_reject=False)).row == "4b"
    assert select_claim(base(s1_reject=False, n25=6, neff=6)).row == "6"
    assert select_claim(base(s1_reject=False)).row == "7"
    assert select_claim(base(s1_reject=False, inferiority_met=True)).row == "8"


def test_claim_qualifiers():
    c = select_claim(base(persistence_majority=True, strata_given=True, stranger_won=False,
                          sub_chance=True, sub_chance_points=3.0))
    text = " ".join(c.qualifiers)
    assert "Row 15" in text and "Row 14" in text and "Row 13" in text
    assert c.headline.startswith("The generic head does not clear chance")
