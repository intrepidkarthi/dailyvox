package com.dailyvox.app.system

import com.dailyvox.app.data.Entry
import com.dailyvox.twin.LanguageFeature
import com.dailyvox.twin.LanguageGate

/**
 * The language a feature should READ an entry in, for the engine's
 * [LanguageGate] (multilingual plan B-5).
 *
 * The gate answers "can this feature read language X?". This answers "what is
 * X for this entry?", and it is the only place in the app that does, so every
 * surface asks the same question the same way:
 *
 *  1. The entry's stored language column (B-2) is the source. A spoken entry
 *     carries the tag the recogniser was asked for; a typed one, what the
 *     platform TextClassifier said when it was saved.
 *  2. With no column (every entry from before 1.3, and a spoken one where no
 *     language was asked for), text that reads as English ([EnglishText]) is
 *     read as English, exactly as 1.2.1 read it. That is what keeps English
 *     unchanged.
 *  3. Otherwise the TextClassifier's answer, where the caller has one (only
 *     off the main thread, at save time: see [com.dailyvox.app.data.Repo]),
 *     and failing that [UNREAD], which no gate row lists: quiet.
 *
 * One more rule, from plan D5 (code-mixed speech): an entry TAGGED English
 * whose words do not read as English (Hinglish spoken into the English pack)
 * is [UNREAD] too. The English word lists would misread it just as they
 * misread Spanish, and 1.2.1 already kept them quiet on such text.
 *
 * The returned tag is never written back into the column: core's rule is that
 * the column holds only what was known, and a guess there would be
 * indistinguishable from a fact.
 *
 * Pure and Android-free, so the rules are tested on the JVM.
 */
object ReadingLanguage {

    /**
     * "Not English, and not identified." `LanguageGate.baseCode` maps it to
     * null, so every feature is unsupported for it.
     */
    const val UNREAD = "und"

    /**
     * The language to gate on. Null means English as it always was (the
     * gate's [LanguageGate.supportsRecorded] reads null as English).
     *
     * [detect] is consulted only when there is no stored language and the
     * text does not read as English, so an English entry never pays for a
     * classifier call and never has its reading changed by one.
     */
    fun of(stored: String?, text: String, detect: (() -> String?)? = null): String? {
        if (stored != null) {
            return if (isEnglish(stored) && !EnglishText.likely(text)) UNREAD else stored
        }
        if (EnglishText.likely(text)) return null
        val detected = detect?.invoke()?.takeUnless { it.isBlank() || isEnglish(it) }
        return detected ?: UNREAD
    }

    fun of(entry: Entry): String? = of(entry.language, entry.text)

    /** Whether [feature] can read [entry]. */
    fun reads(feature: LanguageFeature, entry: Entry): Boolean =
        LanguageGate.supportsRecorded(feature, of(entry))

    /** Whether [feature] can read [text], given its stored language. */
    fun reads(feature: LanguageFeature, stored: String?, text: String): Boolean =
        LanguageGate.supportsRecorded(feature, of(stored, text))

    /**
     * The entry's valence where sentiment can read it, otherwise null. A row
     * scored before its language was known can still carry a number the
     * lexicon had no business producing; this is where it stops counting.
     * For an English entry, exactly [Entry.valence].
     */
    fun valence(entry: Entry): Float? =
        entry.valence?.takeIf { reads(LanguageFeature.SENTIMENT, entry) }

    /**
     * The entry's people where names can be read in its language, otherwise
     * empty. A German entry saved before 1.3 can still carry every capitalised
     * noun ("Arbeit") in its entities column, and nothing rewrites that
     * column, so every surface that shows or counts people reads them through
     * here rather than [Entry.entityList]. For an English entry, exactly
     * [Entry.entityList].
     */
    fun people(entry: Entry): List<String> =
        if (com.dailyvox.twin.NameDetector.canRead(entry.text, of(entry))) entry.entityList else emptyList()

    private fun isEnglish(tag: String) = LanguageGate.baseCode(tag) == "en"
}
