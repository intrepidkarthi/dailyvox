package com.dailyvox.app.system

import com.dailyvox.app.data.Entry
import com.dailyvox.twin.LanguageFeature

/**
 * What the Speak screen hands back after an entry is saved.
 *
 * Built ONLY from what the app already computed for the entry on this phone:
 * the VADER valence, the name detector's people, the word count and the
 * length. No model is asked anything and nothing is inferred beyond those.
 * A mirror, not an oracle -- every field here can be traced to the words the
 * user just said, and a field with nothing under it is null and not shown.
 *
 * Pure and Android-free so the grounding rules are tested on the JVM. The
 * screen turns this into sentences through strings.xml.
 */
object Reflection {

    enum class Tone { LIGHT, EVEN, HEAVY }
    enum class Drift { LIGHTER, HEAVIER, SIMILAR }

    data class Card(
        val words: Int,
        val seconds: Int,
        val typed: Boolean,
        /** Null when there were too few words for a valence to mean anything. */
        val tone: Tone?,
        /** Null without enough recent entries to compare against. */
        val drift: Drift?,
        /** A name the detector found that ALSO appears in the text as a whole word. */
        val person: String?,
        /** Other entries in the last 30 days that name the same person. */
        val personEarlier: Int,
        /**
         * The user's own sentence that mentions tomorrow, quoted back. Null
         * whenever there is no such sentence: the "for tomorrow" line is only
         * ever their words, never a suggestion the app made up.
         */
        val tomorrow: String?,
        /** The saved entry, so a mood picked on the card lands on the right row. */
        val entryId: String = "",
        /** The user's own label for this entry. Wins over [suggestedMood]. */
        val chosenMood: String? = null,
        /** The app's suggestion ([MoodSuggestion]); shown only as one. */
        val suggestedMood: String? = null,
    ) {
        /** Audio kept, no words heard. The card says so and nothing else. */
        val wordless: Boolean get() = words == 0

        /** The mood the card shows, and whether it is still only a suggestion. */
        val mood: String? get() = chosenMood ?: suggestedMood
        val moodIsSuggested: Boolean get() = chosenMood == null && suggestedMood != null

        /**
         * The card after the user picks a label on it, or clears it with
         * null. Same rule as [com.dailyvox.app.data.Repo.setSelfLabel], so the
         * card and the row cannot disagree.
         */
        fun withMood(label: String?): Card = copy(
            chosenMood = label,
            suggestedMood = if (label == null) null else suggestedMood,
        )
    }

    /** VADER's own convention for where neutral ends. */
    private const val NEUTRAL = 0.05f
    /** How far from the recent average counts as lighter or heavier. */
    private const val DRIFT = 0.15f
    private const val MIN_WORDS_FOR_TONE = 3
    private const val MIN_RECENT = 3
    private const val RECENT_TAKE = 7
    private const val DAY = 86_400_000L
    private const val QUOTE_MAX = 140

    fun of(entry: Entry, others: List<Entry>): Card {
        val words = entry.wordCount
        val earlier = others.filter { it.id != entry.id && it.createdAt < entry.createdAt }

        // A null valence is "the lexicon read nothing here" -- another language,
        // or no scored word. That is not EVEN, and the card says nothing about
        // tone rather than calling an unread entry balanced. The engine's gate
        // decides which languages the reflection line reads (REFLECTION), and
        // which valences count (SENTIMENT): a number stored before the entry's
        // language was known does not give a German entry a tone.
        val v = ReadingLanguage.valence(entry)
            ?.takeIf { ReadingLanguage.reads(LanguageFeature.REFLECTION, entry) }
        val tone = if (words < MIN_WORDS_FOR_TONE || v == null) null else when {
            v >= NEUTRAL -> Tone.LIGHT
            v <= -NEUTRAL -> Tone.HEAVY
            else -> Tone.EVEN
        }

        // Unread entries are left out of the baseline, not averaged in as 0.
        val recent = earlier
            .filter { it.text.isNotBlank() && entry.createdAt - it.createdAt <= 14 * DAY }
            .mapNotNull { e -> ReadingLanguage.valence(e)?.let { e to it } }
            .sortedByDescending { it.first.createdAt }
            .take(RECENT_TAKE)
        val drift = if (tone == null || v == null || recent.size < MIN_RECENT) null else {
            val delta = v - recent.map { it.second }.average().toFloat()
            when {
                delta > DRIFT -> Drift.LIGHTER
                delta < -DRIFT -> Drift.HEAVIER
                else -> Drift.SIMILAR
            }
        }

        // Grounded twice: the detector named them AND the name is in the text
        // as written. A detector hit that the text does not contain would put
        // a name on screen the user never said. Whole words only, so "Ann"
        // is not found inside "Annual" and "Sam" not inside "Samsung".
        val person = ReadingLanguage.people(entry).firstOrNull { nameIn(it, entry.text) }
        val personEarlier = if (person == null) 0 else earlier.count { e ->
            entry.createdAt - e.createdAt <= 30 * DAY &&
                (ReadingLanguage.people(e).any { it.equals(person, ignoreCase = true) } ||
                    nameIn(person, e.text))
        }

        return Card(
            words = words,
            seconds = entry.durationSec,
            typed = entry.audioPath == null && entry.durationSec == 0,
            tone = tone,
            drift = drift,
            person = person,
            personEarlier = personEarlier,
            tomorrow = tomorrowSentence(entry.text),
            entryId = entry.id,
            chosenMood = entry.selfLabel,
            suggestedMood = entry.suggestedMood,
        )
    }

    /**
     * The name as a whole word, case as written. Letters and digits on either
     * side mean it is part of a longer word; "Sarah's" still counts.
     *
     * Combining marks count as part of the word too (\p{M}). Without them a
     * name followed by a Devanagari vowel sign or a decomposed accent ("Ana"
     * + U+0301) matched inside a longer word: "प्रिय" was found in "प्रिया",
     * because the vowel sign after it is a mark, not a letter.
     */
    internal fun nameIn(name: String, text: String): Boolean =
        Regex("(?<![\\p{L}\\p{M}\\p{N}])" + Regex.escape(name) + "(?![\\p{L}\\p{M}\\p{N}])")
            .containsMatchIn(text)

    /**
     * The first sentence that says "tomorrow", trimmed to fit a card. Matched
     * as a whole word so "tomorrows" in a song title does not count.
     */
    internal fun tomorrowSentence(text: String): String? {
        val word = Regex("\\btomorrow\\b", RegexOption.IGNORE_CASE)
        val sentence = text
            .split(Regex("(?<=[.!?])\\s+|\\n+"))
            .map { it.trim() }
            .firstOrNull { word.containsMatchIn(it) }
            ?: return null
        if (sentence.length <= QUOTE_MAX) return sentence

        // A long sentence is windowed around the word itself. Cutting from the
        // front alone could quote a "for tomorrow" line with no tomorrow in it.
        val hit = word.find(sentence)!!.range
        val start = if (hit.last < QUOTE_MAX - 1) 0 else hit.first - QUOTE_MAX / 2
        var window = if (start == 0) sentence else sentence.substring(start).substringAfter(' ')
        var tail = ""
        if (window.length > QUOTE_MAX) {
            window = window.take(QUOTE_MAX).substringBeforeLast(' ').trimEnd(',', ';', ':', ' ')
            tail = "…"
        }
        return (if (start == 0) "" else "…") + window + tail
    }
}
