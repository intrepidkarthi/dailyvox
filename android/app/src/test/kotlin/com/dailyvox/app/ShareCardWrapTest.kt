package com.dailyvox.app

import com.dailyvox.app.system.ShareCard
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** A0-9. The card wraps every script inside the card, and English as before. */
class ShareCardWrapTest {

    /** One unit per char: easy to reason about, and monotonic like a real Paint. */
    private val chars: (String) -> Float = { it.length.toFloat() }

    /** The old space-splitting wrap, kept here as the English reference. */
    private fun oldWrap(text: String, max: Float): List<String> {
        val out = mutableListOf<String>()
        var line = StringBuilder()
        text.split(" ").forEach { w ->
            val cand = if (line.isEmpty()) w else "$line $w"
            if (chars(cand) > max) { out.add(line.toString()); line = StringBuilder(w) } else line = StringBuilder(cand)
        }
        if (line.isNotEmpty()) out.add(line.toString())
        return out
    }

    @Test fun `English wraps exactly as before`() {
        listOf(
            "I had a really lovely walk with Sarah today and felt happy about it",
            "Long day at work, the meeting ran over and I missed dinner again",
            "short",
        ).forEach { t ->
            listOf(10f, 16f, 24f, 40f).forEach { max ->
                assertEquals("$t @ $max", oldWrap(t, max), ShareCard.wrapLines(t, max, Locale.US, chars))
            }
        }
    }

    @Test fun `Chinese with no spaces wraps instead of running off the card`() {
        val zh = "今天和妈妈一起去公园散步天气很好我们聊了很久心情也变得轻松了"
        // Old behaviour: the whole entry on one line, as wide as the entry.
        assertTrue(oldWrap(zh, 10f).any { it == zh })
        val lines = ShareCard.wrapLines(zh, 10f, Locale.CHINESE, chars)
        assertTrue(lines.size > 1)
        assertTrue(lines.all { it.length <= 10 })
        assertEquals(zh, lines.joinToString(""))
    }

    @Test fun `Thai wraps inside the card`() {
        val th = "วันนี้ฉันไปเดินเล่นที่สวนกับแม่อากาศดีมากและเราคุยกันนานมาก"
        val lines = ShareCard.wrapLines(th, 12f, Locale("th"), chars)
        assertTrue(lines.size > 1)
        assertTrue(lines.all { it.length <= 12 })
        assertEquals(th, lines.joinToString(""))
    }

    @Test fun `a single run wider than the card is broken, never drawn off the edge`() {
        val lines = ShareCard.wrapLines("supercalifragilisticexpialidocious", 10f, Locale.US, chars)
        assertTrue(lines.all { it.length <= 10 })
        assertEquals("supercalifragilisticexpialidocious", lines.joinToString(""))
    }

    @Test fun `Devanagari conjuncts are not cut when a run is force-broken`() {
        val hi = "क्षत्रियक्षत्रियक्षत्रिय"
        val lines = ShareCard.wrapLines(hi, 4f, Locale("hi"), chars)
        assertEquals(hi, lines.joinToString(""))
        // No line starts with a combining mark (a virama or vowel sign).
        assertTrue(lines.none { Character.getType(it[0]) == Character.NON_SPACING_MARK.toInt() ||
            Character.getType(it[0]) == Character.COMBINING_SPACING_MARK.toInt() })
    }
}
