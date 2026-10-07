"""Two-round donor arms: share fitted heads, never text (prereg section 7.3; DEVIATIONS D4).

WHY: the pre-registration's register-confound control compares a person's own
head with heads built from OTHER participants' entries (donor, donorPlusPrior,
pooledLOPO). In the result-file-only design no machine holds two people's
entries, so these arms are rebuilt from shared heads instead:

  Round 1  `run` writes weights.json: this participant's ridge heads (385 x 7
           numbers each), fitted on their own adaptation pool. Sending it is
           the participant's choice.
  Coordinator  `donors` turns everyone's weights into, for each participant P,
           donor heads computed ONLY from the other participants' weights.
  Round 2  `run --donors` scores those heads on P's own test tail, locally.

HOW the heads stand in for row-level refits (divide-and-conquer ridge): if
participant q's head is W_q = (A_q + mu I)^-1 (b_q + mu W0) with A_q = X_q'X_q,
then when the A_q are similar across people, the mean over D people of heads
fitted at mu = lambda / D approximates the ridge refit on all their rows pooled
at lambda. So:

  * donor (prereg: K rows round-robin across others, volume-matched, lambda)
    = mean over others of their K-row heads at lambda. Each donor contributes
    about K / D rows' worth, matching the volume.
  * pooledLOPO (prereg: all others' pool rows, lambda)
    = mean over others of their pool heads fitted at lambda / d, with d the
    shared divisor closest to the number of others. Participants ship pool
    heads for d in {1, 2, 4, 8, 16, 32} because D is unknown in round 1.
  * donorPlusPrior = P's own bias-only refit on top of the donor head, done
    locally in round 2, exactly as section 7.3 defines it.

The approximation is measured against the exact row-level refits on synthetic
cohorts in `selfcheck` and reported in DEVIATIONS.md.

Privacy rule: a donors file never contains one other person's head; every head
in it averages at least two other participants (MIN_WEIGHTS_PARTICIPANTS = 3).
"""

from __future__ import annotations

import hashlib
import json
import math
from datetime import datetime, timezone
from pathlib import Path
from typing import Any

import numpy as np

from . import __version__
from .heads import fit_ridge_to_prior
from .protocol import (
    DONOR_KS, DONOR_LAMBDAS, DONOR_MANIFEST_SCHEMA, DONORS_SCHEMA, MIN_WEIGHTS_PARTICIPANTS,
    POOL_DIVISORS, WEIGHTS_SCHEMA, WEIGHTS_SIG_DIGITS, canonical_json, embedding_model_string,
    protocol_hash,
)
from .split import Split

WEIGHTS_STRING_KEYS = frozenset({
    "schema", "tool_version", "protocol_hash", "generic_head_sha256", "embedding_model",
    "participant_code", "input_sha256", "created_at", "manifest_sha256", "note",
})


class DonorError(RuntimeError):
    """Weights or donors files cannot be used; the message says why."""


def lam_key(lam: float) -> str:
    return f"lambda_{int(lam)}"


def round_matrix(W: np.ndarray) -> list[list[float]]:
    """Fixed significant digits: smaller files, and identical bytes on re-run."""
    return [[float(f"{v:.{WEIGHTS_SIG_DIGITS}g}") for v in row] for row in W]


def build_weights(Xb: np.ndarray, y: np.ndarray, sp: Split, W0: np.ndarray,
                  meta: dict[str, Any]) -> dict[str, Any]:
    """Round 1: this participant's heads, exactly what the donor arms consume."""
    heads: dict[str, dict[str, Any]] = {}
    for lam in DONOR_LAMBDAS:
        block: dict[str, Any] = {}
        for k in DONOR_KS:
            rows = min(k, sp.pool)            # prereg F2b: first min(K, pool_q) rows
            block[f"k{k}"] = round_matrix(fit_ridge_to_prior(Xb[:rows], y[:rows], W0, lam))
        for d in POOL_DIVISORS:
            block[f"pool_div{d}"] = round_matrix(
                fit_ridge_to_prior(Xb[:sp.pool], y[:sp.pool], W0, lam / d))
        heads[lam_key(lam)] = block
    return {
        "schema": WEIGHTS_SCHEMA,
        **meta,
        "rows_used": {**{f"k{k}": min(k, sp.pool) for k in DONOR_KS}, "pool": sp.pool},
        "shape": list(W0.shape),
        "heads": heads,
        "created_at": _now(),
    }


def _now() -> str:
    return datetime.now(timezone.utc).replace(microsecond=0).isoformat().replace("+00:00", "Z")


def find_free_text_generic(obj: Any, allowed: frozenset[str], path: str = "$") -> list[str]:
    from .schema import RESULT_KEY_RE, is_hash_field

    bad: list[str] = []
    if isinstance(obj, dict):
        for k, v in obj.items():
            p = f"{path}.{k}"
            if not RESULT_KEY_RE.match(str(k)):
                bad.append(f"{path} (key)")
            if isinstance(v, str):
                if not (path == "$" and k in allowed) and not is_hash_field(k, v):
                    bad.append(p)
            else:
                bad.extend(find_free_text_generic(v, allowed, p))
    elif isinstance(obj, list):
        for i, v in enumerate(obj):
            if isinstance(v, str):
                bad.append(f"{path}[{i}]")
            elif isinstance(v, (dict, list)):
                bad.extend(find_free_text_generic(v, allowed, f"{path}[{i}]"))
    return bad


def _check_matrix(M: Any, shape: list[int]) -> bool:
    if not isinstance(M, list) or len(M) != shape[0]:
        return False
    for row in M:
        if not isinstance(row, list) or len(row) != shape[1]:
            return False
        for v in row:
            if isinstance(v, bool) or not isinstance(v, (int, float)) or not math.isfinite(v):
                return False
    return True


def validate_weights(doc: Any, source: str = "weights") -> None:
    errs: list[str] = []
    if not isinstance(doc, dict) or doc.get("schema") != WEIGHTS_SCHEMA:
        raise DonorError(f"{source}: not a {WEIGHTS_SCHEMA} file")
    for k in ("protocol_hash", "generic_head_sha256", "participant_code", "input_sha256",
              "heads", "shape", "rows_used", "tool_version"):
        if k not in doc:
            errs.append(f"missing '{k}'")
    if not errs:
        for lam in DONOR_LAMBDAS:
            block = doc["heads"].get(lam_key(lam), {})
            for key in [f"k{k}" for k in DONOR_KS] + [f"pool_div{d}" for d in POOL_DIVISORS]:
                if not _check_matrix(block.get(key), doc["shape"]):
                    errs.append(f"head {lam_key(lam)}.{key} missing or malformed")
    errs.extend(f"free text at {p}" for p in find_free_text_generic(doc, WEIGHTS_STRING_KEYS))
    if errs:
        raise DonorError(f"{source}: " + "; ".join(errs[:10]))


def choose_divisor(n_others: int) -> int:
    """The shipped divisor closest to the number of others, in log2 (ties: smaller)."""
    target = math.log2(max(n_others, 1))
    return min(POOL_DIVISORS, key=lambda d: (abs(math.log2(d) - target), d))


def file_sha256(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_weights(inputs: list[Path]) -> list[tuple[Path, dict[str, Any]]]:
    paths: list[Path] = []
    for p in inputs:
        paths.extend(sorted(p.glob("*.json")) if p.is_dir() else [p])
    out = []
    for p in paths:
        try:
            doc = json.loads(p.read_text("utf-8"))
        except (json.JSONDecodeError, UnicodeDecodeError) as exc:
            raise DonorError(f"{p}: not JSON ({exc})") from exc
        validate_weights(doc, str(p))
        out.append((p, doc))
    return out


def build_donors(weights: list[tuple[Path, dict[str, Any]]], p0_codes: set[str] | None = None
                 ) -> tuple[dict[str, dict[str, Any]], dict[str, Any]]:
    """Coordinator step. Returns ({code: donors doc}, manifest)."""
    p0_codes = p0_codes or set()
    problems: list[str] = []
    for key in ("protocol_hash", "generic_head_sha256", "tool_version", "embedding_model"):
        values = {str(d.get(key)) for _, d in weights}
        if len(values) > 1:
            problems.append(f"mixed {key}: " + ", ".join(
                f"{p.name}={str(d.get(key))[:16]}" for p, d in weights))
    if weights and weights[0][1]["protocol_hash"] != protocol_hash():
        problems.append("weights were made under a different protocol than this tool")
    for key in ("participant_code", "input_sha256"):
        seen: dict[str, list[str]] = {}
        for p, d in weights:
            seen.setdefault(d[key], []).append(p.name)
        problems.extend(f"duplicate {key} {v[:16]}: {', '.join(f)}"
                        for v, f in sorted(seen.items()) if len(f) > 1)
    pool_members = sorted((d["participant_code"], d) for _, d in weights
                          if d["participant_code"] not in p0_codes)
    if len(pool_members) < MIN_WEIGHTS_PARTICIPANTS:
        problems.append(
            f"only {len(pool_members)} non-P0 participants sent weights; the donor arms need at "
            f"least {MIN_WEIGHTS_PARTICIPANTS} (each donor head must average at least 2 other "
            "people, so no file ever carries one person's head; the prereg needs N10 >= 2)")
    if problems:
        raise DonorError("refusing to build donors:\n  - " + "\n  - ".join(problems))

    manifest_core = {
        "schema": DONOR_MANIFEST_SCHEMA,
        "protocol_hash": weights[0][1]["protocol_hash"],
        "generic_head_sha256": weights[0][1]["generic_head_sha256"],
        "p0_excluded": sorted(p0_codes & {d["participant_code"] for _, d in weights}),
        "weights": sorted(({"participant_code": d["participant_code"],
                            "input_sha256": d["input_sha256"],
                            "weights_sha256": file_sha256(p)} for p, d in weights),
                          key=lambda r: r["participant_code"]),
    }
    manifest_sha = hashlib.sha256(canonical_json(manifest_core)).hexdigest()
    mats = {code: {lk: {k: np.asarray(v, dtype=np.float64) for k, v in blk.items()}
                   for lk, blk in d["heads"].items()} for code, d in pool_members}
    donors: dict[str, dict[str, Any]] = {}
    for _, d in sorted(weights, key=lambda t: t[1]["participant_code"]):
        code = d["participant_code"]
        others = [c for c, _ in pool_members if c != code]
        div = choose_divisor(len(others))
        heads: dict[str, dict[str, Any]] = {}
        for lam in DONOR_LAMBDAS:
            lk = lam_key(lam)
            blk = {f"donor_k{k}": round_matrix(np.mean([mats[o][lk][f"k{k}"] for o in others], 0))
                   for k in DONOR_KS}
            blk["pooled_lopo"] = round_matrix(
                np.mean([mats[o][lk][f"pool_div{div}"] for o in others], 0))
            heads[lk] = blk
        donors[code] = {
            "schema": DONORS_SCHEMA,
            "tool_version": __version__,
            "protocol_hash": d["protocol_hash"],
            "generic_head_sha256": d["generic_head_sha256"],
            "embedding_model": d.get("embedding_model", embedding_model_string()),
            "participant_code": code,
            "input_sha256": d["input_sha256"],
            "manifest_sha256": manifest_sha,
            "n_donors": len(others),
            "pool_divisor": div,
            "synthetic": bool(d.get("synthetic", False)),
            "shape": d["shape"],
            "heads": heads,
        }
    manifest = {**manifest_core, "manifest_sha256": manifest_sha,
                "min_participants": MIN_WEIGHTS_PARTICIPANTS,
                "donors_files": sorted(f"donors-{c}.json" for c in donors)}
    return donors, manifest


def validate_donors(doc: Any, source: str = "donors") -> None:
    if not isinstance(doc, dict) or doc.get("schema") != DONORS_SCHEMA:
        raise DonorError(f"{source}: not a {DONORS_SCHEMA} file")
    errs = [f"missing '{k}'" for k in ("participant_code", "input_sha256", "manifest_sha256",
                                       "protocol_hash", "generic_head_sha256", "heads", "shape")
            if k not in doc]
    if not errs:
        for lam in DONOR_LAMBDAS:
            blk = doc["heads"].get(lam_key(lam), {})
            for key in [f"donor_k{k}" for k in DONOR_KS] + ["pooled_lopo"]:
                if not _check_matrix(blk.get(key), doc["shape"]):
                    errs.append(f"head {lam_key(lam)}.{key} missing or malformed")
    errs.extend(f"free text at {p}" for p in find_free_text_generic(doc, WEIGHTS_STRING_KEYS))
    if errs:
        raise DonorError(f"{source}: " + "; ".join(errs[:10]))


def check_donors_for_export(donors: dict[str, Any], export_doc: dict[str, Any],
                            input_sha256: str, head_sha256: str) -> None:
    """Round 2 refuses a donors file that does not belong to exactly this export."""
    problems = []
    if donors["participant_code"] != export_doc["participant_code"]:
        problems.append(f"the donors file is for {donors['participant_code']}, but this export is "
                        f"{export_doc['participant_code']}")
    if donors["input_sha256"] != input_sha256:
        problems.append("this export is not the file used in round 1 (its SHA-256 differs). "
                        "Run round 2 on exactly the export you ran in round 1.")
    if donors["protocol_hash"] != protocol_hash():
        problems.append("the donors file was made under a different protocol than this tool")
    if donors["generic_head_sha256"] != head_sha256:
        problems.append("the donors file was made with a different generic head")
    if problems:
        raise DonorError("refusing round 2:\n  - " + "\n  - ".join(problems))


def write_donors(out_dir: Path, donors: dict[str, dict[str, Any]], manifest: dict[str, Any]) -> list[Path]:
    out_dir.mkdir(parents=True, exist_ok=True)
    paths = []
    for code, doc in donors.items():
        p = out_dir / f"donors-{code}.json"
        p.write_text(json.dumps(doc, sort_keys=True, separators=(",", ":")) + "\n", "utf-8")
        paths.append(p)
    (out_dir / "donors-manifest.json").write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n",
                                                  "utf-8")
    return paths
