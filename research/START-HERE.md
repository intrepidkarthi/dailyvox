# Start here: contributing to DailyVox research

You are joining a small research programme with one goal: **a personal digital twin**, a model of one person learned only from their own journal, running entirely on their own phone, with nothing sent to a server. This page tells you what you would work on, what your contribution produces, how that becomes published research, and how it moves the twin forward.

Read this first, then the [research page](https://getdailyvox.com/research) and the [paper](https://getdailyvox.com/paper/measuring-a-model-of-one.pdf).

---

## The two questions

1. **Does the phone change what the twin learns?** iPhone and Android turn speech into text with different on-device recognisers. If one drops words, mangles names or does not capitalise them, the twin learns less about the people in someone's life on that phone.
2. **Does a model of *you* beat a generic model *on you*?** If a small model adapted on a person's own labelled entries predicts their own later feelings better than a model trained on strangers, and better than a model adapted on *other* people's journals, then on-device personal models are worth building. If not, that is a finding too.

Everything below serves one of these two questions.

## Where things stand

| Piece | Status |
|---|---|
| Apps (iPhone 1.12, Android 1.1) | Live. Self-labelling of entries exists on both |
| Research export, same format on both apps (`dailyvox-research-export/1`) | Built, ships in the next app updates |
| Analysis tool, [`study-kit/`](study-kit/) (`dailyvox-study`) | Built: runs on the participant's own laptop, writes numbers only |
| Pre-registration | Draft. Being revised for the laptop design ([`study-kit/DEVIATIONS.md`](study-kit/DEVIATIONS.md)); frozen only after academic review |
| Consent for the laptop design | Draft ([`study-kit/CONSENT-CHANGES.md`](study-kit/CONSENT-CHANGES.md)); needs ethics review |
| Ethics approval | **Not yet.** Until it exists, nobody outside the core team is recruited |

## How the study works (the privacy model)

No one in this programme ever reads anyone else's journal.

1. **Journal.** Use DailyVox on iPhone or Android for about two months. After each entry, tap how the day actually felt. Aim for about 60 labelled entries. Typed entries count ("I can't talk right now").
2. **Export.** Settings › Research › Export research data. The file stays on your device until you move it to your own laptop.
3. **Round 1.** Run `dailyvox-study run export.json` on your own laptop (never in Google Colab or any online notebook). It writes two files of numbers: `result.json` and `weights.json` (your personal model's weights). Send only those two.
4. **Round 2.** A few days later you receive a `donors` file built from everyone else's weights. Run the tool again with it; it scores those models on your own entries and writes an updated `result.json`. Send that.
5. **Combine.** Results are combined into one report: does the personal model beat the generic one, and does it beat models adapted on other people, across everyone, on iPhone and on Android.

The second round is what lets the study say the model learned *you* and not just how people talk in a spoken journal.

## Roles

**Everyone: be participant one.** Journal for two months like any participant. You cannot run a study well that you have not been through.

### Study 1: "Does the phone change the twin?"
- **You do:** write 30 to 40 short diary-style scripts that mention people and places; read them aloud into DailyVox on 3 to 5 phones (Pixel, Samsung, OnePlus, iPhone); score each transcript against its script: word error rate, names caught, names capitalised.
- **You deliver:** the scripts, a scoring notebook run on your own machine, a results table per phone, and a 4 to 6 page write-up.
- **Time:** about 6 weeks. Only team members recording themselves.
- **It becomes:** the cross-platform section of a methods paper on evaluating a personal model without data leaving the device.

### Study 2: "Does a model of you beat the generic one?"
- **You do:** weeks 1 to 4, test `dailyvox-study` on synthetic data and try to break it (see [`study-kit/README.md`](study-kit/README.md)); then, after ethics approval, help recruit 15 to 20 volunteers, support them through two months and both rounds, and collect their result and weight files. Then run `combine` once, exactly as pre-registered.
- **You deliver:** a tool test report, the recruitment and support log, the combined results report.
- **Time:** about 16 weeks.
- **It becomes:** a registered report: the journal accepts the design before the data exists, so the result is published whether it is positive, negative or "we could not tell".

## Publication

| Output | Target |
|---|---|
| Study 2, registered report | Peer Community In Registered Reports, then Royal Society Open Science or Peer Community Journal; alternative: JMIR Formative Research |
| Study 1 and the evaluation method | ACM Transactions on Interactive Intelligent Systems; alternative: PeerJ Computer Science |

**Credit.** Contributions are recorded with the CRediT roles (investigation, data curation, formal analysis, software, writing). Anyone who meets the journal's authorship criteria is eligible for co-authorship, agreed in writing before work starts; the principal investigator makes the final call. Everyone else is acknowledged by name.

There is no funding and nothing to pay anyone. What you get is a real app as a testbed, a working instrument, open questions, and a publication path.

## How it reaches the twin

- Study 1 decides whether the twin works on Android phones at all, and on which ones.
- Study 2 decides whether personal on-device models are worth building: the core assumption of the whole twin.
- The method (measure on the device, share only numbers) becomes how every future twin feature is evaluated without collecting anyone's journal.

## Rules

1. Never handle anyone else's journal text. Only result and weight files move.
2. Never run the tool in Colab or any hosted notebook.
3. No recruiting outside the team until ethics approval and the new consent are in place.
4. The analysis runs once, after data collection ends. No peeking, no tuning.
5. Every number in a write-up points to the file or script it came from.

## First week

1. Install DailyVox ([App Store](https://apps.apple.com/app/id6760454642) · [Google Play](https://play.google.com/store/apps/details?id=com.dailyvox.app)) and record your first labelled entry.
2. Read the research page, the paper, and [`study-kit/README.md`](study-kit/README.md).
3. Install the tool and run `dailyvox-study selfcheck`.
4. Pick Study 1 or Study 2 and write one paragraph on what you think could go wrong with it.
5. Email hello@getdailyvox.com with that paragraph.
