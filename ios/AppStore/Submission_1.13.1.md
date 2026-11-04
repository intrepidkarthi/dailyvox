# App Store Connect — DailyVox 1.13.1 (build 47)

A patch release. Only the fields below change; everything else stays as in
`Submission_1.13.0.md` (description, promotional text, keywords, screenshots,
App Privacy "Data Not Collected").

## 1. Version and build

| Field | Value |
|---|---|
| Version | **1.13.1** (new version in ASC) |
| Build | **47** |
| Data model | unchanged since 1.13.0 — no CloudKit schema step |

## 2. What's New — PASTE INTO "What's New in This Version"

```
Better for everyone who speaks to DailyVox in a language other than English.

FIXED
- If your iPhone is set to another language and its speech model isn't installed, DailyVox no longer writes your words down in English. It tells you how to install your language's model instead.
- No suggested mood or reflection on entries DailyVox can't read yet, rather than a wrong one.
- The daily question no longer asks about names from entries it can't read.
- Names written in Hindi, Tamil and other Indian scripts now match correctly.
- "Words you came back to" works properly in Chinese, Japanese and Thai.

Entries in English work exactly as before.
```

*(644 of 4,000 characters.)*

## 3. App Review Information → Notes

Replace with the full contents of `ios/AppStore/ReviewNotes_1.13.1.txt`
(3,574 of 4,000 characters).

## 4. Before you submit

1. On an iPhone set to Hindi (or any language without its dictation model),
   record an entry: it must say the model is missing, not show English text.
2. Settings → Developer → Speech locale probe exists only in debug builds; the
   App Store build does not contain it (checked in the archive).
3. English: record and type an entry; reflection and suggested mood appear as in 1.13.0.

## 5. Order
Distribute build 47 from Organizer → create 1.13.1 → paste §2 and §3 → submit.
