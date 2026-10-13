package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.EarlySignals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * Week one. Every signal must be a count the user could check by reading
 * their own entries, and the window must hand over to the real patterns at
 * exactly the engine's threshold.
 */
class EarlySignalsTest {

    private val la = ZoneId.of("America/Los_Angeles")
    private var seq = 0

    private fun at(d: Int, h: Int = 21): Long =
        LocalDateTime.of(2026, 10, d, h, 0).atZone(la).toInstant().toEpochMilli()

    private fun entry(
        text: String,
        at: Long,
        entities: String = "",
        hour: Int? = null,
        self: String? = null,
        suggested: String? = null,
        audio: String? = "/a.m4a",
    ) = Entry(
        id = "e${seq++}", text = text, createdAt = at, durationSec = 40, valence = 0f,
        entities = entities, hourOfDay = hour, selfLabel = self, suggestedMood = suggested,
        audioPath = audio,
    )

    private fun words(n: Int) = List(n) { "w$it" }.joinToString(" ")

    // ── The window ──────────────────────────────────────────────────────────

    @Test
    fun `the window opens at three and closes at the patterns threshold`() {
        assertEquals(8, EarlySignals.UNTIL)
        assertEquals(com.dailyvox.twin.Insights.MIN_ENTRIES, EarlySignals.UNTIL)
        assertFalse(EarlySignals.shows(2))
        assertTrue(EarlySignals.shows(3))
        assertTrue(EarlySignals.shows(7))
        assertFalse(EarlySignals.shows(8))
    }

    @Test
    fun `nothing below three or from the patterns threshold`() {
        val two = List(2) { entry("Walked the dog by the river.", at(1 + it)) }
        assertNull(EarlySignals.of(two, la))
        val eight = List(8) { entry("Walked the dog by the river.", at(1 + it)) }
        assertNull(EarlySignals.of(eight, la))
        assertNotNull(EarlySignals.of(eight.take(3), la))
    }

    // ── When ────────────────────────────────────────────────────────────────

    @Test
    fun `usual time of day needs a clear lead`() {
        val evening = listOf(entry("a", at(1), hour = 20), entry("b", at(2), hour = 21),
                             entry("c", at(3), hour = 8))
        val t = EarlySignals.timeOfDay(evening, la)!!
        assertEquals(EarlySignals.Part.EVENING, t.part)
        assertEquals(2, t.count)
        assertEquals(3, t.of)

        // One each: nothing is usual yet.
        val spread = listOf(entry("a", at(1), hour = 20), entry("b", at(2), hour = 13),
                            entry("c", at(3), hour = 8))
        assertNull(EarlySignals.timeOfDay(spread, la))
        // A tie at the top is not a usual time either.
        val tie = spread + entry("d", at(4), hour = 21) + entry("e", at(5), hour = 9)
        assertNull(EarlySignals.timeOfDay(tie, la))
    }

    @Test
    fun `time of day falls back to the local clock, not UTC`() {
        // 21:00 in Los Angeles is 04:00 UTC, the small hours. No stored hour.
        val es = List(3) { entry("x", at(1 + it, 21)) }
        assertEquals(EarlySignals.Part.EVENING, EarlySignals.timeOfDay(es, la)!!.part)
    }

    // ── How long ────────────────────────────────────────────────────────────

    @Test
    fun `length compares the latest half against the first`() {
        val es = listOf(entry(words(20), at(1)), entry(words(30), at(2)),
                        entry(words(60), at(3)), entry(words(70), at(4)))
        val l = EarlySignals.length(es)!!
        assertEquals(45, l.averageWords)
        assertEquals(2, l.half)
        assertEquals(25, l.earlier)
        assertEquals(65, l.later)
        assertEquals(EarlySignals.Trend.LONGER, l.trend)
    }

    @Test
    fun `small or proportionally small changes are steady`() {
        val tiny = listOf(entry(words(4), at(1)), entry(words(5), at(2)), entry(words(8), at(3)))
        assertEquals(EarlySignals.Trend.STEADY, EarlySignals.length(tiny)!!.trend)
        val near = listOf(entry(words(100), at(1)), entry(words(100), at(2)), entry(words(110), at(3)))
        assertEquals(EarlySignals.Trend.STEADY, EarlySignals.length(near)!!.trend)
        val shorter = listOf(entry(words(80), at(1)), entry(words(50), at(2)), entry(words(30), at(3)))
        assertEquals(EarlySignals.Trend.SHORTER, EarlySignals.length(shorter)!!.trend)
    }

    @Test
    fun `entries with no words are left out of length`() {
        val es = listOf(entry(words(20), at(1)), entry("", at(2)), entry(words(30), at(3)),
                        entry(words(40), at(4)))
        val l = EarlySignals.length(es)!!
        assertEquals(3, l.of)
        assertEquals(30, l.averageWords)
        // Only two with words: too few to say anything about length.
        assertNull(EarlySignals.length(es.take(3)))
    }

    @Test
    fun `length is ordered by when it was said, not list order`() {
        val es = listOf(entry(words(70), at(3)), entry(words(20), at(1)), entry(words(45), at(2)))
        val s = EarlySignals.of(es, la)!!
        assertEquals(20, s.length!!.earlier)
        assertEquals(70, s.length!!.later)
    }

    // ── What comes back ─────────────────────────────────────────────────────

    @Test
    fun `a word in two entries comes back as it was said`() {
        val es = listOf(
            entry("Spent the evening at the Reservoir again.", at(1)),
            entry("Ran past the reservoir before work.", at(2)),
            entry("Quiet one, read a book.", at(3)),
        )
        val r = EarlySignals.recurring(es)
        assertEquals(1, r.size)
        assertEquals("Reservoir", r[0].word)   // the first form said, on a tie
        assertEquals(2, r[0].entries)
        assertFalse(r[0].isName)
    }

    @Test
    fun `a word said twice in one entry is one entry`() {
        val es = listOf(
            entry("Garden garden garden.", at(1)),
            entry("Nothing to report.", at(2)),
            entry("Slept early.", at(3)),
        )
        assertTrue(EarlySignals.recurring(es).isEmpty())
    }

    @Test
    fun `whole words only`() {
        // "plant" inside "planted" and "plantation" is not the word "plant".
        val es = listOf(
            entry("Planted the tomatoes.", at(1)),
            entry("Read about a plantation.", at(2)),
            entry("Bought a plant.", at(3)),
        )
        assertTrue(EarlySignals.recurring(es).none { it.word.equals("plant", true) })
    }

    @Test
    fun `names come first and only when the text says them`() {
        val es = listOf(
            entry("Lunch with Priya and the garden club.", at(1), entities = "Priya"),
            entry("Priya's garden is huge.", at(2), entities = "Priya"),
            // The detector named Arjun but the words never say it.
            entry("Phoned home, garden talk.", at(3), entities = "Arjun"),
        )
        val r = EarlySignals.recurring(es)
        assertEquals("Priya", r[0].word)
        assertTrue(r[0].isName)
        assertEquals(2, r[0].entries)
        assertTrue(r.none { it.word == "Arjun" })
        assertEquals("garden", r[1].word)
        assertEquals(3, r[1].entries)
        // A name is never repeated as a plain word.
        assertEquals(1, r.count { it.word.equals("priya", true) })
    }

    @Test
    fun `a name is a whole word too`() {
        val es = listOf(
            entry("Saw Ann today.", at(1), entities = "Ann"),
            entry("Anna called.", at(2), entities = "Anna"),
            entry("Annual review prep.", at(3)),
        )
        assertTrue(EarlySignals.recurring(es).none { it.isName })
    }

    @Test
    fun `glue words and short words are not signals`() {
        val es = List(3) { entry("I think that it was really just a day.", at(1 + it)) }
        assertTrue(EarlySignals.recurring(es).isEmpty())
    }

    @Test
    fun `unspaced scripts are skipped rather than guessed at`() {
        val es = List(3) { entry("今日は公園を散歩しました", at(1 + it)) }
        assertTrue(EarlySignals.recurring(es).isEmpty())
    }

    @Test
    fun `at most three, most entries first`() {
        val es = listOf(
            entry("coffee bread cheese olives", at(1)),
            entry("coffee bread cheese olives", at(2)),
            entry("coffee bread", at(3)),
        )
        val r = EarlySignals.recurring(es)
        assertEquals(3, r.size)
        assertEquals(listOf("bread", "coffee"), r.take(2).map { it.word })
        assertEquals(3, r[0].entries)
    }

    // ── Moods ───────────────────────────────────────────────────────────────

    @Test
    fun `moods the user chose are counted apart from suggestions`() {
        val es = listOf(
            entry("a", at(1), self = "joy", suggested = "sadness"),
            entry("b", at(2), self = "joy"),
            entry("c", at(3), suggested = "fear"),
            entry("d", at(4), self = "sad"),   // legacy word, canon key
        )
        val m = EarlySignals.moods(es)!!
        assertEquals(listOf("joy" to 2, "sadness" to 1), m.chosen)
        // The suggestion on an entry the user labelled is not counted at all.
        assertEquals(listOf("fear" to 1), m.suggested)
    }

    @Test
    fun `no moods at all is no mood line`() {
        assertNull(EarlySignals.moods(List(3) { entry("x", at(1 + it)) }))
    }

    @Test
    fun `nothing about valence or personality is in the signals`() {
        // The shape itself is the guarantee: counts, words and chosen moods.
        val fields = EarlySignals.Signals::class.java.declaredFields.map { it.name }.toSet()
        assertTrue(fields.none { it.contains("valence", true) || it.contains("tone", true) })
    }
}
