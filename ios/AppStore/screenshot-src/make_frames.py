#!/usr/bin/env python3
"""
DailyVox App Store frames, built to the store canvas.

The design is `DailyVox Store Images.dc.html` in the Claude Design project —
seven frames, S1 to S7. This renders that layout at 3x with REAL app
screenshots inside the phone, rather than the canvas's hand-drawn
approximations of them.

The canvas specifies, per frame: a saturated ground of its own, a DM Mono
eyebrow, a Nunito 900 headline with one word in the frame's accent colour, a
large figure with a handwritten Caveat gloss beside it, a phone cropped by the
bottom edge, and one rotated sticker overlapping the device.

Everything is measured from the canvas at 440x956 and multiplied by S=3.

Usage:  python3 make_frames.py <raw-dir> <out-dir> [locale]

With a locale (1.14), the copy comes from locales/<locale>/captions.json and
the frame list from LOCALE_FRAMES below; layout, grounds and stickers' colours
and positions stay the English set's.
"""
import sys, os, json
from PIL import Image, ImageDraw, ImageFont, ImageFilter

RAW, OUT = sys.argv[1], sys.argv[2]
LOCALE = sys.argv[3] if len(sys.argv) > 3 else None
HERE = os.path.dirname(os.path.abspath(__file__))
APP_FONTS = os.path.join(HERE, "..", "..", "solyn", "Fonts")
OWN_FONTS = os.path.join(HERE, "fonts")

S = 3                       # canvas is drawn at 440x956; the store wants 1320x2868
W, H = 440 * S, 956 * S

# Phone plate: .stph { left:40 right:40 top:392 bottom:-24; radius 40 40 0 0 }
PH_X, PH_TOP = 40 * S, 392 * S
PH_W = W - 80 * S
PH_RADIUS = 40 * S


def font(path, size, weight=None):
    f = ImageFont.truetype(path, size)
    if weight is not None:
        f.set_variation_by_axes([weight])
    return f


def nunito(size, weight=900):
    return font(os.path.join(APP_FONTS, "Nunito-Variable.ttf"), size, weight)


def mono(size):
    return ImageFont.truetype(os.path.join(APP_FONTS, "DMMono-Medium.ttf"), size)


def caveat(size):
    return ImageFont.truetype(os.path.join(OWN_FONTS, "Caveat-SemiBold.ttf"), size)


def tracked(d, xy, text, f, fill, tracking=0):
    """Letter-spaced runs. PIL has no tracking, and the canvas leans on it hard
    for the mono eyebrows (.18em)."""
    x, y = xy
    for ch in text:
        d.text((x, y), ch, font=f, fill=fill)
        x += d.textlength(ch, font=f) + tracking
    return x - xy[0]


def rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def phone(img, shot_path, anchor="top"):
    """The device plate: full-bleed screenshot, rounded at the top only, running
    off the bottom of the frame. The canvas gives it no bezel — the screen IS
    the plate — which is why these read as posters rather than product shots.

    `anchor` decides which end of the screen survives the crop. It defaults to
    the top, which is right for every frame but one: the Speak screen docks its
    microphone at the BOTTOM (that is the whole point — thumb reach), so a
    top-anchored crop of the frame captioned "42 seconds is the app" would show
    everything except the button it is talking about.
    """
    shot = Image.open(shot_path).convert("RGB")
    h = int(shot.height * (PH_W / shot.width))
    shot = shot.resize((PH_W, h), Image.LANCZOS)

    visible = H - PH_TOP + 24 * S          # bottom:-24 → it overruns the frame
    if h > visible:
        top = 0 if anchor == "top" else h - visible
        shot = shot.crop((0, top, PH_W, top + visible))
    h = shot.height

    # box-shadow: 0 -6px 40px rgba(0,0,0,.25) — light from below, so the plate
    # lifts off the ground instead of sitting on it.
    glow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    ImageDraw.Draw(glow).rounded_rectangle(
        [PH_X - 6 * S, PH_TOP - 6 * S, PH_X + PH_W + 6 * S, PH_TOP + h],
        radius=PH_RADIUS + 6 * S, fill=(0, 0, 0, 64))
    glow = glow.filter(ImageFilter.GaussianBlur(40 * S / 3))
    img.paste(Image.alpha_composite(img.convert("RGBA"), glow).convert("RGB"), (0, 0))

    mask = Image.new("L", (PH_W, h), 0)
    md = ImageDraw.Draw(mask)
    md.rounded_rectangle([0, 0, PH_W, h + PH_RADIUS], radius=PH_RADIUS, fill=255)
    img.paste(shot, (PH_X, PH_TOP), mask)


def sticker(img, spec):
    """.stick — a rotated card overlapping the device. Rendered oversized and
    rotated with bicubic resampling, because a 3-4 degree rotation on hard type
    aliases badly otherwise."""
    title, sub, bg, fg, sub_fg, rot, pos = (
        spec["title"], spec["sub"], rgb(spec["bg"]), rgb(spec["fg"]),
        spec.get("sub_fg"), spec["rot"], spec["pos"])
    sub_fg = rgb(sub_fg) if sub_fg else tuple(int(c * 0.62 + 255 * 0.0) for c in fg)

    ft, fs = nunito(15 * S, 800), caveat(17 * S)
    probe = ImageDraw.Draw(Image.new("RGB", (1, 1)))
    tw = max(probe.textlength(title, font=ft), probe.textlength(sub, font=fs))
    pad_x, pad_y = 14 * S, 10 * S
    cw, ch = int(tw + pad_x * 2), int(ft.size * 1.2 + fs.size * 1.05 + pad_y * 2)

    card = Image.new("RGBA", (cw, ch), (0, 0, 0, 0))
    cd = ImageDraw.Draw(card)
    cd.rounded_rectangle([0, 0, cw, ch], radius=14 * S, fill=bg + (255,))
    cd.text((pad_x, pad_y), title, font=ft, fill=fg + (255,))
    cd.text((pad_x, pad_y + ft.size * 1.18), sub, font=fs, fill=sub_fg + (255,))

    card = card.rotate(rot, expand=True, resample=Image.BICUBIC)

    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    x, y = pos
    # A longer translation must not push the card off the right edge.
    x = min(x, W - card.width - 16 * S)
    shadow.paste((0, 0, 0, 46), (x, y + 6 * S), card.split()[3])
    shadow = shadow.filter(ImageFilter.GaussianBlur(18 * S / 3))
    img.paste(Image.alpha_composite(img.convert("RGBA"), shadow).convert("RGB"), (0, 0))
    img.paste(card, (x, y), card)


# ---------------------------------------------------------------- the frames
#
# Ground, accent and copy are the canvas's, verbatim. The numbers are NOT: the
# canvas says "213 stars" in the headline over a phone reading "140 ✦", and the
# app is the thing being advertised, so every figure here matches what the
# seeded screenshot beneath it actually shows.
FRAMES = [
    dict(name="01_a_sky_made_of_you", shot="twin.png",
         bg="#221B4A", fg="#F1EDE2", accent="#D9A441",
         eyebrow="MEET YOUR TWIN",
         head=[("a sky", None), ("made of ", "you")],
         figure="35", gloss="stars in your sky",
         sticker=dict(title="100% on-device", sub="no cloud, no account",
                      bg="#D9A441", fg="#101B2D", rot=-4, pos=(int(250 * 3), int(344 * 3)))),

    dict(name="02_42_seconds", shot="speak.png",
         bg="#1D5038", fg="#F7F3EA", accent="#A9E58B",
         eyebrow="JUST TALK",
         head=[(None, "42 seconds"), ("is the app", None)],
         figure="0:42", gloss="the whole ritual", anchor="bottom",
         sticker=dict(title="your voice", sub="transcribed on this phone",
                      bg="#F7F3EA", fg="#1E2A26", rot=4, pos=(int(24 * 3), int(352 * 3)))),

    dict(name="03_answers_with_receipts", shot="ask.png",
         bg="#A34324", fg="#FBF3EA", accent="#F2C879",
         eyebrow="ASK YOUR TWIN",
         head=[("answers with", None), (None, "receipts")],
         figure=None, gloss="3 entries cited, every time",
         sticker=dict(title="3 entries cited", sub="tap any to read it",
                      bg="#D9A441", fg="#101B2D", rot=-3, pos=(int(228 * 3), int(300 * 3)))),

    dict(name="04_describe_find", shot="search.png",
         bg="#3A3153", fg="#F7F3EA", accent="#B9A5F2",
         eyebrow="SEARCH BY MEANING",
         head=[("describe it,", None), (None, "find it")],
         figure=None, gloss="words you never typed",
         sticker=dict(title="49% match", sub="on words you never typed",
                      bg="#F7F3EA", fg="#1E2A26", rot=3, pos=(int(44 * 3), int(308 * 3)))),

    dict(name="05_streak", shot="insights.png",
         bg="#0F3E46", fg="#F1EDE2", accent="#D9A441",
         eyebrow="YOUR PATTERNS",
         head=[("it spots the", None), (None, "streak"), (" first", None)],
         figure="32", gloss="days in a row, your longest",
         sticker=dict(title="32-day streak", sub="your longest yet",
                      bg="#5ECCD3", fg="#0F3E46", rot=-4, pos=(int(246 * 3), int(346 * 3)))),

    dict(name="06_private_by_design", shot="settings.png",
         bg="#571F14", fg="#FBF3EA", accent="#F2B279",
         eyebrow="PRIVATE BY DESIGN",
         head=[("your diary,", None), (None, "yours only")],
         figure="0", figure_colour="#F08465", gloss="DailyVox servers exist",
         sticker=dict(title="on-device, always", sub="Data Not Collected",
                      bg="#101B2D", fg="#F1EDE2", sub_fg="#EDCB86",
                      rot=-3, pos=(int(238 * 3), int(348 * 3)))),

    dict(name="07_first_star", shot="recording.png",
         bg="#16342B", fg="#F7F3EA", accent="#F2C14E",
         eyebrow="YOUR FIRST 42S",
         head=[("speak once,", None), ("watch it ", "ignite")],
         figure="1", gloss="star. then a sky.",
         sticker=dict(title="your first star", sub="born from your voice",
                      bg="#D9A441", fg="#101B2D", rot=4, pos=(int(24 * 3), int(520 * 3)))),

    # 1.12. Asked for by a user who journals at work and at home, around people,
    # where speaking out loud is not an option.
    dict(name="08_cant_talk_type_it", shot="typing.png",
         bg="#14385C", fg="#F1EDE2", accent="#8FD3FF",
         eyebrow="CAN'T TALK RIGHT NOW?",
         head=[("then type", None), (None, "instead")],
         figure=None, gloss="it counts just the same",
         sticker=dict(title="typed, not recorded", sub="still counts for your streak",
                      bg="#F7F3EA", fg="#1E2A26", rot=-3, pos=(int(196 * 3), int(760 * 3)))),

    dict(name="09_share_a_star", shot="share.png",
         bg="#5A2341", fg="#FBF3EA", accent="#F2B6C8",
         eyebrow="SHARE A STAR",
         head=[("your sky,", None), (None, "not your words")],
         figure="35", gloss="nights kept, on the card",
         sticker=dict(title="no words on it", sub="ever",
                      bg="#D9A441", fg="#101B2D", rot=4, pos=(int(24 * 3), int(420 * 3)))),

    dict(name="10_every_night_kept", shot="journal.png",
         bg="#3D3410", fg="#F7F3EA", accent="#F2C14E",
         eyebrow="YOUR JOURNAL",
         head=[("every night,", None), (None, "kept")],
         figure=None, gloss="a colour for every mood",
         sticker=dict(title="mood at a glance", sub="one line per entry",
                      bg="#F7F3EA", fg="#1E2A26", rot=-4, pos=(int(246 * 3), int(380 * 3)))),
]


def build(spec):
    bg, fg, accent = rgb(spec["bg"]), rgb(spec["fg"]), rgb(spec["accent"])
    img = Image.new("RGB", (W, H), bg)
    d = ImageDraw.Draw(img)

    pad_l, pad_t = 44 * S, 64 * S

    # eyebrow — DM Mono 600 13px, letter-spacing .18em
    tracked(d, (pad_l, pad_t), spec["eyebrow"], mono(13 * S), accent,
            tracking=13 * S * 0.18)

    # headline — Nunito 900 52px/1.08, one word in the accent. English was
    # written to fit; German compounds are not, so the size steps down until
    # the longest line clears the right margin (the same 44px as the left).
    size = 52
    while size > 36:
        fh = nunito(size * S)
        widest = max(d.textlength((p or "") + (h or ""), font=fh) for p, h in spec["head"])
        if widest <= W - 2 * pad_l:
            break
        size -= 2
    fh = nunito(size * S)
    y = pad_t + 18 * S + 13 * S
    for line in spec["head"]:
        x = pad_l
        plain, hot = line
        if plain:
            d.text((x, y), plain, font=fh, fill=fg)
            x += d.textlength(plain, font=fh)
        if hot:
            d.text((x, y), hot, font=fh, fill=accent)
        y += size * S * 1.08

    # figure + handwritten gloss, sharing a baseline
    y += 26 * S - 8 * S
    if spec.get("figure"):
        ff = nunito(64 * S)
        fc = rgb(spec.get("figure_colour", spec["accent"]))
        d.text((pad_l, y), spec["figure"], font=ff, fill=fc)
        gx = pad_l + d.textlength(spec["figure"], font=ff) + 14 * S
        gy = y + ff.size * 0.42
    else:
        gx, gy = pad_l, y + 6 * S
    fg_gloss = tuple(int(c * 0.85 + bg[i] * 0.15) for i, c in enumerate(fg))
    gs = 26
    while gs > 18 and gx + d.textlength(spec["gloss"], font=caveat(gs * S)) > W - pad_l:
        gs -= 1
    d.text((gx, gy), spec["gloss"], font=caveat(gs * S), fill=fg_gloss)

    phone(img, os.path.join(RAW, spec["shot"]), spec.get("anchor", "top"))
    sticker(img, spec["sticker"])
    return img


SIZES = {
    "iPhone_6.9_1320x2868": (1320, 2868),
    "iPhone_6.5_1284x2778": (1284, 2778),
    "iPhone_6.3_1206x2622": (1206, 2622),
    "iPhone_6.1_1170x2532": (1170, 2532),
    # The ONE size App Store Connect requires as of October 2026 ("iPhone with
    # Dynamic Island, medium display"); the others are optional or scaled from it.
    "iPhone_DI_medium_1179x2556": (1179, 2556),
}

# ---------------------------------------------------------------- locales
#
# What each localized set shows, in store order. App Store Connect takes ten
# per locale. Every frame here was checked against that locale's capture: the
# app is quiet where it cannot read a language, so the sets differ.
#
#   · 00 leads: the language is the news for these users. It sits over the
#     journal in that language, not the Language-you-speak picker, which lists
#     every language Apple can transcribe and would claim far more than five.
#   · 04 is captioned for WORD search (meaning search is English-only) but
#     left out for now: the search screen itself is still titled "Search by
#     meaning" and shows match percentages in every language. It comes back
#     when that screen says what it does.
#   · 03 Ask your Twin is left out everywhere for now. The engine's answer
#     frame is English ("From your journal, the closest I have to that is…",
#     and the abstention line), so a German question gets an English answer
#     around German quotes. It comes back once those lines are localized, and
#     never for pt-BR, which the app does not name as an Ask language (#127).
#   · 10 drops: 00 already shows the journal.
LANGUAGE_FRAME = dict(name="00_your_language", shot="journal.png",
                      bg="#2A2357", fg="#F1EDE2", accent="#F2C14E",
                      sticker=dict(bg="#D9A441", fg="#101B2D", rot=-4,
                                   pos=(int(232 * 3), int(560 * 3))))
LOCALE_FRAMES = {
    "default": ["00_your_language", "01_a_sky_made_of_you", "02_42_seconds",
                "05_streak", "06_private_by_design",
                "08_cant_talk_type_it", "09_share_a_star", "07_first_star"],
}


def localized(locale):
    with open(os.path.join(HERE, "locales", locale, "captions.json"), encoding="utf-8") as f:
        copy = json.load(f)
    by_name = {f["name"]: f for f in FRAMES + [LANGUAGE_FRAME]}
    out = []
    for i, name in enumerate(LOCALE_FRAMES.get(locale, LOCALE_FRAMES["default"]), 1):
        c = copy[name]
        spec = dict(by_name[name])
        spec.update(eyebrow=c["eyebrow"], head=[tuple(l) for l in c["head"]],
                    figure=c.get("figure"), gloss=c["gloss"])
        spec["sticker"] = dict(spec["sticker"], title=c["sticker"]["title"], sub=c["sticker"]["sub"])
        # Store order is the file order, so the numbers are renumbered per set.
        spec["out"] = "%02d_%s" % (i, name.split("_", 1)[1])
        out.append(spec)
    return out


# A localized set is uploaded at the required size and the 6.9" base only.
if LOCALE:
    FRAMES = localized(LOCALE)
    SIZES = {k: v for k, v in SIZES.items()
             if k in ("iPhone_6.9_1320x2868", "iPhone_DI_medium_1179x2556")}

base = os.path.dirname(OUT.rstrip("/"))
for spec in FRAMES:
    frame = build(spec)
    for folder, (w, h) in SIZES.items():
        dst = os.path.join(base, folder)
        os.makedirs(dst, exist_ok=True)
        out = frame if (w, h) == (W, H) else frame.resize((w, h), Image.LANCZOS)
        out.save(os.path.join(dst, spec.get("out", spec["name"]) + ".png"))
    print("wrote", spec.get("out", spec["name"]))
