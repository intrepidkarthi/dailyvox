package com.dailyvox.app

import com.dailyvox.app.data.Sentiment
import org.junit.Assert.assertTrue
import org.junit.Test

class SentimentTest {

    @Test fun `everyday diary phrasing is not silently neutral`() {
        // Three of twelve seeded entries scored exactly 0.00 in a real PDF
        // export, because the lexicon subset held emotion nouns and almost no
        // ordinary diary verbs. A mood curve pinned to zero reads as broken.
        assertTrue(Sentiment.valence("The review went sideways and I let it get to me.") < -0.1f)
        assertTrue(Sentiment.valence("Slept badly again.") < -0.1f)
    }

    @Test fun `negation flips the sign`() {
        assertTrue(Sentiment.valence("I am not happy about it.") <
                   Sentiment.valence("I am happy about it."))
    }

    @Test fun `output stays inside the reporting range`() {
        val extreme = "great wonderful beautiful love best win happy grateful proud excited"
        assertTrue(Sentiment.valence(extreme) in -1f..1f)
        assertTrue(Sentiment.valence("terrible awful hate worst failed hopeless") in -1f..1f)
    }

    @Test fun `text with no lexicon hits is neutral`() {
        assertTrue(kotlin.math.abs(Sentiment.valence("The bus arrived at four.")) < 0.05f)
    }
}
