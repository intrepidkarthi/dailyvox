# Play Store submission runbook

Every step here needs either a credential only you can own or an action taken
inside your Play Console account, which is why none of it is automated and none
of it has been done for you. The assets and the build are ready; this is the
part a person does.

Read `SUBMISSION_CHECKLIST.md` first. It lists one **hard blocker** that no
amount of paperwork clears, and it is still open.

---

## 0. The blocker, before anything else

**Does Android's speech recogniser capitalise names on real hardware?**

The entity graph's only input is names arriving capitalised in transcripts.
Apple's recogniser does this. Android's varies by OEM, and if it returns
lowercase the Twin screen is empty and the product's central feature silently
does nothing — on a listing that sells exactly that feature.

The emulator cannot answer it: it ships no offline language pack, so nothing is
ever transcribed on it. The names in the store screenshots come from the seeded
demo journal.

Test it like this, on a **physical** Samsung and a **physical** Xiaomi:

1. Settings › System › Languages › Speech › Offline speech recognition —
   install the English pack.
2. Open DailyVox, record an entry that says a few names out loud:
   *"I called Sarah about the trip to Mumbai and then James rang."*
3. Open the entry. Are `Sarah`, `Mumbai` and `James` capitalised in the
   transcript, and underlined in the entry body?
4. Open the Twin tab. Are they in the sky?

If they come back lowercase, **stop**. Shipping is worse than waiting: the
listing's headline promise would be false on that hardware, and the store
review is not what would catch it — a one-star review would.

---

## 1. Generate the release signing key

Only you can do this: the key's password has to be owned by a person, and a
keystore in a chat log is a compromised keystore.

```bash
keytool -genkeypair -v -keystore ~/dailyvox-release.jks \
  -alias dailyvox -keyalg RSA -keysize 4096 -validity 10000
```

Then create `android/keystore.properties` — already gitignored, and the build
reads it automatically:

```properties
storeFile=/absolute/path/to/dailyvox-release.jks
storePassword=…
keyAlias=dailyvox
keyPassword=…
```

**Back the `.jks` up somewhere that is not this laptop before you upload
anything.** With Play App Signing enrolled the upload key is recoverable; the
enrolment has to happen first, so this ordering matters.

Verify it took:

```bash
cd android && ./gradlew :app:bundleRelease
unzip -l app/build/outputs/bundle/release/app-release.aab | grep -c 'META-INF/.*\.RSA'
```

That count is currently **0**. It must be non-zero before an upload will be
accepted.

---

## 2. Create the Play Console listing

App name, short and full description are in `STORE_LISTING.md`, already within
Play's limits (29/30, 72/80, 3,884/4,000). Paste them verbatim — the character
counts are recorded there and the full description is close to the ceiling.

Assets:

| Play field | File |
|---|---|
| Feature graphic | `assets/feature-graphic.png` (1024×500 exactly) |
| Phone screenshots | `assets/screenshots/01.png` … `08.png` (1242×2208) |
| App icon | already in the bundle |
| Privacy policy | `https://getdailyvox.com/privacy` |

Screenshot order matters. `02.png` is Android's own permission screen and is the
single most persuasive frame in the set — it is evidence rather than a claim,
and it is the one thing no App Store listing can show at all. Do not bury it.

---

## 3. Data safety and content rating

`DATA_SAFETY.md` holds the answers **and the verification method for each
claim**, which is the part worth having when Google asks you to justify one.
`CONTENT_RATING.md` holds the questionnaire answers.

Answer "no data collected" only because it is true here, and it is checkable:
there is no INTERNET permission in the merged manifest and Auto Backup is off.
Both are asserted by CI on every build.

---

## 4. The health-data declaration

Four `health.READ_*` permissions put this app in Google's **health apps review
track**. That is a form plus a wait, not a checkbox, and it is the step most
likely to add a week you did not plan for.

The manifest side is complete: the API 34+ `VIEW_PERMISSION_USAGE` activity-alias
with the `HEALTH_PERMISSIONS` category is declared, and so is the `<queries>`
entry API 33 needs to see Health Connect at all.

What the form wants is the *why*: sleep, HRV, resting heart rate and steps are
read to correlate a person's own physiology against their own journal, on their
own device, and none of it leaves the phone. Health Connect access is optional,
read-only, and not requested until the user turns Body signals on — which the
Android permission screen shows as "Health, fitness and wellness — Not allowed"
on a fresh install.

---

## 5. Internal testing track first

Never straight to production.

1. Upload the signed AAB to the **internal testing** track.
2. Read the **pre-launch report** — Google runs the app on real devices in a lab.
   This is the closest thing to the hardware test in §0 that you can get without
   owning the phones, though it is not a substitute: the lab devices may or may
   not have offline speech packs installed.
3. Install from the internal track on your own phone and record a real entry.
4. Only then promote.

---

## 6. What to say when it is live

Nothing, until it is. `SUBMISSION_CHECKLIST.md` has a standing "do not do" that
still applies: the website, `llms.txt`, README and roadmap all say Android is in
development, deliberately and in those words. When it ships, they change
together — a half-updated set is worse than an un-updated one, because it reads
as carelessness about exactly the claims this product asks to be trusted on.

---

## What is already done

- Release bundle builds clean: 5.2 MB AAB, 4.9 MB universal APK
- No INTERNET permission in the merged manifest, asserted by CI
- Auto Backup disabled, asserted by CI
- Nine permissions total, all four health ones unheld until opt-in
- 36 app unit tests, 51 engine tests, lint clean
- Eight screenshots and the feature graphic, recaptured 2026-08-25 from the
  release candidate and checked against Play's size limits
- Store listing copy, data safety answers, content rating answers
- Verified on an emulator end to end (see the checklist for what that did and
  did not prove)
