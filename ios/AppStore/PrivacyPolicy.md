# DailyVox Privacy Policy

**Last Updated: October 14, 2026**

*The published policy at [getdailyvox.com/privacy](https://getdailyvox.com/privacy) is the source of truth, and also covers DailyVox for Android. This file is the iOS copy kept with the App Store materials.*

## Our Promise

DailyVox is built on one fundamental principle: **your data is yours alone**. We don't collect it, we don't store it, we don't sell it, and we don't have access to it. Period.

## What Data DailyVox Processes

DailyVox processes the following types of data **entirely on your device**:

- **Voice Recordings**: Audio files recorded through the app
- **Transcriptions**: Text converted from your voice recordings using Apple's Speech framework
- **Journal Entries**: Text you write or dictate
- **Mood Data**: Mood selections you make for your entries, and moods the app suggests from an entry's words, which are always marked as suggestions
- **AI Analysis**: Emotional patterns, personality insights, and your Digital Twin model
- **Digital Twin Data**: Personality model, emotional signature, and knowledge graph generated from your entries
- **Photos**: Images you attach to diary entries (stored on-device only, never uploaded)
- **Health and motion data** (optional, read-only): if you turn on Body Twin, sleep, heart rate, heart-rate variability, steps, mindful minutes and motion activity, read on your iPhone

## Where Your Data Lives

**On your device. Only on your device.**

All data is stored locally on your iPhone using:
- **Core Data**: For diary entries and metadata
- **UserDefaults**: For settings, preferences, and AI model data
- **Application Support Directory**: For audio files

### Optional iCloud Sync
If you choose to enable iCloud sync, your diary entries are synced through **Apple's CloudKit** infrastructure:
- Data is encrypted using your Apple ID
- We have zero access to your iCloud data
- Apple's privacy protections apply
- You can disable this at any time

## What We Do NOT Do

- We do **NOT** collect any personal information
- We do **NOT** send data to our servers (we don't have servers that receive user data)
- We do **NOT** use third-party analytics or tracking
- We do **NOT** use third-party advertising
- We do **NOT** share, sell, or transfer your data to anyone
- We do **NOT** require an account or login
- We do **NOT** use cookies or web tracking
- We do **NOT** access your contacts or other personal data beyond photos you explicitly attach to entries

## AI Processing

All AI processing in DailyVox happens **100% on-device**:

- **Speech Recognition**: Uses Apple's built-in Speech framework, on-device only, whether or not the phone is online. If no on-device speech model is available, transcription stops and says so rather than sending audio to a server.
- **Emotion Detection**: On-device using Apple's NaturalLanguage framework
- **Digital Twin Engine**: On-device machine learning that builds your personal model
- **DailyVox Brain**: Rule-based cognitive AI running locally
- **Ask Your Twin**: On iPhones with Apple Intelligence, answers come from Apple's on-device model
- **Suggested moods**: Read from the entry's text on your iPhone, and never written over a mood you chose

**No AI processing is sent to external servers.**

## Permissions We Request

| Permission | Why We Need It | When It's Used |
|-----------|---------------|----------------|
| Microphone | To record voice diary entries | Only while actively recording |
| Speech Recognition | To transcribe voice to text | Only when processing a recording |
| Face ID / Touch ID | To lock the app for privacy | Only when app lock is enabled |
| Notifications | To send daily journal reminders | Only if you enable reminders |
| Photo Library | To attach photos to entries, and for the optional photo context note | Only when you use the photo picker, or turn on Photo context |
| Health (read-only) | Body Twin: what your body felt around each entry | Only if you turn on Body Twin |
| Motion & Fitness | Body Twin: whether you were moving when you recorded | Only if you turn on Body Twin |
| Media & Apple Music | The optional music context note | Only if you turn it on |

All permissions are optional. The app functions without them (text-only mode).

## Reminders on the Lock Screen

Reminders are generic by default: they do not contain anything you said. If you turn on **"Include a line from your past in reminders"** in Settings, the daily reminder can quote, word for word, a line from an entry you made a week earlier. The notification is created on your iPhone and nothing leaves it, but it appears on the Lock Screen and in Notification Center, where anyone who can see your phone can read it. This setting is off by default, and turning it off takes the quotes out of reminders that are already scheduled.

## Photo Storage

Photos you attach to diary entries are:
- Stored locally on your device in the app's sandboxed directory
- Compressed as JPEG files
- **Never uploaded** to any server or cloud service
- Not included in iCloud sync (only filenames sync, not photo files)
- Deleted when you uninstall the app

## Data Retention

- Your data stays on your device until **you** delete it
- Uninstalling the app removes all local data
- iCloud data can be managed through your iCloud settings
- Audio files are stored in the app's sandboxed directory

## Children's Privacy

DailyVox does not knowingly collect data from children under 13. Since we don't collect any data at all, there is no age-specific data collection concern.

## Third-Party Services

DailyVox uses the following Apple frameworks (subject to Apple's privacy policy):
- Apple Speech Framework (for transcription)
- Apple NaturalLanguage Framework (for NLP)
- Apple CloudKit (optional, for iCloud sync)
- Apple HealthKit (optional, read-only, for Body Twin)
- Apple WidgetKit (for Home Screen widgets)

We do not integrate any third-party SDKs, analytics tools, or advertising networks.

## App Store Privacy Labels

Based on Apple's App Privacy guidelines:

**Data Not Collected**: DailyVox does not collect any data that leaves your device.

**Data Linked to You**: None.

**Data Used to Track You**: None.

## Your Rights

Since we don't collect your data, traditional data rights (access, deletion, portability) are already fully in your hands:
- You can export all your data at any time (Settings > Export)
- You can delete individual entries or all data
- You can uninstall the app to remove all local data
- iCloud data can be managed through Apple's iCloud settings

## Changes to This Policy

We may update this privacy policy from time to time. We will notify you of any changes by updating the "Last Updated" date at the top of this policy.

## Contact Us

If you have questions about this privacy policy:
- Email: intrepidkarthi@gmail.com

## Summary

**We built DailyVox because we believe your most personal thoughts deserve absolute privacy.** Your diary entries, voice recordings, emotional patterns, insights, and Digital Twin data all stay on your device. We can't see them, access them, or share them - because they never leave your phone.

Your twin is yours. Your thoughts are yours. Always.
