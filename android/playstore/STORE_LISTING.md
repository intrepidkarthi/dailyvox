# DailyVox — Google Play listing

**Status: DRAFT. The app is not released and this listing has not been submitted.**
Nothing here may be published while the recogniser-capitalisation assumption is
untested on physical hardware (see `SUBMISSION_CHECKLIST.md`).

---

> **Do not hand-count these fields.** Every count in this directory was wrong,
> in three documents at once, and they disagreed with each other — the full
> description was out by 830 characters. Run `python3 playstore/verify.py`
> instead; it reads the copy below and exits 1 on any overrun.
>
> The full description currently sits about 59 characters under the 4,000 limit.
> That is a real constraint: adding a sentence means removing one.

## App name (30 characters max)

**Paste this:**

```
DailyVox: Private Voice Diary
```

*Why:* "Private" earns its slot — it is the search term this audience actually
types, and it is the one claim the listing can prove rather than assert.

## Short description (80 characters max)

**Paste this:**

```
Voice journal with no internet permission. Check it yourself in app info.
```

*Why:* Play shows this above the fold, before anyone taps *Read more*, so it
matters more here than the iOS subtitle does. The iOS subtitle is "Private
On-Device Audio Diary" — three adjectives and a noun, and every competitor can
write that sentence. **This one names a verifiable fact and invites the reader
to go and check it**, which only an app with an empty permission list can say.

> The paragraph above is commentary and has been mistaken for the field itself,
> because it used to sit between the heading and the fence. It is 112 characters
> and would be rejected at upload. **Only ever paste what is inside the fence** —
> and run `python3 playstore/verify.py`, which prints the exact string it
> measured so there is nothing left to misread.

## Full description (4000 characters max)

**Paste this:**

```
Speak for forty-two seconds. That's the whole app.

DailyVox turns what you say into a private journal, and builds a Digital Twin
that learns who you are from your own words. All of it happens on this phone.

WHY YOU CAN BELIEVE THAT

Most journal apps promise privacy. This one can be checked in ten seconds,
without trusting a word of this page:

• Open Android Settings → Apps → DailyVox → Permissions.
• There is no internet permission there. Not "unused" — absent.
• An app cannot use a permission it does not hold. Not through a bug, not
  through an update, not if someone forks it.

Then turn on airplane mode and record an entry. Everything still works, because
there is no server to be cut off from.

The complete list of what DailyVox asks for:
• Microphone — to hear you
• Notifications — the optional evening reminder, and the recording timer
• Vibration — haptics
• Biometrics — the optional app lock
• Health Connect — only if you switch on Body signals, read-only, four types

That's it. No analytics SDK. No crash reporter. No account. No sign-up. No ads.
No subscription. No "free trial" that becomes a bill.

Android's own cloud backup is switched OFF inside the app, on purpose. Left at
its default it would copy your journal and recordings to Google Drive — by the
system, without this app needing any permission. We turned it off so "nothing
leaves this phone" stays true rather than nearly true.

Transcription is the same trap, and it is why DailyVox needs Android 13 or
newer. The ordinary speech recogniser can send your audio to Google — again by
another app, needing no permission from this one. Android 13 added a recogniser
guaranteed to stay on the phone, and it is the only one DailyVox will use. With
no offline language pack installed it says so and stops, rather than
transcribing over a network.

YOUR DIGITAL TWIN

As you speak, the Twin quietly builds a picture of you:

• The people, places and things you mention, and how they connect
• How your mood moves across days, weeks and times of day
• How you sound — pace, pitch, and where you pause
• Patterns worth noticing, and only when there is enough evidence to say so

Every insight is computed from your own entries. If there isn't enough there
yet, DailyVox says so instead of inventing something.

ASK YOUR TWIN

Ask what it has actually read. Answers come from real numbers in your own
journal, and each one names the entries it drew from, so you can check it.

There is no free-form chatbot, and that is a decision rather than a missing
feature. A model small enough to run on every Android phone would guess, and a
Twin that guesses about your life is worse than one that stays quiet.

WHAT ELSE IS IN IT

• Search your journal by what you meant, or by voice
• Play back the original recording of any entry
• See exactly what the Twin filed from each entry, and correct it
• Tell it how the day actually felt — your word, not its guess
• Home screen widget and a Quick Settings tile for one-tap recording
• Optional evening reminder, with no streak guilt if you miss a night
• App lock with your fingerprint, face, or device PIN
• Photos attached to entries, kept on this phone
• Export as PDF or readable JSON, and an encrypted backup you control
• Your backup opens on an iPhone too — the format is identical on both

Body signals are optional. With your permission DailyVox reads sleep, morning
HRV, resting heart rate and steps from Health Connect, so the Twin can tell you
whether a rough night actually changes how YOU write — a question only your own
entries can answer.

FREE, AND OPEN

Free forever. No paid tier exists. The app's source code is public — how it
records, stores and exports your words can be read by anyone. The Twin's
analysis engine stays closed, but it runs inside an app that holds no internet
permission.

DailyVox is a twenty-year diary habit turned into software, by someone who
wanted to keep writing without handing it to anyone.
```

## Categorisation

| Field | Value |
|---|---|
| Category | Health & Fitness |
| Tags | see below — **pick 5 in Console, do not paste these** |
| Contains ads | **No** |
| In-app purchases | **No** |
| Content rating | Everyone (see `CONTENT_RATING.md`) |

### Category

**Health & Fitness.** Worth recording that this is a pure discovery choice and
carries no compliance weight: the Health apps declaration form is mandatory for
**every** app that uses Health Connect, whatever category it sits in. Picking
Lifestyle would not avoid the health review, and Health & Fitness is where
Play's own definition puts journaling, mood and daily-routine tracking.

### Tags

Play allows **five**, chosen from its own fixed list of roughly 159 — you pick
them from a picker in Console, you cannot invent them. The previous version of
this file listed three:

> ~~Journal, Mental wellness, Productivity~~

Three problems. Only three of five slots were used, so two free discovery slots
were being thrown away. **Productivity** is a Play *category* name, and Play's
guidance calls it one of the tags too generic to be worth a slot (alongside
Tools, Utilities and Lifestyle). And the strings were written as prose, which
cannot be pasted anywhere — the picker decides the exact wording.

So this is a **priority order to match against the picker**, not a list to copy.
Take the closest string Console actually offers, top down, until five are used:

| # | Want | Why it earns a slot |
|---|---|---|
| 1 | Journaling / Journal / Diary | The core noun. Whichever spelling the picker has |
| 2 | Mental health / Mental wellness | The segment buyers browse, and where the Twin belongs |
| 3 | Self improvement | Confirmed to exist as a Play tag |
| 4 | Mood tracker / Mood tracking | A real shipped feature — valence, the 14-day curve |
| 5 | Voice / Audio / Dictation | The actual differentiator, if any such tag exists |

Avoid: Productivity, Lifestyle, Tools, Utilities — Play treats them as noise.

**Do not** take a tag the app cannot back. Meditation, Therapy, Fitness and
Sleep tracking are all adjacent and all wrong: DailyVox reads sleep, it does not
track it, and a tag that oversells is a refund and a one-star, not a download.
