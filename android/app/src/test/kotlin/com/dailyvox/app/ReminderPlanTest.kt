package com.dailyvox.app

import com.dailyvox.app.system.ReminderPlan
import com.dailyvox.app.system.ReminderPlan.Kind
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * The rules that decide whether a phone buzzes tonight.
 *
 * Before this the reminder was one setInexactRepeating alarm: it never stopped
 * for someone who had drifted away, it slid an hour at every DST change, and
 * its "already spoken today" check compared UTC days.
 */
class ReminderPlanTest {

    private val kolkata = ZoneId.of("Asia/Kolkata")
    private val newYork = ZoneId.of("America/New_York")
    private val la = ZoneId.of("America/Los_Angeles")

    private fun at(zone: ZoneId, y: Int, mo: Int, d: Int, h: Int, mi: Int = 0): Long =
        LocalDateTime.of(y, mo, d, h, mi).atZone(zone).toInstant().toEpochMilli()

    private fun local(millis: Long, zone: ZoneId): LocalDateTime =
        java.time.Instant.ofEpochMilli(millis).atZone(zone).toLocalDateTime()

    @Test
    fun `opened this morning, reminded this evening`() {
        val opened = at(kolkata, 2026, 10, 5, 9)
        val fire = ReminderPlan.next(opened, opened, 21, kolkata)!!
        assertEquals(Kind.DAILY, fire.kind)
        assertEquals(at(kolkata, 2026, 10, 5, 21), fire.atMillis)
    }

    @Test
    fun `past tonight's hour, the next one is tomorrow`() {
        val opened = at(kolkata, 2026, 10, 5, 22)
        val fire = ReminderPlan.next(opened, opened, 21, kolkata)!!
        assertEquals(at(kolkata, 2026, 10, 6, 21), fire.atMillis)
    }

    @Test
    fun `seven evenings of daily reminders, counted from the last open`() {
        val opened = at(kolkata, 2026, 10, 5, 9)
        // Evening 6 is the last daily one.
        val lastDaily = ReminderPlan.next(at(kolkata, 2026, 10, 11, 12), opened, 21, kolkata)!!
        assertEquals(Kind.DAILY, lastDaily.kind)
        assertEquals(at(kolkata, 2026, 10, 11, 21), lastDaily.atMillis)
    }

    @Test
    fun `a lapsed user gets one welcome-back a few evenings past the horizon`() {
        val opened = at(kolkata, 2026, 10, 5, 9)
        // Just after the last daily reminder fired.
        val fire = ReminderPlan.next(at(kolkata, 2026, 10, 11, 21, 1), opened, 21, kolkata)!!
        assertEquals(Kind.WELCOME_BACK, fire.kind)
        assertEquals(at(kolkata, 2026, 10, 15, 21), fire.atMillis)
    }

    @Test
    fun `after the welcome-back, silence until the app is opened`() {
        val opened = at(kolkata, 2026, 10, 5, 9)
        assertNull(ReminderPlan.next(at(kolkata, 2026, 10, 15, 21, 1), opened, 21, kolkata))
        assertNull(ReminderPlan.next(at(kolkata, 2026, 12, 25, 12), opened, 21, kolkata))
    }

    @Test
    fun `opening the app again restarts the daily reminders`() {
        val back = at(kolkata, 2026, 11, 20, 8)
        val fire = ReminderPlan.next(back, back, 21, kolkata)!!
        assertEquals(Kind.DAILY, fire.kind)
        assertEquals(at(kolkata, 2026, 11, 20, 21), fire.atMillis)
    }

    @Test
    fun `the hour stays 9pm local across the end of daylight saving`() {
        // DST ends in New York on 2026-11-01. A 24-hour repeat set on the 31st
        // would have landed at 8pm on the 1st.
        val opened = at(newYork, 2026, 10, 31, 22)
        val fire = ReminderPlan.next(opened, opened, 21, newYork)!!
        assertEquals(LocalDateTime.of(2026, 11, 1, 21, 0), local(fire.atMillis, newYork))
    }

    @Test
    fun `an hour that does not exist on a spring-forward day still fires`() {
        // 2am does not exist in New York on 2026-03-08; atZone moves it to 3am.
        val opened = at(newYork, 2026, 3, 7, 23)
        val fire = ReminderPlan.next(opened, opened, 2, newYork)!!
        assertEquals(LocalDateTime.of(2026, 3, 8, 3, 0), local(fire.atMillis, newYork))
    }

    @Test
    fun `after a flight the slot is the new zone's evening`() {
        val now = at(kolkata, 2026, 10, 5, 9)
        val there = ReminderPlan.next(now, now, 21, la)!!
        assertEquals(21, local(there.atMillis, la).hour)
    }

    @Test
    fun `already spoken today is the user's day, not UTC's`() {
        // 8am and 9pm in Los Angeles are 15:00 UTC and 04:00 UTC the next day.
        val morning = at(la, 2026, 10, 5, 8)
        val reminder = at(la, 2026, 10, 5, 21)
        assertTrue(ReminderPlan.sameLocalDay(morning, reminder, la))
        assertFalse(morning / 86_400_000L == reminder / 86_400_000L)  // the old check
        assertFalse(ReminderPlan.sameLocalDay(at(la, 2026, 10, 4, 23), reminder, la))
    }
}
