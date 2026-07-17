# DailyVox 1.6.0 (build 20) — Submission Runbook

Paste-ready. Source of truth for copy: `metadata.json` + `AppStoreMetadata.md`.

## ⚠️ Device-test gates before archiving (do NOT skip)

1.6.0 adds two new permissions and several device-dependent surfaces. Validate on a real iPhone before archiving:
- **Photo context** (Settings → Your Day): enable → permission prompt → record/open next day → a "mostly … photos" note appears in the ambient review queue → Keep/Let go works. On a device with no photos, the source produces nothing and nothing blocks.
- **Music mood** (Settings → Your Day): enable → Media Library prompt → after listening, a mood note appears in the queue.
- **Spoken Words** (Settings): add a name → it survives relaunch → a new recording of that name transcribes correctly (contextualStrings bias).
- **SpeechAnalyzer** (iOS 26 device): entries transcribe via the new path; on an iOS < 26 device the current recognizer still works.
- **iCloud default-off migration**: a fresh install starts with sync OFF; an existing install that was syncing still syncs after update (nobody's data stops).

## Notes for App Review (paste verbatim)

> DailyVox is a privacy-first voice diary. All AI runs on-device (Apple Speech/SpeechAnalyzer + NaturalLanguage); the app makes no network calls, requires no account, and functions fully offline. HealthKit (Body Twin, from 1.5.0) remains read-only, app-target only.
>
> NEW IN 1.6.0 — two on-device ambient signals, both OFF BY DEFAULT and user-initiated:
>
> • Photos (NSPhotoLibraryUsageDescription): if the user turns on "Photo context" (Settings → Your Day), DailyVox reads the day's photos on-device with the Vision framework (VNClassifyImageRequest) to derive a one-line scene label ("mostly trail photos"). Only the derived text label is produced — no photo is copied, stored, or transmitted; network access is disabled on the image requests. The existing photo-attachment use is unchanged.
>
> • Media Library (NSAppleMusicUsageDescription): if the user turns on "Music mood", DailyVox reads recently-played tracks from the on-device library (MPMediaQuery) to derive a coarse mood word ("reached for calm music"). Only the derived label is produced; no track list or audio leaves the device; no network/ShazamKit.
>
> HOW TO TEST both: neither is requested at first launch. Settings → "Your Day (Ambient)" → toggle a source → grant permission → the derived note appears in a review-and-discard queue (Settings → "Review waiting signals"), where the user taps Keep (it becomes Twin context) or Let go (deleted). On a device with no photos/music, the sources produce nothing and nothing blocks.
>
> Everything derived stays on-device (Application Support, excluded from backups). The App Store privacy label remains "Data Not Collected." The research pilot row in Settings is an outbound link to getdailyvox.com/research; the app itself collects and transmits nothing.

## Pre-flight verification (fill at build time)

- [ ] `MARKETING_VERSION = 1.6.0`, `CURRENT_PROJECT_VERSION = 20`
- [ ] Release build at main: BUILD SUCCEEDED
- [ ] `NSAppleMusicUsageDescription` + updated `NSPhotoLibraryUsageDescription` present; both permission-gated, off by default
- [ ] Ambient sources OFF by default (verified in a fresh install)
- [ ] Widget extension has no photo/music access
- [ ] aps-environment flips to production at archive; HealthKit app-only

## App Store Connect — per-field pastes

| Field | Source |
|:--|:--|
| What's New | `metadata.json → whats_new` (draft from CHANGELOG 1.6.0) |
| Description | add ambient + semantic-memory lines to `AppStoreMetadata.md` |
| App Privacy | no questionnaire change — derived labels on-device, nothing collected |
| Screenshots | keep current until ambient/search surfaces are device-verified, then refresh |
