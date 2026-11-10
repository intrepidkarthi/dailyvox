package com.dailyvox.app

import android.content.Context
import androidx.test.core.app.ApplicationProvider
import com.dailyvox.app.audio.SpeechCapture
import java.util.Locale
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * B-8: the recogniser probe is re-run when the phone's language or the
 * speaking choice changes. 1.2's flag was forever: a phone switched from
 * English to Hindi kept asking for the English pack it probed on day one.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ProbeCacheTest {

    private val ctx = ApplicationProvider.getApplicationContext<Context>()
    private val prefs get() = ctx.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)
    private lateinit var saved: Locale

    @Before fun setUp() { saved = Locale.getDefault(); prefs.edit().clear().commit(); Locale.setDefault(Locale.US) }
    @After fun tearDown() { Locale.setDefault(saved); prefs.edit().clear().commit() }

    private fun markProbed() = prefs.edit().putString("recogniser_probed_for", SpeechCapture.probeKey(ctx)).commit()

    @Test
    fun `a fresh install probes`() = assertTrue(SpeechCapture.needsProbe(ctx))

    @Test
    fun `1_2's forever flag does not count as a probe`() {
        prefs.edit().putBoolean("recogniser_probed", true).commit()
        assertTrue(SpeechCapture.needsProbe(ctx))
    }

    @Test
    fun `probed once, same locale, no re-probe`() {
        markProbed()
        assertFalse(SpeechCapture.needsProbe(ctx))
    }

    @Test
    fun `a locale change re-probes`() {
        markProbed()
        Locale.setDefault(Locale.forLanguageTag("hi-IN"))
        assertTrue(SpeechCapture.needsProbe(ctx))
    }

    @Test
    fun `choosing a speaking language re-probes and is what the recogniser is asked for`() {
        markProbed()
        SpeechCapture.setSpeakingLanguage(ctx, "hi-IN")
        assertTrue(SpeechCapture.needsProbe(ctx))
        assertEquals("hi-IN", SpeechCapture.speakingLanguage(ctx))
        assertEquals("hi", SpeechCapture.wanted(ctx).language)
        SpeechCapture.setSpeakingLanguage(ctx, null)
        assertNull(SpeechCapture.speakingLanguage(ctx))
        assertEquals(Locale.US, SpeechCapture.wanted(ctx))
    }

    @Test
    fun `download asks for the wanted language in the recogniser's own spelling`() {
        prefs.edit().putString("recogniser_supported", "en-US,cmn-Hans-CN,hi-IN").commit()
        SpeechCapture.setSpeakingLanguage(ctx, "zh-CN")
        assertEquals("cmn-Hans-CN", SpeechCapture.downloadTag(ctx))
        SpeechCapture.setSpeakingLanguage(ctx, null)
        assertEquals("en-US", SpeechCapture.downloadTag(ctx))
    }
}
