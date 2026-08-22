# App Store Connect — DailyVox 1.11.0 (build 44)

Everything below is what changes in App Store Connect for this release. Fields
not listed here are unchanged and need no attention.

---

## 1. Version and build

| Field | Value |
|---|---|
| Version | **1.11.0** (new version — create it in ASC) |
| Build | **44** |
| Archive | `ios/build/DailyVox-1.11.0-44.xcarchive` |
| Minimum iOS | 17.0 (unchanged) |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` is already in Info.plist, so ASC will not ask |

The archive is signed with a **Development** certificate because that is the only
one in this keychain. Distribute from Xcode → Window → Organizer → Distribute
App → App Store Connect, which will create the distribution certificate and the
App Store provisioning profile against team `9W3J36YT29`.

---

## 2. What's New — PASTE INTO "What's New in This Version"

Speak, and watch the words arrive.

NEW
- Live transcription. The recording screen and the Dynamic Island show what you are saying as you say it, with a gold star when a name is caught. On-device, always.
- The Dynamic Island, in full: a 42-second ring, the phrase being heard, and Finish or Discard without opening the app.
- A "Speak" control for Control Centre, the Lock Screen and the Action Button.
- Two new share cards. "Tonight" is different every night. "Body" reads how you slept against how you wrote — it stays hidden unless you have kept body signals, and its switch starts off every single time.
- Your sky now means something. How far a star sits from the centre is how long ago you spoke; the angle is the hour of day. A usual bedtime becomes a visible band.
- The app now brings its own typefaces, and everything still scales with your text size.

FIXED, AND THIS ONE MATTERS MOST
Voice recordings were being sent to Apple's speech servers whenever the phone was online. On-device transcription is now unconditional: if no on-device model is installed, transcription stops and tells you why rather than reaching for the network.

ALSO FIXED
- The microphone now sits at the bottom of the Speak tab, where your thumb is.
- The starred filter in your Journal could not be reached at all. It can now.
- The streak on the home screen could disagree with the streak in Insights.
- Editing an entry changed its timestamp, and an edit could be lost if iOS closed the app.
- A phone call no longer loses the recording in progress.
- Dozens of taps that were too small to hit, now big enough.

*(1,600 of 4,000 characters.)*

---

## 3. Promotional Text — PASTE INTO "Promotional Text"

See your words appear as you speak them — on the screen and in the Dynamic Island. Nothing is uploaded, because there is nowhere to upload it to.

*(145 of 170 characters. This field can be changed later without a new build.)*

---

## 4. App Review Information → Notes

Replace the existing notes with the full contents of
`ios/AppStore/ReviewNotes_1.11.0.md` (3,508 of 4,000 characters). It is also
mirrored into `metadata.json` under `review_information.notes_for_reviewer`.

The two things a reviewer is most likely to query, both answered in those notes:

- **Transcription can fail on purpose.** On a device with no on-device speech
  model, recording shows "Recording Saved" and instructions to enable Dictation.
  That is the fix for this release working, not a defect.
- **The Body share card.** Reachable only after keeping a body snapshot in
  Settings → Body Twin. Steps: keep a snapshot, then Share → Body.

**Demo account:** still none required. No accounts exist.

---

## 5. Fields that do NOT change

| Field | Why it stays |
|---|---|
| App Name, Subtitle | Unchanged |
| Keywords | Unchanged (93/100 chars) |
| Description | Unchanged — still accurate |
| Category | Health & Fitness / Productivity |
| Age Rating | 4+ |
| Price | Free |
| **App Privacy ("Data Not Collected")** | **Still correct — see below** |

### Why App Privacy does not change despite the new health card

Apple defines "collect" as transmitting data off the device in a way that makes
it accessible to the developer over time. DailyVox has no server. HealthKit data
is read on the device, used on the device, and rendered into an image on the
device. A user choosing to share that image through the iOS share sheet is the
user distributing their own data, not the developer collecting it — the same
status as a screenshot. So the "Data Not Collected" declaration holds, and a
`PrivacyInfo.xcprivacy` matching it now ships in the binary (see §6).

---

## 6. New in the binary: privacy manifest

`solyn/PrivacyInfo.xcprivacy` is included for the first time in build 44. Without
it, Apple emails an **ITMS-91053 "Missing API declaration"** notice after upload.

It declares no tracking, no tracking domains, no collected data types, and one
required-reason API: `NSPrivacyAccessedAPICategoryUserDefaults` with reason
`CA92.1` (the app reads and writes only its own defaults and its own app group's).

An audit of the source found no other required-reason API in use — no
file-timestamp, disk-space, system-boot-time or active-keyboard calls. Storage
figures in Settings come from `.fileSizeKey`, which is file size and is not a
required-reason API.

---

## 7. Screenshots — STALE, and the one blocker

The live sets in `AppStore/screenshots/iPhone_*` predate this redesign. They show
the old centred microphone, the old Journal header, and a Twin sky whose stars
were placed by hash rather than by date. Shipping them would advertise a version
of the app that no longer exists.

Regenerate five, in this order:

1. **Speak** — microphone docked at the bottom, live transcript mid-sentence
2. **Journal** — entries with the mono meta line, search closed
3. **Twin** — the sky, with the gold star count and MIND / HEART / GRAPH
4. **Entry** — "What your Twin filed", gold-underlined names, the audio player
5. **Share → Tonight** — the card

Sizes required: 6.7" (1290 × 2796) and 6.5" (1284 × 2778). iPad if the listing
still carries iPad screenshots.

---

## 8. Privacy policy — needs deploying before submission

`website/public/privacy.html` has been amended locally and **is not yet live**.
The old text said health data is "never shared with anyone", which the new Body
card makes untrue in the one way that matters: you can now put your own sleep on
a card and share it. The amended paragraph says who can share it (you, never us),
what the card can show (nights measured, average sleep, mood after long nights
versus short), and what it will never show (heart rate, heart-rate variability).

App Review reads the hosted URL, not the repo. **Deploy this before submitting.**

---

## 9. Localization gap — your call, not a blocker

The listing is localized in German, Spanish, French and Italian. The app is not,
fully: **91 of 422 user-visible strings have no translation** and fall back to
English at runtime.

- **20 are new in this release** — "Starred only", "Search your entries",
  "Include how you slept", "What's on your mind?", "Nothing here yet", and the
  rest of the copy written this session.
- **71 predate it** — "Data Shield", "Ask your Twin", "Entries stored",
  "AES-256", and most of the mono instrument labels.

I have not machine-translated them. Several are deliberately typographic English
("TRANSCRIBED ON THIS PHONE", "SPEAK TAB, THE GREEN MIC") where a literal
translation would read as noise, and the rest carry a voice that took work to
get right. Translating them is a decision about that voice, so it is yours.

This is not a rejection risk. It is a quality gap a reviewer in one of those four
locales could reasonably notice, and it grows every release.

---

## 10. Order of operations

1. Deploy the privacy policy (§8)
2. Regenerate screenshots (§7)
3. Xcode → Organizer → Distribute App → App Store Connect (§1)
4. Create the 1.11.0 version in ASC; attach build 44
5. Paste What's New (§2), Promotional Text (§3), Review Notes (§4)
6. Upload screenshots
7. Submit
