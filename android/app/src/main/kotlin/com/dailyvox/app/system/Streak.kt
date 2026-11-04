package com.dailyvox.app.system

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId
import java.time.temporal.ChronoUnit

/**
 * The streak, and the one place it is counted.
 *
 * There used to be four copies of this: Repo, the widget, the privacy receipt
 * and (by implication) the Speak header's milestone haptic. All four divided
 * milliseconds by 86.4 million, which is a UTC day, so in California an
 * evening entry counted towards tomorrow. And all four reset a returning user
 * to the exact state of somebody who had never spoken at all. Every consumer
 * now reads [State], so the header, Insights, the widget and the receipt
 * cannot disagree about the same journal.
 *
 * THE RULES.
 *
 *  - A day is the user's LOCAL calendar day in the zone passed in, so a DST
 *    change or a late-night entry lands on the day the user would name.
 *  - Today is never a miss. Until it ends it is simply not spoken yet, so a run
 *    that reached yesterday is still alive this morning.
 *  - ONE GRACE DAY. A single missed day between two spoken days does not break
 *    the run. It is not counted as a spoken day: the number is always days the
 *    user actually spoke. Two missed days in a row always break it.
 *  - At most one grace in any 7 days: two grace days in one run must be at
 *    least [GRACE_SPACING_DAYS] apart. Otherwise every other day would do, and
 *    a streak that asks for nothing means nothing.
 *  - A user with entries and no live run is RETURNING, never NEW. They see a
 *    welcome back with their longest run and days spoken, not "no streak yet".
 *
 * Pure and Android-free, so the rules are tested on the JVM.
 */
object Streak {

    /** Two grace days in one run must be at least this many days apart. */
    const val GRACE_SPACING_DAYS = 7L

    enum class Kind {
        /** Has never spoken. */
        NEW,
        /** Has a live run. */
        ACTIVE,
        /** Has spoken before, and the run has ended. Welcomed back, not reset. */
        RETURNING,
    }

    data class State(
        /** Days spoken in the live run. Grace days are not in it. */
        val current: Int,
        /** The longest run in the whole journal, by the same rules. */
        val longest: Int,
        /** Distinct local days with at least one entry, ever. */
        val daysSpoken: Int,
        val spokenToday: Boolean,
        /** The grace days the live run is leaning on, newest first. */
        val graceDays: List<LocalDate>,
    ) {
        val kind: Kind
            get() = when {
                daysSpoken == 0 -> Kind.NEW
                current > 0 -> Kind.ACTIVE
                else -> Kind.RETURNING
            }

        /**
         * What [current] will read once an entry is saved today. The milestone
         * haptic fires on this, so a second entry on a day already spoken
         * cannot fire it again.
         */
        val ifSpokenToday: Int
            get() = if (spokenToday) current else current + 1

        companion object {
            val EMPTY = State(0, 0, 0, false, emptyList())
        }
    }

    fun localDay(millis: Long, zone: ZoneId): LocalDate =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()

    fun of(createdAts: Iterable<Long>, nowMillis: Long, zone: ZoneId): State =
        of(createdAts.map { localDay(it, zone) }.toSet(), localDay(nowMillis, zone))

    fun of(days: Set<LocalDate>, today: LocalDate): State {
        if (days.isEmpty()) return State.EMPTY
        val spokenToday = today in days
        val (current, graces) = walk(days, if (spokenToday) today else today.minusDays(1))

        // Every run ends on a spoken day whose next day was not spoken, so the
        // longest is the longest walk back from one of those. The same walk as
        // [current], so the two can never use different rules.
        val longest = days
            .filter { it.plusDays(1) !in days }
            .maxOf { walk(days, it).first }

        return State(
            current = current,
            longest = maxOf(longest, current),
            daysSpoken = days.size,
            spokenToday = spokenToday,
            graceDays = graces,
        )
    }

    /**
     * Spoken days counted back from [from], bridging a single missed day when
     * the day before it was spoken and no other grace in this run is within
     * [GRACE_SPACING_DAYS]. Returns the count and the grace days used.
     */
    private fun walk(days: Set<LocalDate>, from: LocalDate): Pair<Int, List<LocalDate>> {
        var d = from
        var count = 0
        val graces = mutableListOf<LocalDate>()
        while (true) {
            if (d in days) { count++; d = d.minusDays(1); continue }
            val before = d.minusDays(1)
            val spaced = graces.lastOrNull()
                ?.let { ChronoUnit.DAYS.between(d, it) >= GRACE_SPACING_DAYS } ?: true
            if (before !in days || !spaced) break
            graces += d
            d = before
        }
        return count to graces
    }
}
