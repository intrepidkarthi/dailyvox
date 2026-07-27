# DailyVox 1.8.0 (build 23) — Submission Runbook

Paste-ready. Source of truth for copy: `metadata.json` + `AppStoreMetadata.md`.

## ⚠️ Device-test gates before archiving (do NOT skip)

Unlike 1.7.0, nothing here is device-tiered — the fix is in the on-device
retrieval path every iPhone already uses (no Apple Intelligence dependency).
Fully testable on simulator or any real device:

- **Ask Your Twin retrieval, the actual regression this release exists for:**
  record 2–3 short entries on distinct topics (e.g. one mentioning a gym
  workout, one about coffee with a friend, one plain morning-walk entry).
  Ask a question about one of them ("Did I talk about the gym?") → answer
  quotes the matching entry with a date + "From your journal" citation chips.
  Ask about something never written ("Do I play chess?") → the plain "I
  don't have enough journaled evidence" line, never an invented answer. Both
  legs matter: 1.7.0 shipped a chat that answered in demos but measurably
  abstained on almost every real question post-ship — this build's whole
  purpose is closing that gap without breaking honest abstention.
- **Streak milestone:** with a streak past 30 days, open Insights — the
  milestone card shows the true streak length once, not "7-Day Streak!" on
  every visit.
- **Entry topics:** an entry mentioning "today," "this morning," or similar
  should NOT show those words as Topics or in the Twin's "Main themes" —
  only real subject nouns.
- **Theme consistency:** Ask Your Twin and Settings render in the app's warm
  ivory background, matching every other tab (previously fell back to system
  gray).
- **Research pilot (Settings → Research, opt-in, unchanged gate):** enabling
  "Label my entries after recording" shows a one-tap emotion + intensity
  picker right after the next recording; with it on, every third day the
  Record tab's starting-thought prompts lead with a plain "Just log your
  day" option instead of the usual reflective prompts. Off by default;
  invisible to users who never open that toggle.
- **Regression sweep:** record → transcribe → entry saves; classic question
  chips still answer on all devices; Apple-Intelligence conversational chat
  (1.7.0's feature) unaffected — this release doesn't touch that path.

## Notes for App Review (paste verbatim)

> DailyVox is a privacy-first voice diary. All AI runs on-device (Apple
> Speech/SpeechAnalyzer, NaturalLanguage, and the Foundation Models
> framework where available); the app makes no network calls, requires no
> account, and functions fully offline. HealthKit (from 1.5.0) remains
> read-only, app-target only.
>
> UPDATED IN 1.8.0 — the free-text retrieval path (on-device semantic
> search, every iPhone) is now hybrid: per-sentence embedding similarity
> plus content-word overlap, replacing whole-entry vector averaging that
> under-retrieved on realistic questions. Behavior is unchanged from the
> reviewer's perspective — the app still quotes the user's own closest
> entries verbatim with citations, or states plainly that nothing was
> written on the topic; only the on-device ranking quality changed. No new
> permissions, entitlements, or network access.
>
> ALSO IN 1.8.0 — pilot participants (opted in via Settings → an existing,
> unchanged research toggle) can now optionally record a one-tap emotion
> label right after each recording. This is off by default, on-device only,
> and leaves the phone solely through the existing user-initiated research
> export — no new data leaves the app automatically.
>
> HOW TO TEST: Twin tab → "Ask Your Twin". Record 2–3 short entries on
> distinct topics, then ask a question about one of them — the answer
> quotes and cites the matching entry. A question about something never
> written returns the plain "I don't have enough journaled evidence" line,
> never an invented answer. On an Apple Intelligence device, the same box
> returns conversational answers with citations, unchanged from 1.7.0.

## Pre-flight verification (fill at build time)

- [ ] `MARKETING_VERSION = 1.8.0`, `CURRENT_PROJECT_VERSION = 23`
- [ ] Release build at main: BUILD SUCCEEDED
- [ ] No new Info.plist keys or entitlements vs 1.7.0
- [ ] App icon: the four mac-idiom @2x slots that were 2x-oversized now
      pass Xcode's asset validation with zero AppIcon warnings
- [ ] Semantic index rebuilds transparently on first launch (versioned
      cache key) — no user-visible migration step, no data loss
- [ ] Pilot self-label toggle default OFF; classic chat/behavior unchanged
      for users who never open Settings → Research

## App Store Connect — per-field pastes

| Field | Source |
|:--|:--|
| Promotional Text | `metadata.json → promotional_text` |
| What's New | `metadata.json → whats_new` |
| Description | `AppStoreMetadata.md → Description` (unchanged this release) |
| Keywords | unchanged (anchored ASO — do not touch) |
| App Privacy | no questionnaire change — on-device only, nothing collected |
| Review Notes | verbatim block above |
| Screenshots | keep current for submission — no UI surface changed enough to require new screenshots (Ask Your Twin's screen layout is identical; only answer quality changed) |

## Post-approval sweep

1. ROADMAP: v1.8 → shipped (already annotated in this branch's commit)
2. Repo CHANGELOG: date the 1.8.0 entry (already dated in this branch's commit)
3. Website changelog: add v1.8.0 latest/shipped section; homepage version
   badge bump
4. Confirm pilot participants who already have the self-label toggle on
   see the picker after their next recording (no re-opt-in needed)
