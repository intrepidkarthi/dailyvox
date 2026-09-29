# Play Console — Health apps declaration

Mandatory for **every** publishing request from an app that uses Health Connect,
new or update, regardless of store category. Play requires a justification per
data type with a clear user-facing benefit, and asks that only the minimum
necessary types be requested.

Everything below is what the code does, with the file and line that does it, so
a reviewer's follow-up question has an answer.

DailyVox reads **four** types, **read-only**, and writes nothing back to Health
Connect. Nothing is requested until the user turns Body signals on in Settings;
the permissions are declared in the manifest but not held until then.

---

## Sleep — `android.permission.health.READ_SLEEP`

**Paste this:**

```
DailyVox is a voice journal. With the user's permission it reads last night's
sleep duration so it can tell the user whether their own sleep is related to how
they write about their day.

The app reads sleep sessions from 18:00 the previous evening to the present and
sums their duration. That number is shown on the entry the user recorded that
day ("Slept 7.2 hours"), and is used to compute a personal insight comparing the
sentiment of entries written after seven or more hours of sleep against those
written after less — shown only once there are at least three nights on each
side, so the app never draws a conclusion from too little data.

The data is read on the device, stored only on the device, and is never
transmitted. The app holds no internet permission at all. Body signals are
entirely optional and the rest of the app is unaffected if they stay off.
```

*Where:* window in `body/BodySignals.kt`; insight in the engine's
`Insights.kt:97` — split at a fixed 7.0 hours, `minPerSide = 3`, rendered as
"After seven or more hours you write %+.2f; under seven, %+.2f."

---

## Steps — `android.permission.health.READ_STEPS`

**Paste this:**

```
DailyVox is a voice journal. With the user's permission it reads the user's step
count for the day so it can tell them whether how much they moved is related to
how they write about their day.

The app aggregates total steps from midnight to the present. The figure is shown
on the entry recorded that day ("12,431 steps today"), and is used to compute a
personal insight comparing the sentiment of entries on the user's more active
days against their quieter ones. The comparison is made against the user's OWN
median step count rather than a generic target, because the question is how this
person's own movement relates to their own writing. It is shown only once there
are at least four days on each side.

The data is read on the device, stored only on the device, and is never
transmitted. The app holds no internet permission at all. Body signals are
entirely optional and the rest of the app is unaffected if they stay off.
```

*Where:* `StepsRecord.COUNT_TOTAL` aggregate in `body/BodySignals.kt`; insight in
`Insights.kt:108`, split at the user's own median, `minPerSide = 4`.

---

## Heart rate variability — `android.permission.health.READ_HEART_RATE_VARIABILITY`

**Paste this:**

```
DailyVox is a voice journal. With the user's permission it reads the user's
morning heart rate variability (RMSSD) and shows it alongside the journal entry
they recorded that day, so that when they read the entry back they can see the
physiological context they wrote it in.

Only morning readings are used — from midnight to 11:00 — because HRV varies
with posture, food and activity through the day, so a whole-day average would
not be a meaningful figure to show anyone. The value appears on the entry as
"HRV 48 ms this morning" and nowhere else.

The data is read on the device, stored only on the device, and is never
transmitted. The app holds no internet permission at all. Body signals are
entirely optional and the rest of the app is unaffected if they stay off.
```

---

## Resting heart rate — `android.permission.health.READ_RESTING_HEART_RATE`

**Paste this:**

```
DailyVox is a voice journal. With the user's permission it reads the user's
resting heart rate for the day and shows it alongside the journal entry they
recorded, so that when they read the entry back they can see the physiological
context they wrote it in.

The app takes the most recent resting heart rate reading recorded that day. The
value appears on the entry as "Resting pulse 58 bpm" and nowhere else.

The data is read on the device, stored only on the device, and is never
transmitted. The app holds no internet permission at all. Body signals are
entirely optional and the rest of the app is unaffected if they stay off.
```

---

## Read this before submitting: two of the four are weaker than the code claims

`BodySignals.kt` says it reads "only the four fields the Twin actually
correlates against", and `DATA_SAFETY.md` repeated it. **That is true of sleep
and steps and false of the other two.** Traced through the code:

| Type | Shown on the entry | Feeds a Twin insight |
|---|---|---|
| Sleep | yes | **yes** — `Insights.kt:97` |
| Steps | yes | **yes** — `Insights.kt:108` |
| HRV | yes | **no** |
| Resting heart rate | yes | **no** |

`Entry.toChatEntry()` hands the engine `sleepHours` and `stepsToday`. It does
not pass `hrvMs` or `restingHrBpm`, and no engine file references them. They are
read, stored and displayed — and nothing computes with them.

That is still a genuine user-facing benefit and the justifications above state
it accurately rather than overselling it. But Play asks for the **minimum
necessary** data types, and this is a decision worth making deliberately rather
than by default:

- **Keep both.** Defensible: the user sees the number next to their entry, which
  is a real feature and is what the wording above claims. Costs two extra data
  types in the health review.
- **Drop both.** Removes two types from the declaration and shortens the
  permission list the store listing invites people to inspect. Costs the two
  rows on the entry screen. Wiring HRV into the engine later would mean asking
  for the permission again.
- **Wire them up first.** HRV against journal sentiment is the most interesting
  of the four for this product and the correlation code already exists —
  `Insights.split()` is generic. This turns the weakest justification into the
  strongest.

Nothing here is blocking. But do not submit the form describing HRV as
something the Twin analyses, because it currently does not.
