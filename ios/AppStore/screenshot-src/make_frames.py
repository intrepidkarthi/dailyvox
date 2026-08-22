#!/usr/bin/env python3
"""
DailyVox App Store frames.

Drawn in the app's own language rather than around it. The previous set was a
cream gradient wash with emoji stickers, a handwriting face and slang copy
("that's the whole app", "no cap") — a different product's voice bolted onto
this one's screenshots. Everything here comes from the design system:
the palette is `DS.Palette` verbatim, the faces are the two the app actually
bundles, and there is no third font, no emoji and no 3D carnival tilt.

The set alternates NIGHT and DAY grounds down the six frames, so the row of
thumbnails in the App Store reads as a rhythm rather than six of the same
picture. Star fields appear only on the night frames — cream is paper in this
design and paper stays clean.

Usage:  python3 make_frames.py <raw-dir> <out-dir>
"""
import sys, os, math, random
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW, OUT = sys.argv[1], sys.argv[2]
HERE = os.path.dirname(os.path.abspath(__file__))
FONTS = os.path.join(HERE, "..", "..", "solyn", "Fonts")

W, H = 1320, 2868

# The device starts here on every frame and runs past the bottom edge. Fixed
# rather than derived from the headline height: six frames whose phones start at
# six different heights read as six unrelated pictures in the App Store's row.
DEVICE_TOP = 742

# DS.Palette, verbatim.
NAVY        = (16, 27, 45)
NAVY_SURF   = (28, 42, 66)
NAVY_TEXT   = (241, 237, 226)
IVORY       = (247, 243, 234)
INK         = (30, 42, 38)
INK_MUTE    = (139, 150, 144)
SAGE        = (46, 91, 68)
GOLD        = (217, 164, 65)
GOLD_NIGHT  = (237, 203, 134)
GOLD_DAY    = (138, 106, 31)


def nunito(size, weight=800):
    f = ImageFont.truetype(os.path.join(FONTS, "Nunito-Variable.ttf"), size)
    f.set_variation_by_axes([weight])
    return f


def mono(size):
    return ImageFont.truetype(os.path.join(FONTS, "DMMono-Medium.ttf"), size)


def tracked(d, xy, text, font, fill, tracking=0, anchor_centre=False):
    """DM Mono with letter-spacing. PIL has no tracking, so the run is drawn
    glyph by glyph — which is also what lets the eyebrow be centred exactly."""
    widths = [d.textlength(ch, font=font) for ch in text]
    total = sum(widths) + tracking * max(len(text) - 1, 0)
    x, y = xy
    if anchor_centre:
        x -= total / 2
    for ch, w in zip(text, widths):
        d.text((x, y), ch, font=font, fill=fill)
        x += w + tracking
    return total


def starfield(img, seed, count=190):
    """The same idea the app's sky draws: small dots, most of them faint, a few
    near enough to notice. Never a uniform grid — a regular field reads as a
    texture, and this is meant to read as depth."""
    d = ImageDraw.Draw(img, "RGBA")
    rng = random.Random(seed)
    for _ in range(count):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        r = rng.uniform(1.2, 4.4)
        a = int(rng.uniform(28, 130))
        # One in fourteen is gold — enough to warm the field without becoming
        # a second subject competing with the device.
        c = GOLD_NIGHT if rng.random() < 0.07 else NAVY_TEXT
        d.ellipse([x - r, y - r, x + r, y + r], fill=c + (a,))


def device(img, shot_path, top, night, width=985):
    """The phone, upright, running off the bottom edge of the frame.

    No rotation and no perspective: the app is a calm object, and tilting six
    screenshots at six angles is a way of being interesting instead of being
    clear. Running it past the bottom says there is more of it without saying
    so — and it removes the strip of empty ground under a fully-contained
    device, which reads as a mistake rather than as space.
    """
    shot = Image.open(shot_path).convert("RGB")
    scale = width / shot.width
    sh = int(shot.height * scale)
    shot = shot.resize((width, sh), Image.LANCZOS)

    radius = int(width * 0.135)
    pad = int(width * 0.017)
    x = (W - width) // 2

    # A cream screenshot on a cream ground has almost no edge of its own; the
    # black body carries it, but the whole object still floats. A soft cast
    # shadow gives it somewhere to sit. On navy the ground is already darker
    # than the body, so the shadow is only a faint deepening.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    gd = ImageDraw.Draw(glow)
    spread, alpha = (26, 46) if night else (34, 62)
    gd.rounded_rectangle([x - pad - spread, top - spread // 2,
                          x + width + pad + spread, top + sh + pad * 2 + spread],
                         radius=radius + pad + spread, fill=(0, 0, 0, alpha))
    glow = glow.filter(ImageFilter.GaussianBlur(46))
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB"), (0, 0))

    mask = Image.new("L", shot.size, 0)
    ImageDraw.Draw(mask).rounded_rectangle([0, 0, width, sh], radius=radius, fill=255)

    body = Image.new("RGBA", (width + pad * 2, sh + pad * 2), (0, 0, 0, 0))
    bd = ImageDraw.Draw(body)
    bd.rounded_rectangle([0, 0, body.width, body.height],
                         radius=radius + pad, fill=(11, 11, 14, 255))
    # A single hairline, not a chrome bezel stack.
    bd.rounded_rectangle([0, 0, body.width - 1, body.height - 1],
                         radius=radius + pad, outline=(92, 92, 100, 255), width=3)
    body.paste(shot, (pad, pad), mask)
    img.paste(body, (x - pad, top), body)


def headline(d, lines, top, colour, size=104, leading=1.02):
    f = nunito(size, 800)
    y = top
    for line in lines:
        d.text((W / 2, y), line, font=f, fill=colour, anchor="ma")
        y += size * leading
    return y


FRAMES = [
    # 1 — the whole product in one sentence. Day, because speaking is a daytime
    #     act in this design and the mic is green on cream.
    dict(shot="speak.png", night=False,
         eyebrow="SPEAK  ·  42 SECONDS",
         head=["Talk for a minute.", "That's the entry."],
         sub=None),

    # 2 — the differentiator, and the only frame that explains a mechanic,
    #     because the sky means nothing until someone tells you it does.
    dict(shot="twin.png", night=True,
         eyebrow="YOUR SKY",
         head=["Every night you keep", "becomes a star."],
         sub="DISTANCE IS HOW LONG AGO  ·  ANGLE IS THE HOUR"),

    # 3
    dict(shot="journal.png", night=False,
         eyebrow="YOUR JOURNAL",
         head=["What you said,", "and when you said it."],
         sub=None),

    # 4 — cream paper on a night ground. The entry screen is the one that shows
    #     the Twin's work being checkable, which is the trust argument.
    dict(shot="entry.png", night=True,
         eyebrow="WHAT YOUR TWIN FILED",
         head=["It reads every entry.", "You can check its work."],
         sub=None),

    # 5
    dict(shot="share.png", night=False,
         eyebrow="SHARE  ·  NO WORDS ON IT",
         head=["A year of your life,", "with nothing private in it."],
         sub=None, size=92),

    # 6 — the claim the whole product rests on, stated flatly.
    dict(shot="settings.png", night=True,
         eyebrow="0 NETWORK CALLS",
         head=["There is no server", "to send it to."],
         sub="TRANSCRIBED ON DEVICE  ·  NO ACCOUNT  ·  NO ANALYTICS"),
]


def build(i, spec):
    night = spec["night"]
    bg = NAVY if night else IVORY
    img = Image.new("RGB", (W, H), bg)

    if night:
        starfield(img, seed=i * 977)
    d = ImageDraw.Draw(img, "RGBA")

    eyebrow_colour = GOLD_NIGHT if night else GOLD_DAY
    head_colour = NAVY_TEXT if night else INK
    sub_colour = (NAVY_TEXT + (140,)) if night else (INK_MUTE + (255,))

    tracked(d, (W / 2, 196), spec["eyebrow"], mono(29), eyebrow_colour,
            tracking=5.5, anchor_centre=True)

    y = headline(d, spec["head"], 286, head_colour, size=spec.get("size", 104))

    if spec["sub"]:
        # 26px put this against the descenders of the line above it. A sub-line
        # is a caption on the headline, not a third line of it.
        tracked(d, (W / 2, y + 54), spec["sub"], mono(23), sub_colour,
                tracking=3.2, anchor_centre=True)
        y += 96

    # A fixed top for every frame, so the six device tops align exactly when the
    # thumbnails sit in a row. The headline block is built to fit above it.
    device(img, os.path.join(RAW, spec["shot"]), top=DEVICE_TOP, night=night)
    return img


# App Store Connect needs one iPhone set and scales it down itself, but the
# listing has historically carried all four and a missing size silently keeps an
# OLD screenshot live for that device class. Rendering at 6.9" and resampling is
# exact — every size below is the same aspect ratio (roughly 19.5:9).
SIZES = {
    "iPhone_6.9_1320x2868": (1320, 2868),
    "iPhone_6.5_1284x2778": (1284, 2778),
    "iPhone_6.3_1206x2622": (1206, 2622),
    "iPhone_6.1_1170x2532": (1170, 2532),
}

names = ["01_speak", "02_sky", "03_journal", "04_filed", "05_share", "06_private"]
base = os.path.dirname(OUT.rstrip("/"))

for i, (name, spec) in enumerate(zip(names, FRAMES), 1):
    frame = build(i, spec)
    for folder, (w, h) in SIZES.items():
        d = os.path.join(base, folder)
        os.makedirs(d, exist_ok=True)
        out = frame if (w, h) == (W, H) else frame.resize((w, h), Image.LANCZOS)
        out.save(os.path.join(d, f"{name}.png"))
    print("wrote", name, "×", len(SIZES))
