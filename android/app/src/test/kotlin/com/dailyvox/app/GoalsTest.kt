package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Goals
import org.junit.Assert.assertEquals
import org.junit.Test
import java.util.Calendar
import java.util.TimeZone

/**
 * Only the parts that take a clock rather than a Context are tested here: the
 * preference getters are three lines of SharedPreferences each, and wiring
 * Robolectric in to watch them read back what they wrote would test the
 * framework rather than this file.
 *
 * What is worth testing is the week boundary, because it is where a goal
 * silently becomes wrong for most of the world.
 */
class GoalsTest {

    private val day = 86_400_000L

    private fun at(y: Int, m: Int, d: Int, hour: Int = 12): Long {
        val c = Calendar.getInstance(TimeZone.getDefault())
        c.set(y, m - 1, d, hour, 0, 0); c.set(Calendar.MILLISECOND, 0)
        return c.timeInMillis
    }

    private fun entry(at: Long, i: Int = 0) =
        Entry(id = "e$at-$i", createdAt = at, text = "spoke", durationSec = 40, valence = 0.2f)

    @Test
    fun `two entries in one evening is one night`() {
        // The whole reason the target counts nights: otherwise a target of three
        // is cleared by talking three times before bed, which is not the habit
        // anyone is trying to build.
        val now = at(2026, 8, 26)
        val evening = at(2026, 8, 26, hour = 21)
        val entries = listOf(entry(evening, 1), entry(evening + 60_000, 2), entry(evening + 120_000, 3))
        assertEquals(1, Goals.nightsThisWeek(entries, now))
    }

    @Test
    fun `entries before this week do not count`() {
        val now = at(2026, 8, 26)
        val lastWeek = now - 8 * day
        assertEquals(0, Goals.nightsThisWeek(listOf(entry(lastWeek)), now))
    }

    @Test
    fun `the week boundary follows the device locale, not Sunday`() {
        // firstDayOfWeek is Sunday in the US and Monday across most of Europe
        // and India. Hard-coding Sunday would reset the goal on the wrong day
        // for most of the people this app is being built for.
        val cal = Calendar.getInstance()
        val now = System.currentTimeMillis()
        cal.timeInMillis = now
        val elapsed = ((cal.get(Calendar.DAY_OF_WEEK) - cal.firstDayOfWeek) + 7) % 7
        assertEquals(7 - elapsed, Goals.daysLeftInWeek(now))
    }

    @Test
    fun `days left is seven on the first day of the week and one on the last`() {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 12)
        cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        // Walk to the locale's own first day rather than assuming which it is.
        while (cal.get(Calendar.DAY_OF_WEEK) != cal.firstDayOfWeek) cal.add(Calendar.DAY_OF_YEAR, 1)
        assertEquals(7, Goals.daysLeftInWeek(cal.timeInMillis))
        cal.add(Calendar.DAY_OF_YEAR, 6)
        assertEquals(1, Goals.daysLeftInWeek(cal.timeInMillis))
    }

    @Test
    fun `distinct days across the week are counted once each`() {
        val cal = Calendar.getInstance()
        cal.set(Calendar.HOUR_OF_DAY, 20)
        cal.set(Calendar.MINUTE, 0); cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        while (cal.get(Calendar.DAY_OF_WEEK) != cal.firstDayOfWeek) cal.add(Calendar.DAY_OF_YEAR, 1)
        val weekStart = cal.timeInMillis
        // Three separate nights, two entries each.
        val entries = (0..2).flatMap {
            listOf(entry(weekStart + it * day, 1), entry(weekStart + it * day + 3_600_000, 2))
        }
        assertEquals(3, Goals.nightsThisWeek(entries, weekStart + 3 * day))
    }

    @Test
    fun `the milestone ladder is the one the share card already uses`() {
        // Not a second list. See the note in Goals: Android and iOS genuinely
        // disagree here, and the disagreement is recorded rather than hidden.
        assertEquals(com.dailyvox.app.system.Shareables.MILESTONES, Goals.MILESTONES)
    }
}
