#!/usr/bin/env python3
"""Play Store frames, 1242x2208 (9:16, comfortably inside Play's limits).

Deliberately NOT the iOS treatment. That set uses tilted 3D devices, handwritten
Caveat accents, emoji stickers and slang ("no cap", "the whole vibe"). It works
on the App Store, where the audience is browsing.

This audience is different. Someone searching Play for a private journal has
usually already been burned by one, and arrives sceptical. Slang reads as sales.
So these frames are flat, quiet, and let the claim carry the weight — and one of
them is a screenshot of ANDROID'S OWN SETTINGS, which is the one piece of
evidence no competitor can fake and no iOS listing can show at all.
"""
import os, subprocess, html

HERE = os.path.dirname(os.path.abspath(__file__))
OUT  = os.path.join(os.path.dirname(HERE), "assets", "screenshots")
os.makedirs(OUT, exist_ok=True)

# (source, kicker, headline, subline, dark?)
FRAMES = [
    ("01-speak.png", "the whole app",
     "Speak for<br>forty-two seconds.", "No typing. No blank page to fill.", False),
    ("10-permissions.png", "android's own settings — not ours",
     "Microphone.<br>Notifications.<br>That's the list.",
     "No internet permission at all. Check it yourself, before you trust us.", True),
    ("03-twin.png", "your digital twin",
     "It learns you<br>from your<br>own words.",
     "People, mood, and how you sound. All computed on this phone.", True),
    ("02-journal.png", "your journal",
     "Every night,<br>kept here.", "Search by what you meant, or just by voice.", False),
    ("04-insights.png", "patterns",
     "Only what the<br>numbers support.",
     "Nothing is claimed until the evidence supports it.", False),
    ("05-ask.png", "ask your twin",
     "Answers that<br>cite your<br>own entries.",
     "No chatbot guessing about your life. Numbers, and their source.", False),
    ("06-filed.png", "nothing hidden",
     "See exactly<br>what it filed.",
     "Mood, people, pace, body. Visible and correctable.", False),
    ("07-onboarding-ledger.png", "before you record anything",
     "The permission<br>ledger, first.",
     "Including the one we do not ask for.", False),
]

TPL = """<!doctype html><meta charset=utf-8>
<link href="https://fonts.googleapis.com/css2?family=Nunito:wght@700;800;900&family=Inter:wght@400;500;600&family=DM+Mono:wght@500&display=swap" rel=stylesheet>
<style>
*{{margin:0;box-sizing:border-box}}
.f{{width:1242px;height:2208px;position:relative;overflow:hidden;
    font-family:'Nunito',sans-serif;background:{bg};
    display:flex;flex-direction:column;align-items:center}}
.k{{margin-top:96px;font-family:'DM Mono',monospace;font-size:23px;letter-spacing:.17em;
    text-transform:uppercase;color:{kick}}}
h2{{margin-top:26px;font-weight:900;font-size:82px;line-height:1.03;
    letter-spacing:-.03em;color:{ink};text-align:center}}
p{{margin-top:24px;font-family:'Inter',sans-serif;font-size:29px;line-height:1.45;
   color:{sub};text-align:center;max-width:900px;font-weight:500}}
.shot{{margin-top:auto;width:840px;border-radius:44px 44px 0 0;overflow:hidden;
       box-shadow:0 -30px 90px -30px rgba(0,0,0,{shadow});border:1px solid {edge};
       border-bottom:none}}
.shot img{{width:100%;display:block}}
</style>
<div class=f>
  <div class=k>{kicker}</div>
  <h2>{head}</h2>
  <p>{sub_t}</p>
  <div class=shot><img src="{img}"></div>
</div>"""

LIGHT = dict(bg="#FAF8F5", ink="#0F140F", kick="#8A4A20", sub="rgba(15,20,15,.62)",
             shadow=".22", edge="rgba(15,20,15,.10)")
DARK  = dict(bg="#0F140F", ink="#F2EFE9", kick="#E0B15C", sub="rgba(242,239,233,.66)",
             shadow=".55", edge="rgba(242,239,233,.10)")

chrome = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
made = 0
for i, (img, kicker, head, sub_t, dark) in enumerate(FRAMES, 1):
    src = os.path.join(HERE, img)
    if not os.path.exists(src):
        print(f"  SKIP {img} — not captured"); continue
    theme = DARK if dark else LIGHT
    page = TPL.format(img="file://" + src, kicker=kicker, head=head,
                      sub_t=html.escape(sub_t), **theme)
    tmp = os.path.join(HERE, f".frame_{i:02d}.html")
    open(tmp, "w").write(page)
    out = os.path.join(OUT, f"{i:02d}.png")
    subprocess.run([chrome, "--headless", "--disable-gpu", f"--screenshot={out}",
                    "--window-size=1242,2208", "--hide-scrollbars",
                    f"file://{tmp}"], capture_output=True)
    os.remove(tmp)
    made += 1
    print(f"  {out}")
print(f"{made} frames")
