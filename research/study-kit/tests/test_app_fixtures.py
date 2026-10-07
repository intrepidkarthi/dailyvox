"""The tool must accept exactly what the two apps write (branch research/export-v1)."""

import importlib.util
import json
from pathlib import Path

import pytest

from dailyvox_study.cli import main
from dailyvox_study.pipeline import read_export
from dailyvox_study.schema import validate_export

FIX = Path(__file__).parent / "fixtures"


def _generator():
    spec = importlib.util.spec_from_file_location("make_app_fixtures", FIX / "make_app_fixtures.py")
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


@pytest.mark.parametrize("name", ["ios-export-v1.json", "android-export-v1.json",
                                  "android-export-v1-empty.json"])
def test_committed_fixture_matches_generator(name):
    assert (FIX / name).read_text("utf-8") == _generator().FIXTURES[name]()


@pytest.mark.parametrize("name", ["ios-export-v1.json", "android-export-v1.json",
                                  "android-export-v1-empty.json"])
def test_fixture_validates_without_warnings(name):
    doc, _, warnings = read_export(FIX / name)
    assert warnings == []
    assert doc["platform"] in ("ios", "android")


def test_ios_shape_details():
    raw = (FIX / "ios-export-v1.json").read_text("utf-8")
    doc = json.loads(raw)
    assert '"app_version" : "1.12.0"' in raw                       # Apple's " : " separator
    assert list(doc) == sorted(doc)                                 # sorted keys
    assert all(e["id"] == e["id"].upper() for e in doc["entries"])
    assert "http://x.y/z" in raw                                    # slashes not escaped


def test_android_shape_details():
    raw = (FIX / "android-export-v1.json").read_text("utf-8")
    doc = json.loads(raw)
    assert list(doc)[:3] == ["schema", "consent_version", "participant_code"]   # contract order
    assert all(e["id"] == e["id"].lower() for e in doc["entries"])
    assert "\\u0001" in raw and '\\"fine\\"' in raw                 # Kotlin escaping
    assert any("\u0001" in e["text"] for e in doc["entries"])


def test_distant_past_date_warns(good_export):
    doc = json.loads(json.dumps(good_export))
    doc["entries"][0]["created_at"] = "0001-01-01T00:00:00Z"
    assert any("no real date" in w for w in validate_export(doc))


@pytest.mark.model
@pytest.mark.parametrize("name,status", [("ios-export-v1.json", "ok"),
                                         ("android-export-v1.json", "ok"),
                                         ("android-export-v1-empty.json", "excluded_too_few")])
def test_run_accepts_app_exports(tmp_path, name, status):
    out = tmp_path / "result.json"
    wout = tmp_path / "weights.json"
    assert main(["run", str(FIX / name), "-o", str(out), "-w", str(wout)]) == 0
    result = json.loads(out.read_text("utf-8"))
    assert result["status"] == status
    assert result["synthetic"] is False
    raw = (FIX / name).read_text("utf-8")
    doc = json.loads(raw)
    text = out.read_text("utf-8")
    for e in doc["entries"]:
        assert e["id"] not in text and e["created_at"] not in text
    if status == "ok":
        assert wout.exists()
        wtext = wout.read_text("utf-8")
        for e in doc["entries"]:
            assert e["id"] not in wtext
    else:
        assert not wout.exists()
