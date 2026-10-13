package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Resurface
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import java.time.DayOfWeek
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId

/**
 * The past, brought back. Two rules carry the weight: every line is the
 * user's own words, cut only at a boundary, and every "when" is the user's
 * local calendar, including the dates calendars make awkward.
 */
class ResurfaceTest {

    private val la = ZoneId.of("America/Los_Angeles")
    private val tokyo = ZoneId.of("Asia/Tokyo")
    private var seq = 0

    private fun at(y: Int, m: Int, d: Int, h: Int = 21, zone: ZoneId = la): Long =
        LocalDateTime.of(y, m, d, h, 0).atZone(zone).toInstant().toEpochMilli()

    private fun entry(
        text: String,
        at: Long,
        entities: String = "",
        audio: String? = "/a.m4a",
        id: String = "e${seq++}",
    ) = Entry(id = id, text = text, createdAt = at, durationSec = 40,
              valence = 0f, entities = entities, audioPath = audio)

    private val said = "Walked to the river with Sarah after work."

    // ── Week ago ────────────────────────────────────────────────────────────

    @Test
    fun `week ago quotes the entry from seven local days back`() {
        val e = entry(said, at(2026, 10, 6))
        val m = Resurface.weekAgo(listOf(e), at(2026, 10, 13, 9), la)!!
        assertEquals(e.id, m.entry.id)
        assertEquals(said, m.excerpt)
        assertEquals(Resurface.Span.DAYS, m.span)
        assertEquals(7, m.ago)
    }

    @Test
    fun `week ago falls back to six then eight days and says so`() {
        val six = entry(said, at(2026, 10, 7))
        val eight = entry("The train was late again this morning.", at(2026, 10, 5))
        val now = at(2026, 10, 13, 9)
        assertEquals(6, Resurface.weekAgo(listOf(six, eight), now, la)!!.ago)
        assertEquals(8, Resurface.weekAgo(listOf(eight), now, la)!!.ago)
        assertNull(Resurface.weekAgo(listOf(entry(said, at(2026, 10, 3))), now, la))
    }

    @Test
    fun `week ago is hidden when there is nothing`() {
        assertNull(Resurface.weekAgo(emptyList(), at(2026, 10, 13), la))
    }

    @Test
    fun `local day decides, not the UTC day`() {
        // 11pm in Los Angeles on the 6th is already the 7th in UTC. Divided by
        // 86.4 million it would be six days back, not seven.
        val late = entry(said, at(2026, 10, 6, 23))
        val m = Resurface.weekAgo(listOf(late), at(2026, 10, 13, 8), la)!!
        assertEquals(7, m.ago)
        // The same instant, read in Tokyo, is the 7th: six days back there.
        assertEquals(6, Resurface.weekAgo(listOf(late), at(2026, 10, 13, 20, tokyo), tokyo)!!.ago)
    }

    @Test
    fun `untranscribed, blank and very short entries are skipped`() {
        val now = at(2026, 10, 13)
        val day = at(2026, 10, 6)
        val list = listOf(
            entry("", day),                       // audio, no words
            entry("   ", day, audio = null),
            entry("ok fine", day),
        )
        assertNull(Resurface.weekAgo(list, now, la))
    }

    @Test
    fun `a deleted entry is never shown`() {
        val keep = entry("The quiet one I kept for myself today.", at(2026, 10, 6, 8))
        val gone = entry("A much longer entry that was later deleted by the person who said it.", at(2026, 10, 6, 20))
        val now = at(2026, 10, 13)
        assertEquals(gone.id, Resurface.weekAgo(listOf(keep, gone), now, la)!!.entry.id)
        // Deleting removes it from the table, and the selection runs over the table.
        assertEquals(keep.id, Resurface.weekAgo(listOf(keep), now, la)!!.entry.id)
    }

    // ── On this day ─────────────────────────────────────────────────────────

    @Test
    fun `on this day finds a month and a year back`() {
        val month = entry(said, at(2026, 9, 13))
        val year = entry("First night in the new flat, boxes everywhere.", at(2025, 10, 13))
        val found = Resurface.onThisDay(listOf(year, month), at(2026, 10, 13), la)
        assertEquals(listOf(Resurface.Span.MONTHS to 1, Resurface.Span.YEARS to 1),
                     found.map { it.span to it.ago })
    }

    @Test
    fun `month end is skipped, not clamped`() {
        val feb28 = entry(said, at(2026, 2, 28))
        // 31 March: a month back is a date February does not have.
        assertTrue(Resurface.onThisDay(listOf(feb28), at(2026, 3, 31), la).isEmpty())
        assertTrue(Resurface.onThisDay(listOf(feb28), at(2026, 3, 30), la).isEmpty())
        assertEquals(1, Resurface.onThisDay(listOf(feb28), at(2026, 3, 28), la).size)
    }

    @Test
    fun `leap day comes back on the 28th in a year without one`() {
        val leap = entry(said, at(2024, 2, 29))
        val found = Resurface.onThisDay(listOf(leap), at(2025, 2, 28), la)
        assertEquals(1, found.size)
        assertEquals(Resurface.Span.YEARS to 1, found[0].span to found[0].ago)
        // And on its own date four years on, not on 1 March.
        assertEquals(4, Resurface.onThisDay(listOf(leap), at(2028, 2, 29), la).single().ago)
        assertTrue(Resurface.onThisDay(listOf(leap), at(2025, 3, 1), la).isEmpty())
    }

    @Test
    fun `a leap day today does not borrow the 28th from other years`() {
        val feb28 = entry(said, at(2027, 2, 28))
        assertTrue(Resurface.onThisDay(listOf(feb28), at(2028, 2, 29), la).isEmpty())
    }

    @Test
    fun `on this day reaches back years and caps the cards`() {
        val list = (1..6).map { entry("Entry number $it from long ago, kept.", at(2026 - it, 10, 13)) }
        val found = Resurface.onThisDay(list, at(2026, 10, 13), la)
        assertEquals(Resurface.ON_THIS_DAY_MAX, found.size)
        assertEquals(listOf(1, 2, 3), found.map { it.ago })
    }

    // ── Recap ───────────────────────────────────────────────────────────────

    @Test
    fun `recap day follows the locale's first day of the week`() {
        val sunday = LocalDate.of(2026, 10, 11)
        assertTrue(Resurface.isRecapDay(sunday, DayOfWeek.SUNDAY))
        assertFalse(Resurface.isRecapDay(sunday, DayOfWeek.MONDAY))
        assertEquals(LocalDate.of(2026, 10, 4), Resurface.lastWeekStart(sunday, DayOfWeek.SUNDAY))
        assertEquals(LocalDate.of(2026, 9, 28), Resurface.lastWeekStart(sunday, DayOfWeek.MONDAY))
        assertEquals(LocalDate.of(2026, 10, 5),
                     Resurface.lastWeekStart(LocalDate.of(2026, 10, 12), DayOfWeek.MONDAY))
    }

    @Test
    fun `first day of the week comes from the locale, else Sunday`() {
        assertEquals(DayOfWeek.SUNDAY, Resurface.firstDayOfWeek(java.util.Locale.US))
        assertEquals(DayOfWeek.MONDAY, Resurface.firstDayOfWeek(java.util.Locale.GERMANY))
        assertEquals(DayOfWeek.SUNDAY, Resurface.firstDayOfWeek(java.util.Locale.ENGLISH))
    }

    @Test
    fun `recap counts entries and days from the entries themselves`() {
        val from = LocalDate.of(2026, 10, 4)
        val list = listOf(
            entry("Sarah came over and we cooked dinner together.", at(2026, 10, 4), "Sarah"),
            entry("Short call with Sarah about the weekend plans.", at(2026, 10, 4, 22), "Sarah"),
            entry("Long day at the office, nothing much to say really.", at(2026, 10, 7), "Office"),
            entry("", at(2026, 10, 9)),                                   // still an entry
            entry("Outside the week entirely, Sarah again.", at(2026, 10, 11), "Sarah"),
        )
        val r = Resurface.recap(list, from, la)!!
        assertEquals(4, r.entries)
        assertEquals(3, r.daysSpoken)
        assertEquals("Sarah", r.name)
        assertEquals(2, r.nameEntries)
        assertNotNull(r.line)
    }

    @Test
    fun `a name said once is not the week's headline`() {
        val from = LocalDate.of(2026, 10, 4)
        val list = listOf(
            entry("Lunch with Priya near the station today.", at(2026, 10, 5), "Priya"),
            entry("Quiet evening, read a book and slept early.", at(2026, 10, 6)),
        )
        val r = Resurface.recap(list, from, la)!!
        assertNull(r.name)
        assertEquals(0, r.nameEntries)
    }

    @Test
    fun `a detected name the text never says is not counted`() {
        val from = LocalDate.of(2026, 10, 4)
        val list = listOf(
            entry("Went for a run along the canal path.", at(2026, 10, 5), "Sam"),
            entry("Another run, the Samsung watch died halfway.", at(2026, 10, 6), "Sam"),
        )
        assertNull(Resurface.recap(list, from, la)!!.name)
    }

    @Test
    fun `an empty week has no recap`() {
        assertNull(Resurface.recap(emptyList(), LocalDate.of(2026, 10, 4), la))
        val elsewhere = listOf(entry(said, at(2026, 9, 1)))
        assertNull(Resurface.recap(elsewhere, LocalDate.of(2026, 10, 4), la))
    }

    // ── Excerpts ────────────────────────────────────────────────────────────

    @Test
    fun `excerpt stops at a sentence boundary once it reads as a line`() {
        val text = "I finally told Sarah about the job. She laughed, then hugged me. We stayed up late."
        assertEquals("I finally told Sarah about the job.", Resurface.excerpt(text))
    }

    @Test
    fun `excerpt joins short sentences while they fit`() {
        assertEquals("Tired. Good tired, though.", Resurface.excerpt("Tired. Good tired, though."))
    }

    @Test
    fun `excerpt is verbatim, only trimmed`() {
        val text = "  the light   was strange today, almost green  "
        assertEquals("the light   was strange today, almost green", Resurface.excerpt(text))
    }

    @Test
    fun `an overlong sentence is cut at a word and marked`() {
        val text = ("word ".repeat(60)).trim() + "."
        val ex = Resurface.excerpt(text)!!
        assertTrue(ex.endsWith("…"))
        assertTrue(ex.length <= Resurface.EXCERPT_MAX)
        assertTrue(text.startsWith(ex.removeSuffix("…")))
        assertFalse(ex.removeSuffix("…").endsWith(" "))
    }

    @Test
    fun `an excerpt never runs on past a paragraph`() {
        assertEquals("Tired.", Resurface.excerpt("Tired.\nGood tired, though."))
    }

    @Test
    fun `a newline ends a sentence`() {
        assertEquals("Grocery list done", Resurface.excerpt("Grocery list done\nthen the long walk home by the sea"))
    }

    @Test
    fun `emoji are never split`() {
        val family = "👩‍👩‍👧"   // 👩‍👩‍👧
        val text = family.repeat(40)
        val ex = Resurface.excerpt(text)!!.removeSuffix("…")
        assertTrue(ex.isNotEmpty())
        assertEquals(0, ex.length % family.length)
        assertTrue(text.startsWith(ex))
        // No lone surrogate anywhere.
        ex.forEachIndexed { i, c ->
            if (Character.isHighSurrogate(c)) assertTrue(Character.isLowSurrogate(ex[i + 1]))
        }
    }

    @Test
    fun `emoji inside a sentence survive whole`() {
        assertEquals("Best day 🎉 with the kids at the beach.",
                     Resurface.excerpt("Best day 🎉 with the kids at the beach. Sunburnt now."))
    }

    @Test
    fun `right-to-left text keeps its own terminators`() {
        val arabic = "كان يومًا طويلًا في العمل وأنا متعب جدًا؟ لكن العشاء مع العائلة كان جميلًا."
        assertEquals("كان يومًا طويلًا في العمل وأنا متعب جدًا؟", Resurface.sentences(arabic).first())
        assertTrue(arabic.startsWith(Resurface.excerpt(arabic)!!))
        val hebrew = "היום הלכתי לים עם אמא שלי והיה נפלא באמת. אחר כך ישנו."
        assertEquals("היום הלכתי לים עם אמא שלי והיה נפלא באמת.", Resurface.sentences(hebrew).first())
        assertTrue(hebrew.startsWith(Resurface.excerpt(hebrew)!!))
    }

    @Test
    fun `scripts without spaces split on their own marks and cut on characters`() {
        val ja = "今日は友達と海に行ってとても楽しかったです。夜は早く寝ました。"
        assertEquals("今日は友達と海に行ってとても楽しかったです。夜は早く寝ました。", Resurface.excerpt(ja))
        val long = "あ".repeat(200)
        val ex = Resurface.excerpt(long)!!
        assertTrue(ex.endsWith("…"))
        assertTrue(ex.length <= Resurface.EXCERPT_MAX)
    }

    @Test
    fun `closing quotes stay with their sentence`() {
        assertEquals("She said “not tonight.”", Resurface.sentences("She said “not tonight.” I agreed.").first())
    }

    @Test
    fun `nothing to quote is null`() {
        assertNull(Resurface.excerpt(""))
        assertNull(Resurface.excerpt("   \n  "))
    }
}
