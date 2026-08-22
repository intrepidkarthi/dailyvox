#!/bin/bash
#
# Regenerate the App Store screenshot set, end to end.
#
# The last set went four releases stale because doing this was an afternoon of
# tapping. It is now one command.
#
#   ./make_screenshots.sh [device-name]
#
set -euo pipefail

DEVICE_NAME="${1:-iPhone 16 Pro Max}"     # 6.9" — 1320x2868, Apple's current base size
BUNDLE="com.dailyvox.app"
HERE="$(cd "$(dirname "$0")" && pwd)"
IOS="$HERE/../.."
RAW="$HERE/raw"
OUT="$HERE/../screenshots/iPhone_6.9_1320x2868"
DD="$(mktemp -d)/dd"

DEV=$(xcrun simctl list devices available | grep "$DEVICE_NAME (" | head -1 | grep -oE '[0-9A-F-]{36}')
[ -n "$DEV" ] || { echo "No simulator named '$DEVICE_NAME'"; exit 1; }
echo "device: $DEVICE_NAME ($DEV)"

xcrun simctl boot "$DEV" 2>/dev/null || true
xcrun simctl bootstatus "$DEV" -b >/dev/null

echo "building…"
xcodebuild -project "$IOS/solyn.xcodeproj" -scheme solyn -configuration Debug \
  -destination "id=$DEV" -derivedDataPath "$DD" build >/dev/null

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

  xcrun simctl launch "$DEV" "$BUNDLE" -ScreenshotMode "$@" >/dev/null
  sleep 5                                    # the launch seeds and folds
  xcrun simctl io "$DEV" screenshot --type=png "$RAW/$name.png" >/dev/null 2>&1
  echo "  captured $name"
}

echo "capturing…"
shoot speak    -StartTab speak
shoot twin     -StartTab twin
shoot journal  -StartTab journal
shoot entry    -StartTab journal -ScreenshotScene entry
shoot share    -StartTab journal -ScreenshotScene share
shoot settings -StartTab speak   -ScreenshotScene settings

echo "composing…"
python3 "$HERE/make_frames.py" "$RAW" "$OUT"

echo
echo "Done → $OUT"
echo "Upload these to App Store Connect as the 6.9\" set; Apple scales them"
echo "down to the smaller iPhone sizes automatically."
