package com.dailyvox.app

import com.dailyvox.app.system.LocaleFormat
import com.dailyvox.app.ui.components.Directional
import java.text.SimpleDateFormat
import java.time.LocalDate
import java.time.Month
import java.time.ZoneId
import java.util.Calendar
import java.util.Date
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Test

/**
 * B-13 and B-16. Two halves, both pinned: other languages get their own date
 * shapes and capitals, and English prints byte-for-byte what 1.2 printed.
 */
class LocaleFormatTest {

    private val englishLocales = listOf(Locale.US, Locale.UK, Locale.forLanguageTag("en-IN"), Locale.forLanguageTag("en-AU"))

    private fun everyDayOf(year: Int) = generateSequence(LocalDate.of(year, 1, 1)) { it.plusDays(1) }
        .takeWhile { it.year == year }

    @Test
    fun `English receipt date is exactly 1_2's, every day of the year`() {
        everyDayOf(2026).forEach { d ->
            val old = SimpleDateFormat("MMMM d, yyyy", Locale.US)
                .format(Date.from(d.atStartOfDay(ZoneId.systemDefault()).toInstant())).uppercase()
            englishLocales.forEach { loc -> assertEquals("$d $loc", old, LocaleFormat.receiptDate(d, loc)) }
        }
    }

    @Test
    fun `English warmest month is exactly 1_2's`() {
        (0..11).forEach { m ->
            val old = SimpleDateFormat("MMMM", Locale.US).format(
                Calendar.getInstance().apply { set(Calendar.DAY_OF_MONTH, 1); set(Calendar.MONTH, m) }.time)
            englishLocales.forEach { loc -> assertEquals(old, LocaleFormat.monthName(m, loc)) }
        }
    }

    @Test
    fun `other languages get their own month, not English`() {
        assertEquals("Oktober", LocaleFormat.monthName(Month.OCTOBER, Locale.GERMANY))
        // Lower-case in Spanish and French; a heading on a card, so capitalised.
        assertEquals("Octubre", LocaleFormat.monthName(Month.OCTOBER, Locale.forLanguageTag("es-ES")))
        assertEquals("Octobre", LocaleFormat.monthName(Month.OCTOBER, Locale.FRANCE))
        assertNotEquals("October", LocaleFormat.monthName(Month.OCTOBER, Locale.forLanguageTag("hi-IN")))
    }

    @Test
    fun `other languages get the platform's date order on the receipt`() {
        val d = LocalDate.of(2026, 10, 26)
        val de = LocaleFormat.receiptDate(d, Locale.GERMANY)
        assertEquals(true, de.startsWith("26.")); assertEquals(true, de.contains("OKTOBER"))
        assertEquals(true, LocaleFormat.receiptDate(d, Locale.FRANCE).contains("OCTOBRE"))
    }

    @Test
    fun `capitals follow the reader's language and are unchanged for English`() {
        listOf("today · 9:41 PM · 12 words", "Priya", "not transcribed", "MAMÁ").forEach {
            englishLocales.forEach { loc -> assertEquals(it.uppercase(), LocaleFormat.upper(it, loc)) }
        }
        assertEquals("İSTANBUL", LocaleFormat.upper("istanbul", Locale.forLanguageTag("tr-TR")))
        assertEquals("ISTANBUL", "istanbul".uppercase())
    }

    @Test
    fun `English keeps its patterns, other languages ask the platform`() {
        val asked = mutableListOf<Pair<Locale, String>>()
        val best: (Locale, String) -> String = { l, s -> asked += l to s; "HH:mm" }
        englishLocales.forEach { assertEquals("h:mm a", LocaleFormat.pattern("h:mm a", "jmm", it, best)) }
        assertEquals(emptyList<Pair<Locale, String>>(), asked)
        assertEquals("HH:mm", LocaleFormat.pattern("h:mm a", "jmm", Locale.GERMANY, best))
        assertEquals(listOf(Locale.GERMANY to "jmm"), asked)
        // A platform that cannot answer falls back to the old pattern, never crashes.
        assertEquals("h:mm a", LocaleFormat.pattern("h:mm a", "jmm", Locale.GERMANY) { _, _ -> error("no") })
    }

    @Test
    fun `chevrons point the right way, and LTR is 1_2's glyphs`() {
        assertEquals("‹", Directional.back(rtl = false))
        assertEquals("›", Directional.forward(rtl = false))
        assertEquals("›", Directional.back(rtl = true))
        assertEquals("‹", Directional.forward(rtl = true))
    }
}
