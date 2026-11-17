package com.dailyvox.app.system

import android.content.Context
import android.view.textclassifier.TextClassificationManager
import java.util.Locale

/**
 * What language a piece of TYPED or IMPORTED text is in (plan B-2).
 *
 * Spoken entries do not need this: the recogniser was asked for a language and
 * that tag is recorded. Typed text has no such witness, so it goes to the
 * platform's own on-device `TextClassifier.detectLanguage` (API 29, part of the
 * OS -- no new dependency, no model shipped in the APK, nothing sent anywhere).
 *
 * The rule is the multilingual plan's: quiet, never wrong. A short entry ("ok",
 * "Sarah!") or a low-confidence answer is null, which every reader treats as
 * unknown. A wrong label would be worse than none, because the label decides
 * which voice reads the entry aloud.
 */
object TextLanguage {

    /** Below this the classifier is guessing; it says so with its own score. */
    const val MIN_CONFIDENCE = 0.6f

    /** Fewer letters than this is not enough text to tell languages apart. */
    const val MIN_LETTERS = 12

    /** (BCP-47 tag, confidence 0..1), in any order. */
    fun interface Detector {
        fun hypotheses(text: String): List<Pair<String, Float>>
    }

    /**
     * The platform classifier. Must run off the main thread (the call can block
     * on the system's text-classifier service); every caller here is on IO.
     * Any failure is no answer, never a crash on save.
     */
    fun platform(context: Context): Detector = Detector { text ->
        runCatching {
            val tc = context.getSystemService(TextClassificationManager::class.java)?.textClassifier
                ?: return@runCatching emptyList()
            val result = tc.detectLanguage(
                android.view.textclassifier.TextLanguage.Request.Builder(text).build()
            )
            (0 until result.localeHypothesisCount).map { i ->
                val loc = result.getLocale(i)
                loc.toLanguageTag() to result.getConfidenceScore(loc)
            }
        }.getOrDefault(emptyList())
    }

    /** The confident answer, or null. Pure, so the rule is testable without a phone. */
    /**
     * Overruling the language a person speaks takes more than a confident
     * guess: the classifier calls a short Spanish question ("¿Carmen se muda a
     * Mumbai?") English with better than [MIN_CONFIDENCE].
     */
    const val OVERRULE_CONFIDENCE = 0.9f
    const val OVERRULE_LETTERS = 40

    /**
     * The language a QUESTION is in (Ask your Twin), given [personLanguage]:
     * the language they speak, else the app's. The classifier's answer when it
     * agrees with that language, or when it is very sure about a question long
     * enough to judge; otherwise the person's language.
     */
    fun question(context: Context, text: String, personLanguage: String): String =
        question(platform(context), text, personLanguage)

    fun question(detector: Detector, text: String, personLanguage: String): String {
        if (text.isBlank()) return personLanguage
        val hypotheses = detector.hypotheses(text)
        val detected = choose(text, hypotheses) ?: return personLanguage
        if (base(detected) == base(personLanguage)) return detected
        return choose(text, hypotheses, OVERRULE_LETTERS, OVERRULE_CONFIDENCE) ?: personLanguage
    }

    private fun base(tag: String) = Locale.forLanguageTag(tag.replace('_', '-')).language

    internal fun choose(
        text: String,
        hypotheses: List<Pair<String, Float>>,
        minLetters: Int = MIN_LETTERS,
        minConfidence: Float = MIN_CONFIDENCE,
    ): String? {
        // Combining marks count: Devanagari writes most vowels as marks, and a
        // letters-only count makes a full Hindi sentence look half as long.
        val letters = text.count {
            it.isLetter() || Character.getType(it).let { t ->
                t == Character.NON_SPACING_MARK.toInt() || t == Character.COMBINING_SPACING_MARK.toInt()
            }
        }
        if (letters < minLetters) return null
        val (tag, score) = hypotheses.maxByOrNull { it.second } ?: return null
        if (score < minConfidence) return null
        val clean = Locale.forLanguageTag(tag.replace('_', '-')).toLanguageTag()
        return clean.takeUnless { it.isBlank() || it == "und" }
    }

    fun detect(context: Context, text: String): String? = detect(platform(context), text)

    fun detect(detector: Detector, text: String): String? =
        if (text.isBlank()) null else choose(text, detector.hypotheses(text))

    /**
     * A language tag read from a file (an import), kept only if it parses to
     * a real language. Anything else is unknown, and the text is classified
     * instead.
     */
    internal fun validTag(raw: String?): String? {
        val t = raw?.trim()?.takeIf { it.isNotEmpty() } ?: return null
        val tag = Locale.forLanguageTag(t.replace('_', '-')).toLanguageTag()
        return tag.takeUnless { it == "und" || it.isBlank() }
    }
}
