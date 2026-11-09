#!/bin/sh
# Renders card.html to public/og-image.png at 1200x630 with headless Chrome.
cd "$(dirname "$0")"
"/Applications/Google Chrome.app/Contents/MacOS/Google Chrome" --headless=new --disable-gpu --hide-scrollbars \
  --allow-file-access-from-files --force-device-scale-factor=1 --window-size=1200,630 --virtual-time-budget=8000 \
  --screenshot="$PWD/../../public/og-image.png" "file://$PWD/card.html" 2>/dev/null
