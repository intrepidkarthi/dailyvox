---
slug: journal-app-privacy-comparison
lang: de
source: /blog/journal-app-privacy-comparison
title: "Tagebuch-Apps im Datenschutz-Vergleich: Wer liest mit?"
meta_description: "Die meisten nicht. 10 Apps im Flugmodus getestet: 8 nutzen Accounts und Cloud. Nur Apple Journal und DailyVox lassen Einträge auf deinem Smartphone."
---
**Transparenzhinweis:** Geschrieben von Karthikeyan NG, dem Entwickler von DailyVox – einer der hier getesteten Apps. Da hier ein Interessenkonflikt vorliegt, kannst du die Methode unten selbst ausprobieren: Jede Datenschutz-Aussage lässt sich in etwa zehn Sekunden im Flugmodus überprüfen, oder noch gründlicher mit einem Netzwerk-Proxy. Verlass dich auf kein Wort von mir – mach selbst den Test.

Dein Papiertagebuch würdest du nicht offen auf einer Parkbank liegen lassen. Aber die meisten Menschen haben keine Ahnung, ob ihr digitales Journal im Grunde genau das tut: auf einem Server liegen, lesbar für das Unternehmen hinter der App, dessen Mitarbeiter oder jeden, der in deren Systeme eindringt.

Wir haben uns 10 beliebte Journal- und Tagebuch-Apps angesehen, ihre Datenschutzlabels im App Store geprüft, die Datenschutzerklärungen gelesen und getestet, was passiert, wenn man sie offline nutzt. Das sind die Ergebnisse.

## Die Datenschutz-Vergleichstabelle

| App | Erfasste Daten | Cloud-Verarbeitung | Account erforderlich | Verschlüsselung | Datenschutzlabel |
|---|---|---|---|---|---|
| **DailyVox** | Keine | Nein – komplett auf dem Gerät | Nein | Nur auf dem Gerät | Data Not Collected |
| **Apple Journal** | Nutzungsdaten | iCloud-Sync (optional) | Apple ID | Ende-zu-Ende (iCloud) | Minimal |
| **Day One** | Identifikatoren, Nutzung, Diagnose | Ja – Sync und KI-Funktionen | Ja | Ende-zu-Ende (Premium) | Linked to You |
| **Reflectly** | Identifikatoren, Nutzung, Einkäufe | Ja – KI-Analyse in der Cloud | Ja | Nicht angegeben | Linked to You |
| **Jour** | Identifikatoren, Nutzung, Diagnose | Ja – KI-Coaching in der Cloud | Ja | Nicht angegeben | Linked to You |
| **Notion** | Identifikatoren, Nutzung, Inhalte | Ja – alle Inhalte auf Servern | Ja | Im Ruhezustand und bei der Übertragung (kein E2E) | Linked to You |
| **Obsidian** | Keine (ohne Sync) | Nein (außer bei Nutzung des Sync-Add-ons) | Nein | Lokale Dateien / E2E mit Sync | Data Not Collected |
| **Penzu** | Identifikatoren, Nutzung | Ja – alle Einträge auf Servern | Ja | AES-256 (nur Pro) | Linked to You |
| **Diarium** | Diagnose | Optionaler Cloud-Sync | Nein | Auf Geräteebene | Minimal |
| **Journey** | Identifikatoren, Nutzung, Diagnose | Ja – Google Drive oder Journey Cloud | Ja | Bei der Übertragung (standardmäßig kein E2E) | Linked to You |

## Was dir diese Tabelle verrät

Die wichtigste Spalte ist „Cloud-Verarbeitung“. Wenn deine Einträge auf einem Server landen, kann theoretisch jemand anderes darauf zugreifen. Dabei spielt es keine Rolle, wie gut die Verschlüsselung bei der Übertragung ist: Sobald Daten auf einem Server liegen, hast du keine Kontrolle mehr darüber.

Nur drei Apps auf dieser Liste behalten deine Daten standardmäßig komplett auf deinem Gerät: DailyVox, Obsidian und Diarium. Alle anderen verlangen, dass dein Tagebuch an einen Server gesendet wird – sei es für die Synchronisierung, KI-Funktionen oder grundlegende Funktionen.

## Das Problem mit der Account-Pflicht

Wenn eine App einen Account verlangt, weiß das Unternehmen, wer du bist. Deine Tagebucheinträge sind mit deiner E-Mail-Adresse, deinem Namen und deiner Identität verknüpft. Selbst bei einer Ende-zu-Ende-Verschlüsselung sind Metadaten für den Dienst sichtbar: wann du Tagebuch schreibst, wie oft und wie lang deine Einträge sind.

Apps, die ohne Account funktionieren (DailyVox, Obsidian, Diarium), können deine Daten nicht mit deiner Identität verknüpfen, weil sie deine Identität von vornherein gar nicht erfassen.

## Ende-zu-Ende-Verschlüsselung: Notwendig, aber nicht ausreichend

Ende-zu-Ende-Verschlüsselung (E2E) bedeutet, dass das Unternehmen deine Daten auf seinen Servern nicht lesen kann. Day One bietet das für Premium-Nutzer an. Apple bietet es für iCloud-Daten. Das ist gut, löst aber nicht jedes Problem:

- E2E verhindert nicht, dass das Unternehmen Metadaten sieht.
- E2E nützt nichts, wenn das Unternehmen KI-Funktionen in der Cloud betreibt – zur Verarbeitung müssen die Daten entschlüsselt werden.
- E2E schützt dich nicht, falls das Unternehmen sein Verschlüsselungskonzept in Zukunft ändert.
- E2E bedeutet immer noch, dass deine verschlüsselten Daten auf dem Server eines Fremden liegen.

Der sicherste Ansatz sind Daten, die dein Gerät nie verlassen. Verschlüsselung ist eine Schadensbegrenzung für Cloud-Speicher – kein Ersatz für rein lokale Speicherung.

## Was „Data Not Collected“ im App Store bedeutet

Die Datenschutzlabels von Apple im App Store verpflichten Entwickler offenzulegen, welche Daten ihre App erfasst. Das Label „Data Not Collected“ bedeutet, dass die App keinerlei Daten vom Gerät wegschickt.

Das ist der höchste Datenschutzstandard im App Store. Nur zwei Journal-Apps in unserem Vergleich tragen ihn: DailyVox und Obsidian. Du kannst das Datenschutzlabel jeder App selbst im App Store unter „App-Datenschutz“ nachprüfen. Wenn du genauer verstehen willst, was diese Labels bedeuten, lies unseren Leitfaden zu [Anzeichen dafür, dass deine Journal-App deine Daten verkauft](/blog/signs-your-journal-app-is-selling-your-data).

## KI-Funktionen und Datenschutz: Der Konflikt

Hier ist die unbequeme Wahrheit: Die meisten KI-gestützten Journal-Funktionen erfordern Cloud-Verarbeitung. Reflectly, Jour und die KI-Funktionen von Day One schicken deine Einträge zur Analyse ausnahmslos an Server. Anders können sie diese Funktionen nicht anbieten – die KI-Modelle sind schlicht zu groß für ein Smartphone.

DailyVox ist eine Ausnahme. Die App führt KI-Funktionen – Sprachtranskription, Sentiment-Analyse, Mood-Tracking, Digital Twin – komplett auf dem Gerät aus und nutzt dafür Apples Core ML- und Natural Language-Frameworks. Der Kompromiss: On-Device-Modelle sind weniger leistungsfähig als Cloud-Modelle wie GPT-4. Für das Führen eines Tagebuchs reichen On-Device-Modelle jedoch völlig aus.

## Unsere Empfehlung

Wenn Datenschutz für dich an erster Stelle steht – und bei einem Tagebuch sollte er das –, wähle eine App aus der Kategorie „Data Not Collected“. Dein Tagebuch enthält die persönlichsten Daten, die du überhaupt erzeugst. Es verdient den stärksten verfügbaren Schutz, und der ist simpel: Daten, die dein Gerät nie verlassen, können weder geleakt, verkauft noch per Gerichtsbeschluss herausverlangt werden.

Unser vollständiges datenschutzorientiertes Ranking mit ausführlichen Tests findest du unter [die beste Journal-App für Datenschutz](/blog/best-journal-app-for-privacy). Wenn du dein Tagebuch per Sprache führst, bewertet unser Guide [die beste Sprachtagebuch-App](/blog/best-voice-journal-app) sieben Apps nach denselben Datenschutzkriterien, und der [Journal-App-Vergleich](/compare) stellt die großen textbasierten Apps direkt gegenüber. Und wenn du genau verstehen willst, wie On-Device-KI die Datenschutzprobleme der Cloud-Verarbeitung umgeht, lies [wie On-Device-KI funktioniert](/blog/how-on-device-ai-works).

## Wer kann mitlesen, was du einer KI-App anvertraust?

Jede App in der Tabelle oben gibt irgendein Datenschutzversprechen ab. Der eigentliche Test ist simpler als jedes davon: Auf welchen Computern liegt nach dem Speichern eines Eintrags eine lesbare Kopie?

Genau damit werden KI-Apps derzeit beworben. Am 21. Oktober 2026 kündigte Eternal mit Dark einen KI-Assistenten an, dessen Werbeversprechen lautet: „Wir können deine Unterhaltungen nicht lesen“. Laut Ankündigung sind Chats Ende-zu-Ende-verschlüsselt und werden auf Eternals eigenen Servern verarbeitet. Das ist besser als ein Anbieter, der mitliest und prüft, was du tippst – aber deine Worte liegen immer noch auf den Rechnern eines Unternehmens, geschützt nur durch dessen Schlüssel und Richtlinien.

Im Grunde gibt es drei Antworten: Ein Unternehmen kann deine Texte lesen. Ein Unternehmen speichert deine Texte, behauptet aber, sie nicht lesen zu können. Oder kein Unternehmen bekommt sie jemals zu Gesicht. DailyVox gehört zur dritten Kategorie. Es gibt keinen Account und kein Backend, die KI läuft direkt auf dem Smartphone, und ein Eintrag verlässt das Gerät nur über den iCloud-Sync zwischen deinen eigenen Geräten, wenn du ihn einschaltest. Der Quellcode ist Open Source – man muss dieser Aussage also nicht blind vertrauen, man kann sie nachprüfen.

Lesetipp dazu: [Kann das Unternehmen mitlesen, was du seiner KI erzählst?](/blog/can-the-company-read-what-you-tell-its-ai)

## Häufig gestellte Fragen

### Was ist der Unterschied zwischen Journey Cloud und Journey Premium beim Datenschutz?

Journey Premium schaltet die Synchronisierung über Journey Cloud frei, aktiviert aber standardmäßig keine Ende-zu-Ende-Verschlüsselung. Deine Einträge sind nur bei der Übertragung verschlüsselt, nicht auf den Servern des Anbieters. Day One löst das besser und macht Zero-Knowledge-Verschlüsselung zum Standard für synchronisierte Einträge. Ich habe DailyVox gebaut, um gänzlich auf Server zu verzichten. Jede Sprachnotiz bleibt auf deinem iPhone. Der Nachteil liegt auf der Hand: Wenn du dein iPhone ohne lokales Backup verlierst, sind deine Einträge für immer weg.

### Ist der Journey Cloud-Sync erforderlich, um Tagebucheinträge über mehrere Geräte hinweg zu sichern?

Nein. Apps handhaben Backups je nach Architektur unterschiedlich. Journey setzt auf Google Drive oder die hauseigene Journey Cloud. Apple Journal und Day One nutzen die iCloud-Infrastruktur zur Synchronisierung. DailyVox hat keine eigenen Server und nutzt den lokalen iPhone-Speicher – du kannst Audiodateien jedoch über Apples CloudKit synchronisieren. Wenn du Webzugriff oder geräteübergreifende Synchronisierung brauchst, funktioniert Journey. DailyVox nicht, denn ich weigere mich, Servercode für deine privaten Gedanken zu schreiben. Für die Android-App gilt dieselbe Regel: keine Server, und sie verlangt überhaupt keine Internetberechtigung.

### Kann ich automatisches Mood-Tracking und Journal-Analysen nutzen, ohne Daten in die Cloud hochzuladen?

Ja. Apps wie Rosebud und Daylio verarbeiten Stimmungstrends auf entfernten Servern oder setzen auf simple manuelle Protokolle. DailyVox führt ein lokales Digital Twin-Modell über Apple-Frameworks direkt auf der Hardware deines iPhone aus. Es erfasst emotionale Muster, ohne ein einziges Byte an eine externe API zu senden. Das funktioniert komplett im Flugmodus. Der Nachteil ist die Bindung an die Plattform: Du kannst dir diese emotionalen Trends weder im Webbrowser noch auf einem Computer ansehen.
