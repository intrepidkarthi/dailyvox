# Play Store submission checklist

**Status: BLOCKED — do not submit.**

Assets are complete. The app is not ready, and the blockers are engineering, not
paperwork.

## Blockers

- [ ] **Recogniser capitalisation verified on physical devices.** The entity
      graph gets its input from names being capitalised in transcripts. Apple's
      recogniser does this; Android's varies by OEM and is untested on real
      hardware. If it returns lowercase, the Twin screen is empty and the
      product's central feature silently does nothing. **This alone blocks
      release.**
- [ ] Tested on real Samsung and Xiaomi hardware, not only a Pixel emulator.
      The privacy-preferring audience skews mid-tier, and that is exactly the
      hardware the emulator does not represent.
- [ ] Offline language pack behaviour confirmed on a device that lacks one. The
      error path is written and shows the Settings route, but has only been seen
      on an emulator.
- [ ] Release signing key generated and stored. Play App Signing enrolled.
- [ ] `versionCode` / `versionName` set for a real release.
- [ ] Pre-launch report reviewed after the first internal-track upload.

## Ready

- [x] Store listing copy — name 29/30, short 73/80, full 3,459/4,000 chars
- [x] Feature graphic — 1024x500 exactly
- [x] Eight phone screenshots — 1242x2208, all within Play's limits
- [x] App icon — adaptive, shipped in the APK
- [x] Data safety declaration, with the verification method recorded per claim
- [x] Content rating answers
- [x] Privacy policy — getdailyvox.com/privacy
- [x] Release build verified: 3.21 MB, no INTERNET permission
- [x] Auto Backup disabled and confirmed absent from `dumpsys package` flags

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

## Screenshot regeneration

```bash
python3 screenshot-src/compose.py     # needs Chrome; sources in screenshot-src/
```

Raw captures came from a Pixel 9 Pro emulator at 1280x2856. If the emulator's
display goes black, cold-boot it — `emulator -avd <name> -wipe-data -no-snapshot`
— rather than restarting, which does not clear a wedged window manager.
