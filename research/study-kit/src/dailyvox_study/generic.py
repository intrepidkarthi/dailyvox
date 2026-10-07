"""The generic (K = 0) head: trained once on GoEmotions, identical for everyone.

WHY GoEmotions: the generic head needs licence-clean training text labelled
with exactly the study's 7 classes. GoEmotions (Demszky et al. 2020,
Apache-2.0) ships an official Ekman mapping from its 27 emotions onto
anger/disgust/fear/joy/sadness/surprise, plus neutral, which is the study's
canon one-to-one. Rows are taken from the raw TSVs at a pinned commit of the
google-research repository and every file is SHA-256-checked, so the corpus
cannot drift underneath the protocol.

Row recipe (follows the published Experiment A "R2" recipe; see DEVIATIONS.md D2):
  train + dev splits; map each row's labels through the Ekman mapping;
  keep rows whose labels all map to ONE canon class; drop rows under 5 words;
  drop exact-duplicate text; cap each class at 800 rows (seeded sample).

WHY ship the trained head with the package: the pre-registration requires a
hash-pinned generic head (section 7.1). Participants run on different laptops,
whose maths libraries can differ in the last bit; if each laptop retrained
the head, the K = 0 comparator would differ by a hair per participant. So the
head trained once (by `dailyvox-study build-generic-head`) is shipped as JSON,
its SHA-256 is pinned below, and every participant loads exactly those bytes.
Rebuilding is fully reproducible from the pinned data and is how anyone can
audit the shipped head; selfcheck does exactly that.
"""

from __future__ import annotations

import csv
import hashlib
import io
import json
import urllib.request
from dataclasses import dataclass
from importlib import resources
from pathlib import Path
from typing import Any

import numpy as np

from .protocol import (
    CANON_LABELS, GENERIC_LAMBDA_GRID, GENERIC_MIN_WORDS, GENERIC_PER_CLASS_CAP,
    GENERIC_SPLITS, GENERIC_VAL_FRACTION, GOEMOTIONS_FILES, LABEL_INDEX, SEED,
    goemotions_url, protocol_hash,
)
from .heads import add_bias, fit_ridge, predict

# SHA-256 of the shipped head's weights (little-endian float64, C order).
# Filled from the build run on 2026-10-07; see README "Reproducing the generic head".
PINNED_GENERIC_HEAD_SHA256 = "4e41f31191be15a04a4981907600b6ea0bd59216793e3f663ef422e69e3b1ef2"
PACKAGED_HEAD = "generic_head_v1.json"


def cache_dir() -> Path:
    return Path.home() / ".cache" / "dailyvox-study"


def weights_sha256(W: np.ndarray) -> str:
    return hashlib.sha256(np.ascontiguousarray(W, dtype="<f8").tobytes()).hexdigest()


@dataclass
class GenericHead:
    W: np.ndarray                 # (385, 7)
    lam: float
    n_rows: int
    class_histogram: dict[str, int]
    val_accuracy: dict[str, float]
    sha256: str
    source: str                   # "packaged" | "cache" | "built"

    def to_json(self) -> dict[str, Any]:
        return {
            "protocol_hash": protocol_hash(),
            "lambda": self.lam,
            "n_rows": self.n_rows,
            "class_histogram": self.class_histogram,
            "val_accuracy_by_lambda": self.val_accuracy,
            "weights_sha256": self.sha256,
            "shape": list(self.W.shape),
            "weights": self.W.tolist(),
        }


def _download(name: str, dest: Path) -> bytes:
    """Fetch one pinned GoEmotions file (or reuse the cached copy) and verify it."""
    expected = GOEMOTIONS_FILES[name]
    if dest.exists():
        data = dest.read_bytes()
        if hashlib.sha256(data).hexdigest() == expected:
            return data
    with urllib.request.urlopen(goemotions_url(name), timeout=120) as resp:
        data = resp.read()
    got = hashlib.sha256(data).hexdigest()
    if got != expected:
        raise RuntimeError(f"GoEmotions {name}: SHA-256 {got} != pinned {expected}. "
                           "The upstream file changed; the protocol cannot run on it.")
    dest.parent.mkdir(parents=True, exist_ok=True)
    dest.write_bytes(data)
    return data


def load_generic_rows(data_dir: Path | None = None) -> tuple[list[str], np.ndarray, dict[str, int]]:
    """Build the generic training rows. Returns (texts, labels, filter_counts)."""
    data_dir = data_dir or cache_dir() / "goemotions"
    files = {name: _download(name, data_dir / name) for name in GOEMOTIONS_FILES}
    emotions = files["emotions.txt"].decode("utf-8").split()
    ekman = json.loads(files["ekman_mapping.json"].decode("utf-8"))
    to_canon: dict[str, str] = {"neutral": "neutral"}
    for canon, fine in ekman.items():
        for f in fine:
            to_canon[f] = canon
    assert set(to_canon.values()) == set(CANON_LABELS), "Ekman mapping no longer matches the canon"

    counts = {"rows_read": 0, "multi_class": 0, "too_short": 0, "duplicate": 0}
    texts: list[str] = []
    labels: list[int] = []
    seen: set[str] = set()
    for split in GENERIC_SPLITS:
        reader = csv.reader(io.StringIO(files[split].decode("utf-8")), delimiter="\t",
                            quoting=csv.QUOTE_NONE)
        for row in reader:
            counts["rows_read"] += 1
            text, ids = row[0].strip(), row[1]
            classes = {to_canon[emotions[int(i)]] for i in ids.split(",")}
            if len(classes) != 1:
                counts["multi_class"] += 1
                continue
            if len(text.split()) < GENERIC_MIN_WORDS:
                counts["too_short"] += 1
                continue
            if text in seen:
                counts["duplicate"] += 1
                continue
            seen.add(text)
            texts.append(text)
            labels.append(LABEL_INDEX[classes.pop()])

    y = np.asarray(labels)
    rng = np.random.default_rng(SEED)
    keep: list[int] = []
    for c in range(len(CANON_LABELS)):
        idx = np.flatnonzero(y == c)
        if len(idx) > GENERIC_PER_CLASS_CAP:
            idx = np.sort(rng.choice(idx, GENERIC_PER_CLASS_CAP, replace=False))
        keep.extend(idx.tolist())
    keep.sort()
    counts["rows_kept"] = len(keep)
    return [texts[i] for i in keep], y[keep], counts


def train_generic_head(texts: list[str], y: np.ndarray, embed) -> GenericHead:
    """Select lambda on a seeded 90/10 split inside the generic data, refit on all of it."""
    Xb = add_bias(embed(texts))
    rng = np.random.default_rng(SEED)
    order = rng.permutation(len(y))
    cut = int(len(y) * (1.0 - GENERIC_VAL_FRACTION))
    fit_idx, val_idx = order[:cut], order[cut:]
    val_acc: dict[str, float] = {}
    best_lam, best_acc = None, -1.0
    for lam in GENERIC_LAMBDA_GRID:
        W = fit_ridge(Xb[fit_idx], y[fit_idx], lam)
        acc = float(np.mean(predict(Xb[val_idx], W) == y[val_idx]))
        val_acc[_lam_key(lam)] = round(acc, 6)
        if acc > best_acc:               # strict: ties keep the smaller lambda
            best_lam, best_acc = lam, acc
    W = fit_ridge(Xb, y, best_lam)
    hist = {lab: int(np.sum(y == i)) for i, lab in enumerate(CANON_LABELS)}
    return GenericHead(W=W, lam=float(best_lam), n_rows=len(y), class_histogram=hist,
                       val_accuracy=val_acc, sha256=weights_sha256(W), source="built")


def _lam_key(lam: float) -> str:
    return f"lambda_{int(lam)}" if float(lam).is_integer() else f"lambda_{lam}"


def _from_json(doc: dict[str, Any], source: str) -> GenericHead:
    W = np.asarray(doc["weights"], dtype=np.float64)
    sha = weights_sha256(W)
    if sha != doc["weights_sha256"]:
        raise RuntimeError(f"generic head ({source}) is corrupt: weights hash {sha} "
                           f"!= recorded {doc['weights_sha256']}")
    return GenericHead(W=W, lam=float(doc["lambda"]), n_rows=int(doc["n_rows"]),
                       class_histogram=dict(doc["class_histogram"]),
                       val_accuracy=dict(doc["val_accuracy_by_lambda"]), sha256=sha,
                       source=source)


def packaged_head() -> GenericHead | None:
    """The shipped head, if present and built under the current protocol."""
    try:
        text = resources.files("dailyvox_study.data").joinpath(PACKAGED_HEAD).read_text("utf-8")
    except (FileNotFoundError, ModuleNotFoundError):
        return None
    doc = json.loads(text)
    if doc.get("protocol_hash") != protocol_hash():
        return None
    head = _from_json(doc, "packaged")
    if PINNED_GENERIC_HEAD_SHA256 != "UNPINNED" and head.sha256 != PINNED_GENERIC_HEAD_SHA256:
        raise RuntimeError("shipped generic head does not match the pinned SHA-256; "
                           "reinstall the tool")
    return head


def cache_path() -> Path:
    return cache_dir() / protocol_hash() / "generic_head.json"


def build_and_cache(embed, data_dir: Path | None = None) -> tuple[GenericHead, dict[str, int]]:
    texts, y, counts = load_generic_rows(data_dir)
    head = train_generic_head(texts, y, embed)
    path = cache_path()
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(head.to_json(), sort_keys=True), encoding="utf-8")
    return head, counts


def get_generic_head(embed) -> GenericHead:
    """Packaged head first (identical for everyone), then cache, then build."""
    head = packaged_head()
    if head is not None:
        return head
    path = cache_path()
    if path.exists():
        return _from_json(json.loads(path.read_text("utf-8")), "cache")
    head, _ = build_and_cache(embed)
    return head
