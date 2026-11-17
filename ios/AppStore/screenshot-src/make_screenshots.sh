#!/bin/bash
#
# Regenerate the App Store screenshot set, end to end.
#
# The last set went four releases stale because doing this was an afternoon of
# tapping. It is now one command.
#
#   ./make_screenshots.sh [device-name]
#   LOCALE=de-DE ./make_screenshots.sh     # one localized set (1.14)
#   SKIP_BUILD=1 LOCALE=fr-FR ./make_screenshots.sh
#
# A localized run reads its journal, canned search/Ask/typed text from
# locales/<LOCALE>/seed.json and its captions from locales/<LOCALE>/captions.json,
# runs the app in that language, and writes raw/<LOCALE> and
# ../screenshots/<LOCALE>/<size>. Without LOCALE it is the English set, unchanged.
#
set -euo pipefail

DEVICE_NAME="${1:-iPhone 16 Pro Max}"     # 6.9" — 1320x2868, Apple's current base size
BUNDLE="com.dailyvox.app"
HERE="$(cd "$(dirname "$0")" && pwd)"
IOS="$HERE/../.."
LOCALE="${LOCALE:-}"
DD="${DD:-$HERE/.dd}"
if [ -n "$LOCALE" ]; then
  RAW="$HERE/raw/$LOCALE"
  OUT="$HERE/../screenshots/$LOCALE/iPhone_6.9_1320x2868"
  SEED="$HERE/locales/$LOCALE/seed.json"
  [ -f "$SEED" ] || { echo "No seed for $LOCALE at $SEED"; exit 1; }
  LANG_CODE="${LOCALE%%-*}"
  REGION="${LOCALE/-/_}"
  case "$LOCALE" in
    pt-BR) LANG_CODE="pt-BR" ;;          # Portuguese the app ships is Brazil's
    it)    REGION="it_IT" ;;             # App Store's code for Italian has no region
  esac
  # The app's language, the region's formats (dates, "Okt."), and the journal.
  LOCALE_ARGS=(-AppleLanguages "($LANG_CODE)" -AppleLocale "$REGION" -ScreenshotSeedFile "$SEED")
else
  RAW="$HERE/raw"
  OUT="$HERE/../screenshots/iPhone_6.9_1320x2868"
  LOCALE_ARGS=()
fi

DEV=$(xcrun simctl list devices available | grep "$DEVICE_NAME (" | head -1 | grep -oE '[0-9A-F-]{36}')
[ -n "$DEV" ] || { echo "No simulator named '$DEVICE_NAME'"; exit 1; }
echo "device: $DEVICE_NAME ($DEV)"

xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b >/dev/null

if [ -z "${SKIP_BUILD:-}" ]; then
echo "building…"
xcodebuild -project "$IOS/solyn.xcodeproj" -scheme solyn -configuration Debug \
  -destination "id=$DEV" -derivedDataPath "$DD" build >/dev/null
fi

APP="$DD/Build/Products/Debug-iphonesimulator/solyn.app"

mkdir -p "$RAW"
shoot () {
  local name="$1"; shift

  # A FRESH CONTAINER PER SHOT, not per run.
  #
  # The seeder folds its 35 entries into whatever Twin state already exists,
  # and re-`configure`-ing the engines reloads on top rather than resetting.
  # So the second launch shows a Twin badge reading 70 over a journal of 35,
  # the third 105, the fourth 140 — and the numbers drift between frames of
  # the same set. Reinstalling costs a few seconds and removes the class.
  xcrun simctl uninstall "$DEV" "$BUNDLE" 2>/dev/null || true
  xcrun simctl install "$DEV" "$APP"

  # 9:41, full bars, charged — Apple's own convention, and it keeps a live
  # clock or a real battery percentage from dating the set. Re-applied after
  # each install, because uninstalling clears the override.
  xcrun simctl status_bar "$DEV" override \
    --time "9:41" --batteryState charged --batteryLevel 100 --cellularBars 4 --wifiBars 3

  # The Night theme, pinned. The default theme (Sunset) follows the real
  # clock, so a set shot in the morning came out in Day colours next to a set
  # shot the evening before in Night ones. THEME=Day re-shoots in daylight.
  xcrun simctl launch "$DEV" "$BUNDLE" -ScreenshotMode -selectedTheme "${THEME:-Night}" \
    ${LOCALE_ARGS[@]+"${LOCALE_ARGS[@]}"} "$@" >/dev/null
  sleep "${WAIT:-5}"                         # the launch seeds and folds
  xcrun simctl io "$DEV" screenshot --type=png "$RAW/$name.png" >/dev/null 2>&1
  echo "  captured $name"
}

echo "capturing…"
# One per store frame in the canvas (S1–S7), plus the surfaces the earlier
# in-app set used.
shoot twin      -StartTab twin                            # S1  a sky made of you
shoot speak     -StartTab speak                           # S2  42 seconds is the app
# Ask fades its answer in; at 5 s the 2026-10-06 capture caught it half-drawn.
WAIT=14 shoot ask -StartTab ask -ScreenshotScene ask     # S3  answers with receipts
shoot search    -StartTab journal -ScreenshotScene search # S4  describe it, find it
shoot insights  -StartTab twin   -ScreenshotScene insights # S5 it spots the streak
shoot settings  -StartTab speak  -ScreenshotScene settings # S6 private by design
shoot recording -StartTab speak  -ScreenshotScene recording # S7 speak once
shoot typing    -StartTab speak  -ScreenshotScene typing    # S8 can't talk? type it

# Not in the store set, but captured so the raw folder covers every surface a
# future frame might want.
shoot journal   -StartTab journal
shoot entry     -StartTab journal -ScreenshotScene entry
shoot share     -StartTab journal -ScreenshotScene share

echo "composing…"
python3 "$HERE/make_frames.py" "$RAW" "$OUT" ${LOCALE:+"$LOCALE"}

echo
echo "Done → $OUT"
echo "Upload these to App Store Connect as the 6.9\" set; Apple scales them"
echo "down to the smaller iPhone sizes automatically."
