"""Validation of the two file contracts: the app export (input) and the result (output).

WHY hand-written checks instead of a JSON-Schema library: the people running
this are volunteers, not engineers. When an export is malformed, they need an
error that names the entry and the field in plain words ("entries[12].self_label
is 'happy'; must be one of joy, sadness, ...") so they can tell the researcher
exactly what went wrong. Every check also collects ALL problems in one pass,
so nobody has to fix-and-rerun one error at a time.

The export contract is `dailyvox-research-export/1`; the result contract is
`dailyvox-study-result/1` (both documented in README.md).
"""

from __future__ import annotations

import re
from datetime import datetime
from typing import Any

from .protocol import (
    ADMISSIBLE_CONSENT_VERSIONS, CANON_LABELS, EXPORT_SCHEMA, RESULT_SCHEMA,
)

PARTICIPANT_CODE_RE = re.compile(r"^DV-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{2}$")
SHA256_RE = re.compile(r"^[0-9a-f]{64}$")
# Object keys in a result are short identifiers (label names, "k25", "lambda_1").
RESULT_KEY_RE = re.compile(r"^[a-z0-9_]{1,40}$")

EXPORT_REQUIRED = {
    "schema": str, "consent_version": str, "participant_code": str,
    "platform": str, "app_version": str, "os_version": str,
    "device_model": str, "exported_at": str, "entry_count": int, "entries": list,
}
EXPORT_OPTIONAL = {"synthetic": bool}
ENTRY_REQUIRED = {
    "id": str, "created_at": str, "text": str, "self_label": str,
    "input": str, "duration_sec": (int, float),
}
MAX_ERRORS = 25


class ExportError(ValueError):
    """The export file does not satisfy dailyvox-research-export/1."""

    def __init__(self, errors: list[str]):
        self.errors = errors
        shown = errors[:MAX_ERRORS]
        more = f"\n  ... and {len(errors) - MAX_ERRORS} more" if len(errors) > MAX_ERRORS else ""
        super().__init__("export is not valid:\n  - " + "\n  - ".join(shown) + more)


class ConsentMismatch(ValueError):
    """Prereg X1: an export with a non-admissible consent stamp is never analysed."""


class ResultError(ValueError):
    """A result file does not satisfy dailyvox-study-result/1."""


def parse_iso8601(value: str) -> datetime | None:
    """Parse an ISO-8601 timestamp; accept a trailing 'Z'. Return None if invalid."""
    if not isinstance(value, str) or not value:
        return None
    try:
        dt = datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None
    return dt if dt.tzinfo is not None else None


def _type_ok(value: Any, expected: type | tuple[type, ...]) -> bool:
    # bool is a subclass of int in Python; never accept it where a number is meant.
    if isinstance(value, bool) and expected is not bool:
        return False
    return isinstance(value, expected)


def _type_name(expected: type | tuple[type, ...]) -> str:
    if isinstance(expected, tuple):
        return "number"
    return {str: "string", int: "integer", list: "list", bool: "true/false"}.get(expected, str(expected))


def validate_export(doc: Any) -> list[str]:
    """Return human-readable warnings; raise ExportError listing every problem.

    Consent admissibility is checked separately (check_consent) so the error
    names the rule (X1) rather than looking like a formatting slip.
    """
    errors: list[str] = []
    warnings: list[str] = []
    if not isinstance(doc, dict):
        raise ExportError(["the file is not a JSON object (did you pick the right file?)"])

    for key, typ in EXPORT_REQUIRED.items():
        if key not in doc:
            errors.append(f"missing field '{key}'")
        elif not _type_ok(doc[key], typ):
            errors.append(f"field '{key}' must be a {_type_name(typ)}")
    for key in doc:
        if key not in EXPORT_REQUIRED and key not in EXPORT_OPTIONAL:
            warnings.append(f"unknown top-level field '{key}' ignored")
    if "synthetic" in doc and not isinstance(doc["synthetic"], bool):
        errors.append("field 'synthetic' must be true/false")

    if doc.get("schema") not in (None, EXPORT_SCHEMA) and isinstance(doc.get("schema"), str):
        errors.append(f"schema is '{doc['schema']}'; this tool reads '{EXPORT_SCHEMA}' "
                      "(update the app or the tool)")
    code = doc.get("participant_code")
    if isinstance(code, str) and not PARTICIPANT_CODE_RE.match(code):
        errors.append(f"participant_code '{code}' is not of the form DV-XXXX-XX "
                      "(letters A-Z without I and O, digits 2-9)")
    if isinstance(doc.get("platform"), str) and doc["platform"] not in ("ios", "android"):
        errors.append(f"platform is '{doc['platform']}'; must be 'ios' or 'android'")
    if isinstance(doc.get("exported_at"), str) and parse_iso8601(doc["exported_at"]) is None:
        errors.append("exported_at is not an ISO-8601 timestamp with a time zone")

    entries = doc.get("entries")
    if isinstance(entries, list):
        if isinstance(doc.get("entry_count"), int) and not isinstance(doc.get("entry_count"), bool) \
                and doc["entry_count"] != len(entries):
            errors.append(f"entry_count says {doc['entry_count']} but the file has "
                          f"{len(entries)} entries (the file may be truncated)")
        seen_ids: dict[str, int] = {}
        prev_dt: datetime | None = None
        for i, e in enumerate(entries):
            where = f"entries[{i}]"
            if not isinstance(e, dict):
                errors.append(f"{where} is not an object")
                continue
            for key, typ in ENTRY_REQUIRED.items():
                if key not in e:
                    errors.append(f"{where} is missing '{key}'")
                elif not _type_ok(e[key], typ):
                    errors.append(f"{where}.{key} must be a {_type_name(typ)}")
            lab = e.get("self_label")
            if isinstance(lab, str) and lab not in CANON_LABELS:
                errors.append(f"{where}.self_label is '{lab}'; must be one of "
                              f"{', '.join(CANON_LABELS)}")
            inp = e.get("input")
            if isinstance(inp, str) and inp not in ("voice", "typed"):
                errors.append(f"{where}.input is '{inp}'; must be 'voice' or 'typed'")
            dur = e.get("duration_sec")
            if _type_ok(dur, (int, float)):
                if dur < 0:
                    errors.append(f"{where}.duration_sec is negative")
                if inp == "typed" and dur != 0:
                    errors.append(f"{where} is 'typed' but has duration_sec {dur} "
                                  "(typed entries have no audio, so duration must be 0)")
            eid = e.get("id")
            if isinstance(eid, str):
                if not eid:
                    errors.append(f"{where}.id is empty")
                elif eid in seen_ids:
                    errors.append(f"{where}.id duplicates entries[{seen_ids[eid]}].id")
                else:
                    seen_ids[eid] = i
            ca = e.get("created_at")
            if isinstance(ca, str):
                dt = parse_iso8601(ca)
                if dt is None:
                    errors.append(f"{where}.created_at is not an ISO-8601 timestamp with a time zone")
                else:
                    if prev_dt is not None and dt < prev_dt:
                        errors.append(f"{where} is older than the entry before it; entries must be "
                                      "in chronological order (oldest first)")
                    prev_dt = dt
    if errors:
        raise ExportError(errors)
    return warnings


def check_consent(doc: dict[str, Any]) -> None:
    """Prereg X1: fail closed, with a named error, on a non-admissible consent stamp."""
    cv = doc.get("consent_version")
    if cv not in ADMISSIBLE_CONSENT_VERSIONS:
        raise ConsentMismatch(
            f"consent_version is '{cv}', but this study analyses only exports made under "
            f"consent {', '.join(ADMISSIBLE_CONSENT_VERSIONS)}. Update the app, re-read and "
            "accept the current consent in Settings -> Research, then export again.")


# --- Result files -----------------------------------------------------------

RESULT_REQUIRED = {
    "schema": str, "tool_version": str, "protocol_hash": str,
    "embedding_model": str, "participant_code": str, "platform": str,
    "app_version": str, "consent_version": str, "input_sha256": str,
    "n_labelled": int, "n_voice": int, "n_typed": int, "label_counts": dict,
    "status": str, "k_primary": int, "created_at": str,
}
RESULT_STATUSES = ("ok", "excluded_too_few")

# Keys whose string values are allowed in a result. Everything else must be a
# number, bool, null, list or object. This is what keeps the file numbers-only.
RESULT_STRING_KEYS = frozenset({
    "schema", "tool_version", "protocol_hash", "embedding_model",
    "participant_code", "platform", "app_version", "consent_version",
    "input_sha256", "status", "created_at", "generic_head_sha256", "note", "environment",
})


def validate_result(doc: Any, source: str = "result") -> None:
    """Raise ResultError if a result file is malformed or carries free text."""
    errs: list[str] = []
    if not isinstance(doc, dict):
        raise ResultError(f"{source}: not a JSON object")
    for key, typ in RESULT_REQUIRED.items():
        if key not in doc:
            errs.append(f"missing '{key}'")
        elif not _type_ok(doc[key], typ):
            errs.append(f"'{key}' must be a {_type_name(typ)}")
    if doc.get("schema") != RESULT_SCHEMA:
        errs.append(f"schema must be '{RESULT_SCHEMA}'")
    if doc.get("status") not in RESULT_STATUSES:
        errs.append(f"status must be one of {RESULT_STATUSES}")
    if isinstance(doc.get("participant_code"), str) and not PARTICIPANT_CODE_RE.match(doc["participant_code"]):
        errs.append("participant_code has the wrong format")
    for k in ("protocol_hash", "input_sha256"):
        if isinstance(doc.get(k), str) and not SHA256_RE.match(doc[k]):
            errs.append(f"'{k}' is not a SHA-256 hex digest")
    if doc.get("status") == "ok":
        for k in ("acc", "delta_primary", "win_primary", "test_size", "primary", "null_arm"):
            if k not in doc:
                errs.append(f"status is ok but '{k}' is missing")
    errs.extend(f"free text at {p}" for p in find_free_text(doc))
    if errs:
        raise ResultError(f"{source}: " + "; ".join(errs))


def find_free_text(obj: Any, path: str = "$") -> list[str]:
    """Paths of string values outside the small whitelist of metadata keys."""
    bad: list[str] = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}"
            if not RESULT_KEY_RE.match(str(k)):
                bad.append(f"{path} (key {str(k)[:12]!r}...)")
            if isinstance(v, str):
                if not (path == "$" and k in RESULT_STRING_KEYS):
                    bad.append(p)
            else:
                bad.extend(find_free_text(v, p))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            if isinstance(v, str):
                bad.append(f"{path}[{i}]")
            else:
                bad.extend(find_free_text(v, f"{path}[{i}]"))
    return bad
