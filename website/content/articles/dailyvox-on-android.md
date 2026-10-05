---
slug: dailyvox-on-android
title: "DailyVox Is on Android, and It Cannot Reach the Internet"
meta_description: "DailyVox is now on Google Play. The Android app requests no internet permission at all, so a journal entry has no route off the phone. Here is how that was built."
target_queries: ["dailyvox android", "private voice journal android", "offline voice journal app android"]
voice: karthik
cluster: privacy
---

# DailyVox Is on Android, and It Cannot Reach the Internet

DailyVox is on Google Play as of 2 October 2026. It needs Android 13 or newer and it is free. Its permission list is short: the microphone, notifications, vibration, biometric unlock, and one the Android libraries add for the app's own internal use. Internet is not on it.

That last fact is the whole release. On iPhone, "nothing leaves your phone" is a promise backed by Apple's privacy label and a codebase you can read. On Android it is something you can check in ten seconds without trusting me: Settings › Apps › DailyVox › Permissions. An app without the internet permission cannot open a network connection. There is no setting to flip, no server to subpoena, no analytics SDK quietly phoning home. The operating system refuses on my behalf.

## Why there was no Android app for two years

For a long time I said DailyVox would stay on iPhone, and I had a reason that sounded like engineering. Apple ships named-entity recognition, sentiment analysis and sentence embeddings as free on-device services. Android ships none of the three. A port looked like three models to bundle, three accuracy problems to own, and twice the surface area.

Then I measured it. A capitalisation-and-recurrence heuristic found people's names in my own journal about as well as Apple's tagger. The open VADER sentiment lexicon tracked hand-labelled moods better than Apple's built-in scorer did: a correlation of 0.66 against 0.59 across 1,459 labelled entries. The argument for staying single-platform was an assumption I had never tested. Most of the people I would want to reach in India carry Android phones, so the assumption was also expensive.

## The leak I almost shipped

The hard part of Android was not the Twin. It was speech.

Android lets an app ask the system recogniser to prefer offline transcription. Prefer is the operative word. When the phone has an offline language pack, speech stays on the device. When it does not, Google's recogniser can quietly send the audio to a server and hand back text, and the app sees nothing unusual. My first build used that flag. Onboarding said "On-device. Nothing left your phone." On a phone without the pack, that sentence was false.

The app's missing internet permission did not prevent it either, because the upload happens inside the recogniser's process, not inside DailyVox. My test was airplane mode, and airplane mode could never catch it: with no network there is nothing to leak to, so the test passed on exactly the phones that were leaking.

The fix was to stop asking politely. DailyVox now uses only the on-device recogniser, which fails rather than falling back to the network. That is also why the app needs Android 13: older versions do not have an on-device recogniser to require. If your phone is missing its offline speech pack, the app tells you and offers to fetch it. Your phone's speech service does the download, the same way it would from Android's settings. DailyVox sends a language code to start it and never your voice.

## Two more doors, closed

Android backs up app data to Google Drive by default. For a journal that would copy every entry and every recording to the cloud, with no network permission required from the app at all. Auto Backup is switched off.

Voice search was the third route. The first version of the journal's search mic handed the microphone to the system voice-input screen, which is a different app with its own internet access, to transcribe a line from someone's diary. Search now goes through the same on-device path as recording.

One door I cannot close: your keyboard. If you type into DailyVox and tap the microphone key on your keyboard, that dictation belongs to the keyboard app. DailyVox asks keyboards to hide that key. Some ignore the request. The record buttons inside DailyVox are the ones that stay on the phone.

## What Android 1.0 does, and what it does not

The core is the same as on iPhone. You speak for about 42 seconds, the phone transcribes it, and the entry gets a mood and joins the constellation of people and places your Twin keeps. Insights show patterns once they hold up across enough entries. Ask your Twin answers from your own entries and names the ones it used, and when nothing in your journal supports an answer, it says so. There is a home-screen widget, a Quick Settings tile, a daily reminder and an app lock that uses your fingerprint, face or PIN.

What it does not have yet: the on-device conversational Twin, which on iPhone runs on Apple's built-in language model and has no Android equivalent I would ship without a server. No health data, no photos, and English only for now. Android has its own version line for this reason. It is 1.0, not 1.11, because matching the iPhone number would claim a parity it has not earned.

Nothing syncs between iPhone and Android, because syncing them would need a server and DailyVox does not have one. Moving a journal between phones uses an encrypted backup file, and the format is identical on both platforms. A backup made on an Android phone opens on an iPhone, and the other way round.

## Check it yourself

Install it, open Android's own permission screen for DailyVox, and read the list. Microphone and notifications. That is all of it. Then put the phone in airplane mode and record an entry. The transcript, the mood and the star in your sky all still happen.

The Android app's source is in the [same public repository](https://github.com/intrepidkarthi/dailyvox/tree/main/android) as the iPhone app. Every claim in this post maps to a line of code you can read: the manifest with no internet permission, the recogniser that refuses to fall back, and the backup rules that keep Google Drive out.

## FAQ

### Is DailyVox on Android free?

Yes. It is free on Google Play with no ads, no account and no subscription, the same as on iPhone.

### Which Android version does DailyVox need?

Android 13 or newer. Android 13 is where the on-device speech recogniser arrived, and DailyVox will not transcribe over a network instead.

### Does DailyVox for Android work offline?

Yes, once your phone has its offline speech pack. If it does not, the app offers to download it through your phone's speech service; after that, recording, transcription and the Twin work in airplane mode.

### Can I move my journal from iPhone to Android?

Yes. Export an encrypted backup on one phone and import it on the other. The backup format is the same on both platforms. There is no live sync between them.
