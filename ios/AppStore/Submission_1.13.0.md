# App Store Connect — DailyVox 1.13.0 (build 46)

Everything below is what changes in App Store Connect for this release. Fields
not listed here are unchanged and need no attention.

---

## 1. Version and build

| Field | Value |
|---|---|
| Version | **1.13.0** (new version — create it in ASC) |
| Build | **46** |
| Minimum iOS | 17.0 (unchanged) |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` is already in Info.plist |

Distribute from Xcode → Window → Organizer → Distribute App → App Store Connect
(team `9W3J36YT29`), as for 1.11.0.

---

## 2. What's New — PASTE INTO "What's New in This Version"

Now it talks back from the very first day.

NEW
- Something back every time you speak: a short reflection under each entry, and when you name someone, a line to pick up tomorrow.
- A suggested mood for each entry, clearly marked, one tap to change. It never replaces a mood you chose, and it stays quiet when it isn't sure.
- Your past, brought back: "A week ago you said…", "On this day" from earlier months and years, and a weekly recap counted from your own entries.
- A question that changes each day, with "Different question" one tap away. Now and then it asks about someone you mentioned.
- Early signals from your third entry: when you usually speak, how long you talk, words that keep coming back.
- A kinder streak: one rest day a week doesn't break it, and coming back says welcome back, not zero.

PRIVATE, AS ALWAYS
Reminders stay generic. They can quote a line from your past only if you switch that on, because reminders show on the Lock Screen.

FIXED
- Turning reminders off now stops every one of them, including those already scheduled.
- The streak now agrees everywhere: Today, Insights, widgets, the Lock Screen and Live Activities.

*(1,154 of 4,000 characters.)*

---

## 3. Promotional Text — PASTE INTO "Promotional Text"

Speak for a minute, get something back: a reflection, a mood, a line from a week ago. All of it on your iPhone.

*(111 of 170 characters. Can be changed later without a new build.)*

---

## 4. App Review Information → Notes

Keep the 1.11.0 notes (`ReviewNotes_1.11.0.md`) and add:

- **Reminder quoting is off by default.** Settings → "Include a line from your
  past in reminders". When on, the evening reminder may quote an entry from
  exactly seven days earlier. Entry text never appears in a notification
  otherwise.
- **Suggested moods** are produced on the device from the entry text and are
  labelled as suggestions everywhere they appear, including exports
  ("Calm (suggested)").

**Demo account:** none required. No accounts exist.

---

## 5. Fields that do NOT change

| Field | Why it stays |
|---|---|
| App Name, Subtitle, Keywords, Description | Unchanged |
| Category, Age Rating, Price | Unchanged |
| **App Privacy ("Data Not Collected")** | Still correct: every new feature runs on the device; nothing is sent anywhere |

---

## 6. CloudKit — confirm before submitting

Build 46 adds an optional `suggestedMood` attribute to `DiaryEntry`. The schema
(`CD_DiaryEntry.CD_suggestedMood`) must be in **Production** before this build
ships: switch the CloudKit Dashboard to Production and check that `CD_DiaryEntry`
lists `CD_suggestedMood`. Production previously had **no** record types at all,
so iCloud sync could not have worked for any user before this deploy. Then confirm
with a TestFlight build: turn sync on,
save an entry, and check Production → Records for a `CD_DiaryEntry`.

---

## 7. Before you submit

1. **Device pass** — nothing in this release has been looked at on a real phone.
   Check on an iPhone, at the largest Dynamic Type size and with VoiceOver:
   the reflection card, the mood chip, the week-ago / on-this-day / recap cards,
   the daily question and "Different question", the early-signals card, and the
   streak header after a missed day.
2. **Translations — your call.** All 100 new strings this release are
   English only and fall back to English in de/es/fr/it, as with the 1.11.0
   gap. Not a rejection risk.
3. **Screenshots** — unchanged screens are still accurate; regenerate only if you
   want the new cards shown (`bash ios/AppStore/screenshot-src/make_screenshots.sh`).

---

## 8. Order of operations

1. Merge the iOS stack in order (#100 → #104 → #106 → #108 → #110 → this PR)
2. Device pass (§7.1)
3. Xcode → Organizer → Distribute App → App Store Connect
4. TestFlight: confirm iCloud sync writes a `CD_DiaryEntry` to Production (§6)
5. Create 1.13.0 in ASC; attach build 46
6. Paste What's New (§2), Promotional Text (§3), Review Notes (§4)
7. Submit
