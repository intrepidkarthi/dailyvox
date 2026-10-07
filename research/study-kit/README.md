# dailyvox-study

An open-source tool for a decentralised research study on [DailyVox](https://getdailyvox.com), a voice journal app for iPhone and Android.

The question: does a small emotion model adapted on *your own* labelled diary entries predict *your later* labels better than a generic model, and how many entries does that take? This is Experiment B of the DailyVox research programme (a per-person "K-curve"), implemented here so that **nobody ever has to send their diary to anyone**.

- Participants export their own labelled entries from the app.
- They run `dailyvox-study run` **on their own laptop**.
- They share the numbers-only `result.json` and, if they agree, `weights.json` (their fitted model weights, no text).
- A coordinator turns everyone's weights into per-person "donor" models (`dailyvox-study donors`); each participant runs the tool once more with theirs (round 2) and sends the new `result.json`.
- Anyone can pool result files with `dailyvox-study combine`.

Same tool and same protocol for iPhone and Android exports.

## Privacy model

What stays on the participant's laptop, always:

- the export file (diary text, labels, timestamps, entry ids);
- the sentence embeddings computed from the text (held in memory, never written to disk);
- every model fitted on the entries, except the ones in `weights.json`, which the participant chooses whether to send (see below).

What the result file contains: numbers only. Accuracies, win/tie/loss flags, counts of labels, counts of voice and typed entries, test-set sizes, permutation-null statistics, the participant code, platform, app version, consent version, tool and model versions, a software-environment line (Python and library versions, OS family) and a SHA-256 fingerprint of the export file. It never contains entry text, entry ids or entry dates. The tool checks this before writing anything:

- every string value must be one of a short list of metadata fields, and every object key must be a short identifier, so text cannot hide in the file;
- the serialised file is searched for every entry id, every entry timestamp and every three-word window of every entry; any hit aborts the run and nothing is written.

The `input_sha256` fingerprint lets a participant prove later which export produced their numbers. Nothing can be read back out of it.

### What weights.json is

The pre-registration's key control asks whether *your* model beats models built from *other* people's entries; if it does not, the lift is about how anyone talks into a phone, not about you. To run that control without moving anyone's text, `run` also writes `weights.json`:

- **Contents:** your small emotion models, fitted on your own early entries on your own laptop. There are 18 tables of 385 x 7 numbers: models after your first 5, 10 and 25 entries and after your whole adaptation window, at the registered lambda = 10 and its fallback lambda = 1. It also carries your participant code, a fingerprint of your export and version fields, and comes to about 650 KB.
- **Never in it:** words, entry ids, dates, or per-entry labels. The same leak guard as `result.json` runs on it before it is written.
- **It is derived from your journal.** Each table is the generic model plus a weighted sum of the numerical summaries (embeddings) of your own entries. Someone holding it and the public language model could probe which kinds of sentences your model links with each feeling, or test whether a given sentence looks like one of yours. It does not contain your text, and recovering readable text from it is not a known attack, but it is not nothing. **Sending it is your choice.**
- **Who sees it:** only the coordinator. No other participant ever receives your weights; each participant receives only averages over at least two other people.

## The two-round flow (with weights)

1. **Round 1 (participant):** `dailyvox-study run EXPORT.json` writes `result.json` and `weights.json`. Send both, or only `result.json` if you do not want to share weights.
2. **Coordinator:** collect the weights files, then:
   ```
   dailyvox-study donors weights/ -o donors/ [--p0 DV-XXXX-XX]
   ```
   This writes `donors-<code>.json` for each participant and `donors-manifest.json`. Each donors file holds heads computed **only from the other participants' weights**:
   - **donor:** the mean of the others' K-entry heads;
   - **pooledLOPO:** the mean of the others' whole-pool heads, fitted at lambda / d so that their average approximates one model fitted on everyone else's entries.

   It refuses mixed protocol versions or generic heads, duplicate participants, and fewer than 3 non-P0 participants (so no file ever contains one person's head). Send each participant **only their own** donors file.
3. **Round 2 (participant):** run the tool again on **the same export**:
   ```
   dailyvox-study run EXPORT.json --donors donors-DV-XXXX-XX.json -o result.json
   ```
   It refuses (exit 5) if the export is not byte-identical to the round-1 file or the donors file belongs to someone else. The new `result.json` (schema `dailyvox-study-result/2`, `round: 2`) adds the donor, donorPlusPrior and pooledLOPO accuracies. Send it.

`combine` runs Step 4 (H3b, personal vs donorPlusPrior) only when every analysed result is a round-2 result from the same donors build. Otherwise it reports Step 4 as unrunnable, says why, and applies the pre-registered fallback (claim-map row 3). How the head-averaging compares with the pre-registration's row-level refits is measured in `selfcheck` and written up in DEVIATIONS.md D4.

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
   This validates the export, computes everything, checks both output files for leaks and writes `result.json` and `weights.json`. Open them in a text editor if you want to see exactly what you are about to share.
3. **Send `result.json`** (and `weights.json` if you agree, see above) to the researcher. **Keep your export file** until round 2 is done: round 2 must run on exactly the same file. Then keep it private or delete it.

Run the tool **once, after you have finished labelling** (plus the round-2 run). Looking at your own numbers mid-study can change how you label, which would bend the measurement.

Exit codes: `0` ok; `2` the export is malformed (the message lists every problem with the entry number); `3` the export was made under a consent version this study does not accept (prereg rule X1); `4` combine or donors refused (duplicates, mixed versions, too few participants); `5` round 2 refused (the donors file does not match this export); `22` combine refused because the data freeze has not passed.

## The combine flow

```
dailyvox-study combine results/ -o report.md --json --freeze-date 2027-01-15
```

`combine` accepts files and directories. It refuses, and lists the offending files, when:

- two files share a `participant_code` or an `input_sha256` (someone sent twice; keep the last file received on or before the freeze date and remove the others);
- files differ in `protocol_hash`, `tool_version`, `embedding_model` or `generic_head_sha256` (numbers from different protocols are not the same quantity);
- synthetic and real results are mixed;
- round-2 results come from different donors builds (different manifest hashes);
- the results are real and `--freeze-date` is missing or in the future (exit code 22).

Options: `--p0 DV-XXXX-XX` tags the developer's own participant code, which the pre-registration excludes from every confirmatory test (rule X8). `--strata strata.json` maps participant codes to recruitment strata (`developer`, `known`, `existing_user`, `stranger`) so claim-map row 14 can be evaluated.

The report runs the pre-registered fixed sequence (Step 1 exact sign-flip permutation on per-person Delta-accuracy at K = 25; Step 1b per-person McNemar combined by Fisher; Step 2 win-rate with ties counted as losses against the exact binomial critical value; Step 3 personal vs prior-only; Step 4 personal vs donorPlusPrior with the retained / withdrawn / cannot-separate verdict, when round-2 results are in; Step 5 win-rate at K = 10), prints the registered outcome sentence from the claim map, and then the descriptive tier: the K-curve with bootstrap intervals, win/tie/loss against every comparator, the permutation-null diagnostic, reference lines, sensitivity analyses, and a per-platform (iOS vs Android) breakdown with typed and voice shares.

The sign-flip test enumerates all 2^N sign patterns when N <= 20 (about a million patterns) and otherwise uses a seeded Monte Carlo of 200,000 draws, and the report says which.

## What is computed (short version)

Per participant, entries in chronological order:

- **Split** (prereg section 4.2, rule S3): the test set is the last `m = min(35, max(10, n - 25))` entries; the adaptation pool is everything before it. Fewer than 35 labelled entries: not in the primary analysis (`status: excluded_too_few`); 30 to 34 still contribute to the K = 10 breadth test; fewer than 30: not analysed.
- **Features**: `sentence-transformers/all-MiniLM-L6-v2`, pinned to Hugging Face revision `1110a243fdf4706b3f48f1d95db1a4f5529b4d41`, CPU, one thread, seed 42, inputs sorted.
- **Generic head (K = 0)**: one-vs-rest ridge over [embedding, 1], trained on GoEmotions mapped to the 7 study labels, lambda chosen on a seeded 90/10 split inside GoEmotions. Shipped with the tool and hash-pinned so every participant uses the identical head.
- **Personal head**: `W = argmin ||XW - Y||^2 + lambda ||W - W_generic||^2` with lambda = 10 on the first K entries, K in {0, 5, 10, 25}. K = 0 is the generic head exactly.
- **Comparison arms that need only your data**: prior-only (bias refit), recency-matched last-K, persistence (two variants), majority-of-K, majority-of-pool, a stratified-chance reference, and a 1,000-shuffle permutation null.
- **Comparison arms built from other people's weights (round 2)**: donor, donorPlusPrior (your own bias refit over the donor head) and pooledLOPO, all scored on your own test entries.
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

Writes fake exports (alternating iOS and Android, about 20% typed entries) whose personas use everyday topics as private emotion cues, so personalisation has something to find. With `--shared-mapping`, every persona uses the same cues instead: a "register-only" signal that other people's models carry just as well, which is the case H3b must not mistake for personalisation. Every file is marked `"synthetic": true` and the flag carries into result, weights and donors files and reports.

`selfcheck` runs both kinds of cohort through the full two-round flow. On the reference machine H3b is retained for the personal-signal cohort (+8.4 pts, p = 0.002) and "cannot separate" for the register-only cohort (+0.7 pts, p = 0.30).

## App export fixtures

`tests/fixtures/` holds exports shaped exactly like each app's writer on branch `research/export-v1`: iOS (`JSONEncoder` with sorted keys, Apple's `" : "` separator, uppercase ids, unescaped slashes) and Android (contract key order, one entry per line, lowercase ids, its own string escaping), plus an empty Android export. `tests/fixtures/make_app_fixtures.py` regenerates them, and the tests check that `run` accepts all three.

## Troubleshooting

- **"export is not valid"**: the message lists each problem with its entry number. Most often the file was edited by hand, or is from an older app version. Export again from the app; do not edit the file.
- **"consent_version is ..."**: update the app, re-read and accept the current consent in Settings > Research, and export again.
- **The model download fails**: check your internet connection and run again. Behind a proxy, set `HTTPS_PROXY`. After the first successful download the tool works offline.
- **`status: excluded_too_few`**: fewer than 35 labelled entries. The file is still worth sending; it is counted and reported. Under 30 entries no `weights.json` is written.
- **Round 2 says "this export is not the file used in round 1"**: you exported again from the app, or the file changed. Round 2 needs the exact file from round 1. If it is gone, tell the coordinator; do not re-export.
- **A warning that an entry "has no real date"**: the app wrote a placeholder date (year 0001) for an entry that lost its date. It is analysed as your oldest entry. Mention it to the researcher.
- **Different numbers on two laptops**: tiny floating-point differences between machines can, rarely, flip a single prediction. Send the result from the machine you ran first; never cherry-pick between runs.
- **Tests offline**: `pytest -m "not model"` skips tests that need the embedding model.

## Licences

Code: MIT (this repository). Embedding model `all-MiniLM-L6-v2`: Apache-2.0. GoEmotions (Demszky et al., 2020): Apache-2.0; the shipped generic head is a derived artefact of it.

## Documents in this folder

- [STUDENT-GUIDE.md](STUDENT-GUIDE.md): one page for volunteers.
- [DEVIATIONS.md](DEVIATIONS.md): every difference from the Experiment B pre-registration, with section references, for re-registration.
- [CONSENT-CHANGES.md](CONSENT-CHANGES.md): DRAFT memo of what the consent must change for the result-file-only model.
