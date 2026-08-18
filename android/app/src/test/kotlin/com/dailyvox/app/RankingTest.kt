package com.dailyvox.app

import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.Repo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Ask shows each citation's score as a percentage, so the score is now visible
 * to the user rather than an internal sort key. That raises the bar: a ranking
 * that merely orders correctly can still print three identical percentages and
 * look broken, which is exactly what a hand-check on the emulator showed before
 * the query typo behind it was found.
 */
class RankingTest {

    private fun e(id: String, text: String, entities: String = "") = Entry(
        id = id, text = text, createdAt = 1_700_000_000_000L, durationSec = 30,
        valence = 0f, entities = entities,
    )

    private val corpus = listOf(
        e("walk", "Walked before anyone was up. Sarah's flight lands tonight.", "Sarah"),
        e("hike", "Long hike up the ridge trail with Sarah. We got rained on.", "Sarah"),
        e("work", "The review went sideways and James pushed back on the timeline.", "James"),
    )

    @Test
    fun `an entry matching every term outranks one matching half`() {
        val ranked = Repo.rank("hike with Sarah", corpus)

        assertEquals("only the two Sarah entries match", 2, ranked.size)
        assertEquals("the hike is the best match", "hike", ranked[0].first.id)
        // Both terms present, so a full score — not the tie the emulator showed.
        assertEquals(1.0f, ranked[0].second, 0.001f)
        assertEquals("the walk matches Sarah alone", 0.5f, ranked[1].second, 0.001f)
    }

    @Test
    fun `stop words do not dilute the score`() {
        // "with" is a stop word: were it counted as a term, the hike entry would
        // score 2/3 and print 66% for a query it answers completely.
        val withStop = Repo.rank("hike with Sarah", corpus).first().second
        val without = Repo.rank("hike Sarah", corpus).first().second
        assertEquals(without, withStop, 0.001f)
    }

    @Test
    fun `entity names are searchable even when spelled differently in the text`() {
        // "Sarah's" in the transcript stems differently from the entity "Sarah";
        // the entity list is what makes a name reliably findable.
        val ranked = Repo.rank("Sarah", corpus)
        assertEquals(2, ranked.size)
        assertTrue("both Sarah entries score fully", ranked.all { it.second == 1.0f })
    }

    @Test
    fun `a query with no content words returns nothing rather than everything`() {
        // Ask renders whatever this returns as "the closest is…". Falling back
        // to the whole journal would present an arbitrary entry as a match.
        assertTrue(Repo.rank("the and with", corpus).isEmpty())
        assertTrue(Repo.rank("   ", corpus).isEmpty())
    }

    @Test
    fun `an unmatched query returns nothing`() {
        assertTrue(Repo.rank("submarine tuba", corpus).isEmpty())
    }
}
