"""Frozen protocol constants for the DailyVox decentralised K-curve study.

WHY this module exists: a pre-registered analysis is only as good as the
promise that nobody tuned it after seeing data. Every number that changes what
the analysis computes lives here, in one place, and the SHA-256 of a canonical
JSON of these constants (``protocol_hash``) is stamped into every result file.
``combine`` refuses to pool result files whose protocol hashes differ, so a
participant who ran a modified copy of the tool cannot silently enter a cohort.

Changing ANY value below is a protocol change: it changes the hash, and it
must be logged in DEVIATIONS.md and re-registered.

The constants follow the Experiment B pre-registration (FINAL draft v2.1):
S3 split rule (section 4.2), K grid (section 4.4), lambda_adapt = 10 and the
lambda = 1 fallback (section 4.5 / 6.6), seed 42, the 7-class canon
(section 4.1), and alpha = 0.05 one-sided fixed sequence (section 6.1).
Deviations forced by the open-embedding, result-file-only design are listed
in DEVIATIONS.md.
"""

from __future__ import annotations

import hashlib
import json
from typing import Any

from . import __version__

# --- Label canon (prereg section 4.1: exactly 7 classes, neutral included) ---
CANON_LABELS: tuple[str, ...] = (
    "joy", "sadness", "anger", "fear", "surprise", "disgust", "neutral",
)
N_CLASSES = len(CANON_LABELS)
LABEL_INDEX: dict[str, int] = {lab: i for i, lab in enumerate(CANON_LABELS)}

# --- Schemas and consent (contract sections 1-2; prereg X1) ---
EXPORT_SCHEMA = "dailyvox-research-export/1"
RESULT_SCHEMA = "dailyvox-study-result/1"
# X1: only exports stamped with an admissible consent version are analysed.
# "3.0" is the result-file-only consent (see CONSENT-CHANGES.md).
ADMISSIBLE_CONSENT_VERSIONS: tuple[str, ...] = ("3.0",)
CONSENT_FOR_SYNTH = ADMISSIBLE_CONSENT_VERSIONS[0]

# --- Split rule S3 (prereg section 4.2 / Amendment A1) ---
TEST_CAP = 35          # m = min(TEST_CAP, max(TEST_FLOOR, n - K_PRIMARY))
TEST_FLOOR = 10
K_PRIMARY = 25
K_GRID: tuple[int, ...] = (0, 5, 10, 25)
K_BREADTH = 10                     # H4 (Step 5)
MIN_LABELLED_ANY = 30              # X4: below this, no analysis at all
MIN_LABELLED_PRIMARY = 35          # X5: below this, not in N25
GAP_SENSITIVITY_MAX = 25           # X15

# --- Heads (prereg section 4.5) ---
LAMBDA_ADAPT = 10.0
LAMBDA_FALLBACK = 1.0              # section 6.6 lambda branch destination
LAMBDA_SWEEP: tuple[float, ...] = (1.0, 10.0, 100.0)   # E5, section 6.6 probe
GENERIC_LAMBDA_GRID: tuple[float, ...] = (1.0, 10.0, 100.0, 1000.0)
GENERIC_VAL_FRACTION = 0.10        # seeded 90/10 split inside generic data
SEED = 42

# --- Statistics (prereg sections 6.1-6.6, 7.3, 7.5) ---
ALPHA = 0.05
EXACT_ENUMERATION_MAX_N = 20       # 2^20 = 1,048,576 sign patterns
MONTE_CARLO_DRAWS = 200_000        # used only when N > 20, and reported
NULL_PERMUTATIONS = 1000           # section 7.5 pre-registered P
BOOTSTRAP_DRAWS = 10_000
INFERIORITY_WIN_PROB = 0.70        # section 6.3 criterion (a)
INFERIORITY_DELTA = 0.06           # section 6.3 criterion (b): +6 pt
DONOR_NONINFERIORITY_MARGIN = 0.02 # section 7.3 (unrunnable here; kept for the map)
LOW_D_THRESHOLD = 2                # section 6.6: median d <= 2 branch
FALLBACK_D_MIN = 4                 # section 6.6: median d at lambda=1 >= 4
LABEL_RATE_FLAG = 0.15             # S11 (not computable from export v1)

# --- Embedding model (DEVIATION D1: replaces Apple NLEmbedding) ---
EMBEDDING_MODEL_ID = "sentence-transformers/all-MiniLM-L6-v2"
EMBEDDING_MODEL_REVISION = "1110a243fdf4706b3f48f1d95db1a4f5529b4d41"
EMBEDDING_MODEL_LICENSE = "Apache-2.0"
EMBEDDING_DIM = 384
EMBEDDING_BATCH_SIZE = 32

# --- Generic training data (DEVIATION D2: replaces the missing ship-train.json) ---
GOEMOTIONS_REPO = "google-research/google-research"
GOEMOTIONS_COMMIT = "7951440944924ac61b6e2f9a2a3c715834005c40"
GOEMOTIONS_FILES: dict[str, str] = {
    # file name -> SHA-256 of the raw bytes at GOEMOTIONS_COMMIT
    "train.tsv": "1c254a142be5c00e80d819b9ae1bbd36d94b2eeb8f4b1271846508d57e57d9c5",
    "dev.tsv": "575489c079c9de1097062a01738f998590d6b7ead66dd1c9fd1d2ba01fd8bc62",
    "emotions.txt": "45c3ef86782d2a4d7fedcd6d8c111aa0d0e94720689bd164fac94fefb4495a89",
    "ekman_mapping.json": "d6b1fea382917c1685c42e1324a0344106be9390f52a3850ce032656d103a328",
}
GOEMOTIONS_LICENSE = "Apache-2.0"
GENERIC_SPLITS: tuple[str, ...] = ("train.tsv", "dev.tsv")
GENERIC_MIN_WORDS = 5
GENERIC_PER_CLASS_CAP = 800


def goemotions_url(name: str) -> str:
    return (f"https://raw.githubusercontent.com/{GOEMOTIONS_REPO}/"
            f"{GOEMOTIONS_COMMIT}/goemotions/data/{name}")


def embedding_model_string() -> str:
    return f"{EMBEDDING_MODEL_ID}@{EMBEDDING_MODEL_REVISION}"


def tool_version_major() -> str:
    return __version__.split(".")[0]


def frozen_constants() -> dict[str, Any]:
    """Every value that changes what is computed. Hashed into protocol_hash."""
    return {
        "protocol": "dailyvox-expB-decentralised",
        "tool_version_major": tool_version_major(),
        "label_canon": list(CANON_LABELS),
        "admissible_consent_versions": list(ADMISSIBLE_CONSENT_VERSIONS),
        "split_rule": {
            "rule": "m = min(cap, max(floor, n - k_primary)); test = last m; pool = first n - m",
            "cap": TEST_CAP, "floor": TEST_FLOOR, "k_primary": K_PRIMARY,
            "min_labelled_any": MIN_LABELLED_ANY,
            "min_labelled_primary": MIN_LABELLED_PRIMARY,
        },
        "k_grid": list(K_GRID),
        "k_breadth": K_BREADTH,
        "lambda_adapt": LAMBDA_ADAPT,
        "lambda_fallback": LAMBDA_FALLBACK,
        "lambda_sweep": list(LAMBDA_SWEEP),
        "generic_lambda_grid": list(GENERIC_LAMBDA_GRID),
        "generic_val_fraction": GENERIC_VAL_FRACTION,
        "seed": SEED,
        "alpha": ALPHA,
        "exact_enumeration_max_n": EXACT_ENUMERATION_MAX_N,
        "monte_carlo_draws": MONTE_CARLO_DRAWS,
        "null_permutations": NULL_PERMUTATIONS,
        "bootstrap_draws": BOOTSTRAP_DRAWS,
        "inferiority": {"win_prob": INFERIORITY_WIN_PROB, "delta": INFERIORITY_DELTA},
        "low_d_threshold": LOW_D_THRESHOLD,
        "fallback_d_min": FALLBACK_D_MIN,
        "embedding": {
            "model": EMBEDDING_MODEL_ID, "revision": EMBEDDING_MODEL_REVISION,
            "dim": EMBEDDING_DIM, "batch_size": EMBEDDING_BATCH_SIZE,
            "normalised": True, "device": "cpu",
        },
        "generic_data": {
            "source": f"github:{GOEMOTIONS_REPO}/goemotions/data",
            "commit": GOEMOTIONS_COMMIT,
            "files_sha256": dict(sorted(GOEMOTIONS_FILES.items())),
            "splits": list(GENERIC_SPLITS),
            "mapping": "official ekman_mapping.json; neutral -> neutral",
            "row_filter": "single canonical class after mapping; >= min_words words; exact-duplicate text dropped",
            "min_words": GENERIC_MIN_WORDS,
            "per_class_cap": GENERIC_PER_CLASS_CAP,
        },
        "head": "one-vs-rest ridge over [embedding, 1], one-hot 0/1 targets, bias penalised",
        "adaptation": "W = argmin ||XW - Y||^2 + lambda ||W - W_generic||^2 (closed form)",
    }


def canonical_json(obj: Any) -> bytes:
    """Byte-stable JSON: sorted keys, no whitespace, ASCII only."""
    return json.dumps(obj, sort_keys=True, separators=(",", ":"),
                      ensure_ascii=True, allow_nan=False).encode("ascii")


def protocol_hash() -> str:
    return hashlib.sha256(canonical_json(frozen_constants())).hexdigest()
