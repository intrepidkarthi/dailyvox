#!/usr/bin/env python3
"""Play Store frames, 1242x2208.

Rebuilt. The first pass was a flat cream card with a headline and a screenshot
below it — technically correct, visually a template. The iOS set earns its
attention with a big stat numeral, a handwritten accent, a gold-edged device and
sticker callouts that overlap the screen. This has to do at least that.

Where it deliberately differs from iOS: the palette is the Android app's own
(ink / cream / amber, sky always night), and frame 02 is a screenshot of
ANDROID'S OWN SETTINGS — evidence no competitor can fake and no App Store
listing can show at all. iOS has to assert its privacy claim. This one exhibits
it, so the claim gets the hero numeral rather than a feature.
"""
import os, subprocess, html

HERE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(os.path.dirname(HERE), "assets", "screenshots")
os.makedirs(OUT, exist_ok=True)

def sticker(text, sub, pos, rot, tone="light"):
    return (f'<div class="stk {tone}" style="{pos};--r:{rot}deg">'
            f'<b>{html.escape(text)}</b><small>{html.escape(sub)}</small></div>')

FRAMES = [
    dict(img="01-speak.png", dark=False,
         kick="just talk", head='that\'s the<br>whole <em>app</em>.',
         stat="42", script="seconds a night",
         stickers=sticker("no typing", "no blank page to fill", "left:20px;top:1120px", -5)
                + sticker("works in airplane mode", "0 network calls", "right:52px;top:1560px", 4, "sage")),

    dict(img="10-permissions.png", dark=True,
         kick="android's own settings — not ours", head='the permission<br>list, in <em>full</em>.',
         stat="0", script="network permissions",
         stickers=sticker("microphone", "that's it, plus notifications", "left:18px;top:1180px", -4, "gold")
                + sticker("check it yourself", "settings › apps › dailyvox", "right:52px;top:1620px", 5)),

    dict(img="03-twin.png", dark=True,
         kick="your digital twin", head='a sky made<br>of <em>you</em>.',
         stat="12", script="stars in your sky",
         stickers=sticker("people it knows", "sarah ×3 · james ×2", "left:18px;top:1200px", -5, "gold")
                + sticker("100% on this phone", "no cloud, no account", "right:52px;top:1640px", 4, "sage")),

    dict(img="02-journal.png", dark=False,
         kick="your journal", head='every night,<br><em>kept here</em>.',
         stat=None, script=None,
         stickers=sticker("search by meaning", "or just by voice", "left:20px;top:1180px", -4)
                + sticker("nothing uploaded", "not one byte", "right:52px;top:1620px", 5, "sage")),

    dict(img="05-ask.png", dark=False,
         kick="ask your twin", head='answers with<br><em>receipts</em>.',
         stat=None, script=None,
         stickers=sticker("cites your entries", "every single answer", "left:20px;top:1160px", -5, "gold")
                + sticker("no chatbot guessing", "real numbers only", "right:52px;top:1600px", 4)),

    dict(img="04-insights.png", dark=False,
         kick="patterns", head='it clocks you<br>before <em>you do</em>.',
         stat=None, script=None,
         stickers=sticker("only when proven", "nothing claimed early", "left:20px;top:1180px", -4)
                + sticker("mood · sleep · pace", "all computed here", "right:52px;top:1620px", 5, "gold")),

    dict(img="06-filed.png", dark=False,
         kick="nothing hidden", head='see exactly<br>what it <em>filed</em>.',
         stat=None, script=None,
         stickers=sticker("mood +0.42", "people, pace, body", "left:20px;top:1160px", -5, "gold")
                + sticker("wrong? fix it", "you stay in charge", "right:52px;top:1600px", 4)),

    dict(img="07-onboarding-ledger.png", dark=False,
         kick="before you record anything", head='the ledger<br>comes <em>first</em>.',
         stat=None, script=None,
         stickers=sticker("internet", "NOT REQUESTED", "left:20px;top:1200px", -4, "sage")),
]

TPL = """<!doctype html><meta charset=utf-8>
<link href="https://fonts.googleapis.com/css2?family=Caveat:wght@700&family=Nunito:wght@700;800;900&family=DM+Mono:wght@500&display=swap" rel=stylesheet>
<style>
*{{margin:0;box-sizing:border-box}}
.f{{width:1242px;height:2208px;position:relative;overflow:hidden;font-family:'Nunito',sans-serif;
    background:{bg}}}
.grain{{position:absolute;inset:0;z-index:9;pointer-events:none;opacity:{grain};mix-blend-mode:{blend};
  background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='200' height='200'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.8' numOctaves='2'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")}}
.sp{{position:absolute;color:{amber};opacity:.5}}
.top{{position:absolute;top:88px;left:64px;right:64px;z-index:6}}
.k{{font-family:'DM Mono',monospace;font-size:21px;letter-spacing:.17em;text-transform:uppercase;color:{kick}}}
h2{{margin-top:20px;font-weight:900;font-size:92px;line-height:.96;letter-spacing:-.035em;color:{ink}}}
h2 em{{font-style:normal;color:{amber}}}
.statrow{{margin-top:26px;display:flex;align-items:baseline;gap:22px}}
.stat{{font-weight:900;font-size:132px;line-height:.8;color:{amber};letter-spacing:-.05em}}
.script{{font-family:'Caveat',cursive;font-weight:700;font-size:46px;color:{scr};transform:rotate(-2deg)}}
.stage{{position:absolute;left:50%;transform:translateX(-50%);top:{top}px;z-index:3}}
.dev{{width:760px;padding:9px;border-radius:52px;background:{bez};
      box-shadow:0 0 0 2px {edge}, 0 60px 120px -30px rgba(0,0,0,{sh})}}
.dev .scr{{border-radius:44px;overflow:hidden;display:block}}
.dev img{{width:100%;display:block}}
.stk{{position:absolute;z-index:7;border-radius:26px;padding:22px 28px;
      transform:rotate(var(--r));box-shadow:0 26px 54px -14px rgba(0,0,0,.34);
      max-width:390px}}
.stk b{{display:block;font-weight:900;font-size:35px;line-height:1.1;color:#2B2520}}
.stk small{{display:block;font-weight:700;font-size:24px;margin-top:5px;color:rgba(43,37,32,.55)}}
.stk.light{{background:#fff}}
.stk.gold{{background:#F6D88A}}
.stk.gold small{{color:rgba(58,42,18,.62)}}
.stk.sage{{background:#5B7C6B}}
.stk.sage b{{color:#fff}} .stk.sage small{{color:rgba(255,255,255,.74)}}
</style>
<div class=f>
  {sparks}
  <div class=top>
    <div class=k>{kicker}</div>
    <h2>{head}</h2>
    {statblock}
  </div>
  <div class=stage><div class=dev><div class=scr><img src="{img}"></div></div></div>
  {stickers}
  <div class=grain></div>
</div>"""

LIGHT = dict(
    bg=("radial-gradient(760px 620px at 88% 6%, rgba(224,177,92,.30), transparent 62%),"
        "radial-gradient(680px 560px at 4% 84%, rgba(120,156,138,.24), transparent 60%),"
        "linear-gradient(160deg,#FBF6EC 0%,#F5EEE0 58%,#EFE8DA 100%)"),
    ink="#171310", amber="#B0762A", kick="#8A4A20", scr="#B26A3C",
    bez="#0c0c0f", edge="rgba(224,177,92,.55)", sh=".30", grain=".09", blend="multiply")
DARK = dict(
    bg=("radial-gradient(800px 640px at 84% 8%, rgba(224,177,92,.22), transparent 62%),"
        "radial-gradient(700px 580px at 6% 88%, rgba(120,156,138,.18), transparent 60%),"
        "linear-gradient(158deg,#0F140F 0%,#141A14 58%,#0C100C 100%)"),
    ink="#F5F1E8", amber="#E0B15C", kick="#E0B15C", scr="rgba(245,241,232,.62)",
    bez="#000", edge="rgba(224,177,92,.42)", sh=".62", grain=".07", blend="overlay")

def sparks(dark):
    import math
    s = 90210; out = []
    for i in range(9):
        s = (s * 1103515245 + 12345) & 0x7fffffff; x = (s / 0x7fffffff) * 1150 + 40
        s = (s * 1103515245 + 12345) & 0x7fffffff; y = (s / 0x7fffffff) * 700 + 40
        size = 24 + (i * 7) % 40
        out.append(f'<div class=sp style="left:{x:.0f}px;top:{y:.0f}px;font-size:{size}px">&#10022;</div>')
    return "".join(out)

chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
made = 0
for i, fr in enumerate(FRAMES, 1):
    src = os.path.join(HERE, fr["img"])
    if not os.path.exists(src):
        print(f"  SKIP {fr['img']}"); continue
    theme = DARK if fr["dark"] else LIGHT
    statblock = ""
    if fr.get("stat"):
        statblock = (f'<div class=statrow><div class=stat>{fr["stat"]}</div>'
                     f'<div class=script>{html.escape(fr["script"])}</div></div>')
    top = 620 if fr.get("stat") else 520
    page = TPL.format(img="file://" + src, kicker=fr["kick"], head=fr["head"],
                      statblock=statblock, stickers=fr["stickers"], top=top,
                      sparks=sparks(fr["dark"]), **theme)
    tmp = os.path.join(HERE, f".f{i:02d}.html")
    open(tmp, "w").write(page)
    out = os.path.join(OUT, f"{i:02d}.png")
    subprocess.run([chrome, "--headless", "--disable-gpu", f"--screenshot={out}",
                    "--window-size=1242,2208", "--hide-scrollbars", f"file://{tmp}"],
                   capture_output=True)
    os.remove(tmp); made += 1
print(f"{made} frames")
