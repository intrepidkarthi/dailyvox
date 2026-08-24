#!/usr/bin/env python3
"""
The social card — 1200x630 for Open Graph and Twitter.

Same language as the App Store frames and the site hero: navy ground, star
field, Nunito headline with one word in gold, DM Mono eyebrow, a Caveat gloss,
and a real screenshot rather than a mockup. Landscape rather than portrait, so
the phone sits beside the words instead of under them.

Usage:  python3 make_og.py <raw-dir> <out.png>
"""
import sys, os, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
APP_FONTS = os.path.join(HERE, "..", "..", "solyn", "Fonts")
OWN_FONTS = os.path.join(HERE, "fonts")

W, H = 1200, 630
NAVY, NAVY_TEXT = (16, 27, 45), (241, 237, 226)
GOLD, GOLD_NIGHT = (217, 164, 65), (237, 203, 134)


def nunito(sz, wt=800):
    f = ImageFont.truetype(os.path.join(APP_FONTS, "Nunito-Variable.ttf"), sz)
    f.set_variation_by_axes([wt]); return f

def mono(sz):  return ImageFont.truetype(os.path.join(APP_FONTS, "DMMono-Medium.ttf"), sz)
def caveat(sz): return ImageFont.truetype(os.path.join(OWN_FONTS, "Caveat-SemiBold.ttf"), sz)


def tracked(d, xy, text, f, fill, tracking=0):
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=f, fill=fill); x += d.textlength(ch, font=f) + tracking
    return x - xy[0]


img = Image.new("RGB", (W, H), NAVY)

# star field — the app's own sky, continued onto the card
sd = ImageDraw.Draw(img, "RGBA")
rng = random.Random(4242)
for _ in range(150):
    x, y = rng.uniform(0, W), rng.uniform(0, H)
    r = rng.uniform(0.9, 2.9)
    a = int(rng.uniform(26, 125))
    c = GOLD_NIGHT if rng.random() < 0.08 else NAVY_TEXT
    sd.ellipse([x - r, y - r, x + r, y + r], fill=c + (a,))

# a warm bloom behind the device, so the phone is lit rather than pasted
glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
ImageDraw.Draw(glow).ellipse([W * 0.55, -120, W * 1.12, H + 120], fill=GOLD + (30,))
img = Image.alpha_composite(img.convert("RGBA"), glow.filter(ImageFilter.GaussianBlur(90))).convert("RGB")

d = ImageDraw.Draw(img)
L = 74

tracked(d, (L, 96), "FREE  ·  ON-DEVICE  ·  NO ACCOUNT", mono(20), GOLD_NIGHT, tracking=3.4)

y = 146
for line, hot in [("Your voice builds", None), ("a Digital Twin", None), ("that ", "knows you.")]:
    f = nunito(58)
    x = L
    d.text((x, y), line, font=f, fill=NAVY_TEXT)
    if hot:
        d.text((x + d.textlength(line, font=f), y), hot, font=f, fill=GOLD_NIGHT)
    y += 70

d.text((L, y + 16), "42 seconds a day. Nothing leaves the phone.",
       font=caveat(34), fill=tuple(int(c * .82) for c in NAVY_TEXT))

# wordmark
wm = nunito(30, 800)
d.text((L, H - 74), "DailyVox", font=wm, fill=NAVY_TEXT)
sx = L + d.textlength("DailyVox", font=wm) + 14
d.polygon([(sx + 11, H - 72), (sx + 14, H - 62), (sx + 24, H - 59),
           (sx + 14, H - 56), (sx + 11, H - 46), (sx + 8, H - 56),
           (sx - 2, H - 59), (sx + 8, H - 62)], fill=GOLD)
tracked(d, (L, H - 38), "GETDAILYVOX.COM", mono(16),
        tuple(int(c * .6) for c in NAVY_TEXT), tracking=2.4)

# the device: a real screenshot, tilted off the right edge
shot = Image.open(os.path.join(RAW, "twin.png")).convert("RGB")
pw = 300
shot = shot.resize((pw, round(shot.height * (pw / shot.width))), Image.LANCZOS)
radius = 34
mask = Image.new("L", shot.size, 0)
ImageDraw.Draw(mask).rounded_rectangle([0, 0, shot.width, shot.height], radius=radius, fill=255)

pad = 6
body = Image.new("RGBA", (shot.width + pad * 2, shot.height + pad * 2), (0, 0, 0, 0))
bd = ImageDraw.Draw(body)
bd.rounded_rectangle([0, 0, body.width, body.height], radius=radius + pad, fill=(11, 11, 14, 255))
bd.rounded_rectangle([0, 0, body.width - 1, body.height - 1], radius=radius + pad,
                     outline=(96, 96, 104, 255), width=2)
body.paste(shot, (pad, pad), mask)
body = body.rotate(-7, expand=True, resample=Image.BICUBIC)

shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
px, py = int(W * 0.66), -40
shadow.paste((0, 0, 0, 120), (px + 6, py + 22), body.split()[3])
img = Image.alpha_composite(img.convert("RGBA"),
                            shadow.filter(ImageFilter.GaussianBlur(26))).convert("RGB")
img.paste(body, (px, py), body)

img.save(OUT, "PNG", optimize=True)
print("wrote", OUT, img.size, os.path.getsize(OUT) // 1024, "KB")
