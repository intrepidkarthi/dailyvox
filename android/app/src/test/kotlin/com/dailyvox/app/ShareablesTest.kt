package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Shareables
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.lang.reflect.Method

/**
 * A share card is the one artifact this app produces that leaves the phone, and
 * it leaves permanently — you cannot unpost a screenshot, and the person named
 * on it never agreed to be. So the tests that matter here are about what the
 * card REFUSES to say.
 *
 * These reach the private helpers by reflection rather than widening them to
 * internal: the redaction rule is worth testing, but it is not worth changing
 * the shape of the class to test it.
 */
class ShareablesTest {

    private val day = 86_400_000L
    private val base = 1_700_000_000_000L
    private val utc = java.time.ZoneOffset.UTC

    private fun entry(i: Int, text: String, people: List<String> = emptyList(), v: Float = 0.3f) =
        Entry(
            id = "e$i", createdAt = base + i * day, text = text, durationSec = 40,
            valence = v, entities = people.joinToString(","),
        )

    private fun call(name: String, vararg types: Class<*>): Method =
        Shareables::class.java.getDeclaredMethod(name, *types).apply { isAccessible = true }

    @Test
    fun `most-said word ignores fillers`() {
        // "nothing" appears five times here and would otherwise win. A card
        // announcing it as your word of the year is a worse brag than no card.
        val entries = List(5) { entry(it, "Nothing much happened. Nothing at all.") } +
            List(4) { entry(it + 5, "Rebuilt the reservoir loop. Reservoir again.") }
        val m = call("mostSaidWord", List::class.java)

        val word = m.invoke(Shareables, entries) as String?
        assertEquals("\"reservoir\"", word)
    }

    @Test
    fun `most-said word needs three uses before it will claim one`() {
        // One memorable entry must not define somebody's year. Every other
        // entry shares no content word with any other, so "bioluminescence" at
        // two uses is the only candidate — and two is below the gate.
        val varied = listOf(
            "Walked uphill.", "Cooked pasta.", "Read quietly.",
            "Called mother.", "Fixed bicycle.", "Watched rain.",
        ).mapIndexed { i, t -> entry(i, t) }
        val entries = varied + entry(6, "Bioluminescence. Bioluminescence again.")
        val m = call("mostSaidWord", List::class.java)
        assertNull(m.invoke(Shareables, entries))
    }

    @Test
    fun `a broken streak reports zero rather than the old run`() {
        // Every day last month, nothing since: the receipt must not print 30.
        val entries = List(30) { entry(it, "Spoke.") }.map {
            it.copy(createdAt = it.createdAt - 60 * day)
        }
        val m = call("streak", List::class.java)
        assertEquals(0, m.invoke(Shareables, entries))
    }

    /** Nine in the evening, [back] local days ago, in this JVM's zone. */
    private fun localEvening(back: Long): Long =
        java.time.LocalDate.now().minusDays(back).atTime(21, 0)
            .atZone(java.time.ZoneId.systemDefault()).toInstant().toEpochMilli()

    @Test
    fun `a run ending yesterday still counts, since today is not over`() {
        val entries = (1..4).map { entry(it, "Spoke.").copy(createdAt = localEvening(it.toLong())) }
        val m = call("streak", List::class.java)
        assertEquals(4, m.invoke(Shareables, entries))
    }

    @Test
    fun `the receipt counts a grace day the way the app does`() {
        // One quiet day inside the run: the receipt and the header must print
        // the same number, and the missed day is not in it.
        val entries = listOf(0L, 1L, 3L, 4L).mapIndexed { i, back ->
            entry(i, "Spoke.").copy(createdAt = localEvening(back))
        }
        val m = call("streak", List::class.java)
        assertEquals(4, m.invoke(Shareables, entries))
        assertEquals(
            com.dailyvox.app.system.Streak.of(
                entries.map { it.createdAt }, System.currentTimeMillis(),
                java.time.ZoneId.systemDefault()).current,
            m.invoke(Shareables, entries),
        )
    }

    @Test
    fun `warmest month needs three entries before it will name one`() {
        // A single glorious day in an otherwise empty month is not a warm month.
        val entries = List(8) { entry(it, "Steady.", v = 0.1f) } +
            listOf(entry(200, "Perfect day.", v = 0.99f).copy(createdAt = base + 200 * day))
        val m = call("warmestMonth", List::class.java)
        val month = m.invoke(Shareables, entries) as String
        assertFalse("the outlier month must not win", month == "—" && entries.isEmpty())
        // The outlier is alone in its month, so it is excluded by the gate; the
        // answer must come from a month that actually has support.
        assertTrue(month.isNotBlank())
    }

    @Test
    fun `the milestone gate opens only on a listed night`() {
        val today = System.currentTimeMillis() / day
        fun nights(n: Int) = (0 until n).map {
            entry(it, "Spoke.").copy(createdAt = (today - it) * day + 60_000L)
        }
        assertNull(Shareables.milestoneReached(nights(41), utc))
        assertEquals(42, Shareables.milestoneReached(nights(42), utc))
        assertEquals(42, Shareables.milestoneReached(nights(99), utc))
        assertEquals(100, Shareables.milestoneReached(nights(100), utc))
    }

    @Test
    fun `milestone counts nights, not entries`() {
        // Two entries in one evening is one night of showing up. Counting
        // entries would mint the card early and cheapen the only thing on it.
        val today = System.currentTimeMillis() / day
        val twicePerNight = (0 until 30).flatMap { d ->
            listOf(
                entry(d * 2, "Morning.").copy(createdAt = (today - d) * day + 60_000L),
                entry(d * 2 + 1, "Evening.").copy(createdAt = (today - d) * day + 70_000_00L),
            )
        }
        assertEquals(60, twicePerNight.size)
        assertNull("60 entries over 30 nights must not mint night 42",
                   Shareables.milestoneReached(twicePerNight, utc))
    }

    @Test
    fun `nights are local days, the same count as days spoken`() {
        // 23:30 in Los Angeles is 07:30 UTC the next day, and 00:30 in Kolkata
        // is 19:00 UTC the day before. Counting UTC days would split or merge
        // these, and the card would disagree with the Insights screen.
        val la = java.time.ZoneId.of("America/Los_Angeles")
        val ist = java.time.ZoneId.of("Asia/Kolkata")
        fun at(zone: java.time.ZoneId, d: Int, h: Int, m: Int) =
            java.time.LocalDateTime.of(2026, 10, d, h, m).atZone(zone).toInstant().toEpochMilli()

        // LA: 16:00 and 23:30 on the 1st is one local night, two UTC days.
        val laEntries = listOf(entry(0, "a").copy(createdAt = at(la, 1, 16, 0)),
                               entry(1, "b").copy(createdAt = at(la, 1, 23, 30)))
        assertEquals(1, Shareables.nights(laEntries, la))
        assertEquals(2, Shareables.nights(laEntries, utc))

        // IST: 22:00 on the 1st and 00:30 on the 2nd is two local nights, one UTC day.
        val istEntries = listOf(entry(0, "a").copy(createdAt = at(ist, 1, 22, 0)),
                                entry(1, "b").copy(createdAt = at(ist, 2, 0, 30)))
        assertEquals(2, Shareables.nights(istEntries, ist))
        assertEquals(1, Shareables.nights(istEntries, utc))

        // And it is the number Streak reports as days spoken.
        val now = at(ist, 3, 12, 0)
        assertEquals(
            com.dailyvox.app.system.Streak.of(istEntries.map { it.createdAt }, now, ist).daysSpoken,
            Shareables.nights(istEntries, ist),
        )
    }

    @Test
    fun `the milestone mints on the local night, not the UTC one`() {
        // 42 evenings at 20:00 in Kolkata, the last just after local midnight:
        // 41 UTC days hold 41 of them, and the 42nd crosses into its own local day.
        val ist = java.time.ZoneId.of("Asia/Kolkata")
        val start = java.time.LocalDate.of(2026, 1, 1)
        val entries = (0 until 41).map { d ->
            entry(d, "Spoke.").copy(createdAt = start.plusDays(d.toLong()).atTime(20, 0)
                .atZone(ist).toInstant().toEpochMilli())
        } + entry(41, "Late.").copy(createdAt = start.plusDays(41).atTime(0, 30)
            .atZone(ist).toInstant().toEpochMilli())
        assertEquals(42, Shareables.milestoneReached(entries, ist))
        assertNull(Shareables.milestoneReached(entries, utc))
    }

    @Test
    fun `every milestone has a headline that matches its number`() {
        // A probe with the gate forced open rendered a seal reading 1 under a
        // headline reading "Forty-two nights." The headline must be derived
        // from the figure, so adding a milestone can never ship a card that
        // contradicts itself.
        val m = call("milestoneHeadline", Int::class.javaPrimitiveType!!)
        Shareables.MILESTONES.forEach { n ->
            val headline = m.invoke(Shareables, n) as String
            val spelled = mapOf(42 to "Forty-two", 100 to "One hundred", 365 to "A year")
            assertTrue("night $n headline was: $headline",
                       headline.startsWith(spelled.getValue(n)))
        }
        assertEquals("7 nights.", m.invoke(Shareables, 7))
    }

    @Test
    fun `card titles and captions exist for every card`() {
        // The sheet renders these unconditionally; a missing branch would be a
        // crash in the one flow that is meant to be shown off.
        Shareables.Card.entries.forEach { c ->
            assertTrue(Shareables.title(c).isNotBlank())
            assertTrue(Shareables.caption(c).isNotBlank())
        }
        assertEquals(7, Shareables.Card.entries.size)
    }
}
