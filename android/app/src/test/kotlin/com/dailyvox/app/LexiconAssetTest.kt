package com.dailyvox.app

import com.dailyvox.twin.Sentiment
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The asset is the APP's responsibility, so its test lives here.
 *
 * The engine owns the parser and the scorer and tests those against a fixture;
 * it does not reach across into this repo to find a file. What can only be
 * checked here is that the real table is actually present and shippable — the
 * one failure mode that is otherwise silent, because a missing asset makes every
 * entry score 0.00 and a flat mood curve looks exactly like a neutral month.
 */
class LexiconAssetTest {

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
        // this asserted excellent=3.4 and horrific=-3.9 from recall; both were
        // wrong, and the test caught me rather than the code.
        assertEquals(1.9f, shipped["good"]!!, 0.001f)
        assertEquals(-2.5f, shipped["bad"]!!, 0.001f)
        assertEquals(2.7f, shipped["excellent"]!!, 0.001f)
        assertEquals(-3.4f, shipped["horrific"]!!, 0.001f)
    }

    @Test fun `the real table scores real diary phrasing`() {
        assertTrue(Sentiment.valence("Slept badly again.", shipped) < -0.1f)
        assertTrue(Sentiment.valence("Best afternoon in weeks.", shipped) > 0.1f)
    }
}
