package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.Repo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** A0-4. A query the tokenizer cannot read finds nothing, never everything. */
class SearchEmptyTermsTest {

    private fun e(id: String, text: String) =
        Entry(id = id, text = text, createdAt = id.hashCode().toLong(), durationSec = 30, valence = null)

    private val journal = listOf(
        e("a", "Dinner with Priya by the river"),
        e("b", "Long day at work, the meeting ran over"),
        e("c", "आज दादी से बात हुई"),
    )

    @Test fun `an English query ranks as before`() {
        assertEquals(listOf("a"), Repo.searchResults("dinner", journal).map { it.id })
        assertEquals(listOf("b"), Repo.searchResults("meeting at work", journal).map { it.id })
    }

    @Test fun `a Devanagari query finds its entry, not the whole journal`() {
        // B-9: the engine's Unicode tokenizer reads the script, so the query
        // finds the entry it names. Before it, the query tokenised to nothing.
        assertEquals(listOf("c"), Repo.searchResults("दादी", journal).map { it.id })
    }

    @Test fun `a query of only stopwords or short words is not the whole journal`() {
        assertTrue(Repo.searchResults("the", journal).isEmpty())
        assertTrue(Repo.searchResults("à", journal).isEmpty())
    }
}
