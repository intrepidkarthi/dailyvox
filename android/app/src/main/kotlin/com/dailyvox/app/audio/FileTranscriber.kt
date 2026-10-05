package com.dailyvox.app.audio

import android.content.Context
import android.media.AudioFormat
import android.os.Bundle
import android.os.ParcelFileDescriptor
import android.speech.RecognitionListener
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import android.content.Intent
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.suspendCancellableCoroutine
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeoutOrNull
import java.io.File
import java.util.Locale
import kotlin.coroutines.resume

/**
 * Transcribe an entry that was recorded but never turned into words.
 *
 * The whole reason this can exist: `RecognizerIntent.EXTRA_AUDIO_SOURCE` takes
 * "a ParcelFileDescriptor pointing to an already opened audio source for the
 * recognizer to use", with channel count, encoding and sampling rate alongside
 * it. It arrived in API 33, which is our minSdk exactly. So the platform
 * recogniser can read a file instead of the microphone, and an entry that
 * failed on a phone with no language pack becomes transcribable the moment the
 * user installs one — from audio we kept at the time.
 *
 * ### The trap, and why most of this class exists
 *
 * The same javadoc says: *"If this extra is not set or the recognizer does not
 * support this feature, the recognizer will open the mic."* Support is optional
 * and the failure is **silent**. A recogniser that ignores the extra starts
 * listening to the room and hands back whatever it hears — so a user sitting in
 * a cafe would get the next table's conversation saved as their diary entry,
 * with no error anywhere.
 *
 * That is the same shape as `EXTRA_PREFER_OFFLINE` being a preference rather
 * than a guarantee, which is the bug this app already shipped once. So the
 * result from this path is not trusted until the recogniser has demonstrably
 * read our bytes.
 *
 * The proof is the pipe. A pipe holds [PIPE_BUFFER_BYTES] before a write blocks.
 * If we manage to push more than that, something drained it, and the only
 * reader is the recogniser. If the write stalls with less than a bufferful
 * gone, nobody is reading our audio and the transcript — whatever it says —
 * did not come from this file. Discard it.
 */
object FileTranscriber {

    sealed interface Result {
        data class Text(val value: String) : Result
        /** The recogniser answered, but never read our audio. Never trust this. */
        data object IgnoredTheFile : Result
        data class Failed(val reason: String) : Result
    }

    /** Linux pipe capacity. Writing past it proves a reader consumed the front. */
    private const val PIPE_BUFFER_BYTES = 64 * 1024
    private const val TIMEOUT_MS = 60_000L

    suspend fun transcribe(context: Context, audio: File, language: String?): Result =
        withContext(Dispatchers.IO) {
            if (!audio.exists()) return@withContext Result.Failed("The recording is missing.")
            if (!SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
                return@withContext Result.Failed("This phone has no on-device recogniser.")
            }
            val (pcm, sampleRate) = AudioDecoder.toPcm(audio)
                ?: return@withContext Result.Failed("The recording could not be decoded.")
            if (pcm.isEmpty()) return@withContext Result.Failed("The recording is empty.")

            withTimeoutOrNull(TIMEOUT_MS) { run(context, pcm, sampleRate, language) }
                ?: Result.Failed("The recogniser did not finish in time.")
        }

    private suspend fun run(
        context: Context,
        pcm: ShortArray,
        sampleRate: Int,
        language: String?,
    ): Result {
        val pipe = ParcelFileDescriptor.createPipe()
        val read = pipe[0]
        val write = pipe[1]
        // Counted on the writer thread, read back once the recogniser settles.
        // Atomic rather than a lock: one writer, one reader, and a stale value
        // could only make us MORE suspicious, never less.
        val written = java.util.concurrent.atomic.AtomicLong(0)

        val writer = Thread {
            runCatching {
                ParcelFileDescriptor.AutoCloseOutputStream(write).use { out ->
                    val buf = ByteArray(4096)
                    var i = 0
                    while (i < pcm.size) {
                        var b = 0
                        while (b < buf.size - 1 && i < pcm.size) {
                            val s = pcm[i++].toInt()
                            buf[b++] = (s and 0xFF).toByte()
                            buf[b++] = ((s shr 8) and 0xFF).toByte()
                        }
                        out.write(buf, 0, b)
                        written.addAndGet(b.toLong())
                    }
                }
            }
        }.apply { isDaemon = true; start() }

        val text = suspendCancellableCoroutine<String?> { cont ->
            val recognizer = runCatching {
                SpeechRecognizer.createOnDeviceSpeechRecognizer(context)
            }.getOrElse { cont.resume(null); return@suspendCancellableCoroutine }

            recognizer.setRecognitionListener(object : RecognitionListener {
                private var done = false
                private fun finish(v: String?) {
                    if (done) return
                    done = true
                    runCatching { recognizer.destroy() }
                    cont.resume(v)
                }
                override fun onResults(results: Bundle?) = finish(
                    results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull()
                )
                override fun onError(error: Int) = finish(null)
                override fun onReadyForSpeech(params: Bundle?) {}
                override fun onBeginningOfSpeech() {}
                override fun onRmsChanged(rmsdB: Float) {}
                override fun onBufferReceived(buffer: ByteArray?) {}
                override fun onEndOfSpeech() {}
                override fun onPartialResults(partialResults: Bundle?) {}
                override fun onEvent(eventType: Int, params: Bundle?) {}
            })

            recognizer.startListening(
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                    putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE, language ?: Locale.getDefault().toLanguageTag())
                    // The whole point: read this, not the microphone.
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE, read)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_CHANNEL_COUNT, 1)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_ENCODING, AudioFormat.ENCODING_PCM_16BIT)
                    putExtra(RecognizerIntent.EXTRA_AUDIO_SOURCE_SAMPLING_RATE, sampleRate)
                }
            )
            cont.invokeOnCancellation { runCatching { recognizer.destroy() } }
        }

        runCatching { writer.join(2_000) }
        runCatching { read.close() }

        // Did anything actually consume our audio?
        val consumed = written.get() > PIPE_BUFFER_BYTES
        return when {
            !consumed -> Result.IgnoredTheFile
            text.isNullOrBlank() -> Result.Failed("The recogniser returned no words for this recording.")
            else -> Result.Text(text)
        }
    }
}
