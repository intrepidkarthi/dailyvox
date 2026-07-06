#!/usr/bin/env python3
"""voiceprint.py — the measurement layer for "does it act like me?"

Tier-A of the discrimination ladder: stylometric distance (Burrows's Delta).
Your 18-year corpus is ground truth for YOU. This:
  1. fits a voiceprint from the corpus (most-frequent-word z-score model),
  2. reports your internal self-consistency  -- the FLOOR a Twin must fall within,
  3. scores any candidate text (e.g. Twin-generated) and reports whether it
     lands inside your voiceprint cloud.

Pure numpy/scipy -- no sklearn needed.

Usage:
  python3 voiceprint.py fit   <corpus.txt> [voiceprint.json]
  python3 voiceprint.py score <voiceprint.json> <candidate.txt>
  python3 voiceprint.py       <corpus.txt>          # fit + report
"""
import sys, re, json
import numpy as np

MFW_N = 150  # number of most-frequent words in the stylometric signature

def clean_text(p):
    """Strip frontmatter, markdown, and urls so only prose remains."""
    lines = [l for l in p.splitlines()
             if not re.match(r'^\s*(title|date|tags|slug|excerpt|original_url|description|draft|pubDate|---)\s*[:]?', l, re.I)
             and not l.strip().startswith('![')]
    body = "\n".join(lines)
    body = re.sub(r'https?://\S+', ' ', body)          # strip urls
    body = re.sub(r'[`*#>_\[\]\(\)]', ' ', body)        # strip md punctuation
    return body

def split_docs(raw):
    """Split the corpus dump into individual documents, strip frontmatter."""
    parts = re.split(r'={20,}\nFILE: .+?\n={20,}\n', raw)
    docs = [clean_text(p) for p in parts]
    docs = [d for d in docs if len(d.split()) >= 120]   # ignore stubs
    return docs if len(docs) > 1 else [clean_text(raw)]

def tokenize(text):
    return re.findall(r"[a-z]+(?:'[a-z]+)?", text.lower())

def doc_vector(tokens, vocab):
    n = len(tokens) or 1
    c = {}
    for t in tokens:
        if t in vocab: c[t] = c.get(t, 0) + 1
    return np.array([c.get(w, 0) / n for w in vocab])

def fit(corpus_path):
    raw = open(corpus_path, encoding='utf-8', errors='ignore').read()
    docs = split_docs(raw)
    toks = [tokenize(d) for d in docs]
    # most frequent words across the whole corpus
    freq = {}
    for ts in toks:
        for t in ts: freq[t] = freq.get(t, 0) + 1
    vocab = [w for w, _ in sorted(freq.items(), key=lambda x: -x[1])[:MFW_N]]
    M = np.vstack([doc_vector(ts, vocab) for ts in toks])     # docs x MFW (rel freq)
    mu = M.mean(axis=0); sd = M.std(axis=0); sd[sd == 0] = 1e-9
    Z = (M - mu) / sd                                         # z-scored
    self_dist = np.abs(Z).mean(axis=1)                        # each doc's distance to centroid
    model = {
        "mfw": vocab, "mu": mu.tolist(), "sd": sd.tolist(),
        "n_docs": len(docs), "total_words": int(sum(len(t) for t in toks)),
        "self_mean": float(self_dist.mean()), "self_std": float(self_dist.std()),
        "self_p50": float(np.percentile(self_dist, 50)),
        "self_p90": float(np.percentile(self_dist, 90)),
        "self_max": float(self_dist.max()),
    }
    return model, self_dist

def score(model, candidate_path):
    raw = clean_text(open(candidate_path, encoding='utf-8', errors='ignore').read())
    vocab = model["mfw"]; mu = np.array(model["mu"]); sd = np.array(model["sd"])
    z = (doc_vector(tokenize(raw), vocab) - mu) / sd
    dist = float(np.abs(z).mean())
    # percentile of this distance within the author's own self-distance cloud
    thr90 = model["self_p90"]
    pctl = 100.0 * (1.0 / (1.0 + np.exp(-(dist - model["self_mean"]) / (model["self_std"] + 1e-9))))
    verdict = "WITHIN your voiceprint" if dist <= thr90 else "OUTSIDE your voiceprint"
    return dist, pctl, verdict

def report(model, self_dist):
    print("=== VOICEPRINT (Burrows's Delta, %d most-frequent words) ===" % MFW_N)
    print(f"corpus: {model['n_docs']} documents, {model['total_words']:,} words")
    print(f"\nYour internal self-consistency (the FLOOR a Twin must fall within):")
    print(f"  mean distance-to-centroid : {model['self_mean']:.3f}")
    print(f"  std                       : {model['self_std']:.3f}")
    print(f"  median (p50)              : {model['self_p50']:.3f}")
    print(f"  p90 (acceptance threshold): {model['self_p90']:.3f}")
    print(f"  max (most atypical of you): {model['self_max']:.3f}")
    print(f"\nINTERPRETATION: any candidate text scoring <= {model['self_p90']:.3f} is")
    print(f"statistically indistinguishable from your own writing on this metric.")
    print(f"That threshold is the target for Twin-generated text (the personal Turing test).")

def main():
    a = sys.argv[1:]
    if not a:
        print(__doc__); return
    if a[0] == "score" and len(a) >= 3:
        model = json.load(open(a[1]))
        dist, pctl, verdict = score(model, a[2])
        print(f"candidate distance-to-your-centroid: {dist:.3f}")
        print(f"acceptance threshold (your p90)     : {model['self_p90']:.3f}")
        print(f"VERDICT: {verdict}")
        return
    corpus = a[1] if a[0] == "fit" and len(a) >= 2 else a[0]
    out = a[2] if (a[0] == "fit" and len(a) >= 3) else "voiceprint.json"
    model, self_dist = fit(corpus)
    json.dump(model, open(out, "w"), indent=2)
    report(model, self_dist)
    print(f"\nvoiceprint model -> {out}")

if __name__ == "__main__":
    main()
