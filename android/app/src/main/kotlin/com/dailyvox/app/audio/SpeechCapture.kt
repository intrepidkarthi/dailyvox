package com.dailyvox.app.audio

import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionListener
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import java.util.Locale
import kotlinx.coroutines.channels.BufferOverflow
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow

/**
 * On-device speech capture.
 *
 * `createOnDeviceSpeechRecognizer` forces recognition to stay on the device --
 * it does not fall back to the network, it fails instead. That failure mode is
 * the correct one for this product: a journal that silently uploaded audio to
 * fill a gap would break the only promise it makes.
 *
 * It is the ONLY recognizer this class will construct. There is no second
 * branch, because every second branch anyone has written here has been a
 * network branch wearing a preference flag.
 *
 * The language asked for is the one the recogniser SAYS it has an offline pack
 * for, discovered once by [probeLanguages] and cached — not the phone's locale,
 * which is what this used to send and which fails on any device whose locale and
 * installed pack differ by region.
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
    /** The fix is a missing offline pack, which [SpeechCapture.downloadPack] can ask for. */
    val offerDownload: Boolean = false,
)

/** Where a [SpeechCapture.downloadPack] request has got to. */
sealed interface PackDownload {
    data object Idle : PackDownload
    data object Requested : PackDownload
    data class Progress(val percent: Int) : PackDownload
    /** The recogniser accepted it but will fetch later, e.g. on Wi-Fi. */
    data object Scheduled : PackDownload
    data object Done : PackDownload
    data object Failed : PackDownload
}

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

    fun clearError() {
        _error.value = null
        // A finished or failed download belongs to the card being dismissed.
        if (_pack.value !is PackDownload.Requested && _pack.value !is PackDownload.Progress) _pack.value = PackDownload.Idle
    }

    private val _pack = MutableStateFlow<PackDownload>(PackDownload.Idle)
    val pack: StateFlow<PackDownload> = _pack

    /**
     * Ask the phone's recogniser to fetch its own offline pack.
     *
     * The download happens in the RECOGNISER's process, over its connection --
     * exactly as the pack would arrive from Android Settings. DailyVox still
     * holds no INTERNET permission and no audio moves anywhere; this sends a
     * language tag, not a recording. The platform may show its own approval
     * prompt, and may only schedule the fetch, so the outcome is reported as
     * what it is rather than as "fixed".
     *
     * API 33 has only the fire-and-forget form; 34 adds a listener.
     */
    fun downloadPack() {
        if (!onDeviceAvailable) { _pack.value = PackDownload.Failed; return }
        val rec = runCatching { SpeechRecognizer.createOnDeviceSpeechRecognizer(context) }
            .getOrNull() ?: run { _pack.value = PackDownload.Failed; return }
        val intent = Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_LANGUAGE, Locale.getDefault().toLanguageTag())
        }
        // The next session must re-ask what is installed, or it keeps
        // requesting the stale (absent) language it cached before the download.
        prefs.edit().remove(LANG_KEY).remove(PROBED_KEY).apply()
        _pack.value = PackDownload.Requested
        if (Build.VERSION.SDK_INT >= 34) {
            val ok = runCatching {
                rec.triggerModelDownload(intent, context.mainExecutor,
                    object : android.speech.ModelDownloadListener {
                        override fun onProgress(completedPercent: Int) {
                            _pack.value = PackDownload.Progress(completedPercent)
                        }
                        override fun onSuccess() {
                            // The card stays up saying so, with Try again. Clearing
                            // the error here made the card vanish on success, which
                            // on a real phone read as the button having done nothing.
                            _pack.value = PackDownload.Done
                            runCatching { rec.destroy() }
                        }
                        override fun onScheduled() {
                            _pack.value = PackDownload.Scheduled
                            runCatching { rec.destroy() }
                        }
                        override fun onError(error: Int) {
                            android.util.Log.w(TAG, "triggerModelDownload error=$error")
                            _pack.value = PackDownload.Failed
                            runCatching { rec.destroy() }
                        }
                    })
            }.isSuccess
            if (!ok) { _pack.value = PackDownload.Failed; runCatching { rec.destroy() } }
        } else {
            // No callback on 33: the request is all we can truthfully report.
            if (runCatching { rec.triggerModelDownload(intent) }.isFailure) _pack.value = PackDownload.Failed
            runCatching { rec.destroy() }
        }
    }

    /**
     * A session that captured audio and produced no words.
     *
     * Separate from [finished] on purpose. `finished` only ever carried
     * non-blank text, so when transcription failed nothing was emitted at all —
     * and the collector in SpeakScreen is where `recorder.stop()` lives. The
     * recording was therefore never even closed, let alone saved. The failure
     * was not "no transcript", it was **the user's words deleted**, silently,
     * on a device where the recogniser does not work.
     *
     * The Journal's voice-search box also collects [finished] and must not act
     * on an empty result, which is why this is a second flow rather than a
     * blank string on the first one.
     */
    private val _unrecognised = MutableSharedFlow<Unit>(
        replay = 0, extraBufferCapacity = 1, onBufferOverflow = BufferOverflow.DROP_OLDEST,
    )
    val unrecognised: SharedFlow<Unit> = _unrecognised

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

    private val prefs
        get() = context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)

    /**
     * The language tag the recogniser actually holds an on-device pack for.
     *
     * Nothing set this before, so every session ran in the phone's default
     * locale — and that is the single most likely reason a phone that CAN
     * transcribe reports that it cannot. A device set to en-IN whose installed
     * pack is en-US fails with ERROR_LANGUAGE_UNAVAILABLE, and the app read
     * that as "no pack installed" and told the user to go and download one they
     * already had. Asking the recogniser what it has, and then asking it for
     * that, is the difference between working and not on a lot of hardware.
     *
     * Cached because the answer only changes when the user installs a pack, and
     * re-probing on every tap costs a recognizer construction.
     */
    private var language: String?
        get() = prefs.getString(LANG_KEY, null)
        set(v) { prefs.edit().putString(LANG_KEY, v).apply() }

    /** Every on-device pack the recogniser reports, for the error message. */
    private var installed: List<String>
        get() = prefs.getString(INSTALLED_KEY, null)
            ?.split(",")?.filter { it.isNotBlank() }.orEmpty()
        set(v) { prefs.edit().putString(INSTALLED_KEY, v.joinToString(",")).apply() }

    /**
     * A recogniser that answers NOTHING is the failure this class did not model.
     *
     * Every other outcome arrives as a callback, so every other outcome could be
     * handled. `startListening` binding to a service that then goes quiet
     * produces no `onReadyForSpeech`, no `onError`, no `onRmsChanged` -- and the
     * state machine has no way back:
     *
     *   tap 1  ->  state RECORDING, nothing ever fires
     *   tap 2  ->  reads as "stop", state PROCESSING, still nothing fires
     *   tap 3+ ->  start() returns at `state != IDLE`, forever
     *
     * The button is then dead for the life of the process, with no error card,
     * which is precisely "I tap it and nothing happens". Observed on a OnePlus
     * handset. The watchdog is the floor under that: any sign of life cancels
     * it, and silence past the deadline is reported as the failure it is.
     */
    private val main = Handler(Looper.getMainLooper())
    private var watchdog: Runnable? = null

    private fun arm(ms: Long, onSilence: () -> Unit) {
        disarm()
        val r = Runnable { watchdog = null; onSilence() }
        watchdog = r
        main.postDelayed(r, ms)
    }

    /** Called from every callback: the recogniser is talking, so stop counting. */
    private fun disarm() {
        watchdog?.let { main.removeCallbacks(it) }
        watchdog = null
    }

    fun start() {
        if (_state.value != State.IDLE) return
        kept.setLength(0)
        abandoned = false
        // Probe once per install, before the first session rather than after a
        // failure: the answer picks the language AND writes the error message,
        // and recovering from an error mid-recording means throwing away the
        // words that were already spoken.
        if (language == null && !prefs.getBoolean(PROBED_KEY, false)) {
            probeLanguages { beginSession() }
            return
        }
        beginSession()
    }

    /**
     * Ask the recogniser which languages it can do offline, then carry on.
     *
     * `checkRecognitionSupport` is API 33 and reports installed, pending and
     * merely-supported languages separately — only the first kind works with no
     * network, so only the first kind is recorded here.
     *
     * Always calls [then], including on failure. A phone that will not answer
     * the question should still get a recording attempt: the attempt produces a
     * real error code, which is better than a probe's silence.
     */
    private fun probeLanguages(then: () -> Unit) {
        if (!onDeviceAvailable) { then(); return }
        val probe = runCatching { SpeechRecognizer.createOnDeviceSpeechRecognizer(context) }
            .getOrNull() ?: run { then(); return }
        var settled = false
        fun done(langs: List<String>) {
            if (settled) return
            settled = true
            prefs.edit().putBoolean(PROBED_KEY, true).apply()
            installed = langs
            language = pick(langs)
            runCatching { probe.destroy() }
            then()
        }
        // A recogniser that never answers must not cost the user the tap.
        // `checkRecognitionSupport` is a bound service call into somebody
        // else's process, and there is no contract that it replies at all --
        // an OEM that stays silent would leave `then` uncalled and the Speak
        // button dead on touch, with no error, which is exactly the silent
        // failure this class already had once. Two seconds, then record anyway
        // in the platform default and let the real error code speak.
        Handler(Looper.getMainLooper()).postDelayed({ done(emptyList()) }, PROBE_TIMEOUT_MS)
        runCatching {
            probe.checkRecognitionSupport(
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                },
                context.mainExecutor,
                object : RecognitionSupportCallback {
                    override fun onSupportResult(support: RecognitionSupport) {
                        done(support.installedOnDeviceLanguages)
                    }
                    override fun onError(error: Int) = done(emptyList())
                },
            )
        }.onFailure { done(emptyList()) }
    }

    /**
     * Which installed pack to speak to, given the phone's locale.
     *
     * Exact tag first, then any pack in the same LANGUAGE — en-US is the right
     * answer for a phone set to en-IN, and the wrong answer is to fail. Falls
     * back to whatever single pack exists, because a recogniser with one
     * language is better used than not.
     */
    private fun pick(langs: List<String>): String? {
        if (langs.isEmpty()) return null
        val want = Locale.getDefault()
        val tag = want.toLanguageTag()
        langs.firstOrNull { it.equals(tag, true) }?.let { return it }
        langs.firstOrNull { it.replace('_', '-').substringBefore('-')
            .equals(want.language, true) }?.let { return it }
        return langs.first()
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
        // On-device or not at all. The generic recognizer used to stand in here
        // whenever no on-device one was available, with EXTRA_PREFER_OFFLINE set
        // -- and a preference is not a guarantee. Google's recognizer honours it
        // when a pack is installed and goes to its own servers when one is not.
        // That path uploaded the audio while onboarding said "Nothing left your
        // phone", and it needed no INTERNET permission of ours to do it: the
        // upload happens in the recognizer's process, not this one. Which is
        // also why the manifest cannot be the whole proof the listing says it is.
        if (!onDeviceAvailable) {
            _error.value = noOnDeviceRecogniser()
            _state.value = State.IDLE
            return false
        }
        // Guarded. This throws on a device whose configured on-device
        // recogniser component does not resolve, and the call site is a Compose
        // onTap lambda -- so an unguarded throw here takes the app down on the
        // press of the one button the product is built around.
        val r = runCatching { SpeechRecognizer.createOnDeviceSpeechRecognizer(context) }
            .getOrElse {
                _error.value = recogniserUnreachable()
                _state.value = State.IDLE
                return false
            }
        recognizer = r
        r.setRecognitionListener(object : RecognitionListener {
            override fun onReadyForSpeech(params: Bundle?) {
                android.util.Log.i(TAG, "onReadyForSpeech")
                disarm(); _state.value = State.RECORDING
            }
            override fun onBeginningOfSpeech() { disarm() }
            // 0..10 dB-ish; normalised for the button's pulse.
            override fun onRmsChanged(rms: Float) {
                disarm()
                _level.value = (rms / 10f).coerceIn(0f, 1f)
            }
            override fun onBufferReceived(buffer: ByteArray?) {}
            // Not while pausing or discarding: the session is ending because we
            // asked it to, and flipping to PROCESSING would drop the dial for a
            // frame on its way to PAUSED.
            override fun onEndOfSpeech() {
                if (!pausing && !abandoned) _state.value = State.PROCESSING
                // Listening is over and the transcript is owed. If it never
                // arrives, keep the words already heard rather than stranding
                // the entry in PROCESSING with no button that works.
                armResults()
            }
            override fun onError(error: Int) {
                android.util.Log.w(TAG, "onError code=$error")
                disarm()
                // A discarded session raises ERROR_CLIENT on its way out. That
                // is us, not the phone, and an error card for it would be a lie.
                if (!abandoned && !pausing) _error.value = describe(error)
                finish("")
            }
            override fun onResults(results: Bundle?) {
                android.util.Log.i(TAG, "onResults n=" +
                    (results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.size ?: -1))
                disarm()
                finish(results?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)?.firstOrNull().orEmpty())
            }
            override fun onPartialResults(partialResults: Bundle?) {
                disarm()
                partialResults?.getStringArrayList(SpeechRecognizer.RESULTS_RECOGNITION)
                    ?.firstOrNull()?.let { _partial.value = it }
            }
            override fun onEvent(eventType: Int, params: Bundle?) {}
        })
        r.startListening(Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
            putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
            putExtra(RecognizerIntent.EXTRA_PARTIAL_RESULTS, true)
            putExtra(RecognizerIntent.EXTRA_PREFER_OFFLINE, true)
            // The pack the recogniser told us it has. Unset means the probe
            // found nothing or never ran, and the platform default is then the
            // best remaining guess.
            language?.let { putExtra(RecognizerIntent.EXTRA_LANGUAGE, it) }
            // Custom vocabulary. Biasing strings landed in API 33 alongside the
            // on-device recognizer, and asking for the extra on older platforms
            // is harmless -- an unknown extra is ignored, never rejected.
            val bias = com.dailyvox.app.system.Vocabulary.get(context)
            if (bias.isNotEmpty() && Build.VERSION.SDK_INT >= 33) {
                putExtra(RecognizerIntent.EXTRA_BIASING_STRINGS, bias.toTypedArray())
            }
        })
        _state.value = State.RECORDING
        // From here the recogniser owes us a callback. Anything it says cancels
        // this; saying nothing surfaces an error and puts the button back.
        arm(START_TIMEOUT_MS) {
            _error.value = recogniserSilent()
            recognizer?.let { runCatching { it.cancel() } }
            pausing = false
            // Through finish(), not straight to IDLE: finish is what emits
            // `unrecognised`, and that is the only signal that makes the screen
            // stop the MediaRecorder and keep the audio. Skipping it here left
            // the mic held and the .m4a orphaned -- on exactly the silent
            // recogniser this watchdog exists for.
            finish("")
        }
        return true
    }

    /**
     * The transcript is owed after listening stops. Salvage the partial if it
     * never comes: partial results are what was actually heard, and handing back
     * a slightly rough entry beats losing it to a recogniser that went quiet.
     */
    private fun armResults() = arm(RESULT_TIMEOUT_MS) {
        if (_state.value != State.PROCESSING) return@arm
        android.util.Log.w(TAG, "recogniser produced no result within ${RESULT_TIMEOUT_MS}ms")
        finish(_partial.value)
    }

    fun stop() {
        when (_state.value) {
            State.RECORDING -> {
                _state.value = State.PROCESSING
                recognizer?.stopListening()
                // Not only in onEndOfSpeech: a recogniser that never reached
                // onReadyForSpeech will not send that either, and this is the
                // tap that would otherwise wedge the state at PROCESSING for
                // good.
                armResults()
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
        disarm()
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
        if (whole.isNotBlank()) {
            _finished.tryEmit(whole)
            return
        }
        // A session that ends with NOTHING must never end quietly.
        //
        // The first watchdog only covered a recogniser that said nothing at
        // all. A OnePlus showed the other shape: it fires onRmsChanged, so it
        // is plainly alive and the start watchdog disarms -- and then no result
        // and no error ever arrive. The results watchdog then salvaged the
        // partial, the partial was empty, and finish("") walked back to IDLE
        // reporting nothing. "No voice recorded, no error thrown" is that path.
        //
        // Guarding it here rather than at the call site covers every route into
        // finish(), including ones nobody has hit yet. Only speaks when nothing
        // else already has: onError sets a specific message first, and this
        // must not overwrite a better one.
        if (_error.value == null) _error.value = nothingCameBack()
        // Tell the screen there IS audio worth keeping, even with no words.
        _unrecognised.tryEmit(Unit)
    }

    fun release() { disarm(); recognizer?.destroy(); recognizer = null }

    private companion object {
        const val TAG = "DailyVoxSpeech"
        const val LANG_KEY = "recogniser_language"
        const val INSTALLED_KEY = "recogniser_installed"
        const val PROBED_KEY = "recogniser_probed"
        const val PROBE_TIMEOUT_MS = 2_000L
        /** onReadyForSpeech normally lands in well under a second. */
        const val START_TIMEOUT_MS = 6_000L
        /** Generous: real transcription of a long entry takes a few seconds. */
        const val RESULT_TIMEOUT_MS = 15_000L
    }

    /**
     * The one that matters is ERROR_LANGUAGE_UNAVAILABLE (13): the language is
     * supported but its offline pack is not downloaded. This app holds no
     * INTERNET permission, so it cannot fetch that pack itself — but it can ask the
     * recogniser to, which is [downloadPack]. The
     * message therefore has to point at the place the user can fix it, rather
     * than apologise and leave them stuck.
     *
     * Observed on a clean Pixel emulator as "LANGUAGE_PACK_ERROR with error
     * code 13", which is precisely the case the port plan flagged as untested.
     */
    /**
     * Two dead ends, and only one of them is the user's to fix. Below API 33 the
     * on-device recognizer does not exist at all, so no setting reaches it; from
     * 33 the language pack is a download away. minSdk keeps the first case off
     * phones that install from Play -- it stays for sideloads, and for the day
     * someone lowers minSdk back without reading this file.
     */
    private fun noOnDeviceRecogniser(): CaptureError =
        if (Build.VERSION.SDK_INT < 33) CaptureError(
            message = "This version of Android has no on-device speech recogniser.",
            fix = "DailyVox needs Android 13 or newer -- that is the version where offline recognition arrived. It will not transcribe over a network on any version.",
        ) else CaptureError(
            message = "No offline speech pack is installed for your language yet.",
            fix = "Your phone's speech service can download it now. DailyVox still has no internet permission and sends nothing -- the pack comes to your phone, your voice never leaves it.",
            openLanguageSettings = true,
            offerDownload = true,
        )

    /**
     * The recogniser took the request and said nothing. Not a language problem,
     * not a permission problem, and NOT something the user can fix in speech
     * settings -- so it must not send them there, which is what every other
     * failure message on this screen does.
     */
    private fun recogniserSilent() = CaptureError(
        message = "This phone's speech recogniser accepted the recording and never responded.",
        fix = "Tap to try again. If it keeps happening, check that Android's speech " +
            "service (Settings \u203a Apps \u203a Default apps \u203a Digital assistant app, " +
            "or Speech Recognition & Synthesis in the app list) is enabled and not " +
            "battery-restricted -- some OEM builds ship it disabled.",
    )

    /**
     * The session ended with no words and no explanation from the recogniser.
     *
     * Distinct from [recogniserSilent], which is "it never answered at all".
     * This one heard audio -- the level meter moved -- and then returned an
     * empty result with no error code, which is a recogniser fault rather than
     * anything the user did wrong. Say so, rather than implying they were too
     * quiet.
     */
    private fun nothingCameBack() = CaptureError(
        message = "The recogniser finished without returning any words.",
        fix = "Tap to try again. If it keeps happening, this phone's speech " +
            "service is not transcribing \u2014 check that Speech Recognition & " +
            "Synthesis is enabled and not battery-restricted in Android " +
            "Settings \u203a Apps, and that an offline language is installed under " +
            "System \u203a Languages \u203a Speech.",
        openLanguageSettings = true,
    )

    /** Construction failed outright: the configured component does not resolve. */
    private fun recogniserUnreachable() = CaptureError(
        message = "This phone's on-device speech recogniser could not be started.",
        fix = "It is listed as available but will not open. Check that Speech " +
            "Recognition & Synthesis is installed and enabled in Settings \u203a Apps.",
    )

    private fun describe(code: Int): CaptureError = when (code) {
        // Says which packs the recogniser DOES have, when it has any. The flat
        // "no pack for your language" was wrong often enough to be misleading:
        // the usual case is a phone with en-US installed and a locale of en-IN,
        // where the pack exists and the request was simply for the wrong tag.
        // Naming what is installed is also the only way a user can tell the two
        // situations apart from inside the app.
        SpeechRecognizer.ERROR_LANGUAGE_UNAVAILABLE,
        SpeechRecognizer.ERROR_LANGUAGE_NOT_SUPPORTED -> CaptureError(
            message = installed.takeIf { it.isNotEmpty() }?.let {
                "This phone's speech packs (${it.joinToString(", ")}) could not " +
                    "handle ${Locale.getDefault().toLanguageTag()}."
            } ?: "This phone has no offline speech pack installed yet.",
            fix = "Your phone's speech service can download the pack now. DailyVox still has no internet permission and sends nothing -- the pack comes to your phone, your voice never leaves it.",
            openLanguageSettings = true,
            offerDownload = true,
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
            fix = "Download the offline pack for your language and it will work with no network at all. DailyVox will not transcribe over a network.",
            openLanguageSettings = true,
            offerDownload = true,
        )
        else -> CaptureError(
            message = "The recogniser stopped unexpectedly.",
            fix = "Tap to try again.",
        )
    }
}
