#!/bin/sh
# Render the three App Store creative assets (+ safe-area preview versions).
# Usage: sh render.sh        (from anywhere)
set -e
HERE="$(cd "$(dirname "$0")" && pwd)"
CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
mkdir -p "$HERE/preview"
render() { # variant W H out [guides]
  q="v=$1"; [ -n "$5" ] && q="$q&guides=1"
  "$CHROME" --headless --disable-gpu --hide-scrollbars --allow-file-access-from-files \
    --force-device-scale-factor=1 --virtual-time-budget=5000 \
    --window-size="$2,$3" --screenshot="$4" "file://$HERE/creative.html?$q" 2>/dev/null
  "$CHROME" --headless --disable-gpu --allow-file-access-from-files --virtual-time-budget=5000 \
    --window-size="$2,$3" --dump-dom "file://$HERE/creative.html?$q" 2>/dev/null | grep -o '<title>[^<]*' | sed "s|<title>|$1: |"
}
render universal 5244 2950 "$HERE/universal-5244x2950.png"
render header    3840 1646 "$HERE/header-3840x1646.png"
render search    3840 2560 "$HERE/search-3840x2560.png"
render universal 5244 2950 "$HERE/preview/universal-guides.png" 1 >/dev/null
render header    3840 1646 "$HERE/preview/header-guides.png" 1 >/dev/null
render search    3840 2560 "$HERE/preview/search-guides.png" 1 >/dev/null
# Apple: "Images can't include alpha channels or transparencies." Flatten to RGB.
python3 - "$HERE" <<'PY'
import sys, os
from PIL import Image
d = sys.argv[1]
for f in ["universal-5244x2950.png", "header-3840x1646.png", "search-3840x2560.png"]:
    p = os.path.join(d, f); im = Image.open(p).convert("RGB"); im.save(p, optimize=True)
    print(f, im.size, im.mode, f"{os.path.getsize(p)/1e6:.1f} MB")
PY
