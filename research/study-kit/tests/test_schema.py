import copy

import pytest

from dailyvox_study.schema import (
    ConsentMismatch, ExportError, check_consent, find_free_text, validate_export,
)


def test_good_export_validates(good_export):
    assert validate_export(good_export) == []
    check_consent(good_export)


def test_unknown_top_level_field_warns_not_fails(good_export):
    doc = dict(good_export, intensity_scale="1-3")
    assert any("intensity_scale" in w for w in validate_export(doc))


def _expect(doc, fragment):
    with pytest.raises(ExportError) as exc:
        validate_export(doc)
    assert any(fragment in e for e in exc.value.errors), exc.value.errors


def test_bad_label(good_export):
    doc = copy.deepcopy(good_export)
    doc["entries"][3]["self_label"] = "happy"
    _expect(doc, "entries[3].self_label is 'happy'")


def test_missing_field(good_export):
    doc = copy.deepcopy(good_export)
    del doc["platform"]
    _expect(doc, "missing field 'platform'")


def test_entry_missing_text(good_export):
    doc = copy.deepcopy(good_export)
    del doc["entries"][0]["text"]
    _expect(doc, "entries[0] is missing 'text'")


def test_not_chronological(good_export):
    doc = copy.deepcopy(good_export)
    doc["entries"][5], doc["entries"][6] = doc["entries"][6], doc["entries"][5]
    _expect(doc, "chronological")


def test_typed_with_duration(good_export):
    doc = copy.deepcopy(good_export)
    doc["entries"][2]["input"] = "typed"
    doc["entries"][2]["duration_sec"] = 30
    _expect(doc, "typed")


def test_bad_participant_code(good_export):
    doc = dict(good_export, participant_code="DV-IIII-OO")
    _expect(doc, "participant_code")


def test_entry_count_mismatch(good_export):
    doc = dict(good_export, entry_count=999)
    _expect(doc, "entry_count")


def test_duplicate_ids(good_export):
    doc = copy.deepcopy(good_export)
    doc["entries"][1]["id"] = doc["entries"][0]["id"]
    _expect(doc, "duplicates")


def test_wrong_schema(good_export):
    doc = dict(good_export, schema="dailyvox-research-export/2")
    _expect(doc, "schema")


def test_bad_platform_and_bool_as_number(good_export):
    doc = copy.deepcopy(good_export)
    doc["platform"] = "windows"
    doc["entries"][0]["duration_sec"] = True
    with pytest.raises(ExportError) as exc:
        validate_export(doc)
    msgs = " ".join(exc.value.errors)
    assert "platform" in msgs and "duration_sec" in msgs


def test_all_errors_collected(good_export):
    doc = copy.deepcopy(good_export)
    doc["entries"][0]["self_label"] = "x"
    doc["entries"][1]["self_label"] = "y"
    with pytest.raises(ExportError) as exc:
        validate_export(doc)
    assert len(exc.value.errors) >= 2


def test_not_an_object():
    with pytest.raises(ExportError):
        validate_export([1, 2, 3])


def test_consent_mismatch(good_export):
    with pytest.raises(ConsentMismatch):
        check_consent(dict(good_export, consent_version="2.1"))


def test_free_text_detector():
    assert find_free_text({"schema": "x", "acc": {"k0": 0.5}}) == []
    assert find_free_text({"acc": {"k0": "I felt sad"}}) == ["$.acc.k0"]
    assert find_free_text({"list": [1, "word"]}) == ["$.list[1]"]
    assert find_free_text({"label_counts": {"I felt sad today": 1}})  # text smuggled as a key
