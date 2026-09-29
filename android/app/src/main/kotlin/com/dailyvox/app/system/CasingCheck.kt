package com.dailyvox.app.system

import com.dailyvox.twin.NameDetector

/**
 * Does this phone's recogniser capitalise names?
 *
 * The Twin's entity graph has exactly one input: proper nouns arriving
 * capitalised. `NameDetector.extract` skips any token that is not, with no
 * fallback. On iOS that assumption holds — Apple's recogniser cases names, and
 * the detector was measured at 99.1% untyped recall on Apple transcripts.
 *
 * On Android it is the port's largest untested assumption, and the evidence
 * suggests it is a bad one: Google's speech-to-text is widely reported to have
 * stopped reliably capitalising proper nouns, and every GMS phone — Pixel,
 * Galaxy, Motorola, Nothing — runs that same model, so no choice of handset
 * escapes it.
 *
 * This class does not fix that. It makes it OBSERVABLE, which has to come first:
 * without it an empty Twin looks identical whether the user has genuinely
 * written about nobody or the recogniser has been quietly discarding every name
 * they ever said. Those need different words on screen, and right now the app
 * cannot tell them apart.
 *
 * ### The two failures are not the same
 *
 * **Nothing capitalised** is the obvious one and the kinder one: the graph is
 * empty, uniformly, and it is unmistakable once looked for.
 *
 * **Inconsistent capitalisation** is the likelier one and much worse, because
 * of how the detector's precision guard works. A token is accepted only if it
 * is NEVER seen lowercase anywhere in the corpus. So a name the recogniser
 * capitalises most of the time and lowercases once is disqualified — across the
 * whole journal, permanently. The more often a name recurs, the more chances it
 * has to be lowercased once and lost. That inverts the detector: it removes
 * exactly the recurring people it exists to track, while a random word
 * capitalised once and never seen lowercase sails through.
 *
 * [Inconsistent] therefore reports the contested tokens by name. They are the
 * evidence, and they are the names being thrown away.
 */
object CasingCheck {

    sealed interface Verdict {
        /** Too little text to say anything honest yet. */
        data object NotEnoughYet : Verdict
        /** Proper nouns are arriving capitalised. The detector can work. */
        data object Casing : Verdict
        /** No non-trivial mid-sentence capitals at all. The graph cannot fill. */
        data object NotCasing : Verdict
        /** Names arrive cased sometimes and lowercase others; these are lost. */
        data class Inconsistent(val contested: List<String>) : Verdict
    }

    /**
     * Words before a verdict is offered at all.
     *
     * A short journal legitimately contains no names, and calling that a broken
     * recogniser would be a worse error than staying quiet — it would tell the
     * user their phone is faulty because they wrote three entries about the
     * weather.
     */
    private const val MIN_WORDS = 200

    /**
     * Capitalised by grammar or convention rather than because the recogniser
     * identified a name, so they are not evidence either way.
     *
     * "I" is the important one: it is capitalised mid-sentence in almost every
     * English sentence ever spoken, so without this exclusion **every** corpus
     * looks like it is casing correctly and the check would never fire. Days
     * and months are here for the same reason the detector excludes them —
     * capitalised by convention, never lowercase, and no evidence about names.
     */
    private val trivial: Set<String> = setOf(
        "i", "i'm", "i've", "i'll", "i'd",
        "monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday",
        "january", "february", "march", "april", "may", "june", "july", "august",
        "september", "october", "november", "december",
    )

    fun of(texts: List<String>): Verdict {
        if (texts.sumOf { wordCount(it) } < MIN_WORDS) return Verdict.NotEnoughYet

        val (midSentence, seenLower) = NameDetector.vocabulary(texts)
        // Sentence-initial capitals are grammar, so `vocabulary` already ignores
        // them; what is left is the recogniser making a choice.
        val evidence = midSentence - trivial
        if (evidence.isEmpty()) return Verdict.NotCasing

        // Capitalised mid-sentence somewhere AND lowercase somewhere else. Every
        // one of these is a token the detector will refuse for the life of the
        // journal.
        val contested = evidence.intersect(seenLower)
        val clean = evidence - seenLower
        return if (contested.size > clean.size) {
            Verdict.Inconsistent(contested.sorted().take(5))
        } else {
            Verdict.Casing
        }
    }

    private fun wordCount(t: String): Int =
        t.split(' ', '\n', '\t').count { w -> w.any { it.isLetter() } }
}
