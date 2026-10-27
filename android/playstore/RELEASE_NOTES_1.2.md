# Google Play — DailyVox 1.2 (versionCode 6)

## Release notes — PASTE INTO "Release notes" (en-US, max 500 characters)

```
Now it talks back from day one.
• A short reflection after every entry
• A suggested mood, one tap to change, never over yours
• "A week ago you said…", On this day, and a weekly recap
• A new question each day
• Early signals from your third entry
• One rest day a week won't break your streak
Fixed: reminders now stop after a week away instead of repeating, follow your local day, and keep their time across daylight saving.
```

*(427 of 500 characters.)*

## Build

```
cd android && ./gradlew :app:bundleRelease
```

Upload the signed AAB to the internal testing track first, as in
`SUBMISSION_RUNBOOK.md`.

## Before you upload

1. **Device pass** — nothing in this release has been seen on a real phone.
   Check the reflection card, mood chip, week-ago / on-this-day / recap cards,
   the daily question, early signals, and the streak after a missed day, at the
   largest font size and with TalkBack.
2. **Data safety** — unchanged. Every new feature runs on the device and the app
   still holds no internet permission.
3. **Merge order** — #102 → #103 → #105 → #107 → #109 → this PR.
