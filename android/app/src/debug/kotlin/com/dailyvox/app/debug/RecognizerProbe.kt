package com.dailyvox.app.debug

import android.content.ClipData
import android.content.ClipboardManager
import android.content.Context
import android.content.Intent
import android.os.Build
import android.os.Handler
import android.os.Looper
import android.speech.RecognitionSupport
import android.speech.RecognitionSupportCallback
import android.speech.RecognizerIntent
import android.speech.SpeechRecognizer
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import java.util.Locale

/**
 * DEBUG BUILDS ONLY (src/debug; src/release holds an empty stub).
 *
 * The multilingual plan's B-17 device probe, Android half: what this phone's
 * on-device recogniser says it can do, straight from
 * `SpeechRecognizer.checkRecognitionSupport`. Google publishes no on-device
 * list for most Indian languages, so whether hi-IN, ta-IN and pt-BR exist on a
 * given handset is something only the handset can answer. That answer gates the
 * Hindi decision (D2), and it has to come from real phones.
 *
 * Read-only. It asks; it never downloads, never records, and sends nothing:
 * the result is shown, logged under [TAG], and copyable to the clipboard.
 */
object RecognizerProbe {

    const val TAG = "DailyVoxProbe"

    /** The tags the plan needs a yes/no for, in its order. */
    val WATCH = listOf(
        "en-US", "en-IN", "hi-IN", "pt-BR", "es-ES", "es-US", "fr-FR", "de-DE", "it-IT",
        "ta-IN", "te-IN", "bn-IN", "mr-IN", "kn-IN", "ml-IN", "gu-IN",
    )

    data class Support(
        val installed: List<String>,
        val pending: List<String>,
        val supported: List<String>,
        val online: List<String>,
    )

    /** The state of [tag] across the lists, matching region-insensitively as a fallback. */
    internal fun status(tag: String, s: Support): String {
        fun has(list: List<String>) = list.any { it.replace('_', '-').equals(tag, true) }
        fun sameLang(list: List<String>) = list.filter {
            it.replace('_', '-').substringBefore('-').equals(tag.substringBefore('-'), true)
        }
        return when {
            has(s.installed) -> "INSTALLED"
            has(s.pending) -> "pending download"
            has(s.supported) -> "supported, not installed"
            sameLang(s.installed + s.pending + s.supported).isNotEmpty() ->
                "absent (same language: " + sameLang(s.installed + s.pending + s.supported).distinct().joinToString(", ") + ")"
            has(s.online) -> "online only (unusable: DailyVox is on-device only)"
            else -> "absent"
        }
    }

    internal fun report(header: List<String>, s: Support?, error: String?): String = buildString {
        header.forEach { appendLine(it) }
        if (s == null) {
            appendLine("checkRecognitionSupport: ${error ?: "no answer"}")
            return@buildString
        }
        appendLine("installed (${s.installed.size}): ${s.installed.sorted().joinToString(", ")}")
        appendLine("pending (${s.pending.size}): ${s.pending.sorted().joinToString(", ")}")
        appendLine("supported on-device (${s.supported.size}): ${s.supported.sorted().joinToString(", ")}")
        appendLine("online (${s.online.size}): ${s.online.sorted().joinToString(", ")}")
        appendLine("--")
        WATCH.forEach { appendLine("$it: ${status(it, s)}") }
    }

    private fun header(context: Context): List<String> = listOf(
        "device: ${Build.MANUFACTURER} ${Build.MODEL} (${Build.DEVICE})",
        "android: ${Build.VERSION.RELEASE} / API ${Build.VERSION.SDK_INT}",
        "locale: ${Locale.getDefault().toLanguageTag()}",
        "recognition available: ${SpeechRecognizer.isRecognitionAvailable(context)}",
        "on-device available: " +
            (Build.VERSION.SDK_INT >= 33 && SpeechRecognizer.isOnDeviceRecognitionAvailable(context)),
        "recogniser service: " + (runCatching {
            android.provider.Settings.Secure.getString(context.contentResolver, "voice_recognition_service")
        }.getOrNull() ?: "unknown"),
    )

    /** Calls [done] exactly once, on the main thread, within five seconds. */
    fun run(context: Context, done: (String) -> Unit) {
        val head = header(context)
        var settled = false
        fun finish(s: Support?, err: String?) {
            if (settled) return
            settled = true
            val text = report(head, s, err)
            text.lines().forEach { android.util.Log.i(TAG, it) }
            done(text)
        }
        if (Build.VERSION.SDK_INT < 33 || !SpeechRecognizer.isOnDeviceRecognitionAvailable(context)) {
            finish(null, "no on-device recogniser on this phone"); return
        }
        val rec = runCatching { SpeechRecognizer.createOnDeviceSpeechRecognizer(context) }
            .getOrElse { finish(null, "could not create: ${it.javaClass.simpleName}"); return }
        Handler(Looper.getMainLooper()).postDelayed({
            finish(null, "no answer within 5 s"); runCatching { rec.destroy() }
        }, 5_000)
        runCatching {
            rec.checkRecognitionSupport(
                Intent(RecognizerIntent.ACTION_RECOGNIZE_SPEECH).apply {
                    putExtra(RecognizerIntent.EXTRA_LANGUAGE_MODEL, RecognizerIntent.LANGUAGE_MODEL_FREE_FORM)
                },
                context.mainExecutor,
                object : RecognitionSupportCallback {
                    override fun onSupportResult(support: RecognitionSupport) {
                        finish(Support(
                            installed = support.installedOnDeviceLanguages,
                            pending = support.pendingOnDeviceLanguages,
                            supported = support.supportedOnDeviceLanguages,
                            online = support.onlineLanguages,
                        ), null)
                        runCatching { rec.destroy() }
                    }
                    override fun onError(error: Int) {
                        finish(null, "error $error"); runCatching { rec.destroy() }
                    }
                },
            )
        }.onFailure { finish(null, "threw ${it.javaClass.simpleName}"); runCatching { rec.destroy() } }
    }

    /** A Settings card. Only ever compiled into debug builds. */
    @Composable
    fun Card() {
        val context = LocalContext.current
        val scheme = MaterialTheme.colorScheme
        var result by remember { mutableStateOf<String?>(null) }
        Spacer(Modifier.height(10.dp))
        Column(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(scheme.surface)
                .padding(horizontal = 17.dp, vertical = 15.dp),
        ) {
            Text("SPEECH LANGUAGES · DEBUG BUILD", fontSize = 10.5.sp, letterSpacing = 1.2.sp,
                 fontWeight = FontWeight.SemiBold, color = scheme.onSurfaceVariant)
            Spacer(Modifier.height(9.dp))
            Row {
                Text(
                    "Probe recogniser", fontSize = 12.sp, fontWeight = FontWeight.Bold,
                    color = scheme.onPrimary,
                    modifier = Modifier.clip(RoundedCornerShape(14.dp)).background(scheme.primary)
                        .clickable { result = "asking…"; run(context) { result = it } }
                        .padding(horizontal = 14.dp, vertical = 9.dp),
                )
                result?.takeIf { it != "asking…" }?.let { text ->
                    Spacer(Modifier.width(8.dp))
                    Text(
                        "Copy", fontSize = 12.sp, fontWeight = FontWeight.Bold,
                        color = scheme.primary,
                        modifier = Modifier.clip(RoundedCornerShape(14.dp))
                            .clickable {
                                context.getSystemService(ClipboardManager::class.java)
                                    ?.setPrimaryClip(ClipData.newPlainText("recogniser probe", text))
                            }
                            .padding(horizontal = 14.dp, vertical = 9.dp),
                    )
                }
            }
            result?.let {
                Spacer(Modifier.height(10.dp))
                Text(it, fontFamily = com.dailyvox.app.ui.theme.DmMono, fontSize = 10.sp,
                     lineHeight = 14.sp, color = scheme.onSurface)
            }
        }
    }
}
