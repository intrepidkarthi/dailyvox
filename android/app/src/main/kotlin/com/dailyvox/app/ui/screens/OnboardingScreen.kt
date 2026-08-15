package com.dailyvox.app.ui.screens

import android.Manifest
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.ui.components.MonoLabel

/**
 * Onboarding, and the permission ledger is the whole idea.
 *
 * Most apps ask for the microphone and say nothing about what they did not ask
 * for. This screen shows all three rows — microphone REQUIRED, Health Connect
 * OPTIONAL, internet NOT REQUESTED — because the third one is the claim, and it
 * is the only one the user can check independently.
 *
 * The airplane-mode line is the design spec's strongest argument and it is
 * currently absent from the iOS app entirely. §8 of that spec lists it as
 * something iOS should adopt back; it ships here first.
 */
@Composable
fun OnboardingScreen(onDone: () -> Unit, modifier: Modifier = Modifier) {
    var granted by remember { mutableStateOf(false) }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        granted = it
        // Continue either way. A journal that refuses to open because you said
        // no to the microphone is punishing caution, and caution is the thing
        // this product is for.
        onDone()
    }

    Column(
        modifier.fillMaxSize().padding(horizontal = 26.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        MonoLabel("01 / 03 · permission")
        Spacer(Modifier.height(18.dp))
        Text(
            "Nothing you say leaves this phone.",
            style = MaterialTheme.typography.displayMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(14.dp))
        Text(
            "Transcription runs on your device. No account, no server, no analytics SDK. " +
                "Prove it: switch on airplane mode and record your first entry.",
            fontSize = 15.sp, lineHeight = 24.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.widthIn(max = 520.dp),
        )

        Spacer(Modifier.height(28.dp))
        LedgerRow("Microphone", "required", MaterialTheme.colorScheme.secondary)
        Spacer(Modifier.height(8.dp))
        LedgerRow("Health Connect", "optional", MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        LedgerRow("Internet", "not requested", Color(0xFF4F7A3E))

        Spacer(Modifier.height(30.dp))
        Text(
            "Allow microphone",
            fontSize = 16.sp, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onPrimary,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(MaterialTheme.colorScheme.primary)
                .clickable { ask.launch(Manifest.permission.RECORD_AUDIO) }
                .padding(vertical = 18.dp)
                .wrapContentWidth(Alignment.CenterHorizontally),
        )
        Spacer(Modifier.height(14.dp))
        Text(
            "See how it works first",
            fontSize = 14.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .clickable { onDone() }
                .padding(vertical = 12.dp)
                .wrapContentWidth(Alignment.CenterHorizontally),
        )
    }
}

@Composable
private fun LedgerRow(label: String, state: String, dot: Color) {
    Row(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(dot))
        Spacer(Modifier.width(12.dp))
        Text(label, fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface,
             modifier = Modifier.weight(1f))
        MonoLabel(state)
    }
}
