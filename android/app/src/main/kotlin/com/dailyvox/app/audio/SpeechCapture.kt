package com.dailyvox.app.audio

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * On-device speech capture.
 *
 * `createOnDeviceSpeechRecognizer` (API 33+) forces recognition to stay on the
 * device -- it does not fall back to the network, it fails instead. That failure
 * mode is the correct one for this product: a journal that silently uploaded
 * audio to fill a gap would break the only promise it makes. On API < 33 the
 * platform recognizer is used with EXTRA_PREFER_OFFLINE, which is a preference
 * rather than a guarantee, so the UI says so.
 *
 * Known gap, and it is the largest untested assumption in the port: the name
 * detector depends entirely on transcripts CAPITALISING names. Apple's recognizer
 * does. Android's varies by OEM, and if it returns lowercase the entity graph
 * gets no input at all. This class is where that will first be observable.
 */
/** A failure the user can act on, rather than a silent return to idle. */
data class CaptureError(
    val message: String,
    val fix: String,
    val openLanguageSettings: Boolean = false,
)

class SpeechCapture(private val context: Context) {

    /**
     * PAUSED is a real state, not a label on a stopped recording. The button
     * that says Pause used to call the same handler as Stop, so the only
     * difference between the two controls was the glyph.
     */
    enum class State { IDLE, RECORDING, PAUSED, PROCESSING }

    private val _state = MutableStateFlow(State.IDLE)
    val state: StateFlow<State> = _state

    private val _partial = MutableStateFlow("")
    val partial: StateFlow<String> = _partial

    private val _level = MutableStateFlow(0f)
    val level: StateFlow<Float> = _level

    /**
     * Why the last attempt failed, in the user's language, or null.
     *
     * The recognizer used to fail SILENTLY: onError called finish("") and the
     * button went back to idle with no message. On an emulator — and on any
     * phone whose offline language pack is not installed — tapping record simply
     * did nothing, forever, with no way to find out why.
     */
    private val _error = MutableStateFlow<CaptureError?>(null)
    val error: StateFlow<CaptureError?> = _error

    fun clearError() { _error.value = null }

    private val _finished = MutableSharedFlow<String>(
        replay = 0, extraBufferCapacity = 1, onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val finished: SharedFlow<String> = _finished

    private var recognizer: SpeechRecognizer? = null

    /**
     * Transcript from the segments before the current one.
     *
     * SpeechRecognizer has no pause: a session that stops is over, and resuming
     * means starting a new one. So pausing banks what has been heard so far and
     * the next segment appends to it — the user gets one entry, the recogniser
     * gets several sessions, and nobody has to know.
     */
    private val kept = StringBuilder()

    /** True while a `stopListening` is on its way to PAUSED, not to a saved entry. */
    @Volatile private var pausing = false

    /**
     * Set by [cancel]: whatever the recogniser says next is thrown away.
     *
     * A flag rather than just destroying the recognizer, because `onResults`
     * can already be queued on the main thread when the user taps Discard —
     * and an entry that arrives after you discarded it is the worst kind.
     */
    @Volatile private var abandoned = false

    val onDeviceAvailable: Boolean
        get() = Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

    fun start() {
        if (_state.value != State.IDLE) return
        kept.setLength(0)
        abandoned = false
        beginSession()
    }

    /** Pick up where a pause left off. The kept transcript survives. */
    fun resume() {
        if (_state.value != State.PAUSED) return
        // If the recogniser has gone away mid-entry, save what was already said
        // rather than dropping the user back to idle with their words in limbo.
        if (!beginSession()) finish("")
    }

    private fun beginSession(): Boolean {
        _partial.value = ""
        pausing = false
        val r = when {
            onDeviceAvailable -> SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            SpeechRecognizer.isRecognitionAvailable(context) -> SpeechRecognizer.createSpeechRecognizer(context)
            else -> { _state.value = State.IDLE; return false }
        }
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { _state.value = State.RECORDING }
            override fun onBeginningOfSpeech() {}
            // 0..10 dB-ish; normalised for the button's pulse.
            override fun onRmsChanged(rms: Float) { _level.value = (rms / 10f).coerceIn(0f, 1f) }
            override fun onBufferReceived(buffer: ByteArray?) {}
            // Not while pausing or discarding: the session is ending because we
            // asked it to, and flipping to PROCESSING would drop the dial for a
            // frame on its way to PAUSED.
            override fun onEndOfSpeech() {
                if (!pausing && !abandoned) _state.value = State.PROCESSING
            }
            override fun onError(error: Int) {
                // A discarded session raises ERROR_CLIENT on its way out. That
                // is us, not the phone, and an error card for it would be a lie.
                if (!abandoned && !pausing) _error.value = describe(error)
                finish("")
            }
            override fun onResults(results: Bundle?) {
                finish(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty())
            }
            override fun onPartialResults(partialResults: Bundle?) {
                partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.let { _partial.value = it }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        r.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            // Custom vocabulary. Biasing strings landed in API 33 alongside the
            // on-device recognizer, and asking for the extra on older platforms
            // is harmless -- an unknown extra is ignored, never rejected.
            val bias = com.dailyvox.app.system.Vocabulary.get(context)
            if (bias.isNotEmpty() && Build.VERSION.SDK_INT >= 33) {
                putExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, bias.toTypedArray())
            }
        })
        _state.value = State.RECORDING
        return true
    }

    fun stop() {
        when (_state.value) {
            State.RECORDING -> {
                _state.value = State.PROCESSING
                recognizer?.stopListening()
            }
            // Nothing is listening, so there is no result to wait for: what was
            // kept before the pause IS the entry.
            State.PAUSED -> finish("")
            else -> return
        }
    }

    /** Bank the current segment and stop listening, without ending the entry. */
    fun pause() {
        if (_state.value != State.RECORDING) return
        pausing = true
        _state.value = State.PAUSED
        recognizer?.stopListening()
    }

    /**
     * Throw the whole recording away — no `finished`, no kept text, no error
     * card for the ERROR_CLIENT the recogniser raises on its way out.
     */
    fun cancel() {
        abandoned = true
        pausing = false
        kept.setLength(0)
        _partial.value = ""
        _level.value = 0f
        _state.value = State.IDLE
        val r = recognizer
        recognizer = null
        runCatching { r?.cancel() }
        runCatching { r?.destroy() }
    }

    private fun finish(text: String) {
        _level.value = 0f
        val out = text.ifBlank { _partial.value }
        _partial.value = ""
        recognizer?.destroy(); recognizer = null

        if (abandoned) {
            abandoned = false
            kept.setLength(0)
            _state.value = State.IDLE
            return
        }

        if (pausing) {
            pausing = false
            if (out.isNotBlank()) {
                if (kept.isNotEmpty()) kept.append(' ')
                kept.append(out)
            }
            _state.value = State.PAUSED
            return
        }

        _state.value = State.IDLE
        val whole = buildString {
            append(kept)
            if (isNotEmpty() && out.isNotBlank()) append(' ')
            append(out)
        }.trim()
        kept.setLength(0)
        if (whole.isNotBlank()) _finished.tryEmit(whole)
    }

    fun release() { recognizer?.destroy(); recognizer = null }

    /**
     * The one that matters is ERROR_LANGUAGE_UNAVAILABLE (13): the language is
     * supported but its offline pack is not downloaded. This app holds no
     * INTERNET permission, so it CANNOT fetch that pack itself — by design. The
     * message therefore has to point at the place the user can fix it, rather
     * than apologise and leave them stuck.
     *
     * Observed on a clean Pixel emulator as "LANGUAGE_PACK_ERROR with error
     * code 13", which is precisely the case the port plan flagged as untested.
     */
    private fun describe(code: Int): CaptureError = when (code) {
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> CaptureError(
            message = "This phone has no offline speech pack for your language yet.",
            fix = "Android Settings › System › Languages › Speech › Offline speech recognition. DailyVox cannot download it for you, because it has no internet permission at all.",
            openLanguageSettings = true,
        )
        SpeechRecognizer.ERROR_INSUFFICIENT_PERMISSIONS -> CaptureError(
            message = "The microphone permission was turned off.",
            fix = "Android Settings › Apps › DailyVox › Permissions.",
        )
        SpeechRecognizer.ERROR_RECOGNIZER_BUSY -> CaptureError(
            message = "Something else is using the microphone.",
            fix = "Close any other recording or call, then try again.",
        )
        SpeechRecognizer.ERROR_NO_MATCH,
        SpeechRecognizer.ERROR_SPEECH_TIMEOUT -> CaptureError(
            message = "Nothing was heard.",
            fix = "Tap again and speak a little closer to the phone.",
        )
        // Deliberately explicit: a NETWORK error means the platform recognizer
        // tried to go online, which is the one thing this app promises never
        // happens. Saying "check your connection" would endorse it.
        SpeechRecognizer.ERROR_NETWORK,
        SpeechRecognizer.ERROR_NETWORK_TIMEOUT,
        SpeechRecognizer.ERROR_SERVER,
        SpeechRecognizer.ERROR_SERVER_DISCONNECTED -> CaptureError(
            message = "This phone's recogniser wanted to use the internet, so nothing was recorded.",
            fix = "Turn on offline speech recognition in Android Settings › System › Languages › Speech. DailyVox will not transcribe over a network.",
            openLanguageSettings = true,
        )
        else -> CaptureError(
            message = "The recogniser stopped unexpectedly.",
            fix = "Tap to try again.",
        )
    }
}
