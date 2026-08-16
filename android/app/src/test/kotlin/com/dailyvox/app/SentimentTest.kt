package com.dailyvox.app

import com.dailyvox.app.data.Sentiment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class SentimentTest {

    /**
     * Reads the SHIPPED asset off disk, which is the point of this whole file.
     * The only realistic way the lexicon fails in production is not being
     * packaged, and that failure is silent — every entry scores 0.00 and the
     * mood curve flatlines while looking like a genuinely neutral month.
     */
    private val shipped: Map<String, Float> by lazy {
        val f = java.io.File("src/main/assets/vader.txt")
        assertTrue("vader.txt is missing from src/main/assets", f.exists())
        f.useLines { Sentiment.parseLexicon(it) }
    }

    @Test fun `the shipped lexicon is the full VADER table`() {
        // A floor rather than equality, so an upstream refresh does not fail the
        // build while a truncated or half-written file still does.
        assertTrue("only ${shipped.size} entries", shipped.size > 7_000)
    }

    @Test fun `known VADER scores survive the round trip`() {
        // Read off the published table, not from memory. My first attempt at
        // this test asserted excellent=3.4 and horrific=-3.9 from recall; both
        // were wrong, and the test caught me rather than the code.
        assertEquals(1.9f, shipped["good"]!!, 0.001f)
        assertEquals(-2.5f, shipped["bad"]!!, 0.001f)
        assertEquals(2.7f, shipped["excellent"]!!, 0.001f)
        assertEquals(-3.4f, shipped["horrific"]!!, 0.001f)
    }

    @Test fun `everyday diary phrasing is scored`() {
        assertTrue(Sentiment.valence("Slept badly again.", shipped) < -0.1f)
        assertTrue(Sentiment.valence("Frustrated with myself today.", shipped) < -0.1f)
        assertTrue(Sentiment.valence("Best afternoon in weeks.", shipped) > 0.1f)
    }

    @Test fun `a sentence VADER has no word for scores zero - documented gap`() {
        // "The review went sideways" contains not one token in the 7,517-entry
        // table, so it reads 0.00. This asserts that ON PURPOSE.
        //
        // An earlier version of this app carried ~40 hand-weighted diary words
        // that covered exactly this sentence. They were removed: 14 of them were
        // absent from VADER because VADER omits polysemous words deliberately
        // ("quiet", "cold", "light", "close", "behind"), and bolting unmeasured
        // weights onto a table validated at r=+0.663 to rescue one demo sentence
        // is the unmeasured tinkering this project's eval programme exists to
        // stop. Measured across the twelve seeded entries, pure VADER leaves
        // exactly ONE at 0.00 — this one. That was judged the better trade.
        //
        // If this ever starts failing, someone has added words to the lexicon,
        // and the correlation needs re-measuring before it ships.
        assertEquals(0f, Sentiment.valence("The review went sideways.", shipped), 0.0001f)
    }

    @Test fun `negation flips the sign`() {
        assertTrue(Sentiment.valence("I am not happy about it.", shipped) <
                   Sentiment.valence("I am happy about it.", shipped))
    }

    @Test fun `output stays inside the reporting range`() {
        val extreme = "great wonderful beautiful love best win happy grateful proud excited"
        assertTrue(Sentiment.valence(extreme, shipped) in -1f..1f)
        assertTrue(Sentiment.valence("terrible awful hate worst failed hopeless", shipped) in -1f..1f)
    }

    @Test fun `text with no lexicon hits is neutral`() {
        assertEquals(0f, Sentiment.valence("The bus arrived at four.", shipped), 0.0001f)
    }

    @Test fun `an empty lexicon scores nothing rather than crashing`() {
        // The load-failure path. It must not throw — it must return 0 and let
        // the caller's log carry the alarm.
        assertEquals(0f, Sentiment.valence("wonderful terrible day", emptyMap()), 0.0001f)
    }
}
