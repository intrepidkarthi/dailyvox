#!/usr/bin/env python3
"""study.py — the discrimination + adaptation study (the real benchmark).

Turns the single-passage probe into a measured result:

  Discrimination: held-out passages of YOU vs on-device-LLM passages, scored by
  stylometric distance, reported as AUC (1.0 = trivially distinguishable from you,
  0.5 = indistinguishable = passes the personal Turing test) with bootstrap CIs.

  Adaptation vs prompting: does a model FIT to you land inside your voiceprint
  where PROMPTING a shared model cannot? Adaptation arm = a word-trigram model
  fit to your corpus (a runnable proxy for on-device LoRA; see README caveat).

Method guards:
  - voiceprint is fit on a TRAIN split only; YOU is evaluated on a HELD-OUT split.
  - all evaluated passages are length-matched (~200-word chunks) to remove the
    short-text bias that inflates distance.

Usage:
  python3 study.py <corpus.txt> <gen_dir>
    gen_dir contains tNN/baseline.txt (generic) and tNN/styled.txt (prompt-styled).
"""
import sys, os, re, json, random, glob
import numpy as np
from voiceprint import clean_text, tokenize, doc_vector, split_docs

MFW_N = 150
CHUNK = 200          # words per evaluated passage (length-matched)
MIN_CHUNK = 140

def chunks(tokens, size=CHUNK):
    out = []
    for i in range(0, len(tokens), size):
        c = tokens[i:i+size]
        if len(c) >= MIN_CHUNK:
            out.append(c)
    return out

def fit_centroid(train_chunks):
    freq = {}
    for ts in train_chunks:
        for t in ts: freq[t] = freq.get(t, 0) + 1
    vocab = [w for w, _ in sorted(freq.items(), key=lambda x: -x[1])[:MFW_N]]
    M = np.vstack([doc_vector(ts, vocab) for ts in train_chunks])
    mu = M.mean(0); sd = M.std(0); sd[sd == 0] = 1e-9
    return vocab, mu, sd

def dist_tokens(ts, vocab, mu, sd):
    return float(np.abs((doc_vector(ts, vocab) - mu) / sd).mean())

def dists_from_texts(texts, vocab, mu, sd):
    out = []
    for t in texts:
        toks = tokenize(clean_text(t))
        for c in chunks(toks):
            out.append(dist_tokens(c, vocab, mu, sd))
    return np.array(out)

def auc_separable(you, ai):
    """P(you more you-like than ai) = P(you_dist < ai_dist). 0.5 = indistinguishable."""
    you = np.asarray(you); ai = np.asarray(ai)
    wins = 0.0
    for y in you:
        wins += np.sum(ai > y) + 0.5 * np.sum(ai == y)
    return wins / (len(you) * len(ai))

def boot_ci(x, n=2000):
    x = np.asarray(x); idx = np.arange(len(x))
    means = [x[np.random.choice(idx, len(x), replace=True)].mean() for _ in range(n)]
    return float(np.percentile(means, 2.5)), float(np.percentile(means, 97.5))

# ---- word-trigram "adaptation" model (proxy for on-device LoRA) ----
def train_trigram(train_tokens):
    model = {}
    for i in range(len(train_tokens) - 2):
        k = (train_tokens[i], train_tokens[i+1])
        model.setdefault(k, []).append(train_tokens[i+2])
    return model

def gen_trigram(model, keys, seed, n_words=CHUNK + 40):
    rnd = random.Random(seed)
    k = keys[rnd.randrange(len(keys))]
    out = [k[0], k[1]]
    for _ in range(n_words):
        nxts = model.get((out[-2], out[-1]))
        if not nxts:
            k = keys[rnd.randrange(len(keys))]; out += [k[0], k[1]]; continue
        out.append(rnd.choice(nxts))
    return " ".join(out)

def main():
    corpus, gen_dir = sys.argv[1], sys.argv[2]
    raw = open(corpus, encoding='utf-8', errors='ignore').read()
    docs = split_docs(raw)
    # deterministic train/test split: every 5th doc -> test
    train_docs = [d for i, d in enumerate(docs) if i % 5 != 0]
    test_docs  = [d for i, d in enumerate(docs) if i % 5 == 0]

    train_chunks = [c for d in train_docs for c in chunks(tokenize(d))]
    test_chunks  = [c for d in test_docs  for c in chunks(tokenize(d))]
    vocab, mu, sd = fit_centroid(train_chunks)

    # classes
    you = np.array([dist_tokens(c, vocab, mu, sd) for c in test_chunks])           # held-out YOU
    self_train = np.array([dist_tokens(c, vocab, mu, sd) for c in train_chunks])   # reference
    generic = dists_from_texts([open(f).read() for f in sorted(glob.glob(f"{gen_dir}/*/baseline.txt"))], vocab, mu, sd)
    styled  = dists_from_texts([open(f).read() for f in sorted(glob.glob(f"{gen_dir}/*/styled.txt"))],   vocab, mu, sd)

    # adaptation arm: trigram fit to TRAIN, generate matched passages
    train_tokens = [t for d in train_docs for t in tokenize(d)]
    tri = train_trigram(train_tokens); keys = list(tri.keys())
    adapt_texts = [gen_trigram(tri, keys, seed=1000 + i) for i in range(12)]
    adapt = dists_from_texts(adapt_texts, vocab, mu, sd)

    classes = {"YOU (held-out, real)": you, "ADAPT (model fit to you)": adapt,
               "PROMPT styled (shared model)": styled, "PROMPT generic (shared model)": generic}

    print("=" * 68)
    print("DISCRIMINATION + ADAPTATION STUDY")
    print(f"corpus: {len(docs)} docs | train {len(train_chunks)} chunks / test {len(test_chunks)} chunks | {MFW_N} MFW, {CHUNK}-word passages")
    print("=" * 68)
    print(f"\n{'class':<32}{'n':>4}{'mean dist':>11}{'  95% CI':>16}")
    print("-" * 68)
    results = {}
    for name, x in classes.items():
        lo, hi = boot_ci(x) if len(x) > 2 else (float('nan'), float('nan'))
        print(f"{name:<32}{len(x):>4}{x.mean():>11.3f}   [{lo:.3f}, {hi:.3f}]")
        results[name] = {"n": int(len(x)), "mean": float(x.mean()), "ci": [lo, hi]}
    print(f"\n(reference: train self-distance mean {self_train.mean():.3f})")

    print(f"\n{'discrimination: YOU vs ...':<34}{'AUC':>8}   interpretation")
    print("-" * 68)
    for name, x in classes.items():
        if name.startswith("YOU"): continue
        a = auc_separable(you, x)
        tag = "indistinguishable" if a < 0.65 else ("separable" if a < 0.85 else "trivially separable")
        print(f"{'YOU vs ' + name:<34}{a:>8.3f}   {tag}")
        results.setdefault("auc", {})[name] = float(a)

    pooled_ai = np.concatenate([generic, styled])
    a_prompt = auc_separable(you, pooled_ai)
    print(f"\nHEADLINE  AUC(YOU vs prompted shared model) = {a_prompt:.3f}")
    print(f"          AUC(YOU vs model fit to you)      = {auc_separable(you, adapt):.3f}")
    results["headline"] = {"you_vs_prompt": float(a_prompt), "you_vs_adapt": float(auc_separable(you, adapt))}

    json.dump(results, open(f"{gen_dir}/../results.json", "w"), indent=2)
    print(f"\nresults -> {os.path.normpath(gen_dir + '/../results.json')}")

if __name__ == "__main__":
    main()
