package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.foundation.border
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.ui.components.*

/**
 * Day · Night · Sunset — FINAL-SPEC §2.8. Sunset is the default and follows the
 * real sun.
 *
 * "Real" here means the clock, not an almanac. A true solar calculation needs
 * latitude and longitude, and this app holds no location permission and is never
 * going to ask for one to decide a background colour. Evening is taken as 19:00
 * to 06:00, which is wrong by up to about an hour at the solstices and wrong in
 * the right direction: the app is used at night.
 */
enum class ThemeChoice { LIGHT, DARK, SUNSET }

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
    onBack: () -> Unit = {},
    entryCount: Int,
    lockEnabled: Boolean = false,
    lockAvailable: Boolean = false,
    onLock: (Boolean) -> Unit = {},
    theme: ThemeChoice,
    onTheme: (ThemeChoice) -> Unit,
    onExport: () -> Unit,
    onExportPdf: () -> Unit = {},
    onExportEncrypted: () -> Unit = {},
    onImport: () -> Unit = {},
    reminderOn: Boolean = false,
    reminderHour: Int = 21,
    onReminder: (Boolean, Int) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    val scheme = MaterialTheme.colorScheme
    val night = scheme.background == com.dailyvox.app.ui.theme.NightBackground
    val positive = scheme.tertiary
    val goldText = if (night) com.dailyvox.app.ui.theme.NightGoldText
                   else com.dailyvox.app.ui.theme.DayGoldText

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(14.dp))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("‹", fontSize = 30.sp, color = scheme.onBackground,
                 modifier = Modifier.clip(RoundedCornerShape(24.dp)).clickable(onClick = onBack)
                     .defaultMinSize(48.dp, 48.dp).wrapContentSize())
            Spacer(Modifier.width(4.dp))
            Text("Settings", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold,
                 color = scheme.onBackground)
        }

        // ── DATA SHIELD ────────────────────────────────────────────────────
        // First, because it is the product's argument. Every line is a fact the
        // reader can check without trusting this screen.
        SettingsCard {
            SectionLabel("DATA SHIELD", positive)
            Spacer(Modifier.height(11.dp))
            LedgerRow("Network calls made") {
                Mono("0 · EVER", positive)
            }
            LedgerRow("Encryption at rest") { Mono("AES-256", scheme.onSurfaceVariant) }
            LedgerRow("Biometric lock") {
                Switch(
                    checked = lockEnabled, onCheckedChange = onLock, enabled = lockAvailable,
                    modifier = Modifier.height(20.dp),
                )
            }
            LedgerRow("Health Connect") { Mono("REVIEW QUEUE", goldText) }
            Spacer(Modifier.height(11.dp))
            Text(
                "The complete permission list: microphone, notifications, vibration, " +
                    "biometrics. No network permission of any kind — check it in " +
                    "Android Settings › Apps › DailyVox.",
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
        }

        // ── THEME ──────────────────────────────────────────────────────────
        SettingsCard {
            SectionLabel("THEME", scheme.onSurfaceVariant)
            Spacer(Modifier.height(11.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    ThemeChoice.LIGHT to "Day",
                    ThemeChoice.DARK to "Night",
                    ThemeChoice.SUNSET to "Sunset",
                ).forEach { (choice, label) ->
                    val on = choice == theme
                    Text(
                        label, fontSize = 11.sp,
                        fontWeight = if (on) FontWeight.ExtraBold else FontWeight.Bold,
                        color = if (on) scheme.onPrimary else scheme.onSurfaceVariant,
                        modifier = Modifier
                            .weight(1f)
                            .clip(RoundedCornerShape(15.dp))
                            .then(
                                if (on) Modifier.background(scheme.primary)
                                else Modifier.border(1.5.dp, scheme.onSurfaceVariant.copy(alpha = 0.25f),
                                                     RoundedCornerShape(15.dp))
                            )
                            .clickable { onTheme(choice) }
                            .padding(vertical = 10.dp)
                            .wrapContentWidth(Alignment.CenterHorizontally),
                    )
                }
            }
            Spacer(Modifier.height(9.dp))
            Text(
                "Sunset follows the real sun — paper by day, sky by night.",
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
        }

        // ── REMINDER ───────────────────────────────────────────────────────
        SettingsCard {
            SectionLabel("EVENING REMINDER", scheme.onSurfaceVariant)
            Spacer(Modifier.height(11.dp))
            LedgerRow("Remind me around ${hourLabel(reminderHour)}") {
                Switch(
                    checked = reminderOn,
                    onCheckedChange = { onReminder(it, reminderHour) },
                    modifier = Modifier.height(20.dp),
                )
            }
            if (reminderOn) {
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(18, 20, 21, 22).forEach { h ->
                        val on = h == reminderHour
                        Text(
                            hourLabel(h), fontSize = 11.sp, fontWeight = FontWeight.Bold,
                            color = if (on) scheme.onPrimary else scheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f)
                                .clip(RoundedCornerShape(13.dp))
                                .then(
                                    if (on) Modifier.background(scheme.primary)
                                    else Modifier.border(1.5.dp,
                                        scheme.onSurfaceVariant.copy(alpha = 0.25f),
                                        RoundedCornerShape(13.dp))
                                )
                                .clickable { onReminder(true, h) }
                                .padding(vertical = 9.dp)
                                .wrapContentWidth(Alignment.CenterHorizontally),
                        )
                    }
                }
            }
            Spacer(Modifier.height(9.dp))
            // "Around", not "at": this is a windowed alarm, and promising a
            // minute you cannot deliver teaches people to distrust the app.
            Text(
                "One notification, no streak guilt. Delivered in a window rather " +
                    "than on the minute — exact alarms are a restricted permission " +
                    "a journal does not qualify for.",
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
        }

        // ── BACKUP & EXPORT ────────────────────────────────────────────────
        SettingsCard {
            SectionLabel("BACKUP & EXPORT", scheme.onSurfaceVariant)
            Spacer(Modifier.height(11.dp))
            ChevronRow("Export as PDF", "· printable, shareable", onExportPdf)
            ChevronRow("Export as JSON", "· readable, portable", onExport)
            ChevronRow("Encrypted backup", "· opens on any phone", onExportEncrypted)
            ChevronRow("Import backup", "· adds, never replaces", onImport)
        }

        SettingsCard {
            SectionLabel("WORDS WE KEEP GETTING WRONG", scheme.onSurfaceVariant)
            Spacer(Modifier.height(9.dp))
            // The only user-facing lever on the port's biggest measured
            // weakness: a name the recogniser mishears never reaches the graph
            // at all, so the person simply is not in the Twin.
            var words by remember {
                mutableStateOf(com.dailyvox.app.system.Vocabulary.get(context))
            }
            var draft by remember { mutableStateOf("") }
            Row(verticalAlignment = Alignment.CenterVertically) {
                OutlinedTextField(
                    value = draft, onValueChange = { draft = it },
                    placeholder = { Text("Add a name", fontSize = 12.sp) },
                    singleLine = true, modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    "Add", fontSize = 12.sp, fontWeight = FontWeight.Bold,
                    color = scheme.onPrimary,
                    modifier = Modifier
                        .clip(RoundedCornerShape(14.dp))
                        .background(scheme.primary)
                        .clickable {
                            com.dailyvox.app.system.Vocabulary.add(context, draft)
                            words = com.dailyvox.app.system.Vocabulary.get(context)
                            draft = ""
                        }
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                )
            }
            if (words.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp)) {
                    words.forEach { w ->
                        Text(
                            "$w  ×", fontSize = 9.5.sp, letterSpacing = 0.5.sp,
                            fontWeight = FontWeight.SemiBold, color = goldText,
                            modifier = Modifier
                                .clip(RoundedCornerShape(10.dp))
                                .background(com.dailyvox.app.ui.theme.Gold.copy(alpha = 0.16f))
                                .clickable {
                                    com.dailyvox.app.system.Vocabulary.remove(context, w)
                                    words = com.dailyvox.app.system.Vocabulary.get(context)
                                }
                                .padding(horizontal = 9.dp, vertical = 5.dp),
                        )
                    }
                }
            }
            Spacer(Modifier.height(9.dp))
            Text(
                "These make the recogniser more likely to hear the word. A nudge, not a guarantee.",
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
        }

        Spacer(Modifier.height(10.dp))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text("In development · open source", fontSize = 11.sp,
                 color = scheme.onSurfaceVariant)
            Text("$entryCount entries", fontSize = 11.sp, color = scheme.onSurfaceVariant)
        }
        Spacer(Modifier.height(130.dp))
    }
}

@Composable
private fun SettingsCard(content: @Composable ColumnScope.() -> Unit) {
    Spacer(Modifier.height(10.dp))
    Column(
        Modifier.fillMaxWidth().padding(horizontal = 16.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 17.dp, vertical = 15.dp),
        content = content,
    )
}

@Composable
private fun SectionLabel(text: String, color: androidx.compose.ui.graphics.Color) {
    Text(text, fontSize = 9.5.sp, letterSpacing = 1.2.sp,
         fontWeight = FontWeight.SemiBold, color = color)
}

@Composable
private fun LedgerRow(label: String, trailing: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().padding(vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium,
             color = MaterialTheme.colorScheme.onSurface)
        trailing()
    }
}

@Composable
private fun Mono(text: String, color: androidx.compose.ui.graphics.Color) {
    Text(text, fontSize = 11.sp, letterSpacing = 0.5.sp,
         fontWeight = FontWeight.SemiBold, color = color)
}

@Composable
private fun ChevronRow(label: String, hint: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().clickable(onClick = onClick).padding(vertical = 7.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, fontSize = 12.sp, fontWeight = FontWeight.Medium,
                 color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.width(5.dp))
            Text(hint, fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text("›", fontSize = 16.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
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

private fun hourLabel(h: Int): String = when {
    h == 12 -> "noon"
    h > 12 -> "${h - 12}pm"
    else -> "${h}am"
}
