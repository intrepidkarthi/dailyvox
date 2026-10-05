package com.dailyvox.app

import com.dailyvox.app.system.CasingCheck
import com.dailyvox.app.system.CasingCheck.Verdict
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The check exists to tell three situations apart that look identical on
 * screen: a journal with nobody in it, a recogniser that does not capitalise,
 * and a recogniser that capitalises inconsistently. If it cannot do that
 * reliably it is worse than nothing, because it would tell people their phone
 * is broken when they simply wrote about the weather.
 *
 * The corpora below are deliberately long enough to clear MIN_WORDS, since a
 * verdict on a short journal is exactly the false alarm being guarded against.
 */
class CasingCheckTest {

    /** Filler that carries no name evidence either way, to reach MIN_WORDS. */
    private fun padding(n: Int) = List(n) {
        "walked to the market and back again in the rain and thought about " +
            "nothing much at all for once which was a relief after the week " +
            "that came before it and the one before that"
    }

    @Test
    fun `a short journal gets no verdict, however it is cased`() {
        assertEquals(Verdict.NotEnoughYet, CasingCheck.of(listOf("Saw Sarah today.")))
        assertEquals(Verdict.NotEnoughYet, CasingCheck.of(listOf("saw sarah today.")))
    }

    @Test
    fun `well-cased transcripts read as casing`() {
        val texts = padding(6) + listOf(
            "Walked with Sarah by the reservoir and she talked about Mumbai.",
            "Told Sarah about the job. James rang later and I let it go.",
            "Coffee with Adyah before work, then a long call with Priya.",
        )
        assertEquals(Verdict.Casing, CasingCheck.of(texts))
    }

    @Test
    fun `an all-lowercase recogniser is caught`() {
        val texts = padding(6) + listOf(
            "walked with sarah by the reservoir and she talked about mumbai.",
            "told sarah about the job. james rang later and i let it go.",
            "coffee with adyah before work, then a long call with priya.",
        )
        assertEquals(Verdict.NotCasing, CasingCheck.of(texts))
    }

    /**
     * The important one. "I" is capitalised mid-sentence in almost every English
     * sentence, so without excluding it a lowercase corpus would look perfectly
     * well-cased and this check would never once fire.
     */
    @Test
    fun `capital I alone is not evidence of casing`() {
        val texts = padding(6) + listOf(
            "told sarah about the job and I let it go, which I regret.",
            "james rang later and I did not pick up, and I should have.",
        )
        assertEquals(Verdict.NotCasing, CasingCheck.of(texts))
    }

    /** Days and months are capitalised by convention, not by name recognition. */
    @Test
    fun `calendar words alone are not evidence of casing`() {
        val texts = padding(6) + listOf(
            "quiet Sunday, cooked properly for once and read on the balcony.",
            "back to it on Monday and the whole of March feels like this.",
        )
        assertEquals(Verdict.NotCasing, CasingCheck.of(texts))
    }

    @Test
    fun `inconsistent casing is reported with the names being lost`() {
        val texts = padding(6) + listOf(
            "Walked with Sarah by the reservoir and she talked about Mumbai.",
            "told sarah about the job, and james rang later.",
            "Coffee with Adyah, then sarah called and adyah texted about mumbai.",
        )
        val v = CasingCheck.of(texts)
        assertTrue("expected Inconsistent, got $v", v is Verdict.Inconsistent)
        val contested = (v as Verdict.Inconsistent).contested
        assertTrue(
            "the contested tokens ARE the names being discarded, got $contested",
            contested.containsAll(listOf("sarah", "adyah")),
        )
    }

    /**
     * A long journal that genuinely mentions nobody must not be reported as a
     * broken recogniser — this is the false alarm that would matter most,
     * because it accuses the user's phone of a fault it does not have.
     */
    @Test
    fun `a nameless journal reads as not casing, not as inconsistent`() {
        val v = CasingCheck.of(padding(8))
        assertEquals(Verdict.NotCasing, v)
    }
}
