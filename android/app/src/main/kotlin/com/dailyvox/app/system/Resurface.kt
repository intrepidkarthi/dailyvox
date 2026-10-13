package com.dailyvox.app.system

import com.dailyvox.app.data.Entry
import java.time.DayOfWeek
import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * The diary's payoff: the user's own past, handed back to them.
 *
 * Three things, each drawn only when the journal really has something under
 * it, and each a VERBATIM excerpt of what the user said. Nothing here is
 * paraphrased, summarised or inferred; the only edits an excerpt ever gets are
 * trimming whitespace and cutting at a sentence (or, failing that, a word)
 * boundary, marked with an ellipsis when the cut lands mid-sentence.
 *
 *  - [weekAgo]: the entry from seven local days ago, else six, else eight.
 *  - [onThisDay]: the same calendar date one month, six months and whole years
 *    back. A date that does not exist that month is skipped rather than
 *    clamped, so 31 March does not show 28 February four days running. The
 *    one exception is 29 February, which is remembered on 28 February in a
 *    year that has no 29th, or it would come back once every four years.
 *  - [recap]: counts for one local week, read off the entries themselves and
 *    never off the Twin's learned profile, plus one line from that week.
 *
 * Every day boundary is the user's LOCAL calendar in the zone passed in. A
 * millisecond-divided-by-86.4-million day is a UTC day, and in California an
 * evening entry would land on tomorrow's card.
 *
 * Runs over the live table each time, so an entry that has been deleted is
 * simply not in the list and can never come back here.
 *
 * Pure and Android-free, so these rules are tested on the JVM.
 */
object Resurface {

    /** An excerpt is a line, not the entry. */
    const val EXCERPT_MAX = 140
    /** Sentences are added until the excerpt is at least this long. */
    private const val EXCERPT_SOFT_MIN = 30
    /** Fewer words than this is a fragment, not something worth quoting back. */
    const val MIN_WORDS = 4
    /** Week-ago days, in the order they are tried. */
    private val WEEK_AGO_DAYS = listOf(7L, 6L, 8L)
    /** Months back that "on this day" looks at, besides whole years. */
    private val MONTHS_BACK = listOf(1L, 6L)
    /** How far back whole years are tried. A twenty-year diary is the user story. */
    private const val YEARS_BACK = 30L
    /** On this day: at most this many cards, nearest first. */
    const val ON_THIS_DAY_MAX = 3
    /** A name has to come up in at least this many entries in the week. */
    const val RECAP_MIN_MENTIONS = 2

    enum class Span { DAYS, MONTHS, YEARS }

    /**
     * One entry from the past and the line quoted from it.
     *
     * [ago] is in [span] units: 7 DAYS, 1 MONTHS, 3 YEARS. The card names the
     * real distance, so a six-day-old entry is never called "a week ago".
     */
    data class Memory(val entry: Entry, val excerpt: String, val span: Span, val ago: Int)

    data class Recap(
        /** First and last local day of the week the recap covers. */
        val from: LocalDate,
        val to: LocalDate,
        val entries: Int,
        val daysSpoken: Int,
        /** A name from the week's entries, or null unless it came up often enough. */
        val name: String?,
        /** How many of the week's entries say [name]. Zero when [name] is null. */
        val nameEntries: Int,
        /** One verbatim line from the week, or null when nothing was quotable. */
        val line: Line?,
    )

    /** An entry and the excerpt quoted from it. */
    data class Line(val entry: Entry, val excerpt: String)

    // ── Week ago ────────────────────────────────────────────────────────────

    fun weekAgo(all: List<Entry>, nowMillis: Long, zone: ZoneId): Memory? {
        val today = localDate(nowMillis, zone)
        val byDay = quotable(all).groupBy { localDate(it.first.createdAt, zone) }
        for (back in WEEK_AGO_DAYS) {
            val pick = best(byDay[today.minusDays(back)]) ?: continue
            return Memory(pick.first, pick.second, Span.DAYS, back.toInt())
        }
        return null
    }

    // ── On this day ─────────────────────────────────────────────────────────

    fun onThisDay(all: List<Entry>, nowMillis: Long, zone: ZoneId): List<Memory> {
        val today = localDate(nowMillis, zone)
        val byDay = quotable(all).groupBy { localDate(it.first.createdAt, zone) }
        if (byDay.isEmpty()) return emptyList()
        val earliest = byDay.keys.min()

        val found = mutableListOf<Memory>()
        for (m in MONTHS_BACK) {
            val day = today.minusMonths(m)
            // minusMonths clamps 31 March to 28 February; that is a different
            // date, not the same one a month ago.
            if (day.dayOfMonth != today.dayOfMonth) continue
            best(byDay[day])?.let { found += Memory(it.first, it.second, Span.MONTHS, m.toInt()) }
        }
        for (y in 1L..YEARS_BACK) {
            val day = today.minusYears(y)
            if (day.isBefore(earliest.minusDays(1))) break
            val candidates = buildList {
                if (day.dayOfMonth == today.dayOfMonth) byDay[day]?.let { addAll(it) }
                // 28 Feb in a non-leap year also remembers a 29 Feb back then.
                if (today.monthValue == 2 && today.dayOfMonth == 28 && !today.isLeapYear) {
                    val leap = day.withDayOfMonth(1).plusMonths(1).minusDays(1)
                    if (leap.dayOfMonth == 29) byDay[leap]?.let { addAll(it) }
                }
            }
            best(candidates)?.let { found += Memory(it.first, it.second, Span.YEARS, y.toInt()) }
        }
        return found.take(ON_THIS_DAY_MAX)
    }

    // ── Weekly recap ────────────────────────────────────────────────────────

    /**
     * The recap appears on the first day of the user's week (Sunday in the US,
     * Monday in most of Europe), looking back at the seven days just finished.
     */
    fun isRecapDay(today: LocalDate, firstDayOfWeek: DayOfWeek): Boolean =
        today.dayOfWeek == firstDayOfWeek

    /**
     * The locale's first day of the week, or Sunday when the locale names no
     * region to take one from. A bare "en" would otherwise fall to the world
     * default of Monday, which is wrong for most of the people it describes.
     */
    fun firstDayOfWeek(locale: java.util.Locale): DayOfWeek =
        if (locale.country.isNullOrEmpty()) DayOfWeek.SUNDAY
        else java.time.temporal.WeekFields.of(locale).firstDayOfWeek

    /** The first day of the most recent week that has fully ended. */
    fun lastWeekStart(today: LocalDate, firstDayOfWeek: DayOfWeek): LocalDate {
        val back = (today.dayOfWeek.value - firstDayOfWeek.value + 7) % 7
        return today.minusDays(back.toLong()).minusDays(7)
    }

    /** Null when the week has no entries: a recap of nothing is not shown. */
    fun recap(all: List<Entry>, from: LocalDate, zone: ZoneId): Recap? {
        val to = from.plusDays(6)
        val week = all.filter {
            val d = localDate(it.createdAt, zone)
            !d.isBefore(from) && !d.isAfter(to) && (it.text.isNotBlank() || it.isUntranscribed)
        }
        if (week.isEmpty()) return null

        // A name counts only when the entry's text actually says it, so a
        // detector hit the user never spoke cannot be the week's headline.
        // Counted per entry: saying "Sarah" five times in one entry is one
        // entry about Sarah.
        val counts = week
            .flatMap { e -> e.entityList.filter { Reflection.nameIn(it, e.text) } }
            .distinct()
            .map { name -> name to week.count { Reflection.nameIn(name, it.text) } }
            .filter { it.second >= RECAP_MIN_MENTIONS }
            .sortedWith(compareByDescending<Pair<String, Int>> { it.second }.thenBy { it.first })
        val top = counts.firstOrNull()

        // The line: from the entry the user said most in, the latest on a tie.
        val line = quotable(week)
            .sortedWith(compareByDescending<Pair<Entry, String>> { it.first.wordCount }
                .thenByDescending { it.first.createdAt })
            .firstOrNull()
            ?.let { (e, ex) -> Line(e, ex) }

        return Recap(
            from = from,
            to = to,
            entries = week.size,
            daysSpoken = week.map { localDate(it.createdAt, zone) }.toSet().size,
            name = top?.first,
            nameEntries = top?.second ?: 0,
            line = line,
        )
    }

    // ── Excerpts ────────────────────────────────────────────────────────────

    /**
     * A short verbatim excerpt from the start of [text], or null when there is
     * nothing to quote.
     *
     * Whole sentences are kept while they fit, until the excerpt reads as a
     * line. A first sentence longer than [EXCERPT_MAX] is cut at the last
     * space, or for scripts written without spaces at a character boundary
     * that never splits an emoji or a combining mark, and ends in "…".
     */
    fun excerpt(text: String): String? {
        val t = text.trim()
        val ends = sentenceEnds(t)
        if (ends.isEmpty()) return null
        val first = t.substring(0, ends[0].end).trim()
        if (first.length > EXCERPT_MAX) return cut(first)

        // A prefix of the text itself, never sentences re-joined: re-joining
        // would put a space between two Japanese sentences that had none.
        var end = ends[0].end
        for (i in 1 until ends.size) {
            if (ends[i - 1].paragraph) break
            if (t.substring(0, end).trimEnd().length >= EXCERPT_SOFT_MIN) break
            if (t.substring(0, ends[i].end).trimEnd().length > EXCERPT_MAX) break
            end = ends[i].end
        }
        return t.substring(0, end).trim()
    }

    /** Where a sentence ends (exclusive), and whether a newline ends it. */
    internal data class End(val end: Int, val paragraph: Boolean)

    /** The sentences of [text], trimmed. */
    internal fun sentences(text: String): List<String> {
        var start = 0
        return sentenceEnds(text).map { e -> text.substring(start, e.end).trim().also { start = e.end } }
    }

    /**
     * Sentence ends, on the terminators people actually dictate in: Latin
     * `.!?`, the ellipsis, Arabic `؟` and `۔`, Devanagari `।`, and the
     * full-width CJK marks, which are not followed by a space. Closing quotes
     * and brackets stay with the sentence they close. A newline always ends
     * one, and an excerpt never runs on past it. Stretches with nothing but
     * whitespace in them are not sentences.
     */
    internal fun sentenceEnds(text: String): List<End> {
        val out = mutableListOf<End>()
        var segmentStart = 0
        var i = 0
        fun close(at: Int, paragraph: Boolean) {
            if (text.substring(segmentStart, at).isNotBlank()) out += End(at, paragraph)
            else if (paragraph && out.isNotEmpty()) out[out.lastIndex] = out.last().copy(paragraph = true)
            segmentStart = at
        }
        while (i < text.length) {
            val cp = text.codePointAt(i)
            i += Character.charCount(cp)
            if (cp == '\n'.code) { close(i - 1, true); segmentStart = i; continue }
            val wide = cp in WIDE_TERMINATORS
            if (cp in TERMINATORS || wide) {
                while (i < text.length && text.codePointAt(i).let { it in TERMINATORS || it in WIDE_TERMINATORS || it in CLOSERS }) {
                    i += Character.charCount(text.codePointAt(i))
                }
                if (wide || i >= text.length || Character.isWhitespace(text.codePointAt(i))) close(i, false)
            }
        }
        close(text.length, false)
        return out
    }

    private fun cut(sentence: String): String {
        val limit = EXCERPT_MAX - 1
        val space = sentence.lastIndexOf(' ', limit)
        val end = if (space >= EXCERPT_MAX / 2) space else graphemeBoundaryAtOrBefore(sentence, limit)
        return sentence.substring(0, end).trimEnd().trimEnd(',', ';', ':', '-', '—', '–') + "…"
    }

    /**
     * The last grapheme boundary at or before [limit]. BreakIterator keeps a
     * surrogate pair and a base letter with its combining marks together; the
     * loop after it also refuses to end on a zero-width joiner or a variation
     * selector, which older JDKs do not treat as part of the cluster.
     */
    private fun graphemeBoundaryAtOrBefore(s: String, limit: Int): Int {
        val it = java.text.BreakIterator.getCharacterInstance()
        it.setText(s)
        var end = if (it.isBoundary(limit)) limit else it.preceding(limit)
        while (end > 0 && splitsSequence(s, end)) end = it.preceding(end).coerceAtLeast(0)
        return end
    }

    /** True when cutting at [at] would separate an emoji from its joiner or modifier. */
    private fun splitsSequence(s: String, at: Int): Boolean {
        if (at >= s.length) return false
        val before = s.codePointBefore(at)
        val after = s.codePointAt(at)
        return before == ZWJ || after == ZWJ || after in 0xFE00..0xFE0F || after in 0x1F3FB..0x1F3FF ||
            Character.getType(after) == Character.NON_SPACING_MARK.toInt()
    }

    private const val ZWJ = 0x200D

    private val TERMINATORS = setOf('.'.code, '!'.code, '?'.code, 0x2026, 0x061F, 0x0964, 0x06D4)
    private val WIDE_TERMINATORS = setOf(0x3002, 0xFF01, 0xFF1F, 0xFF0E)
    private val CLOSERS = setOf('"'.code, '\''.code, ')'.code, ']'.code, 0x201D, 0x2019, 0x00BB, 0x300D, 0x300F, 0xFF09)

    // ── Helpers ─────────────────────────────────────────────────────────────

    /**
     * Entries with something worth quoting, paired with the quote. An entry
     * with no words (audio the recogniser missed) or only a word or three is
     * skipped rather than shown as an empty card.
     */
    private fun quotable(all: List<Entry>): List<Pair<Entry, String>> =
        all.asSequence()
            .filter { !it.isUntranscribed && it.wordCount >= MIN_WORDS }
            .mapNotNull { e -> excerpt(e.text)?.let { e to it } }
            .toList()

    /** On a day with several entries, the one with the most said; the earliest on a tie. */
    private fun best(day: List<Pair<Entry, String>>?): Pair<Entry, String>? =
        day?.sortedWith(compareByDescending<Pair<Entry, String>> { it.first.wordCount }
            .thenBy { it.first.createdAt })?.firstOrNull()

    fun localDate(millis: Long, zone: ZoneId): LocalDate =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()
}
