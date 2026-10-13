package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.Repo
import com.dailyvox.app.system.MoodSuggestion
import com.dailyvox.app.system.Reflection
import com.dailyvox.app.system.Research
import com.dailyvox.app.system.SelfLabels
import com.dailyvox.twin.Sentiment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The suggested mood. Two rules under test: a weak signal suggests nothing,
 * and a suggestion never becomes the user's label unless the user makes it so.
 */
class MoodSuggestionTest {

    private val shipped: Map<String, Float> by lazy {
        java.io.File("src/main/assets/vader.txt").useLines { Sentiment.parseLexicon(it) }
    }

    private fun suggest(text: String): String? = MoodSuggestion.from(
        Sentiment.valence(text, shipped), text.split(' ').count { it.isNotBlank() },
    )

    @Test fun `strong positive suggests joy, strong negative suggests sadness`() {
        assertEquals("joy", MoodSuggestion.from(0.5f, 8))
        assertEquals("joy", MoodSuggestion.from(0.93f, 8))
        assertEquals("sadness", MoodSuggestion.from(-0.5f, 8))
        assertEquals("sadness", MoodSuggestion.from(-0.93f, 8))
    }

    @Test fun `a weak signal suggests nothing, and nothing is not neutral`() {
        listOf(0f, 0.05f, -0.05f, 0.3f, -0.3f, 0.49f, -0.49f).forEach {
            assertNull("suggested something at $it", MoodSuggestion.from(it, 20))
        }
    }

    @Test fun `too few words suggests nothing however strong the score`() {
        assertNull(MoodSuggestion.from(0.9f, MoodSuggestion.MIN_WORDS - 1))
        assertNull(MoodSuggestion.from(-0.9f, 0))
        assertEquals("joy", MoodSuggestion.from(0.9f, MoodSuggestion.MIN_WORDS))
    }

    @Test fun `a broken score suggests nothing`() {
        assertNull(MoodSuggestion.from(Float.NaN, 20))
    }

    @Test fun `only joy and sadness are ever suggested, both from the canon`() {
        val seen = (-100..100).mapNotNull { MoodSuggestion.from(it / 100f, 20) }.toSet()
        assertEquals(setOf("joy", "sadness"), seen)
        val canon = SelfLabels.CANON.map { it.first }.toSet()
        assertTrue(seen.all { it in canon })
    }

    @Test fun `real diary phrasing through the shipped lexicon`() {
        assertEquals("joy", suggest("Best afternoon in weeks, lunch with my sister was wonderful."))
        assertEquals("sadness", suggest("I feel awful and lonely tonight, everything went wrong."))
        // Mixed, and plain logistics: nothing to go on, so nothing suggested.
        assertNull(suggest("Went to the shop, then the bank, then home again."))
        assertNull(suggest("Great start to the day but I am sad about how it ended."))
    }

    // ---------------------------------------------------------- storage rules

    private fun entry(label: String? = null, suggested: String? = "joy") = Entry(
        id = "e", text = "a lovely long walk by the river", createdAt = 1L, durationSec = 30,
        valence = 0.7f, selfLabel = label, suggestedMood = suggested,
    )

    @Test fun `a suggestion shows as the mood and is marked as one`() {
        val e = entry()
        assertEquals("joy", e.mood)
        assertTrue(e.moodIsSuggested)
        assertNull(e.selfLabel)
    }

    @Test fun `the user's label always wins over the suggestion`() {
        val e = entry(label = "sadness", suggested = "joy")
        assertEquals("sadness", e.mood)
        assertFalse(e.moodIsSuggested)
    }

    @Test fun `picking keeps the suggestion beside the choice`() {
        val picked = Repo.withLabel(entry(), "sadness")
        assertEquals("sadness", picked.selfLabel)
        assertEquals("joy", picked.suggestedMood)
        assertFalse(picked.moodIsSuggested)

        val confirmed = Repo.withLabel(entry(), "joy")
        assertEquals("joy", confirmed.selfLabel)
        assertFalse(confirmed.moodIsSuggested)
    }

    @Test fun `clearing leaves no mood at all`() {
        val cleared = Repo.withLabel(entry(label = "joy"), null)
        assertNull(cleared.selfLabel)
        assertNull(cleared.suggestedMood)
        assertNull(cleared.mood)
    }

    @Test fun `an edit re-suggests only while the suggestion is still live`() {
        // Live suggestion: follows the corrected words.
        assertEquals("sadness", Repo.resuggest(entry(), words = 10, valence = -0.8f))
        assertNull(Repo.resuggest(entry(), words = 10, valence = 0.1f))
        // The user picked: the record of what they were shown stays.
        assertEquals("joy", Repo.resuggest(entry(label = "anger"), words = 10, valence = -0.8f))
        // The user cleared: nothing comes back.
        assertNull(Repo.resuggest(entry(suggested = null), words = 10, valence = 0.9f))
    }

    @Test fun `the card applies the same rule as the row`() {
        val card = Reflection.of(entry(), emptyList())
        assertEquals("e", card.entryId)
        assertEquals("joy", card.mood)
        assertTrue(card.moodIsSuggested)

        val picked = card.withMood("fear")
        assertEquals("fear", picked.mood)
        assertFalse(picked.moodIsSuggested)
        assertEquals("joy", picked.suggestedMood)

        val cleared = picked.withMood(null)
        assertNull(cleared.mood)
        assertNull(cleared.suggestedMood)
    }

    @Test fun `a suggestion never reaches the research export`() {
        val device = Research.Device("DV-7K3Q-M9", "1.1", "Android 15", "Google Pixel 9")
        val onlySuggested = entry(label = null, suggested = "joy")
        val chosen = entry(label = "sadness", suggested = "joy").copy(id = "f", createdAt = 2L)
        // Read as text: the writer is plain JVM, and org.json would need Robolectric.
        val out = Research.export(listOf(onlySuggested, chosen), device, 0L)
        assertTrue(out.contains("\"entry_count\": 1"))
        assertTrue(out.contains("\"id\": \"f\""))
        assertFalse(out.contains("\"id\": \"e\""))
        assertTrue(out.contains("\"self_label\": \"sadness\""))
        assertFalse(out.contains("joy"))
        assertFalse(out.contains("suggest"))
    }
}
