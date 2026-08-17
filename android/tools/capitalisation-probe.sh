#!/usr/bin/env bash
# Answers the one question blocking an Android release:
#
#   Does this phone's speech recogniser capitalise names?
#
# The entity graph is built entirely from capitalisation evidence. Apple's
# recogniser capitalises; Android's varies by OEM, and no emulator can tell you
# what a Samsung or Xiaomi does. If it returns lowercase, the Twin screen is
# empty on that phone and the product's central feature silently does nothing.
#
# Usage:  android/tools/capitalisation-probe.sh
#
# Then speak the three sentences it prints, on the device. It reads the entries
# back out of the app's own database and shows the RAW transcript, so you can see
# the casing directly rather than inferring it from whether chips appeared.
set -euo pipefail

PKG=com.dailyvox.app
SENTENCES=(
  "I met Sarah at the ridge trail this morning."
  "James called from Portland about the timeline."
  "Priya sent photos from the wedding in Mumbai."
)

command -v adb >/dev/null || { echo "adb not on PATH"; exit 1; }
adb get-state >/dev/null 2>&1 || { echo "No device. Connect a phone with USB debugging on."; exit 1; }

MODEL=$(adb shell getprop ro.product.model | tr -d '\r')
BRAND=$(adb shell getprop ro.product.brand | tr -d '\r')
API=$(adb shell getprop ro.build.version.sdk | tr -d '\r')
echo "Device: $BRAND $MODEL (API $API)"
echo

echo "Speak these three, one entry each, then press Enter:"
for i in "${!SENTENCES[@]}"; do echo "  $((i+1)). ${SENTENCES[$i]}"; done
echo
read -r -p "Press Enter once all three are recorded... "

echo
echo "Reading the app's database..."
WORK=$(mktemp -d)
DB="$WORK/dailyvox.db"

# Room runs in WAL mode, so recent writes live in dailyvox.db-wal rather than the
# main file. Copying only the .db yields a 4096-byte header and "no such table".
# Found by running this against a real database before trusting it on a phone.
for part in "" "-wal" "-shm"; do
  adb exec-out run-as $PKG cat "databases/dailyvox.db${part}" > "${DB}${part}" 2>/dev/null || true
done

if [ ! -s "$DB" ]; then
  echo "Could not read the database. The build must be debuggable (a debug APK)."
  exit 1
fi

python3 - "$DB" <<'PY'
import sqlite3, sys, re
con = sqlite3.connect(sys.argv[1])
rows = con.execute(
    "SELECT text, entities FROM entries ORDER BY createdAt DESC LIMIT 3"
).fetchall()

if not rows:
    print("No entries found. Were the three recorded?")
    sys.exit(1)

EXPECTED = {"sarah", "james", "portland", "priya", "mumbai", "ridge", "trail"}
print("=" * 68)
capitalised_any = False
for text, entities in reversed(rows):
    print(f"\nTRANSCRIPT: {text}")
    print(f"FILED     : {entities or '(nothing)'}")
    # Which expected names appear, and how are they cased?
    for w in re.findall(r"[A-Za-z]+", text):
        if w.lower() in EXPECTED:
            state = "CAPITALISED" if w[0].isupper() else "lowercase"
            if w[0].isupper():
                capitalised_any = True
            print(f"   {w!r:14} -> {state}")

print("\n" + "=" * 68)
if capitalised_any:
    print("VERDICT: this recogniser capitalises names.")
    print("The entity graph has the input it needs on this device.")
else:
    print("VERDICT: NO capitalisation seen.")
    print("On this device the entity graph gets NOTHING, and the Twin screen")
    print("will be empty however many entries are recorded. This is the")
    print("documented release blocker, not a bug in the detector.")
print("=" * 68)
PY
