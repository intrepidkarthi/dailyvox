# Play Store release plan — DailyVox for Android v1.0

**Status (2026-09-29): release candidate built, versionCode 4. Not submitted.**
Branch `android/release-1.0`. Engineering blockers are closed; what is left is a
signing check, one physical-phone test, and Google's own review clocks.

---

## Supported devices

The variable that decides whether DailyVox works is not the phone brand but the
**speech recogniser** on it, and whether that recogniser capitalises names (the
Twin's only input). A model list cannot guarantee either on its own; what it can
do is keep v1.0 on the one family where both are Google's reference
implementation, and widen only on evidence.

### Tier 1 — v1.0 launch set (the only devices in the Play catalog)

Google Pixel phones, Android 13 or newer:

| Line | Models |
|---|---|
| Pixel 6 | 6, 6 Pro, 6a |
| Pixel 7 | 7, 7 Pro, 7a, Pixel Fold |
| Pixel 8 | 8, 8 Pro, 8a |
| Pixel 9 | 9, 9 Pro, 9 Pro XL, 9 Pro Fold, 9a |
| Pixel 10 | 10, 10 Pro, 10 Pro XL, 10 Pro Fold |

Why Pixel: the on-device recogniser is Android System Intelligence, Google's
own, present on every one. It is also what the emulator runs, and on
2026-09-29 the full path was exercised there: recogniser reached, missing pack
detected, the in-app **Download speech pack** button raised Google's own
"Download English (US) update, 62 MB" prompt, and the recogniser reported
success — with the app still holding no INTERNET permission.

**"Works 100%" on Tier 1 is conditional on one test that has not been run:**
a physical Pixel (any model above) records a spoken entry containing two names,
and the transcript comes back with the names capitalised and the Twin sky shows
them. If the names come back lowercase, the Twin screen explains why
(`CasingCheck`) instead of sitting empty — but that is degraded, not working.

### Tier 2 — add after closed testing proves them

Samsung Galaxy S23 / S24 / S25 series, Z Fold 5–7, Z Flip 5–7, A35 / A55.
Third-party apps on Galaxy get Google's recogniser, not Samsung's, so these are
*expected* to behave like Pixel — but that is reported, not observed. Add each
to the catalog when the pre-launch report or a tester on that model passes the
same record-two-names test.

### Not supported in v1.0

| Devices | Why |
|---|---|
| OnePlus / Oppo / Realme | The dead Speak button was observed on OnePlus: the recogniser bound and never answered |
| Xiaomi / Redmi / Poco | Aggressive background restriction that resets after updates; untested |
| Huawei / Honor | No Google services, so no on-device recogniser at all |
| Android 12 and older | No on-device recogniser API; excluded automatically by minSdk 33 |
| Tablets, Chromebooks, TV, Wear | Not designed or tested for them |

### How to enforce it in Play Console

Release › Device catalog: filter by manufacturer, exclude everything that is not
Google, and exclude non-phone form factors. Re-include Tier 2 models one at a
time as they pass. Exclusions are reversible and need no new upload.

---

## Remaining steps, in order

1. **Signing — confirm, do not generate.** The 31 Aug bundle is signed with
   `CN=DailyVox, Bengaluru`, and `versionCode 2` was already uploaded, so an
   upload key exists. `~/code/creds/personal/dailyvox_keystore.jks` is the likely
   one: compare its SHA-256 (`keytool -list -v -keystore …`) with Play Console ›
   App integrity › Upload key certificate. Then create the gitignored
   `android/keystore.properties` and run `./gradlew :app:bundleRelease`.
   Generating a new key when one is enrolled is a support ticket, not a command.
2. **Physical Pixel test** (the Tier 1 condition above). Install the internal-
   track build, go through onboarding as a stranger would — the app lock prompt
   appears on first launch — record two entries naming people, then check the
   Twin sky, Ask, a 30-second background relock, and airplane mode.
3. **Internal testing track**, then **closed testing**. If the developer account
   is a personal account created after Nov 2023, Google requires **12 testers
   opted in for 14 consecutive days** before production unlocks. Recruit them
   now; that clock is the long pole.
4. **Read the pre-launch report** — real multi-OEM hardware, free. Any Tier 2
   model that passes goes into the catalog.
5. **Forms**: Data safety (from `DATA_SAFETY.md`), content rating
   (`CONTENT_RATING.md`), privacy policy getdailyvox.com/privacy. No health
   declaration — v1.0 declares no health permission.
6. **Production, staged**: 5% → 20% → 50% → 100%, halting on Android vitals.
   Only then change the website's "in development" wording.

---

## Done for v1.0

- **Nothing a user says is lost.** Room migrations survive a table that is
  already ahead (Robolectric `MigrationTest`); the silent-recogniser watchdog
  keeps the audio; onboarding keeps an untranscribed first entry; leaving Speak
  mid-filing saves instead of deleting; no double recorder.
- **Speech stays on the phone**, and a missing pack is now one tap to fix
  (`triggerModelDownload`, done by the recogniser in its own process).
- **No Health Connect.** No screen ever requested it, so it was removed rather
  than sent to the health-apps review. Five permissions in the APK: microphone,
  notifications, vibrate, biometric, and androidx's private receiver permission.
- **App lock on from first launch** wherever the phone has a screen lock, and
  re-locks after 30 s out of sight (iOS locks on backgrounding; the grace keeps
  the file picker and share sheet from bouncing the user to the lock screen).
- **Brand parity with iOS**: the same gold-mic icon (launcher layers regenerated
  from the iOS master, rim artefacts removed), the same store name
  "DailyVox: Voice Journal Diary", the iOS subtitle leading the short
  description, the same primary category, and the brand fonts actually
  rendering (they had been drawing at ExtraLight).
- **Design pass** against FINAL-SPEC and the shipped iOS app across every screen,
  plus predictive-back previews, a springing nav indicator and tab cross-fades.
- **Store assets**: eight new frames and a new feature graphic, captured from
  this build. `python3 playstore/verify.py` passes: listing lengths, the APK's
  permissions against DATA_SAFETY.md, no INTERNET, and the listing's claims
  against the source.
- Release build 2026-09-29: universal APK 4.87 MB, AAB 5.46 MB, 55 app unit
  tests green. Re-measure with `verify.py`; do not hand-copy.

---

## Do not do

- **Do not** describe Android as available anywhere until it is. The website,
  llms.txt and every doc currently say "in development", deliberately.
- **Do not** add a permission to the manifest without updating both the
  onboarding ledger and the Settings ledger. Those screens claim to be complete
  lists, and a listing that omits one is worth less than no listing.
- **Do not** re-enable Android Auto Backup. It would copy the journal and the
  audio to Google Drive via the system, needing no permission from the app, and
  every privacy claim in this listing would become false without a single line
  of code changing.
- **Do not** add a device to the catalog because it "should" work. Tier 2 moves
  on a passed test, not on the table in this file.

## Screenshot regeneration

```bash
# captures: a -PseedDemo debug build on the Pixel 9 Pro emulator, LIGHT theme,
# system UI demo mode for a clean 9:41 status bar
python3 screenshot-src/compose.py     # needs Chrome; uses the app's bundled fonts
```

The feature graphic's render command is at the bottom of
`assets/feature-graphic.html`. If the emulator's display goes black, cold-boot
it — `emulator -avd <name> -wipe-data -no-snapshot` — rather than restarting.
