# Play Console — Health apps declaration

> **Not used by v1.0.** The release declares no Health Connect permission, so this
> form is not submitted. Kept for when Body signals ship with a real opt-in.

Mandatory for **every** publishing request from an app that uses Health Connect,
new or update, regardless of store category. Play requires a justification per
data type with a clear user-facing benefit, and asks that only the minimum
necessary types be requested.

Everything below is what the code does, with the file and line that does it, so
a reviewer's follow-up question has an answer.

DailyVox reads **two** types — sleep and steps — **read-only**, and writes nothing back to Health
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

## Decided 2026-09-29: HRV and resting heart rate are not requested

Earlier builds also read heart rate variability and resting heart rate. Traced
through the code, those two were read, stored and shown beside the entry, and
**nothing computed with them** — `Entry.toChatEntry()` passes only `sleepHours`
and `stepsToday` to the engine. Play asks for the minimum necessary types, so
both were dropped from the manifest and from `BodySignals.PERMISSIONS` before
the first release.

| Type | Shown on the entry | Feeds a Twin insight |
|---|---|---|
| Sleep | yes | **yes** — `Insights.kt:97` |
| Steps | yes | **yes** — `Insights.kt:108` |

The `hrvMs` / `restingHrBpm` columns stay in the database (nullable, no
migration) so the entry screen still renders values recorded by earlier test
builds. Add the permissions back only when the engine correlates them, and
write the justification then — as analysis, because it will be.
