# Google Play — DailyVox 1.2.1 (versionCode 7)

A patch release. It ships BEFORE the languages release (Android 1.3 / iOS
1.14), on its own: these are fixes for people already speaking or typing in a
language other than English, and they change nothing for English.

## Release notes — PASTE INTO "Release notes" (en-US, max 500 characters)

```
Quieter where it can't read yet.
• If your phone has no speech pack for your language, DailyVox offers to download it instead of writing your words down in English
• No mood guesses, tone, or "warmest month" for entries the app can't read yet
• Search no longer shows your whole journal for a query it can't read
• Share cards wrap Chinese, Japanese and Thai text properly
English entries work exactly as before.
```

*(412 of 500 characters.)*

## Build

```
cd android && ./gradlew :app:bundleRelease
```

Upload the signed AAB to the internal testing track first, as in
`SUBMISSION_RUNBOOK.md`.

## Before you upload

1. **Database upgrade.** This release moves the database from version 4 to 5
   (valence becomes nullable; MIGRATION_4_5 rebuilds the table, covered by
   MigrationTest). Install 1.2 from Play on a test phone with entries, then
   install this build over it, and check every entry, label, photo and
   recording is still there.
2. **Device pass.** With the phone language set to Hindi (or Portuguese) and
   only the English speech pack installed, tap record: the card must say the
   pack is missing and offer the download, and no English transcript appears.
   With English, recording works as before.
3. **Data safety** — unchanged. No permission added; the app still holds no
   internet permission (checked in the merged manifest).
