package com.dailyvox.app.data

import kotlin.math.abs

/**
 * Lexicon valence, the Android replacement for NLTagger's sentimentScore.
 *
 * Android has no OS sentiment API, and the licence-clean LEARNED replacement is
 * already known to fail: the GoEmotions-trained head lost its gate twice, and a
 * 10-configuration sweep found no passing setting (TwinFidelityReport S13). The
 * reason is register -- a head carries whatever prior its training corpus had.
 * A lexicon has no corpus, so it has no prior to mis-transfer, which is why this
 * approach transfers where the head did not.
 *
 * MEASURED against the same 1,459 human-labelled diary entries Apple's scorer was
 * measured on (docs/android-port-blockers-2026-08-14.md): VADER r = +0.663 and
 * 87.1% sign accuracy, against NLTagger's +0.594 and 79.8%. Both shuffled
 * controls collapsed to chance.
 *
 * THIS FILE IS NOT YET THAT RESULT. The measurement used the full VADER lexicon
 * (~7,500 entries, MIT). Bundling it as an asset is a tracked follow-up; what is
 * here is a compact high-frequency subset, so it is directionally right and
 * WILL score lower than +0.663 until the full table ships. Stated rather than
 * implied, because quoting the measured number against this implementation
 * would be quoting a number this code did not earn.
 */
object Sentiment {

    private val lexicon: Map<String, Float> = buildMap {
        listOf(
            "good" to 1.9f, "great" to 3.1f, "happy" to 2.7f, "love" to 3.2f, "loved" to 2.9f,
            "wonderful" to 2.9f, "beautiful" to 2.9f, "calm" to 1.8f, "peaceful" to 2.2f,
            "grateful" to 2.6f, "proud" to 2.5f, "excited" to 2.6f, "hopeful" to 2.3f,
            "better" to 1.9f, "best" to 3.2f, "enjoyed" to 2.3f, "fun" to 2.3f, "glad" to 2.1f,
            "relaxed" to 2.0f, "clear" to 1.2f, "steady" to 1.0f, "warm" to 1.4f,
            "laughed" to 2.4f, "smile" to 2.2f, "thankful" to 2.6f, "achieved" to 2.2f,
            "progress" to 1.7f, "win" to 2.8f, "won" to 2.7f, "helped" to 1.8f,
            "bad" to -2.5f, "sad" to -2.1f, "angry" to -2.7f, "anxious" to -2.4f,
            "tired" to -1.5f, "exhausted" to -2.2f, "worried" to -2.3f, "afraid" to -2.5f,
            "hate" to -3.2f, "terrible" to -3.1f, "awful" to -3.0f, "hurt" to -2.4f,
            "stressed" to -2.3f, "frustrated" to -2.4f, "disappointed" to -2.4f,
            "lonely" to -2.4f, "struggle" to -1.9f, "struggling" to -2.0f, "pain" to -2.6f,
            "difficult" to -1.7f, "hard" to -1.2f, "problem" to -1.8f, "worse" to -2.2f,
            "worst" to -3.1f, "cried" to -2.3f, "loss" to -2.4f, "failed" to -2.6f,
            "overwhelmed" to -2.2f, "nervous" to -1.8f, "guilty" to -2.2f, "ashamed" to -2.4f,
            // Second pass, added after reading a real PDF export: three of twelve
            // entries scored EXACTLY 0.00 -- "the review went sideways",
            // "slept badly", "work is sitting on my chest" -- because the first
            // pass covered emotion nouns and almost no everyday diary verbs.
            // A mood curve pinned to zero looks broken rather than neutral.
            "badly" to -2.0f, "sideways" to -1.5f, "wrong" to -2.0f, "mistake" to -1.9f,
            "regret" to -2.2f, "annoyed" to -1.8f, "upset" to -2.2f, "hopeless" to -2.9f,
            "drained" to -2.0f, "restless" to -1.4f, "heavy" to -1.3f, "stuck" to -1.6f,
            "late" to -0.9f, "missed" to -1.4f, "argument" to -2.2f, "fight" to -2.2f,
            "sick" to -2.1f, "sore" to -1.4f, "dread" to -2.6f, "doubt" to -1.5f,
            "awkward" to -1.5f, "embarrassed" to -2.1f, "rushed" to -1.3f, "behind" to -1.1f,
            "boring" to -1.5f, "dull" to -1.3f, "cold" to -0.8f, "quiet" to 0.6f,
            "rested" to 1.8f, "easy" to 1.6f, "kind" to 2.0f, "gentle" to 1.8f,
            "safe" to 2.0f, "light" to 1.2f, "bright" to 1.8f, "fresh" to 1.6f,
            "generous" to 2.2f, "patient" to 1.7f, "honest" to 1.8f, "close" to 1.2f,
            "surprised" to 0.9f, "curious" to 1.4f, "focused" to 1.6f, "finished" to 1.5f,
            "solved" to 2.1f, "learned" to 1.5f, "enough" to 1.0f, "worth" to 1.6f,
        ).forEach { (w, v) -> put(w, v) }
    }

    private val negators = setOf("not", "no", "never", "cannot", "cant", "can't", "didnt", "didn't", "wasnt", "wasn't", "dont", "don't")
    private val boosters = mapOf("very" to 1.3f, "really" to 1.3f, "so" to 1.2f, "extremely" to 1.5f, "quite" to 1.1f, "slightly" to 0.7f, "a" to 1f)

    /** Compound valence in -1..1, VADER's normalisation: x / sqrt(x^2 + 15). */
    fun valence(text: String): Float {
        val tokens = text.lowercase().split(Regex("[^a-z']+")).filter { it.isNotEmpty() }
        var sum = 0f
        tokens.forEachIndexed { i, t ->
            var v = lexicon[t] ?: return@forEachIndexed
            if (i > 0) {
                boosters[tokens[i - 1]]?.let { v *= it }
                if (tokens[i - 1] in negators) v *= -0.74f       // VADER's negation factor
            }
            if (i > 1 && tokens[i - 2] in negators) v *= -0.74f
            sum += v
        }
        if (sum == 0f) return 0f
        return (sum / kotlin.math.sqrt(sum * sum + 15f)).coerceIn(-1f, 1f)
    }
}
