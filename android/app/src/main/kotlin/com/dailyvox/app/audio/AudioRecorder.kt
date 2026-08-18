package com.dailyvox.app.audio

import android.content.Context
import android.media.MediaPlayer
import android.media.MediaRecorder
import android.os.Build
import java.io.File

/**
 * Records the audio alongside transcription, and plays it back.
 *
 * SpeechRecognizer gives text but keeps no file, so without this an entry could
 * be recorded and never heard again — the transcript would be the only artifact,
 * and a voice journal whose voice is discarded is a text journal with extra steps.
 *
 * AAC in an MP4 container, matching the iOS recorder so a `.twin` archive holds
 * one audio format rather than one per platform.
 */
class AudioRecorder(private val context: Context) {

    private var recorder: MediaRecorder? = null
    private var current: File? = null

    fun start(): File? = try {
        val dir = File(context.filesDir, "recordings").apply { mkdirs() }
        val f = File(dir, "entry-${System.currentTimeMillis()}.m4a")
        val r = if (Build.VERSION.SDK_INT >= 31) MediaRecorder(context) else @Suppress("DEPRECATION") MediaRecorder()
        r.setAudioSource(MediaRecorder.AudioSource.MIC)
        r.setOutputFormat(MediaRecorder.OutputFormat.MPEG_4)
        r.setAudioEncoder(MediaRecorder.AudioEncoder.AAC)
        r.setAudioSamplingRate(44_100)
        r.setAudioEncodingBitRate(64_000)
        r.setOutputFile(f.absolutePath)
        r.prepare(); r.start()
        recorder = r; current = f
        f
    } catch (_: Exception) {
        // The recogniser may already hold the mic on some OEM builds. Losing the
        // audio file is bad; losing the transcript too would be worse, so this
        // degrades to transcript-only rather than failing the whole recording.
        recorder = null; current = null; null
    }

    fun stop(): File? {
        return try {
            recorder?.apply { stop(); release() }
            recorder = null
            current?.takeIf { it.exists() && it.length() > 0 }
        } catch (_: Exception) {
            recorder = null; null
        } finally { current = null }
    }
}

/**
 * Plays a list of recordings back to back — the Journal's "Play today".
 *
 * Sequential rather than concatenated: joining the files would mean decoding and
 * re-encoding AAC to produce something the user never asked to keep, and a gap
 * between two entries is honest anyway. They were two separate moments.
 */
class AudioQueue {
    private var player: MediaPlayer? = null
    private var queue: List<String> = emptyList()
    private var index = 0
    var isPlaying = false
        private set

    fun play(paths: List<String>, onFinished: () -> Unit = {}) {
        stop()
        queue = paths.filter { java.io.File(it).exists() }
        if (queue.isEmpty()) { onFinished(); return }
        index = 0
        isPlaying = true
        advance(onFinished)
    }

    private fun advance(onFinished: () -> Unit) {
        if (index >= queue.size) { stop(); onFinished(); return }
        player = MediaPlayer().apply {
            runCatching {
                setDataSource(queue[index])
                setOnCompletionListener { index++; advance(onFinished) }
                prepare(); start()
            }.onFailure {
                // A missing or unreadable file must not strand the queue.
                index++; advance(onFinished)
            }
        }
    }

    fun stop() {
        runCatching { player?.stop(); player?.release() }
        player = null
        isPlaying = false
    }
}

/** Playback for the entry detail scrubber. One player, released on dispose. */
class AudioPlayback {
    private var player: MediaPlayer? = null

    val durationMs: Int get() = player?.duration ?: 0
    val positionMs: Int get() = runCatching { player?.currentPosition ?: 0 }.getOrDefault(0)
    val isPlaying: Boolean get() = runCatching { player?.isPlaying == true }.getOrDefault(false)

    fun toggle(path: String, onComplete: () -> Unit) {
        val p = player
        if (p != null && p.isPlaying) { p.pause(); return }
        if (p != null) { p.start(); return }
        player = MediaPlayer().apply {
            setDataSource(path); prepare(); start()
            setOnCompletionListener { onComplete() }
        }
    }

    fun seekTo(ms: Int) = runCatching { player?.seekTo(ms) }
    fun release() { runCatching { player?.release() }; player = null }
}
