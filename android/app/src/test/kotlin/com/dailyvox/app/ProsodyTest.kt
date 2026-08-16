package com.dailyvox.app

import com.dailyvox.app.audio.Prosody
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import kotlin.math.PI
import kotlin.math.sin

/**
 * Prosody, tested against signals whose answers are known by construction.
 *
 * The alternative was listening to it, on an emulator with no microphone.
 */
class ProsodyTest {

    private val sr = 44_100

    /** A tone at [hz] for [seconds], then optional silence. Amplitude is well
     *  above the adaptive floor so voicing is unambiguous. */
    private fun tone(hz: Double, seconds: Double, silenceAfter: Double = 0.0): ShortArray {
        val voiced = (sr * seconds).toInt()
        val quiet = (sr * silenceAfter).toInt()
        return ShortArray(voiced + quiet) { i ->
            if (i >= voiced) 0
            else (sin(2.0 * PI * hz * i / sr) * 12000).toInt().toShort()
        }
    }

    @Test fun `pitch is recovered from a known tone`() {
        val p = Prosody.analyse(tone(150.0, 2.0), sr, wordCount = 8)
        assertTrue("not analysable", p.available)
        // Autocorrelation quantises to integer lags, so exact equality is not
        // available: at 150Hz one lag step is ~0.5Hz. 5Hz is generous and would
        // still catch an octave error, which is the failure that matters.
        assertEquals(150.0, p.pitchMean, 5.0)
    }

    @Test fun `a higher tone reads higher`() {
        val low = Prosody.analyse(tone(110.0, 1.5), sr, 5).pitchMean
        val high = Prosody.analyse(tone(260.0, 1.5), sr, 5).pitchMean
        assertTrue("$low should be below $high", low < high)
    }

    @Test fun `silence is counted as pause, not speech`() {
        // 1s of tone, 1s of silence: roughly half the recording is quiet.
        val p = Prosody.analyse(tone(180.0, 1.0, silenceAfter = 1.0), sr, 4)
        assertTrue("pauseRatio was ${p.pauseRatio}", p.pauseRatio in 0.35..0.65)
        assertTrue("expected a long pause, got ${p.longPauseCount}", p.longPauseCount >= 1)
    }

    @Test fun `speaking rate is per second of voiced audio, not wall clock`() {
        // 10 words over 2s of speech followed by 8s of silence is 5 words/sec,
        // not 1. Rating someone a slow talker because they paused is the bug
        // this definition exists to avoid.
        val p = Prosody.analyse(tone(160.0, 2.0, silenceAfter = 8.0), sr, wordCount = 10)
        assertEquals(5.0, p.speakingRate, 1.0)
    }

    @Test fun `pure silence is unavailable rather than a row of zeroes`() {
        val p = Prosody.analyse(ShortArray(sr * 2), sr, 5)
        assertFalse(p.available)
    }

    @Test fun `a clip too short to analyse is unavailable`() {
        assertFalse(Prosody.analyse(tone(150.0, 0.01), sr, 1).available)
    }

    @Test fun `noise does not produce a confident pitch`() {
        // White noise clears the energy gate but has no periodicity. The
        // clarity threshold is what stops room hiss being reported as a voice.
        val rng = java.util.Random(42)
        val noise = ShortArray(sr * 2) { (rng.nextGaussian() * 6000).toInt().toShort() }
        val p = Prosody.analyse(noise, sr, 6)
        assertTrue("noise reported ${p.pitchMean} Hz", p.pitchMean < 20.0 || !p.available)
    }
}
