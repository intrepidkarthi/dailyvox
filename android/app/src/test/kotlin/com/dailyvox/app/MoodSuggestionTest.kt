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
 * The suggested mood. Two rules under test: a weak or mixed signal suggests
 * nothing, and a suggestion never becomes the user's label unless the user
 * makes it so.
 */
class MoodSuggestionTest {

    private val shipped: Map<String, Float> by lazy {
        java.io.File("src/main/assets/vader.txt").useLines { Sentiment.parseLexicon(it) }
    }

    private fun suggest(text: String): String? = MoodSuggestion.from(text, shipped)

    @Test fun `a strong score leans, a weak one does not, and nothing is not neutral`() {
        assertEquals(1, MoodSuggestion.lean(0.5f, 8))
        assertEquals(1, MoodSuggestion.lean(0.93f, 8))
        assertEquals(-1, MoodSuggestion.lean(-0.5f, 8))
        assertEquals(-1, MoodSuggestion.lean(-0.93f, 8))
        listOf(0f, 0.05f, -0.05f, 0.3f, -0.3f, 0.49f, -0.49f).forEach {
            assertEquals("leaned at $it", 0, MoodSuggestion.lean(it, 20))
        }
    }

    @Test fun `too few words suggests nothing however strong the score`() {
        assertEquals(0, MoodSuggestion.lean(0.9f, MoodSuggestion.MIN_WORDS - 1))
        assertEquals(0, MoodSuggestion.lean(-0.9f, 0))
        assertEquals(1, MoodSuggestion.lean(0.9f, MoodSuggestion.MIN_WORDS))
        assertNull(suggest("So happy, wonderful day."))
    }

    @Test fun `a broken score suggests nothing`() {
        assertEquals(0, MoodSuggestion.lean(Float.NaN, 20))
    }

    @Test fun `clear entries get joy or sadness, both from the canon`() {
        val joy = listOf(
            "Best afternoon in weeks, lunch with my sister was wonderful.",
            "So happy today, we laughed all evening and I feel grateful.",
        )
        val sad = listOf(
            "I feel awful and lonely tonight, everything went wrong.",
            "I cried most of the evening, I miss her so much and it hurts.",
        )
        joy.forEach { assertEquals(it, "joy", suggest(it)) }
        sad.forEach { assertEquals(it, "sadness", suggest(it)) }
        val canon = SelfLabels.CANON.map { it.first }.toSet()
        assertTrue("joy" in canon && "sadness" in canon)
    }

    @Test fun `mixed, sarcastic, grieving, angry and frightened entries get nothing`() {
        listOf(
            // Plain logistics: nothing to go on.
            "Went to the shop, then the bank, then home again.",
            // Mixed: one clear word the other way is enough to abstain.
            "Great start to the day but I am sad about how it ended.",
            "My grandmother died today. Everyone was so kind and loving and supportive at the funeral.",
            "I won the award but I feel empty and numb inside.",
            "Good morning good night good grief.",
            // Sarcasm reads as praise to a lexicon.
            "Oh great, another wonderful Monday stuck in traffic for two hours.",
            "Yeah, fantastic, my boss yelled at me again, just perfect.",
            // Pleasantries add up without anyone saying they felt good.
            "Thank you thank you, okay, sure, fine, whatever.",
            // Strongly negative, but not sadness: never relabelled as sad.
            "I was so angry, furious, I wanted to scream at him.",
            "Terrified about the biopsy results tomorrow, scared and anxious.",
            "So sad and so angry at how they treated her today.",
            // Negated.
            "Honestly I was not happy at all with it.",
            "Not sad, just tired after a long day.",
        ).forEach { assertNull(it, suggest(it)) }
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
        assertEquals("sadness", Repo.resuggest(entry(), "sadness"))
        assertNull(Repo.resuggest(entry(), null))
        // The user picked: the record of what they were shown stays.
        assertEquals("joy", Repo.resuggest(entry(label = "anger"), "sadness"))
        // The user cleared: nothing comes back.
        assertNull(Repo.resuggest(entry(suggested = null), "joy"))
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
