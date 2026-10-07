"""Glue: export file -> validated document -> result (+ weights) -> checked bytes.

WHY a separate module: the CLI, the selfcheck and the tests must all go through
exactly the same path, including the leak checks on BOTH output files, so there
is no way to produce a result or weights file that skipped them.
"""

from __future__ import annotations

import hashlib
import json
from dataclasses import dataclass
from pathlib import Path
from typing import Any, Callable

import numpy as np

from .analyze import analyze, assert_no_leak
from .generic import GenericHead, get_generic_head
from .schema import ExportError, validate_export, validate_result
from .weights import DonorError, check_donors_for_export, validate_donors, validate_weights


def read_export(path: Path) -> tuple[dict[str, Any], bytes, list[str]]:
    raw = path.read_bytes()
    try:
        doc = json.loads(raw.decode("utf-8"))
    except (UnicodeDecodeError, json.JSONDecodeError) as exc:
        raise ExportError([f"the file is not valid UTF-8 JSON ({exc})"]) from exc
    warnings = validate_export(doc)
    return doc, raw, warnings


def serialise(result: dict[str, Any]) -> str:
    return json.dumps(result, indent=2, sort_keys=True, ensure_ascii=True, allow_nan=False) + "\n"


def serialise_compact(doc: dict[str, Any]) -> str:
    return json.dumps(doc, sort_keys=True, separators=(",", ":"), ensure_ascii=True,
                      allow_nan=False) + "\n"


@dataclass
class RunOutput:
    result: dict[str, Any]
    text: str
    warnings: list[str]
    weights_text: str | None


def load_donors(path: Path) -> dict[str, Any]:
    try:
        doc = json.loads(path.read_text("utf-8"))
    except (json.JSONDecodeError, UnicodeDecodeError) as exc:
        raise DonorError(f"{path}: not JSON ({exc})") from exc
    validate_donors(doc, str(path))
    return doc


def run_export_full(path: Path, head: GenericHead | None = None,
                    embed: Callable[[list[str]], np.ndarray] | None = None,
                    donors_path: Path | None = None) -> RunOutput:
    if embed is None:
        from .embed import embed_texts as embed
    doc, raw, warnings = read_export(path)
    head = head or get_generic_head(embed)
    donors = None
    if donors_path is not None:
        donors = load_donors(donors_path)
        check_donors_for_export(donors, doc, hashlib.sha256(raw).hexdigest(), head.sha256)
    result, weights = analyze(doc, raw, head.W, head.sha256, embed, donors)
    text = serialise(result)
    assert_no_leak(result, doc, text)
    validate_result(json.loads(text), str(path))
    weights_text = None
    if weights is not None:
        weights_text = serialise_compact(weights)
        assert_no_leak(weights, doc, weights_text, kind="weights")
        validate_weights(json.loads(weights_text), "weights")
    return RunOutput(result, text, warnings, weights_text)


def run_export(path: Path, head: GenericHead | None = None,
               embed: Callable[[list[str]], np.ndarray] | None = None
               ) -> tuple[dict[str, Any], str, list[str]]:
    """Round-1 convenience wrapper returning (result, text, warnings)."""
    out = run_export_full(path, head, embed)
    return out.result, out.text, out.warnings
