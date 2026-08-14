# App Review Notes — DailyVox 1.10.0 (build 25)

## What changed in this build

**Localization.** The app is now available in Spanish, French, German and Italian
alongside English, via a single `Localizable.xcstrings` String Catalog (358 strings,
complete in all four). The app follows the system language; there is no in-app
language picker to test.

**App Store screenshots.** All four device sizes replaced.

No new frameworks, permissions, entitlements or network capability were added.

## How to review the localization

Set the device language to Spanish, French, German or Italian and relaunch. The
entire interface translates. No account, no sign-in, and no network connection is
required at any point.

## Why only four languages

This is likely to be the first question, so: the Speech framework transcribes far
more languages than four, and DailyVox has always supported that. Recording works in
every language the device can transcribe, in this build as in every previous one.

The limit is `NLEmbedding.sentenceEmbedding`, which powers the app's search-by-meaning
feature and is available for English, Spanish, French, German and Italian only.
Shipping the interface in a language where that feature silently returned nothing
would have been a worse experience than not shipping that language yet. Additional
languages will follow if and when Apple's on-device embeddings cover them.

## Privacy, unchanged

- No accounts, no sign-in, no server. There is no backend of any kind.
- All processing is on-device: transcription (`SpeechAnalyzer` / `SFSpeechRecognizer`),
  analysis (`NaturalLanguage`), and conversational answers (Foundation Models on
  supported hardware, on-device semantic retrieval elsewhere).
- Optional iCloud sync uses the user's own private CloudKit database.
- "Data Not Collected" on the privacy nutrition label remains accurate.

## Demo data

No demo account is needed. The app opens straight into a usable state. To see the
Digital Twin populated, record two or three entries; the Twin builds from the
device's own entries and nothing is fetched.

## Notes for the reviewer

- Microphone access is requested at the point of first recording, with the purpose
  string shown in context.
- Speech recognition permission is likewise requested at first use.
- HealthKit is optional and off by default (Settings → Body Twin). The app is fully
  functional without granting it.
- Notifications are optional and off unless enabled during onboarding.
