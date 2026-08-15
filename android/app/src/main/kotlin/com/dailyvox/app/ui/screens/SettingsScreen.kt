package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.ui.components.*

enum class ThemeChoice { LIGHT, DARK, SYSTEM }

/**
 * Settings, led by the Data Shield ledger.
 *
 * The ledger is first because it is the product's argument, and because every
 * line in it is a fact the user could verify themselves rather than a promise
 * they have to take. "Network calls, ever: 0" is checkable with airplane mode in
 * ten seconds, which is the point.
 */
@Composable
fun SettingsScreen(
    entryCount: Int,
    lockEnabled: Boolean = false,
    lockAvailable: Boolean = false,
    onLock: (Boolean) -> Unit = {},
    theme: ThemeChoice,
    onTheme: (ThemeChoice) -> Unit,
    onExport: () -> Unit,
    modifier: Modifier = Modifier,
) {
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(12.dp))
        ScreenTitle("Settings")

        MonoLabel("Your data shield")
        Spacer(Modifier.height(8.dp))
        DvCard {
            ShieldRow("Network calls, ever", "0")
            Divider()
            ShieldRow("Recordings uploaded", "0")
            Divider()
            ShieldRow("Analytics SDKs", "none")
            Divider()
            ShieldRow("Entries on this device", "$entryCount")
            Spacer(Modifier.height(12.dp))
            Text(
                "The app requests no INTERNET permission. You can confirm that in Android's app info, and everything here keeps working in airplane mode.",
                fontSize = 12.sp, lineHeight = 19.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(Modifier.height(22.dp))
        MonoLabel("Lock")
        Spacer(Modifier.height(8.dp))
        DvCard {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text(
                        if (lockAvailable) "Require unlock to open" else "No lock set on this device",
                        fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface,
                    )
                    Spacer(Modifier.height(3.dp))
                    Text(
                        if (lockAvailable) "Fingerprint, face, or your device PIN."
                        else "Set a screen lock in Android settings to enable this.",
                        fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                }
                Switch(checked = lockEnabled, onCheckedChange = onLock, enabled = lockAvailable)
            }
        }

        Spacer(Modifier.height(22.dp))
        MonoLabel("Appearance")
        Spacer(Modifier.height(8.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            ThemeChoice.entries.forEach { t ->
                val on = t == theme
                Text(
                    t.name.lowercase().replaceFirstChar { it.uppercase() },
                    fontSize = 14.sp,
                    color = if (on) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .weight(1f)
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (on) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.surfaceVariant)
                        .clickable { onTheme(t) }
                        .padding(vertical = 13.dp)
                        .wrapContentWidth(Alignment.CenterHorizontally),
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(
            "Dynamic colour is deliberately absent. Material's wallpaper theming replaces every colour role, so there is no setting where it leaves the palette alone — it would repaint the app and the sky with it.",
            fontSize = 12.sp, lineHeight = 19.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )

        Spacer(Modifier.height(22.dp))
        MonoLabel("Your data is yours")
        Spacer(Modifier.height(8.dp))
        DvCard(Modifier.clickable(onClick = onExport)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Export everything", fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
                MonoLabel("JSON + AES-256")
            }
            Spacer(Modifier.height(4.dp))
            Text("Two files: readable JSON you can take anywhere, and an AES-256-GCM backup sealed to this device.",
                 fontSize = 12.sp, lineHeight = 18.sp,
                 color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(Modifier.height(24.dp))
        Text(
            "DailyVox for Android · in development · free forever · open source\nData Not Collected — because there is nowhere to send it.",
            fontSize = 11.sp, lineHeight = 18.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(130.dp))
    }
}

@Composable
private fun ShieldRow(label: String, value: String) {
    Row(Modifier.fillMaxWidth().padding(vertical = 7.dp),
        horizontalArrangement = Arrangement.SpaceBetween) {
        Text(label, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface)
        Text(value, fontSize = 14.sp, color = MaterialTheme.colorScheme.secondary)
    }
}

@Composable
private fun Divider() {
    Box(Modifier.fillMaxWidth().height(1.dp)
        .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.12f)))
}
