# DailyVox 1.9.0 (build 24) — Submission Runbook

Paste-ready. Source of truth for copy: `metadata.json` + `AppStoreMetadata.md`.
Long-form marketing variants: `marketing/launch/release-notes-v1.9.0.md`.

## ⚠️ Device-test gates before archiving (do NOT skip)

Nothing here is device-tiered — no Apple Intelligence dependency, no HealthKit
path touched. All of it is testable on a simulator or any real device, though
**read-aloud wants a real device** (simulator voice output is unreliable and the
installed-voice list differs from a phone's).

- **Read aloud, the feature this release exists for:** Twin tab → "Ask Your
  Twin" → ask anything → a "Read aloud" button sits under the answer. Tap it →
  the reply is spoken; the button becomes "Stop" and stops it mid-sentence.
  Leave the screen while it is speaking → speech stops, no audio orphaned in
  the background.
- **Voice picker:** Settings → Twin Voice. The list is scoped to your language,
  deduplicated by name, with your exact locale's variant (en-IN on an
  Indian-English phone) at the top rather than buried. "Hear a sample" speaks a
  line in the highlighted voice so voices can be compared without going back to
  the chat. Switch voice → the next "Read aloud" uses it.
- **It asks nothing:** turning read-aloud on triggers **no permission prompt**
  and no enrollment. If any authorization dialog appears here, that is a
  regression — Personal Voice was deliberately removed from the shipped surface
  in `e98b670`.
- **Off by default:** a fresh install must never speak until the user taps
  "Read aloud". (People use this app in bed.)
- **Reminder offer at the end of onboarding:** run a clean install → the final
  onboarding screen shows a pre-checked "Remind me each evening at <time>" box
  above "Enter my sky". Leave it checked → the iOS notification prompt appears
  *after* tapping "Enter my sky", and the reminder is scheduled only if granted.
  Uncheck it → **no prompt at all**, and the reminder stays off. Decline the
  system prompt → app continues normally, nothing scheduled, no nagging.
- **Dynamic Type:** Settings → Accessibility → Display & Text Size → Larger
  Text. Drag toward the largest sizes and walk Record / Timeline / Insights /
  Twin / Settings — text grows, nothing clips into unreadability, no layout
  collapses. This touched 138 call sites, so it is the widest-blast-radius
  change in the release and deserves the most walking around.
- **Constellation labels:** Twin tab → the constellation card. The name and
  topic labels are plainly readable against the dark card (they were 9pt at 30%
  opacity — 2.5:1 — and effectively invisible; now 8.75:1).
- **VoiceOver:** enable it and visit the Twin tab. The Twin Resolution ring
  announces its score (it was pure geometry, silent). The section picker
  announces which section is selected instead of reading as six identical
  buttons, and no longer comes to rest with a word cut in half.
- **Regression sweep:** record → transcribe → entry saves; Ask Your Twin
  answers with citations on every device tier (1.8.0's hybrid retrieval is
  untouched); Face ID lock, HealthKit review queue, and the research-pilot
  toggle all behave as in 1.8.0.

## Notes for App Review (paste verbatim)

> DailyVox is a privacy-first voice diary. All AI runs on-device (Apple
> Speech/SpeechAnalyzer, NaturalLanguage, and the Foundation Models
> framework where available); the app makes no network calls, requires no
> account, and functions fully offline. HealthKit (from 1.5.0) remains
> read-only, app-target only.
>
> NEW IN 1.9.0 — the Twin can read its replies aloud. This uses
> AVSpeechSynthesizer with speech voices already installed on the device, so
> synthesis is entirely local and no audio is uploaded. It requires no new
> permission, no entitlement, and no enrollment: there is no Personal Voice
> authorization request and no voice recording or cloning of any kind. The
> feature is off until the user taps "Read aloud", and the voice is chosen in
> Settings → Twin Voice.
>
> ALSO IN 1.9.0 — the optional daily reminder is now offered on the last
> onboarding screen instead of only in Settings. This is the same local
> UNUserNotificationCenter request the app has always made, moved earlier in
> the flow: the user sees a checkbox they can clear before any system prompt
> appears, and clearing it means no prompt is shown at all. Declining the
> prompt leaves the app fully functional; nothing is scheduled and the user is
> not asked again.
>
> ALSO IN 1.9.0 — an accessibility pass: text now scales with Dynamic Type
> across the app, several low-contrast labels were corrected, and VoiceOver
> now announces the Twin Resolution score and the selected Twin section. No
> functional change.
>
> There are no new Info.plist usage-description keys, entitlements, or
> capabilities versus 1.8.0.
>
> HOW TO TEST: Twin tab → "Ask Your Twin" → ask any question → tap "Read
> aloud" under the answer to hear it. Settings → Twin Voice to change the
> voice, with "Hear a sample" to compare. For the accessibility work, set
> Settings → Accessibility → Display & Text Size → Larger Text to a large
> size and reopen the app.

## Pre-flight verification (fill at build time)

- [x] `MARKETING_VERSION = 1.9.0`, `CURRENT_PROJECT_VERSION = 24`
- [x] Release build at `main` (761fa96): **BUILD SUCCEEDED**, 0 warnings
      (`-configuration Release -destination generic/platform=iOS`)
- [x] No new Info.plist keys or entitlements vs 1.8.0 (diff of
      `9491576..761fa96` over `Info.plist` and `*.entitlements` is empty)
- [x] `NSMotionUsageDescription` and the HealthKit keys are each backed by real
      code (`ActivityContextDetector`, `BodyTwin`) — the 1.4.0 rejection was
      *unbacked* keys, and that class of problem is absent here
- [x] No Personal Voice / `AVSpeechSynthesisVoice` authorization API on the
      shipped path — read-aloud is permission-free by construction
- [ ] Read-aloud verified on a **real device** (simulator audio is unreliable)
- [ ] Dynamic Type walked at the largest text size across all five tabs
- [ ] Clean-install onboarding: reminder checkbox → prompt only when left checked

## App Store Connect — per-field pastes

| Field | Source |
|:--|:--|
| Promotional Text | `metadata.json → promotional_text` |
| What's New | `metadata.json → whats_new` |
| Description | `AppStoreMetadata.md → Description` (unchanged this release) |
| Keywords | unchanged (anchored ASO — do not touch) |
| App Privacy | no questionnaire change — on-device only, nothing collected |
| Review Notes | verbatim block above |
| Screenshots | keep current 1.8.0 set. No screen's layout changed enough to require new captures; read-aloud adds one button inside an existing screen. Known cosmetic issues are logged in `appstore-screenshots-review-2026-07-26.md` (sticker overlaps, frame 06's Settings screen, stale 3 July captures) — none are blockers |

## Post-approval sweep

1. ROADMAP: v1.9 `(built … — awaiting archive)` → shipped, with the live date
2. Repo CHANGELOG: 1.9.0 already dated 2026-07-29 — correct if it ships on time
3. Website: bump the three v1.8.0 markers to v1.9.0 —
   `index.html` wordmark `<span class="ver">`, the footer colophon, and the
   `SoftwareApplication` schema's `softwareVersion`; add a
   "◆ latest · v1.9.0" section to `changelog.html` and demote 1.8.0
4. Confirm read-aloud on a second device family (older iPhone without Apple
   Intelligence) — the feature is tier-independent and should behave identically

## What is deliberately NOT in this release

Voice cloning. The spike succeeded on 2026-07-28 — Kyutai Pocket TTS reproduced
Karthik's own voice from a 30-second slice of existing journal audio, validated
by ear. It is held for v1.10 because the iPhone peak-memory number is still
projected rather than measured, and the weights used were an unlicensed mirror
of a January checkpoint. Read-aloud in this release uses system voices only:
the right accent family, not the user's own voice.
