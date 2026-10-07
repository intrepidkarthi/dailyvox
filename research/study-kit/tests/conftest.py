"""Shared fixtures. Tests marked `model` need the embedding model (network on first run)."""

from __future__ import annotations

import json
from pathlib import Path

import pytest

from dailyvox_study.synth import make_persona_export, write_synthetic


@pytest.fixture
def good_export() -> dict:
    return make_persona_export(0, 40)


@pytest.fixture(scope="session")
def synthetic_cohort(tmp_path_factory) -> dict:
    """Run a 10-person synthetic cohort once; reused by every model test."""
    from dailyvox_study.embed import embed_texts
    from dailyvox_study.generic import get_generic_head
    from dailyvox_study.pipeline import run_export

    base = tmp_path_factory.mktemp("cohort")
    exports = write_synthetic(base / "exports", 10)
    head = get_generic_head(embed_texts)
    results_dir = base / "results"
    results_dir.mkdir()
    results = {}
    for p in exports:
        result, text, _ = run_export(p, head=head)
        out = results_dir / f"result-{result['participant_code']}.json"
        out.write_text(text, "utf-8")
        results[p] = (out, result, text)
    return {"base": base, "exports": exports, "results": results, "head": head,
            "results_dir": results_dir}


def write_json(path: Path, doc: dict) -> Path:
    path.write_text(json.dumps(doc), "utf-8")
    return path
