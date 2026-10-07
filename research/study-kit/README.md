# dailyvox-study

An open-source tool for a decentralised research study on [DailyVox](https://getdailyvox.com), a voice journal app for iPhone and Android.

The question: does a small emotion model adapted on *your own* labelled diary entries predict *your later* labels better than a generic model, and how many entries does that take? This is Experiment B of the DailyVox research programme (a per-person "K-curve"), implemented here so that **nobody ever has to send their diary to anyone**.

- Participants export their own labelled entries from the app.
- They run `dailyvox-study run` **on their own laptop**.
- They share **only** the numbers-only `result.json`.
- Anyone can pool result files with `dailyvox-study combine`.

Same tool and same protocol for iPhone and Android exports.

## Privacy model

What stays on the participant's laptop, always:

- the export file (diary text, labels, timestamps, entry ids);
- the sentence embeddings computed from the text (held in memory, never written to disk);
- every model fitted on the entries.

What the result file contains: numbers only. Accuracies, win/tie/loss flags, counts of labels, counts of voice and typed entries, test-set sizes, permutation-null statistics, the participant code, platform, app version, consent version, tool and model versions, a software-environment line (Python and library versions, OS family) and a SHA-256 fingerprint of the export file. It never contains entry text, entry ids or entry dates. The tool checks this before writing anything:

- every string value must be one of a short list of metadata fields, and every object key must be a short identifier, so text cannot hide in the file;
- the serialised file is searched for every entry id, every entry timestamp and every three-word window of every entry; any hit aborts the run and nothing is written.

The `input_sha256` fingerprint lets a participant prove later which export produced their numbers. Nothing can be read back out of it.

**Network use.** On first run the tool downloads the embedding model weights from huggingface.co (about 90 MB). Rebuilding the generic head (optional; `selfcheck` does it) downloads the public GoEmotions files from GitHub. The participant's text is never sent anywhere: it is only ever given to the local model. Hugging Face telemetry is switched off.

**Do not run this in Google Colab, Kaggle, a Jupyter hub, or any hosted notebook or cloud machine.** Uploading your export to such a service sends your diary to someone else's computer, which is exactly what this design exists to avoid. Run it on a laptop or desktop you control.

## Install

Python 3.10 or newer. CPU only; no GPU needed.

With pipx (recommended for participants):

```
pipx install "git+https://github.com/intrepidkarthi/dailyvox.git#subdirectory=research/study-kit"
```

Or in a virtual environment (for developers):

```
cd research/study-kit
python3 -m venv .venv
source .venv/bin/activate
pip install -e ".[test]"
```

Check it works (about a minute the first time, mostly the model download):

```
dailyvox-study selfcheck
```

## The participant flow (3 steps)

1. **Label and export.** In DailyVox, turn on Settings > Research > "Label my entries after recording", journal for about two months (about 60 labelled entries), then use Settings > Research > "Export research data" and save the file to your laptop. The plain-language version is [STUDENT-GUIDE.md](STUDENT-GUIDE.md).
2. **Run.**
   ```
   dailyvox-study run dailyvox-research-export.json -o result.json
   ```
   This validates the export, computes everything, checks the result for leaks and writes `result.json`. Open `result.json` in a text editor if you want to see exactly what you are about to share.
3. **Send only `result.json`** to the researcher. Keep your export file private (or delete it).

Run the tool **once, after you have finished labelling**. Looking at your own numbers mid-study can change how you label, which would bend the measurement.

Exit codes: `0` ok; `2` the export is malformed (the message lists every problem with the entry number); `3` the export was made under a consent version this study does not accept (prereg rule X1); `4` combine refused (duplicates or mixed versions); `22` combine refused because the data freeze has not passed.

## The combine flow

```
dailyvox-study combine results/ -o report.md --json --freeze-date 2027-01-15
```

`combine` accepts files and directories. It refuses, and lists the offending files, when:

- two files share a `participant_code` or an `input_sha256` (someone sent twice; keep the last file received on or before the freeze date and remove the others);
- files differ in `protocol_hash`, `tool_version`, `embedding_model` or `generic_head_sha256` (numbers from different protocols are not the same quantity);
- synthetic and real results are mixed;
- the results are real and `--freeze-date` is missing or in the future (exit code 22).

Options: `--p0 DV-XXXX-XX` tags the developer's own participant code, which the pre-registration excludes from every confirmatory test (rule X8). `--strata strata.json` maps participant codes to recruitment strata (`developer`, `known`, `existing_user`, `stranger`) so claim-map row 14 can be evaluated.

The report runs the pre-registered fixed sequence (Step 1 exact sign-flip permutation on per-person Delta-accuracy at K = 25; Step 1b per-person McNemar combined by Fisher; Step 2 win-rate with ties counted as losses against the exact binomial critical value; Step 3 personal vs prior-only; Step 4 is unrunnable in this design, see DEVIATIONS.md D4; Step 5 win-rate at K = 10), prints the registered outcome sentence from the claim map, and then the descriptive tier: the K-curve with bootstrap intervals, win/tie/loss against every comparator, the permutation-null diagnostic, reference lines, sensitivity analyses, and a per-platform (iOS vs Android) breakdown with typed and voice shares.

The sign-flip test enumerates all 2^N sign patterns when N <= 20 (about a million patterns) and otherwise uses a seeded Monte Carlo of 200,000 draws, and the report says which.

## What is computed (short version)

Per participant, entries in chronological order:

- **Split** (prereg section 4.2, rule S3): the test set is the last `m = min(35, max(10, n - 25))` entries; the adaptation pool is everything before it. Fewer than 35 labelled entries: not in the primary analysis (`status: excluded_too_few`); 30 to 34 still contribute to the K = 10 breadth test; fewer than 30: not analysed.
- **Features**: `sentence-transformers/all-MiniLM-L6-v2`, pinned to Hugging Face revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`, CPU, one thread, seed 42, inputs sorted.
- **Generic head (K = 0)**: one-vs-rest ridge over [embedding, 1], trained on GoEmotions mapped to the 7 study labels, lambda chosen on a seeded 90/10 split inside GoEmotions. Shipped with the tool and hash-pinned so every participant uses the identical head.
- **Personal head**: `W = argmin ||XW - Y||^2 + lambda ||W - W_generic||^2` with lambda = 10 on the first K entries, K in {0, 5, 10, 25}. K = 0 is the generic head exactly.
- **Comparison arms that need only your data**: prior-only (bias refit), recency-matched last-K, persistence (two variants), majority-of-K, majority-of-pool, a stratified-chance reference, and a 1,000-shuffle permutation null.
- Everything `combine` needs to apply the pre-registered lambda fallback and low-disagreement branches without anyone re-running anything.

## Reproducing the generic head

```
dailyvox-study build-generic-head -o head.json
```

Downloads `train.tsv`, `dev.tsv`, `emotions.txt` and `ekman_mapping.json` from `google-research/google-research` at commit `7951440944924ac61b6e2f9a2a3c715834005c40`, verifies each file's SHA-256, maps the 27 GoEmotions labels to Ekman's six plus neutral with the official mapping, keeps rows whose labels map to one class, drops rows under 5 words and duplicate texts, caps each class at 800 rows (seeded), embeds, selects lambda and fits. On the reference machine this gives 5,029 rows, lambda = 10, and weights SHA-256 `4e41f31191be15a04a4981907600b6ea0bd59216793e3f663ef422e69e3b1ef2`, the hash pinned in the tool. On another machine the last bits may differ; `selfcheck` reports whether the rebuilt head makes identical predictions.

## Synthetic data

```
dailyvox-study synth -o synthetic/ --participants 12
```

Writes fake exports (alternating iOS and Android, about 20% typed entries) whose personas use everyday topics as private emotion cues, so personalisation has something to find. Every file is marked `"synthetic": true` and the flag carries into result files and reports.

## Troubleshooting

- **"export is not valid"**: the message lists each problem with its entry number. Most often the file was edited by hand, or is from an older app version. Export again from the app; do not edit the file.
- **"consent_version is ..."**: update the app, re-read and accept the current consent in Settings > Research, and export again.
- **The model download fails**: check your internet connection and run again. Behind a proxy, set `HTTPS_PROXY`. After the first successful download the tool works offline.
- **`status: excluded_too_few`**: fewer than 35 labelled entries. The file is still worth sending; it is counted and reported.
- **Different numbers on two laptops**: tiny floating-point differences between machines can, rarely, flip a single prediction. Send the result from the machine you ran first; never cherry-pick between runs.
- **Tests offline**: `pytest -m "not model"` skips tests that need the embedding model.

## Licences

Code: MIT (this repository). Embedding model `all-MiniLM-L6-v2`: Apache-2.0. GoEmotions (Demszky et al., 2020): Apache-2.0; the shipped generic head is a derived artefact of it.

## Documents in this folder

- [STUDENT-GUIDE.md](STUDENT-GUIDE.md): one page for volunteers.
- [DEVIATIONS.md](DEVIATIONS.md): every difference from the Experiment B pre-registration, with section references, for re-registration.
- [CONSENT-CHANGES.md](CONSENT-CHANGES.md): DRAFT memo of what the consent must change for the result-file-only model.
