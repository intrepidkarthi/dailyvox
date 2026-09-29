package com.dailyvox.app.ui.components

import android.content.Context
import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.audio.CaptureError
import com.dailyvox.app.audio.PackDownload
import com.dailyvox.app.audio.SpeechCapture

/**
 * The one place a speech failure is shown. Speak, onboarding and journal search
 * each used to carry their own copy of this card, and the three had already
 * drifted in padding and wording before the download action existed to drift
 * as well.
 *
 * When the fault is a missing offline pack, the primary action asks the
 * recogniser to fetch it ([SpeechCapture.downloadPack]); Settings stays as the
 * fallback for a phone that refuses.
 */
@Composable
fun SpeechErrorCard(
    err: CaptureError,
    capture: SpeechCapture,
    secondaryLabel: String,
    onSecondary: () -> Unit,
    modifier: Modifier = Modifier,
    compact: Boolean = false,
) {
    val context = LocalContext.current
    val pack by capture.pack.collectAsState()
    val cs = MaterialTheme.colorScheme

    Column(
        modifier.fillMaxWidth()
            .clip(RoundedCornerShape(if (compact) 14.dp else 18.dp))
            .background(cs.surface)
            .padding(if (compact) 14.dp else 16.dp),
    ) {
        Text(err.message, fontSize = if (compact) 13.sp else 14.sp,
             fontWeight = FontWeight.SemiBold, color = cs.onSurface)
        Spacer(Modifier.height(6.dp))
        Text(packLine(pack) ?: err.fix, fontSize = if (compact) 12.sp else 13.sp,
             lineHeight = if (compact) 18.sp else 20.sp, color = cs.onSurfaceVariant)
        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val downloading = pack is PackDownload.Requested || pack is PackDownload.Progress
            when {
                err.offerDownload && pack == PackDownload.Idle ->
                    Pill("Download speech pack", primary = true, compact) { capture.downloadPack() }
                err.offerDownload && pack == PackDownload.Done ->
                    Pill("Try again", primary = true, compact) { capture.clearError() }
                err.openLanguageSettings && !downloading ->
                    Pill("Open speech settings", primary = !err.offerDownload || pack == PackDownload.Failed, compact) {
                        openSpeechSettings(context)
                    }
            }
            if (!downloading) Pill(secondaryLabel, primary = false, compact, onSecondary)
        }
    }
}

private fun packLine(p: PackDownload): String? = when (p) {
    PackDownload.Idle -> null
    PackDownload.Requested -> "Asking your phone's speech service for the pack…"
    is PackDownload.Progress -> "Downloading the speech pack · ${p.percent}%"
    PackDownload.Scheduled -> "Your phone will download the pack shortly, usually on Wi-Fi. Record whenever you like — entries keep their audio until it arrives."
    PackDownload.Done -> "Speech pack installed. Your voice stays on this phone."
    PackDownload.Failed -> "Your phone's speech service would not download it from here. It can be installed in Android Settings › System › Languages › Speech."
}

@Composable
private fun Pill(text: String, primary: Boolean, compact: Boolean, onClick: () -> Unit) {
    val cs = MaterialTheme.colorScheme
    Text(
        text,
        fontSize = if (compact) 12.5.sp else 13.sp,
        fontWeight = FontWeight.SemiBold,
        color = if (primary) cs.onPrimary else cs.onSurfaceVariant,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .then(if (primary) Modifier.background(cs.primary) else Modifier)
            .clickable(onClick = onClick)
            .padding(horizontal = if (compact) 12.dp else 16.dp, vertical = if (compact) 8.dp else 11.dp),
    )
}

/**
 * Deep-link where it exists; the general language screen is the fallback, since
 * the voice-input screen is not on every OEM.
 */
fun openSpeechSettings(context: Context) {
    listOf(
        "com.android.settings.VOICE_INPUT_SETTINGS",
        android.provider.Settings.ACTION_VOICE_INPUT_SETTINGS,
        android.provider.Settings.ACTION_LOCALE_SETTINGS,
    ).firstOrNull { action ->
        runCatching {
            context.startActivity(Intent(action).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        }.isSuccess
    }
}
