package com.dailyvox.app.system

import com.dailyvox.twin.Sentiment

/**
 * A suggested mood, read off the entry's words.
 *
 * The answer is a key from [SelfLabels.CANON] or null, and null is the usual
 * answer. Valence is one axis: it can say "this reads clearly good" or "this
 * reads clearly bad" and nothing finer, so only two labels are ever suggested,
 * and each only when the words themselves back it:
 *
 *  - Joy for a strong positive that holds at least one strong positive word.
 *    Pleasantries ("thank you, okay, sure, fine") are weak in VADER and add up
 *    to a high compound without anyone saying they felt good.
 *  - Sadness for a strong negative that names sadness (sad, lonely, cried,
 *    miss, grief...). A strong negative on its own is as likely anger or fear,
 *    and calling "furious" or "terrified" sad would be a guess shown as a read.
 *    An entry that also names anger or fear gets nothing, for the same reason.
 *
 * Either way a MIXED entry gets nothing. The compound is a sum, so "my
 * grandmother died, everyone was so kind and loving" scores +0.60 and sarcasm
 * ("oh great, another wonderful Monday stuck in traffic") scores higher still.
 * One clear word pulling the other way is enough to abstain: a wrong "Reads
 * like Joy" on a bereavement entry costs far more than a missing suggestion.
 *
 * Neutral is never suggested either. A score near zero means the lexicon found
 * little to go on, not that the person felt nothing, and saying "neutral" about
 * an entry the scorer could not read would present a guess as fact.
 *
 * A suggestion is stored apart from the self-label and is only ever shown
 * marked as one. Pure and Android-free so the rules are tested on the JVM
 * against the shipped lexicon.
 */
object MoodSuggestion {

    /** Well past VADER's own +-0.05 neutral band. */
    const val STRONG = 0.5f

    /** Fewer words than this and one word decides the score, so no suggestion. */
    const val MIN_WORDS = 5

    /**
     * A word pulling against the overall sign by at least this much (lexicon
     * scale, -4..4) makes the entry mixed. Low on purpose: "empty" is -0.8 and
     * "stuck" -1.0, and both are what turn a good-sounding entry into a bad day.
     */
    const val AGAINST = 0.5f

    /** Joy needs one word at least this positive; "thank" (1.5) and "fine" (0.8) are not. */
    const val JOY_WORD = 2.0f

    /** Words that name sadness itself. Only these let a negative entry read as sad. */
    private val SADNESS = setOf(
        "sad", "sadly", "sadness", "saddened", "unhappy", "lonely", "loneliness",
        "lonesome", "cry", "cried", "crying", "cries", "tears", "sob", "sobbed",
        "sobbing", "miss", "missed", "missing", "misses", "grief", "grieving",
        "grieve", "mourn", "mourning", "heartbroken", "heartbreak", "heartbreaking",
        "depressed", "miserable", "hopeless", "homesick",
    )

    /** Anger and fear. Present alongside a sadness word, the entry is too mixed to call. */
    private val ANGER_OR_FEAR = setOf(
        "angry", "furious", "mad", "rage", "hate", "frustrated", "annoyed",
        "irritated", "scared", "afraid", "terrified", "fear", "panic", "anxious",
        "nervous", "worried",
    )

    /**
     * Words VADER has no score for that still sink an otherwise bright entry:
     * "my boss yelled at me again, just perfect", "okay, sure, fine, whatever".
     * Only ever used to abstain, never added to the score.
     */
    private val UNSCORED_NEGATIVE = setOf(
        "yelled", "yelling", "shouted", "shouting", "screamed", "screaming",
        "afraid", "whatever",
    )

    /** Same tokens and negation window as [Sentiment.valence], so the two agree. */
    private val negators = setOf("not", "no", "never", "cannot", "cant", "can't", "didnt", "didn't", "wasnt", "wasn't", "dont", "don't")

    /**
     * The suggestion to offer, or none for a research participant.
     *
     * On Android the user's mood and the research label are one column
     * (`selfLabel`), and accepting a suggestion is one tap. For someone labelling
     * entries for the study that tap would export the text model's own guess as
     * the participant's label, and the study measures the text model against
     * those labels. So while study labelling is on, the app suggests nothing.
     */
    fun offered(text: String, table: Map<String, Float>, studyLabelling: Boolean): String? =
        if (studyLabelling) null else from(text, table)

    fun from(text: String, table: Map<String, Float>): String? {
        // The lexicon and every word list here are English. On another language
        // they do not fail, they misread: VADER's false friends gave "joy" on
        // sad Spanish and Italian entries. No suggestion beats a wrong one.
        if (!EnglishText.likely(text)) return null
        val sign = lean(Sentiment.valence(text, table), words(text))
        if (sign == 0) return null

        val tokens = text.lowercase().split(Regex("[^a-z']+")).filter { it.isNotEmpty() }
        fun negated(i: Int) = (i > 0 && tokens[i - 1] in negators) || (i > 1 && tokens[i - 2] in negators)
        // Each scored word with negation applied: "not sad" counts as positive.
        val scored = tokens.mapIndexedNotNull { i, t ->
            table[t]?.let { if (negated(i)) it * -0.74f else it }
        }

        if (scored.any { it * sign <= -AGAINST }) return null
        if (sign > 0) {
            if (tokens.withIndex().any { (i, t) -> t in UNSCORED_NEGATIVE && !negated(i) }) return null
            return if (scored.any { it >= JOY_WORD }) "joy" else null
        }
        val named = tokens.withIndex().filter { (i, _) -> !negated(i) }.map { it.value }
        if (named.any { it in ANGER_OR_FEAR }) return null
        return if (named.any { it in SADNESS }) "sadness" else null
    }

    /** +1 strongly positive, -1 strongly negative, 0 too weak or too short to read. */
    internal fun lean(compound: Float, words: Int): Int = when {
        words < MIN_WORDS || compound.isNaN() -> 0
        compound >= STRONG -> 1
        compound <= -STRONG -> -1
        else -> 0
    }

    /** The count [com.dailyvox.app.data.Entry.wordCount] uses. */
    internal fun words(text: String): Int = text.split(' ', '\n').count { it.isNotBlank() }
}
