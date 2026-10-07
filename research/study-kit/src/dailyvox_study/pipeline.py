"""Glue: export file -> validated document -> result dict -> checked bytes.

WHY a separate module: the CLI, the selfcheck and the tests must all go through
exactly the same path, including the leak check, so there is no way to produce
a result file that skipped it.
"""

from __future__ import annotations

import json
from pathlib import Path
from typing import Any, Callable

import numpy as np

from .analyze import analyze, assert_no_leak
from .generic import GenericHead, get_generic_head
from .schema import ExportError, validate_export, validate_result


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


def run_export(path: Path, head: GenericHead | None = None,
               embed: Callable[[list[str]], np.ndarray] | None = None
               ) -> tuple[dict[str, Any], str, list[str]]:
    if embed is None:
        from .embed import embed_texts as embed
    doc, raw, warnings = read_export(path)
    head = head or get_generic_head(embed)
    result = analyze(doc, raw, head.W, head.sha256, embed)
    text = serialise(result)
    assert_no_leak(result, doc, text)
    validate_result(json.loads(text), str(path))
    return result, text, warnings
