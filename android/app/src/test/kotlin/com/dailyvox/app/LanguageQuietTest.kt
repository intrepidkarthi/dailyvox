package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.Repo
import com.dailyvox.app.system.EnglishText
import com.dailyvox.app.system.MoodSuggestion
import com.dailyvox.app.system.Reflection
import com.dailyvox.app.system.Shareables
import com.dailyvox.app.system.Valence
import com.dailyvox.twin.Sentiment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * A0-3 and the MoodSuggestion gate. In a language the English lexicon cannot
 * read, valence is absent (null), not neutral (0), and nothing downstream turns
 * that absence into a finding. English is scored exactly as before.
 */
class LanguageQuietTest {

    private val shipped: Map<String, Float> by lazy {
        java.io.File("src/main/assets/vader.txt").useLines { Sentiment.parseLexicon(it) }
    }

    private val hindi = "आज मेरी दादी का देहांत हो गया। मैं बहुत रोया और पूरा दिन घर पर रहा।"
    private val spanish = "Hoy fue un día muy triste. Mi abuela murió y no pude estar con ella, " +
        "pero la familia estaba en paz y todo fue tranquilo."
    private val german = "Heute war ich sehr müde und traurig. Die Arbeit war schwer und ich bin allein."
    private val italian = "Oggi sono molto triste, mia nonna non sta bene e ho pianto tutto il giorno."
    private val english = "I had a really lovely walk with Sarah today and felt happy."

    // ---- EnglishText ----

    @Test fun `English reads as English, short or long`() {
        assertTrue(EnglishText.likely(english))
        assertTrue(EnglishText.likely("fine"))
        assertTrue(EnglishText.likely("Tired."))
        assertTrue(EnglishText.likely(""))
        // A borrowed phrase does not flip a whole English entry.
        assertTrue(EnglishText.likely("I told my mother c'est la vie and we laughed about it."))
        assertTrue(EnglishText.likely("Went to the café with Zoë and had a croissant."))
    }

    @Test fun `other languages do not read as English`() {
        listOf(hindi, spanish, german, italian,
            "Je suis très fatigué aujourd'hui et je n'ai rien fait.",
            "Hoje eu estou muito cansado e não fiz nada.",
            "இன்று நான் மிகவும் சோர்வாக இருந்தேன்").forEach {
            assertFalse("read as English: $it", EnglishText.likely(it))
        }
    }

    // ---- Valence ----

    @Test fun `English valence is exactly the engine's score`() {
        listOf(english, "The meeting went badly again and I hate it.", "Good and bad, it cancels.")
            .forEach { assertEquals(Sentiment.valence(it, shipped), Valence.of(it, shipped)) }
    }

    @Test fun `no lexicon word means no valence, not zero`() {
        assertNull(Valence.of("Went to the shop and back.", shipped))
        assertNull(Valence.of("", shipped))
    }

    @Test fun `non-English text has no valence even where false friends score`() {
        // The engine DOES score these -- that is the bug. German "war" and
        // "die" read as -0.91 on an entry about being tired.
        assertTrue(Sentiment.valence(german, shipped) < -0.5f)
        assertTrue(Sentiment.valence(frenchGrief, shipped) > 0.5f)
        listOf(hindi, spanish, german, italian, frenchGrief).forEach {
            assertNull("scored: $it", Valence.of(it, shipped))
        }
    }

    /** "My grandmother died today. She was super, truly adorable. I am sad." */
    private val frenchGrief = "Ma grand-mère est morte aujourd'hui. Elle était super, vraiment adorable. Je suis triste."

    // ---- MoodSuggestion ----

    @Test fun `English suggestions are unchanged`() {
        assertEquals("joy", MoodSuggestion.from(
            "Today was wonderful, we laughed all afternoon and I felt so happy.", shipped))
    }

    @Test fun `non-English entries are never suggested a mood`() {
        // Before the gate this grief entry leaned strongly positive on "super"
        // and "adorable" with nothing scored against it: "Reads like Joy".
        assertEquals(1, MoodSuggestion.lean(Sentiment.valence(frenchGrief, shipped), MoodSuggestion.words(frenchGrief)))
        listOf(hindi, spanish, german, italian, frenchGrief,
            "Minha avó morreu hoje. Ela era super legal, a melhor. Estou triste demais.",
            ).forEach { assertNull("suggested for: $it", MoodSuggestion.from(it, shipped)) }
    }

    // ---- Reflection tone and drift ----

    private val day = 86_400_000L
    private val now = 1_790_000_000_000L
    private fun entry(text: String, v: Float?, at: Long = now, id: String = "new") =
        Entry(id = id, text = text, createdAt = at, durationSec = 40, valence = v, audioPath = "/a.m4a")

    @Test fun `an unread entry gets no tone and no drift`() {
        val history = List(4) { entry("a heavy day at work again", -0.6f, now - (it + 1) * day, "h$it") }
        val card = Reflection.of(entry(hindi, null), history)
        assertNull(card.tone)
        assertNull(card.drift)
    }

    @Test fun `unread history is left out of the drift baseline, not averaged as zero`() {
        val unread = List(5) { entry(hindi, null, now - (it + 1) * day, "u$it") }
        // Only unread history: too little to compare against.
        assertNull(Reflection.of(entry("a really good walk today", 0.6f), unread).drift)
        val read = List(3) { entry("a really good walk", 0.6f, now - (it + 1) * day, "r$it") }
        // With read history at the same level, the unread zeros would have made it LIGHTER.
        assertEquals(Reflection.Drift.SIMILAR,
            Reflection.of(entry("a really good walk today", 0.6f), read + unread).drift)
    }

    @Test fun `English tone is unchanged`() {
        assertEquals(Reflection.Tone.EVEN, Reflection.of(entry("went to the shop and back", 0f), emptyList()).tone)
        assertEquals(Reflection.Tone.LIGHT, Reflection.of(entry("a really good walk today", 0.6f), emptyList()).tone)
    }

    // ---- Year One warmest month ----

    private fun at(month: Int, d: Int): Long = java.util.Calendar.getInstance().apply {
        clear(); set(2025, month, d, 12, 0)
    }.timeInMillis

    @Test fun `warmest month is absent for a journal the lexicon could not read`() {
        val entries = (0..2).flatMap { m -> List(4) { entry(hindi, null, at(m, it + 1), "e$m$it") } }
        assertNull(Shareables.warmestMonthIndex(entries))
    }

    @Test fun `warmest month is absent when valence does not vary`() {
        val entries = (0..2).flatMap { m -> List(4) { entry("ok", 0f, at(m, it + 1), "e$m$it") } }
        assertNull(Shareables.warmestMonthIndex(entries))
    }

    @Test fun `warmest month still names the warm month in English`() {
        val entries = (0..2).flatMap { m ->
            List(4) { entry("x", if (m == 1) 0.7f else 0.1f, at(m, it + 1), "e$m$it") }
        } + List(4) { entry(hindi, null, at(3, it + 1), "h$it") }
        assertEquals(1, Shareables.warmestMonthIndex(entries))
    }

    // ---- the one-time clear of stored zeros ----

    @Test fun `stored zeros the lexicon never read are cleared, real zeros stay`() {
        val rows = listOf(
            entry(hindi, 0f, id = "hi"),
            entry("Went to the shop and back.", 0f, id = "plain"),
            // A zero the lexicon DID read is a number, not an absence: it stays.
            entry("a really good walk", 0f, id = "readzero"),
            entry(english, 0.6f, id = "en"),
        )
        val cleared = Repo.unreadValence(rows, shipped)
        assertEquals(setOf("hi", "plain"), cleared.map { it.id }.toSet())
        assertTrue(cleared.all { it.valence == null })
    }
}
