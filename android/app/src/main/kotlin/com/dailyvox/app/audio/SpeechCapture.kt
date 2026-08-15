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
class SpeechCapture(private val context: Context) {

    enum class State { IDLE, RECORDING, PROCESSING }

    private val _state = MutableStateFlow(State.IDLE)
    val state: StateFlow<State> = _state

    private val _partial = MutableStateFlow("")
    val partial: StateFlow<String> = _partial

    private val _level = MutableStateFlow(0f)
    val level: StateFlow<Float> = _level

    private val _finished = MutableSharedFlow<String>(
        replay = 0, extraBufferCapacity = 1, onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val finished: SharedFlow<String> = _finished

    private var recognizer: SpeechRecognizer? = null

    val onDeviceAvailable: Boolean
        get() = Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)

    fun start() {
        if (_state.value != State.IDLE) return
        _partial.value = ""
        val r = when {
            onDeviceAvailable -> SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            SpeechRecognizer.isRecognitionAvailable(context) -> SpeechRecognizer.createSpeechRecognizer(context)
            else -> { _state.value = State.IDLE; return }
        }
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) { _state.value = State.RECORDING }
            override fun onBeginningOfSpeech() {}
            // 0..10 dB-ish; normalised for the button's pulse.
            override fun onRmsChanged(rms: Float) { _level.value = (rms / 10f).coerceIn(0f, 1f) }
            override fun onBufferReceived(buffer: ByteArray?) {}
            override fun onEndOfSpeech() { _state.value = State.PROCESSING }
            override fun onError(error: Int) { finish("") }
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
        })
        _state.value = State.RECORDING
    }

    fun stop() {
        if (_state.value != State.RECORDING) return
        _state.value = State.PROCESSING
        recognizer?.stopListening()
    }

    private fun finish(text: String) {
        _level.value = 0f
        _state.value = State.IDLE
        val out = text.ifBlank { _partial.value }
        _partial.value = ""
        recognizer?.destroy(); recognizer = null
        if (out.isNotBlank()) _finished.tryEmit(out)
    }

    fun release() { recognizer?.destroy(); recognizer = null }
}
