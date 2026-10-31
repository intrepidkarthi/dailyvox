package com.dailyvox.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.RadioButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.R
import com.dailyvox.app.audio.LanguageTags
import com.dailyvox.app.audio.PackDownload
import com.dailyvox.app.audio.SpeakingOption
import com.dailyvox.app.audio.SpeechCapture
import com.dailyvox.app.audio.speakingOptions
import java.util.Locale

/**
 * "Language you speak" (plan B-8): the language the recogniser listens for,
 * separate from the app's own language.
 *
 * Offers only what the phone's on-device recogniser says it has or can fetch
 * (`checkRecognitionSupport`, asked fresh when this opens). Picking one that
 * is not installed asks the recogniser to download it, in ITS process -- this
 * app still holds no INTERNET permission. Nothing here ever falls back to
 * English: a language with no on-device model is shown as exactly that.
 */
@Composable
fun SpeakingLanguagePicker() {
    val context = LocalContext.current
    val scheme = MaterialTheme.colorScheme
    val capture = remember { SpeechCapture(context) }
    DisposableEffect(Unit) { onDispose { capture.release() } }

    var choice by remember { mutableStateOf(SpeechCapture.speakingLanguage(context)) }
    var installed by remember { mutableStateOf(SpeechCapture.installedPacks(context)) }
    var supported by remember { mutableStateOf(SpeechCapture.supportedPacks(context)) }
    var checking by remember { mutableStateOf(true) }
    var open by remember { mutableStateOf(false) }
    val pack by capture.pack.collectAsState()

    LaunchedEffect(Unit) {
        capture.refreshLanguages { i, s -> installed = i; supported = s; checking = false }
    }
    // A finished download changes what is installed; ask again so the row
    // says "On this phone" instead of still offering the download.
    LaunchedEffect(pack) {
        if (pack == PackDownload.Done) capture.refreshLanguages { i, s -> installed = i; supported = s }
    }

    val phone = Locale.getDefault()
    val options = speakingOptions(installed, supported, phone)
    val current = options.firstOrNull { o ->
        if (choice == null) o.tag == null else o.tag != null && LanguageTags.same(o.tag, choice!!)
    } ?: options.first()
    val currentTag = current.tag ?: phone.toLanguageTag()
    val currentName = LanguageTags.languageName(currentTag)
    val provider = runCatching {
        android.provider.Settings.Secure.getString(context.contentResolver, "voice_recognition_service")
    }.getOrNull()?.takeIf { it.contains("google", true) }?.let { "Google" }
        ?: stringResource(R.string.speak_lang_provider_fallback)

    Row(
        Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(vertical = 6.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Column(Modifier.weight(1f)) {
            Text(
                if (current.tag == null) stringResource(R.string.speak_lang_same_as_phone, current.label)
                else current.label,
                fontSize = 15.sp, fontWeight = FontWeight.Medium, color = scheme.onSurface,
            )
            Text(
                if (checking && installed.isEmpty()) stringResource(R.string.speak_lang_checking)
                else stateLabel(current.state),
                fontSize = 11.sp, color = scheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.width(8.dp))
        Text(
            stringResource(R.string.speak_lang_change), fontSize = 12.sp, fontWeight = FontWeight.Bold,
            color = scheme.onPrimary,
            modifier = Modifier.clip(RoundedCornerShape(14.dp)).background(scheme.primary)
                .clickable { open = true }.padding(horizontal = 14.dp, vertical = 9.dp),
        )
    }

    when (current.state) {
        SpeakingOption.State.NEEDS_DOWNLOAD -> {
            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.speak_lang_needs_download, currentName, provider),
                fontSize = 11.5.sp, lineHeight = 17.sp, color = scheme.onSurface,
            )
            val line = packLine(context.resources, pack)
            if (line != null) {
                Spacer(Modifier.height(4.dp))
                Text(line, fontSize = 11.sp, lineHeight = 16.sp, color = scheme.onSurfaceVariant)
            }
            if (pack == PackDownload.Idle || pack == PackDownload.Failed) {
                Spacer(Modifier.height(6.dp))
                TextButton(onClick = { capture.downloadPack(current.tag) }) {
                    Text(stringResource(R.string.speak_lang_download))
                }
            }
        }
        SpeakingOption.State.UNAVAILABLE -> {
            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.speak_lang_unavailable, currentName),
                fontSize = 11.5.sp, lineHeight = 17.sp, color = scheme.onSurface,
            )
        }
        SpeakingOption.State.ON_PHONE -> Unit
    }
    Spacer(Modifier.height(9.dp))
    Text(
        stringResource(R.string.speak_lang_explain),
        fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
    )

    if (open) AlertDialog(
        onDismissRequest = { open = false },
        title = { Text(stringResource(R.string.speak_lang_dialog_title)) },
        text = {
            Column(Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState())) {
                options.forEach { o ->
                    val selected = o == current
                    Row(
                        Modifier.fillMaxWidth().clickable {
                            open = false
                            SpeechCapture.setSpeakingLanguage(context, o.tag)
                            choice = o.tag
                            capture.clearError()
                            // One step: choosing a language that needs its pack
                            // asks for the pack (B-8, triggerModelDownload).
                            if (o.state == SpeakingOption.State.NEEDS_DOWNLOAD && o.tag != null) {
                                capture.downloadPack(o.tag)
                            }
                        }.padding(vertical = 4.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        RadioButton(selected = selected, onClick = null)
                        Spacer(Modifier.width(8.dp))
                        Column {
                            Text(
                                if (o.tag == null) stringResource(R.string.speak_lang_same_as_phone, o.label) else o.label,
                                fontSize = 15.sp,
                            )
                            Text(stateLabel(o.state), fontSize = 11.sp, color = scheme.onSurfaceVariant)
                        }
                    }
                }
            }
        },
        confirmButton = {},
        dismissButton = {
            TextButton(onClick = { open = false }) { Text(stringResource(R.string.speak_lang_cancel)) }
        },
    )
}

@Composable
private fun stateLabel(state: SpeakingOption.State): String = stringResource(
    when (state) {
        SpeakingOption.State.ON_PHONE -> R.string.speak_lang_state_on_phone
        SpeakingOption.State.NEEDS_DOWNLOAD -> R.string.speak_lang_state_download
        SpeakingOption.State.UNAVAILABLE -> R.string.speak_lang_state_unavailable
    }
)
