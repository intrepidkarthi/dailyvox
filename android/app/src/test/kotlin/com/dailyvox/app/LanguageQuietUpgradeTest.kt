package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.Repo
import com.dailyvox.app.system.Reflection
import com.dailyvox.app.system.Valence
import com.dailyvox.app.ui.screens.askFacts
import com.dailyvox.twin.ChatEntry
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
 * The two places LanguageQuietTest did not reach: moods 1.2 already saved on a
 * phone (the upgrade), and Ask your Twin, which builds its own aggregate.
 */
class LanguageQuietUpgradeTest {

    private val shipped: Map<String, Float> by lazy {
        java.io.File("src/main/assets/vader.txt").useLines { Sentiment.parseLexicon(it) }
    }

    private val hindi = "आज मेरी दादी का देहांत हो गया। मैं बहुत रोया और पूरा दिन घर पर रहा।"
    private val german = "Heute war ich sehr müde und traurig. Die Arbeit war schwer und ich bin allein."
    private val french = "Ma grand-mère est morte ce matin. Je suis très triste et je pleure."
    private val spanish = "Hoy fue un día muy triste. Mi abuela murió y no pude estar con ella."
    private val english = "I had a really lovely walk with Sarah today and felt happy."
    private val englishLow = "The meeting went badly again and I hate it."

    private val day = 86_400_000L
    private val now = 1_790_000_000_000L
    private fun entry(text: String, v: Float?, at: Long = now, id: String = "new") =
        Entry(id = id, text = text, createdAt = at, durationSec = 40, valence = v, audioPath = "/a.m4a")

    // ---- the one-time upgrade pass ----

    @Test fun `a false-friend score saved by 1_2 is cleared, and so is its mood suggestion`() {
        assertNull(Valence.of(german, shipped))
        assertNull(Valence.of(french, shipped))
        // Even before the pass, 1.3's gate ignores 1.2's stored score: the
        // entry has no stored language and does not read as English, so
        // SENTIMENT cannot read it and the German entry gets no tone.
        assertNull(Reflection.of(entry(german, -0.91f), emptyList()).tone)

        val rows = listOf(
            entry(german, -0.91f, id = "de"),
            entry(french, 0.88f, id = "fr").copy(suggestedMood = "joy"),
            // The user's own label is theirs: the valence goes, label and suggestion stay.
            entry(spanish, 0.4f, id = "es").copy(selfLabel = "sad", suggestedMood = "joy"),
            // English is untouched, score and suggestion both.
            entry(english, Valence.of(english, shipped), id = "en").copy(suggestedMood = "joy"),
            entry(englishLow, Valence.of(englishLow, shipped), id = "en2"),
            entry("a really good walk", 0f, id = "readzero"),
        )
        assertNotNull(rows.first { it.id == "en" }.valence)
        assertNotNull(rows.first { it.id == "en2" }.valence)

        val out = Repo.unreadValence(rows, shipped).associateBy { it.id }
        assertEquals(setOf("de", "fr", "es"), out.keys)
        assertNull(out.getValue("de").valence)
        assertNull(out.getValue("fr").valence)
        assertNull(out.getValue("fr").suggestedMood)
        assertNull(out.getValue("es").valence)
        assertEquals("sad", out.getValue("es").selfLabel)
        assertEquals("joy", out.getValue("es").suggestedMood)
        assertNull(Reflection.of(out.getValue("de"), emptyList()).tone)
    }

    @Test fun `a non-English suggestion is cleared even when valence was already null`() {
        val out = Repo.unreadValence(listOf(entry(hindi, null, id = "hi").copy(suggestedMood = "joy")), shipped)
        assertEquals(1, out.size)
        assertNull(out[0].suggestedMood)
        assertNull(out[0].valence)
    }

    @Test fun `an English journal is not rewritten at all`() {
        val rows = listOf(english, englishLow, "Good and bad, it cancels.").mapIndexed { i, t ->
            entry(t, Valence.of(t, shipped), id = "e$i").copy(suggestedMood = "calm")
        }
        assertTrue(Repo.unreadValence(rows, shipped).isEmpty())
    }

    // ---- Ask your Twin ----

    private fun journal(text: String, n: Int = 12, v: (Int) -> Float?) =
        List(n) { entry(text, v(it), now - (n - it) * day, "j$it") }

    @Test fun `Ask gives no mood verdict for a journal the lexicon could not read`() {
        // 1.3: every entry counts toward "enough entries" (the engine gates
        // each fact itself), so the Twin offers what it can read -- when you
        // speak -- and nothing about mood, style, topics or personality.
        val facts = askFacts(journal(hindi) { null })
        assertTrue(facts.hasEnoughData)
        assertFalse(facts.hasEnoughMoodData)
        assertEquals(0, facts.readableTextEntries)
        val offered = TwinQuestion.available(facts)
        listOf(
            TwinQuestion.POSITIVE_OR_NEGATIVE, TwinQuestion.MOOD_PATTERN,
            TwinQuestion.MOOD_OVER_TIME, TwinQuestion.HAPPIEST_WHEN,
            TwinQuestion.STRESS_TRIGGERS, TwinQuestion.PERSONALITY,
            TwinQuestion.COMMUNICATION_STYLE, TwinQuestion.DOMINANT_TOPICS,
        ).forEach { assertFalse("$it offered", it in offered) }
        listOf(
            TwinQuestion.POSITIVE_OR_NEGATIVE, TwinQuestion.MOOD_PATTERN,
            TwinQuestion.MOOD_OVER_TIME, TwinQuestion.HAPPIEST_WHEN,
            TwinQuestion.STRESS_TRIGGERS, TwinQuestion.PERSONALITY,
        ).forEach { q ->
            val a = TwinResponseGenerator.generate(q, facts)
            listOf("balanced", "Even", "even", "steady").forEach {
                assertFalse("$q said '$it': $a", a.contains(it))
            }
        }
    }

    @Test fun `Ask leaves unread entries out of a mixed journal's mood`() {
        val warm = journal(english, 6) { 0.6f }
        val hi = List(6) { entry(hindi, null, now - it * day, "h$it") }
        val facts = askFacts(warm + hi)
        // Every entry is in the journal; only the English six carry a mood.
        assertEquals(12, facts.totalEntries)
        assertEquals(0.6, facts.baselineValence, 1e-6)
    }

    @Test fun `Ask on an English journal answers exactly as before`() {
        val en = journal(english) { if (it % 2 == 0) 0.6f else -0.3f }
        val before = TwinFacts.from(en.map { ChatEntry(it.id, it.createdAt, it.text, it.valence!!) })
        val after = askFacts(en)
        assertEquals(TwinQuestion.available(before), TwinQuestion.available(after))
        TwinQuestion.values().forEach { q ->
            assertEquals(q.name, TwinResponseGenerator.generate(q, before), TwinResponseGenerator.generate(q, after))
        }
    }
}
