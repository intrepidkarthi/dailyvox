package com.dailyvox.app

import android.content.Context
import android.os.Bundle
import android.os.Looper
import android.speech.SpeechRecognizer
import androidx.test.core.app.ApplicationProvider
import com.dailyvox.app.audio.SpeechCapture
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.Shadows.shadowOf
import org.robolectric.annotation.Config
import org.robolectric.shadows.ShadowSpeechRecognizer

/**
 * The Galaxy S24 report: the recogniser hears silence (the recorder holds the
 * microphone), times out after ~5 s, and that ended the whole entry. When the
 * recorder heard the room, the entry now records on and the file is
 * transcribed after stop. A phone whose recogniser works, or a silent room,
 * behaves as before.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class SpeechCaptureDeafTest {

    private val ctx = ApplicationProvider.getApplicationContext<Context>()
    private lateinit var capture: SpeechCapture

    @Before fun setUp() {
        ShadowSpeechRecognizer.reset()
        ShadowSpeechRecognizer.setIsOnDeviceRecognitionAvailable(true)
        // Skip the language probe: it is a bound-service round trip with its own tests.
        ctx.getSharedPreferences("dailyvox", Context.MODE_PRIVATE).edit()
            .putString("recogniser_probed_for", SpeechCapture.probeKey(ctx)).commit()
        capture = SpeechCapture(ctx)
    }

    private fun recogniser() = shadowOf(ShadowSpeechRecognizer.getLatestSpeechRecognizer())
    private fun idle() = shadowOf(Looper.getMainLooper()).idle()
    private fun results(text: String) = Bundle().apply {
        putStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION, arrayListOf(text))
    }

    private fun startHearing(roomHeard: Boolean) {
        capture.soundCheck = { roomHeard }
        capture.start(); idle()
        recogniser().triggerOnReadyForSpeech(Bundle()); idle()
    }

    @Test fun `a recogniser that times out while the room is heard keeps the entry recording`() {
        startHearing(roomHeard = true)
        val old = recogniser()
        old.triggerOnError(SpeechRecognizer.ERROR_SPEECH_TIMEOUT); idle()
        assertEquals(SpeechCapture.State.RECORDING, capture.state.value)
        assertTrue(capture.deaf)
        assertNull("no error card while still recording", capture.error.value)
        assertTrue("the deaf recogniser is let go", old.isDestroyed)

        // Pause and resume stay deaf: no new recogniser session to fail again.
        capture.pause(); assertEquals(SpeechCapture.State.PAUSED, capture.state.value)
        capture.resume(); assertEquals(SpeechCapture.State.RECORDING, capture.state.value)

        runBlocking {
            val handed = launch(start = CoroutineStart.UNDISPATCHED) {
                assertEquals("", capture.needsFileTranscript.first())
            }
            capture.stop()
            handed.join()
        }
        assertEquals("filing waits for the file transcript", SpeechCapture.State.PROCESSING, capture.state.value)
        capture.fileDone()
        assertEquals(SpeechCapture.State.IDLE, capture.state.value)
        assertFalse(capture.deaf)
    }

    @Test fun `no match, no audio and an empty result go deaf too`() {
        for (error in listOf(SpeechRecognizer.ERROR_NO_MATCH, SpeechRecognizer.ERROR_AUDIO)) {
            setUp(); startHearing(roomHeard = true)
            recogniser().triggerOnError(error); idle()
            assertTrue("error $error", capture.deaf)
            capture.cancel()
        }
        setUp(); startHearing(roomHeard = true)
        recogniser().triggerOnEndOfSpeech(); idle()
        recogniser().triggerOnResults(results("")); idle()
        assertTrue(capture.deaf)
        assertEquals(SpeechCapture.State.RECORDING, capture.state.value)
    }

    @Test fun `a silent room still ends with nothing heard`() {
        startHearing(roomHeard = false)
        recogniser().triggerOnError(SpeechRecognizer.ERROR_SPEECH_TIMEOUT); idle()
        assertFalse(capture.deaf)
        assertEquals(SpeechCapture.State.IDLE, capture.state.value)
        assertNotNull(capture.error.value)
    }

    @Test fun `after the user pressed stop a no-match is just the end`() {
        startHearing(roomHeard = true)
        capture.stop()
        recogniser().triggerOnError(SpeechRecognizer.ERROR_NO_MATCH); idle()
        assertFalse(capture.deaf)
        assertEquals(SpeechCapture.State.IDLE, capture.state.value)
    }

    @Test fun `a recogniser that hears is unchanged`() {
        startHearing(roomHeard = true)
        runBlocking {
            val saved = launch(start = CoroutineStart.UNDISPATCHED) {
                assertEquals("I walked to the lake", capture.finished.first())
            }
            recogniser().triggerOnEndOfSpeech(); idle()
            recogniser().triggerOnResults(results("I walked to the lake")); idle()
            saved.join()
        }
        assertFalse(capture.deaf)
        assertEquals(SpeechCapture.State.IDLE, capture.state.value)
    }
}
