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
 *  - the text does not read as English ([EnglishText]); the lexicon is English
 *    and its false friends ("sin", "die", "war") score other languages wrongly
 *    rather than not at all, or
 *  - no token of the text is in the lexicon (the same tokens the engine reads).
 *
 * Otherwise exactly the engine's score, so English is unchanged.
 */
object Valence {

    fun of(text: String, table: Map<String, Float>): Float? {
        if (table.isEmpty()) return null
        if (!EnglishText.likely(text)) return null
        val tokens = text.lowercase().split(Regex("[^a-z']+")).filter { it.isNotEmpty() }
        if (tokens.none { it in table }) return null
        return Sentiment.valence(text, table)
    }
}
