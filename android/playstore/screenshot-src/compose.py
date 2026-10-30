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

    python3 compose.py            # every locale; needs Google Chrome
    python3 compose.py de fr      # only these (en = the English set)

LOCALIZED SETS (1.3, the languages release). Captures for each live in
<locale>/ beside this file, from a debug build seeded in that language
(`./gradlew installDebug -PseedDemo -PseedDemoLang=de`) with the app's own
language set to match (`adb shell cmd locale set-app-locales com.dailyvox.app
--locales de-DE`), and frames go to assets/screenshots/<locale>/. English keeps
its old paths. Outside English the app does NOT suggest a mood, reflect, read
traits, draw a mood curve, find themes or search by meaning, and Ask your Twin
still answers in English -- so no localized frame claims any of those, and the
Ask frame is replaced by the "speak your language" Settings card. German has
no name detection (every noun is capitalised), so its sky has no named stars
and its caption does not mention people; pt-BR copy does not claim names
either. es/it/pt-BR have no "filed" frame: the entry screen's "Ask about this"
button is clipped in those languages (an app bug), and a store frame must not
show clipped text.
"""
import html
import os
import subprocess

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.join(os.path.dirname(HERE), "assets", "screenshots")
FONTS = os.path.normpath(os.path.join(HERE, "..", "..", "app", "src", "main", "res", "font"))

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

# Same order and grounds as English. The Ask slot holds the language card,
# because Ask still answers in English (see the docstring).
SLOTS = [CORAL, VIOLET, EMERALD, OCEAN, BERRY, TEAL, ORCHID, NIGHT]

def localized(rows):
    out = []
    for c, (img, kick, head, sub, stk) in zip(SLOTS, rows):
        if img is None:
            continue
        out.append(dict(img=img, c=c, kick=kick, head=head, sub=sub, stk=stk))
    return out

STK_SPEAK = "left:54px;top:1640px"
STK_TWIN = "right:54px;top:1760px"
STK_LANG = "right:54px;top:1960px"
STK_PERM = "right:54px;top:1290px"

LOCALES = {
    "de": localized([
        ("01-speak.png", "Einfach reden",
         '42 Sekunden sind<br><mark>die ganze App</mark>.',
         "Antippen, sprechen, fertig. Kein Schreiben, keine leere Seite.",
         sticker("transkribiert", "auf dem Telefon", STK_SPEAK, -5)),
        # No names in German (every noun is capitalised), so the sky has no
        # named stars and the copy says nothing about people.
        ("03-twin.png", "Dein Twin",
         'Ein Himmel<br><mark>aus dir</mark>.',
         "Jede Nacht, in der du sprichst, wird ein Stern.",
         sticker("jede Nacht", "ein neuer Stern", STK_TWIN, 4)),
        ("02-journal.png", "Dein Tagebuch",
         'Jede Nacht<br><mark>hier bewahrt</mark>.',
         "Durchsuchen per Tastatur oder per Stimme.", None),
        ("08-language.png", "Auf Deutsch",
         'Sprich einfach<br><mark>Deutsch</mark>.',
         "Die Spracherkennung läuft auf dem Telefon, auch auf Deutsch.",
         sticker("Sprachpaket", "auf dem Telefon", STK_LANG, 4)),
        ("04-insights.png", "Deine Serie",
         'Jede Nacht<br><mark>zählt</mark>.',
         "Serie und Wochenrückblick, gezählt auf diesem Telefon.", None),
        ("10-permissions.png", "Androids eigene Einstellungen",
         'Kein Internet.<br><mark>Prüf es selbst</mark>.',
         "Mikrofon und Benachrichtigungen. Sonst nichts.",
         sticker("Internet-Berechtigung", "nicht angefragt", STK_PERM, 4)),
        ("06-filed.png", "Dein eigenes Wort",
         'Wie es sich<br><mark>wirklich</mark> anfühlte.',
         "Du benennst das Gefühl selbst und korrigierst jedes Wort.", None),
        ("07-onboarding-ledger.png", "Vor deinem ersten Wort",
         'Die Berechtigungen<br><mark>kommen zuerst</mark>.',
         "Bevor du etwas aufnimmst: was die App braucht und was sie nie sendet.", None),
    ]),
    "es": localized([
        ("01-speak.png", "Solo habla",
         '42 segundos son<br><mark>toda la app</mark>.',
         "Toca, habla y listo. Sin teclear, sin página en blanco.",
         sticker("transcrito", "en este teléfono", STK_SPEAK, -5)),
        ("03-twin.png", "Tu Gemelo",
         'Un cielo<br><mark>hecho de ti</mark>.',
         "Las personas de las que hablas se vuelven estrellas.",
         sticker("cada noche", "una estrella nueva", STK_TWIN, 4)),
        ("02-journal.png", "Tu diario",
         'Cada noche,<br><mark>guardada aquí</mark>.',
         "Busca escribiendo o con la voz.", None),
        ("08-language.png", "En español",
         'Habla en<br><mark>español</mark>.',
         "El reconocimiento de voz funciona en el teléfono, también en español.",
         sticker("paquete de voz", "en el teléfono", STK_LANG, 4)),
        ("04-insights.png", "Tu racha",
         'Cada noche<br><mark>cuenta</mark>.',
         "Tu racha y tu semana, contadas en este teléfono.", None),
        ("10-permissions.png", "Los ajustes de Android",
         'Sin internet.<br><mark>Compruébalo</mark>.',
         "Micrófono y notificaciones. Nada más.",
         sticker("permiso de internet", "no solicitado", STK_PERM, 4)),
        (None, None, None, None, None),   # filed: button clipped in Spanish
        ("07-onboarding-ledger.png", "Antes de tu primera palabra",
         'Primero,<br><mark>los permisos</mark>.',
         "Antes de grabar nada: lo que necesita y lo que nunca envía.", None),
    ]),
    "fr": localized([
        ("01-speak.png", "Parle, c'est tout",
         '42 secondes,<br><mark>c\'est toute l\'app</mark>.',
         "Touche, parle, c'est fait. Rien à taper, pas de page blanche.",
         sticker("transcrit", "sur ce téléphone", STK_SPEAK, -5)),
        ("03-twin.png", "Ton Jumeau",
         'Un ciel<br><mark>fait de toi</mark>.',
         "Les personnes dont tu parles deviennent des étoiles.",
         sticker("chaque soir", "une nouvelle étoile", STK_TWIN, 4)),
        ("02-journal.png", "Ton journal",
         'Chaque soir,<br><mark>gardé ici</mark>.',
         "Cherche en tapant ou à la voix.", None),
        ("08-language.png", "En français",
         'Parle<br><mark>français</mark>.',
         "La reconnaissance vocale tourne sur le téléphone, en français aussi.",
         sticker("pack vocal", "sur le téléphone", STK_LANG, 4)),
        ("04-insights.png", "Ta série",
         'Chaque soir<br><mark>compte</mark>.',
         "Ta série et ta semaine, comptées sur ce téléphone.", None),
        ("10-permissions.png", "Les réglages d'Android",
         'Pas d\'internet.<br><mark>Vérifie toi-même</mark>.',
         "Micro et notifications. Rien d'autre.",
         sticker("autorisation internet", "non demandée", STK_PERM, 4)),
        ("06-filed.png", "Ton mot à toi",
         'Ce que tu as<br><mark>vraiment</mark> ressenti.',
         "Tu nommes l'émotion toi-même, et tu corriges chaque mot.", None),
        ("07-onboarding-ledger.png", "Avant ton premier mot",
         'Les autorisations<br><mark>d\'abord</mark>.',
         "Avant d'enregistrer : ce dont l'app a besoin, et ce qu'elle n'envoie jamais.", None),
    ]),
    "it": localized([
        ("01-speak.png", "Parla e basta",
         '42 secondi sono<br><mark>tutta l\'app</mark>.',
         "Tocca, parla, fatto. Niente da scrivere, nessuna pagina bianca.",
         sticker("trascritto", "su questo telefono", STK_SPEAK, -5)),
        ("03-twin.png", "Il tuo Gemello",
         'Un cielo<br><mark>fatto di te</mark>.',
         "Le persone di cui parli diventano stelle.",
         sticker("ogni sera", "una nuova stella", STK_TWIN, 4)),
        ("02-journal.png", "Il tuo diario",
         'Ogni sera,<br><mark>custodita qui</mark>.',
         "Cerca scrivendo o con la voce.", None),
        ("08-language.png", "In italiano",
         'Parla<br><mark>italiano</mark>.',
         "Il riconoscimento vocale funziona sul telefono, anche in italiano.",
         sticker("pacchetto vocale", "sul telefono", STK_LANG, 4)),
        ("04-insights.png", "La tua serie",
         'Ogni sera<br><mark>conta</mark>.',
         "La tua serie e la tua settimana, contate su questo telefono.", None),
        ("10-permissions.png", "Le impostazioni di Android",
         'Niente internet.<br><mark>Verifica tu</mark>.',
         "Microfono e notifiche. Nient'altro.",
         sticker("permesso internet", "non richiesto", STK_PERM, 4)),
        (None, None, None, None, None),   # filed: button clipped in Italian
        ("07-onboarding-ledger.png", "Prima di dire una parola",
         'Prima<br><mark>i permessi</mark>.',
         "Prima di registrare: cosa serve all'app e cosa non invia mai.", None),
    ]),
    "pt-BR": localized([
        ("01-speak.png", "É só falar",
         '42 segundos são<br><mark>o app inteiro</mark>.',
         "Toque, fale, pronto. Sem digitar, sem página em branco.",
         sticker("transcrito", "neste celular", STK_SPEAK, -5)),
        # No claim about people in pt-BR copy (see the docstring).
        ("03-twin.png", "Seu Twin",
         'Um céu<br><mark>feito de você</mark>.',
         "Cada noite em que você fala vira uma estrela.",
         sticker("toda noite", "uma nova estrela", STK_TWIN, 4)),
        ("02-journal.png", "Seu diário",
         'Toda noite,<br><mark>guardada aqui</mark>.',
         "Busque digitando ou pela voz.", None),
        ("08-language.png", "Em português",
         'Fale em<br><mark>português</mark>.',
         "O reconhecimento de voz roda no celular, em português também.",
         sticker("pacote de voz", "no celular", STK_LANG, 4)),
        ("04-insights.png", "Sua sequência",
         'Toda noite<br><mark>conta</mark>.',
         "Sua sequência e sua semana, contadas neste celular.", None),
        ("10-permissions.png", "Configurações do Android",
         'Sem internet.<br><mark>Confira você mesmo</mark>.',
         "Microfone e notificações. Mais nada.",
         sticker("permissão de internet", "não solicitada", STK_PERM, 4)),
        (None, None, None, None, None),   # filed: button clipped in Portuguese
        ("07-onboarding-ledger.png", "Antes da primeira palavra",
         'As permissões<br><mark>vêm primeiro</mark>.',
         "Antes de gravar: o que o app precisa e o que ele nunca envia.", None),
    ]),
}

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
</div>
<script>
// Longer languages: shrink a headline (each line kept whole) or the kicker
// until it fits the frame, rather than letting it run off the edge.
document.fonts.ready.then(() => {{
  for (const el of document.querySelectorAll("h2,.k")) {{
    el.style.whiteSpace = "nowrap";
    const max = document.querySelector(".top").clientWidth;
    let size = parseFloat(getComputedStyle(el).fontSize);
    while (el.scrollWidth > max && size > 40) {{ size -= 2; el.style.fontSize = size + "px"; }}
  }}
}});
</script>"""

CHROME = "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"

import sys

def render(frames, src_dir, out_dir):
    os.makedirs(out_dir, exist_ok=True)
    made = 0
    for i, fr in enumerate(frames, 1):
        src = os.path.join(src_dir, fr["img"])
        if not os.path.exists(src):
            print(f"  SKIP {fr['img']}")
            continue
        c1, c2, mk, mt = fr["c"]
        page = TPL.format(fonts=FONTS, c1=c1, c2=c2, mk=mk, mt=mt, INK=INK,
                          kick=html.escape(fr["kick"]), head=fr["head"], sub=html.escape(fr["sub"]),
                          img="file://" + src, stk=fr["stk"] or "", top=760)
        tmp = os.path.join(HERE, f".f{i:02d}.html")
        open(tmp, "w").write(page)
        out = os.path.join(out_dir, f"{i:02d}.png")
        # virtual-time-budget: let the @font-face files load before the capture,
        # or the first frames come out in the fallback face.
        subprocess.run([CHROME, "--headless", "--disable-gpu", "--allow-file-access-from-files",
                        "--virtual-time-budget=4000", f"--screenshot={out}",
                        "--window-size=1242,2208", "--hide-scrollbars", f"file://{tmp}"],
                       capture_output=True)
        os.remove(tmp)
        made += 1
    # A locale that dropped a frame must not keep a stale higher-numbered one.
    for n in range(made + 1, 9):
        stale = os.path.join(out_dir, f"{n:02d}.png")
        if out_dir != OUT and os.path.exists(stale):
            os.remove(stale)
    print(f"{made} frames -> {out_dir}")

wanted = sys.argv[1:] or ["en", *LOCALES]
for loc in wanted:
    if loc == "en":
        render(FRAMES, HERE, OUT)
    else:
        render(LOCALES[loc], os.path.join(HERE, loc), os.path.join(OUT, loc))
