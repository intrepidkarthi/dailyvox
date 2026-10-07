"""End-to-end tests that need the embedding model (marked `model`)."""

import copy
import json
import shutil
from datetime import date

import numpy as np
import pytest

from dailyvox_study.analyze import LeakError, assert_no_leak
from dailyvox_study.cli import main
from dailyvox_study.combine import (
    CombineError, FreezeInterlock, analyse_cohort, check_cohort, check_freeze, load_results,
)
from dailyvox_study.pipeline import run_export
from dailyvox_study.report import render
from dailyvox_study.selfcheck import (
    NULL_DELTA_MIN, SHUFFLED_ACC_MAX, SHUFFLED_DELTA_MIN, collapsed,
)
from dailyvox_study.synth import make_persona_export, shuffle_labels

pytestmark = pytest.mark.model


def test_no_text_or_ids_leak(synthetic_cohort):
    for export, (_, result, text) in synthetic_cohort["results"].items():
        doc = json.loads(export.read_text("utf-8"))
        for e in doc["entries"]:
            assert e["id"] not in text
            assert e["created_at"] not in text
            assert e["text"] not in text
            words = e["text"].split()
            for i in range(len(words) - 2):
                frag = " ".join(words[i:i + 3])
                if len(frag) >= 12:
                    assert frag not in text
        assert doc["exported_at"] not in text
        assert "os_version" not in result and "device_model" not in result


def test_leak_guard_refuses(good_export):
    with pytest.raises(LeakError):
        assert_no_leak({"acc": {"k0": 0.5}}, good_export,
                       json.dumps({"x": good_export["entries"][0]["text"]}))
    with pytest.raises(LeakError):
        assert_no_leak({"note2": {"t": "hello"}}, good_export, "{}")


def test_k0_equals_generic_in_results(synthetic_cohort):
    for _, (_, r, _) in synthetic_cohort["results"].items():
        if r["status"] == "ok" or r.get("in_n10"):
            assert r["acc"]["k0"] == r["acc"]["generic"]
            assert r["arms"]["prior_only"]["k0"] == r["acc"]["generic"]


def test_deterministic_rerun(synthetic_cohort):
    export = synthetic_cohort["exports"][0]
    first = dict(synthetic_cohort["results"][export][1])
    _, again, _ = run_export(export, head=synthetic_cohort["head"])
    second = json.loads(again)
    first.pop("created_at"), second.pop("created_at")
    assert json.dumps(first, sort_keys=True) == json.dumps(second, sort_keys=True)


def test_duplicate_refusal(synthetic_cohort, tmp_path):
    d = tmp_path / "res"
    shutil.copytree(synthetic_cohort["results_dir"], d)
    src = sorted(d.glob("*.json"))[0]
    shutil.copy(src, d / "copy-of-first.json")
    with pytest.raises(CombineError) as exc:
        check_cohort(load_results(sorted(d.glob("*.json"))))
    assert "duplicate participant_code" in str(exc.value)
    assert "copy-of-first.json" in str(exc.value)
    assert main(["combine", str(d), "-o", str(tmp_path / "r.md")]) == 4


def test_duplicate_input_sha_with_different_code(synthetic_cohort, tmp_path):
    d = tmp_path / "res"
    shutil.copytree(synthetic_cohort["results_dir"], d)
    src = sorted(d.glob("*.json"))[0]
    doc = json.loads(src.read_text("utf-8"))
    doc["participant_code"] = "DV-ZZZZ-ZZ"
    (d / "renamed.json").write_text(json.dumps(doc), "utf-8")
    with pytest.raises(CombineError) as exc:
        check_cohort(load_results(sorted(d.glob("*.json"))))
    assert "duplicate input_sha256" in str(exc.value)


def test_mixed_protocol_refused(synthetic_cohort, tmp_path):
    d = tmp_path / "res"
    shutil.copytree(synthetic_cohort["results_dir"], d)
    f = sorted(d.glob("*.json"))[1]
    doc = json.loads(f.read_text("utf-8"))
    doc["protocol_hash"] = "0" * 64
    doc["tool_version"] = "0.2.0"
    f.write_text(json.dumps(doc), "utf-8")
    with pytest.raises(CombineError) as exc:
        check_cohort(load_results(sorted(d.glob("*.json"))))
    assert "mixed protocol_hash" in str(exc.value) and "mixed tool_version" in str(exc.value)


def test_freeze_interlock_for_real_results(synthetic_cohort):
    loaded = load_results(sorted(synthetic_cohort["results_dir"].glob("*.json")))
    real = [(p, dict(d, synthetic=False)) for p, d in loaded]
    with pytest.raises(FreezeInterlock):
        check_freeze(real, None)
    with pytest.raises(FreezeInterlock):
        check_freeze(real, "2099-01-01", today=date(2026, 10, 7))
    check_freeze(real, "2026-10-01", today=date(2026, 10, 7))


def test_combine_report_and_null_collapse(synthetic_cohort):
    loaded = load_results(sorted(synthetic_cohort["results_dir"].glob("*.json")))
    check_cohort(loaded)
    rep = analyse_cohort([d for _, d in loaded])
    md = render(rep)
    assert "Registered outcome sentence" in md and "SYNTHETIC DATA" in md
    assert rep["cohort"]["N25"] == 8 and rep["cohort"]["N10"] == 9
    assert "ios" in rep["platforms"] and "android" in rep["platforms"]
    nl = rep["null"]
    assert collapsed(nl["mean_null_delta_primary_over_permutations"], NULL_DELTA_MIN)
    assert nl["null_win_rate_mean"] < 0.5
    # the synthetic personas carry personal signal, so the real arm should lift
    assert rep["steps"]["step1"]["mean_delta"] > 0


def test_shuffled_labels_collapse(synthetic_cohort, tmp_path):
    deltas, accs = [], []
    for i, export in enumerate(synthetic_cohort["exports"]):
        doc = shuffle_labels(json.loads(export.read_text("utf-8")), 500 + i)
        p = tmp_path / f"s{i}.json"
        p.write_text(json.dumps(doc), "utf-8")
        r, _, _ = run_export(p, head=synthetic_cohort["head"])
        if r["status"] == "ok":
            deltas.append(r["delta_primary"])
            accs.append(r["acc"]["k25"])
    assert collapsed(float(np.mean(deltas)), SHUFFLED_DELTA_MIN)
    assert float(np.mean(accs)) <= SHUFFLED_ACC_MAX


def test_excluded_participant_has_no_metrics(tmp_path, synthetic_cohort):
    doc = make_persona_export(3, 20)
    p = tmp_path / "few.json"
    p.write_text(json.dumps(doc), "utf-8")
    r, text, _ = run_export(p, head=synthetic_cohort["head"])
    assert r["status"] == "excluded_too_few" and "acc" not in r and not r["in_n10"]


def test_empty_text_entries_excluded_before_split(tmp_path, synthetic_cohort):
    doc = make_persona_export(1, 40)
    doc = copy.deepcopy(doc)
    doc["entries"][0]["text"] = "   "
    p = tmp_path / "blank.json"
    p.write_text(json.dumps(doc), "utf-8")
    r, _, _ = run_export(p, head=synthetic_cohort["head"])
    assert r["n_excluded_empty_text"] == 1 and r["n_labelled"] == 39


def test_cli_run_consent_mismatch(tmp_path):
    doc = make_persona_export(2, 40)
    doc["consent_version"] = "2.1"
    p = tmp_path / "old.json"
    p.write_text(json.dumps(doc), "utf-8")
    assert main(["run", str(p), "-o", str(tmp_path / "r.json")]) == 3
    assert not (tmp_path / "r.json").exists()
