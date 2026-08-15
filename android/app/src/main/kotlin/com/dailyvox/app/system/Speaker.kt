package com.dailyvox.app.system

import android.content.Context
import android.speech.tts.TextToSpeech
import java.util.Locale

/**
 * Read-aloud, the Android peer of TwinVoiceService.
 *
 * Shipped on iOS in v1.9 as an accessibility feature — it made the app usable by
 * people it had previously locked out — so it is not optional polish here.
 *
 * Note the scope line this deliberately does NOT cross: no MediaSession, no
 * MediaStyle notification, no audio-focus handling. Those are required the moment
 * playback becomes a background media experience, and they bring six named Play
 * quality criteria with them. In-app, foreground read-aloud stays below that line.
 */
class Speaker(context: Context) {

    private var ready = false
    private val tts = TextToSpeech(context.applicationContext) { status ->
        ready = status == TextToSpeech.SUCCESS
    }.apply { language = Locale.getDefault() }

    val isSpeaking: Boolean get() = runCatching { tts.isSpeaking }.getOrDefault(false)

    fun toggle(text: String) {
        if (!ready) return
        if (tts.isSpeaking) tts.stop()
        else tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "entry")
    }

    fun stop() = runCatching { tts.stop() }
    fun release() = runCatching { tts.stop(); tts.shutdown() }
}
