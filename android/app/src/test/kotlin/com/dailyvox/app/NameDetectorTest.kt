package com.dailyvox.app

import com.dailyvox.app.data.NameDetector
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Regression tests for the two defects that shipped to a running app and were
 * only caught by reading a PDF export.
 *
 * Both were invisible to the gold-corpus measurement — it scores span overlap,
 * which charges "Told Sarah" as one ordinary false positive and cannot see that
 * the same span also stops Sarah resolving in the graph. These tests assert the
 * behaviour the metric could not.
 */
class NameDetectorTest {

    private fun extract(text: String, corpus: List<String> = emptyList()): List<String> {
        val (mid, lower) = NameDetector.vocabulary(corpus + text)
        return NameDetector.extract(text, mid, lower)
    }

    @Test fun `a name never spans a full stop`() {
        // This case needs BOTH tokens to pass the per-token evidence check, or
        // it proves nothing: with an unattested opener like "Cooked" the token
        // filter alone already drops it, and the boundary break goes untested.
        // A falsification run caught exactly that — removing the break left the
        // first version of this test green.
        //
        // So: attest both names mid-sentence, then put them in adjacent
        // sentences. Without the break they merge into "Sarah James".
        val corpus = listOf("Long hike with Sarah.", "The call with James ran long.")
        val out = extract("I saw Sarah. James was late again.", corpus)
        assertEquals(listOf("Sarah", "James"), out)
    }

    @Test fun `the full stop is what separates them, not the whitespace`() {
        // Same two attested names inside ONE sentence stay joined, which is the
        // adjacency rule still doing its job.
        val corpus = listOf("Long hike with Sarah.", "The call with James ran long.")
        assertEquals(listOf("Sarah James"), extract("Met Sarah James at the door.", corpus))
    }

    @Test fun `a run does not survive a sentence it should have ended`() {
        // Before the fix this returned the single entity "Quiet Sunday Cooked".
        val out = extract("Quiet Sunday. Cooked properly for the first time in a fortnight.")
        assertTrue("no entity should span the full stop, got $out",
                   out.none { it.contains(" ") && it.contains("Cooked") })
    }

    @Test fun `a sentence-initial verb does not ride in on an attested name`() {
        // "Told Sarah about the job" filed a person called "Told Sarah", because
        // Sarah's evidence was pooled across the whole run.
        val corpus = listOf("Long hike up the ridge trail with Sarah.")
        val out = extract("Told Sarah about the job thing finally.", corpus)
        assertEquals(listOf("Sarah"), out)
    }

    @Test fun `possessives resolve to the same node`() {
        val corpus = listOf("Long hike with Sarah.")
        assertEquals(listOf("Sarah"), extract("Sarah's flight lands tonight.", corpus))
    }

    @Test fun `calendar words are not people`() {
        // Weekdays are capitalised by convention and never appear lowercase, so
        // every corpus signal this detector has would otherwise call them names.
        assertTrue(extract("Sunday was slow. Monday will be worse.").isEmpty())
    }

    @Test fun `contractions are not people`() {
        // "I'm" tokenises as one word, so listing "i" never excluded it.
        assertTrue(extract("I'm more nervous than I expected.").isEmpty())
    }

    @Test fun `mid-sentence names are still found`() {
        assertEquals(listOf("Sarah"), extract("Long hike up the ridge trail with Sarah."))
    }

    @Test fun `multi-word names within one sentence stay joined`() {
        val corpus = listOf("We drove to Golden Gate that morning.")
        assertTrue(extract("Crossed Golden Gate at dusk.", corpus).contains("Golden Gate"))
    }

    @Test fun `a first mention that opens its sentence is missed - documented cost`() {
        // Not a bug report: this asserts the KNOWN price of treating
        // sentence-initial capitalisation as grammar. If a later change makes
        // this pass, the strict arm has been loosened and precision must be
        // re-measured before it ships.
        assertFalse(extract("Priya sent photos from the wedding.").contains("Priya"))
    }
}
