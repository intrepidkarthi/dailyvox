package com.dailyvox.app

import com.dailyvox.app.data.Entry
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The path where the recogniser fails and the microphone did not.
 *
 * Until 2026-08-31 this case deleted the recording. `SpeechCapture.finished`
 * only emitted non-blank text, and the collector that emitted it is where
 * `recorder.stop()` was called — so a failed transcription meant the audio file
 * was never even closed, let alone saved. On a phone whose recogniser does not
 * work, every entry the user spoke was destroyed, silently.
 *
 * These tests hold the two halves of the fix: an entry can exist with audio and
 * no words, and everything that reads its text has to cope with that rather
 * than reporting "1 WORDS" and a nonsense pace.
 */
class UntranscribedEntryTest {

    private fun entry(text: String, audio: String? = null) = Entry(
        id = "e1", text = text, createdAt = 0L, durationSec = 42, valence = 0f,
        audioPath = audio,
    )

    @Test
    fun `empty text with audio is an untranscribed entry, not a blank one`() {
        assertTrue(entry("", audio = "/x/a.m4a").isUntranscribed)
    }

    @Test
    fun `empty text with no audio is not claimed as untranscribed`() {
        // Nothing was captured at all — there is no recording to offer, so the
        // screens must not promise one.
        assertFalse(entry("").isUntranscribed)
    }

    @Test
    fun `a real entry is never treated as untranscribed`() {
        assertFalse(entry("Walked to the ridge trail.", audio = "/x/a.m4a").isUntranscribed)
    }

    /**
     * The bug that made an untranscribed entry look absurd rather than merely
     * empty: "".split(" ") is [""], size 1.
     */
    @Test
    fun `word count is zero for no words, not one`() {
        assertEquals(0, entry("").wordCount)
        assertEquals(0, entry("   ").wordCount)
    }

    @Test
    fun `word count ignores padding and newlines`() {
        assertEquals(5, entry("Walked  before anyone\nwas up").wordCount)
    }

    /**
     * Pace is words-per-minute over the recording. With the old count, a
     * 42-second silent entry reported 1 wpm as though the user had said one
     * word; it must report nothing at all.
     */
    @Test
    fun `pace over an untranscribed entry is zero`() {
        val e = entry("", audio = "/x/a.m4a")
        assertEquals(0, e.wordCount * 60 / e.durationSec.coerceAtLeast(1))
    }
}
