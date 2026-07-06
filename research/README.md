# DailyVox Research

DailyVox builds a private, fully on-device model of one person — the Digital Twin — from voice journal entries. Because the model runs where the data lives and nothing ever leaves the device, it can't be evaluated the way cloud products are: there is no server, no telemetry, no population dashboard. So we evaluate it the hard, honest way, and we publish the method.

This directory holds the public research artifacts.

## The measurement principles

- **Lift over a baseline, or it doesn't count.** A do-nothing model scores ~75% on naive agreement metrics for these tasks. Every number we report is lift over an explicit baseline (a constant-prior dummy, persistence/climatology for forecasting, a population mean for personality) plus a tracking correlation.
- **The metrics must be able to say no.** Our evaluation includes negative controls — shuffle the labels or the inputs and the metrics must collapse to chance. An evaluation that can only produce good news is broken.
- **Mirror, not oracle.** We measured whether the Twin can forecast mood; it cannot beat "tomorrow ≈ today," consistent with the affect-forecasting literature. DailyVox is therefore positioned as reflection and precedent, never mood prediction.

Background reading: [Body Twin — and where it honestly falls short of the plan](https://getdailyvox.com/blog/body-twin-v1-5-what-shipped).

## `twinkit/` — the reproducible instrument

A small, runnable, on-device replica of how the DailyVox Twin pipeline works (same Apple frameworks: `NaturalLanguage`, `FoundationModels`), plus a stylometric measurement layer (Burrows's Delta) for the question *"does the model act like me?"*. Runs entirely on a Mac; your data never leaves your machine and is never committed (see its `.gitignore`). An academic write-up using this instrument is in preparation.

## `pilot/` — the human fidelity pilot (participants wanted)

A small study measuring how well the Twin's trait estimates agree with a person's own self-report, on real diaries. If you use DailyVox and are willing to share your diary export privately with the researcher for scoring, see [`pilot/PARTICIPANT-SHEET.md`](pilot/PARTICIPANT-SHEET.md). Only numeric scores are ever published — never your words.
