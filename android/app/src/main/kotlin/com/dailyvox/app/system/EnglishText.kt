package com.dailyvox.app.system

/**
 * Does this text read as English? The gate in front of every feature that
 * reads words through an English-only list: the VADER lexicon (valence,
 * [MoodSuggestion]) and the sensitive-topic list behind the grounded daily
 * question.
 *
 * Those features do not fail on other languages, which is the problem -- they
 * answer wrongly. Spanish "sin" and German "die" and "war" are VADER words, so
 * a sad Spanish entry can read as joy and a German one as grief. In a language
 * a feature cannot read, the feature stays quiet; this is how it knows.
 *
 * Pure and dependency-free on purpose: no TextClassifier (it needs a Context
 * and a system service, and its answer varies by OEM), no new library, no
 * network. Two cheap signals, both conservative:
 *
 *  1. Script. Letters mostly outside Latin (Devanagari, Tamil, Cyrillic, CJK,
 *     Arabic...) are not English.
 *  2. Function words. Latin-script text that uses more es/fr/de/it/pt function
 *     words than English ones, and at least two, is not English. Words that are
 *     also common English ("a", "die", "war", "was", "as", "in", "no", "me")
 *     are left out of the foreign list so they cannot tip English text over.
 *
 * Ambiguous or very short text counts as English, so English behaviour is
 * unchanged: a three-word English entry was scored before and still is.
 */
object EnglishText {

    private val ENGLISH = setOf(
        "the", "and", "i", "to", "a", "of", "was", "it", "in", "my", "that", "is",
        "with", "for", "on", "but", "me", "so", "had", "have", "today", "about",
        "we", "he", "she", "they", "this", "at", "just", "not", "be", "been",
        "felt", "feel", "really", "what", "then", "from", "were", "you", "her",
        "his", "him", "our", "after", "went", "got", "an", "it's", "i'm", "didn't",
        "don't", "would", "could", "all", "out", "up", "there", "when", "like",
        "some", "very", "much", "because", "did", "do", "am", "are", "how", "she's",
        "he's", "i've", "i'd", "can't", "into", "over", "too", "said", "think",
    )

    private val FOREIGN = setOf(
        // Spanish
        "de", "la", "que", "el", "y", "los", "las", "del", "se", "por", "una",
        "con", "para", "es", "muy", "pero", "yo", "hoy", "estoy", "estuve", "fue",
        "tengo", "porque", "mucho", "también", "cuando", "como", "más", "mañana",
        "día", "ella", "él", "hay", "todo", "estaba", "mí", "mis", "nos",
        // French
        "le", "les", "et", "est", "je", "il", "une", "des", "du", "pas", "qui",
        "au", "aux", "sur", "avec", "pour", "ce", "cette", "mais", "très",
        "j'ai", "c'est", "nous", "vous", "ai", "suis", "était", "aujourd'hui",
        "mon", "ma", "mes", "elle", "avait", "été", "rien",
        // German
        "der", "das", "und", "ist", "ich", "nicht", "ein", "eine", "mit", "auf",
        "den", "dem", "von", "zu", "wir", "mein", "meine", "heute", "sehr",
        "aber", "auch", "nach", "mich", "mir", "dass", "habe", "hatte", "bin",
        "sich", "noch", "wieder", "einen", "wurde",
        // Italian
        "di", "che", "non", "sono", "ho", "un", "per", "mi", "della", "nel",
        "molto", "oggi", "anche", "io", "questo", "questa", "perché", "stato",
        "stata", "ero", "gli",
        // Portuguese
        "não", "eu", "você", "um", "uma", "com", "os", "muito", "hoje", "foi",
        "estou", "mas", "meu", "minha", "está", "ele", "ela", "na", "em",
        "isso", "ontem",
    )

    /** Fewer function-word hits than this from other languages never flips the answer. */
    private const val MIN_FOREIGN = 2

    private val token = Regex("[\\p{L}\\p{M}']+")

    fun likely(text: String): Boolean {
        var latin = 0
        var other = 0
        for (ch in text) {
            if (!Character.isLetter(ch)) continue
            when (Character.UnicodeScript.of(ch.code)) {
                Character.UnicodeScript.LATIN -> latin++
                Character.UnicodeScript.COMMON, Character.UnicodeScript.INHERITED -> Unit
                else -> other++
            }
        }
        if (other > latin) return false

        var en = 0
        var foreign = 0
        token.findAll(text.lowercase()).forEach { m ->
            val w = m.value.trim('\'')
            if (w in ENGLISH) en++
            if (w in FOREIGN) foreign++
        }
        return !(foreign >= MIN_FOREIGN && foreign > en)
    }
}
