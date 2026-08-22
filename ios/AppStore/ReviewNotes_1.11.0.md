# App Review Notes — DailyVox 1.11.0 (build 44)

## What changed in this build

**A Control Center control.** "Speak" can be added to Control Centre, the Lock
Screen controls, or the Action Button. It does **not** record from there — it
opens the app already recording, because the microphone is only ever live with
the app in the foreground. No background-audio mode is requested.

**Live Activity / Dynamic Island.** The recording Live Activity now shows a
42-second ring, the phrase currently being transcribed, a mood bar, and Finish /
Discard buttons (`LiveActivityIntent`, running in the app process). Nothing is
sent anywhere; see the privacy note below.

**Typography.** The app now bundles Nunito, Inter and DM Mono (SIL Open Font
License 1.1) rather than using the system face. Text scales with Dynamic Type,
capped at 1.6×.

**Interface.** The Record, Journal, Twin and Entry screens were reworked against
the product's design specification. The Twin's constellation now encodes real
data — distance from centre is how long ago an entry was spoken, angle is the
time of day it was spoken, size is its length.

**Sharing.** New "Tonight" and "Body" cards join the existing share cards. All
cards are rendered on the device and handed to the standard share sheet; the app
never transmits them. Names are excluded by default.

The "Body" card is the only shareable that can carry HealthKit-derived
information, and it is gated three ways: it does not appear at all unless the
user has reviewed and **kept** at least one body snapshot; it has its own switch
that is **off** each time the sheet is opened; and with that switch off the card
renders a "your body stays here" state carrying no health value. It draws sleep
hours and the app's own mood score only — heart-rate variability and resting
heart rate are never rendered on any shareable surface. To reproduce: Settings →
Body Twin, keep a snapshot, then Share → Body.

## Privacy — the part most relevant to review

**Speech is transcribed on the device, always.** This build changed
`requiresOnDeviceRecognition` to be unconditional. Previously the app allowed
Apple's server-based recognition when the device was online; it no longer does.
Where no on-device speech model is installed, transcription **fails and explains
why** rather than falling back to the network. The recording is still saved and
the user can type the entry.

To reproduce on a device without an installed model: record an entry and the app
shows "Recording Saved" with instructions to enable Dictation. This is expected
behaviour, not a defect.

**iCloud sync is user-controlled and off by default for new installs.**
Settings → iCloud Sync. When it is on, entries sync via the user's own iCloud
(CloudKit); when off, nothing leaves the device. The in-app "Data Shield" panel
states which of the two is currently true rather than asserting a fixed claim.

**No analytics, no advertising identifiers, no third-party SDKs, no accounts.**

## Permissions used

| Permission | Why |
|---|---|
| Microphone | recording voice entries |
| Speech recognition | on-device transcription only |
| Notifications | one optional local daily reminder, scheduled on-device |
| HealthKit (read) | optional body context; every signal is reviewed by the user before the app keeps it |
| Photo library | optional, user-initiated attachment and export |

No new entitlements were added in this build.

## Test account

None required. The app has no accounts and no server. Launch and record.
