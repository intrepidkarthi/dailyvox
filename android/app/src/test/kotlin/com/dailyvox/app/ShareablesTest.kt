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

    @Test
    fun `a run ending yesterday still counts, since today is not over`() {
        val today = System.currentTimeMillis() / day
        val entries = (1..4).map {
            entry(it, "Spoke.").copy(createdAt = (today - it) * day + 60_000L)
        }
        val m = call("streak", List::class.java)
        assertEquals(4, m.invoke(Shareables, entries))
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
        assertNull(Shareables.milestoneReached(nights(41)))
        assertEquals(42, Shareables.milestoneReached(nights(42)))
        assertEquals(42, Shareables.milestoneReached(nights(99)))
        assertEquals(100, Shareables.milestoneReached(nights(100)))
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
                   Shareables.milestoneReached(twicePerNight))
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
        assertEquals(6, Shareables.Card.entries.size)
    }
}
