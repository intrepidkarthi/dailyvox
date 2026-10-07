"""Synthetic exports for testing and demos. Clearly marked synthetic, never real.

WHY synthetic personas need a PERSONAL signal: the study asks whether a head
adapted on one person's entries predicts that person better than a generic
head. A useful test cohort therefore needs entries whose emotion is carried
partly by cues that only make sense for that person. Each persona gets its own
random mapping from everyday topics ("the bus ride", "my sister's call") to
emotions: the same topic means joy for one persona and fear for another, so a
generic head cannot learn it but a personal head can. A minority of entries
also carry a generic emotional phrase, so the generic head is above chance.

Labels are uniform by construction (balanced blocks of the 7 classes), which
is what makes the permutation null collapse to roughly zero on this data
(prereg section 7.5: the null collapse check is a synthetic-only gate).

Every file carries "synthetic": true, app_version "0.0.0-synthetic" and a
device_model of "synthetic"; result files inherit the flag, and `combine`
refuses to mix synthetic and real results.
"""

from __future__ import annotations

import json
from datetime import datetime, timedelta, timezone
from pathlib import Path
from typing import Any

import numpy as np

from .protocol import CANON_LABELS, CONSENT_FOR_SYNTH, EXPORT_SCHEMA

CODE_ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
ENTRY_COUNTS = (60, 70, 45, 35, 85, 60, 30, 25, 55, 60, 40, 100)

TOPICS = (
    "the bus ride home", "my sister's call", "the team standup", "cooking dinner",
    "the gym session", "the rent payment", "my neighbour's dog", "the dentist visit",
    "the group chat", "my manager's email", "the long walk by the lake", "the grocery run",
    "the new project", "my old school friend", "the weekend plans", "the leaking tap",
    "the train delay", "my mother's health", "the book club", "the job interview",
    "the evening rain", "the coffee shop", "the car service", "my cousin's wedding",
    "the late meeting", "the garden", "the phone bill", "the football match",
)
CUES = {
    "joy": ("and honestly it made me really happy", "I felt great about it",
            "that was a lovely moment"),
    "sadness": ("and I felt quite low afterwards", "it left me feeling sad",
                "I just felt down about it"),
    "anger": ("and it really made me angry", "I was furious about it",
              "it annoyed me so much"),
    "fear": ("and I got really anxious about it", "it scared me a bit",
             "I was nervous the whole time"),
    "surprise": ("and I did not see that coming", "it totally surprised me",
                 "what a shock that was"),
    "disgust": ("and honestly it was gross", "it disgusted me",
                "the whole thing was revolting"),
    "neutral": ("nothing much else to say", "it was an ordinary day",
                "just noting it down"),
}
FILLERS = ("I keep thinking about it.", "Anyway, that was the main thing today.",
           "Not sure what else to add.", "That is where my head is at.",
           "It stayed with me for a while.")
OPENERS = ("Today it was mostly about", "This morning I kept coming back to",
           "Tonight I am thinking about", "The big thing today was", "Mostly today:")
TYPED = ("I can't talk right now, but {topic}.", "Typing this one: {topic}. {cue}.",
         "Quick note about {topic}.")


def participant_code(rng: np.random.Generator) -> str:
    chars = [CODE_ALPHABET[i] for i in rng.integers(0, len(CODE_ALPHABET), 6)]
    return f"DV-{''.join(chars[:4])}-{''.join(chars[4:])}"


def uniform_labels(n: int, rng: np.random.Generator) -> list[str]:
    labels: list[str] = []
    while len(labels) < n:
        labels.extend(rng.permutation(CANON_LABELS).tolist())
    return labels[:n]


def make_persona_export(index: int, n_entries: int, seed: int = 42,
                        cue_rate: float = 0.35, typed_rate: float = 0.2) -> dict[str, Any]:
    rng = np.random.default_rng([seed, index])
    code = participant_code(rng)
    platform = "ios" if index % 2 == 0 else "android"
    topics = rng.permutation(len(TOPICS))
    personal = {lab: [TOPICS[t] for t in topics[3 * i:3 * i + 3]]
                for i, lab in enumerate(CANON_LABELS)}
    labels = uniform_labels(n_entries, rng)
    start = datetime(2026, 8, 1, 20, 0, tzinfo=timezone.utc) + timedelta(hours=int(index))
    entries = []
    for j, lab in enumerate(labels):
        topic = personal[lab][int(rng.integers(0, 3))]
        if rng.random() < cue_rate:
            cue = CUES[lab][int(rng.integers(0, 3))]
        elif rng.random() < 0.25:
            other = CANON_LABELS[int(rng.integers(0, len(CANON_LABELS)))]
            cue = CUES[other][int(rng.integers(0, 3))]
        else:
            cue = ""
        typed = rng.random() < typed_rate
        if typed:
            tmpl = TYPED[int(rng.integers(0, len(TYPED)))]
            text = tmpl.format(topic=topic, cue=cue or "that is all").replace(". .", ".")
        else:
            filler = FILLERS[int(rng.integers(0, len(FILLERS)))]
            opener = OPENERS[int(rng.integers(0, len(OPENERS)))]
            text = f"Day {j + 1}. {opener} {topic}{', ' + cue if cue else ''}. {filler}"
        created = start + timedelta(days=j, minutes=int(rng.integers(0, 120)))
        entries.append({
            "id": f"synthetic-{index}-{j:04d}-{int(rng.integers(0, 1 << 30)):08x}",
            "created_at": created.isoformat().replace("+00:00", "Z"),
            "text": text,
            "self_label": lab,
            "input": "typed" if typed else "voice",
            "duration_sec": 0 if typed else int(rng.integers(20, 120)),
        })
    return {
        "schema": EXPORT_SCHEMA,
        "consent_version": CONSENT_FOR_SYNTH,
        "participant_code": code,
        "platform": platform,
        "app_version": "0.0.0-synthetic",
        "os_version": "synthetic",
        "device_model": "synthetic",
        "exported_at": (start + timedelta(days=n_entries + 1)).isoformat().replace("+00:00", "Z"),
        "entry_count": len(entries),
        "synthetic": True,
        "entries": entries,
    }


def write_synthetic(out_dir: Path, participants: int, seed: int = 42,
                    counts: tuple[int, ...] = ENTRY_COUNTS) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for i in range(participants):
        doc = make_persona_export(i, counts[i % len(counts)], seed=seed)
        path = out_dir / f"synthetic-export-{i:02d}-{doc['participant_code']}.json"
        path.write_text(json.dumps(doc, indent=1, ensure_ascii=False), encoding="utf-8")
        paths.append(path)
    return paths


def shuffle_labels(doc: dict[str, Any], seed: int) -> dict[str, Any]:
    """Destroy the text-label link (for the null-collapse selfcheck)."""
    rng = np.random.default_rng(seed)
    labs = [e["self_label"] for e in doc["entries"]]
    perm = rng.permutation(len(labs))
    out = json.loads(json.dumps(doc))
    for e, j in zip(out["entries"], perm):
        e["self_label"] = labs[j]
    return out
