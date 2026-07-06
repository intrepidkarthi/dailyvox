# twinkit — a local Mac replica of the DailyVox TwinEngine

This is a runnable, on-device reproduction of how DailyVox works, plus the
measurement layer for the research question *"does the model act like me?"*.
It runs entirely on your Mac and uses the **same Apple frameworks the app uses**
(`NaturalLanguage`, `FoundationModels`). No network, no cloud — same as the app.

## What maps to what

| TwinEngine layer (the app) | twinkit | Framework |
|---|---|---|
| 1. Extraction (per entry, write-time) | `twin ingest` | `NLTagger` (sentiment, `nameType`, `lexicalClass`), `NLEmbedding` |
| 2. Aggregation (nightly rollups) | `twin profile` | on-device data ops |
| 3. Query (ask the Twin) | `twin ask` | `FoundationModels` (~3B on-device LLM) |
| **Evaluation** (does it act like me?) | `measure/voiceprint.py` | Burrows's Delta (numpy) |

## Build

```sh
swiftc -O twin.swift -o twin        # one-time; or `swift twin.swift <cmd>` to run uncompiled
```

## Daily use — "the information we add every day"

Drop one text file per day into `entries/`, named by date:

```
entries/2026-06-15.txt      # paste (or transcribe) the day's journal entry
```

Then:

```sh
./twin ingest entries store.json          # extract features from every entry
./twin profile store.json                 # the aggregated Twin profile
./twin ask store.json "what's been weighing on me lately?"
```

`entries/` and all `*.json` are git-ignored — your data never leaves the machine
and is never committed.

## The measurement: are we "acting like me" yet?

The ladder (see the paper, §"What is not yet shown"):

1. **Tier A — stylometric distance (runnable today).** Build a voiceprint from your
   corpus; it reports the *floor* — how consistent you are with yourself. Any
   candidate text scoring under your p90 threshold is statistically
   indistinguishable from you on this metric.

   ```sh
   python3 measure/voiceprint.py fit ~/Desktop/all-articles.txt voiceprint.json
   python3 measure/voiceprint.py score voiceprint.json some_text.txt
   ```

2. **Tier B — discrimination + adaptation study (built: `measure/study.py`).**
   Many held-out passages of YOU vs many on-device-LLM passages, scored by
   stylometric distance and reported as AUC (1.0 = trivially told apart from you,
   0.5 = indistinguishable). It also contrasts *prompting a shared model* against a
   *model fit to your corpus* (a trigram, a runnable proxy for on-device LoRA).

   ```sh
   ./twin generate ~/Desktop/all-articles.txt /tmp/study/gen/t01 "a topic"   # repeat for many topics
   python3 measure/study.py ~/Desktop/all-articles.txt /tmp/study/gen
   ```

   Result (this corpus, n=100 held-out you / 28 prompted / 12 fit-to-you):
   - AUC(you vs **prompted shared model**) = **0.81** — reliably distinguishable
   - AUC(you vs **model fit to you**)      = **0.43** — indistinguishable

   i.e. prompting a shared model is *not* personalization; fitting to the person is.
   Caveats: the trigram reproduces the stylometric signature partly by construction
   and is not coherent prose (mechanism, not a twin); the metric is style, not
   decisions; single subject, modest N. Real on-device LoRA is the faithful next step.

3. **Tier C — blind opinion prediction (next).** Novel questions you've never written
   about; the Twin predicts your answer; compare to your real answer. Tests modeling,
   not memorization.

## Honest status

- Layers 1–3 reproduce DailyVox's *reading* of you, on-device, today.
- Tiers A and B are measured: prompting a shared model is reliably separable from
  you (AUC 0.81); a model fit to you is not (AUC 0.43). Tier C (deciding like you)
  and real on-device LoRA adaptation are the open work.
- Sounding like you (Tier A/B) is necessary, not sufficient, for *deciding* like
  you (the rung-4 "digital twin" claim). Don't conflate them.
