package com.dailyvox.app

import com.dailyvox.app.system.Streak
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * The streak. Three things carry the weight: a day is the user's local day,
 * one quiet day is forgiven at most once a week, and someone coming back is
 * never shown the state of someone who has never spoken.
 */
class StreakTest {

    private val today = LocalDate.of(2026, 10, 13)
    private val la = ZoneId.of("America/Los_Angeles")

    /** Days spoken, as days back from [today]. */
    private fun state(vararg back: Long) =
        Streak.of(back.map { today.minusDays(it) }.toSet(), today)

    // ── New, active, returning ──────────────────────────────────────────────

    @Test
    fun `no entries is a new user`() {
        val s = Streak.of(emptySet(), today)
        assertEquals(Streak.Kind.NEW, s.kind)
        assertEquals(0, s.current)
        assertEquals(0, s.longest)
        assertEquals(0, s.daysSpoken)
    }

    @Test
    fun `a broken run is a returning user, with what they kept`() {
        // Ten days in a row last month, nothing since.
        val s = state(*(40L..49L).toList().toLongArray())
        assertEquals(Streak.Kind.RETURNING, s.kind)
        assertEquals(0, s.current)
        assertEquals(10, s.longest)
        assertEquals(10, s.daysSpoken)
    }

    @Test
    fun `a single entry long ago is returning, not new`() {
        assertEquals(Streak.Kind.RETURNING, state(300).kind)
    }

    @Test
    fun `today is never a miss`() {
        // Spoke the last three days, not yet today: alive, and today would make four.
        val s = state(1, 2, 3)
        assertEquals(Streak.Kind.ACTIVE, s.kind)
        assertEquals(3, s.current)
        assertFalse(s.spokenToday)
        assertEquals(4, s.ifSpokenToday)
    }

    @Test
    fun `a second entry today does not move the number`() {
        val s = state(0, 1, 2)
        assertTrue(s.spokenToday)
        assertEquals(3, s.current)
        assertEquals(3, s.ifSpokenToday)
    }

    // ── One grace day ───────────────────────────────────────────────────────

    @Test
    fun `one missed day inside a run is forgiven and not counted`() {
        val s = state(0, 1, 3, 4)
        assertEquals(4, s.current)
        assertEquals(listOf(today.minusDays(2)), s.graceDays)
    }

    @Test
    fun `two missed days in a row break the run`() {
        val s = state(0, 1, 4, 5)
        assertEquals(2, s.current)
        assertTrue(s.graceDays.isEmpty())
        assertEquals(2, s.longest)
    }

    @Test
    fun `missing yesterday keeps the run alive until today ends`() {
        // Spoke the two days before yesterday. Today is not over, so the run
        // is still there for the taking, and speaking now makes three.
        val s = state(2, 3)
        assertEquals(Streak.Kind.ACTIVE, s.kind)
        assertEquals(2, s.current)
        assertEquals(3, s.ifSpokenToday)
        assertEquals(listOf(today.minusDays(1)), s.graceDays)
    }

    @Test
    fun `missing yesterday and the day before is a welcome back`() {
        val s = state(3, 4, 5)
        assertEquals(Streak.Kind.RETURNING, s.kind)
        assertEquals(3, s.longest)
    }

    @Test
    fun `grace cannot be chained into every other day`() {
        // Spoke on even days only: the first gap is forgiven, the next one is
        // two days later and is not.
        val s = state(0, 2, 4, 6, 8)
        assertEquals(2, s.current)
        assertEquals(listOf(today.minusDays(1)), s.graceDays)
    }

    @Test
    fun `two graces a week apart are both allowed`() {
        // Gaps at 3 and 10 days back: exactly seven apart.
        val spoken = (0L..14L).filter { it != 3L && it != 10L }
        val s = state(*spoken.toLongArray())
        assertEquals(13, s.current)
        assertEquals(listOf(today.minusDays(3), today.minusDays(10)), s.graceDays)
    }

    @Test
    fun `two graces six days apart break the run at the second`() {
        val spoken = (0L..14L).filter { it != 3L && it != 9L }
        val s = state(*spoken.toLongArray())
        // 0,1,2 then grace at 3, then 4..8, then 9 needs a second grace too soon.
        assertEquals(8, s.current)
        assertEquals(listOf(today.minusDays(3)), s.graceDays)
    }

    @Test
    fun `a head grace yesterday counts against the week too`() {
        // Missed yesterday (grace) and five days back: only four days apart.
        val s = state(2, 3, 4, 6, 7)
        assertEquals(3, s.current)
        assertEquals(listOf(today.minusDays(1)), s.graceDays)
    }

    @Test
    fun `longest uses the same rules and takes the best run`() {
        // Old run: 20..29 with one gap at 25 (9 days). Then a hard break.
        // Current: 0..2.
        val old = (20L..29L).filter { it != 25L }
        val s = state(*(old + listOf(0L, 1L, 2L)).toLongArray())
        assertEquals(3, s.current)
        assertEquals(9, s.longest)
        assertEquals(12, s.daysSpoken)
    }

    @Test
    fun `longest is never shorter than current`() {
        val spoken = (0L..30L).filter { it % 7 != 3L }
        val s = state(*spoken.toLongArray())
        assertTrue(s.longest >= s.current)
        assertEquals(spoken.size, s.current)
    }

    // ── Local days, timezones, DST ──────────────────────────────────────────

    private fun at(y: Int, m: Int, d: Int, h: Int, min: Int = 0, zone: ZoneId = la): Long =
        LocalDateTime.of(y, m, d, h, min).atZone(zone).toInstant().toEpochMilli()

    @Test
    fun `an evening entry in California counts on its own local day`() {
        // 21:00 in Los Angeles is already tomorrow in UTC. Counted by UTC
        // days these two would be the same day and the streak would be 1.
        val entries = listOf(at(2026, 10, 12, 21), at(2026, 10, 13, 8))
        val s = Streak.of(entries, at(2026, 10, 13, 9), la)
        assertEquals(2, s.current)
        assertTrue(s.spokenToday)
    }

    @Test
    fun `just before and just after local midnight are two days`() {
        val entries = listOf(at(2026, 10, 12, 23, 59), at(2026, 10, 13, 0, 1))
        val s = Streak.of(entries, at(2026, 10, 13, 12), la)
        assertEquals(2, s.current)
        assertEquals(2, s.daysSpoken)
    }

    @Test
    fun `a late entry in India is not pushed into the next day`() {
        val kolkata = ZoneId.of("Asia/Kolkata")
        val entries = listOf(at(2026, 10, 11, 23, 30, kolkata), at(2026, 10, 12, 23, 30, kolkata))
        val s = Streak.of(entries, at(2026, 10, 13, 7, 0, kolkata), kolkata)
        assertEquals(2, s.current)
        assertFalse(s.spokenToday)
    }

    @Test
    fun `the spring-forward night is still one day`() {
        // 8 March 2026: Los Angeles skips 02:00-03:00. A 23-hour day must
        // still be one day, not the end of a run.
        val entries = listOf(
            at(2026, 3, 7, 22), at(2026, 3, 8, 23), at(2026, 3, 9, 22),
        )
        val s = Streak.of(entries, at(2026, 3, 9, 23), la)
        assertEquals(3, s.current)
    }

    @Test
    fun `the fall-back night is still one day`() {
        // 1 November 2026: Los Angeles repeats 01:00-02:00, a 25-hour day.
        val entries = listOf(
            at(2026, 10, 31, 0, 30), at(2026, 11, 1, 23, 30), at(2026, 11, 2, 0, 30),
        )
        val s = Streak.of(entries, at(2026, 11, 2, 9), la)
        assertEquals(3, s.current)
        assertEquals(3, s.daysSpoken)
    }
}
