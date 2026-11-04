package com.dailyvox.app.system

import java.time.Instant
import java.time.LocalDate
import java.time.ZoneId

/**
 * WHEN the reminder fires. Pure java.time, no Android, so the rules that decide
 * whether a phone buzzes tonight are tested on the JVM rather than trusted.
 *
 * Three rules, all measured in the user's LOCAL calendar:
 *
 *  1. Evenings 0..6 after the last time the app was opened get the daily
 *     reminder. The same seven-day horizon iOS arms.
 *  2. A user who has not opened the app in that week is not nagged forever.
 *     The repeating alarm this replaces fired every night for as long as the
 *     phone stayed up, which is how an app earns the "turn off notifications"
 *     long-press. Instead: three quiet evenings, then ONE welcome-back on
 *     evening 10, then silence until they choose to come back.
 *  3. The hour is a wall-clock hour. A repeating alarm is an interval in
 *     milliseconds, so it slid to 8pm or 10pm across a DST change and kept
 *     the old city's 9pm after a flight. Each slot here is computed from the
 *     local date at the time it is armed.
 */
object ReminderPlan {

    /** Evenings armed after an open: offsets 0 until this. Matches iOS. */
    const val HORIZON_DAYS = 7

    /** The one welcome-back, a few quiet evenings past the horizon. */
    const val WELCOME_BACK_DAY = 10

    enum class Kind { DAILY, WELCOME_BACK }

    data class Fire(val atMillis: Long, val kind: Kind)

    /**
     * The next reminder strictly after [nowMillis], or null when there is
     * nothing left to send until the app is opened again.
     */
    fun next(nowMillis: Long, lastOpenedMillis: Long, hourOfDay: Int, zone: ZoneId): Fire? {
        val hour = hourOfDay.coerceIn(0, 23)
        val opened = localDate(lastOpenedMillis, zone)

        var day = localDate(nowMillis, zone)
        var slot = slot(day, hour, zone)
        if (slot <= nowMillis) {
            day = day.plusDays(1)
            slot = slot(day, hour, zone)
        }

        val lastDaily = opened.plusDays(HORIZON_DAYS - 1L)
        if (!day.isAfter(lastDaily)) return Fire(slot, Kind.DAILY)

        val welcome = slot(opened.plusDays(WELCOME_BACK_DAY.toLong()), hour, zone)
        return if (welcome > nowMillis) Fire(welcome, Kind.WELCOME_BACK) else null
    }

    /**
     * "Already spoken today", in the user's calendar. The receiver used to
     * compare `millis / 86_400_000`, which is a UTC day: in California an entry
     * made at 8am and a reminder at 9pm fall on different UTC days, so the
     * reminder fired at someone who had already recorded.
     */
    fun sameLocalDay(aMillis: Long, bMillis: Long, zone: ZoneId): Boolean =
        localDate(aMillis, zone) == localDate(bMillis, zone)

    private fun localDate(millis: Long, zone: ZoneId): LocalDate =
        Instant.ofEpochMilli(millis).atZone(zone).toLocalDate()

    /** atZone moves a slot that lands in a DST gap forward, never drops it. */
    private fun slot(day: LocalDate, hour: Int, zone: ZoneId): Long =
        day.atTime(hour, 0).atZone(zone).toInstant().toEpochMilli()
}
