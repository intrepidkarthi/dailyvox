# What every permission is for, and where the app uses it

Nine permissions, and this is the file that answers "why do you need that?" for
each. The store listing invites people to read the permission list in app info,
so each line here is traced to the code that uses it rather than described.

Regenerate the list itself from the artifact — `python3 playstore/verify.py`
diffs it against the built APK. Do not hand-maintain it; it was wrong before.

---

## Microphone — `RECORD_AUDIO`

**Two consumers, both only while the Speak screen is in front of the user.**

**Paste this:**

```
The app is a voice journal: the user taps record and speaks, and the microphone
is what hears them. It is used for two things, both starting only when the user
taps record and both stopping when they stop.

First, transcription. The spoken entry is converted to text by Android's
on-device speech recogniser, so the entry can be searched and read back. The app
uses createOnDeviceSpeechRecognizer specifically, which keeps recognition on the
phone and fails rather than falling back to a network recogniser.

Second, the recording itself is saved as an audio file in the app's private
storage, so the user can play back their own voice later from the entry.

Nothing is recorded in the background. Recording requires the app to be open and
in the foreground — the app deliberately holds no foreground-service permission,
so leaving the app stops the recording. Neither the audio nor the transcript is
ever transmitted; the app holds no internet permission.
```

*Where:* `audio/SpeechCapture.kt` (`SpeechRecognizer`) and `audio/AudioRecorder.kt`
(`MediaRecorder`, `AudioSource.MIC`). Driven from `ui/screens/SpeakScreen.kt` and
the onboarding beat.

---

## Notifications — `POST_NOTIFICATIONS`

**Two channels. The listing said "the evening reminder, nothing else" and that
was wrong — see the correction at the bottom of this file.**

**Paste this:**

```
Two notifications, and no others.

1. An optional evening reminder to record the day's entry. It is off until the
   user switches it on and picks a time, and it does not post if they have
   already recorded that day.

2. An ongoing notification shown only while a recording is actually in progress,
   displaying the elapsed time with a control to finish the entry. It appears
   when recording starts and is cleared when it ends.

The second one is deliberately a plain ongoing notification rather than a
foreground service. A microphone foreground service would let the app record
with the screen off, which this app does not want to be able to do — so it does
not request FOREGROUND_SERVICE or FOREGROUND_SERVICE_MICROPHONE. The notification
mirrors the recording state; it does not keep the microphone alive.

No marketing, promotional or engagement notifications are ever sent.
```

*Where:* `system/Reminders.kt`, channel `dailyvox.reminder`, gated on the
`reminder` preference which defaults to off; and `system/RecordingLive.kt`,
channel `dailyvox.recording`, shown from `SpeakScreen.kt` while the state is
RECORDING.

---

## Vibration — `VIBRATE`

**Paste this:**

```
Haptic feedback on the record button: a short pulse when a recording starts and
when it stops, a distinct one when an entry is saved, and one when the user
reaches a seven-day streak. It is used for nothing else.
```

*Where:* `system/Haptics.kt` (`VibrationEffect` via `VibratorManager`), called
from `SpeakScreen.kt`. A normal permission — granted at install, never prompted.

---

## Biometrics — `USE_BIOMETRIC`

**Paste this:**

```
An optional app lock. If the user turns it on, the journal is hidden behind the
device's own biometric prompt — fingerprint or face — falling back to the device
PIN, pattern or password if biometrics are unavailable or fail.

The app never sees or stores biometric data. It asks the Android BiometricPrompt
API for a yes or no and receives only that. The lock is off by default and the
app is fully usable without it.
```

*Where:* `security/AppLock.kt`, `BiometricPrompt` with
`BIOMETRIC_STRONG or DEVICE_CREDENTIAL`. Note the manifest explicitly removes
`USE_FINGERPRINT`, which androidx.biometric would otherwise merge in for API 27
and below — dead weight at minSdk 33, on a permission list people are invited to
read.

---

## Health Connect — four `health.READ_*` permissions

Sleep, heart rate variability, resting heart rate, steps. **Read-only, optional,
and nothing is requested until the user turns Body signals on.**

Per-type justifications for the Play health form are in
[`HEALTH_DECLARATION.md`](HEALTH_DECLARATION.md) — that form requires a separate
explanation for each data type, and two of the four are weaker than the code
comments used to claim. Read it before submitting.

*Where:* `body/BodySignals.kt`.

---

## `com.dailyvox.app.DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION`

Not requested by this app and not shown to users. `androidx.core` defines it and
uses it to guard receivers it registers at runtime so they cannot be triggered by
other apps. It is a signature-level permission the app declares for its own use.

It is listed here only because it appears in the built artifact, and a permission
list that is presented as complete has to actually be complete — this one was
missing from `DATA_SAFETY.md` while a permission that had been removed was
listed instead.

---

## Correction to the store listing, 2026-08-26

`STORE_LISTING.md`'s full description reads:

> • Notifications — the evening reminder, nothing else

**There is a second notification**: the ongoing one shown while recording
(`system/RecordingLive.kt`, channel `dailyvox.recording`). "Nothing else" is
false, in the paragraph headed "The complete list of what DailyVox asks for" —
which is the most scrutinised sentence in the listing and the one the whole
argument rests on. Fixed in the listing; recorded here because the class of
error matters more than the instance.
