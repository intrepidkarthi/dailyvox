package com.dailyvox.app.system

/**
 * A suggested mood, read off the entry's VADER compound score.
 *
 * The answer is a key from [SelfLabels.CANON] or null, and null is the usual
 * answer. Valence is one axis: it can say "this reads clearly good" or "this
 * reads clearly bad" and nothing finer, so only two labels are ever suggested.
 * Joy for a strong positive. Sadness for a strong negative, which is the
 * nearest canon label for "heavy" and the one a tap most often confirms. Anger,
 * fear, surprise and disgust need more than a sign to tell apart, so they are
 * never guessed at.
 *
 * Neutral is never suggested either. A score near zero means the lexicon found
 * little to go on, not that the person felt nothing, and saying "neutral" about
 * an entry the scorer could not read would present a guess as fact.
 *
 * A suggestion is stored apart from the self-label and is only ever shown
 * marked as one. Pure and Android-free so the thresholds are tested on the JVM.
 */
object MoodSuggestion {

    /**
     * Well past VADER's own +-0.05 neutral band. One strong word in a short
     * sentence crosses it, a mixed entry ("a great day, but sad by the end")
     * does not.
     */
    const val STRONG = 0.5f

    /** Fewer words than this and one word decides the score, so no suggestion. */
    const val MIN_WORDS = 5

    fun from(compound: Float, words: Int): String? = when {
        words < MIN_WORDS || compound.isNaN() -> null
        compound >= STRONG -> "joy"
        compound <= -STRONG -> "sadness"
        else -> null
    }
}
