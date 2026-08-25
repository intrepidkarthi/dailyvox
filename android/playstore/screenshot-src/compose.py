#!/usr/bin/env python3
"""Play Store frames, 1242x2208 — matching the shipped iOS system.

Two rebuilds got here. The first was a flat template. The second invented its own
look — gradients, sparkles, film grain — because I had studied ONE iOS frame and
extrapolated. Looking at the whole set shows a much stricter system, and the job
was to match it, not to design a parallel one:

  · SOLID saturated ground per frame. No gradient, no grain, no sparkles.
  · A DIFFERENT accent colour per frame, used four times over: kicker, one word
    in the headline, the stat numeral, and the device's top rim.
  · Headline enormous and tight, cream, one word in the accent.
  · Stat numeral huge in the accent, with a Caveat script line beside it.
  · Device large and CROPPED by the bottom edge, so the frame feels like a
    window rather than a poster with a picture on it.
  · One or two stickers, tilted, overlapping the screen.

What stays Android's own is the content: the palette is drawn from the app's
ink/amber/sage tokens rather than iOS's, and frame 02 is a screenshot of
ANDROID'S OWN SETTINGS — the one piece of evidence no competitor can fake and no
App Store listing can show at all.
"""
import os, subprocess, html

HERE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(os.path.dirname(HERE), "assets", "screenshots")
os.makedirs(OUT, exist_ok=True)

def stk(text, sub, pos, rot, tone="light"):
    return (f'<div class="stk {tone}" style="{pos};--r:{rot}deg">'
            f'<b>{html.escape(text)}</b><small>{html.escape(sub)}</small></div>')

# bg, accent — one pairing per frame, drawn from the app's own tokens
INK    = ("#0F140F", "#E0B15C")   # ink / amber
FOREST = ("#14261C", "#8FCBA4")   # deep green / sage
NIGHT  = ("#101A26", "#D6A84A")   # night blue / gold
CLAY   = ("#241611", "#E0906A")   # deep clay / terracotta
SLATE  = ("#111C22", "#6FC3D6")   # slate / cyan

# Every `stat` below must match what the DEVICE SCREENSHOT beside it shows.
# They drifted once: the frames claimed 12 while the captures said TOTAL 38,
# which is the kind of thing a store reviewer reads as a fabricated number.
# Check against screenshot-src/04-insights.png before changing a seed.
FRAMES = [
    dict(img="01-speak.png", theme=INK, kick="just talk",
         head='42 seconds<br>is the <em>app</em>.', stat="0:42", script="the whole ritual",
         stickers=stk("no typing", "no blank page to fill", "left:26px;top:1560px", -5)),

    dict(img="10-permissions.png", theme=FOREST, kick="android's own settings",
         head='the permission<br>list, in <em>full</em>.', stat="0", script="network permissions",
         stickers=stk("microphone", "that's the whole list", "left:26px;top:1180px", -4, "accent")
                + stk("check it yourself", "settings › apps › dailyvox", "right:40px;top:1560px", 5)),

    dict(img="03-twin.png", theme=NIGHT, kick="meet your twin",
         head='a sky made<br>of <em>you</em>.', stat="38", script="stars in your sky",
         stickers=stk("100% on this phone", "no cloud, no account", "right:40px;top:1720px", 4, "accent")),

    dict(img="05-ask.png", theme=SLATE, kick="ask your twin",
         head='answers with<br><em>receipts</em>.', stat="0", script="calls to any server",
         stickers=stk("cites your entries", "every single answer", "left:26px;top:1700px", -5, "accent")),

    dict(img="04-insights.png", theme=CLAY, kick="your patterns",
         head='it clocks you<br>before <em>you do</em>.', stat="30", script="nights, at a glance",
         stickers=stk("only when proven", "nothing claimed early", "right:40px;top:1660px", 4)),

    dict(img="02-journal.png", theme=FOREST, kick="your journal",
         head='every night,<br><em>kept here</em>.', stat="38", script="entries, on this phone",
         stickers=stk("search by meaning", "or just by voice", "left:26px;top:1700px", -4, "accent")),

    dict(img="06-filed.png", theme=INK, kick="nothing hidden",
         head='see what it<br><em>filed</em>.', stat=None, script=None,
         stickers=stk("mood, people, pace", "wrong? fix it yourself", "left:26px;top:1620px", -5, "accent")),

    dict(img="07-onboarding-ledger.png", theme=NIGHT, kick="before you record anything",
         head='the ledger<br>comes <em>first</em>.', stat=None, script=None,
         stickers=stk("internet", "NOT REQUESTED", "right:40px;top:1640px", 4, "accent")),
]

TPL = """<!doctype html><meta charset=utf-8>
<link href="https://fonts.googleapis.com/css2?family=Caveat:wght@700&family=Nunito:wght@700;800;900&family=DM+Mono:wght@500&display=swap" rel=stylesheet>
<style>
*{{margin:0;box-sizing:border-box}}
.f{{width:1242px;height:2208px;position:relative;overflow:hidden;
    font-family:'Nunito',sans-serif;background:{bg}}}
.top{{position:absolute;top:96px;left:62px;right:62px;z-index:6}}
.k{{font-family:'DM Mono',monospace;font-size:22px;letter-spacing:.22em;
    text-transform:uppercase;color:{ac};font-weight:500}}
h2{{margin-top:20px;font-weight:900;font-size:94px;line-height:.94;
    letter-spacing:-.042em;color:#F6F1E6}}
h2 em{{font-style:normal;color:{ac}}}
.row{{margin-top:{gap}px;display:flex;align-items:baseline;gap:26px}}
.stat{{font-weight:900;font-size:132px;line-height:.76;color:{ac};letter-spacing:-.055em}}
.script{{font-family:'Caveat',cursive;font-weight:700;font-size:46px;
         color:rgba(246,241,230,.80);transform:rotate(-2deg)}}
/* Cropped by the bottom edge on purpose — a window, not a poster. */
.stage{{position:absolute;left:50%;transform:translateX(-50%);top:{top}px;z-index:3;
        width:830px}}
.dev{{width:100%;border-radius:56px 56px 0 0;overflow:hidden;
      border-top:5px solid {ac};
      box-shadow:0 -12px 60px -12px rgba(0,0,0,.5)}}
.dev img{{width:100%;display:block}}
.stk{{position:absolute;z-index:7;border-radius:26px;padding:24px 30px;
      transform:rotate(var(--r));box-shadow:0 26px 56px -14px rgba(0,0,0,.42);
      max-width:400px}}
.stk b{{display:block;font-weight:900;font-size:37px;line-height:1.08;color:#20211E}}
.stk small{{display:block;font-weight:700;font-size:25px;margin-top:5px;color:rgba(32,33,30,.56)}}
.stk.light{{background:#FBF7EE}}
.stk.accent{{background:{ac}}}
.stk.accent b{{color:#12160F}} .stk.accent small{{color:rgba(18,22,15,.62)}}
</style>
<div class=f>
  <div class=top>
    <div class=k>{kicker}</div>
    <h2>{head}</h2>
    {statblock}
  </div>
  <div class=stage><div class=dev><img src="{img}"></div></div>
  {stickers}
</div>"""

chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
made = 0
for i, fr in enumerate(FRAMES, 1):
    src = os.path.join(HERE, fr["img"])
    if not os.path.exists(src):
        print(f"  SKIP {fr['img']}"); continue
    bg, ac = fr["theme"]
    statblock, top, gap = "", 520, 0
    if fr.get("stat"):
        statblock = (f'<div class=row><div class=stat>{fr["stat"]}</div>'
                     f'<div class=script>{html.escape(fr["script"])}</div></div>')
        top, gap = 570, 34
    page = TPL.format(img="file://" + src, kicker=fr["kick"], head=fr["head"],
                      statblock=statblock, stickers=fr["stickers"],
                      top=top, gap=gap, bg=bg, ac=ac)
    tmp = os.path.join(HERE, f".f{i:02d}.html")
    open(tmp, "w").write(page)
    out = os.path.join(OUT, f"{i:02d}.png")
    subprocess.run([chrome, "--headless", "--disable-gpu", f"--screenshot={out}",
                    "--window-size=1242,2208", "--hide-scrollbars", f"file://{tmp}"],
                   capture_output=True)
    os.remove(tmp); made += 1
print(f"{made} frames")
