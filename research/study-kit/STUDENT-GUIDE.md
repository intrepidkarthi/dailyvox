# Taking part in the DailyVox study: a one-page guide

Thank you for volunteering. This study asks a simple question: can a tiny model that learns from *your* diary predict how *you* feel better than a generic model can? Your diary never leaves your devices. You only ever send a small file of numbers.

## 1. Install the app

- iPhone: https://apps.apple.com/app/id6760454642
- Android: https://play.google.com/store/apps/details?id=com.dailyvox.app

The app is free and works fully offline.

## 2. Read the consent, then turn on research labelling

Open **Settings > Research**, read the consent, and turn on **"Label my entries after recording"**. Note the participant code shown there (it looks like `DV-7K3Q-M9`). It is random and not linked to your name.

## 3. Journal for about two months

- Record roughly one entry a day, the way you normally would. About a minute is plenty.
- Right after each entry, tap how it felt: joy, sadness, anger, fear, surprise, disgust or neutral. There is no right answer and nothing to "do well" at.
- Label **in the moment**, not later. Skipping is always fine.
- **Typed entries count.** If you can't talk right now (on a bus, in a library), type the entry instead.
- Aim for **about 60 labelled entries**. Fewer than 35 still counts as taking part, but cannot go into the main comparison.

## 4. Export your data to your laptop

When you reach about 60 labelled entries, go to **Settings > Research > Export research data** and save the file to your own laptop (AirDrop, a USB cable, or saving to Files and copying it over). The export holds your entry text, so treat it like your diary.

## 5. Run the tool on your own laptop

You need Python 3.10 or newer. In a terminal:

```
pipx install "git+https://github.com/intrepidkarthi/dailyvox.git#subdirectory=research/study-kit"
dailyvox-study run dailyvox-research-export.json -o result.json
```

The first run downloads a small public language model (about 90 MB). Your text is never uploaded.

**Do not use Google Colab, Kaggle or any online notebook or cloud computer.** That would upload your diary to someone else's machine. Use your own laptop.

Run it once, when you have finished labelling. Peeking at your numbers part-way through can change how you label.

## 6. Send ONLY result.json

Email or message **only `result.json`** to the researcher. Never send the export file.

**What is in result.json:** numbers. How accurate each model was on your later entries, win or loss flags, how many entries you labelled with each feeling, how many were voice and how many typed, your participant code, phone platform (iPhone or Android), app version, the tool's version, software versions on your laptop, and a fingerprint of your export file.

**What is never in it:** your words, any sentence or phrase from your entries, entry dates or times, entry ids, audio, your name, email or contacts. The tool checks this before it writes the file, and you can open `result.json` in any text editor to see for yourself.

## 7. Withdrawing

You can stop at any time without giving a reason. If you have not sent anything, just stop: nothing has left your devices. If you have sent `result.json`, email the researcher with your participant code and ask for it to be deleted. If the pooled analysis has already been published, a published total cannot be un-published; the consent explains exactly what happens in that case.

Questions? Ask before you start: the contact address is in the consent screen.
