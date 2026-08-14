#!/usr/bin/env python3
"""DailyVox App Store set (1320x2868) — warm on-brand cosmic, 6 distinct screens,
dramatic varied 3D angles/sizes, bold ink headline + highlighter, handwritten accent, stickers. No footer."""
import os
OUT="/Users/karthikeyanng/CascadeProjects/voicetotext/website/public/_appstore"
os.makedirs(OUT,exist_ok=True)

T="""<!doctype html><html><head><meta charset=utf-8>
<link href="https://fonts.googleapis.com/css2?family=Caveat:wght@700&family=Nunito:wght@700;800;900&display=swap" rel=stylesheet>
<style>
*{{margin:0;box-sizing:border-box}}
.f{{width:1320px;height:2868px;position:relative;overflow:hidden;font-family:'Nunito',sans-serif;
 background:
  radial-gradient(880px 800px at 12% 8%, rgba(255,201,150,.62), transparent 60%),
  radial-gradient(1000px 900px at 92% 20%, rgba(214,168,74,.50), transparent 60%),
  radial-gradient(900px 860px at 86% 90%, rgba(198,141,98,.48), transparent 60%),
  radial-gradient(960px 960px at 4% 96%, rgba(120,156,138,.52), transparent 62%),
  linear-gradient(162deg,#FBF4E7 0%,#F6ECD9 55%,#EFE9DC 100%);}}
.grain{{position:absolute;inset:0;z-index:8;pointer-events:none;opacity:.10;mix-blend-mode:multiply;
 background-image:url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='220' height='220'%3E%3Cfilter id='n'%3E%3CfeTurbulence type='fractalNoise' baseFrequency='0.85' numOctaves='2' stitchTiles='stitch'/%3E%3C/filter%3E%3Crect width='100%25' height='100%25' filter='url(%23n)'/%3E%3C/svg%3E")}}
.spark{{position:absolute;z-index:1;color:#D4A547;text-shadow:0 0 22px rgba(212,165,71,.5)}}
.cap{{position:absolute;top:140px;left:0;right:0;text-align:center;padding:0 62px;z-index:6}}
.cap .k{{display:inline-block;background:rgba(91,124,107,.14);border:2px solid rgba(91,124,107,.30);
 color:#3F5A4D;font-weight:900;font-size:30px;letter-spacing:.15em;text-transform:uppercase;
 padding:14px 32px;border-radius:999px;transform:rotate(-2deg)}}
.cap h2{{margin-top:28px;font-weight:900;font-size:150px;line-height:.88;color:#2B2520;letter-spacing:-.04em}}
.cap h2 .hl{{position:relative;display:inline-block;color:#2B2520;z-index:1}}
.cap h2 .hl:after{{content:'';position:absolute;left:-10px;right:-10px;bottom:14px;height:.30em;background:#F4C752;z-index:-1;border-radius:6px;transform:rotate(-1.2deg)}}
.cap .scr{{margin-top:22px;font-family:'Caveat';font-weight:700;font-size:62px;color:#B26A3C;transform:rotate(-2deg)}}
.ground{{position:absolute;left:50%;top:{gtop}px;transform:translateX(-50%) rotate({grot}deg);width:{gw}px;height:150px;background:radial-gradient(closest-side,rgba(90,60,35,.32),transparent 72%);filter:blur(44px);z-index:2}}
.stage{{position:absolute;left:50%;top:{top}px;transform:translateX(-50%);z-index:3;perspective:2700px}}
.device{{width:{w}px;padding:15px;border-radius:136px;background:#0c0c0f;transform:rotateY({ry}deg) rotateX({rx}deg) rotate({rz}deg);
 box-shadow:0 0 0 3px #5b5b62,0 0 0 6px #26262b,inset 0 2px 3px rgba(255,255,255,.12),0 90px 140px -34px rgba(70,45,25,.4);}}
.device .scr2{{border-radius:122px;overflow:hidden;display:block;box-shadow:inset 0 0 0 2px rgba(0,0,0,.5)}}
.device img{{width:100%;display:block}}
.stk{{position:absolute;z-index:7;background:#fff;border-radius:34px;padding:26px 36px;font-weight:900;font-size:42px;color:#2B2520;
 box-shadow:0 38px 76px -16px rgba(70,45,25,.34);display:inline-flex;align-items:center;gap:18px}}
.stk small{{display:block;font-weight:700;font-size:28px;color:rgba(43,37,32,.5);margin-top:4px}}
.stk.gold{{background:#F6D88A;color:#3A2A12}} .stk.gold small{{color:rgba(58,42,18,.6)}}
.stk.sage{{background:#5B7C6B;color:#fff}} .stk.sage small{{color:rgba(255,255,255,.72)}}
</style></head><body><div class="f">
<div class="spark" style="left:120px;top:560px;font-size:50px">&#10022;</div><div class="spark" style="right:140px;top:470px;font-size:74px">&#10022;</div>
<div class="spark" style="left:80px;top:1520px;font-size:38px">&#10023;</div><div class="spark" style="right:96px;top:1200px;font-size:56px">&#10022;</div>
<div class="spark" style="left:1150px;top:2060px;font-size:40px">&#10023;</div><div class="spark" style="left:240px;top:2190px;font-size:48px">&#10022;</div>
<div class="cap"><div class="k">&#10022; {kick}</div><h2>{head}</h2><div class="scr">{scr}</div></div>
<div class="ground"></div>
<div class="stage"><div class="device"><div class="scr2"><img src="/_appstore/{img}"></div></div></div>
{stickers}
<div class="grain"></div>
</div></body></html>"""

def stk(cls,pos,rot,emoji,t,s):
    return f'<div class="stk {cls}" style="{pos};transform:rotate({rot}deg)">{emoji} <span>{t}<small>{s}</small></span></div>'

# per-screen 3D: (width, stage-top, rotateY, rotateX, rotateZ, ground-w, ground-top, ground-rot)
SCREENS=[
 # 1 HERO — big, near-upright anchor
 dict(img="screen-twin.png", w=1000, top=700, ry=-9, rx=3, rz=1, gw=860, gtop=2400, grot=0,
   kick="meet your digital twin",
   head='it knows you<br>better than<br><span class="hl">you do.</span>', scr="…it's kind of scary, actually",
   stickers=stk("","left:26px;top:1190px",-6,"&#128302;","predicts your mood","before you even feel it")
           +stk("sage","right:22px;top:1680px",5,"&#128274;","100% on your phone","no cloud. no account.")),
 # 2 Record — strong right tilt, smaller
 dict(img="screen-record.png", w=872, top=770, ry=25, rx=7, rz=-4, gw=720, gtop=2420, grot=-4,
   kick="just talk",
   head='speak <span class="hl">42 sec.</span><br>that&#39;s the<br>whole app.', scr="no typing. no blank-page panic.",
   stickers=stk("","left:34px;top:1640px",-6,"&#127908;","your voice, on-device","transcribed on your phone")),
 # 3 Journal — strong left tilt
 dict(img="screen-journal.png", w=930, top=720, ry=-23, rx=4, rz=4, gw=780, gtop=2410, grot=4,
   kick="your journal",
   head='it remembers<br><span class="hl">everything.</span>', scr="every entry, every little detail",
   stickers=stk("gold","right:30px;top:1230px",6,"&#128214;","your whole story","scroll back anytime")
           +stk("","left:30px;top:1720px",-5,"&#127897;&#65039;","all by voice","42 seconds at a time")),
 # 4 Insights — right tilt, moderate
 dict(img="screen-insights.png", w=905, top=745, ry=19, rx=6, rz=-2, gw=750, gtop=2415, grot=-3,
   kick="see your patterns",
   head='it clocks your<br><span class="hl">patterns</span><br>before you do.', scr="moods, streaks, the whole vibe",
   stickers=stk("gold","left:30px;top:1210px",-6,"&#128293;","32-day streak","your longest yet")),
 # 5 Entry detail — dramatic left tilt
 dict(img="screen-entry.png", w=930, top=720, ry=-24, rx=5, rz=3, gw=780, gtop=2410, grot=4,
   kick="every entry, analysed",
   head='it reads<br>between the<br><span class="hl">lines.</span>', scr="emotion, intent, topics — auto",
   stickers=stk("sage","right:28px;top:1240px",6,"&#129504;","understood: reflective","+0.42 sentiment &middot; 4 topics")),
 # 6 Privacy — right tilt
 dict(img="screen-settings.png", w=900, top=755, ry=21, rx=7, rz=-3, gw=750, gtop=2420, grot=-4,
   kick="private by design",
   head='it <span class="hl">never</span><br>leaves your<br>phone. period.', scr="no cloud. no account. no cap.",
   stickers=stk("","left:30px;top:1650px",-6,"&#128737;&#65039;","0 network calls","Data Not Collected")),
 # 7 Onboarding — your voice becomes a star (v1.4.1 signature)
 dict(img="screen-onboarding.png", w=900, top=760, ry=-18, rx=5, rz=3, gw=760, gtop=2415, grot=3,
   kick="your first 42 seconds",
   head='your voice<br>becomes a <span class="hl">star.</span>', scr="speak once — watch it ignite",
   stickers=stk("sage","right:26px;top:1250px",6,"&#11088;","your first star","born from your voice")
           +stk("","left:30px;top:1690px",-6,"&#128241;","kept on your phone","nowhere else")),
]
for i,s in enumerate(SCREENS,1):
    open(os.path.join(OUT,f"shot_{i:02d}.html"),"w").write(T.format(**s))
print("wrote",len(SCREENS),"templates")
