#!/usr/bin/env python3
"""Build the localized landing and support pages.

    python3 website/localized_pages.py

Writes public/<lang>/index.html (served at /<lang>) and public/<lang>/support.html
(served at /<lang>/support) for de, es, fr, it and pt-br. They exist because App
Store Connect wants a Marketing URL and a Support URL per locale, and Play takes
a website.

Edit the copy HERE, not in the generated HTML: the next run overwrites it. The
copy follows the iOS 1.14 / Android 1.3 store listings, and it obeys one table,
because the app is quiet where it cannot read a language yet:

                                   es/fr/de/it         pt-BR
  interface, on-device transcription   yes             yes
  suggested mood, reflections, traits,
  mood trends, themes                  no              no
  search by meaning                    no (words)      no (words)
  Ask your Twin                        yes             not claimed
  names (people)                       not claimed: iOS reads them in es/fr/de/it
                                       but Android cannot in German, and this page
                                       speaks for both apps

The translations are machine drafts. Styling is public/l10n.css.
"""
import html
import json
import pathlib
import re

PUBLIC = pathlib.Path(__file__).resolve().parent / "public"
SITE = "https://getdailyvox.com"
APP_ID = "id6760454642"
PLAY_ID = "com.dailyvox.app"

# hreflang code, html lang, og:locale, Play hl, native name
LANGS = {
    "en":    ("en",    "en",    "en_US", "en",    "English"),
    "de":    ("de",    "de",    "de_DE", "de",    "Deutsch"),
    "es":    ("es",    "es",    "es_ES", "es",    "Español"),
    "fr":    ("fr",    "fr",    "fr_FR", "fr",    "Français"),
    "it":    ("it",    "it",    "it_IT", "it",    "Italiano"),
    "pt-br": ("pt-BR", "pt-BR", "pt_BR", "pt_BR", "Português (Brasil)"),
}
LOCALIZED = ["de", "es", "fr", "it", "pt-br"]


def url(lang, page):
    """Public URL of a page ('home' or 'support') in a language."""
    if lang == "en":
        return SITE + ("/" if page == "home" else "/support")
    return SITE + f"/{lang}" + ("" if page == "home" else "/support")


def path(lang, page):
    return url(lang, page)[len(SITE):] or "/"


def ios_link(campaign):
    return f"https://apps.apple.com/app/{APP_ID}?ct={campaign}&amp;mt=8"


def play_link(lang, campaign):
    hl = LANGS[lang][3]
    return (f"https://play.google.com/store/apps/details?id={PLAY_ID}&amp;hl={hl}"
            f"&amp;referrer=utm_source%3Dgetdailyvox.com%26utm_medium%3Dweb%26utm_campaign%3D{campaign}")


# ─────────────────────────────────────────────────────────────────────────────
# Copy. Strings may hold inline HTML; FAQ answers are lists of paragraphs.
# {mail} and {privacy} are filled in at render time.
# ─────────────────────────────────────────────────────────────────────────────
MAIL = '<a href="mailto:hello@getdailyvox.com">hello@getdailyvox.com</a>'

C = {}

C["de"] = dict(
    title="DailyVox: privates Sprachtagebuch für iPhone und Android",
    desc="Sprich, und dein Handy schreibt mit. DailyVox ist ein kostenloses Sprachtagebuch auf Deutsch: Transkription auf dem Gerät, kein Konto, keine Server von DailyVox.",
    og_title="DailyVox: Sprich, und dein Handy schreibt mit",
    og_desc="Ein privates Sprachtagebuch, jetzt auf Deutsch. Jeder Abend, an dem du sprichst, wird ein Stern an deinem Himmel.",
    skip="Zum Inhalt springen", lang_label="Sprache", nav_support="Hilfe", nav_download="Laden",
    eyebrow="Neu auf Deutsch · iOS 1.14 · Android 1.3",
    h1='Sprich. Dein Handy <span class="accent">schreibt mit.</span>',
    deck="DailyVox ist ein privates Sprachtagebuch für iPhone und Android. Du sprichst, dein Handy schreibt mit, und jeder Abend, an dem du sprichst, wird ein Stern an deinem Himmel. Alles bleibt auf deinem Handy.",
    btn_ios="Im App Store laden →", btn_play="Bei Google Play laden →",
    micro="Kostenlos · Kein Konto · Keine Werbung · Keine Server von DailyVox",
    sky_caption="Ein Stern für jeden Abend, an dem du gesprochen hast",
    f_eyebrow="Was DailyVox kann", f_h2="Ein Tagebuch, das zuhört.",
    features=[
        ("Sprich auf Deutsch",
         ["Sprich auf Deutsch, transkribiert direkt auf deinem Handy. Die App gibt es auf Deutsch, Englisch, Spanisch, Französisch, Italienisch und brasilianischem Portugiesisch."],
         "Die Stimmungsauswertung und die Einblicke deines Twins sind auf Englisch am ausführlichsten und werden ausgebaut."),
        ("Dein Himmel",
         ["Jeder Eintrag wird ein Stern. Der Abstand zur Mitte zeigt, wie lange es her ist, der Winkel die Tageszeit. Mit der Zeit entsteht ein Sternbild, das nur aus dir besteht."],
         None),
        ("Gerade nicht sprechen?",
         ["Tipp auf „Ich kann gerade nicht sprechen“ und schreib stattdessen. Der Eintrag landet genauso in deinem Tagebuch und an deinem Himmel."],
         None),
        ("Frag deinen Twin",
         ["Frag in deinen eigenen Worten. Die Antworten stützen sich auf deine Einträge und nennen die Einträge, aus denen sie stammen. Hast du über etwas nie gesprochen, sagt DailyVox das, statt zu raten."],
         "Außerhalb des Englischen ist die Suche dahinter einfacher, und Antworten zu Stimmung und Persönlichkeit gibt es vorerst nur auf Englisch."),
        ("Teile deinen Himmel, nie deine Worte",
         ["Nach 7, 21 und 42 Abenden bietet dir DailyVox einmal ein Story-Bild deines Sternbilds an. Darauf steht nur, wie viele Abende du festgehalten hast, nie deine Worte, Namen oder Stimmungen. Es geht nur dorthin, wohin du es schickst."],
         None),
        ("Privat gebaut",
         ["Kein Konto, kein Tracking, keine Werbung. DailyVox hat keine Server, deine Einträge bleiben auf deinem Handy. Die iCloud-Synchronisierung auf dem iPhone ist optional und standardmäßig aus. Unter Android hat die App gar keine Internetberechtigung."],
         None),
    ],
    w_eyebrow="Ehrlich gesagt", w_h2="Was auf Deutsch schon geht",
    w_intro="DailyVox sagt dir lieber, was es noch nicht kann, als auf Deutsch zu raten.",
    w_yes_h="Auf Deutsch",
    w_yes=["Die ganze App auf Deutsch", "Transkription auf dem Gerät",
           "Dein Himmel, deine Serie und jeden Tag eine neue Frage",
           "„Vor einer Woche hast du gesagt …“, dieser Tag in früheren Jahren und ein Wochenrückblick",
           "Stimmung selbst markieren, Einträge mit Stern",
           "Suche nach Wörtern im ganzen Tagebuch",
           "Frag deinen Twin: findet und zitiert deine Einträge",
           "Export und App-Sperre"],
    w_later_h="Vorerst nur auf Englisch",
    w_later=["Vorgeschlagene Stimmung und eine kurze Reflexion zu jedem Eintrag",
             "Stimmungsverlauf, Themen und Persönlichkeitseinblicke",
             "Antworten deines Twins zu Stimmung und Persönlichkeit",
             "Suche nach Bedeutung"],
    quiet="Die Stimmungsauswertung und die Einblicke deines Twins sind auf Englisch am ausführlichsten und werden ausgebaut. Wo DailyVox deine Sprache noch nicht gut lesen kann, bleibt es still, statt zu raten.",
    faq_eyebrow="Häufige Fragen", faq_h2="Kurz beantwortet",
    faq=[
        ("Ist DailyVox kostenlos?",
         ["Ja. Für immer kostenlos: kein Abo, keine Bezahlstufe, keine Werbung."]),
        ("Welche Sprachen gibt es?",
         ["Die App gibt es auf Deutsch, Englisch, Spanisch, Französisch, Italienisch und brasilianischem Portugiesisch, und du kannst in jeder dieser Sprachen sprechen. Die Sprache, in der du sprichst, wählst du in den Einstellungen. Sie kann sich von der Sprache der App unterscheiden.",
          "Die Stimmungsauswertung und die Einblicke deines Twins sind auf Englisch am ausführlichsten und werden ausgebaut. Wo DailyVox deine Sprache noch nicht gut lesen kann, bleibt es still, statt zu raten."]),
        ("Funktioniert die App offline?",
         ["Ja. Die Transkription läuft auf deinem Handy. Manche Sprachen brauchen einmalig einen Download: auf dem iPhone von Apple, unter Android ein Sprachpaket von Google, das der Sprachdienst deines Handys lädt. Danach funktioniert das Aufnehmen auch im Flugmodus.",
          "Kann dein iPhone eine Sprache nicht auf dem Gerät transkribieren, wird deine Aufnahme gespeichert und nie auf Englisch umgeschrieben."]),
        ("Wo liegen meine Daten?",
         ["Auf deinem Handy. DailyVox hat kein Konto und keine Server. Auf dem iPhone ist die iCloud-Synchronisierung optional und standardmäßig aus. Apple verschlüsselt die Daten, Ende-zu-Ende aber nur mit dem erweiterten Datenschutz für iCloud. Unter Android hat die App keine Internetberechtigung, und Androids Cloud-Backup ist in der App ausgeschaltet.",
          "Alle Details stehen in der {privacy}."]),
        ("Welche Geräte brauche ich?",
         ["Ein iPhone mit iOS 17 oder neuer, oder ein Android-Handy mit Android 13 oder neuer."]),
    ],
    final_h2="Dein erster Stern wartet.",
    final_p="Zweiundvierzig Sekunden reichen. Kostenlos, ohne Konto.",
    privacy_label="Datenschutzerklärung (auf Englisch)",
    foot_tag="Ein privates Sprachtagebuch, das auf deinem Handy lebt. Kostenlos, und der Quellcode der App ist öffentlich.",
    foot_app="App", foot_en="Auf Englisch", foot_langs="Sprachen",
    foot_site="Website", foot_privacy="Datenschutz", foot_blog="Blog", foot_license="MIT-Lizenz",
    # support
    s_title="DailyVox Hilfe: Support und häufige Fragen",
    s_desc="Hilfe zu DailyVox, dem privaten Sprachtagebuch: Sprache einstellen, Transkription, Export, Synchronisierung und Kontakt.",
    s_eyebrow="Support · Hilfe", s_h1='Wie können wir <span class="accent">helfen?</span>',
    s_lede="DailyVox wird von einer einzigen Person gebaut und gepflegt. Schreib an {mail}, und du bekommst eine echte Antwort von Karthikeyan, dem Entwickler. Du kannst gern auf Deutsch schreiben; die Antwort kommt vielleicht auf Englisch.",
    s_contact_h="Kontakt",
    s_contact=["Eine Frage, ein Fehler, eine Idee? Schreib an {mail}.",
               "Bei technischen Problemen hilft es sehr, wenn du dein Handymodell und deine iOS- oder Android-Version dazuschreibst."],
    s_lang_h="Sprache und Transkription",
    s_lang_faq=[
        ("Wie stelle ich ein, in welcher Sprache ich spreche?",
         ["In der App unter Einstellungen › Sprache, in der du sprichst. DailyVox hört immer eine Sprache, und sie kann sich von der Sprache der App unterscheiden.",
          "Manche Sprachen brauchen einmalig einen Download: auf dem iPhone von Apple, unter Android ein Sprachpaket von Google, das der Sprachdienst deines Handys lädt. DailyVox selbst lädt dabei nichts herunter."]),
        ("Mein Eintrag wurde nicht transkribiert.",
         ["Prüf zuerst, ob in den Einstellungen die richtige Sprache gewählt ist und ob der einmalige Download fertig ist.",
          "Kann dein iPhone eine Sprache nicht auf dem Gerät transkribieren, wird deine Aufnahme trotzdem gespeichert und nie auf Englisch umgeschrieben. Fehlt unter Android das Sprachpaket, sagt DailyVox das und hört auf, statt übers Netz zu transkribieren."]),
        ("Warum schlägt die App keine Stimmung vor?",
         ["Die vorgeschlagene Stimmung, die kurze Reflexion, der Stimmungsverlauf, Themen und Persönlichkeitseinblicke gibt es vorerst nur auf Englisch. Die Stimmungsauswertung und die Einblicke deines Twins sind auf Englisch am ausführlichsten und werden ausgebaut. Wo DailyVox deine Sprache noch nicht gut lesen kann, bleibt es still, statt zu raten.",
          "Deine Stimmung kannst du jederzeit selbst markieren."]),
        ("Die Suche findet nicht, was ich meine.",
         ["Auf Deutsch sucht DailyVox nach den Wörtern, die du gesagt hast. Die Suche nach Bedeutung gibt es vorerst nur auf Englisch. Versuch es mit einem Wort, das im Eintrag tatsächlich vorkommt."]),
    ],
    s_data_h="Daten und Privatsphäre",
    s_data_faq=[
        ("Sind meine Daten privat?",
         ["Ja. DailyVox verarbeitet alles auf deinem Handy und hat keine Server, die deine Daten empfangen könnten. Aufnahmen, Texte und dein Twin bleiben auf dem Gerät. Alle Details stehen in der {privacy}."]),
        ("Funktioniert die App offline?",
         ["Ja, sobald die Sprache eingerichtet ist. Aufnehmen und Transkribieren funktionieren auch im Flugmodus."]),
        ("Wie sichere ich meine Einträge?",
         ["In der App unter Einstellungen › Daten exportieren. Auf dem iPhone als PDF, JSON, Markdown, CSV oder Text, oder als passwortgeschütztes, verschlüsseltes Backup (AES-256-GCM). Unter Android als PDF, lesbares JSON und als verschlüsseltes Backup, das sich auch auf einem iPhone öffnen lässt."]),
        ("Kann ich zwischen Geräten synchronisieren?",
         ["Auf dem iPhone ja, mit der optionalen iCloud-Synchronisierung. Sie ist standardmäßig aus. Apple verschlüsselt die Daten, Ende-zu-Ende aber nur, wenn du den erweiterten Datenschutz für iCloud aktiviert hast.",
          "Unter Android gibt es keine Synchronisierung, und Androids Cloud-Backup ist in der App bewusst ausgeschaltet. Mit dem verschlüsselten Backup kannst du deine Einträge von Hand mitnehmen."]),
        ("Wie sperre ich die App?",
         ["Schalte in den Einstellungen der App die App-Sperre ein: auf dem iPhone mit Face ID oder Touch ID, unter Android mit Fingerabdruck, Gesicht oder Geräte-PIN."]),
        ("Wie lösche ich meine Daten?",
         ["Auf dem iPhone wischst du einen Eintrag in der Zeitleiste nach links, um ihn zu löschen. Wenn du die App deinstallierst, ist alles auf dem Handy gelöscht. Daten in iCloud verwaltest du in den iCloud-Einstellungen deines Geräts."]),
        ("Welche Versionen brauche ich?",
         ["iOS 17 oder neuer auf dem iPhone, Android 13 oder neuer auf Android."]),
    ],
    s_stuck_h="Noch Fragen?",
    s_stuck=["Schreib an {mail}, du bekommst in ein paar Tagen eine Antwort. Für Ideen, die nicht eilen, kannst du auch ein <a href=\"https://github.com/intrepidkarthi/dailyvox/issues\">GitHub-Issue</a> anlegen (auf Englisch)."],
    s_cta_h="DailyVox noch nicht ausprobiert?",
    s_cta_p="Kostenlos auf iPhone und Android. Kein Konto nötig.",
)

C["es"] = dict(
    title="DailyVox: diario de voz privado para iPhone y Android",
    desc="Habla y tu móvil lo escribe. DailyVox es un diario de voz gratuito en español: transcripción en el dispositivo, sin cuenta y sin servidores de DailyVox.",
    og_title="DailyVox: habla y tu móvil lo escribe",
    og_desc="Un diario de voz privado, ahora en español. Cada noche que hablas se convierte en una estrella de tu cielo.",
    skip="Ir al contenido", lang_label="Idioma", nav_support="Ayuda", nav_download="Descargar",
    eyebrow="Ahora en español · iOS 1.14 · Android 1.3",
    h1='Habla. Tu móvil <span class="accent">lo escribe.</span>',
    deck="DailyVox es un diario de voz privado para iPhone y Android. Tú hablas, tu móvil lo escribe, y cada noche que hablas se convierte en una estrella de tu cielo. Todo se queda en tu móvil.",
    btn_ios="Descargar en el App Store →", btn_play="Disponible en Google Play →",
    micro="Gratis · Sin cuenta · Sin anuncios · Sin servidores de DailyVox",
    sky_caption="Una estrella por cada noche que hablaste",
    f_eyebrow="Qué hace DailyVox", f_h2="Un diario que te escucha.",
    features=[
        ("Habla en español",
         ["Habla en español y se transcribe en tu propio móvil. La app está en español, inglés, alemán, francés, italiano y portugués de Brasil."],
         "La lectura del estado de ánimo y los análisis del Gemelo son más completos en inglés y se están ampliando."),
        ("Tu cielo",
         ["Cada entrada se convierte en una estrella. La distancia al centro es cuánto tiempo hace que hablaste; el ángulo, la hora del día. Con el tiempo se forma una constelación hecha solo de ti."],
         None),
        ("¿Ahora no puedes hablar?",
         ["Toca «Ahora no puedo hablar» y escribe. La entrada va a tu diario y a tu cielo igual que una hablada."],
         None),
        ("Pregunta a tu Gemelo",
         ["Pregunta con tus propias palabras. Las respuestas salen de tus entradas y citan las entradas de las que vienen. Si nunca hablaste de algo, DailyVox te lo dice en vez de adivinar."],
         "Fuera del inglés, la búsqueda que hay detrás es más sencilla, y las respuestas sobre estado de ánimo y personalidad solo están en inglés por ahora."),
        ("Comparte tu cielo, nunca tus palabras",
         ["En las noches 7, 21 y 42, DailyVox te ofrece una sola vez una imagen de tu constelación para tus Historias. Solo muestra cuántas noches llevas, nunca tus palabras, nombres o estados de ánimo, y solo va adonde tú la envíes."],
         None),
        ("Privado por diseño",
         ["Sin cuenta, sin rastreo, sin anuncios. DailyVox no tiene servidores: tus entradas se quedan en tu móvil. En iPhone, la sincronización con iCloud es opcional y está desactivada por defecto. En Android, la app ni siquiera tiene permiso de internet."],
         None),
    ],
    w_eyebrow="Con franqueza", w_h2="Lo que ya funciona en español",
    w_intro="DailyVox prefiere decirte lo que aún no sabe hacer antes que adivinar en tu idioma.",
    w_yes_h="En español",
    w_yes=["Toda la app en español", "Transcripción en el dispositivo",
           "Tu cielo, tu racha y una pregunta nueva cada día",
           "«Hace una semana dijiste…», este día en años anteriores y un resumen semanal",
           "Marcar tu estado de ánimo a mano y destacar entradas con una estrella",
           "Búsqueda por palabras en todo tu diario",
           "Pregunta a tu Gemelo: encuentra y cita tus entradas",
           "Exportación y bloqueo de la app"],
    w_later_h="Por ahora solo en inglés",
    w_later=["Estado de ánimo sugerido y una breve reflexión en cada entrada",
             "Tendencias de ánimo, temas y lecturas de personalidad",
             "Respuestas del Gemelo sobre ánimo y personalidad",
             "Búsqueda por significado"],
    quiet="La lectura del estado de ánimo y los análisis del Gemelo son más completos en inglés y se están ampliando. Donde DailyVox aún no lee bien tu idioma, se queda callado en vez de adivinar.",
    faq_eyebrow="Preguntas frecuentes", faq_h2="En pocas palabras",
    faq=[
        ("¿DailyVox es gratis?",
         ["Sí. Gratis para siempre: sin suscripción, sin versión de pago, sin anuncios."]),
        ("¿En qué idiomas está?",
         ["La app está en español, inglés, alemán, francés, italiano y portugués de Brasil, y puedes hablar en cualquiera de ellos. El idioma en el que hablas lo eliges en Ajustes, y puede ser distinto del idioma de la app.",
          "La lectura del estado de ánimo y los análisis del Gemelo son más completos en inglés y se están ampliando. Donde DailyVox aún no lee bien tu idioma, se queda callado en vez de adivinar."]),
        ("¿Funciona sin conexión?",
         ["Sí. La transcripción se hace en tu móvil. Algunos idiomas necesitan una descarga única: en iPhone, de Apple; en Android, un paquete de idioma de Google que descarga el servicio de voz del móvil. Después, puedes grabar incluso en modo avión.",
          "Si tu iPhone no puede transcribir un idioma en el propio dispositivo, tu grabación se guarda y nunca se reescribe en inglés."]),
        ("¿Dónde están mis datos?",
         ["En tu móvil. DailyVox no tiene cuentas ni servidores. En iPhone, la sincronización con iCloud es opcional y está desactivada por defecto; Apple cifra los datos, y solo es de extremo a extremo con la Protección de datos avanzada. En Android, la app no tiene permiso de internet y la copia de seguridad en la nube de Android está desactivada dentro de la app.",
          "Todos los detalles están en la {privacy}."]),
        ("¿Qué necesito?",
         ["Un iPhone con iOS 17 o posterior, o un móvil con Android 13 o posterior."]),
    ],
    final_h2="Tu primera estrella te espera.",
    final_p="Basta con cuarenta y dos segundos. Gratis y sin cuenta.",
    privacy_label="política de privacidad (en inglés)",
    foot_tag="Un diario de voz privado que vive en tu móvil. Gratis, y el código de la app es público.",
    foot_app="App", foot_en="En inglés", foot_langs="Idiomas",
    foot_site="Web", foot_privacy="Privacidad", foot_blog="Blog", foot_license="Licencia MIT",
    s_title="Ayuda de DailyVox: soporte y preguntas frecuentes",
    s_desc="Ayuda con DailyVox, el diario de voz privado: elegir idioma, transcripción, exportar, sincronizar y contacto.",
    s_eyebrow="Soporte · Ayuda", s_h1='¿En qué podemos <span class="accent">ayudarte?</span>',
    s_lede="DailyVox lo crea y lo mantiene una sola persona. Escribe a {mail} y recibirás una respuesta de verdad de Karthikeyan, el desarrollador. Puedes escribir en español; es posible que la respuesta llegue en inglés.",
    s_contact_h="Contacto",
    s_contact=["¿Tienes una pregunta, encontraste un fallo o se te ocurre una idea? Escribe a {mail}.",
               "Si es un problema técnico, ayuda mucho que indiques el modelo de tu móvil y tu versión de iOS o Android."],
    s_lang_h="Idioma y transcripción",
    s_lang_faq=[
        ("¿Cómo elijo el idioma en el que hablo?",
         ["En la app, en Ajustes › Idioma en el que hablas. DailyVox escucha un idioma cada vez, y puede ser distinto del idioma de la app.",
          "Algunos idiomas necesitan una descarga única: en iPhone, de Apple; en Android, un paquete de idioma de Google que descarga el servicio de voz del móvil. DailyVox no descarga nada por su cuenta."]),
        ("Mi entrada no se ha transcrito.",
         ["Comprueba primero que en Ajustes está elegido el idioma correcto y que la descarga única ha terminado.",
          "Si tu iPhone no puede transcribir un idioma en el propio dispositivo, tu grabación se guarda igualmente y nunca se reescribe en inglés. En Android, si falta el paquete de idioma, DailyVox te lo dice y se detiene en lugar de transcribir por internet."]),
        ("¿Por qué la app no me sugiere un estado de ánimo?",
         ["El estado de ánimo sugerido, la breve reflexión, las tendencias de ánimo, los temas y las lecturas de personalidad solo están en inglés por ahora. La lectura del estado de ánimo y los análisis del Gemelo son más completos en inglés y se están ampliando. Donde DailyVox aún no lee bien tu idioma, se queda callado en vez de adivinar.",
          "Siempre puedes marcar tu estado de ánimo a mano."]),
        ("La búsqueda no encuentra lo que quiero decir.",
         ["En español, DailyVox busca las palabras que dijiste. La búsqueda por significado solo está en inglés por ahora. Prueba con una palabra que aparezca de verdad en la entrada."]),
    ],
    s_data_h="Datos y privacidad",
    s_data_faq=[
        ("¿Mis datos son privados?",
         ["Sí. DailyVox lo procesa todo en tu móvil y no tiene servidores que puedan recibir tus datos. Grabaciones, textos y tu Gemelo se quedan en el dispositivo. Todos los detalles están en la {privacy}."]),
        ("¿Funciona sin conexión?",
         ["Sí, en cuanto el idioma está listo. Grabar y transcribir funcionan también en modo avión."]),
        ("¿Cómo hago una copia de mis entradas?",
         ["En la app, en Ajustes › Exportar datos. En iPhone, en PDF, JSON, Markdown, CSV o texto, o como copia cifrada y protegida con contraseña (AES-256-GCM). En Android, en PDF, JSON legible y una copia cifrada que también se abre en un iPhone."]),
        ("¿Puedo sincronizar entre dispositivos?",
         ["En iPhone sí, con la sincronización opcional de iCloud, que está desactivada por defecto. Apple cifra los datos, pero solo es de extremo a extremo si activas la Protección de datos avanzada.",
          "En Android no hay sincronización, y la copia de seguridad en la nube de Android está desactivada a propósito dentro de la app. Con la copia cifrada puedes llevarte tus entradas a mano."]),
        ("¿Cómo bloqueo la app?",
         ["Activa el bloqueo en los ajustes de la app: en iPhone con Face ID o Touch ID; en Android con huella, cara o el PIN del dispositivo."]),
        ("¿Cómo borro mis datos?",
         ["En iPhone, desliza una entrada hacia la izquierda en la línea de tiempo para borrarla. Si desinstalas la app, se borra todo lo que hay en el móvil. Los datos de iCloud se gestionan en los ajustes de iCloud del dispositivo."]),
        ("¿Qué versión necesito?",
         ["iOS 17 o posterior en iPhone, Android 13 o posterior en Android."]),
    ],
    s_stuck_h="¿Sigues con dudas?",
    s_stuck=["Escribe a {mail} y te responderemos en un par de días. Para ideas sin prisa, también puedes abrir un <a href=\"https://github.com/intrepidkarthi/dailyvox/issues\">issue en GitHub</a> (en inglés)."],
    s_cta_h="¿Aún no has probado DailyVox?",
    s_cta_p="Gratis en iPhone y Android. Sin cuenta.",
)

C["fr"] = dict(
    title="DailyVox : journal intime vocal et privé, iPhone et Android",
    desc="Parle, ton téléphone écrit. DailyVox est un journal intime vocal gratuit en français : transcription sur l'appareil, sans compte, sans serveur DailyVox.",
    og_title="DailyVox : parle, ton téléphone écrit",
    og_desc="Un journal intime vocal et privé, désormais en français. Chaque soir où tu parles devient une étoile dans ton ciel.",
    skip="Aller au contenu", lang_label="Langue", nav_support="Aide", nav_download="Télécharger",
    eyebrow="Désormais en français · iOS 1.14 · Android 1.3",
    h1='Parle. Ton téléphone <span class="accent">écrit.</span>',
    deck="DailyVox est un journal intime vocal et privé pour iPhone et Android. Tu parles, ton téléphone écrit, et chaque soir où tu parles devient une étoile dans ton ciel. Tout reste sur ton téléphone.",
    btn_ios="Télécharger dans l'App Store →", btn_play="Disponible sur Google Play →",
    micro="Gratuit · Sans compte · Sans pub · Sans serveur DailyVox",
    sky_caption="Une étoile pour chaque soir où tu as parlé",
    f_eyebrow="Ce que fait DailyVox", f_h2="Un journal qui t'écoute.",
    features=[
        ("Parle en français",
         ["Parle en français, la transcription se fait sur ton téléphone. L'app existe en français, anglais, allemand, espagnol, italien et portugais du Brésil."],
         "La lecture de l'humeur et les analyses du Jumeau sont plus riches en anglais et sont en cours d'extension."),
        ("Ton ciel",
         ["Chaque entrée devient une étoile. La distance au centre dit depuis combien de temps tu as parlé, l'angle dit l'heure. Avec le temps, une constellation se forme, faite uniquement de toi."],
         None),
        ("Tu ne peux pas parler ?",
         ["Touche « Je ne peux pas parler maintenant » et écris. L'entrée rejoint ton journal et ton ciel, comme une entrée parlée."],
         None),
        ("Demande à ton Jumeau",
         ["Pose tes questions avec tes mots. Les réponses s'appuient sur tes entrées et citent celles d'où elles viennent. Si tu n'as jamais parlé de quelque chose, DailyVox te le dit au lieu de deviner."],
         "Hors de l'anglais, la recherche derrière est plus simple, et les réponses sur l'humeur et la personnalité sont pour l'instant en anglais uniquement."),
        ("Partage ton ciel, jamais tes mots",
         ["Aux soirs 7, 21 et 42, DailyVox te propose une seule fois une image de ta constellation pour ta Story. Elle ne montre que le nombre de soirs gardés, jamais tes mots, les noms ou tes humeurs, et ne part que là où tu l'envoies."],
         None),
        ("Privé par conception",
         ["Pas de compte, pas de pistage, pas de pub. DailyVox n'a pas de serveur : tes entrées restent sur ton téléphone. Sur iPhone, la synchronisation iCloud est facultative et désactivée par défaut. Sur Android, l'app n'a même pas l'autorisation Internet."],
         None),
    ],
    w_eyebrow="En toute franchise", w_h2="Ce qui marche déjà en français",
    w_intro="DailyVox préfère te dire ce qu'il ne sait pas encore faire plutôt que deviner dans ta langue.",
    w_yes_h="En français",
    w_yes=["Toute l'app en français", "Transcription sur l'appareil",
           "Ton ciel, ta série et une nouvelle question chaque jour",
           "« Il y a une semaine, tu disais… », ce jour-là les années précédentes, et un récap de la semaine",
           "Noter toi-même ton humeur, mettre des entrées en favori",
           "Recherche par mots dans tout ton journal",
           "Demande à ton Jumeau : il trouve et cite tes entrées",
           "Export et verrouillage de l'app"],
    w_later_h="En anglais pour l'instant",
    w_later=["Humeur suggérée et courte réflexion sur chaque entrée",
             "Tendances d'humeur, thèmes et lectures de personnalité",
             "Réponses du Jumeau sur l'humeur et la personnalité",
             "Recherche par sens"],
    quiet="La lecture de l'humeur et les analyses du Jumeau sont plus riches en anglais et sont en cours d'extension. Là où DailyVox ne lit pas encore bien ta langue, il se tait au lieu de deviner.",
    faq_eyebrow="Questions fréquentes", faq_h2="En bref",
    faq=[
        ("DailyVox est-il gratuit ?",
         ["Oui. Gratuit pour toujours : pas d'abonnement, pas de version payante, pas de pub."]),
        ("Quelles langues sont disponibles ?",
         ["L'app existe en français, anglais, allemand, espagnol, italien et portugais du Brésil, et tu peux parler dans chacune de ces langues. La langue dans laquelle tu parles se choisit dans les réglages de l'app ; elle peut être différente de la langue de l'app.",
          "La lecture de l'humeur et les analyses du Jumeau sont plus riches en anglais et sont en cours d'extension. Là où DailyVox ne lit pas encore bien ta langue, il se tait au lieu de deviner."]),
        ("Est-ce que ça marche hors ligne ?",
         ["Oui. La transcription se fait sur ton téléphone. Certaines langues demandent un téléchargement unique : sur iPhone, depuis Apple ; sur Android, un pack de langue Google que télécharge le service vocal du téléphone. Ensuite, tu peux enregistrer même en mode avion.",
          "Si ton iPhone ne sait pas transcrire une langue sur l'appareil, ton enregistrement est conservé et n'est jamais réécrit en anglais."]),
        ("Où sont mes données ?",
         ["Sur ton téléphone. DailyVox n'a ni compte ni serveur. Sur iPhone, la synchronisation iCloud est facultative et désactivée par défaut ; Apple chiffre les données, et de bout en bout uniquement avec la Protection avancée des données. Sur Android, l'app n'a pas l'autorisation Internet et la sauvegarde cloud d'Android est désactivée dans l'app.",
          "Tous les détails sont dans la {privacy}."]),
        ("De quoi ai-je besoin ?",
         ["Un iPhone sous iOS 17 ou plus récent, ou un téléphone sous Android 13 ou plus récent."]),
    ],
    final_h2="Ta première étoile t'attend.",
    final_p="Quarante-deux secondes suffisent. Gratuit, sans compte.",
    privacy_label="politique de confidentialité (en anglais)",
    foot_tag="Un journal intime vocal et privé qui vit sur ton téléphone. Gratuit, et le code de l'app est public.",
    foot_app="App", foot_en="En anglais", foot_langs="Langues",
    foot_site="Site", foot_privacy="Confidentialité", foot_blog="Blog", foot_license="Licence MIT",
    s_title="Aide DailyVox : support et questions fréquentes",
    s_desc="Aide pour DailyVox, le journal intime vocal et privé : choisir sa langue, transcription, export, synchronisation et contact.",
    s_eyebrow="Support · Aide", s_h1='Comment pouvons-nous <span class="accent">t\'aider ?</span>',
    s_lede="DailyVox est conçu et maintenu par une seule personne. Écris à {mail} et tu recevras une vraie réponse de Karthikeyan, le développeur. Tu peux écrire en français ; la réponse arrivera peut-être en anglais.",
    s_contact_h="Contact",
    s_contact=["Une question, un bug, une idée ? Écris à {mail}.",
               "Pour un problème technique, indiquer le modèle de ton téléphone et ta version d'iOS ou d'Android aide beaucoup."],
    s_lang_h="Langue et transcription",
    s_lang_faq=[
        ("Comment choisir la langue dans laquelle je parle ?",
         ["Dans les réglages de l'app, rubrique « Langue que tu parles ». DailyVox écoute une langue à la fois, et elle peut être différente de la langue de l'app.",
          "Certaines langues demandent un téléchargement unique : sur iPhone, depuis Apple ; sur Android, un pack de langue Google que télécharge le service vocal du téléphone. DailyVox ne télécharge rien lui-même."]),
        ("Mon entrée n'a pas été transcrite.",
         ["Vérifie d'abord que la bonne langue est choisie dans les réglages et que le téléchargement unique est terminé.",
          "Si ton iPhone ne sait pas transcrire une langue sur l'appareil, ton enregistrement est quand même conservé et n'est jamais réécrit en anglais. Sur Android, s'il manque le pack de langue, DailyVox te le dit et s'arrête au lieu de transcrire via Internet."]),
        ("Pourquoi l'app ne me suggère-t-elle pas d'humeur ?",
         ["L'humeur suggérée, la courte réflexion, les tendances d'humeur, les thèmes et les lectures de personnalité sont pour l'instant en anglais uniquement. La lecture de l'humeur et les analyses du Jumeau sont plus riches en anglais et sont en cours d'extension. Là où DailyVox ne lit pas encore bien ta langue, il se tait au lieu de deviner.",
          "Tu peux toujours noter ton humeur toi-même."]),
        ("La recherche ne trouve pas ce que je veux dire.",
         ["En français, DailyVox cherche les mots que tu as prononcés. La recherche par sens est pour l'instant en anglais uniquement. Essaie un mot qui figure vraiment dans l'entrée."]),
    ],
    s_data_h="Données et confidentialité",
    s_data_faq=[
        ("Mes données sont-elles privées ?",
         ["Oui. DailyVox traite tout sur ton téléphone et n'a aucun serveur pour recevoir tes données. Enregistrements, textes et ton Jumeau restent sur l'appareil. Tous les détails sont dans la {privacy}."]),
        ("Est-ce que ça marche hors ligne ?",
         ["Oui, dès que la langue est prête. Enregistrer et transcrire fonctionnent aussi en mode avion."]),
        ("Comment sauvegarder mes entrées ?",
         ["Dans les réglages de l'app, « Exporter les données ». Sur iPhone : PDF, JSON, Markdown, CSV ou texte, ou une sauvegarde chiffrée protégée par mot de passe (AES-256-GCM). Sur Android : PDF, JSON lisible et une sauvegarde chiffrée qui s'ouvre aussi sur un iPhone."]),
        ("Puis-je synchroniser entre plusieurs appareils ?",
         ["Sur iPhone, oui, avec la synchronisation iCloud facultative, désactivée par défaut. Apple chiffre les données, mais de bout en bout uniquement si tu as activé la Protection avancée des données.",
          "Sur Android, il n'y a pas de synchronisation, et la sauvegarde cloud d'Android est désactivée exprès dans l'app. La sauvegarde chiffrée te permet d'emporter tes entrées à la main."]),
        ("Comment verrouiller l'app ?",
         ["Active le verrouillage dans les réglages de l'app : sur iPhone avec Face ID ou Touch ID ; sur Android avec l'empreinte, le visage ou le code de l'appareil."]),
        ("Comment supprimer mes données ?",
         ["Sur iPhone, balaie une entrée vers la gauche dans la chronologie pour la supprimer. Si tu désinstalles l'app, tout ce qui est sur le téléphone est effacé. Les données iCloud se gèrent dans les réglages iCloud de l'appareil."]),
        ("Quelle version me faut-il ?",
         ["iOS 17 ou plus récent sur iPhone, Android 13 ou plus récent sur Android."]),
    ],
    s_stuck_h="Toujours bloqué ?",
    s_stuck=["Écris à {mail}, tu auras une réponse sous quelques jours. Pour une idée qui n'est pas urgente, tu peux aussi ouvrir une <a href=\"https://github.com/intrepidkarthi/dailyvox/issues\">issue GitHub</a> (en anglais)."],
    s_cta_h="Pas encore essayé DailyVox ?",
    s_cta_p="Gratuit sur iPhone et Android. Sans compte.",
)

C["it"] = dict(
    title="DailyVox: diario vocale privato per iPhone e Android",
    desc="Parla e il tuo telefono scrive. DailyVox è un diario vocale gratuito in italiano: trascrizione sul dispositivo, niente account, nessun server di DailyVox.",
    og_title="DailyVox: parla e il tuo telefono scrive",
    og_desc="Un diario vocale privato, ora in italiano. Ogni sera in cui parli diventa una stella nel tuo cielo.",
    skip="Vai al contenuto", lang_label="Lingua", nav_support="Assistenza", nav_download="Scarica",
    eyebrow="Ora in italiano · iOS 1.14 · Android 1.3",
    h1='Parla. Il tuo telefono <span class="accent">scrive.</span>',
    deck="DailyVox è un diario vocale privato per iPhone e Android. Tu parli, il tuo telefono scrive, e ogni sera in cui parli diventa una stella nel tuo cielo. Tutto resta sul tuo telefono.",
    btn_ios="Scarica dall'App Store →", btn_play="Disponibile su Google Play →",
    micro="Gratis · Niente account · Niente pubblicità · Nessun server di DailyVox",
    sky_caption="Una stella per ogni sera in cui hai parlato",
    f_eyebrow="Cosa fa DailyVox", f_h2="Un diario che ti ascolta.",
    features=[
        ("Parla in italiano",
         ["Parla in italiano: la trascrizione avviene sul tuo telefono. L'app è disponibile in italiano, inglese, tedesco, spagnolo, francese e portoghese brasiliano."],
         "La lettura dell'umore e le analisi del Gemello sono più ricche in inglese e le stiamo estendendo."),
        ("Il tuo cielo",
         ["Ogni voce del diario diventa una stella. La distanza dal centro dice quanto tempo fa hai parlato, l'angolo dice l'ora del giorno. Col tempo nasce una costellazione fatta solo di te."],
         None),
        ("Ora non puoi parlare?",
         ["Tocca \"Ora non posso parlare\" e scrivi. La voce finisce nel diario e nel cielo come una parlata."],
         None),
        ("Chiedi al tuo Gemello",
         ["Chiedi con parole tue. Le risposte partono dalle tue voci e citano quelle da cui vengono. Se non hai mai parlato di qualcosa, DailyVox te lo dice invece di inventare."],
         "Fuori dall'inglese la ricerca che c'è dietro è più semplice, e le risposte su umore e personalità per ora sono solo in inglese."),
        ("Condividi il tuo cielo, mai le tue parole",
         ["Alla 7ª, 21ª e 42ª sera, DailyVox ti propone una sola volta un'immagine della tua costellazione per le Storie. Mostra solo quante sere hai custodito, mai le tue parole, i nomi o il tuo umore, e va solo dove la mandi tu."],
         None),
        ("Privato per costruzione",
         ["Niente account, niente tracciamento, niente pubblicità. DailyVox non ha server: le tue voci restano sul tuo telefono. Su iPhone la sincronizzazione iCloud è facoltativa e disattivata di default. Su Android l'app non ha nemmeno il permesso Internet."],
         None),
    ],
    w_eyebrow="Detto onestamente", w_h2="Cosa funziona già in italiano",
    w_intro="DailyVox preferisce dirti cosa non sa ancora fare piuttosto che tirare a indovinare nella tua lingua.",
    w_yes_h="In italiano",
    w_yes=["Tutta l'app in italiano", "Trascrizione sul dispositivo",
           "Il tuo cielo, la tua serie e una domanda nuova ogni giorno",
           "\"Una settimana fa hai detto…\", questo giorno negli anni passati e un riepilogo settimanale",
           "Segnare tu l'umore e mettere una stella alle voci",
           "Ricerca per parole in tutto il diario",
           "Chiedi al tuo Gemello: trova e cita le tue voci",
           "Esportazione e blocco dell'app"],
    w_later_h="Per ora solo in inglese",
    w_later=["Umore suggerito e una breve riflessione su ogni voce",
             "Andamento dell'umore, temi e letture della personalità",
             "Risposte del Gemello su umore e personalità",
             "Ricerca per significato"],
    quiet="La lettura dell'umore e le analisi del Gemello sono più ricche in inglese e le stiamo estendendo. Dove DailyVox non legge ancora bene la tua lingua, resta in silenzio invece di tirare a indovinare.",
    faq_eyebrow="Domande frequenti", faq_h2="In breve",
    faq=[
        ("DailyVox è gratis?",
         ["Sì. Gratis per sempre: niente abbonamento, nessuna versione a pagamento, niente pubblicità."]),
        ("In quali lingue è disponibile?",
         ["L'app è in italiano, inglese, tedesco, spagnolo, francese e portoghese brasiliano, e puoi parlare in ognuna di queste lingue. La lingua in cui parli la scegli nelle Impostazioni, e può essere diversa da quella dell'app.",
          "La lettura dell'umore e le analisi del Gemello sono più ricche in inglese e le stiamo estendendo. Dove DailyVox non legge ancora bene la tua lingua, resta in silenzio invece di tirare a indovinare."]),
        ("Funziona offline?",
         ["Sì. La trascrizione avviene sul tuo telefono. Alcune lingue richiedono un download una tantum: su iPhone da Apple, su Android un pacchetto lingua di Google scaricato dal servizio vocale del telefono. Dopo puoi registrare anche in modalità aereo.",
          "Se il tuo iPhone non sa trascrivere una lingua sul dispositivo, la registrazione viene salvata e mai riscritta in inglese."]),
        ("Dove sono i miei dati?",
         ["Sul tuo telefono. DailyVox non ha account né server. Su iPhone la sincronizzazione iCloud è facoltativa e disattivata di default; Apple cifra i dati, e end-to-end solo con la Protezione avanzata dei dati. Su Android l'app non ha il permesso Internet e il backup cloud di Android è disattivato dentro l'app.",
          "Tutti i dettagli sono nell'{privacy}."]),
        ("Cosa mi serve?",
         ["Un iPhone con iOS 17 o successivo, oppure un telefono con Android 13 o successivo."]),
    ],
    final_h2="La tua prima stella ti aspetta.",
    final_p="Bastano quarantadue secondi. Gratis, senza account.",
    privacy_label="informativa sulla privacy (in inglese)",
    foot_tag="Un diario vocale privato che vive sul tuo telefono. Gratis, e il codice dell'app è pubblico.",
    foot_app="App", foot_en="In inglese", foot_langs="Lingue",
    foot_site="Sito", foot_privacy="Privacy", foot_blog="Blog", foot_license="Licenza MIT",
    s_title="Assistenza DailyVox: supporto e domande frequenti",
    s_desc="Aiuto per DailyVox, il diario vocale privato: scegliere la lingua, trascrizione, esportazione, sincronizzazione e contatti.",
    s_eyebrow="Supporto · Assistenza", s_h1='Come possiamo <span class="accent">aiutarti?</span>',
    s_lede="DailyVox è costruito e curato da una sola persona. Scrivi a {mail} e riceverai una risposta vera da Karthikeyan, lo sviluppatore. Puoi scrivere in italiano; la risposta potrebbe arrivare in inglese.",
    s_contact_h="Contatti",
    s_contact=["Una domanda, un bug, un'idea? Scrivi a {mail}.",
               "Per i problemi tecnici aiuta molto indicare il modello del telefono e la versione di iOS o Android."],
    s_lang_h="Lingua e trascrizione",
    s_lang_faq=[
        ("Come scelgo la lingua in cui parlo?",
         ["Nell'app, in Impostazioni › Lingua che parli. DailyVox ascolta una lingua alla volta, e può essere diversa da quella dell'app.",
          "Alcune lingue richiedono un download una tantum: su iPhone da Apple, su Android un pacchetto lingua di Google scaricato dal servizio vocale del telefono. DailyVox non scarica nulla da sé."]),
        ("La mia voce non è stata trascritta.",
         ["Controlla prima che nelle Impostazioni sia scelta la lingua giusta e che il download una tantum sia finito.",
          "Se il tuo iPhone non sa trascrivere una lingua sul dispositivo, la registrazione viene comunque salvata e mai riscritta in inglese. Su Android, se manca il pacchetto lingua, DailyVox te lo dice e si ferma invece di trascrivere via Internet."]),
        ("Perché l'app non mi suggerisce un umore?",
         ["L'umore suggerito, la breve riflessione, l'andamento dell'umore, i temi e le letture della personalità per ora sono solo in inglese. La lettura dell'umore e le analisi del Gemello sono più ricche in inglese e le stiamo estendendo. Dove DailyVox non legge ancora bene la tua lingua, resta in silenzio invece di tirare a indovinare.",
          "L'umore puoi sempre segnarlo tu."]),
        ("La ricerca non trova quello che intendo.",
         ["In italiano DailyVox cerca le parole che hai detto. La ricerca per significato per ora è solo in inglese. Prova con una parola che compare davvero nella voce."]),
    ],
    s_data_h="Dati e privacy",
    s_data_faq=[
        ("I miei dati sono privati?",
         ["Sì. DailyVox elabora tutto sul tuo telefono e non ha server che possano ricevere i tuoi dati. Registrazioni, testi e il tuo Gemello restano sul dispositivo. Tutti i dettagli sono nell'{privacy}."]),
        ("Funziona offline?",
         ["Sì, una volta pronta la lingua. Registrare e trascrivere funzionano anche in modalità aereo."]),
        ("Come faccio un backup delle mie voci?",
         ["Nell'app, in Impostazioni › Esporta dati. Su iPhone in PDF, JSON, Markdown, CSV o testo, oppure come backup cifrato e protetto da password (AES-256-GCM). Su Android in PDF, JSON leggibile e un backup cifrato che si apre anche su iPhone."]),
        ("Posso sincronizzare tra più dispositivi?",
         ["Su iPhone sì, con la sincronizzazione iCloud facoltativa, disattivata di default. Apple cifra i dati, ma end-to-end solo se hai attivato la Protezione avanzata dei dati.",
          "Su Android non c'è sincronizzazione, e il backup cloud di Android è disattivato apposta dentro l'app. Con il backup cifrato puoi portare le tue voci con te a mano."]),
        ("Come blocco l'app?",
         ["Attiva il blocco nelle impostazioni dell'app: su iPhone con Face ID o Touch ID, su Android con impronta, volto o PIN del dispositivo."]),
        ("Come cancello i miei dati?",
         ["Su iPhone scorri una voce verso sinistra nella cronologia per eliminarla. Se disinstalli l'app, tutto quello che c'è sul telefono viene cancellato. I dati su iCloud si gestiscono nelle impostazioni iCloud del dispositivo."]),
        ("Che versione mi serve?",
         ["iOS 17 o successivo su iPhone, Android 13 o successivo su Android."]),
    ],
    s_stuck_h="Ancora dubbi?",
    s_stuck=["Scrivi a {mail} e ti risponderemo entro un paio di giorni. Per idee senza fretta puoi anche aprire una <a href=\"https://github.com/intrepidkarthi/dailyvox/issues\">issue su GitHub</a> (in inglese)."],
    s_cta_h="Non hai ancora provato DailyVox?",
    s_cta_p="Gratis su iPhone e Android. Senza account.",
)

C["pt-br"] = dict(
    title="DailyVox: diário por voz privado para iPhone e Android",
    desc="Fale e o seu celular escreve. O DailyVox é um diário por voz gratuito em português: transcrição no aparelho, sem conta e sem servidores do DailyVox.",
    og_title="DailyVox: fale e o seu celular escreve",
    og_desc="Um diário por voz privado, agora em português. Cada noite em que você fala vira uma estrela no seu céu.",
    skip="Pular para o conteúdo", lang_label="Idioma", nav_support="Ajuda", nav_download="Baixar",
    eyebrow="Agora em português · iOS 1.14 · Android 1.3",
    h1='Fale. O seu celular <span class="accent">escreve.</span>',
    deck="O DailyVox é um diário por voz privado para iPhone e Android. Você fala, o seu celular escreve, e cada noite em que você fala vira uma estrela no seu céu. Tudo fica no seu celular.",
    btn_ios="Baixar na App Store →", btn_play="Disponível no Google Play →",
    micro="Grátis · Sem conta · Sem anúncios · Sem servidores do DailyVox",
    sky_caption="Uma estrela para cada noite em que você falou",
    f_eyebrow="O que o DailyVox faz", f_h2="Um diário que escuta você.",
    features=[
        ("Fale em português",
         ["Fale em português: a transcrição acontece no seu celular. O app está em português do Brasil, inglês, alemão, espanhol, francês e italiano."],
         "A leitura do humor e as percepções do Twin são mais completas em inglês e estão sendo ampliadas."),
        ("Seu céu",
         ["Cada registro vira uma estrela. A distância do centro mostra há quanto tempo você falou; o ângulo, a hora do dia. Com o tempo, nasce uma constelação feita só de você."],
         None),
        ("Não dá para falar agora?",
         ["Toque em \"Não posso falar agora\" e escreva. O registro vai para o diário e para o seu céu como um falado."],
         None),
        ("Seu passado de volta",
         ["\"Uma semana atrás você disse…\", este dia em anos anteriores e um resumo da semana. Uma pergunta nova todo dia, e uma sequência que um dia de descanso por semana não quebra."],
         None),
        ("Compartilhe seu céu, nunca suas palavras",
         ["Nas noites 7, 21 e 42, o DailyVox oferece uma única vez uma imagem da sua constelação para os Stories. Ela mostra só quantas noites você guardou, nunca suas palavras, nomes ou humores, e só vai para onde você mandar."],
         None),
        ("Privado de propósito",
         ["Sem conta, sem rastreamento, sem anúncios. O DailyVox não tem servidores: seus registros ficam no seu celular. No iPhone, a sincronização com o iCloud é opcional e vem desligada. No Android, o app nem tem permissão de internet."],
         None),
    ],
    w_eyebrow="Com franqueza", w_h2="O que já funciona em português",
    w_intro="O DailyVox prefere dizer o que ainda não sabe fazer a chutar no seu idioma.",
    w_yes_h="Em português",
    w_yes=["O app inteiro em português", "Transcrição no aparelho",
           "Seu céu, sua sequência e uma pergunta nova todo dia",
           "\"Uma semana atrás você disse…\", este dia em anos anteriores e um resumo da semana",
           "Marcar o seu humor e destacar registros com estrela",
           "Busca por palavras no diário inteiro",
           "Exportação e bloqueio do app"],
    w_later_h="Por enquanto, só em inglês",
    w_later=["Humor sugerido e uma breve reflexão em cada registro",
             "Tendências de humor, temas e leituras de personalidade",
             "Busca por significado"],
    quiet="A leitura do humor e as percepções do Twin são mais completas em inglês e estão sendo ampliadas. Onde o DailyVox ainda não lê bem o seu idioma, ele fica quieto em vez de chutar.",
    faq_eyebrow="Perguntas frequentes", faq_h2="Em poucas palavras",
    faq=[
        ("O DailyVox é grátis?",
         ["Sim. Grátis para sempre: sem assinatura, sem versão paga, sem anúncios."]),
        ("Em quais idiomas ele está?",
         ["O app está em português do Brasil, inglês, alemão, espanhol, francês e italiano, e você pode falar em qualquer um deles. O idioma em que você fala é escolhido nos ajustes do app e pode ser diferente do idioma do app.",
          "A leitura do humor e as percepções do Twin são mais completas em inglês e estão sendo ampliadas. Onde o DailyVox ainda não lê bem o seu idioma, ele fica quieto em vez de chutar."]),
        ("Funciona sem internet?",
         ["Sim. A transcrição acontece no seu celular. Alguns idiomas precisam de um download único: no iPhone, da Apple; no Android, um pacote de idioma do Google baixado pelo serviço de voz do celular. Depois disso, dá para gravar até no modo avião.",
          "Se o seu iPhone não consegue transcrever um idioma no próprio aparelho, sua gravação fica salva e nunca é reescrita em inglês."]),
        ("Onde ficam os meus dados?",
         ["No seu celular. O DailyVox não tem conta nem servidores. No iPhone, a sincronização com o iCloud é opcional e vem desligada; a Apple criptografa os dados, e de ponta a ponta só com a Proteção Avançada de Dados. No Android, o app não tem permissão de internet e o backup na nuvem do Android fica desligado dentro do app.",
          "Todos os detalhes estão na {privacy}."]),
        ("Do que eu preciso?",
         ["Um iPhone com iOS 17 ou mais recente, ou um celular com Android 13 ou mais recente."]),
    ],
    final_h2="Sua primeira estrela está esperando.",
    final_p="Quarenta e dois segundos bastam. Grátis, sem conta.",
    privacy_label="política de privacidade (em inglês)",
    foot_tag="Um diário por voz privado que vive no seu celular. Grátis, e o código do app é público.",
    foot_app="App", foot_en="Em inglês", foot_langs="Idiomas",
    foot_site="Site", foot_privacy="Privacidade", foot_blog="Blog", foot_license="Licença MIT",
    s_title="Ajuda do DailyVox: suporte e perguntas frequentes",
    s_desc="Ajuda com o DailyVox, o diário por voz privado: escolher o idioma, transcrição, exportação, sincronização e contato.",
    s_eyebrow="Suporte · Ajuda", s_h1='Como podemos <span class="accent">ajudar?</span>',
    s_lede="O DailyVox é feito e mantido por uma pessoa só. Escreva para {mail} e você recebe uma resposta de verdade do Karthikeyan, o desenvolvedor. Pode escrever em português; a resposta talvez venha em inglês.",
    s_contact_h="Contato",
    s_contact=["Uma dúvida, um bug, uma ideia? Escreva para {mail}.",
               "Em problemas técnicos, ajuda muito informar o modelo do celular e a versão do iOS ou do Android."],
    s_lang_h="Idioma e transcrição",
    s_lang_faq=[
        ("Como escolho o idioma em que eu falo?",
         ["Nos ajustes do app, em \"Idioma em que você fala\". O DailyVox escuta um idioma por vez, e ele pode ser diferente do idioma do app.",
          "Alguns idiomas precisam de um download único: no iPhone, da Apple; no Android, um pacote de idioma do Google baixado pelo serviço de voz do celular. O próprio DailyVox não baixa nada."]),
        ("Meu registro não foi transcrito.",
         ["Primeiro confira se o idioma certo está escolhido nos ajustes e se o download único terminou.",
          "Se o seu iPhone não consegue transcrever um idioma no próprio aparelho, a gravação fica salva mesmo assim e nunca é reescrita em inglês. No Android, se faltar o pacote de idioma, o DailyVox avisa e para, em vez de transcrever pela internet."]),
        ("Por que o app não sugere um humor?",
         ["O humor sugerido, a breve reflexão, as tendências de humor, os temas e as leituras de personalidade, por enquanto, só existem em inglês. A leitura do humor e as percepções do Twin são mais completas em inglês e estão sendo ampliadas. Onde o DailyVox ainda não lê bem o seu idioma, ele fica quieto em vez de chutar.",
          "Você sempre pode marcar o seu humor."]),
        ("A busca não encontra o que eu quero dizer.",
         ["Em português, o DailyVox busca as palavras que você disse. A busca por significado, por enquanto, só existe em inglês. Tente uma palavra que aparece de fato no registro."]),
    ],
    s_data_h="Dados e privacidade",
    s_data_faq=[
        ("Meus dados são privados?",
         ["Sim. O DailyVox processa tudo no seu celular e não tem servidores que possam receber seus dados. Gravações, textos e o seu Twin ficam no aparelho. Todos os detalhes estão na {privacy}."]),
        ("Funciona sem internet?",
         ["Sim, assim que o idioma estiver pronto. Gravar e transcrever funcionam também no modo avião."]),
        ("Como faço backup dos meus registros?",
         ["Exporte pelos ajustes do app. No iPhone, em PDF, JSON, Markdown, CSV ou texto, ou como backup criptografado e protegido por senha (AES-256-GCM). No Android, em PDF, JSON legível e um backup criptografado que também abre no iPhone."]),
        ("Posso sincronizar entre aparelhos?",
         ["No iPhone, sim, com a sincronização opcional do iCloud, que vem desligada. A Apple criptografa os dados, mas de ponta a ponta só se você ativar a Proteção Avançada de Dados.",
          "No Android não há sincronização, e o backup na nuvem do Android fica desligado de propósito dentro do app. Com o backup criptografado você leva seus registros na mão."]),
        ("Como bloqueio o app?",
         ["Ative o bloqueio nos ajustes do app: no iPhone com Face ID ou Touch ID; no Android com digital, rosto ou PIN do aparelho."]),
        ("Como apago meus dados?",
         ["No iPhone, deslize um registro para a esquerda na linha do tempo para apagá-lo. Se você desinstalar o app, tudo o que está no celular é apagado. Os dados do iCloud são gerenciados nos ajustes do iCloud do aparelho."]),
        ("Qual versão eu preciso?",
         ["iOS 17 ou mais recente no iPhone, Android 13 ou mais recente no Android."]),
    ],
    s_stuck_h="Ainda com dúvidas?",
    s_stuck=["Escreva para {mail} e você recebe uma resposta em poucos dias. Para ideias sem pressa, você também pode abrir uma <a href=\"https://github.com/intrepidkarthi/dailyvox/issues\">issue no GitHub</a> (em inglês)."],
    s_cta_h="Ainda não experimentou o DailyVox?",
    s_cta_p="Grátis no iPhone e no Android. Sem conta.",
)


# ─────────────────────────────────────────────────────────────────────────────
# Rendering
# ─────────────────────────────────────────────────────────────────────────────
GTAG = """<!-- Google tag (gtag.js) -->
<script async src="https://www.googletagmanager.com/gtag/js?id=G-R544S4KDBQ"></script>
<script>
  window.dataLayer = window.dataLayer || [];
  function gtag(){dataLayer.push(arguments);}
  gtag('js', new Date());
  gtag('config', 'G-R544S4KDBQ');
</script>"""

FONTS = ('<link rel="preconnect" href="https://fonts.googleapis.com">\n'
         '  <link rel="preconnect" href="https://fonts.gstatic.com" crossorigin>\n'
         '  <link href="https://fonts.googleapis.com/css2?family=Nunito:wght@400;600;700;800'
         '&family=Inter:wght@400;500;600;700&family=DM+Mono:wght@400;500&display=swap" rel="stylesheet">')

# A flat constellation: one dot per night, a few joined. No gradients, no glow.
SKY_STARS = [(160, 160, 7), (112, 98, 4), (214, 92, 4.5), (244, 176, 3.5), (205, 238, 4), (118, 222, 3.5),
             (70, 150, 3), (150, 46, 3), (268, 58, 2.5), (290, 250, 3), (60, 270, 2.5), (40, 70, 2.5),
             (178, 292, 2.5), (98, 300, 2), (300, 120, 2), (24, 196, 2), (238, 300, 2), (132, 132, 2.5),
             (190, 124, 2.5), (82, 40, 2)]
SKY_LINES = [(0, 1), (0, 2), (0, 4), (0, 5), (2, 3), (1, 7), (4, 9)]


def sky_svg():
    lines = "".join(
        f'<line x1="{SKY_STARS[a][0]}" y1="{SKY_STARS[a][1]}" x2="{SKY_STARS[b][0]}" y2="{SKY_STARS[b][1]}"/>'
        for a, b in SKY_LINES)
    dots = "".join(
        (f'<circle cx="{x}" cy="{y}" r="{r}" fill="#EDCB86"/>' if i < 6 else
         f'<circle cx="{x}" cy="{y}" r="{r}" fill="#F1EDE2" opacity=".7"/>')
        for i, (x, y, r) in enumerate(SKY_STARS))
    return (f'<svg viewBox="0 0 320 320" width="320" height="320" aria-hidden="true" focusable="false">'
            f'<g stroke="#EDCB86" stroke-opacity=".45" stroke-width="1.2">{lines}</g>{dots}</svg>')


def plain(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s))


def fill(s, c):
    priv = f'<a href="/privacy" hreflang="en">{c["privacy_label"]}</a>'
    return s.replace("{mail}", MAIL).replace("{privacy}", priv)


def head(lang, page, title, desc, og_title, og_desc, ld):
    hl, html_lang, og_locale, _, _ = LANGS[lang]
    alts = "\n".join(
        f'  <link rel="alternate" hreflang="{LANGS[l][0]}" href="{url(l, page)}">' for l in LANGS)
    alts += f'\n  <link rel="alternate" hreflang="x-default" href="{url("en", page)}">'
    og_alt = "\n".join(f'  <meta property="og:locale:alternate" content="{LANGS[l][2]}">'
                       for l in LANGS if l != lang)
    e = html.escape
    return f"""<!DOCTYPE html>
<html lang="{html_lang}">
<head>
{GTAG}
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>{e(title)}</title>
  <meta name="description" content="{e(desc)}">
  <meta name="theme-color" content="#FAF8F5">
  <meta name="robots" content="index,follow">
  <link rel="canonical" href="{url(lang, page)}">
{alts}
  <meta property="og:type" content="website">
  <meta property="og:url" content="{url(lang, page)}">
  <meta property="og:site_name" content="DailyVox">
  <meta property="og:locale" content="{og_locale}">
{og_alt}
  <meta property="og:title" content="{e(og_title)}">
  <meta property="og:description" content="{e(og_desc)}">
  <meta property="og:image" content="{SITE}/og-image.png?v=1111">
  <meta property="og:image:width" content="1200">
  <meta property="og:image:height" content="630">
  <meta property="og:image:alt" content="DailyVox">
  <meta name="twitter:card" content="summary_large_image">
  <meta name="twitter:title" content="{e(og_title)}">
  <meta name="twitter:description" content="{e(og_desc)}">
  <meta name="twitter:image" content="{SITE}/og-image.png?v=1111">
  <link rel="icon" type="image/x-icon" href="/favicon.ico">
  <link rel="icon" type="image/png" sizes="16x16" href="/favicon-16x16.png">
  <link rel="icon" type="image/png" sizes="32x32" href="/favicon-32x32.png">
  <link rel="apple-touch-icon" sizes="180x180" href="/apple-touch-icon.png">
  <link rel="manifest" href="/manifest.json">
  {FONTS}
  <link rel="stylesheet" href="/l10n.css">
  <script type="application/ld+json">
{ld}
  </script>
</head>"""


def faq_ld(lang, items):
    data = {
        "@context": "https://schema.org", "@type": "FAQPage", "inLanguage": LANGS[lang][0],
        "mainEntity": [{"@type": "Question", "name": q,
                        "acceptedAnswer": {"@type": "Answer", "text": " ".join(plain(p) for p in a)}}
                       for q, a in items],
    }
    return json.dumps(data, ensure_ascii=False, indent=2)


def lang_switch(lang, page, c):
    cur = ' aria-current="page"'
    items = "\n".join(
        f'          <li><a href="{path(l, page)}" hreflang="{LANGS[l][0]}" lang="{LANGS[l][1]}"'
        f'{cur if l == lang else ""}>{LANGS[l][4]}</a></li>'
        for l in LANGS)
    return f"""      <details class="lang">
        <summary aria-label="{c['lang_label']}">{LANGS[lang][4].split(' ')[0]}</summary>
        <ul>
{items}
        </ul>
      </details>"""


def nav(lang, page, c):
    return f"""<a href="#main" class="skip">{c['skip']}</a>
<header>
<nav class="nav" aria-label="DailyVox">
  <div class="wrap nav-in">
    <a href="{path(lang, 'home')}" class="wordmark"><img src="/apple-touch-icon.png" alt="" width="30" height="30"><span>DailyVox</span></a>
    <div class="nav-right">
      <a href="{path(lang, 'support')}" class="nav-link">{c['nav_support']}</a>
{lang_switch(lang, page, c)}
      <a href="{path(lang, 'home')}#download" class="pill sm">{c['nav_download']}</a>
    </div>
  </div>
</nav>
</header>"""


def footer(lang, page, c, campaign):
    langs = "\n".join(
        f'        <a href="{path(l, page)}" hreflang="{LANGS[l][0]}" lang="{LANGS[l][1]}">{LANGS[l][4]}</a>'
        for l in LANGS if l != "en")
    return f"""<footer class="dv-footer">
  <div class="wrap">
    <div class="dv-f-grid">
      <div class="dv-f-brand">
        <a href="{path(lang, 'home')}" class="dv-f-mark"><img src="/apple-touch-icon.png" alt="" width="28" height="28"><span>DailyVox</span></a>
        <p>{c['foot_tag']}</p>
      </div>
      <nav class="dv-f-col" aria-label="{c['foot_app']}">
        <h4>{c['foot_app']}</h4>
        <a href="{ios_link(campaign)}">App Store</a>
        <a href="{play_link(lang, campaign)}">Google Play</a>
        <a href="{path(lang, 'support')}">{c['nav_support']}</a>
        <a href="mailto:hello@getdailyvox.com">hello@getdailyvox.com</a>
      </nav>
      <nav class="dv-f-col" aria-label="{c['foot_en']}">
        <h4>{c['foot_en']}</h4>
        <a href="/" hreflang="en">{c['foot_site']}</a>
        <a href="/privacy" hreflang="en">{c['foot_privacy']}</a>
        <a href="/blog" hreflang="en">{c['foot_blog']}</a>
        <a href="https://github.com/intrepidkarthi/dailyvox">GitHub</a>
      </nav>
      <nav class="dv-f-col" aria-label="{c['foot_langs']}">
        <h4>{c['foot_langs']}</h4>
        <a href="{path('en', page)}" hreflang="en" lang="en">English</a>
{langs}
      </nav>
    </div>
    <div class="dv-f-base">
      <span>&copy; 2026 DailyVox</span>
      <span><a href="https://github.com/intrepidkarthi/dailyvox">{c['foot_license']}</a></span>
    </div>
  </div>
</footer>"""


def faq_block(items, c):
    out = []
    for q, a in items:
        ps = "".join(f"<p>{fill(p, c)}</p>" for p in a)
        out.append(f"      <details><summary>{q}</summary>{ps}</details>")
    return "\n".join(out)


def store_buttons(lang, c, campaign, dark=False):
    cls = "pill dark" if dark else "pill"
    return (f'<a href="{ios_link(campaign)}" class="{cls}">{c["btn_ios"]}</a>\n'
            f'        <a href="{play_link(lang, campaign)}" class="{cls}">{c["btn_play"]}</a>')


def landing(lang):
    c = C[lang]
    camp = lang
    feats = []
    for t, ps, note in c["features"]:
        body = "".join(f"<p>{p}</p>" for p in ps)
        if note:
            body += f'<p class="note">{note}</p>'
        feats.append(f'      <li class="feature"><span class="dot" aria-hidden="true"></span><h3>{t}</h3>{body}</li>')
    yes = "".join(f"<li>{x}</li>" for x in c["w_yes"])
    later = "".join(f"<li>{x}</li>" for x in c["w_later"])
    return f"""{head(lang, 'home', c['title'], c['desc'], c['og_title'], c['og_desc'], faq_ld(lang, c['faq']))}
<body>
{nav(lang, 'home', c)}

<main id="main" tabindex="-1">

<section class="hero-sec" aria-labelledby="hero-h">
  <div class="wrap hero-grid">
    <div>
      <p class="eyebrow">{c['eyebrow']}</p>
      <h1 class="hero" id="hero-h">{c['h1']}</h1>
      <p class="deck">{c['deck']}</p>
      <div class="cta-row" id="download">
        {store_buttons(lang, c, camp)}
      </div>
      <p class="micro">{c['micro']}</p>
    </div>
    <figure class="sky" style="margin:0">
      {sky_svg()}
      <figcaption><p>{c['sky_caption']}</p></figcaption>
    </figure>
  </div>
</section>

<section class="b-cream" aria-labelledby="feat-h">
  <div class="wrap">
    <div class="section-head">
      <p class="eyebrow">{c['f_eyebrow']}</p>
      <h2 id="feat-h">{c['f_h2']}</h2>
    </div>
    <ul class="features">
{chr(10).join(feats)}
    </ul>
  </div>
</section>

<section class="b-forest" aria-labelledby="works-h">
  <div class="wrap">
    <div class="section-head">
      <p class="eyebrow">{c['w_eyebrow']}</p>
      <h2 id="works-h">{c['w_h2']}</h2>
      <p>{c['w_intro']}</p>
    </div>
    <div class="split">
      <div class="yes"><h3>{c['w_yes_h']}</h3><ul>{yes}</ul></div>
      <div class="later"><h3>{c['w_later_h']}</h3><ul>{later}</ul></div>
    </div>
    <p class="quiet">{c['quiet']}</p>
  </div>
</section>

<section aria-labelledby="faq-h">
  <div class="wrap narrow">
    <div class="section-head">
      <p class="eyebrow">{c['faq_eyebrow']}</p>
      <h2 id="faq-h">{c['faq_h2']}</h2>
    </div>
    <div class="faq">
{faq_block(c['faq'], c)}
    </div>
  </div>
</section>

<section class="b-gold final" aria-labelledby="cta-h">
  <div class="wrap narrow">
    <h2 id="cta-h">{c['final_h2']}</h2>
    <p>{c['final_p']}</p>
    <div class="cta-row">
        {store_buttons(lang, c, camp)}
    </div>
  </div>
</section>

</main>

{footer(lang, 'home', c, camp)}
</body>
</html>
"""


def support(lang):
    c = C[lang]
    camp = f"{lang}-support"
    all_faq = c["s_lang_faq"] + c["s_data_faq"]
    contact = "".join(f"<p>{fill(p, c)}</p>" for p in c["s_contact"])
    stuck = "".join(f"<p>{fill(p, c)}</p>" for p in c["s_stuck"])
    return f"""{head(lang, 'support', c['s_title'], c['s_desc'], c['s_title'], c['s_desc'], faq_ld(lang, all_faq))}
<body>
{nav(lang, 'support', c)}

<main id="main" tabindex="-1">

<section class="support-hero" aria-labelledby="hero-h">
  <div class="wrap narrow">
    <p class="eyebrow">{c['s_eyebrow']}</p>
    <h1 class="hero" id="hero-h">{c['s_h1']}</h1>
    <p class="deck">{fill(c['s_lede'], c)}</p>
  </div>
</section>

<section class="prose" aria-label="{c['nav_support']}">
  <div class="wrap narrow">
    <h2>{c['s_contact_h']}</h2>
    {contact}

    <h2>{c['s_lang_h']}</h2>
    <div class="faq">
{faq_block(c['s_lang_faq'], c)}
    </div>

    <h2>{c['s_data_h']}</h2>
    <div class="faq">
{faq_block(c['s_data_faq'], c)}
    </div>

    <h2>{c['s_stuck_h']}</h2>
    {stuck}

    <div class="card-cta">
      <h3>{c['s_cta_h']}</h3>
      <p>{c['s_cta_p']}</p>
      <div class="cta-row" style="margin-top:0">
        {store_buttons(lang, c, camp)}
      </div>
    </div>
  </div>
</section>

</main>

{footer(lang, 'support', c, camp)}
</body>
</html>
"""


def main():
    for lang in LOCALIZED:
        d = PUBLIC / lang
        d.mkdir(exist_ok=True)
        (d / "index.html").write_text(landing(lang), encoding="utf-8")
        (d / "support.html").write_text(support(lang), encoding="utf-8")
        print(f"wrote {lang}/index.html, {lang}/support.html")


if __name__ == "__main__":
    main()
