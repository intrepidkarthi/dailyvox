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
    onExportEncrypted: () -> Unit = {},
    onExportPdf: () -> Unit = {},
    onImport: () -> Unit = {},
    reminderOn: Boolean = false,
    reminderHour: Int = 21,
    onReminder: (Boolean, Int) -> Unit = { _, _ -> },
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(12.dp))
        ScreenTitle("Settings", onBack = onBack)

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
            Spacer(Modifier.height(12.dp))
            MonoLabel("every permission this app holds")
            Spacer(Modifier.height(6.dp))
            // The whole list, not a flattering subset. A ledger that omits a line
            // is worth less than no ledger, and anyone can check it in app info.
            Text(
                "RECORD_AUDIO — to hear you.\n" +
                    "POST_NOTIFICATIONS — the nightly reminder, nothing else.\n" +
                    "VIBRATE — haptics.\n" +
                    "USE_BIOMETRIC — the lock on this screen.\n" +
                    "READ_SLEEP, READ_HEART_RATE_VARIABILITY, READ_RESTING_HEART_RATE, READ_STEPS — declared for Body signals, and requested only if you switch that on. Android will show them as \"not granted\" until then.\n\n" +
                    "That is the complete list. There is no network permission of any kind, so there is no version of this app that could send your journal anywhere.",
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
        MonoLabel("Body signals")
        Spacer(Modifier.height(8.dp))
        BodyCard(context)

        Spacer(Modifier.height(22.dp))
        MonoLabel("Daily reminder")
        Spacer(Modifier.height(8.dp))
        DvCard {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) {
                    Text("Remind me in the evening", fontSize = 15.sp,
                         color = MaterialTheme.colorScheme.onSurface)
                    Spacer(Modifier.height(3.dp))
                    // "Around", not "at". The reminder is a WorkManager window,
                    // not an exact alarm -- USE_EXACT_ALARM is a restricted
                    // permission a journal does not qualify for. Promising a
                    // minute and delivering a window teaches people to distrust
                    // the notification, which costs more than the precision.
                    Text("Around ${hourLabel(reminderHour)}. One notification, no streak guilt.",
                         fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
                }
                Switch(checked = reminderOn, onCheckedChange = { onReminder(it, reminderHour) })
            }
            if (reminderOn) {
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    listOf(18, 20, 21, 22).forEach { h ->
                        val on = h == reminderHour
                        Text(
                            hourLabel(h), fontSize = 13.sp,
                            color = if (on) MaterialTheme.colorScheme.onPrimary
                                    else MaterialTheme.colorScheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f)
                                .clip(RoundedCornerShape(12.dp))
                                .background(if (on) MaterialTheme.colorScheme.secondary
                                            else MaterialTheme.colorScheme.surfaceVariant)
                                .clickable { onReminder(true, h) }
                                .padding(vertical = 11.dp)
                                .wrapContentWidth(Alignment.CenterHorizontally),
                        )
                    }
                }
            }
        }

        Spacer(Modifier.height(22.dp))
        MonoLabel("Words we keep getting wrong")
        Spacer(Modifier.height(8.dp))
        VocabularyCard(context)

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
        DvCard(Modifier.clickable(onClick = onExportEncrypted)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Back up my journal", fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
                MonoLabel("AES-256")
            }
            Spacer(Modifier.height(4.dp))
            // You choose where. That is not a convenience — an export the app
            // filed somewhere of its own choosing was deleted on uninstall, which
            // is precisely when a backup is supposed to exist.
            Text("You pick where it goes — your Files app, an SD card, a USB drive, or a cloud folder if you want one. Locked with a passphrase you choose, and restorable on any phone that knows it, including an iPhone.",
                 fontSize = 12.sp, lineHeight = 18.sp,
                 color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(Modifier.height(10.dp))
        DvCard(Modifier.clickable(onClick = onExport)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Export as readable JSON", fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
                MonoLabel("portable")
            }
            Spacer(Modifier.height(4.dp))
            Text("Unencrypted and openable by anything, including the iPhone app. This is the never-locked-in path; keep it somewhere you would keep a diary.",
                 fontSize = 12.sp, lineHeight = 18.sp,
                 color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(Modifier.height(10.dp))
        DvCard(Modifier.clickable(onClick = onExportPdf)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Export as PDF", fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
                MonoLabel("share")
            }
            Spacer(Modifier.height(4.dp))
            Text("A printable journal, opened straight into the share sheet.",
                 fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(Modifier.height(10.dp))
        DvCard(Modifier.clickable(onClick = onImport)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Import a backup", fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface)
                MonoLabel("adds only")
            }
            Spacer(Modifier.height(4.dp))
            // Stated up front, because the alternative is one mis-tap from
            // erasing a diary. Import never replaces what is already here.
            Text("Reads either file — a sealed .dvx backup from this phone, or a JSON export from here or an iPhone. Entries are added; nothing already here is replaced or deleted.",
                 fontSize = 12.sp, lineHeight = 18.sp,
                 color = MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(Modifier.height(22.dp))
        MonoLabel("Help shape this")
        Spacer(Modifier.height(8.dp))
        ContributeCard(context, entryCount)

        Spacer(Modifier.height(24.dp))
        Text(
            "DailyVox for Android · in development · free forever · open source\nData Not Collected — because there is nowhere to send it.",
            fontSize = 11.sp, lineHeight = 18.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(130.dp))
    }
}

/**
 * The pilot invite and the feedback link, in one card and OUT OF THE WAY.
 *
 * The iOS rating prompt fires at 3, 12 and 40 entries as an interstitial. That
 * pattern is not ported, and not by omission: Play's in-app review API lives in
 * `com.google.android.play:review`, a proprietary binary, and this build is free
 * software end to end. So the ask is a card the user finds, not a modal that
 * finds them. It also gates on 12 entries, because inviting someone into a
 * research cohort on their second night is asking a stranger for their diary.
 *
 * Opening a URL hands off to the browser by intent. This app still holds no
 * INTERNET permission and still makes no network calls of its own -- the "0"
 * three sections above stays literally true.
 */
@Composable
private fun ContributeCard(context: android.content.Context, entryCount: Int) {
    fun open(url: String) = runCatching {
        context.startActivity(
            android.content.Intent(android.content.Intent.ACTION_VIEW, android.net.Uri.parse(url))
                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
        )
    }

    if (entryCount >= 12) {
        DvCard(Modifier.clickable { open("https://getdailyvox.com/research") }) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                Text("Join the research pilot", fontSize = 15.sp,
                     color = MaterialTheme.colorScheme.onSurface)
                MonoLabel("optional")
            }
            Spacer(Modifier.height(4.dp))
            // Every claim here is a constraint on the study design, not marketing.
            Text("A small study on whether a Twin built from your own words reflects you accurately. Participation is opt-in, entries stay on your phone, and anything shared is anonymised first.",
                 fontSize = 12.sp, lineHeight = 18.sp,
                 color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Spacer(Modifier.height(10.dp))
    }

    DvCard(Modifier.clickable { open("https://github.com/intrepidkarthi/dailyvox/issues") }) {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            Text("Report a bug or ask for something", fontSize = 15.sp,
                 color = MaterialTheme.colorScheme.onSurface)
            MonoLabel("github")
        }
        Spacer(Modifier.height(4.dp))
        Text("Opens in your browser. Nothing from your journal is attached, ever — you write the report yourself.",
             fontSize = 12.sp, lineHeight = 18.sp,
             color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/**
 * Health Connect, opt-in and read-only.
 *
 * The onboarding ledger says Health Connect is OPTIONAL, so this switch has to
 * be genuinely optional: nothing is requested until it is turned on, and the
 * app is fully usable forever if it never is. The card names the four record
 * types out loud, because "health data" is not a thing a person can consent to
 * — sleep, HRV, resting heart rate and steps is.
 */
@Composable
private fun BodyCard(context: android.content.Context) {
    val signals = remember { com.dailyvox.app.body.BodySignals(context) }
    val availability = remember { signals.availability() }
    val prefs = remember { context.getSharedPreferences("dailyvox", android.content.Context.MODE_PRIVATE) }
    var enabled by remember { mutableStateOf(prefs.getBoolean("body", false)) }
    val scope = androidx.compose.runtime.rememberCoroutineScope()

    val ask = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.health.connect.client.PermissionController.createRequestPermissionResultContract()
    ) { granted ->
        // The switch reflects what was actually granted, never what was asked.
        val ok = granted.containsAll(com.dailyvox.app.body.BodySignals.PERMISSIONS)
        enabled = ok
        prefs.edit().putBoolean("body", ok).apply()
    }

    DvCard {
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(
                    when (availability) {
                        com.dailyvox.app.body.BodySignals.Availability.AVAILABLE ->
                            "Let the Twin see your body"
                        com.dailyvox.app.body.BodySignals.Availability.NEEDS_UPDATE ->
                            "Health Connect needs updating"
                        else -> "Health Connect is not on this phone"
                    },
                    fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface,
                )
                Spacer(Modifier.height(3.dp))
                Text(
                    when (availability) {
                        com.dailyvox.app.body.BodySignals.Availability.AVAILABLE ->
                            "Sleep, morning HRV, resting heart rate and steps — read only, and only those four."
                        com.dailyvox.app.body.BodySignals.Availability.NEEDS_UPDATE ->
                            "Update Health Connect in the Play Store to use this."
                        else -> "Everything else in DailyVox works exactly the same without it."
                    },
                    fontSize = 12.sp, lineHeight = 18.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Switch(
                checked = enabled,
                enabled = availability == com.dailyvox.app.body.BodySignals.Availability.AVAILABLE,
                onCheckedChange = { on ->
                    if (!on) {
                        enabled = false
                        prefs.edit().putBoolean("body", false).apply()
                    } else {
                        scope.launch {
                            if (signals.granted()) {
                                enabled = true
                                prefs.edit().putBoolean("body", true).apply()
                            } else {
                                ask.launch(com.dailyvox.app.body.BodySignals.PERMISSIONS)
                            }
                        }
                    }
                },
            )
        }
        if (enabled) {
            Spacer(Modifier.height(10.dp))
            // Stated because it is the part people assume is untrue.
            Text(
                "Read when you record, stored on this phone with the entry, and never sent anywhere. Turning this off stops new readings; entries already filed keep what they were spoken with.",
                fontSize = 12.sp, lineHeight = 18.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
    }
}

private fun hourLabel(h: Int): String = when {
    h == 12 -> "noon"
    h > 12 -> "${h - 12}pm"
    else -> "${h}am"
}

/**
 * Custom vocabulary. Small, but it is the only user-facing lever on the port's
 * biggest measured weakness -- names the recognizer mishears never reach the
 * entity graph at all, so the person simply is not in the Twin.
 */
@Composable
private fun VocabularyCard(context: android.content.Context) {
    var words by remember {
        mutableStateOf(com.dailyvox.app.system.Vocabulary.get(context))
    }
    var draft by remember { mutableStateOf("") }

    DvCard {
        Text("Names the recogniser mishears — a friend's name, a place, a word you use that it does not know.",
             fontSize = 12.sp, lineHeight = 18.sp,
             color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(12.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            OutlinedTextField(
                value = draft,
                onValueChange = { draft = it },
                placeholder = { Text("Add a word", fontSize = 14.sp) },
                singleLine = true,
                modifier = Modifier.weight(1f),
            )
            Spacer(Modifier.width(8.dp))
            Text("Add", fontSize = 14.sp, color = MaterialTheme.colorScheme.onPrimary,
                 modifier = Modifier
                     .clip(RoundedCornerShape(14.dp))
                     .background(MaterialTheme.colorScheme.primary)
                     .clickable {
                         com.dailyvox.app.system.Vocabulary.add(context, draft)
                         words = com.dailyvox.app.system.Vocabulary.get(context)
                         draft = ""
                     }
                     .padding(horizontal = 18.dp, vertical = 14.dp))
        }
        if (words.isNotEmpty()) {
            Spacer(Modifier.height(12.dp))
            FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp),
                    verticalArrangement = Arrangement.spacedBy(8.dp)) {
                words.forEach { w ->
                    Text("$w  ×", fontSize = 12.sp,
                         color = MaterialTheme.colorScheme.secondary,
                         modifier = Modifier
                             .clip(RoundedCornerShape(10.dp))
                             .background(MaterialTheme.colorScheme.secondary.copy(alpha = 0.14f))
                             .clickable {
                                 com.dailyvox.app.system.Vocabulary.remove(context, w)
                                 words = com.dailyvox.app.system.Vocabulary.get(context)
                             }
                             .padding(horizontal = 10.dp, vertical = 6.dp))
                }
            }
            Spacer(Modifier.height(8.dp))
            // Honest about what biasing actually does. It raises the odds; it is
            // not a dictionary override, and saying otherwise sets up a broken
            // promise the user will notice on the very next recording.
            Text("These make the recogniser more likely to hear the word. It is a nudge, not a guarantee.",
                 fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
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
