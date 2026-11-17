package com.dailyvox.app.data

/**
 * The demo journal in the 1.3 languages, for LOCALIZED store screenshots only.
 *
 * Same 38 nights as [DummyData]'s English corpus, in the same order, so index i
 * here is index i there (durations and dates are shared). Machine-drafted in a
 * spoken-diary register, not word for word.
 *
 * People are localised once per language and kept consistent across every
 * entry, so the Twin's people read as one cast rather than a shuffle:
 *
 *            Sarah    James    Emma      (Priya, Adyah, Rahul, Mumbai unchanged)
 *   de       Lena     Jonas    Marie
 *   es       Lucía    Javier   Carmen
 *   fr       Camille  Julien   Léa
 *   it       Giulia   Marco    Chiara
 *   pt-BR    Ana      Rafael   Beatriz
 *
 * None of these ever reached a real install (the seeder they feed is
 * DEBUG && SEED_DEMO_DATA only, and they were added after that gate), so they
 * are deliberately NOT in [DummyData.demoTexts]: the purge removes only what
 * actually shipped.
 */
internal object DummyDataTranslations {

    /** Keyed by the BCP-47 tag written into [Entry.language]. */
    val byTag: Map<String, List<String>> by lazy {
        mapOf("de-DE" to de, "es-ES" to es, "fr-FR" to fr, "it-IT" to it, "pt-BR" to ptBR)
    }

    /** "de", "de-DE", "pt-BR", "pt_BR"... to the tag above, or null. */
    fun tagFor(lang: String): String? {
        val norm = lang.trim().replace('_', '-')
        if (norm.isEmpty()) return null
        byTag.keys.firstOrNull { it.equals(norm, ignoreCase = true) }?.let { return it }
        val base = norm.substringBefore('-').lowercase()
        return byTag.keys.firstOrNull { it.substringBefore('-') == base }
    }

    private val de = listOf(
        "Bin spazieren gegangen, bevor irgendwer wach war. Lenas Flug landet heute Abend und ich bin nervöser, als ich dachte. Das Haus fühlt sich anders an, wenn jemand gleich zurückkommt, als hätte es die Luft angehalten.",
        "Das Review ist schiefgelaufen. Jonas hat beim Zeitplan dagegengehalten und ich hab mich davon runterziehen lassen. Ich hätte weniger reden und länger zuhören sollen, und das wusste ich schon, während es passiert ist.",
        "Marie hat aus dem Nichts angerufen und wir haben zwei Stunden geredet. Nichts Wichtiges, und doch alles wichtig. Ich vergesse immer, wie viel leichter ich mich danach fühle, bis ich auflege.",
        "Lange Wanderung mit Lena den Kammweg hoch. Einen knappen Kilometer unterm Gipfel hat es angefangen zu regnen und keiner von uns hatte eine Jacke dabei. Der schönste Nachmittag seit Wochen, und keiner von uns hat es laut gesagt.",
        "Wieder schlecht geschlafen. Die Arbeit liegt mir um drei Uhr morgens auf der Brust und ich krieg sie nicht los. Ich muss das in den Griff kriegen, bevor es mich in den Griff kriegt.",
        "Priya hat Fotos von der Hochzeit geschickt. Die Mangotorte, der Stromausfall mitten im Essen, eine Rede, die zwanzig Minuten zu lang war. Ich hab im Bus laut gelacht und es war mir völlig egal.",
        "Ruhiger Sonntag. Zum ersten Mal seit zwei Wochen richtig gekocht, auf dem Balkon gelesen, den Laptop kein einziges Mal aufgeklappt. Ruhig, und ich hab es gemerkt, während es so war.",
        "Hab Lena endlich das mit dem Job erzählt. Sie war gelassener als ich. Dankbar ist das Wort, auch wenn es zu klein ist für das, was sie getan hat.",
        "Heute frustriert über mich selbst. Derselbe Streit mit Jonas, genau wie letzten Monat. Ich entscheide mich immer wieder dafür, recht zu haben, statt hilfreich zu sein.",
        "Die Runde um den Stausee gelaufen. Irgendwie Gegenwind in beide Richtungen. Beine müde, Kopf klar, und das ist der Tausch, den ich immer wieder mache und über den ich immer wieder froh bin.",
        "Marie zieht im März nach Mumbai. Ich freu mich für sie und bin gleichzeitig still am Boden. Beides, den ganzen Tag, ohne dass eins gewinnt.",
        "Gute Woche. Das Projekt ist raus, drei Nächte am Stück sieben Stunden geschlafen, und nichts ist kaputtgegangen. Ich schreib das auf, damit ich mich erinnere, dass es passiert ist.",
        "Kaffee mit Adyah vor der Arbeit. Sie hat gefragt, was ich dieses Jahr eigentlich will, und ich hatte keine Antwort parat. Das hat mir schon etwas gesagt.",
        "Die Wohnung ist zu still, solange Lena weg ist. Musik angemacht und schlecht gekocht. Hat mehr geholfen, als es sollte.",
        "Langer Tag im Studio mit Rahul. Wir haben die ganze zweite Hälfte umgebaut und sie ist besser, aber ich laufe auf Reserve.",
        "Den ganzen Nachmittag Regen. Am Fenster gelesen und das Handy im anderen Zimmer gelassen. Solche Stunden sollte ich besser schützen.",
        "Jonas hat sich entschuldigt, richtig, ohne dass ich darum gebeten hab. Damit hab ich nicht gerechnet und ich bin nicht gut damit umgegangen. Aber besser als letzten Monat.",
        "Priya und das Baby besucht. Sie eine Stunde lang gehalten und sonst nichts geschafft. Mit Abstand die schönste Stunde des Monats.",
        "Graue Stimmung, ohne besonderen Grund. Bin trotzdem zum Markt gelaufen und hab viel zu viele Orangen gekauft. Kleine Siege zählen auch.",
        "Lena ist wieder da. Das Haus klingt wieder richtig. Wir sind viel zu lange aufgeblieben und ich bereue nichts davon.",
        "Vor dem Vorstand präsentiert und es lief gut. Nach drei Wochen Bammel fühlt sich das fast enttäuschend unspektakulär an.",
        "Heute ist nichts passiert, und genau darum ging es. Der erste Samstag seit Monaten ganz ohne Pläne.",
        "Adyahs Abschied beim Nudelladen. Laut, herzlich, ein bisschen zu lang, genau richtig. Mumbai kann sich glücklich schätzen.",
        "Um vier aufgewacht und nicht mehr eingeschlafen. Um fünf Tee gemacht und zugesehen, wie es hell wird. Seltsam friedlich, als ich aufgehört hab, dagegen anzukämpfen.",
        "Traillauf mit Rahul im Nebel. Man konnte keine zehn Meter weit sehen und es war die beste Stunde der Woche.",
        "Schwieriger Call mit dem Team. Das Ehrliche gesagt statt dem Bequemen, und das hat mich den Nachmittag gekostet.",
        "Marie hat ein Foto von ihrer neuen Wohnung in Mumbai geschickt. Kahle Wände, schönes Licht. Sie klingt wieder wie sie selbst.",
        "Neun Stunden geschlafen und das hat den ganzen Tag verändert. Diese Lektion lerne ich immer wieder neu und vergesse sie immer wieder.",
        "Lena hat gekocht, ich hab abgewaschen, wir haben über einen Film gestritten, den keiner von uns mochte. Ein ganz normaler Abend, und ich würde ihn behalten.",
        "Nach zwei Wochen Pause wieder die Runde um den Stausee. Langsamer, als ich wollte, glücklicher, als ich dachte.",
        "Jonas und ich haben uns endlich auf den Zeitplan geeinigt. Hat drei Wochen länger gedauert als nötig, und das meiste davon geht auf mich.",
        "Ruhige Woche, stetige Arbeit, nichts zu berichten. Das aufzuschreiben fühlt sich an wie eine eigene Art von Fortschritt.",
        "Priya hat gefragt, wie es mir wirklich geht, und auf die echte Antwort gewartet. Das machen nicht viele.",
        "Im Morgengrauen allein zum Kammweg gelaufen. Niemand da. Zwanzig Minuten gesessen und anders zurückgekommen.",
        "Schlechte Nachrichten wegen der Finanzierung. Hab sie erst mal sacken lassen, Lena davon erzählt, mich besser gefühlt. Immer noch schlechte Nachrichten, aber tragbar.",
        "Die erste richtige Sonne seit Wochen. Vom Balkon aus gearbeitet und mehr geschafft als in einer Woche am Schreibtisch.",
        "Rahul macht sich selbstständig. Ich bin nervös für ihn und ein bisschen neidisch, und das sollte ich mir merken.",
        "Jetzt schon zwei Monate. Wenn ich mir die ersten Einträge anhöre, klinge ich wie jemand anderes. Genau darum geht es ja.",
    )

    private val es = listOf(
        "Salí a caminar antes de que nadie se despertara. El vuelo de Lucía aterriza esta noche y estoy más nerviosa de lo que esperaba. La casa se siente distinta cuando alguien está a punto de volver, como si hubiera estado aguantando la respiración.",
        "La revisión salió torcida. Javier se plantó con el calendario y dejé que me afectara. Debería haber hablado menos y escuchado más, y lo sabía mientras estaba pasando.",
        "Carmen me llamó de la nada y estuvimos hablando dos horas. Nada importante, y todo importante. Siempre se me olvida lo ligera que me quedo después, hasta que cuelgo.",
        "Caminata larga por la cresta con Lucía. Nos pilló la lluvia a menos de un kilómetro de la cima y ninguna llevaba chaqueta. La mejor tarde en semanas y ninguna lo dijo en voz alta.",
        "Otra vez dormí fatal. El trabajo se me sienta en el pecho a las tres de la mañana y no consigo soltarlo. Tengo que arreglar esto antes de que me arregle a mí.",
        "Priya mandó fotos de la boda. La tarta de mango, el apagón a mitad de la cena, un discurso que se alargó veinte minutos. Me reí en voz alta en el autobús y me dio igual.",
        "Domingo tranquilo. Cociné en serio por primera vez en dos semanas, leí en el balcón y no abrí el portátil ni una vez. Calma, y me di cuenta mientras la estaba viviendo.",
        "Por fin le conté a Lucía lo del trabajo. Ella se lo tomó con más calma que yo. Agradecida es la palabra, aunque se queda pequeña para lo que hizo.",
        "Hoy estoy frustrada conmigo misma. La misma discusión con Javier, igualita a la del mes pasado. Sigo eligiendo tener razón en vez de ser útil.",
        "Di la vuelta al embalse corriendo. Viento en contra en las dos direcciones, no sé cómo. Piernas cansadas, cabeza despejada, que es el trato que siempre hago y del que siempre me alegro.",
        "Carmen se muda a Mumbai en marzo. Me alegro por ella y por dentro estoy hecha polvo. Las dos cosas, todo el día, sin que gane ninguna.",
        "Buena semana. Entregué el proyecto, dormí siete horas tres noches seguidas y no se rompió nada. Lo apunto para acordarme de que pasó.",
        "Café con Adyah antes del trabajo. Me preguntó qué quiero de verdad este año y no tenía una respuesta preparada, y eso ya me dijo algo.",
        "El piso está demasiado callado sin Lucía. Puse música y cociné mal. Me ayudó más de lo que debería.",
        "Día largo en el estudio con Rahul. Rehicimos toda la segunda mitad y ha quedado mejor, pero voy con la batería en las últimas.",
        "Lluvia toda la tarde. Leí junto a la ventana y dejé el móvil en la otra habitación. Debería proteger más estas horas.",
        "Javier se disculpó, de verdad, sin que yo se lo pidiera. No me lo esperaba y no lo llevé bien. Mejor que el mes pasado, eso sí.",
        "Fui a ver a Priya y al bebé. La tuve en brazos una hora y no hice nada más. De lejos, la mejor hora del mes.",
        "Ánimo gris, sin motivo concreto. Aun así fui andando al mercado y compré demasiadas naranjas. Las pequeñas victorias cuentan.",
        "Lucía ha vuelto. La casa vuelve a sonar como tiene que sonar. Nos quedamos despiertas hasta tardísimo y no me arrepiento de nada.",
        "Presenté ante la junta y salió bien, lo cual, después de tres semanas de pavor, casi me sabe a poco.",
        "Hoy no pasó nada y de eso se trataba. El primer sábado en meses sin ningún plan.",
        "La despedida de Adyah en el sitio de fideos. Ruidosa, cálida, un poco larga, justo como tenía que ser. Mumbai tiene suerte.",
        "Me desperté a las cuatro y no hubo manera de volver a dormirme. A las cinco me hice un té y vi cómo amanecía. Extrañamente tranquilo cuando dejé de pelearme con ello.",
        "Trail con Rahul entre la niebla. No se veía nada a seis metros y fue la mejor hora de la semana.",
        "Llamada difícil con el equipo. Dije lo honesto en vez de lo fácil y me costó la tarde.",
        "Carmen mandó una foto de su piso nuevo en Mumbai. Paredes vacías, buena luz. Vuelve a sonar como ella misma.",
        "Dormí nueve horas y eso cambió todo el día. Aprendo esta lección una y otra vez, y una y otra vez se me olvida.",
        "Lucía cocinó, yo fregué y discutimos por una película que no nos gustó a ninguna. Una noche normal y corriente, y me la quedaría.",
        "Otra vez la vuelta al embalse después de dos semanas parada. Más lenta de lo que quería, más contenta de lo que esperaba.",
        "Javier y yo por fin nos pusimos de acuerdo con el calendario. Tardamos tres semanas más de lo necesario y la mayor parte es culpa mía.",
        "Semana tranquila, trabajo constante, nada que contar. Apuntarlo ya se siente como un tipo de progreso.",
        "Priya me preguntó cómo estoy de verdad, y esperó la respuesta de verdad. No mucha gente hace eso.",
        "Subí sola a la cresta al amanecer. No había nadie. Me senté veinte minutos y volví siendo otra.",
        "Malas noticias con la financiación. Me lo tomé con calma, se lo conté a Lucía y me sentí mejor. Siguen siendo malas noticias, pero se pueden llevar.",
        "El primer sol de verdad en semanas. Trabajé desde el balcón y saqué más que en una semana de escritorio.",
        "Rahul se hace autónomo. Estoy nerviosa por él y un poco envidiosa, y eso hay que tenerlo en cuenta.",
        "Ya van dos meses. Cuando escucho las primeras entradas, parezco otra persona. De eso se trata todo esto.",
    )

    private val fr = listOf(
        "Je suis sortie marcher avant que tout le monde soit réveillé. L'avion de Camille atterrit ce soir et je suis plus nerveuse que prévu. La maison n'est plus la même quand quelqu'un est sur le point de rentrer, comme si elle retenait son souffle.",
        "La revue a mal tourné. Julien a contesté le calendrier et je me suis laissé atteindre. J'aurais dû parler moins et écouter plus longtemps, et je le savais pendant que ça se passait.",
        "Léa m'a appelée sans prévenir et on a parlé deux heures. Rien d'important, et pourtant tout l'était. J'oublie toujours à quel point je me sens plus légère après, jusqu'à ce que je raccroche.",
        "Longue rando sur la crête avec Camille. On s'est fait rincer à un kilomètre du sommet et aucune de nous n'avait de veste. Le meilleur après-midi depuis des semaines, et aucune de nous ne l'a dit à voix haute.",
        "Encore mal dormi. Le travail me pèse sur la poitrine à trois heures du matin et je n'arrive pas à le poser. Il faut que je règle ça avant que ça me règle.",
        "Priya a envoyé les photos du mariage. Le gâteau à la mangue, la coupure de courant en plein dîner, un discours qui a duré vingt minutes de trop. J'ai ri tout haut dans le bus et je m'en fichais.",
        "Dimanche tranquille. J'ai vraiment cuisiné pour la première fois depuis quinze jours, j'ai lu sur le balcon, je n'ai pas ouvert l'ordi une seule fois. Calme, et je l'ai remarqué sur le moment.",
        "J'ai enfin parlé à Camille de cette histoire de boulot. Elle a été plus sereine que moi. Reconnaissante, c'est le mot, même s'il paraît trop petit pour ce qu'elle a fait.",
        "Frustrée contre moi-même aujourd'hui. La même dispute avec Julien, exactement comme le mois dernier. Je continue de choisir d'avoir raison plutôt que d'être utile.",
        "J'ai couru le tour du lac de barrage. Vent de face dans les deux sens, allez savoir comment. Jambes fatiguées, tête claire, c'est l'échange que je fais sans arrêt et dont je suis toujours contente.",
        "Léa part vivre à Mumbai en mars. Heureuse pour elle et effondrée en silence. Les deux, toute la journée, sans que l'un l'emporte.",
        "Bonne semaine. J'ai livré le projet, dormi sept heures trois nuits d'affilée, et rien n'a cassé. Je le note pour me rappeler que c'est arrivé.",
        "Café avec Adyah avant le boulot. Elle m'a demandé ce que je veux vraiment cette année et je n'avais pas de réponse toute prête, ce qui m'a appris quelque chose.",
        "L'appart est trop silencieux sans Camille. J'ai mis de la musique et j'ai mal cuisiné. Ça m'a fait plus de bien que ça n'aurait dû.",
        "Longue journée au studio avec Rahul. On a refait toute la deuxième moitié et c'est mieux, mais je suis sur les rotules.",
        "De la pluie tout l'après-midi. J'ai lu près de la fenêtre et laissé le téléphone dans l'autre pièce. Je devrais protéger ces heures-là avec plus de soin.",
        "Julien s'est excusé, vraiment, sans que je lui demande rien. Je ne m'y attendais pas et je l'ai mal pris. Mieux que le mois dernier quand même.",
        "Je suis allée voir Priya et le bébé. Je l'ai tenue dans mes bras pendant une heure et je n'ai rien fait d'autre. De loin la meilleure heure du mois.",
        "Humeur grise, sans raison particulière. Je suis quand même allée au marché à pied et j'ai acheté beaucoup trop d'oranges. Les petites victoires comptent.",
        "Camille est rentrée. La maison sonne juste à nouveau. On s'est couchées beaucoup trop tard et je ne regrette rien.",
        "J'ai présenté devant le conseil d'administration et ça s'est bien passé, ce qui, après trois semaines d'angoisse, paraît presque décevant.",
        "Il ne s'est rien passé aujourd'hui et c'était le but. Le premier samedi depuis des mois sans aucun projet.",
        "Le pot de départ d'Adyah au resto de nouilles. Bruyant, chaleureux, un peu trop long, exactement ce qu'il fallait. Mumbai a de la chance.",
        "Réveillée à quatre heures, impossible de me rendormir. Thé à cinq heures et j'ai regardé le jour se lever. Étrangement paisible une fois que j'ai arrêté de lutter.",
        "Trail avec Rahul dans le brouillard. On ne voyait pas à six mètres et c'était la meilleure heure de la semaine.",
        "Appel difficile avec l'équipe. J'ai dit la chose honnête plutôt que la chose facile, et ça m'a coûté l'après-midi.",
        "Léa a envoyé une photo de son nouvel appart à Mumbai. Murs nus, belle lumière. Elle a retrouvé sa voix à elle.",
        "Dormi neuf heures et ça a tout changé à la journée. Je réapprends cette leçon sans arrêt et je l'oublie sans arrêt.",
        "Camille a cuisiné, j'ai fait la vaisselle, on s'est disputées sur un film qu'aucune de nous n'a aimé. Une soirée ordinaire, et je la garderais.",
        "De retour sur le tour du lac après quinze jours d'arrêt. Plus lente que je voulais, plus heureuse que je pensais.",
        "Julien et moi, on s'est enfin mis d'accord sur le calendrier. Ça a pris trois semaines de plus que nécessaire et j'en porte la plus grande part.",
        "Semaine calme, travail régulier, rien à signaler. L'écrire, c'est déjà une forme de progrès.",
        "Priya m'a demandé comment j'allais vraiment, et elle a attendu la vraie réponse. Peu de gens font ça.",
        "Montée seule à la crête à l'aube. Personne. Je me suis assise vingt minutes et je suis redescendue différente.",
        "Mauvaise nouvelle pour le financement. J'ai laissé décanter, j'en ai parlé à Camille, ça allait mieux. Toujours une mauvaise nouvelle, mais elle se porte.",
        "Premier vrai soleil depuis des semaines. J'ai travaillé sur le balcon et j'en ai fait plus qu'en une semaine au bureau.",
        "Rahul se lance en freelance. Inquiète pour lui et un peu envieuse, ce qui mérite d'être noté.",
        "Deux mois déjà. Quand je réécoute les premières entrées, on dirait quelqu'un d'autre. C'est tout l'intérêt.",
    )

    private val it = listOf(
        "Sono uscita a camminare prima che si svegliasse qualcuno. Il volo di Giulia atterra stasera e sono più nervosa di quanto pensassi. La casa sembra diversa quando qualcuno sta per tornare, come se stesse trattenendo il respiro.",
        "La revisione è andata storta. Marco ha contestato le scadenze e mi sono fatta prendere. Avrei dovuto parlare meno e ascoltare di più, e lo sapevo mentre succedeva.",
        "Chiara mi ha chiamata dal nulla e abbiamo parlato per due ore. Niente di importante, ed era tutto importante. Mi dimentico sempre quanto mi sento più leggera dopo, finché non riattacco.",
        "Lunga escursione sul sentiero di cresta con Giulia. Ci ha beccate la pioggia a un chilometro dalla cima e nessuna delle due aveva la giacca. Il pomeriggio più bello da settimane e nessuna l'ha detto ad alta voce.",
        "Dormito male un'altra volta. Il lavoro mi pesa sul petto alle tre di notte e non riesco a mollarlo. Devo sistemare questa cosa prima che sia lei a sistemare me.",
        "Priya ha mandato le foto del matrimonio. La torta al mango, il blackout a metà cena, un discorso durato venti minuti di troppo. Ho riso ad alta voce sull'autobus e non me ne importava niente.",
        "Domenica tranquilla. Ho cucinato davvero per la prima volta in due settimane, ho letto sul balcone e non ho aperto il portatile neanche una volta. Calma, e me ne sono accorta mentre succedeva.",
        "Finalmente ho detto a Giulia la cosa del lavoro. Lei era più serena di me. Grata è la parola, anche se è troppo piccola per quello che ha fatto.",
        "Oggi sono arrabbiata con me stessa. La stessa discussione con Marco, identica a quella del mese scorso. Continuo a scegliere di avere ragione invece di essere utile.",
        "Ho fatto il giro del lago di corsa. Vento contro in tutte e due le direzioni, chissà come. Gambe stanche, testa sgombra, che è lo scambio che faccio sempre e di cui sono sempre contenta.",
        "Chiara si trasferisce a Mumbai a marzo. Felice per lei e distrutta in silenzio. Tutte e due le cose, tutto il giorno, senza che ne vinca una.",
        "Bella settimana. Ho consegnato il progetto, ho dormito sette ore per tre notti di fila e non si è rotto niente. Lo scrivo per ricordarmi che è successo.",
        "Caffè con Adyah prima del lavoro. Mi ha chiesto cosa voglio davvero quest'anno e non avevo una risposta pronta, e questo mi ha detto qualcosa.",
        "La casa è troppo silenziosa senza Giulia. Ho messo su un po' di musica e ho cucinato male. Mi ha aiutata più del dovuto.",
        "Giornata lunga in studio con Rahul. Abbiamo rifatto tutta la seconda metà ed è meglio, ma sono proprio a pezzi.",
        "Pioggia tutto il pomeriggio. Ho letto vicino alla finestra e ho lasciato il telefono nell'altra stanza. Dovrei proteggere di più queste ore.",
        "Marco si è scusato, sul serio, senza che glielo chiedessi. Non me l'aspettavo e non l'ho gestita bene. Meglio del mese scorso, però.",
        "Sono andata a trovare Priya e la bambina. L'ho tenuta in braccio per un'ora e non ho fatto nient'altro. Di gran lunga l'ora più bella del mese.",
        "Umore grigio, senza un motivo preciso. Sono andata al mercato lo stesso e ho comprato troppe arance. Anche le piccole vittorie contano.",
        "Giulia è tornata. La casa ha di nuovo il suo suono giusto. Siamo rimaste sveglie fino a tardissimo e non mi pento di niente.",
        "Ho presentato al consiglio ed è andata bene, che dopo tre settimane di ansia sembra quasi una delusione.",
        "Oggi non è successo niente ed era proprio questo il punto. Il primo sabato da mesi senza nessun programma.",
        "La festa d'addio di Adyah al locale dei noodles. Rumorosa, calorosa, un po' troppo lunga, perfetta così. Mumbai è fortunata.",
        "Sveglia alle quattro e non sono più riuscita a riaddormentarmi. Alle cinque mi sono fatta un tè e ho guardato venire giorno. Stranamente in pace, una volta smesso di combatterlo.",
        "Trail con Rahul nella nebbia. Non si vedeva a sei metri ed è stata l'ora più bella della settimana.",
        "Chiamata difficile con il team. Ho detto la cosa onesta invece di quella facile e mi è costata il pomeriggio.",
        "Chiara ha mandato una foto della sua nuova casa a Mumbai. Pareti spoglie, bella luce. Sembra di nuovo lei.",
        "Ho dormito nove ore e la giornata è cambiata completamente. Continuo a imparare questa lezione e continuo a dimenticarla.",
        "Giulia ha cucinato, io ho lavato i piatti, abbiamo litigato per un film che non è piaciuto a nessuna delle due. Una serata normale, e me la terrei.",
        "Di nuovo il giro del lago dopo due settimane di stop. Più lenta di quanto volessi, più felice di quanto pensassi.",
        "Marco e io ci siamo finalmente messi d'accordo sulle scadenze. Ci sono volute tre settimane in più del necessario e quasi tutta la colpa è mia.",
        "Settimana tranquilla, lavoro costante, niente da raccontare. Scriverlo sembra già una specie di progresso.",
        "Priya mi ha chiesto come sto davvero, e ha aspettato la risposta vera. Non sono in tanti a farlo.",
        "Sono salita da sola sulla cresta all'alba. Nessuno. Sono rimasta seduta venti minuti e sono tornata diversa.",
        "Brutte notizie sui finanziamenti. Ci ho dormito su, l'ho detto a Giulia e mi sono sentita meglio. Restano brutte notizie, ma si possono portare.",
        "Il primo vero sole da settimane. Ho lavorato dal balcone e ho fatto più che in una settimana alla scrivania.",
        "Rahul si mette in proprio. Sono in ansia per lui e un po' invidiosa, e vale la pena accorgersene.",
        "Sono già due mesi. Se riascolto le prime voci, sembro un'altra persona. È proprio questo il senso.",
    )

    private val ptBR = listOf(
        "Saí pra caminhar antes de todo mundo acordar. O voo da Ana chega hoje à noite e eu tô mais nervosa do que esperava. A casa fica diferente quando alguém tá pra voltar, como se estivesse prendendo a respiração.",
        "A revisão deu errado. O Rafael bateu o pé no cronograma e eu deixei aquilo me pegar. Eu devia ter falado menos e escutado mais, e eu sabia disso enquanto tava acontecendo.",
        "A Beatriz me ligou do nada e a gente conversou duas horas. Nada importante, e tudo importante. Eu sempre esqueço o quanto fico mais leve depois, até desligar.",
        "Trilha longa pela crista com a Ana. Pegou chuva a menos de um quilômetro do topo e nenhuma de nós tinha casaco. A melhor tarde em semanas e nenhuma de nós falou isso em voz alta.",
        "Dormi mal de novo. O trabalho senta no meu peito às três da manhã e eu não consigo largar. Preciso resolver isso antes que isso me resolva.",
        "A Priya mandou as fotos do casamento. O bolo de manga, a queda de energia no meio do jantar, um discurso que passou vinte minutos do tempo. Eu ri alto no ônibus e nem liguei.",
        "Domingo tranquilo. Cozinhei de verdade pela primeira vez em duas semanas, li na varanda e não abri o notebook nenhuma vez. Calma, e eu percebi enquanto tava acontecendo.",
        "Finalmente contei pra Ana sobre a história do emprego. Ela foi mais tranquila do que eu. Grata é a palavra, mesmo parecendo pequena demais pro que ela fez.",
        "Frustrada comigo mesma hoje. A mesma discussão com o Rafael, igualzinha à do mês passado. Eu continuo escolhendo ter razão em vez de ser útil.",
        "Corri a volta da represa. Vento contra nos dois sentidos, não sei como. Pernas cansadas, cabeça leve, que é a troca que eu sempre faço e sempre fico feliz de ter feito.",
        "A Beatriz vai se mudar pra Mumbai em março. Feliz por ela e arrasada por dentro. As duas coisas, o dia inteiro, sem nenhuma ganhar.",
        "Semana boa. Entreguei o projeto, dormi sete horas três noites seguidas e nada quebrou. Tô anotando pra lembrar que isso aconteceu.",
        "Café com a Adyah antes do trabalho. Ela perguntou o que eu quero de verdade esse ano e eu não tinha resposta pronta, o que já me disse alguma coisa.",
        "O apartamento fica quieto demais sem a Ana. Coloquei música e cozinhei mal. Ajudou mais do que devia.",
        "Dia longo no estúdio com o Rahul. A gente refez a segunda metade inteira e ficou melhor, mas eu tô no bagaço.",
        "Chuva a tarde toda. Li perto da janela e deixei o celular no outro quarto. Eu devia proteger mais essas horas.",
        "O Rafael pediu desculpas, de verdade, sem eu pedir. Eu não esperava e não lidei bem com isso. Melhor que no mês passado, pelo menos.",
        "Fui ver a Priya e a bebê. Fiquei com ela no colo uma hora e não fiz mais nada. De longe a melhor hora do mês.",
        "Humor cinzento, sem motivo nenhum. Fui a pé até a feira mesmo assim e comprei laranja demais. Pequenas vitórias contam.",
        "A Ana voltou. A casa voltou a ter o som certo. A gente ficou acordada até tarde demais e eu não me arrependo de nada.",
        "Apresentei pra diretoria e foi tudo bem, o que depois de três semanas de pavor parece quase sem graça.",
        "Hoje não aconteceu nada e era essa a ideia. O primeiro sábado em meses sem plano nenhum.",
        "A despedida da Adyah no restaurante de lámen. Barulhenta, calorosa, um pouco longa demais, do jeitinho certo. Mumbai tem sorte.",
        "Acordei às quatro e não consegui dormir de novo. Fiz um chá às cinco e fiquei vendo o dia clarear. Estranhamente em paz, depois que parei de brigar com isso.",
        "Corrida na trilha com o Rahul no meio da neblina. Não dava pra ver nada a seis metros e foi a melhor hora da semana.",
        "Reunião difícil com o time. Falei a coisa honesta em vez da coisa fácil e isso me custou a tarde.",
        "A Beatriz mandou uma foto do apartamento novo em Mumbai. Paredes vazias, luz boa. Ela parece ela mesma de novo.",
        "Dormi nove horas e isso mudou o dia inteiro. Eu reaprendo essa lição toda hora e esqueço toda hora.",
        "A Ana cozinhou, eu lavei a louça, a gente discutiu por causa de um filme que nenhuma das duas gostou. Uma noite comum, e eu guardaria ela.",
        "De volta à volta da represa depois de duas semanas parada. Mais lenta do que eu queria, mais feliz do que eu esperava.",
        "O Rafael e eu finalmente fechamos o cronograma. Levou três semanas a mais do que devia e a maior parte disso é culpa minha.",
        "Semana tranquila, trabalho constante, nada pra contar. Anotar isso já parece um tipo de progresso.",
        "A Priya perguntou como eu tô de verdade, e esperou a resposta de verdade. Pouca gente faz isso.",
        "Subi sozinha até a crista de madrugada. Ninguém lá. Fiquei sentada vinte minutos e voltei diferente.",
        "Notícia ruim sobre o financiamento. Deixei assentar, contei pra Ana e me senti melhor. Continua sendo notícia ruim, mas dá pra carregar.",
        "Primeiro sol de verdade em semanas. Trabalhei da varanda e rendi mais do que numa semana na mesa.",
        "O Rahul vai virar freelancer. Tô nervosa por ele e com um pouco de inveja, e vale a pena reparar nisso.",
        "Já são dois meses. Quando ouço as primeiras entradas, pareço outra pessoa. É exatamente esse o ponto.",
    )
}
