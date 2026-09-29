#!/usr/bin/env python3
"""Play Store frames, 1242x2208. Rebuilt 2026-09-29 for the v1.0 release.

The August set matched the iOS structure but not its energy: saturated-but-dark
jewel grounds (mean L* 27) that still read as eight dim rectangles in a
carousel. This set goes the other way on purpose:

  · A VIBRANT two-stop gradient per frame, no hue family twice in a row, since
    the carousel is scrolled and neighbours are what the eye compares.
  · Star dust over every ground: two offset dot lattices at low alpha. It is
    the Twin's sky, so the texture is the product's own metaphor rather than
    decoration.
  · One highlighted phrase per headline, set on a tilted marker. The
    headline is the claim; the marker is the part to remember.
  · A whole device with a real bezel, cropped by the bottom edge.
  · One sticker per frame at most, and only for a fact the screen proves.

Every claim must be true of v1.0 as shipped. In particular: no Health Connect
(nothing about sleep or steps), no "search by meaning" (search is typed words
or voice), and the permissions frame says what Android's own screen shows —
microphone and notifications.

Fonts are the app's own bundled files (app/src/main/res/font), so rendering
needs no network and the frames use exactly the faces the app does.

    python3 compose.py     # needs Google Chrome; captures in this directory
"""
import html
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "assets", "screenshots")
FONTS = os.path.normpath(os.path.join(HERE, "..", "..", "app", "src", "main", "res", "font"))
os.makedirs(OUT, exist_ok=True)

INK = "#14201B"

# (top-left, bottom-right, marker, marker text)
CORAL   = ("#E8432A", "#FF9A2E", "#FFE45C", INK)
VIOLET  = ("#5A34F5", "#1B1566", "#FFC94D", INK)
EMERALD = ("#0C9A5E", "#0A6F86", "#FFE45C", INK)
OCEAN   = ("#1B5FF0", "#00B4CC", "#FFE45C", INK)
BERRY   = ("#D42A66", "#FF7F3F", INK, "#FFE45C")
TEAL    = ("#00806F", "#2DB36F", "#FFFFFF", INK)
ORCHID  = ("#7B35F0", "#DC47C4", "#FFE45C", INK)
NIGHT   = ("#0F1E3C", "#2D5BFF", "#FFC94D", INK)

def sticker(label, big, pos, rot):
    return (f'<div class=stk style="{pos};--r:{rot}deg">'
            f'<small>{html.escape(label)}</small><b>{html.escape(big)}</b></div>')

FRAMES = [
    dict(img="01-speak.png", c=CORAL, kick="Just talk",
         head='42 seconds is<br><mark>the whole app</mark>.',
         sub="Tap, speak, done. No typing, no blank page.",
         stk=sticker("transcribed", "on this phone", "left:54px;top:1640px", -5)),
    dict(img="03-twin.png", c=VIOLET, kick="Your Twin",
         head='A sky made<br><mark>of you</mark>.',
         sub="The people you talk about become the stars.",
         stk=sticker("every night", "one new star", "right:54px;top:1760px", 4)),
    dict(img="02-journal.png", c=EMERALD, kick="Your journal",
         head='Every night,<br><mark>kept here</mark>.',
         sub="Search by typing or by voice. Replay any entry.",
         stk=None),
    dict(img="05-ask.png", c=OCEAN, kick="Ask your Twin",
         head='Answers with<br><mark>receipts</mark>.',
         sub="Every answer comes from your own entries.",
         stk=sticker("network calls", "zero, ever", "right:54px;top:1700px", 4)),
    dict(img="04-insights.png", c=BERRY, kick="Your patterns",
         head='It notices<br><mark>before you do</mark>.',
         sub="Streaks and moods, and patterns once they hold up.",
         stk=None),
    dict(img="10-permissions.png", c=TEAL, kick="Android's own settings",
         head='No internet.<br><mark>Check yourself</mark>.',
         sub="Microphone and notifications. Nothing else.",
         stk=sticker("internet permission", "not requested", "right:54px;top:1170px", 4)),
    dict(img="06-filed.png", c=ORCHID, kick="Nothing hidden",
         head='See what it filed.<br><mark>Fix it</mark>.',
         sub="Mood, people and pace — and your own word for it.",
         stk=None),
    dict(img="07-onboarding-ledger.png", c=NIGHT, kick="Before your first word",
         head='The permission list<br><mark>comes first</mark>.',
         sub="Before you record a word: what it needs, and what it never sends.",
         stk=None),
]

TPL = """<!doctype html><meta charset=utf-8>
<style>
@font-face{{font-family:Nunito;src:url("file://{fonts}/nunito_variable.ttf");font-weight:200 1000}}
@font-face{{font-family:Inter;src:url("file://{fonts}/inter_variable.ttf");font-weight:100 900}}
@font-face{{font-family:DMMono;src:url("file://{fonts}/dm_mono_medium.ttf")}}
*{{margin:0;box-sizing:border-box}}
.f{{width:1242px;height:2208px;position:relative;overflow:hidden;font-family:Nunito,sans-serif;
    background:linear-gradient(155deg,{c1} 0%,{c2} 100%)}}
/* Light: one warm bloom behind the headline, one behind the device. */
.f:before{{content:"";position:absolute;inset:0;
    background:radial-gradient(900px 700px at 12% 6%,rgba(255,255,255,.20),transparent 70%),
               radial-gradient(1100px 900px at 60% 78%,rgba(255,255,255,.16),transparent 70%)}}
/* Star dust: two offset lattices, so it never reads as a grid. */
.dust{{position:absolute;inset:0;opacity:.55;
    background-image:radial-gradient(circle,rgba(255,255,255,.75) 1.6px,transparent 2.4px),
                     radial-gradient(circle,rgba(255,255,255,.45) 1.2px,transparent 2px);
    background-size:137px 131px,89px 97px;background-position:11px 23px,53px 7px;
    -webkit-mask-image:linear-gradient(to bottom,#000 0%,rgba(0,0,0,.2) 55%,transparent 80%)}}
.top{{position:absolute;top:104px;left:72px;right:72px;z-index:6}}
.k{{display:inline-block;font-family:DMMono,monospace;font-size:25px;letter-spacing:.2em;
    text-transform:uppercase;color:#fff;background:rgba(255,255,255,.18);
    border:1.5px solid rgba(255,255,255,.35);border-radius:999px;padding:12px 24px}}
h2{{margin-top:34px;font-weight:900;font-size:104px;line-height:1.0;letter-spacing:-.035em;color:#fff;
    text-shadow:0 4px 30px rgba(0,0,0,.12)}}
mark{{background:{mk};color:{mt};padding:0 20px 6px;border-radius:22px;display:inline-block;
      transform:rotate(-1.6deg);margin-top:10px;box-shadow:0 18px 40px -16px rgba(0,0,0,.45);
      text-shadow:none}}
.sub{{margin-top:34px;font-family:Inter,sans-serif;font-weight:600;font-size:37px;line-height:1.3;
      color:rgba(255,255,255,.92);max-width:1060px}}
.stage{{position:absolute;left:50%;transform:translateX(-50%);top:{top}px;z-index:3;width:880px}}
.dev{{width:100%;border-radius:104px;background:#0B0F14;padding:16px;
      box-shadow:0 60px 120px -30px rgba(0,0,0,.55),0 0 0 3px rgba(255,255,255,.14) inset}}
.scr{{border-radius:90px;overflow:hidden;position:relative}}
.scr img{{width:100%;display:block}}
/* Punch-hole camera, as on the Pixel the captures came from. */
.cam{{position:absolute;top:30px;left:50%;width:30px;height:30px;margin-left:-15px;border-radius:50%;
      background:#05070A;z-index:2}}
.stk{{position:absolute;z-index:7;background:#fff;border-radius:30px;padding:24px 32px 26px;
      transform:rotate(var(--r));box-shadow:0 30px 60px -18px rgba(0,0,0,.45);max-width:420px}}
.stk small{{display:block;font-family:DMMono,monospace;font-size:21px;letter-spacing:.14em;
            text-transform:uppercase;color:rgba(20,32,27,.6)}}
.stk b{{display:block;margin-top:6px;font-weight:900;font-size:46px;line-height:1.05;color:{INK}}}
</style>
<div class=f>
  <div class=dust></div>
  <div class=top>
    <div class=k>{kick}</div>
    <h2>{head}</h2>
    <div class=sub>{sub}</div>
  </div>
  <div class=stage><div class=dev><div class=scr><div class=cam></div><img src="{img}"></div></div></div>
  {stk}
</div>"""

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

made = 0
for i, fr in enumerate(FRAMES, 1):
    src = os.path.join(HERE, fr["img"])
    if not os.path.exists(src):
        print(f"  SKIP {fr['img']}")
        continue
    c1, c2, mk, mt = fr["c"]
    page = TPL.format(fonts=FONTS, c1=c1, c2=c2, mk=mk, mt=mt, INK=INK,
                      kick=html.escape(fr["kick"]), head=fr["head"], sub=html.escape(fr["sub"]),
                      img="file://" + src, stk=fr["stk"] or "", top=760)
    tmp = os.path.join(HERE, f".f{i:02d}.html")
    open(tmp, "w").write(page)
    out = os.path.join(OUT, f"{i:02d}.png")
    # virtual-time-budget: let the @font-face files load before the capture,
    # or the first frames come out in the fallback face.
    subprocess.run([CHROME, "--headless", "--disable-gpu", "--allow-file-access-from-files",
                    "--virtual-time-budget=4000", f"--screenshot={out}",
                    "--window-size=1242,2208", "--hide-scrollbars", f"file://{tmp}"],
                   capture_output=True)
    os.remove(tmp)
    made += 1
print(f"{made} frames -> {OUT}")
