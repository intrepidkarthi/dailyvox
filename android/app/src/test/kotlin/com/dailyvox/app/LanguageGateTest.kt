package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.Repo
import com.dailyvox.app.data.toChatEntry
import com.dailyvox.app.system.EarlySignals
import com.dailyvox.app.system.MoodSuggestion
import com.dailyvox.app.system.ReadingLanguage
import com.dailyvox.app.system.Reflection
import com.dailyvox.app.system.Shareables
import com.dailyvox.app.system.Valence
import com.dailyvox.app.ui.screens.askFacts
import com.dailyvox.app.ui.screens.noticedPatterns
import com.dailyvox.twin.ChatEntry
import com.dailyvox.twin.Insights
import com.dailyvox.twin.LanguageFeature
import com.dailyvox.twin.Sentiment
import com.dailyvox.twin.TwinFacts
import com.dailyvox.twin.TwinQuestion
import com.dailyvox.twin.TwinResponseGenerator
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * B-5 and B-9 on Android 1.3: every feature that reads words asks the engine's
 * LanguageGate, about the language in the entry's stored column. In a
 * language a feature cannot read it is QUIET, never wrong. English is
 * unchanged, and the second half of this file proves it.
 */
class LanguageGateTest {

    private val shipped: Map<String, Float> by lazy {
        java.io.File("src/main/assets/vader.txt").useLines { Sentiment.parseLexicon(it) }
    }

    private val day = 86_400_000L
    private val now = 1_790_000_000_000L
    private var seq = 0

    private fun entry(
        text: String,
        valence: Float? = null,
        language: String? = null,
        entities: String = "",
        at: Long = now,
        id: String = "e${seq++}",
    ) = Entry(
        id = id, text = text, createdAt = at, durationSec = 40, valence = valence,
        entities = entities, audioPath = "/a.m4a", language = language,
    )

    private val englishTexts = listOf(
        "I had a really lovely walk with Sarah today and felt happy.",
        "The meeting went badly again and I hate it.",
        "Good and bad, it cancels.",
        "So happy today, we laughed all evening and I feel grateful.",
        "I miss my dad. The house is so quiet and I cried all night.",
        "Tired.",
        "fine",
    )

    // ── Where the language comes from ───────────────────────────────────────

    @Test fun `the stored column is the source`() {
        assertEquals("es-MX", ReadingLanguage.of("es-MX", "Hoy fue un buen día con mi hermana."))
        assertEquals("hi-IN", ReadingLanguage.of("hi-IN", "आज मेरी दादी से बात हुई"))
        assertEquals("en-US", ReadingLanguage.of("en-US", englishTexts[0]))
    }

    @Test fun `with no column, English text reads as English and nothing is asked`() {
        var asked = false
        assertNull(ReadingLanguage.of(null, englishTexts[0]) { asked = true; "fr" })
        assertFalse("an English entry never pays for a classifier call", asked)
    }

    @Test fun `with no column, other text falls back to the classifier, then to quiet`() {
        val spanish = "Hoy fue un día muy triste. Mi abuela murió y no pude estar con ella."
        assertEquals("es", ReadingLanguage.of(null, spanish) { "es" })
        assertEquals(ReadingLanguage.UNREAD, ReadingLanguage.of(null, spanish))
        assertEquals(ReadingLanguage.UNREAD, ReadingLanguage.of(null, spanish) { null })
        // A classifier that calls non-English text English is not believed.
        assertEquals(ReadingLanguage.UNREAD, ReadingLanguage.of(null, spanish) { "en" })
    }

    @Test fun `an entry tagged English whose words are not English is quiet (code-mixed, D5)`() {
        val hinglish = "आज office में बहुत काम था और मैं थक गया"
        assertEquals(ReadingLanguage.UNREAD, ReadingLanguage.of("en-IN", hinglish))
        assertFalse(ReadingLanguage.reads(LanguageFeature.SENTIMENT, "en-IN", hinglish))
    }

    // ── Quiet where the gate says it cannot read ────────────────────────────

    @Test fun `a short Spanish entry the word heuristic misses is caught by its column`() {
        // "sin" is a VADER word (-2.6). Two words are too few for EnglishText,
        // so 1.2.1 scored this; the stored tag now keeps it quiet.
        val text = "Sin dormir"
        assertNotNull("1.2.1's misread, without a column", Valence.of(text, shipped))
        assertNull(Valence.of(text, shipped, "es-MX"))
        assertNull(MoodSuggestion.from("Sin dormir, sin ganas, sin nada", shipped, "es-MX"))
    }

    @Test fun `mood, valence and the reflection tone are quiet for every non-English tag`() {
        val text = "I had a really lovely walk today and felt happy."
        listOf("es", "fr-FR", "de", "it", "pt-BR", "hi-IN", "ta-IN").forEach { tag ->
            assertNull(tag, Valence.of(text, shipped, tag))
            assertNull(tag, MoodSuggestion.from(text, shipped, tag))
            // A number 1.2 stored before the column existed is not used either.
            val e = entry(text, valence = 0.8f, language = tag)
            assertNull(tag, ReadingLanguage.valence(e))
            assertNull(tag, Reflection.of(e, emptyList()).tone)
        }
    }

    @Test fun `the drift baseline leaves out entries the gate cannot read`() {
        val en = "The meeting went badly again and I hate it today."
        val today = entry(en, valence = -0.6f, language = "en")
        // Three bright Spanish-tagged rows would make "heavier than usual".
        val earlier = List(3) { entry("Un día feliz con amigos", 0.9f, "es", at = now - (it + 1) * day) }
        assertNull(Reflection.of(today, earlier).drift)
    }

    @Test fun `German and caseless entries carry no people into the engine`() {
        val de = entry("Heute war die Arbeit schwer. Mutter rief an.", 0.1f, "de", "Arbeit,Mutter")
        val hi = entry("आज मेरी दादी से बात हुई", null, "hi", "दादी")
        val es = entry("Hoy cené con Lucía en el centro.", null, "es", "Lucía")
        assertTrue(de.toChatEntry().entities.isEmpty())
        assertTrue(hi.toChatEntry().entities.isEmpty())
        assertEquals(listOf("Lucía"), es.toChatEntry().entities)
        assertEquals("de", de.toChatEntry().language)
    }

    @Test fun `Insights makes no finding from valences or people the gate cannot read`() {
        // Twelve German entries 1.2 scored and filed: "Arbeit" on four, high.
        val de = List(12) { i ->
            entry("Heute war die Arbeit gut und ich bin froh.", if (i < 4) 0.9f else 0.0f, "de",
                  if (i < 4) "Arbeit" else "", now - i * day)
        }
        assertTrue(noticedPatterns(de).isEmpty())
    }

    @Test fun `Year One ignores names and moods it cannot read`() {
        val de = List(5) { entry("Die Arbeit war schwer.", 0.9f, "de", "Arbeit", now - it * day) }
        val en = List(2) { entry("Dinner with Sarah was lovely.", 0.5f, "en", "Sarah", now - it * day) }
        assertEquals("Sarah", Shareables.brightestStar(de + en)?.key)
        assertNull(Shareables.brightestStar(de))
        // Only German valences: nothing read, so no "Warmest month".
        assertNull(Shareables.warmestMonthIndex(de + de.map { it.copy(id = it.id + "b", valence = -0.5f) }))
    }

    @Test fun `Ask does not answer mood or style from a Spanish journal`() {
        val es = List(10) { entry("Hoy fue un día bueno con mi hermana y mis amigos.", 0.7f, "es", at = now - it * day) }
        val facts = askFacts(es)
        assertFalse(facts.hasEnoughMoodData)
        assertEquals(TwinResponseGenerator.MOOD_UNREAD,
            TwinResponseGenerator.generate(TwinQuestion.POSITIVE_OR_NEGATIVE, facts))
        assertEquals(TwinResponseGenerator.STYLE_UNREAD,
            TwinResponseGenerator.generate(TwinQuestion.PERSONALITY, facts))
    }

    @Test fun `early signals use the entry language's own stopwords`() {
        val es = List(3) {
            entry("Hoy hablé con mi abuela para saber porque estaba triste.", null, "es", at = now - it * day)
        }
        val words = EarlySignals.recurring(es).map { it.word }
        assertTrue(words.toString(), "abuela" in words)
        assertFalse(words.toString(), "para" in words)
        assertFalse(words.toString(), "porque" in words)
        assertFalse(words.toString(), "estaba" in words)
        // A language with no stop list stays out entirely, rather than showing glue.
        val ru = List(3) { entry("Сегодня я говорил с бабушкой", null, "ru", at = now - it * day) }
        assertTrue(EarlySignals.recurring(ru).isEmpty())
    }

    // ── Search (B-9) ────────────────────────────────────────────────────────

    @Test fun `mamá stays whole and Devanagari is searchable`() {
        assertTrue(Repo.rankWords("mamá") == setOf("mamá"))
        val journal = listOf(
            entry("Hoy hablé con mamá por teléfono.", language = "es", id = "es"),
            // The old [a-z] split cut "mamá" to "mam", which prefix-matched this.
            entry("Mamma mia, what a day at the bakery.", language = "en", id = "en"),
            entry("आज दादी से फ़ोन पर बात हुई", language = "hi", id = "hi"),
        )
        assertEquals(listOf("es"), Repo.searchResults("mamá", journal).map { it.id })
        assertEquals(listOf("hi"), Repo.searchResults("दादी", journal).map { it.id })
        // A decomposed "á" (a + combining acute) finds the precomposed one.
        assertEquals(listOf("es"), Repo.searchResults("mamá", journal).map { it.id })
    }

    @Test fun `search still finds entries from before the column`() {
        val old = entry("Dinner with Priya by the river", id = "old")
        assertEquals(listOf("old"), Repo.searchResults("river", listOf(old)).map { it.id })
    }

    // ── English is unchanged ────────────────────────────────────────────────

    @Test fun `English valence and mood suggestion are identical tagged or untagged`() {
        englishTexts.forEach { t ->
            val before = Valence.of(t, shipped)
            assertEquals(t, before, Valence.of(t, shipped, "en-US"))
            assertEquals(t, before, Valence.of(t, shipped, "en"))
            // And it is still exactly the engine's score where the lexicon read a word.
            before?.let { assertEquals(t, Sentiment.valence(t, shipped), it, 0f) }
            assertEquals(t, MoodSuggestion.from(t, shipped), MoodSuggestion.from(t, shipped, "en-US"))
        }
    }

    @Test fun `English reflection is identical tagged or untagged`() {
        englishTexts.forEachIndexed { i, t ->
            val v = Valence.of(t, shipped)
            val earlier = List(4) { entry(englishTexts[it], Valence.of(englishTexts[it], shipped), at = now - (it + 1) * day) }
            val untagged = Reflection.of(entry(t, v), earlier)
            val tagged = Reflection.of(entry(t, v, "en-GB"), earlier.map { it.copy(language = "en") })
            assertEquals("$i tone", untagged.tone, tagged.tone)
            assertEquals("$i drift", untagged.drift, tagged.drift)
        }
    }

    @Test fun `English Insights match 1_2_1's exactly`() {
        val en = List(12) { i ->
            val sarah = i % 3 == 0
            entry(if (sarah) "Dinner with Sarah was lovely." else "Work was long and dull today.",
                  if (sarah) 0.8f else 0.0f, if (i % 2 == 0) "en-US" else null,
                  if (sarah) "Sarah" else "", now - i * day)
        }
        // 1.2.1's mapping: read valences only, null coerced to 0, no language.
        val before = Insights.find(en.filter { it.valence != null }.map {
            ChatEntry(it.id, it.createdAt, it.text, it.valence ?: 0f, it.entityList,
                      it.sleepHours, it.hourOfDay, it.dayOfWeek, it.stepsToday, it.speakingRate)
        })
        assertTrue("the fixture must produce a finding", before.any { it.lead == "Sarah lifts you." })
        assertEquals(before, noticedPatterns(en))
    }

    @Test fun `English Ask answers match 1_2_1's exactly`() {
        val en = List(12) { i ->
            entry(englishTexts[i % 5], Valence.of(englishTexts[i % 5], shipped) ?: 0.1f,
                  if (i % 2 == 0) "en" else null, if (i % 3 == 0) "Sarah" else "", now - i * day)
        }
        val before = TwinFacts.from(en.map {
            ChatEntry(it.id, it.createdAt, it.text, it.valence!!, it.entityList,
                      it.sleepHours, it.hourOfDay, it.dayOfWeek, it.stepsToday, it.speakingRate)
        })
        val after = askFacts(en)
        assertEquals(TwinQuestion.available(before), TwinQuestion.available(after))
        TwinQuestion.values().forEach { q ->
            assertEquals(q.name, TwinResponseGenerator.generate(q, before), TwinResponseGenerator.generate(q, after))
        }
    }

    @Test fun `English early signals and Year One are unchanged by an English tag`() {
        val texts = listOf(
            "Dinner with Sarah, then a long walk by the river.",
            "Another river walk after work with Sarah.",
            "Coffee with Sarah before work, river was high.",
        )
        val untagged = texts.mapIndexed { i, t -> entry(t, 0.3f * i, null, "Sarah", now - i * day, "u$i") }
        val tagged = untagged.map { it.copy(language = "en-US") }
        assertEquals(EarlySignals.recurring(untagged), EarlySignals.recurring(tagged))
        assertTrue(EarlySignals.recurring(untagged).any { it.word == "Sarah" && it.isName })
        assertEquals(Shareables.brightestStar(untagged), Shareables.brightestStar(tagged))
        assertEquals(Shareables.warmestMonthIndex(untagged), Shareables.warmestMonthIndex(tagged))
    }
}
