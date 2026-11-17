package com.dailyvox.app.system

import com.dailyvox.app.data.Entry
import com.dailyvox.twin.LanguageFeature
import com.dailyvox.twin.LanguageGate
import com.dailyvox.twin.Retrieval
import java.time.Instant
import java.time.ZoneId
import java.util.Locale

/**
 * Early signals: what a week-one journal can honestly say.
 *
 * Patterns need [com.dailyvox.twin.Insights.MIN_ENTRIES] entries and the Twin
 * summary needs five. At one entry a day, a new user could not see either in
 * their first week, and week one is when they decide whether to keep going.
 *
 * So from [MIN_ENTRIES] there is this, and it is held to a stricter rule than
 * the patterns are: ONLY COUNTS. When you usually speak, how long your entries
 * run and which way that is moving, a word or name that is in more than one
 * entry exactly as you said it, and the moods you picked. No personality, no
 * causes, nothing from the Twin's learned profile, and no valence: three
 * entries cannot carry a claim about you, but they can be counted.
 *
 * It gives way at the patterns threshold rather than sitting beside them, so
 * the two never compete. Every line is a count the user can check against
 * their own journal, so nothing here can contradict a pattern later.
 *
 * Pure and Android-free, so these rules are tested on the JVM.
 */
object EarlySignals {

    /** Entries before any early signal is shown. */
    const val MIN_ENTRIES = 3
    /** Where the real patterns take over. One number, read from the engine. */
    val UNTIL: Int = com.dailyvox.twin.Insights.MIN_ENTRIES
    /** A word or name has to be in at least this many entries. */
    const val MIN_RECURRING_ENTRIES = 2
    /** At most this many recurring words and names, names first. */
    const val RECURRING_MAX = 3
    /** Words shorter than this are almost all glue. */
    private const val MIN_WORD_LETTERS = 4
    /** The later half has to differ by this fraction to be called a change... */
    private const val LENGTH_CHANGE = 0.25
    /** ...and by at least this many words, so 4 against 6 is not "longer". */
    private const val LENGTH_CHANGE_MIN_WORDS = 5

    fun shows(entryCount: Int): Boolean = entryCount in MIN_ENTRIES until UNTIL

    /** The same buckets the patterns use for time of day. */
    enum class Part { SMALL_HOURS, MORNING, AFTERNOON, EVENING, LATE_NIGHT }

    fun partOf(hour: Int): Part = when (hour) {
        in 0..4 -> Part.SMALL_HOURS
        in 5..11 -> Part.MORNING
        in 12..16 -> Part.AFTERNOON
        in 17..21 -> Part.EVENING
        else -> Part.LATE_NIGHT
    }

    /** [count] of [of] entries were spoken in [part]. */
    data class TimeOfDay(val part: Part, val count: Int, val of: Int)

    enum class Trend { LONGER, SHORTER, STEADY }

    /**
     * Words per entry, over entries that have words. [earlier] and [later] are
     * the averages of the first and last [half] of them, in the order spoken.
     */
    data class Length(
        val averageWords: Int,
        val of: Int,
        val half: Int,
        val earlier: Int,
        val later: Int,
        val trend: Trend,
    )

    /** [word] as the user said it, in [entries] separate entries. */
    data class Recurring(val word: String, val entries: Int, val isName: Boolean)

    /** Mood keys with their counts, most first. Chosen and suggested never mix. */
    data class Moods(val chosen: List<Pair<String, Int>>, val suggested: List<Pair<String, Int>>)

    data class Signals(
        val entries: Int,
        val timeOfDay: TimeOfDay?,
        val length: Length?,
        val recurring: List<Recurring>,
        val moods: Moods?,
    ) {
        /** True when none of the lines had enough under them. */
        val isEmpty: Boolean
            get() = timeOfDay == null && length == null && recurring.isEmpty() && moods == null
    }

    /** Null outside the early window: before [MIN_ENTRIES], and from [UNTIL] on. */
    fun of(entries: List<Entry>, zone: ZoneId): Signals? {
        if (!shows(entries.size)) return null
        val ordered = entries.sortedBy { it.createdAt }
        return Signals(
            entries = entries.size,
            timeOfDay = timeOfDay(ordered, zone),
            length = length(ordered),
            recurring = recurring(ordered),
            moods = moods(ordered),
        )
    }

    // ── When ────────────────────────────────────────────────────────────────

    /**
     * The part of the day most entries came in, only when it holds at least
     * two of them and more than half of all of them. The card says "usually",
     * and 2 of 5 is not usually; a tie is not a usual time either.
     */
    internal fun timeOfDay(entries: List<Entry>, zone: ZoneId): TimeOfDay? {
        // The stored hour first: the entry knows when it was spoken, and a
        // trip across timezones must not move it.
        val parts = entries.map { e ->
            partOf(e.hourOfDay ?: Instant.ofEpochMilli(e.createdAt).atZone(zone).hour)
        }
        val ranked = parts.groupingBy { it }.eachCount().entries.sortedByDescending { it.value }
        val top = ranked.firstOrNull() ?: return null
        if (top.value < 2) return null
        if (top.value * 2 <= entries.size) return null
        if (ranked.size > 1 && ranked[1].value == top.value) return null
        return TimeOfDay(top.key, top.value, entries.size)
    }

    // ── How long ────────────────────────────────────────────────────────────

    internal fun length(entries: List<Entry>): Length? {
        val words = entries.map { it.wordCount }.filter { it > 0 }
        if (words.size < MIN_ENTRIES) return null
        val half = words.size / 2
        val earlier = words.take(half).average()
        val later = words.takeLast(half).average()
        val diff = later - earlier
        val trend = when {
            kotlin.math.abs(diff) < LENGTH_CHANGE_MIN_WORDS -> Trend.STEADY
            diff >= earlier * LENGTH_CHANGE -> Trend.LONGER
            -diff >= earlier * LENGTH_CHANGE -> Trend.SHORTER
            else -> Trend.STEADY
        }
        return Length(
            averageWords = Math.round(words.average()).toInt(),
            of = words.size,
            half = half,
            earlier = Math.round(earlier).toInt(),
            later = Math.round(later).toInt(),
            trend = trend,
        )
    }

    // ── What comes back ─────────────────────────────────────────────────────

    /**
     * Names and words in at least [MIN_RECURRING_ENTRIES] entries, counted per
     * entry and matched as whole words. Shown as the user said them.
     *
     * Names only when the text actually says them ([Reflection.nameIn]), so a
     * detector hit the user never spoke cannot come back as a signal. Scripts
     * written without spaces are skipped rather than guessed at: there a
     * "word" between spaces is a whole sentence.
     */
    internal fun recurring(entries: List<Entry>): List<Recurring> {
        val spoken = entries.filter { it.text.isNotBlank() }

        // People only from entries whose names can be read (German, caseless
        // scripts: no), the same gate the engine's detector uses.
        val names = spoken.flatMap { ReadingLanguage.people(it) }.distinct()
            .map { name -> Recurring(name, spoken.count { Reflection.nameIn(name, it.text) }, true) }
            .filter { it.entries >= MIN_RECURRING_ENTRIES }
            .sortedWith(compareByDescending<Recurring> { it.entries }.thenBy { it.word })
        val nameKeys = names.map { it.word.lowercase(Locale.ROOT) }.toSet()

        // key -> (entries it is in, every form it was written in)
        val seen = LinkedHashMap<String, Pair<MutableSet<Int>, MutableList<String>>>()
        spoken.forEachIndexed { i, e ->
            // Glue is language-specific (B-5). [STOP] is English; another
            // language's function words come from the engine's own lists, the
            // ones its word search drops. A language with no list (and an
            // entry from before 1.3 that does not read as English) has its
            // words left out rather than "para" or "que" shown as what comes
            // back. English is read exactly as before.
            val reading = ReadingLanguage.of(e)
            if (!LanguageGate.supportsRecorded(LanguageFeature.SEARCH_LEXICAL, reading)) return@forEachIndexed
            val english = (LanguageGate.baseCode(reading) ?: "en") == "en"
            WORD.findAll(e.text).forEach { m ->
                val form = m.value.removeSuffix("'s").removeSuffix("’s").trimEnd('\'', '’')
                if (form.codePoints().anyMatch { unspaced(it) }) return@forEach
                val key = form.lowercase(Locale.ROOT)
                if (key.length < MIN_WORD_LETTERS || key in STOP || key in nameKeys) return@forEach
                if (!english && Retrieval.words(form, reading).isEmpty()) return@forEach
                val slot = seen.getOrPut(key) { mutableSetOf<Int>() to mutableListOf() }
                slot.first += i
                slot.second += form
            }
        }
        val words = seen.entries
            .filter { it.value.first.size >= MIN_RECURRING_ENTRIES }
            .map { (key, v) ->
                // The form said most often; the first one said, on a tie.
                val forms = v.second
                val form = forms.distinct().maxBy { f -> forms.count { it == f } }
                key to Recurring(form, v.first.size, false)
            }
            .sortedWith(compareByDescending<Pair<String, Recurring>> { it.second.entries }.thenBy { it.first })
            .map { it.second }

        return (names + words).take(RECURRING_MAX)
    }

    private val WORD = Regex("\\p{L}[\\p{L}\\p{M}'’]*")

    private fun unspaced(cp: Int): Boolean = when (Character.UnicodeScript.of(cp)) {
        Character.UnicodeScript.HAN, Character.UnicodeScript.HIRAGANA,
        Character.UnicodeScript.KATAKANA, Character.UnicodeScript.THAI,
        Character.UnicodeScript.LAO, Character.UnicodeScript.KHMER,
        Character.UnicodeScript.MYANMAR -> true
        else -> false
    }

    /**
     * Glue, and the words every diary entry says. Four letters and up only,
     * because shorter words are already left out.
     */
    private val STOP = setOf(
        "that", "this", "with", "have", "from", "they", "them", "their", "there",
        "then", "than", "what", "when", "where", "which", "while", "were", "been",
        "being", "about", "would", "could", "should", "just", "really", "very",
        "much", "more", "most", "some", "also", "into", "over", "only", "even",
        "still", "back", "after", "before", "because", "going", "like", "well",
        "know", "think", "thought", "thing", "things", "today", "tonight",
        "yesterday", "tomorrow", "morning", "evening", "night", "time", "felt",
        "feel", "feeling", "went", "said", "says", "getting", "make", "made",
        "does", "doing", "done", "want", "wanted", "need", "little", "actually",
        "pretty", "right", "okay", "yeah", "good", "maybe", "kind", "sort",
        "lots", "else", "other", "another", "these", "those", "your", "yours",
        "mine", "myself", "every", "each", "again", "around", "through", "though",
        "something", "anything", "nothing", "everything", "someone", "anyone",
        "stuff", "here", "days", "week", "will", "didn't", "don't", "doesn't",
        "can't", "won't", "it's", "i'm", "i've", "i'd", "i'll", "that's", "there's",
        "we're", "they're", "you're", "isn't", "wasn't", "got", "gets", "come",
        "came", "take", "took", "tell", "told", "today's", "first", "last",
        "next", "many", "such", "both", "same", "ever", "never", "always",
    )

    // ── Moods ───────────────────────────────────────────────────────────────

    /**
     * Moods the user picked, counted. The app's suggestions are counted apart
     * and only for entries with no pick, so a suggestion can never be shown as
     * a choice. Null when there is neither.
     */
    internal fun moods(entries: List<Entry>): Moods? {
        fun count(keys: List<String>) = keys.groupingBy { it }.eachCount().toList()
            .sortedWith(compareByDescending<Pair<String, Int>> { it.second }.thenBy { it.first })
        val chosen = count(entries.mapNotNull { e ->
            e.selfLabel?.let { SelfLabels.canonical(it) ?: it }
        })
        val suggested = count(entries.filter { it.moodIsSuggested }.mapNotNull { e ->
            e.suggestedMood?.let { SelfLabels.canonical(it) ?: it }
        })
        if (chosen.isEmpty() && suggested.isEmpty()) return null
        return Moods(chosen, suggested)
    }
}
