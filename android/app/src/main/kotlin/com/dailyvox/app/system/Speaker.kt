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
 *
 * The voice follows the ENTRY's language (plan B-13), not the phone's. A Hindi
 * entry read by the English voice is a string of mispronounced syllables -- the
 * spoken version of a wrong transcript -- so when the phone has no voice for
 * the entry's language it stays quiet and says so ([Outcome.NO_VOICE]). An
 * entry with no recorded language (everything before 1.3) is read exactly as
 * 1.2 read it, in the phone's language.
 */
class Speaker(context: Context) {

    enum class Outcome { SPEAKING, STOPPED, NOT_READY, NO_VOICE }

    private var ready = false
    private val tts = TextToSpeech(context.applicationContext) { status ->
        ready = status == TextToSpeech.SUCCESS
    }.apply { language = Locale.getDefault() }

    val isSpeaking: Boolean get() = runCatching { tts.isSpeaking }.getOrDefault(false)

    /** 1.2's call: the phone's language. Kept for text that is the app's own (Ask). */
    fun toggle(text: String) { toggle(text, null) }

    /** Read [text] in [languageTag] (the entry's), or stop if already reading. */
    fun toggle(text: String, languageTag: String?): Outcome {
        if (!ready) return Outcome.NOT_READY
        if (tts.isSpeaking) { tts.stop(); return Outcome.STOPPED }
        val locale = voiceLocale(languageTag) ?: Locale.getDefault()
        if (languageTag != null) {
            val available = runCatching { tts.isLanguageAvailable(locale) }
                .getOrDefault(TextToSpeech.LANG_NOT_SUPPORTED)
            if (!hasVoice(available)) return Outcome.NO_VOICE
        }
        runCatching { tts.language = locale }
        tts.speak(text, TextToSpeech.QUEUE_FLUSH, null, "entry")
        return Outcome.SPEAKING
    }

    fun stop() = runCatching { tts.stop() }
    fun release() = runCatching { tts.stop(); tts.shutdown() }

    companion object {
        /** The TTS locale for an entry tag; null means "no tag, use the phone's". */
        internal fun voiceLocale(languageTag: String?): Locale? =
            languageTag?.takeIf { it.isNotBlank() }
                ?.let { com.dailyvox.app.audio.LanguageTags.toLocale(it) }
                ?.takeIf { it.language.isNotEmpty() }

        /** LANG_AVAILABLE (0) and up are usable; MISSING_DATA (-1) and NOT_SUPPORTED (-2) are not. */
        internal fun hasVoice(availability: Int): Boolean = availability >= TextToSpeech.LANG_AVAILABLE
    }
}
