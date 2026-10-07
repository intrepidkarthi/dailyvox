"""Sentence embeddings: one open model, pinned, CPU-only, deterministic.

WHY one pinned open model: in the decentralised design every participant
computes features on their own laptop. If two people used different models
(or different revisions of the same model) their numbers would not be
comparable, and the study would quietly become a different study per laptop.
So the model id AND its exact Hugging Face commit are frozen in protocol.py,
recorded in every result, and checked by `combine`.

WHY CPU, one thread, sorted inputs: GPU kernels and multi-threaded reductions
can change the last bits of a float between runs. Sorting the unique texts
and batching in that fixed order makes batch composition (and therefore
padding) independent of the order entries arrive in. Accuracies are discrete,
so last-bit drift between DIFFERENT machines almost never flips a prediction,
but on the same machine a re-run is byte-identical (tested).

Privacy: the model weights are downloaded once from huggingface.co; the
participant's text is only ever passed to the local model and never sent
anywhere. We set HF_HUB_DISABLE_TELEMETRY and, after the first download, the
model loads from the local cache.
"""

from __future__ import annotations

import os
import random
from functools import lru_cache
from typing import Sequence

import numpy as np

from .protocol import (
    EMBEDDING_BATCH_SIZE, EMBEDDING_DIM, EMBEDDING_MODEL_ID, EMBEDDING_MODEL_REVISION, SEED,
)

os.environ.setdefault("HF_HUB_DISABLE_TELEMETRY", "1")
os.environ.setdefault("TOKENIZERS_PARALLELISM", "false")


def _set_determinism() -> None:
    import torch

    random.seed(SEED)
    np.random.seed(SEED)
    torch.manual_seed(SEED)
    torch.set_num_threads(1)
    torch.use_deterministic_algorithms(True)


@lru_cache(maxsize=1)
def load_model():
    """Load the pinned model on CPU. Downloads on first use only."""
    _set_determinism()
    from sentence_transformers import SentenceTransformer

    model = SentenceTransformer(EMBEDDING_MODEL_ID, revision=EMBEDDING_MODEL_REVISION,
                                device="cpu")
    model.eval()
    return model


def embed_texts(texts: Sequence[str]) -> np.ndarray:
    """Embed texts in a fixed (sorted, de-duplicated) order; return rows in input order.

    Output: float64 array (len(texts), 384), L2-normalised by the model's own
    Normalize layer.
    """
    if len(texts) == 0:
        return np.zeros((0, EMBEDDING_DIM), dtype=np.float64)
    import torch

    model = load_model()
    _set_determinism()
    unique = sorted(set(texts))
    with torch.inference_mode():
        vecs = model.encode(unique, batch_size=EMBEDDING_BATCH_SIZE, convert_to_numpy=True,
                            normalize_embeddings=True, show_progress_bar=False)
    vecs = np.asarray(vecs, dtype=np.float64)
    if vecs.shape[1] != EMBEDDING_DIM:
        raise RuntimeError(f"embedding dimension {vecs.shape[1]} != {EMBEDDING_DIM}; "
                           "wrong model revision?")
    index = {t: i for i, t in enumerate(unique)}
    return vecs[[index[t] for t in texts]]
