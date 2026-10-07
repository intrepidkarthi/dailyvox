"""Regenerate the two app-shaped export fixtures, byte for byte.

WHY: the tool's real inputs come from two independent writers on branch
`research/export-v1`:

* iOS `ResearchExportV1.encode` (ios/solyn/ResearchExport.swift): Foundation
  JSONEncoder with [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes] and
  .iso8601 dates. That means keys sorted alphabetically at every level,
  two-space indent, Apple's " : " separator, UPPERCASE UUIDs
  (UUID.uuidString), whole-second UTC dates with a Z, durations rounded to Int,
  non-ASCII written raw.
* Android `Research.export` (android/.../system/Research.kt): a hand-built
  string in CONTRACT key order, one entry per line, ", " between fields,
  lowercase UUIDs (UUID.randomUUID().toString()), ISO_INSTANT whole seconds,
  and its own escaping (\\", \\\\, \\n, \\r, \\t, \\b, \\f, other control
  characters as \\u00xx lowercase, everything else raw).

These fixtures reproduce each writer's exact output shape so a change on
either side that the tool would reject shows up as a failing test here. Run
`python tests/fixtures/make_app_fixtures.py` to regenerate; a test asserts the
committed bytes equal the generator's output.
"""

from __future__ import annotations

import json
import math
import uuid
from datetime import datetime, timedelta, timezone
from pathlib import Path

import numpy as np

HERE = Path(__file__).parent
CANON = ("joy", "sadness", "anger", "fear", "surprise", "disgust", "neutral")
PHRASES = (
    "Long day at work, the standup ran over again",
    "Walked by the lake after dinner and the light was beautiful",
    "My sister called about the wedding plans",
    "Couldn't sleep, kept thinking about the interview",
    "The bus broke down and I was late for everything",
    "Cooked the new recipe, it actually worked",
    "Nothing much happened today, just errands",
    "Found out the rent is going up next month",
)
SPECIAL = (
    'She said "fine", \\ really.\nThen\ttab\u0001done',   # quotes, backslash, newline, tab, control
    "Café with Zoë, naïve plan but lovely 😊",              # accents + emoji (non-BMP)
    "இன்று நல்ல நாள், மழை பெய்தது",                         # Tamil script
    "a/b test for the path c:\\temp and http://x.y/z",       # slashes (iOS: withoutEscapingSlashes)
)


def rows(seed: int, n: int) -> list[dict]:
    rng = np.random.default_rng(seed)
    start = datetime(2026, 8, 1, 20, 0, tzinfo=timezone.utc)
    out = []
    for j in range(n):
        text = SPECIAL[j // 9] if j % 9 == 4 and j // 9 < len(SPECIAL) else \
            f"{PHRASES[int(rng.integers(0, len(PHRASES)))]}. Entry {j + 1}."
        typed = j % 7 == 3
        audio_no_duration = j == 11            # recording whose duration was never measured
        created = start + timedelta(days=j, seconds=int(rng.integers(0, 3600)))
        if j == 21:                            # two entries in the same second
            created = out[-1]["created"]
        duration = 0.0 if (typed or audio_no_duration) else float(rng.uniform(5, 120))
        out.append({"id": uuid.UUID(int=int(rng.integers(0, 2**62)) << 64 | j), "created": created,
                    "text": text, "label": CANON[int(rng.integers(0, 7))],
                    "has_audio": not typed, "duration": duration})
    return out


def iso(dt: datetime) -> str:
    return dt.strftime("%Y-%m-%dT%H:%M:%SZ")


def ios_export(n: int = 40) -> str:
    entries = [{
        "id": str(r["id"]).upper(),
        "created_at": iso(r["created"]),
        "text": r["text"],
        "self_label": r["label"],
        "input": "typed" if (not r["has_audio"] and r["duration"] == 0) else "voice",
        # Swift Int(duration.rounded()): half away from zero, not Python's banker's rounding
        "duration_sec": int(math.floor(r["duration"] + 0.5)),
    } for r in rows(1, n)]
    doc = {"schema": "dailyvox-research-export/1", "consent_version": "3.0",
           "participant_code": "DV-7K3Q-M9", "platform": "ios", "app_version": "1.12.0",
           "os_version": "iOS 26.3", "device_model": "iPhone",
           "exported_at": "2026-10-07T10:00:00Z", "entry_count": len(entries), "entries": entries}
    return json.dumps(doc, indent=2, sort_keys=True, ensure_ascii=False, separators=(",", " : "))


def kotlin_q(s: str) -> str:
    """Research.q(): JSON string literal exactly as the Android writer builds it."""
    out = ['"']
    for ch in s:
        if ch == '"':
            out.append('\\"')
        elif ch == "\\":
            out.append("\\\\")
        elif ch == "\n":
            out.append("\\n")
        elif ch == "\r":
            out.append("\\r")
        elif ch == "\t":
            out.append("\\t")
        elif ch == "\b":
            out.append("\\b")
        elif ch == "\f":
            out.append("\\f")
        elif ord(ch) < 0x20:
            out.append(f"\\u{ord(ch):04x}")
        else:
            out.append(ch)
    out.append('"')
    return "".join(out)


def android_export(n: int = 40, empty: bool = False) -> str:
    rs = [] if empty else rows(2, n)
    lines = ["{\n"]

    def field(k: str, v: str, last: bool = False) -> None:
        lines.append(f"  {kotlin_q(k)}: {v}" + ("\n" if last else ",\n"))

    field("schema", kotlin_q("dailyvox-research-export/1"))
    field("consent_version", kotlin_q("3.0"))
    field("participant_code", kotlin_q("DV-P4XA-7C"))
    field("platform", kotlin_q("android"))
    field("app_version", kotlin_q("1.1"))
    field("os_version", kotlin_q("Android 15"))
    field("device_model", kotlin_q("Google Pixel 9"))
    field("exported_at", kotlin_q("2026-10-07T10:00:00Z"))
    field("entry_count", str(len(rs)))
    lines.append(f"  {kotlin_q('entries')}: [")
    for i, r in enumerate(rs):
        dur = int(r["duration"])                      # Entry.durationSec is an Int already
        typed = (not r["has_audio"]) and dur == 0
        lines.append("\n" if i == 0 else ",\n")
        lines.append("    {"
                     f"{kotlin_q('id')}: {kotlin_q(str(r['id']))}, "
                     f"{kotlin_q('created_at')}: {kotlin_q(iso(r['created']))}, "
                     f"{kotlin_q('text')}: {kotlin_q(r['text'])}, "
                     f"{kotlin_q('self_label')}: {kotlin_q(r['label'])}, "
                     f"{kotlin_q('input')}: {kotlin_q('typed' if typed else 'voice')}, "
                     f"{kotlin_q('duration_sec')}: {dur}"
                     "}")
    lines.append("]\n" if not rs else "\n  ]\n")
    lines.append("}\n")
    return "".join(lines)


FIXTURES = {
    "ios-export-v1.json": ios_export,
    "android-export-v1.json": android_export,
    "android-export-v1-empty.json": lambda: android_export(empty=True),
}

if __name__ == "__main__":
    for name, fn in FIXTURES.items():
        (HERE / name).write_text(fn(), encoding="utf-8")
        print("wrote", name)
