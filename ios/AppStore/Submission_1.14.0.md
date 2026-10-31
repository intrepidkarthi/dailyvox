# App Store Connect — DailyVox 1.14.0 (build 49)

The languages release: the app in German, Spanish, French, Italian and Portuguese
(Brazil) as well as English, and "share your sky as a Story". Hindi is held back.
Everything below is what changes in App Store Connect. Fields not listed are
unchanged.

> **The five new locales are unreviewed machine drafts.** Karthik chose to ship
> them without a native review (2026-10-28); a review and fix-up follow the release.
> They claim only what the build does in each language: no suggested mood,
> reflections, mood trends, themes, personality reads or search by meaning outside
> English, and no claim about names (people) in any of them.

Counts were measured by script (Python `len`, Unicode characters), not by eye.
Paste only what is inside a fence.

---

## 1. Version and build

| Field | Value |
|---|---|
| Version | **1.14.0** (new version — create it in ASC) |
| Build | **49** |
| Minimum iOS | 17.0 (unchanged) |
| Export compliance | `ITSAppUsesNonExemptEncryption = false` is already in Info.plist |
| New listing languages | German, Spanish (Spain), French, Italian, Portuguese (Brazil) |

Distribute from Xcode → Window → Organizer → Distribute App → App Store Connect
(team `9W3J36YT29`), as for 1.13.0.

---

## 2. English (U.S.): What's New — PASTE INTO "What's New in This Version"

1.13.1 never went to the App Store, so these notes also carry its fixes.

```
DailyVox now speaks German, Spanish, French, Italian and Portuguese (Brazil).

NEW
- The whole app in German, Spanish, French, Italian and Brazilian Portuguese, as well as English. It follows the language you set for DailyVox in iOS Settings.
- Settings > Language you speak: choose the language DailyVox listens in, separately from the app's language. The list shows only languages this iPhone can transcribe on the device.
- Ask your Twin answers in the language you ask in. Quoted entries stay exactly as you said them.
- Share your sky as a Story: a card of your real constellation, sized for Instagram Stories and WhatsApp Status. It shows how many nights, never your words, names or moods. Offered once each at nights 7, 21 and 42; Settings > Sharing turns the offer off.
- Dates, numbers and quotation marks follow your region.

HONEST ABOUT LANGUAGES
Suggested moods, reflections, mood trends, themes, personality reads and search by meaning read English only for now. In other languages they stay quiet instead of guessing, and search finds the words you said. You can always set a mood yourself.

FIXED
- Speech in another language is never written down as English when its on-device model is missing. The recording is kept, and the app tells you how to install the model.
- Search says "by meaning" only when it actually searched by meaning.
- The daily question no longer asks about people from entries it can't read.
- Names in Hindi, Tamil and other scripts with vowel signs are no longer matched inside longer names.
- Early signals count words properly in Chinese, Japanese and Thai.
```

*(1,599 of 4,000 characters.)*

---

## 3. English (U.S.): Promotional Text — PASTE INTO "Promotional Text"

```
Now in German, Spanish, French, Italian and Brazilian Portuguese. Speak in your language and your iPhone writes it down, on the device. No account, no DailyVox server.
```

*(167 of 170 characters. Can be changed later without a new build.)*

English Name, Subtitle, Keywords and Description are unchanged.

---

## 4. The five new listing languages

In ASC → the app → App Store tab → the language menu next to the version → add
each language below (if one already exists from an earlier release, replace its
fields). Each needs every field in its section, plus a Support URL and screenshots.

**Support URL / Marketing URL per locale.** The localized pages
(`getdailyvox.com/<lang>/support`, `getdailyvox.com/<lang>`) are on website PR #141,
which is meant to merge only once this release is live. Until then use the English
`https://getdailyvox.com/support` and `https://getdailyvox.com`; switch to the
localized URLs after #141 is live (URL fields can be edited without a new version).

| Locale | Name | Subtitle | Keywords | Promo | Description | What's New |
|---|---|---|---|---|---|---|
| de-DE | 24/30 | 25/30 | 98/100 | 143/170 | 2,816/4,000 | 1,510/4,000 |
| es-ES | 23/30 | 22/30 | 98/100 | 137/170 | 2,739/4,000 | 1,429/4,000 |
| fr-FR | 24/30 | 21/30 | 97/100 | 138/170 | 2,834/4,000 | 1,466/4,000 |
| it | 23/30 | 23/30 | 96/100 | 134/170 | 2,745/4,000 | 1,417/4,000 |
| pt-BR | 24/30 | 22/30 | 98/100 | 126/170 | 2,661/4,000 | 1,385/4,000 |

Keywords are comma-separated with no spaces, and repeat no word from that
locale's name or subtitle (Apple already indexes those).

### de-DE — German

**Name** (30 max)

```
DailyVox: Sprachtagebuch
```

*(24 of 30 characters.)*

**Subtitle** (30 max)

```
Privat, auf deinem iPhone
```

*(25 of 30 characters.)*

**Keywords** (100 max)

```
journal,diktieren,transkription,sprachnotiz,notizen,offline,dankbarkeit,erinnerungen,gedanken,twin
```

*(98 of 100 characters.)*

**Promotional Text** (170 max)

```
Jetzt auf Deutsch: Sprich, und dein iPhone schreibt mit, direkt auf dem Gerät. Jede Nacht, in der du sprichst, wird ein Stern an deinem Himmel.
```

*(143 of 170 characters.)*

**What's New in This Version** (4,000 max)

```
DailyVox gibt es jetzt auf Deutsch.

NEU
- Die ganze App auf Deutsch, außerdem auf Spanisch, Französisch, Italienisch und brasilianischem Portugiesisch. Sie folgt der Sprache, die du in den iOS-Einstellungen für DailyVox festlegst.
- Einstellungen > Sprache, in der du sprichst: Wähl, in welcher Sprache DailyVox zuhört, unabhängig von der Sprache der App. Die Liste zeigt nur Sprachen, die dieses iPhone auf dem Gerät transkribieren kann.
- Frag deinen Twin antwortet in der Sprache deiner Frage. Zitierte Einträge bleiben genau so, wie du sie gesagt hast.
- Teile deinen Himmel als Story: ein Bild deines echten Sternbilds im Format für Instagram-Storys und den WhatsApp-Status. Es zeigt nur, wie viele Nächte, nie deine Worte, Namen oder Stimmungen. DailyVox bietet es einmal in Nacht 7, 21 und 42 an; unter Einstellungen > Teilen schaltest du das ab.
- Datum, Zahlen und Anführungszeichen folgen deiner Region.

EHRLICH ZU SPRACHEN
Vorgeschlagene Stimmung, Reflexionen, Stimmungsverlauf, Themen, Persönlichkeitseinblicke und die Suche nach Bedeutung lesen vorerst nur Englisch. Auf Deutsch bleiben sie still, statt zu raten, und die Suche findet die Wörter, die du gesagt hast. Deine Stimmung kannst du jederzeit selbst markieren.

BEHOBEN
- Gesprochenes Deutsch wird nie als Englisch aufgeschrieben, wenn das Sprachmodell fehlt. Die Aufnahme bleibt gespeichert, und die App sagt dir, wie du das Modell installierst.
- Die Suche sagt nur dann „nach Bedeutung“, wenn sie wirklich nach Bedeutung gesucht hat.
```

*(1,510 of 4,000 characters.)*

**Description** (4,000 max)

```
DailyVox ist ein privates Sprachtagebuch. Du sprichst, dein iPhone schreibt mit, und jede Nacht, in der du sprichst, wird ein Stern an deinem Himmel. Die Transkription läuft auf dem Gerät. Kein Konto, keine Server von DailyVox.

SPRICH AUF DEUTSCH
Die ganze App gibt es auf Deutsch. Unter Einstellungen > Sprache, in der du sprichst wählst du, in welcher Sprache DailyVox zuhört. Sie kann sich von der Sprache der App unterscheiden. Manche Sprachen brauchen einmalig einen Download von Apple, danach funktioniert das Aufnehmen auch im Flugmodus. Kann dein iPhone eine Sprache nicht auf dem Gerät transkribieren, bleibt deine Aufnahme gespeichert und wird nie auf Englisch umgeschrieben.

DEIN HIMMEL
Jeder Eintrag wird ein Stern. Der Abstand zur Mitte zeigt, wie lange es her ist, der Winkel die Tageszeit. Mit der Zeit entsteht ein Sternbild, das nur aus dir besteht.

GERADE NICHT SPRECHEN?
Tipp auf „Ich kann gerade nicht sprechen“ und schreib stattdessen. Der Eintrag zählt genauso wie ein gesprochener.

DEINE WORTE KOMMEN ZURÜCK
„Vor einer Woche hast du gesagt …“, dieser Tag in früheren Monaten und Jahren und ein Wochenrückblick, gezählt aus deinen Einträgen. Jeden Tag eine neue Frage, und „Andere Frage“ ist einen Tipp entfernt. Ein Ruhetag pro Woche unterbricht deine Serie nicht.

FRAG DEINEN TWIN
Frag in deinen eigenen Worten. Die Antwort kommt in der Sprache deiner Frage, stützt sich auf deine Einträge und zitiert sie mit Datum. Hast du über etwas nie gesprochen, sagt DailyVox das, statt zu raten. Alles passiert auf diesem iPhone.

TEILE DEINEN HIMMEL, NIE DEINE WORTE
In Nacht 7, 21 und 42 bietet dir DailyVox jeweils einmal ein Story-Bild deines Sternbilds an, im Format für Instagram-Storys und den WhatsApp-Status. Darauf steht nur, wie viele Nächte du festgehalten hast, nie deine Worte, Namen oder Stimmungen. Es geht nur dorthin, wohin du es schickst.

DEIN TAGEBUCH
- Suche nach Wörtern im ganzen Tagebuch, getippt oder gesprochen
- Jede Aufnahme anhören, mit Spulen und Tempo von 0,5x bis 2x
- Stimmung selbst markieren, Einträge mit Stern
- Widgets für Home- und Sperrbildschirm, deine Worte live in der Dynamic Island
- Export als PDF, JSON, Markdown, CSV oder Text
- Erinnerung am Abend und drei Designs: Tag, Nacht und Abendrot
- Datum und Zahlen im Format deiner Region

PRIVAT GEBAUT
- App-Sperre mit Face ID oder Touch ID
- Passwortgeschützte, verschlüsselte Backups (AES-256-GCM)
- iCloud-Synchronisierung optional und standardmäßig aus
- Kein Konto, kein Tracking, keine Analyse, keine Werbung
- Kostenlos, ohne Abo

VORERST NUR AUF ENGLISCH
Die vorgeschlagene Stimmung, die kurze Reflexion zu jedem Eintrag, der Stimmungsverlauf, Themen, Persönlichkeitseinblicke und die Suche nach Bedeutung. Wo DailyVox deine Sprache noch nicht gut lesen kann, bleibt es still, statt zu raten.
```

*(2,816 of 4,000 characters.)*

**Support URL:** `https://getdailyvox.com/support` until #141 is live, then `https://getdailyvox.com/de/support`.

**Screenshots:** `ios/AppStore/screenshots/de-DE/` (being re-shot on the release branch; upload whatever that folder holds at submission).

### es-ES — Spanish (Spain)

**Name** (30 max)

```
DailyVox: Diario de voz
```

*(23 of 30 characters.)*

**Subtitle** (30 max)

```
Privado y en tu iPhone
```

*(22 of 30 characters.)*

**Keywords** (100 max)

```
journal,transcripción,dictado,notas,audio,grabadora,offline,gratitud,recuerdos,pensamientos,gemelo
```

*(98 of 100 characters.)*

**Promotional Text** (170 max)

```
Ahora en español: habla y tu iPhone lo escribe, en el propio dispositivo. Cada noche que hablas se convierte en una estrella de tu cielo.
```

*(137 of 170 characters.)*

**What's New in This Version** (4,000 max)

```
DailyVox ya está en español.

NOVEDADES
- Toda la app en español, y también en alemán, francés, italiano y portugués de Brasil. Sigue el idioma que elijas para DailyVox en los Ajustes de iOS.
- Ajustes > Idioma en el que hablas: elige en qué idioma te escucha DailyVox, aparte del idioma de la app. La lista solo muestra idiomas que este iPhone puede transcribir en el dispositivo.
- Pregunta a tu Gemelo responde en el idioma de tu pregunta. Las entradas citadas quedan tal como las dijiste.
- Comparte tu cielo como Historia: una imagen de tu constelación real, a la medida de las historias de Instagram y los estados de WhatsApp. Solo muestra cuántas noches, nunca tus palabras, nombres o estados de ánimo. Se ofrece una vez en las noches 7, 21 y 42; en Ajustes > Compartir puedes desactivarlo.
- Las fechas, los números y las comillas siguen tu región.

CON FRANQUEZA
El estado de ánimo sugerido, las reflexiones, las tendencias de ánimo, los temas, las lecturas de personalidad y la búsqueda por significado solo leen inglés por ahora. En español se quedan callados en vez de adivinar, y la búsqueda encuentra las palabras que dijiste. Siempre puedes marcar tu estado de ánimo tú mismo.

CORREGIDO
- Lo que dices en español nunca se escribe en inglés si falta el modelo de voz. La grabación se guarda y la app te dice cómo instalar el modelo.
- La búsqueda solo dice «por significado» cuando de verdad buscó por significado.
```

*(1,429 of 4,000 characters.)*

**Description** (4,000 max)

```
DailyVox es un diario de voz privado. Tú hablas, tu iPhone lo escribe, y cada noche que hablas se convierte en una estrella de tu cielo. La transcripción se hace en el dispositivo. Sin cuenta y sin servidores de DailyVox.

HABLA EN ESPAÑOL
Toda la app está en español. En Ajustes > Idioma en el que hablas eliges en qué idioma te escucha DailyVox, que puede ser distinto del idioma de la app. Algunos idiomas necesitan una descarga única de Apple; después puedes grabar incluso en modo avión. Si tu iPhone no puede transcribir un idioma en el dispositivo, tu grabación se guarda y nunca se reescribe en inglés.

TU CIELO
Cada entrada se convierte en una estrella. La distancia al centro es cuánto tiempo hace que hablaste; el ángulo, la hora del día. Con el tiempo se forma una constelación hecha solo de ti.

¿AHORA NO PUEDES HABLAR?
Toca «Ahora no puedo hablar» y escribe. La entrada cuenta igual que una hablada.

TUS PALABRAS VUELVEN
«Hace una semana dijiste…», este día en meses y años anteriores y un resumen semanal, contado a partir de tus entradas. Una pregunta nueva cada día, con «Otra pregunta» a un toque. Un día de descanso a la semana no rompe tu racha.

PREGUNTA A TU GEMELO
Pregunta con tus propias palabras. La respuesta llega en el idioma de tu pregunta, sale de tus entradas y las cita con su fecha. Si nunca hablaste de algo, DailyVox te lo dice en vez de adivinar. Todo pasa en este iPhone.

COMPARTE TU CIELO, NUNCA TUS PALABRAS
En las noches 7, 21 y 42, DailyVox te ofrece una sola vez una imagen de tu constelación, a la medida de las historias de Instagram y los estados de WhatsApp. Solo muestra cuántas noches llevas, nunca tus palabras, nombres o estados de ánimo, y solo va adonde tú la envíes.

TU DIARIO
- Búsqueda por palabras en todo tu diario, escribiendo o con la voz
- Escucha cualquier grabación, avanza y cambia la velocidad de 0,5x a 2x
- Marca tu estado de ánimo y destaca entradas con una estrella
- Widgets en la pantalla de inicio y la pantalla bloqueada, y tus palabras en directo en la Dynamic Island
- Exporta en PDF, JSON, Markdown, CSV o texto
- Recordatorio por la noche y tres temas: Día, Noche y Atardecer
- Fechas y números con el formato de tu región

PRIVADO POR DISEÑO
- Bloqueo de la app con Face ID o Touch ID
- Copias cifradas y protegidas con contraseña (AES-256-GCM)
- Sincronización con iCloud opcional y desactivada por defecto
- Sin cuenta, sin rastreo, sin analíticas, sin anuncios
- Gratis y sin suscripción

POR AHORA SOLO EN INGLÉS
El estado de ánimo sugerido, la breve reflexión en cada entrada, las tendencias de ánimo, los temas, las lecturas de personalidad y la búsqueda por significado. Donde DailyVox aún no lee bien tu idioma, se queda callado en vez de adivinar.
```

*(2,739 of 4,000 characters.)*

**Support URL:** `https://getdailyvox.com/support` until #141 is live, then `https://getdailyvox.com/es/support`.

**Screenshots:** `ios/AppStore/screenshots/es-ES/` (being re-shot on the release branch; upload whatever that folder holds at submission).

### fr-FR — French

**Name** (30 max)

```
DailyVox : Journal vocal
```

*(24 of 30 characters.)*

**Subtitle** (30 max)

```
Privé, sur ton iPhone
```

*(21 of 30 characters.)*

**Keywords** (100 max)

```
intime,carnet,dictée,transcription,notes,audio,mémo,hors-ligne,gratitude,souvenirs,pensées,jumeau
```

*(97 of 100 characters.)*

**Promotional Text** (170 max)

```
Désormais en français : parle, et ton iPhone écrit, directement sur l'appareil. Chaque nuit où tu parles devient une étoile dans ton ciel.
```

*(138 of 170 characters.)*

**What's New in This Version** (4,000 max)

```
DailyVox parle désormais français.

NOUVEAU
- Toute l'app en français, et aussi en allemand, espagnol, italien et portugais du Brésil. Elle suit la langue choisie pour DailyVox dans les Réglages d'iOS.
- Réglages > Langue que tu parles : choisis la langue dans laquelle DailyVox t'écoute, indépendamment de la langue de l'app. La liste ne montre que les langues que cet iPhone sait transcrire sur l'appareil.
- Demande à ton Jumeau répond dans la langue de ta question. Les entrées citées restent telles que tu les as dites.
- Partage ton ciel en Story : une image de ta vraie constellation, au format des stories Instagram et des statuts WhatsApp. Elle montre seulement le nombre de nuits, jamais tes mots, les noms ou tes humeurs. Proposée une seule fois aux nuits 7, 21 et 42 ; Réglages > Partage désactive la proposition.
- Les dates, les nombres et les guillemets suivent ta région.

EN TOUTE FRANCHISE
L'humeur suggérée, les réflexions, les tendances d'humeur, les thèmes, les lectures de personnalité et la recherche par sens ne lisent que l'anglais pour l'instant. En français, ils se taisent au lieu de deviner, et la recherche trouve les mots que tu as dits. Tu peux toujours noter ton humeur toi-même.

CORRIGÉ
- Ce que tu dis en français n'est jamais écrit en anglais quand le modèle vocal manque. L'enregistrement est gardé, et l'app t'explique comment installer le modèle.
- La recherche ne dit « par sens » que lorsqu'elle a vraiment cherché par sens.
```

*(1,466 of 4,000 characters.)*

**Description** (4,000 max)

```
DailyVox est un journal intime vocal et privé. Tu parles, ton iPhone écrit, et chaque nuit où tu parles devient une étoile dans ton ciel. La transcription se fait sur l'appareil. Pas de compte, pas de serveur DailyVox.

PARLE EN FRANÇAIS
Toute l'app est en français. Dans Réglages > Langue que tu parles, tu choisis la langue dans laquelle DailyVox t'écoute ; elle peut différer de celle de l'app. Certaines langues demandent un téléchargement unique depuis Apple ; ensuite, tu peux enregistrer même en mode avion. Si ton iPhone ne sait pas transcrire une langue sur l'appareil, ton enregistrement est gardé et n'est jamais réécrit en anglais.

TON CIEL
Chaque entrée devient une étoile. La distance au centre dit depuis combien de temps tu as parlé, l'angle dit l'heure. Avec le temps, une constellation se forme, faite uniquement de toi.

TU NE PEUX PAS PARLER ?
Touche « Je ne peux pas parler maintenant » et écris. L'entrée compte exactement comme une entrée parlée.

TES MOTS REVIENNENT
« Il y a une semaine, tu disais… », ce jour-là les mois et les années précédents, et un récap de la semaine, compté à partir de tes entrées. Une nouvelle question chaque jour, avec « Autre question » à portée de doigt. Un jour de repos par semaine ne casse pas ta série.

DEMANDE À TON JUMEAU
Pose tes questions avec tes mots. La réponse arrive dans la langue de ta question, s'appuie sur tes entrées et les cite avec leur date. Si tu n'as jamais parlé de quelque chose, DailyVox te le dit au lieu de deviner. Tout se passe sur cet iPhone.

PARTAGE TON CIEL, JAMAIS TES MOTS
Aux nuits 7, 21 et 42, DailyVox te propose une seule fois une image de ta constellation, au format des stories Instagram et des statuts WhatsApp. Elle ne montre que le nombre de nuits gardées, jamais tes mots, les noms ou tes humeurs, et ne part que là où tu l'envoies.

TON JOURNAL
- Recherche par mots dans tout ton journal, au clavier ou à la voix
- Réécoute chaque enregistrement, avance et règle la vitesse de 0,5x à 2x
- Note toi-même ton humeur, mets des entrées en favori
- Widgets sur l'écran d'accueil et l'écran verrouillé, et tes mots en direct dans la Dynamic Island
- Export en PDF, JSON, Markdown, CSV ou texte
- Rappel le soir et trois thèmes : Jour, Nuit et Couchant
- Dates et nombres au format de ta région

PRIVÉ PAR CONCEPTION
- Verrouillage de l'app par Face ID ou Touch ID
- Sauvegardes chiffrées protégées par mot de passe (AES-256-GCM)
- Synchronisation iCloud facultative et désactivée par défaut
- Pas de compte, pas de pistage, pas d'analytique, pas de pub
- Gratuit, sans abonnement

EN ANGLAIS POUR L'INSTANT
L'humeur suggérée, la courte réflexion sur chaque entrée, les tendances d'humeur, les thèmes, les lectures de personnalité et la recherche par sens. Là où DailyVox ne lit pas encore bien ta langue, il se tait au lieu de deviner.
```

*(2,834 of 4,000 characters.)*

**Support URL:** `https://getdailyvox.com/support` until #141 is live, then `https://getdailyvox.com/fr/support`.

**Screenshots:** `ios/AppStore/screenshots/fr-FR/` (being re-shot on the release branch; upload whatever that folder holds at submission).

### it — Italian

**Name** (30 max)

```
DailyVox: Diario vocale
```

*(23 of 30 characters.)*

**Subtitle** (30 max)

```
Privato, sul tuo iPhone
```

*(23 of 30 characters.)*

**Keywords** (100 max)

```
journal,personale,dettatura,trascrizione,note,audio,offline,gratitudine,ricordi,pensieri,gemello
```

*(96 of 100 characters.)*

**Promotional Text** (170 max)

```
Ora in italiano: parla e il tuo iPhone scrive, direttamente sul dispositivo. Ogni notte in cui parli diventa una stella nel tuo cielo.
```

*(134 of 170 characters.)*

**What's New in This Version** (4,000 max)

```
DailyVox ora parla italiano.

NOVITÀ
- Tutta l'app in italiano, e anche in tedesco, spagnolo, francese e portoghese brasiliano. Segue la lingua che scegli per DailyVox nelle Impostazioni di iOS.
- Impostazioni > Lingua che parli: scegli in che lingua ti ascolta DailyVox, a prescindere dalla lingua dell'app. L'elenco mostra solo le lingue che questo iPhone sa trascrivere sul dispositivo.
- Chiedi al tuo Gemello risponde nella lingua della tua domanda. Le voci citate restano come le hai dette.
- Condividi il cielo come Storia: un'immagine della tua vera costellazione, nel formato delle storie di Instagram e dello stato di WhatsApp. Mostra solo quante notti, mai le tue parole, i nomi o il tuo umore. Proposta una sola volta alla notte 7, 21 e 42; in Impostazioni > Condivisione puoi disattivarla.
- Date, numeri e virgolette seguono la tua regione.

DETTO ONESTAMENTE
Umore suggerito, riflessioni, andamento dell'umore, temi, letture della personalità e ricerca per significato per ora leggono solo l'inglese. In italiano restano in silenzio invece di tirare a indovinare, e la ricerca trova le parole che hai detto. L'umore puoi sempre segnarlo tu.

CORRETTO
- Quello che dici in italiano non viene mai scritto in inglese se manca il modello vocale. La registrazione resta salvata e l'app ti spiega come installare il modello.
- La ricerca dice "per significato" solo quando ha davvero cercato per significato.
```

*(1,417 of 4,000 characters.)*

**Description** (4,000 max)

```
DailyVox è un diario vocale privato. Tu parli, il tuo iPhone scrive, e ogni notte in cui parli diventa una stella nel tuo cielo. La trascrizione avviene sul dispositivo. Niente account, nessun server di DailyVox.

PARLA IN ITALIANO
Tutta l'app è in italiano. In Impostazioni > Lingua che parli scegli in che lingua ti ascolta DailyVox, anche diversa dalla lingua dell'app. Alcune lingue richiedono un download unico da Apple; dopo puoi registrare anche in modalità aereo. Se il tuo iPhone non sa trascrivere una lingua sul dispositivo, la registrazione resta salvata e non viene mai riscritta in inglese.

IL TUO CIELO
Ogni voce del diario diventa una stella. La distanza dal centro dice quanto tempo fa hai parlato, l'angolo dice l'ora del giorno. Col tempo nasce una costellazione fatta solo di te.

ORA NON PUOI PARLARE?
Tocca "Ora non posso parlare" e scrivi. La voce conta esattamente come una parlata.

LE TUE PAROLE TORNANO
"Una settimana fa hai detto…", questo giorno nei mesi e negli anni passati e un riepilogo settimanale, contato dalle tue voci. Una domanda nuova ogni giorno, con "Un'altra domanda" a un tocco. Un giorno di riposo a settimana non interrompe la tua serie.

CHIEDI AL TUO GEMELLO
Chiedi con parole tue. La risposta arriva nella lingua della domanda, parte dalle tue voci e le cita con la data. Se non hai mai parlato di qualcosa, DailyVox te lo dice invece di inventare. Tutto succede su questo iPhone.

CONDIVIDI IL TUO CIELO, MAI LE TUE PAROLE
Alla notte 7, 21 e 42, DailyVox ti propone una sola volta un'immagine della tua costellazione, nel formato delle storie di Instagram e dello stato di WhatsApp. Mostra solo quante notti hai custodito, mai le tue parole, i nomi o il tuo umore, e va solo dove la mandi tu.

IL TUO DIARIO
- Ricerca per parole in tutto il diario, scrivendo o a voce
- Riascolta ogni registrazione, scorri e cambia velocità da 0,5x a 2x
- Segna tu l'umore e metti una stella alle voci
- Widget nella schermata Home e nella schermata di blocco, e le tue parole dal vivo nella Dynamic Island
- Esporta in PDF, JSON, Markdown, CSV o testo
- Promemoria la sera e tre temi: Giorno, Notte e Tramonto
- Date e numeri nel formato della tua regione

PRIVATO PER COSTRUZIONE
- Blocco dell'app con Face ID o Touch ID
- Backup cifrati e protetti da password (AES-256-GCM)
- Sincronizzazione iCloud facoltativa e disattivata di default
- Niente account, niente tracciamento, niente analisi, niente pubblicità
- Gratis, senza abbonamento

PER ORA SOLO IN INGLESE
L'umore suggerito, la breve riflessione su ogni voce, l'andamento dell'umore, i temi, le letture della personalità e la ricerca per significato. Dove DailyVox non legge ancora bene la tua lingua, resta in silenzio invece di tirare a indovinare.
```

*(2,745 of 4,000 characters.)*

**Support URL:** `https://getdailyvox.com/support` until #141 is live, then `https://getdailyvox.com/it/support`.

**Screenshots:** `ios/AppStore/screenshots/it/` (being re-shot on the release branch; upload whatever that folder holds at submission).

### pt-BR — Portuguese (Brazil)

**Name** (30 max)

```
DailyVox: Diário por voz
```

*(24 of 30 characters.)*

**Subtitle** (30 max)

```
Privado, no seu iPhone
```

*(22 of 30 characters.)*

**Keywords** (100 max)

```
journal,pessoal,ditado,transcrição,notas,áudio,gravador,offline,gratidão,memórias,pensamentos,twin
```

*(98 of 100 characters.)*

**Promotional Text** (170 max)

```
Agora em português: fale e o seu iPhone escreve, no próprio aparelho. Cada noite em que você fala vira uma estrela no seu céu.
```

*(126 of 170 characters.)*

**What's New in This Version** (4,000 max)

```
O DailyVox agora fala português.

NOVIDADES
- O app inteiro em português do Brasil, e também em alemão, espanhol, francês e italiano. Ele segue o idioma que você escolhe para o DailyVox nos Ajustes do iOS.
- Ajustes > Idioma em que você fala: escolha em que idioma o DailyVox escuta você, separado do idioma do app. A lista mostra só os idiomas que este iPhone consegue transcrever no aparelho.
- Pergunte ao seu Twin responde no idioma da sua pergunta. Os registros citados ficam exatamente como você falou.
- Compartilhe seu céu nos Stories: uma imagem da sua constelação de verdade, no formato dos stories do Instagram e do status do WhatsApp. Mostra só quantas noites, nunca suas palavras, nomes ou humores. Oferecida uma única vez nas noites 7, 21 e 42; em Ajustes > Compartilhamento você desliga a sugestão.
- Datas, números e aspas seguem a sua região.

COM FRANQUEZA
O humor sugerido, as reflexões, as tendências de humor, os temas, as leituras de personalidade e a busca por sentido, por enquanto, só leem inglês. Em português eles ficam quietos em vez de chutar, e a busca encontra as palavras que você falou. Você sempre pode marcar o seu humor.

CORRIGIDO
- O que você fala em português nunca é escrito em inglês quando falta o modelo de voz. A gravação fica salva, e o app explica como instalar o modelo.
- A busca só diz "por sentido" quando realmente buscou por sentido.
```

*(1,385 of 4,000 characters.)*

**Description** (4,000 max)

```
O DailyVox é um diário por voz privado. Você fala, o seu iPhone escreve, e cada noite em que você fala vira uma estrela no seu céu. A transcrição acontece no aparelho. Sem conta e sem servidores do DailyVox.

FALE EM PORTUGUÊS
O app inteiro está em português do Brasil. Em Ajustes > Idioma em que você fala, você escolhe em que idioma o DailyVox escuta, que pode ser diferente do idioma do app. Alguns idiomas precisam de um download único da Apple; depois disso, dá para gravar até no modo avião. Se o seu iPhone não consegue transcrever um idioma no aparelho, a gravação fica salva e nunca é reescrita em inglês.

SEU CÉU
Cada registro vira uma estrela. A distância do centro mostra há quanto tempo você falou; o ângulo, a hora do dia. Com o tempo, nasce uma constelação feita só de você.

NÃO DÁ PARA FALAR AGORA?
Toque em "Não posso falar agora" e escreva. O registro conta igualzinho a um falado.

SUAS PALAVRAS VOLTAM
"Há uma semana você disse…", este dia em meses e anos anteriores e um resumo da semana, contado a partir dos seus registros. Uma pergunta nova todo dia, com "Outra pergunta" a um toque. Um dia de descanso por semana não quebra a sua sequência.

PERGUNTE AO SEU TWIN
Pergunte com as suas palavras. A resposta vem no idioma da pergunta, se apoia nos seus registros e cita cada um com a data. Se você nunca falou de algo, o DailyVox diz isso em vez de chutar. Tudo acontece neste iPhone.

COMPARTILHE SEU CÉU, NUNCA SUAS PALAVRAS
Nas noites 7, 21 e 42, o DailyVox oferece uma única vez uma imagem da sua constelação, no formato dos stories do Instagram e do status do WhatsApp. Ela mostra só quantas noites você guardou, nunca suas palavras, nomes ou humores, e só vai para onde você mandar.

SEU DIÁRIO
- Busca por palavras no diário inteiro, digitando ou falando
- Ouça qualquer gravação, avance e mude a velocidade de 0,5x a 2x
- Marque o seu humor e destaque registros com estrela
- Widgets na tela de início e na tela bloqueada, e suas palavras ao vivo na Dynamic Island
- Exporte em PDF, JSON, Markdown, CSV ou texto
- Lembrete à noite e três temas: Dia, Noite e Pôr do sol
- Datas e números no formato da sua região

PRIVADO DE PROPÓSITO
- Bloqueio do app com Face ID ou Touch ID
- Backups criptografados e protegidos por senha (AES-256-GCM)
- Sincronização com o iCloud opcional e desligada por padrão
- Sem conta, sem rastreamento, sem análises, sem anúncios
- Grátis, sem assinatura

POR ENQUANTO, SÓ EM INGLÊS
O humor sugerido, a breve reflexão em cada registro, as tendências de humor, os temas, as leituras de personalidade e a busca por sentido. Onde o DailyVox ainda não lê bem o seu idioma, ele fica quieto em vez de chutar.
```

*(2,661 of 4,000 characters.)*

**Support URL:** `https://getdailyvox.com/support` until #141 is live, then `https://getdailyvox.com/pt-br/support`.

**Screenshots:** `ios/AppStore/screenshots/pt-BR/` (being re-shot on the release branch; upload whatever that folder holds at submission).

---

## 5. Screenshots

| Locale | Folder |
|---|---|
| en-US | unchanged (`ios/AppStore/screenshots/iPhone_*`) |
| de-DE | `ios/AppStore/screenshots/de-DE/` |
| es-ES | `ios/AppStore/screenshots/es-ES/` |
| fr-FR | `ios/AppStore/screenshots/fr-FR/` |
| it | `ios/AppStore/screenshots/it/` |
| pt-BR | `ios/AppStore/screenshots/pt-BR/` |

The localized sets are being re-shot now, after the Ask and search fixes; upload
what each folder holds when you submit. Check that no localized shot shows a
suggested mood, a reflection or "Search by meaning": in those languages the build
does not show them.

---

## 6. App Review Information → Notes

Replace the existing notes with the full contents of
`ios/AppStore/ReviewNotes_1.14.0.txt` (3,343 of 4,000 characters). It stands
on its own: it keeps the 1.13.0 sections that still apply (on-device speech, iCloud,
Health, permissions) and adds the languages, the "Language you speak" setting, the
quiet English-only features, and the sky Story card with how to turn it off.

**Demo account:** none required. No accounts exist.

---

## 7. Fields that do NOT change

| Field | Why it stays |
|---|---|
| English Name, Subtitle, Keywords, Description | Unchanged for en-US |
| Category, Age Rating, Price | Unchanged |
| **App Privacy ("Data Not Collected")** | Still correct: the languages, the language column and the Story card run on the device; the card goes only where the user sends it from the share sheet |

---

## 8. CloudKit — deploy before submitting

Build 49 adds an optional `transcriptLocale` attribute to `DiaryEntry`. Deploy
`CD_DiaryEntry.CD_transcriptLocale` to **Production** before this build ships:
CloudKit Dashboard → Development → Deploy Schema Changes, then switch to Production
and check that `CD_DiaryEntry` lists `CD_transcriptLocale` (next to `CD_suggestedMood`
from 1.13.0). Then confirm with a TestFlight build: turn sync on, save an entry, and
check Production → Records for a `CD_DiaryEntry` carrying `CD_transcriptLocale`.

---

## 9. Pre-submit checklist

1. [ ] **CloudKit:** `CD_DiaryEntry.CD_transcriptLocale` deployed to Production and
   seen on a TestFlight-written record (§8).
2. [ ] **Build 49** is the one attached (the release branch was at 48 when this was
   written; check `CURRENT_PROJECT_VERSION`).
3. [ ] **Engine:** DailyVoxTwin #38 (language gate) and #39 (Ask phrases) merged, and
   the app's SPM pin includes both. Without #39, Ask answers in English everywhere and
   the localized What's New line about Ask is false.
4. [ ] **Device pass in each language** (set iOS Settings > DailyVox > Language): the
   onboarding, Today, an entry spoken in that language, Search (no "by meaning", no
   "% match"), Ask your Twin (frame and dates in that language, quotes as said), the
   Story card at night 7, and Settings > Language you speak. Largest Dynamic Type once.
5. [ ] **Screenshots** re-shot and uploaded for de-DE, es-ES, fr-FR, it, pt-BR (§5).
6. [ ] **Every localization has a Support URL** (English one until #141 is live).
7. [ ] **Review notes** replaced with `ReviewNotes_1.14.0.txt` (§6).
8. [ ] **Hindi absent:** no `hi.lproj`, no Hindi listing. ("Language you speak" may
   offer Hindi speech on iOS 26; the interface does not claim it.)

---

## 10. Order of operations

1. Merge DailyVoxTwin #38 → #39, then app #137 / #139 into `release/ios-1.14.0`, then #135
2. Bump to build 49 if not already done; archive; Organizer → Distribute App → App Store Connect
3. CloudKit deploy and TestFlight sync check (§8)
4. Device pass (§9.4)
5. Create 1.14.0 in ASC; attach build 49
6. Paste en-US What's New (§2) and Promotional Text (§3)
7. Add the five languages and paste their fields (§4); upload screenshots (§5)
8. Replace Review Notes (§6)
9. Submit
