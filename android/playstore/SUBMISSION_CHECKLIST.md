# Play Store release checklist — DailyVox for Android

**Status: live on [Google Play](https://play.google.com/store/apps/details?id=com.dailyvox.app)
since 2026-10-02.** v1.0 was the first release. Every release since is an update
with its own `versionCode`, and its Play release notes and release-specific checks
are in `RELEASE_NOTES_<version>.md` in this folder (from 1.2 on).

---

## Every update, in order

1. **Version.** Bump `versionCode` and `versionName` in `app/build.gradle.kts`,
   and add the release to the repository's `CHANGELOG.md`.
2. **Release notes.** `RELEASE_NOTES_<version>.md`, within Play's 500-character
   limit for the "Release notes" field.
3. **Tests, against the real engine.** `./gradlew :app:testDebugUnitTest` with the
   engine checked out at `DailyVoxTwin/` in the repository root. A stub build
   compiles but proves nothing about behaviour.
4. **`python3 playstore/verify.py`.** Needs `aapt2` on the path and a release APK
   (`./gradlew :app:assembleRelease`). It checks the APK's permissions against
   `DATA_SAFETY.md`, the listing against Play's limits, and the listing's claims
   against the source. Paste the numbers it prints; do not recall them.
5. **Permissions.** If the release adds one, update `DATA_SAFETY.md`,
   `PERMISSIONS.md`, and the onboarding and Settings ledgers in the app, in the
   same change. If it adds none, Data safety is unchanged.
6. **Device pass** on a real phone: every new screen at the largest font size and
   with TalkBack, and recording **while online** — airplane mode cannot catch a
   network fallback, because with no network there is nothing to leak to.
7. **Build and upload.** `./gradlew :app:bundleRelease` (signing comes from the
   gitignored `keystore.properties`), then the **internal testing** track first,
   as in `SUBMISSION_RUNBOOK.md` §5.
8. **Production, staged**, halting on Android vitals.
9. **After it is live**: see the last section of this file.

---

## The v1.0 launch, kept for the record

Everything below was written for the first release. The device tiers are the
catalog as it was set for v1.0; check Play Console › Device catalog for what is
current rather than this table.

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

## v1.0 launch steps (done)

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

Localized sets (1.3: de, es, fr, it, pt-BR) come from the same pipeline. Per
language: a debug build seeded in that language, the app's language set to
match, and the speech pack downloaded from Settings › Language you speak so the
card reads "on this phone". The system permission frame needs the SYSTEM
language switched too (Android's permission labels ignore per-app language).

```bash
# Clean first: an incremental build after an unseeded one keeps
# SEED_DEMO_DATA=false inlined, and the journal comes up empty.
./gradlew :app:clean && ./gradlew installDebug -PseedDemo -PseedDemoLang=de     # es, fr, it, pt-BR
adb shell cmd locale set-app-locales com.dailyvox.app --locales de-DE
# set Settings › Design to Day before capturing: Sunset turns dark after 17:00
# captures go in screenshot-src/de/ (same filenames as English, 05-ask.png included:
# a question typed in that language, answered from the seeded journal)
python3 screenshot-src/compose.py de    # -> assets/screenshots/de/
```

What each localized set may claim, and which frames it drops, is in the
docstring of `compose.py`. Upload `assets/screenshots/<locale>/` as that
language's phone screenshots in Play Console.

The feature graphic's render command is at the bottom of
`assets/feature-graphic.html`. If the emulator's display goes black, cold-boot
it — `emulator -avd <name> -wipe-data -no-snapshot` — rather than restarting.

## After the release is live

Update the versions the website shows (top-bar badge, footer on every page, schema, "latest" lines), once the store actually serves the new build:

```bash
python3 website/set_version.py --ios <version> --android <version>   # the numbers now live
```

Then add the release to website/public/changelog.html and the roadmap table by hand.
