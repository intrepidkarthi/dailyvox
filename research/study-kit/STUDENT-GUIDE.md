# Taking part in the DailyVox study: a one-page guide

Thank you for volunteering. The question: can a tiny model that learns from *your* diary predict how *you* feel better than a generic model? Your diary never leaves your devices. You only send small files of numbers.

## 1. Install the app and turn on labelling

- iPhone: https://apps.apple.com/app/id6760454642
- Android: https://play.google.com/store/apps/details?id=com.dailyvox.app

Open **Settings > Research**, read the consent, and turn on **"Label my entries after recording"**. Note your participant code (like `DV-7K3Q-M9`). It is random and not linked to your name.

## 2. Journal for about two months

- About one entry a day, as you normally would. A minute is plenty.
- After each entry, tap how it felt: joy, sadness, anger, fear, surprise, disgust or neutral. There is no right answer. Label **in the moment**; skipping is fine.
- **Typed entries count**, for when you can't talk right now.
- Aim for **about 60 labelled entries**. Fewer than 35 still counts as taking part.

## 3. Export to your laptop

**Settings > Research > Export research data**, then save the file to your own laptop. It holds your entry text, so treat it like your diary. **Keep it until the study tells you you're done.**

## 4. Run the tool on your own laptop (round 1)

Python 3.10 or newer. In a terminal:

```
pipx install "git+https://github.com/intrepidkarthi/dailyvox.git#subdirectory=research/study-kit"
dailyvox-study run dailyvox-research-export.json
```

The first run downloads a public language model (about 90 MB); your text is never uploaded. **Never use Google Colab or any online notebook.** Run it once, when you've finished labelling.

This writes two files:

- **result.json**: numbers only. How well each model predicted your later entries, how many entries you labelled with each feeling, voice vs typed counts, your participant code, phone type, app and tool versions, and a fingerprint of your export.
- **weights.json**: your small personal models, as tables of numbers. They come from your entries but contain no words, dates or ids. They let the study compare your model with models built from other people. **Sending it is your choice.**

Neither file ever contains your words, entry dates, ids, audio, name or contacts. Open them in a text editor to check.

## 5. Send, then run once more (round 2)

1. Send **result.json** (and **weights.json** if you agree) to the researcher. **Never send the export.**
2. If you sent weights, you will later get a file called `donors-<your code>.json`. It holds models averaged from other participants. Run:
   ```
   dailyvox-study run dailyvox-research-export.json --donors donors-<your code>.json
   ```
   Use the **same export file** as in round 1; the tool refuses any other.
3. Send the new **result.json**. Then you're done, and you can delete the export.

## 6. Withdrawing

Stop any time, no reason needed. If you haven't sent anything, nothing has left your devices. If you have, email the researcher your participant code: your files are deleted, and the comparison models are rebuilt without you. A result that has already been published can't be un-published; the consent explains exactly what happens then.

Questions? Ask before you start: the contact address is in the consent screen.
