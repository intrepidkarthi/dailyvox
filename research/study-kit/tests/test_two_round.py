"""Two-round donor arms: weights -> donors -> round 2 -> H3b (marked `model`)."""

import json
import shutil

import numpy as np
import pytest

from dailyvox_study.cli import main
from dailyvox_study.combine import analyse_cohort, load_results
from dailyvox_study.pipeline import run_export_full
from dailyvox_study.schema import validate_result
from dailyvox_study.selfcheck import TWO_ROUND_COUNTS
from dailyvox_study.synth import write_synthetic
from dailyvox_study.tworound import run_two_round
from dailyvox_study.weights import DonorError, build_donors, load_weights

pytestmark = pytest.mark.model


@pytest.fixture(scope="session")
def cohorts(tmp_path_factory, synthetic_cohort):
    head = synthetic_cohort["head"]
    out = {}
    for name, shared in (("personal", False), ("register", True)):
        base = tmp_path_factory.mktemp(name)
        exports = write_synthetic(base / "exports", 10, counts=TWO_ROUND_COUNTS,
                                  shared_mapping=shared)
        out[name] = {**run_two_round(exports, head, base), "exports": exports, "head": head}
    return out


def test_h3b_distinguishes_personal_from_register_signal(cohorts):
    p4 = cohorts["personal"]["report"]["steps"]["step4"]
    r4 = cohorts["register"]["report"]["steps"]["step4"]
    assert p4["runnable"] and r4["runnable"]
    assert p4["verdict"] == "retained" and p4["mean_delta"] > 0.03
    assert r4["verdict"] != "retained" and abs(r4["mean_delta"]) < p4["mean_delta"]
    assert cohorts["personal"]["report"]["claim"]["row"] == "1"


def test_weights_files_carry_no_text_or_ids(cohorts):
    c = cohorts["personal"]
    for export in c["exports"]:
        doc = json.loads(export.read_text("utf-8"))
        wpath = c["dirs"]["weights"] / f"weights-{doc['participant_code']}.json"
        text = wpath.read_text("utf-8")
        for e in doc["entries"]:
            assert e["id"] not in text and e["created_at"] not in text
            assert e["text"][:30] not in text
        w = json.loads(text)
        assert w["shape"] == [385, 7]
        assert set(w["heads"]) == {"lambda_10", "lambda_1"}


def test_donor_head_is_mean_of_others_and_never_one_person(cohorts):
    c = cohorts["personal"]
    weights = {json.loads(p.read_text())["participant_code"]: json.loads(p.read_text())
               for p in c["dirs"]["weights"].glob("*.json")}
    code = sorted(weights)[0]
    donors = json.loads((c["dirs"]["donors"] / f"donors-{code}.json").read_text())
    others = [w for k, w in weights.items() if k != code]
    expected = np.mean([np.asarray(w["heads"]["lambda_10"]["k25"]) for w in others], axis=0)
    got = np.asarray(donors["heads"]["lambda_10"]["donor_k25"])
    assert np.allclose(got, expected, rtol=1e-7, atol=1e-9)
    assert donors["n_donors"] == len(others) >= 2
    assert donors["pool_divisor"] == 8          # 9 others -> closest power of two


def test_donors_refusals(cohorts, tmp_path):
    wdir = cohorts["personal"]["dirs"]["weights"]
    files = sorted(wdir.glob("*.json"))
    with pytest.raises(DonorError, match="at least 3"):
        build_donors(load_weights(files[:2]))
    bad = tmp_path / "w"
    bad.mkdir()
    for f in files[:4]:
        shutil.copy(f, bad / f.name)
    doc = json.loads(files[0].read_text())
    doc["protocol_hash"] = "0" * 64
    (bad / files[0].name).write_text(json.dumps(doc))
    with pytest.raises(DonorError, match="mixed protocol_hash"):
        build_donors(load_weights([bad]))
    assert main(["donors", str(bad), "-o", str(tmp_path / "d")]) == 4
    # P0 is excluded from every pool: 3 files with one P0 leaves 2 -> refused
    codes = [json.loads(f.read_text())["participant_code"] for f in files[:3]]
    with pytest.raises(DonorError):
        build_donors(load_weights(files[:3]), {codes[0]})


def test_round2_refuses_other_export_or_other_person(cohorts, tmp_path):
    c = cohorts["personal"]
    e0, e1 = c["exports"][0], c["exports"][1]
    code0 = json.loads(e0.read_text())["participant_code"]
    donors0 = c["dirs"]["donors"] / f"donors-{code0}.json"
    with pytest.raises(DonorError, match="is for"):
        run_export_full(e1, head=c["head"], donors_path=donors0)
    changed = tmp_path / "changed.json"
    doc = json.loads(e0.read_text())
    doc["entries"][-1]["text"] += " edited"
    changed.write_text(json.dumps(doc))
    with pytest.raises(DonorError, match="not the file used in round 1"):
        run_export_full(changed, head=c["head"], donors_path=donors0)
    assert main(["run", str(changed), "--donors", str(donors0), "-o", str(tmp_path / "r.json")]) == 5


def test_round1_only_combine_says_why(synthetic_cohort):
    loaded = load_results(sorted(synthetic_cohort["results_dir"].glob("*.json")))
    rep = analyse_cohort([d for _, d in loaded])
    assert not rep["steps"]["step4"]["runnable"]
    assert "only round-1" in rep["steps"]["step4"]["reason"]
    assert rep["claim"]["row"] == "3"


def test_mixed_round_results_say_which_are_missing(cohorts):
    c = cohorts["personal"]
    r2 = [d for _, d in load_results(sorted(c["dirs"]["round2"].glob("*.json")))]
    r1 = [d for _, d in load_results(sorted(c["dirs"]["round1"].glob("*.json")))]
    mixed = r2[:-1] + [r1[-1]]
    rep = analyse_cohort(mixed)
    assert not rep["steps"]["step4"]["runnable"]
    assert r1[-1]["participant_code"] in rep["steps"]["step4"]["reason"]


def test_result_v1_still_readable(cohorts):
    c = cohorts["personal"]
    doc = json.loads(sorted(c["dirs"]["round1"].glob("*.json"))[0].read_text())
    doc["schema"] = "dailyvox-study-result/1"
    doc.pop("round"), doc.pop("donor_arms")
    validate_result(doc)
