package com.dailyvox.app.system

import android.content.Context
import com.dailyvox.app.data.Entry
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * The question above the record button, one per local calendar day.
 *
 * It used to be "How was your day, really?" every night, forever. That line is
 * still here, as the first of the everyday questions and as the fallback; the
 * rest take turns, so the screen reads differently tomorrow without the app
 * having to remember anything. The question is a function of the date, so it
 * is the same all day and survives a relaunch for free.
 *
 * Three kinds, in the order a day can lead with them:
 *
 *  - [Question.Plain]: the research pilot's neutral slice, ported from iOS
 *    TodayView.orderedPrompts. Every third day-of-year, a pilot participant's
 *    day leads with a plain "log your day" question, because neutral is the
 *    scarce class in real diary data and every everyday question invites an
 *    emotional register. Same cadence, same index, so the two phones in one
 *    cohort ask the same thing on the same date.
 *  - [Question.Grounded]: twice a week at most, a name the user actually said
 *    in the last two weeks, handed back as a question. Only ever a name that
 *    is in the entry's text exactly as written, never one from an entry that
 *    read as hard, and never with a pronoun, because the app does not know
 *    who anyone is. When in doubt, the day simply has no grounded question.
 *  - [Question.Everyday]: the rest.
 *
 * Rotating (the "another question" tap) walks the day's sequence; it never
 * gates the record button, which works whatever the question says.
 *
 * Runs over the live table each time, so a deleted entry is not in the list
 * and its names can never come back here. The words themselves live in
 * strings.xml; this file only picks. Pure and Android-free apart from the
 * small preference helpers at the bottom, so the rules are tested on the JVM.
 */
object DailyQuestion {

    sealed interface Question {
        /** An index into `R.array.daily_questions`. 0 is "How was your day, really?". */
        data class Everyday(val index: Int) : Question
        /** An index into `R.array.daily_questions_plain`. */
        data class Plain(val index: Int) : Question
        /** [name] exactly as the user said it, last said [daysAgo] local days ago. */
        data class Grounded(val name: String, val daysAgo: Int) : Question
    }

    /** Must match the length of `R.array.daily_questions`; a test checks it. */
    const val EVERYDAY_COUNT = 26
    /** Must match `R.array.daily_questions_plain`, and iOS EntryPrompt.neutralPrompts. */
    const val PLAIN_COUNT = 2

    /**
     * Step through the everyday questions this many places a day. Coprime with
     * [EVERYDAY_COUNT], so every question comes up once before any repeats and
     * two days in a row are never neighbours in the list.
     */
    private const val STRIDE = 7

    /** Grounded days. Two a week, never back to back. */
    val GROUNDED_DAYS = setOf(DayOfWeek.TUESDAY, DayOfWeek.SATURDAY)
    /**
     * How far back a name may come from, in local days. Today does not count.
     * Thirteen, not fourteen, so the oldest template, "Last week you
     * mentioned", is still true of the oldest name it can carry.
     */
    const val GROUNDED_WINDOW_DAYS = 13L
    /** How far back an entry that read as hard rules a name out. */
    const val SENSITIVE_WINDOW_DAYS = 30L
    /** VADER's own neutral band. Anything below it is not a day to bring back. */
    private const val NEGATIVE = -0.05f
    /** A name is a word or a few, never a sentence the detector ran on with. */
    private const val NAME_MAX_WORDS = 3

    /** Self-labels and suggestions that mean the entry was a hard one. */
    private val HARD_MOODS = setOf("sadness", "anger", "fear", "disgust")

    /**
     * Words that make an entry off limits whatever its score. VADER sums, so
     * "my grandmother died, everyone was so kind" reads positive, and asking
     * how things are with someone named in it would be the cruellest thing
     * this screen could do. Over-broad on purpose.
     */
    private val SENSITIVE = Regex(
        "\\b(die[ds]?|dying|death|dead|funeral|passed away|pass away|grie(f|ve|ving)|" +
            "hospital|hospice|cancer|diagnos\\w*|surgery|sick|ill|illness|" +
            "broke up|break ?up|breaking up|divorce\\w*|separat\\w*|" +
            "fight|fought|argu\\w*|miscarr\\w*|abus\\w*|assault\\w*|" +
            "hurt|lost|loss|scared|afraid|panic|depress\\w*|suicid\\w*|" +
            "fired|laid off|layoff)\\b",
        RegexOption.IGNORE_CASE,
    )

    /** The pilot rule, exactly as iOS: day-of-year divisible by three. */
    fun pilotLeadsPlain(date: LocalDate, pilot: Boolean): Boolean =
        pilot && date.dayOfYear % 3 == 0

    /** Which plain question a pilot day leads with. Same arithmetic as iOS. */
    fun plainIndex(date: LocalDate): Int = (date.dayOfYear / 3) % PLAIN_COUNT

    /** The day's everyday question, before any rotation. */
    fun everydayIndex(date: LocalDate): Int =
        Math.floorMod(date.toEpochDay() * STRIDE, EVERYDAY_COUNT.toLong()).toInt()

    /**
     * Everything the day can show, lead first. Rotation walks this list and
     * wraps. A first-ever visit gets the signature question and nothing else
     * moves until there is a journal to speak of.
     */
    fun sequence(
        all: List<Entry>,
        now: Long,
        zone: ZoneId,
        pilot: Boolean,
    ): List<Question> {
        val today = Resurface.localDate(now, zone)
        val out = mutableListOf<Question>()
        if (pilotLeadsPlain(today, pilot)) out += Question.Plain(plainIndex(today))
        // A pilot's plain day stays plain: the neutral slice is the point of it.
        else grounded(all, now, zone)?.let { out += it }
        val start = if (all.isEmpty()) 0 else everydayIndex(today)
        for (i in 0 until EVERYDAY_COUNT) {
            out += Question.Everyday(Math.floorMod(start + i * STRIDE, EVERYDAY_COUNT))
        }
        return out
    }

    /** The question to show after [turn] taps of "another question". */
    fun forDay(
        all: List<Entry>,
        now: Long,
        zone: ZoneId,
        pilot: Boolean,
        turn: Int = 0,
    ): Question {
        val seq = sequence(all, now, zone, pilot)
        return seq[Math.floorMod(turn, seq.size)]
    }

    /**
     * A name from the last two weeks, or null. Null is the usual answer:
     * only on [GROUNDED_DAYS], only a name the text says as written and never
     * says lowercase, and never a name any word of which appears in an entry
     * of the last month that read as hard. The name the user said in the most entries
     * wins, the latest on a tie.
     */
    fun grounded(all: List<Entry>, now: Long, zone: ZoneId): Question.Grounded? {
        val today = Resurface.localDate(now, zone)
        if (today.dayOfWeek !in GROUNDED_DAYS) return null

        fun daysAgo(e: Entry) = ChronoUnit.DAYS.between(Resurface.localDate(e.createdAt, zone), today)
        val withText = all.filter { it.text.isNotBlank() }
        val recent = withText.filter { daysAgo(it) in 1..GROUNDED_WINDOW_DAYS }
        if (recent.isEmpty()) return null
        // English only, until there is a sensitive list per language. The guard
        // below is an English word list plus an English lexicon: a Spanish
        // bereavement entry ("murió", "funeral" aside) passes it untouched, and
        // the question would then ask after the person who died. One entry the
        // guard cannot read in the window it guards, and there is no grounded
        // question at all -- the everyday questions carry the day. "Can read"
        // is the engine gate's MOOD row (English), asked of the entry's stored
        // language, so a Spanish-tagged entry is caught even when it is short.
        if (withText.any {
                daysAgo(it) in 0..SENSITIVE_WINDOW_DAYS &&
                    !ReadingLanguage.reads(com.dailyvox.twin.LanguageFeature.MOOD, it)
            }) return null
        val hard = withText.filter { daysAgo(it) in 0..SENSITIVE_WINDOW_DAYS && isHard(it) }
        // Already talked about today: asking again tonight would be an echo.
        val saidToday = withText.filter { daysAgo(it) == 0L }

        return recent
            .flatMap { e -> ReadingLanguage.people(e).filter { looksLikeName(it) && saidAsWritten(it, e.text) } }
            .distinct()
            // "Will" opened a sentence once and "will" is everywhere else: a
            // word the user also says lowercase is a word, not a name.
            .filter { name -> withText.none { saidAsWritten(name.lowercase(), it.text) } }
            // "Aunt Priya" is still Priya: one word of the name in a hard
            // entry, as written or as the detector filed it, is enough.
            .filter { name ->
                val parts = name.split(' ').filter { it.isNotEmpty() } + name
                hard.none { e -> parts.any { saidAsWritten(it, e.text) || it in hardWords(e) } }
            }
            .filter { name -> saidToday.none { saidAsWritten(name, it.text) } }
            .map { name ->
                val hits = recent.filter { saidAsWritten(name, it.text) }
                Triple(name, hits.size, hits.minOf { daysAgo(it) })
            }
            .sortedWith(
                compareByDescending<Triple<String, Int, Long>> { it.second }
                    .thenBy { it.third }
                    .thenBy { it.first }
            )
            .firstOrNull()
            ?.let { Question.Grounded(it.first, it.third.toInt()) }
    }

    /** An entry it would be unkind to bring a name back from. */
    internal fun isHard(e: Entry): Boolean {
        val mood = SelfLabels.canonical(e.selfLabel) ?: e.selfLabel ?: e.suggestedMood
        return mood in HARD_MOODS || (e.valence ?: 0f) <= NEGATIVE || SENSITIVE.containsMatchIn(e.text)
    }

    /** The capitalised words of the names a hard entry's detector filed. */
    private fun hardWords(e: Entry): Set<String> =
        e.entityList.filter { looksLikeName(it) }.flatMap { it.split(' ') }.filter { it.isNotEmpty() }.toSet()

    /** Capitalised, a word or a few. "will" is never Will. */
    internal fun looksLikeName(name: String): Boolean {
        val words = name.split(' ').filter { it.isNotEmpty() }
        return name.length >= 2 && words.size in 1..NAME_MAX_WORDS &&
            words.all { it.first().isUpperCase() }
    }

    /**
     * The name as a whole word, case as written: "Sam" is not in "Samsung" or
     * "sam", "Will" is not in "will". Same matcher as the reflection card.
     */
    internal fun saidAsWritten(name: String, text: String): Boolean = Reflection.nameIn(name, text)

    // ── Preferences ─────────────────────────────────────────────────────────

    /** Same key as iOS @AppStorage, so the setting means one thing everywhere. */
    const val PREF_PILOT = "pilotLabelingEnabled"
    private const val PREF_TURN = "questionTurn"
    private const val PREF_TURN_DAY = "questionTurnDay"

    private fun prefs(context: Context) =
        context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)

    fun isPilot(context: Context): Boolean = prefs(context).getBoolean(PREF_PILOT, false)

    fun setPilot(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean(PREF_PILOT, on).apply()

    /** Taps of "another question" today. Tomorrow starts at the day's own question. */
    fun turn(context: Context, today: LocalDate): Int {
        val p = prefs(context)
        return if (p.getLong(PREF_TURN_DAY, Long.MIN_VALUE) == today.toEpochDay()) p.getInt(PREF_TURN, 0) else 0
    }

    fun setTurn(context: Context, today: LocalDate, turn: Int) =
        prefs(context).edit().putLong(PREF_TURN_DAY, today.toEpochDay()).putInt(PREF_TURN, turn).apply()
}
