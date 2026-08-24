# Play Console — Data safety declaration

**This form is a binding declaration to Google, not marketing copy.** A wrong
answer is grounds for removal, so every line below is written to be defensible
against the actual code, and the verification method is recorded next to it.

---

## Section 1 — Data collection and sharing

| Question | Answer |
|---|---|
| Does your app collect or share any of the required user data types? | **No** |
| Is all of the user data collected by your app encrypted in transit? | *N/A — nothing is transmitted* |
| Do you provide a way for users to request that their data is deleted? | **Yes** |

### Why "No" is the correct answer, and how to check it

Play defines *collection* as transmitting data off the device. DailyVox cannot
transmit anything: the app holds **no `INTERNET` permission**. This is not a
policy we follow, it is a capability we do not have.

```bash
# The complete permission list in the built artifact:
aapt dump permissions app-release.apk
#   uses-permission: android.permission.RECORD_AUDIO
#   uses-permission: android.permission.POST_NOTIFICATIONS
#   uses-permission: android.permission.VIBRATE
#   uses-permission: android.permission.USE_BIOMETRIC
#   uses-permission: android.permission.USE_FINGERPRINT
#   (+ health.READ_* only when Body signals is enabled by the user)
```

There is no `INTERNET` line. An app without it cannot open a socket, so no
third-party SDK inside it could exfiltrate anything either — which is also why
there are no analytics or crash-reporting SDKs to declare.

### Deletion

Entries are deleted individually in the app. All data is removed by uninstalling
or by Android Settings → Apps → DailyVox → Clear storage. There is no server
copy to request deletion of, because there is no server.

---

## Section 2 — Data types, declared for completeness

Play only requires declarations for *collected* data. Nothing here is collected,
so nothing is declared. Recorded for the reviewer's benefit, this is what the app
handles and where it stays:

| Data | Where it lives | Leaves the device? |
|---|---|---|
| Voice recordings | app-private internal storage | No |
| Transcripts | local Room database | No |
| Derived mood, names, prosody | local Room database | No |
| Health data (opt-in) | read from Health Connect, stored locally | No |
| Photos attached to entries | copied into app-private storage | No |
| Exports and backups | **only where the user chooses to save them** | Only by the user's own action |

The last row is the one worth stating plainly. Export writes through the Storage
Access Framework to a location the user picks. If they pick a cloud folder, the
file goes to that cloud — because they put it there. The app does not upload it,
and cannot.

---

## Section 3 — Android Auto Backup

**Disabled** (`allowBackup="false"`, `data_extraction_rules.xml`).

This is worth flagging to a reviewer because the default is the opposite. Left
at its default, Android Auto Backup copies `filesDir` — the journal database and
every audio recording — to the user's Google Drive. The **system** performs that
copy, so it needs no permission from the app. Every claim above would have
remained technically true while the diary sat on a Google server.

Device-to-device transfer during new-phone setup is left enabled: it is a local
transfer, and silently losing a diary when changing phones is its own harm.

---

## Section 4 — Health Connect (Play's health data policy)

| Question | Answer |
|---|---|
| Which Health Connect data types? | Sleep, Heart rate variability (RMSSD), Resting heart rate, Steps |
| Read or write? | **Read only.** The app never writes to Health Connect |
| Purpose | Correlating the user's own physiology against their own journal, on-device |
| Shared with third parties? | **No** — impossible, see Section 1 |
| Required to use the app? | **No.** Fully optional; everything else works untouched |

The app requests exactly the four types it reads. Play's health policy requires
that the requested set match the used set, and a broader request would be both a
violation and indefensible on a screen that prints every permission the app
holds.

---

## Verified

| Claim | How it was checked |
|---|---|
| No INTERNET permission | merged manifest + `dumpsys package` on device |
| Works fully offline | airplane mode, fresh install, full journey exercised |
| Speech never goes to a network | code: `SpeechCapture` constructs `createOnDeviceSpeechRecognizer` and nothing else. **Note what airplane mode cannot check** — until 2026-08-24 a fallback branch sent audio to the platform recognizer, and with no network there was nothing for it to leak to, so the offline test passed on exactly the phones that were leaking. minSdk 33 now guarantees the on-device recognizer exists. |
| Auto Backup off | `ALLOW_BACKUP` absent from `dumpsys package` flags |
| Health permissions not held until opt-in | `dumpsys package` shows `granted=false` for all four |
