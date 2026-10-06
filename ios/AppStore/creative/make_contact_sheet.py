#!/usr/bin/env python3
"""Contact sheet: each deliverable with Apple's art safe area outlined (preview only)."""
import os
from PIL import Image, ImageDraw, ImageFont
HERE = os.path.dirname(os.path.abspath(__file__))
SAFE = {  # from Apple's official PSD templates ("Art Safe Area" layer bbox)
    "universal-5244x2950.png": (1921, 660, 1402, 962),
    "header-3840x1646.png": (1097, 493, 1646, 661),
    "search-3840x2560.png": (836, 765, 2168, 1030),
}
font = ImageFont.truetype(os.path.join(HERE, "../../../android/app/src/main/res/font/dm_mono_medium.ttf"), 26)
W = 1500
tiles = []
for f, (x, y, w, h) in SAFE.items():
    im = Image.open(os.path.join(HERE, f)).convert("RGB")
    s = W / im.width
    t = im.resize((W, round(im.height * s)), Image.LANCZOS)
    d = ImageDraw.Draw(t)
    d.rectangle((x * s, y * s, (x + w) * s, (y + h) * s), outline=(57, 255, 106), width=4)
    if f.startswith("universal"):
        # INFERRED, not from Apple: centred 21:9 and 3:2 crops of the 16:9 canvas.
        for ar, col in ((21 / 9, (255, 120, 120)), (3 / 2, (120, 180, 255))):
            ch = im.width / ar if im.width / ar <= im.height else im.height
            cw = ch * ar
            cx0, cy0 = (im.width - cw) / 2, (im.height - ch) / 2
            d.rectangle((cx0 * s, cy0 * s, (cx0 + cw) * s, (cy0 + ch) * s), outline=col, width=3)
    tiles.append((f, t))
H = sum(t.height + 60 for _, t in tiles) + 80
sheet = Image.new("RGB", (W + 60, H), (40, 40, 44))
d = ImageDraw.Draw(sheet)
yy = 20
for f, t in tiles:
    note = f"{f}  green = Apple safe area"
    if f.startswith("universal"):
        note += "  red/blue = 21:9 / 3:2 centre crops, INFERRED"
    d.text((30, yy), note, fill=(235, 235, 235), font=font)
    sheet.paste(t, (30, yy + 40))
    yy += t.height + 60
os.makedirs(os.path.join(HERE, "preview"), exist_ok=True)
sheet.save(os.path.join(HERE, "preview", "contact-sheet.png"))
print("preview/contact-sheet.png", sheet.size)
