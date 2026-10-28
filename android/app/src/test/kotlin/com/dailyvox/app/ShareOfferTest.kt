package com.dailyvox.app

import com.dailyvox.app.system.ShareOffer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * When the Story card is offered. Once each at nights 7, 21 and 42, after the
 * save that makes that night; nights are local days; never in onboarding;
 * never with the setting off.
 */
class ShareOfferTest {

    private val ist: ZoneId = ZoneId.of("Asia/Kolkata")
    private val start: LocalDate = LocalDate.of(2026, 1, 1)

    private fun at(day: Long, hour: Int = 21, minute: Int = 0, zone: ZoneId = ist): Long =
        start.plusDays(day).atTime(hour, minute).atZone(zone).toInstant().toEpochMilli()

    /** One entry a night for [n] nights. */
    private fun nights(n: Int): List<Long> = (0 until n).map { at(it.toLong()) }

    private fun due(
        before: List<Long>,
        savedAt: Long,
        shown: Set<Int> = emptySet(),
        enabled: Boolean = true,
        onboarding: Boolean = false,
        zone: ZoneId = ist,
    ) = ShareOffer.due(before, savedAt, zone, shown, enabled, onboarding)

    @Test
    fun `offers on the save that makes night 7, 21 and 42`() {
        assertEquals(7, due(nights(6), at(6)))
        assertEquals(21, due(nights(20), at(20)))
        assertEquals(42, due(nights(41), at(41)))
    }

    @Test
    fun `offers nothing on any other night`() {
        val offered = (1..60).mapNotNull { n -> due(nights(n - 1), at(n - 1L)) }
        assertEquals(listOf(7, 21, 42), offered)
    }

    @Test
    fun `each night is offered at most once, ever`() {
        assertNull(due(nights(6), at(6), shown = setOf(7)))
        assertNull(due(nights(20), at(20), shown = setOf(7, 21)))
        // One number already shown does not block a different one.
        assertEquals(42, due(nights(41), at(41), shown = setOf(7, 21)))
    }

    @Test
    fun `a second entry on the same night does not offer again`() {
        // Seven nights already, and tonight was night 7: a later entry tonight
        // is still night 7 and must not re-raise the card.
        val seven = nights(7)
        assertNull(due(seven, at(6, hour = 23, minute = 10)))
    }

    @Test
    fun `nights are local days, not entries and not UTC days`() {
        // Six nights, two entries each: twelve entries is still six nights,
        // so the next night is the seventh.
        val twice = (0 until 6).flatMap { listOf(at(it.toLong(), 8), at(it.toLong(), 22)) }
        assertEquals(12, twice.size)
        assertEquals(7, due(twice, at(6)))

        // 00:30 in Kolkata is the previous day in UTC. Counted in IST it is a
        // new night (the 7th); counted in UTC it lands on a day already
        // spoken, so no offer. The zone passed in decides.
        val late = at(6, hour = 0, minute = 30)
        assertEquals(7, due(nights(6), late, zone = ist))
        assertNull(due(nights(6), late, zone = ZoneId.of("UTC")))
    }

    @Test
    fun `jumping past a number does not offer a stale one`() {
        // An imported backup can land someone on night 30 without a night-21
        // save. Their next night is 31, which is not on the list.
        assertNull(due(nights(30), at(30)))
    }

    @Test
    fun `never with the setting off`() {
        assertNull(due(nights(6), at(6), enabled = false))
        assertNull(due(nights(41), at(41), enabled = false))
    }

    @Test
    fun `never during onboarding`() {
        // Onboarding saves the first star; even a restored journal sitting at
        // six nights must not be asked to share from inside onboarding.
        assertNull(due(nights(6), at(6), onboarding = true))
        assertNull(due(emptyList(), at(0), onboarding = true))
    }

    @Test
    fun `the first entry ever offers nothing`() {
        assertNull(due(emptyList(), at(0)))
    }

    @Test
    fun `daylight saving does not split or merge a night`() {
        // US DST begins 8 March 2026. Entries at 21:00 local on either side are
        // still one local night each.
        val la = ZoneId.of("America/Los_Angeles")
        val days = (0L until 6L).map {
            LocalDateTime.of(2026, 3, 5, 21, 0).plusDays(it).atZone(la).toInstant().toEpochMilli()
        }
        val seventh = LocalDateTime.of(2026, 3, 11, 21, 0).atZone(la).toInstant().toEpochMilli()
        assertEquals(7, ShareOffer.due(days, seventh, la, emptySet(), true, false))
    }
}
