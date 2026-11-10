package com.dailyvox.app.system

import com.dailyvox.twin.Sentiment

/**
 * The entry's valence, or null when there is nothing to read it from.
 *
 * The engine's [Sentiment.valence] returns 0 in two different situations: a
 * genuinely balanced entry, and an entry in which the lexicon found no word at
 * all -- every non-English entry, and English ones too short or too plain to
 * score. Stored as 0, the second case was drawn as a neutral dot, averaged into
 * the mood line, called "even" on the reflection card and could win "Warmest
 * month". A Hindi journal read as "remarkably balanced". That is a guess shown
 * as a finding, so the second case is now null and every surface leaves it out.
 *
 * Null when:
 *  - sentiment cannot read the entry's language: the engine's LanguageGate
 *    (SENTIMENT, English only on Android) asked about [ReadingLanguage]. The
 *    lexicon is English and its false friends ("sin", "die", "war") score
 *    other languages wrongly rather than not at all. With no stored language
 *    this is 1.2.1's rule exactly: text that does not read as English
 *    ([EnglishText]) is not scored.
 *  - no token of the text is in the lexicon (the same tokens the engine reads;
 *    the engine's [Sentiment.valenceOrNull] makes both checks).
 *
 * Otherwise exactly the engine's score, so English is unchanged.
 */
object Valence {

    /**
     * [language] is the entry's stored column, null when unknown. [detect] is
     * the TextClassifier, for callers off the main thread ([ReadingLanguage]).
     */
    fun of(
        text: String,
        table: Map<String, Float>,
        language: String? = null,
        detect: (() -> String?)? = null,
    ): Float? {
        if (table.isEmpty()) return null
        return Sentiment.valenceOrNull(text, ReadingLanguage.of(language, text, detect), table)
    }
}
