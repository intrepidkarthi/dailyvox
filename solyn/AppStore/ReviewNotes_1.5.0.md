# DailyVox 1.5.0 (build 19) — Submission Runbook

Everything below is paste-ready. Source of truth for copy: `metadata.json` (machine) and `AppStoreMetadata.md` (human history).

## 1. Archive & upload (Xcode — requires signing)

1. Xcode → Product → Archive on `solyn` scheme, Release. Confirm version **1.5.0 (19)**.
2. In the Organizer, **inspect archive entitlements before upload**:
   - `aps-environment` must show **production** (Xcode flips it from `development` at distribution signing — verify, this broke CloudKit sync scares before)
   - `com.apple.developer.healthkit` present on the **app** only
3. Validate, then Distribute → App Store Connect.

## 2. App Store Connect — per-field pastes

| Field | Source |
|:--|:--|
| What's New | `metadata.json → whats_new` (also in `AppStoreMetadata.md § 1.5.0`) |
| Promotional Text | `metadata.json → promotional_text` (154 chars) |
| Description | `AppStoreMetadata.md § Description` (now includes "YOUR BODY, YOUR CONTEXT") |
| Keywords | unchanged from 1.4.1 (anchored: `mood tracker`, `digital twin`) |
| Review Notes | § 3 below |
| Screenshots | **keep the live 1.4.1 sets** — regenerate with Body Twin surfaces after approval (fixtures ready in `ScreenshotDataSeeder`; relaunch fresh for Twin-tab shots) |

**App Privacy:** no questionnaire change — reads stay on-device, nothing is collected; "Data Not Collected" label stands.

## 3. Notes for App Review (paste verbatim)

> DailyVox is a privacy-first voice diary. All AI runs on-device (Apple Speech + NaturalLanguage); the app makes no network calls, requires no account, and functions fully offline.
>
> NEW IN 1.5.0 — HealthKit (read-only): the Body Twin feature reads five types (sleep analysis, HRV/SDNN, resting heart rate, steps, mindful minutes) to give journal entries body context. No write access. The HealthKit entitlement and usage strings are on the app target only; the widget extension has no health access. Context on the June 2026 rejection of build 16 (Guideline 2.5.1): usage strings then existed without HealthKit code; they were removed for 1.4.0/1.4.1 and return in 1.5.0 with the full feature behind them.
>
> HOW TO TEST: Health access is user-initiated, never requested at first launch. Enable via Settings → Health, or the Body card on the Twin tab. After enabling, record a short entry — a health snapshot appears in the review queue (Twin tab → Body card), where the user chooses Keep or Let go. On a device without Health data, all Body Twin surfaces show graceful empty states; nothing blocks.
>
> Motion (CMMotionActivity) tags whether the user was at rest or moving during a recording so heart data is interpreted in context. All health snapshots stay on-device: not uploaded, not synced to iCloud, excluded from device backups, deletable via Settings → Health → Wipe all health snapshots.
>
> The research pilot row in Settings is an outbound link to getdailyvox.com/research; the app itself collects and transmits nothing.

## 4. Pre-flight verification (already done 2026-07-17, re-run if main moves)

- [x] `MARKETING_VERSION = 1.5.0`, `CURRENT_PROJECT_VERSION = 19`
- [x] Release build at main: **BUILD SUCCEEDED**
- [x] `NSHealthShareUsageDescription` + `NSMotionUsageDescription` in app Info.plist, real HealthKit code behind them
- [x] `NSHealthUpdateUsageDescription` in app Info.plist (2026-07-17: upload validation demands it because `requestAuthorization(toShare:read:)` is referenced, even with an empty share set; string honestly states the app never writes to Health)
- [x] Widget Info.plist has **zero** health keys; widget bundles `solyn.momd` (PR #39 fix)
- [x] HealthKit entitlement on app target only

## 5. After approval (day-of-live sweep)

1. `ROADMAP.md`: v1.5 → Shipped
2. Website changelog: v1.5.0 entry → shipped (correct the scope: **no Watch app in 1.5.0** — Watch is v1.5 part 2; the current "in development" blurb still promises it)
3. Regenerate App Store screenshots featuring Body Twin surfaces and upload
4. Send the 3 pilot asks (`marketing/content/pilot-recruitment-drafts.md`)
