package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Reflection
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The card shown after an entry is saved. The rule under test is grounding:
 * every line must trace to the entry's own words, and a line with nothing
 * under it must be null rather than filled with something plausible.
 */
class ReflectionTest {

    private val day = 86_400_000L
    private val now = 1_790_000_000_000L

    private fun entry(
        text: String,
        valence: Float = 0f,
        entities: String = "",
        at: Long = now,
        id: String = "new",
        seconds: Int = 40,
        audio: String? = "/a.m4a",
    ) = Entry(
        id = id, text = text, createdAt = at, durationSec = seconds,
        valence = valence, entities = entities, audioPath = audio,
    )

    @Test
    fun `tone follows the entry's own valence`() {
        assertEquals(Reflection.Tone.LIGHT,
            Reflection.of(entry("a really good walk today", 0.6f), emptyList()).tone)
        assertEquals(Reflection.Tone.HEAVY,
            Reflection.of(entry("the meeting went badly again", -0.5f), emptyList()).tone)
        assertEquals(Reflection.Tone.EVEN,
            Reflection.of(entry("went to the shop and back", 0.0f), emptyList()).tone)
    }

    @Test
    fun `too few words, no tone claimed`() {
        assertNull(Reflection.of(entry("fine", 0.4f), emptyList()).tone)
    }

    @Test
    fun `an untranscribed entry says only that the voice is saved`() {
        val card = Reflection.of(entry("", 0f, seconds = 30), emptyList())
        assertTrue(card.wordless)
        assertNull(card.tone); assertNull(card.drift)
        assertNull(card.person); assertNull(card.tomorrow)
    }

    @Test
    fun `no comparison without enough recent entries`() {
        val two = listOf(
            entry("an ordinary sort of day", -0.2f, at = now - day, id = "a"),
            entry("an ordinary sort of day", -0.2f, at = now - 2 * day, id = "b"),
        )
        assertNull(Reflection.of(entry("a lovely bright morning out", 0.7f), two).drift)
    }

    @Test
    fun `lighter and heavier are measured against the last few entries`() {
        val recent = (1..4).map { entry("an ordinary sort of day", 0f, at = now - it * day, id = "r$it") }
        assertEquals(Reflection.Drift.LIGHTER,
            Reflection.of(entry("a lovely bright morning out", 0.7f), recent).drift)
        assertEquals(Reflection.Drift.HEAVIER,
            Reflection.of(entry("it was a hard and sad day", -0.6f), recent).drift)
        assertEquals(Reflection.Drift.SIMILAR,
            Reflection.of(entry("nothing much happened at work", 0.05f), recent).drift)
    }

    @Test
    fun `entries older than two weeks are not the recent average`() {
        val old = (20..24).map { entry("an ordinary sort of day", 0f, at = now - it * day, id = "o$it") }
        assertNull(Reflection.of(entry("a lovely bright morning out", 0.7f), old).drift)
    }

    @Test
    fun `a person is named only when the text says them`() {
        val said = Reflection.of(entry("coffee with Sarah after work", 0.3f, entities = "Sarah"), emptyList())
        assertEquals("Sarah", said.person)

        // The detector's list and the text disagree: show nothing rather than
        // a name the user did not say.
        val notSaid = Reflection.of(entry("coffee after work", 0.3f, entities = "Sarah"), emptyList())
        assertNull(notSaid.person)
    }

    @Test
    fun `earlier mentions count the last month only, and not this entry`() {
        val others = listOf(
            entry("Sarah called", 0f, entities = "Sarah", at = now - 3 * day, id = "a"),
            entry("lunch with Sarah", 0f, entities = "Sarah", at = now - 10 * day, id = "b"),
            entry("Sarah again", 0f, entities = "Sarah", at = now - 45 * day, id = "c"),
            entry("quiet day alone", 0f, at = now - 2 * day, id = "d"),
        )
        val saved = entry("coffee with Sarah after work", 0.3f, entities = "Sarah")
        assertEquals(2, Reflection.of(saved, others + saved).personEarlier)
    }

    @Test
    fun `a name is matched as a whole word, never inside another word`() {
        // "Ann" is not in "Annual review", so the card names nobody.
        val inside = Reflection.of(entry("Annual review went fine", 0.3f, entities = "Ann"), emptyList())
        assertNull(inside.person)

        val others = listOf(
            entry("prepping the Annual review deck", 0f, at = now - 2 * day, id = "a"),
            entry("bought a Samsung charger", 0f, at = now - 3 * day, id = "b"),
            entry("Ann's birthday dinner", 0f, at = now - 4 * day, id = "c"),
        )
        val saved = entry("long call with Ann tonight", 0.3f, entities = "Ann")
        val card = Reflection.of(saved, others + saved)
        assertEquals("Ann", card.person)
        assertEquals(1, card.personEarlier)
    }

    @Test
    fun `the for-tomorrow line is the user's own sentence or nothing`() {
        val card = Reflection.of(
            entry("Long day. The interview is tomorrow at ten. I feel ready.", 0.2f), emptyList())
        assertEquals("The interview is tomorrow at ten.", card.tomorrow)

        assertNull(Reflection.of(entry("Long day at work and then dinner.", 0.2f), emptyList()).tomorrow)
        // Whole word only.
        assertNull(Reflection.tomorrowSentence("Played Tomorrows on repeat."))
    }

    @Test
    fun `a long sentence is quoted around the word, never without it`() {
        val filler = "and then ".repeat(30)
        val quote = Reflection.tomorrowSentence("I walked $filler finally I will call mum tomorrow morning.")!!
        assertTrue(quote.contains("tomorrow"))
        assertTrue(quote.length <= 142)
        assertTrue(quote.startsWith("…"))
    }

    @Test
    fun `a typed entry is labelled typed`() {
        val card = Reflection.of(entry("typed this at my desk", 0f, seconds = 0, audio = null), emptyList())
        assertTrue(card.typed)
        assertEquals(5, card.words)
    }

    /** A0-7. A combining mark after the name means the word goes on. */
    @Test
    fun `a name followed by a combining mark is inside a longer word`() {
        // "प्रिय" then the vowel sign "ा" (U+093E, a mark) is "प्रिया", another word.
        assertFalse(Reflection.nameIn("प्रिय", "आज प्रिया से मिला"))
        assertTrue(Reflection.nameIn("प्रिया", "आज प्रिया से मिला"))
        // Decomposed accent: "Ana" + U+0301 is "Aná", not "Ana".
        assertFalse(Reflection.nameIn("Ana", "Vi a Aná hoy"))
        assertTrue(Reflection.nameIn("Ana", "Vi a Ana hoy"))
    }

    @Test
    fun `English whole-word matching is unchanged`() {
        assertTrue(Reflection.nameIn("Sarah", "Lunch with Sarah's sister."))
        assertTrue(Reflection.nameIn("Sarah", "Sarah, then home."))
        assertFalse(Reflection.nameIn("Sam", "My new Samsung arrived."))
        assertFalse(Reflection.nameIn("Ann", "Annual review"))
    }
}
