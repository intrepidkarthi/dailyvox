package com.dailyvox.app.ui.screens

import com.dailyvox.app.R
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
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
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
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
 * the real sun via SolarClock, rather than the fixed 19:00-06:00 window it used
 * to assume, which was wrong by about an hour at the solstices and wrong in
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
    onExportMarkdown: () -> Unit = {},
    onExportCsv: () -> Unit = {},
    onExportEncrypted: () -> Unit = {},
    onImport: () -> Unit = {},
    onExportResearch: () -> Unit = {},
    reminderOn: Boolean = false,
    reminderHour: Int = 21,
    onReminder: (Boolean, Int) -> Unit = { _, _ -> },
    onShareReceipt: () -> Unit = {},
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
            Text(com.dailyvox.app.ui.components.backGlyph(), fontSize = 30.sp, style = com.dailyvox.app.ui.components.Directional.GlyphStyle,
                 color = scheme.onBackground,
                 modifier = Modifier.clip(RoundedCornerShape(24.dp)).clickable(onClick = onBack)
                     .defaultMinSize(48.dp, 48.dp).wrapContentSize())
            Spacer(Modifier.width(4.dp))
            Text(stringResource(R.string.settings_title), fontFamily = com.dailyvox.app.ui.theme.Nunito, fontSize = 30.sp, fontWeight = FontWeight.ExtraBold,
                 color = scheme.onBackground)
        }

        // ── DATA SHIELD ────────────────────────────────────────────────────
        // First, because it is the product's argument. Every line is a fact the
        // reader can check without trusting this screen.
        SettingsCard {
            SectionLabel(stringResource(R.string.settings_shield_label), positive)
            Spacer(Modifier.height(11.dp))
            LedgerRow(stringResource(R.string.settings_shield_network)) {
                Mono(stringResource(R.string.settings_shield_network_value), positive)
            }
            LedgerRow(stringResource(R.string.settings_shield_encryption)) { Mono("AES-256", scheme.onSurfaceVariant) }
            LedgerRow(stringResource(R.string.settings_shield_lock)) {
                Switch(
                    checked = lockEnabled, onCheckedChange = onLock, enabled = lockAvailable,
                    colors = dvSwitchColors(),
                )
            }
            // No Health Connect row in v1.0: the app declares no health
            // permission, and a ledger row for something it cannot touch would
            // be decoration. It returns with a real Body signals opt-in.
            Spacer(Modifier.height(11.dp))
            Text(
                stringResource(R.string.settings_shield_permissions),
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(11.dp))
            // This card is the privacy receipt, so it is also where you take a
            // copy of it. §F: the screenshot does the arguing.
            Text(
                stringResource(R.string.settings_shield_share), fontSize = 11.5.sp,
                fontWeight = FontWeight.SemiBold, color = goldText,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(com.dailyvox.app.ui.theme.Gold.copy(alpha = 0.14f))
                    .clickable(onClick = onShareReceipt)
                    .padding(horizontal = 12.dp, vertical = 8.dp),
            )
        }

        // ── THEME ──────────────────────────────────────────────────────────
        SettingsCard {
            SectionLabel(stringResource(R.string.settings_theme_label), scheme.onSurfaceVariant)
            Spacer(Modifier.height(11.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                listOf(
                    ThemeChoice.LIGHT to stringResource(R.string.settings_theme_day),
                    ThemeChoice.DARK to stringResource(R.string.settings_theme_night),
                    ThemeChoice.SUNSET to stringResource(R.string.settings_theme_sunset),
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
        }

        // ── REMINDER ───────────────────────────────────────────────────────
        SettingsCard {
            // Label and switch share one row, per the design. The switch is the
            // only control that is always visible; the time hides behind its own
            // chip so the card reads as a sentence rather than a form.
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SectionLabel(stringResource(R.string.settings_reminder_label), scheme.onSurfaceVariant)
                Switch(
                    checked = reminderOn,
                    onCheckedChange = { onReminder(it, reminderHour) },
                    colors = dvSwitchColors(),
                )
            }
            Spacer(Modifier.height(11.dp))
            var picking by remember { mutableStateOf(false) }
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    stringResource(R.string.settings_reminder_preview),
                    fontSize = 12.sp, lineHeight = 17.sp,
                    fontWeight = FontWeight.Medium, color = scheme.onSurface,
                )
                Text(
                    hourLabel(reminderHour), fontSize = 10.sp,
                    fontWeight = FontWeight.SemiBold, color = goldText,
                    modifier = Modifier
                        .clip(RoundedCornerShape(11.dp))
                        .background(com.dailyvox.app.ui.theme.Gold.copy(alpha = 0.16f))
                        .border(1.dp, com.dailyvox.app.ui.theme.Gold.copy(alpha = 0.4f),
                                RoundedCornerShape(11.dp))
                        .clickable { picking = !picking }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
            if (picking) {
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
                                .clickable { onReminder(true, h); picking = false }
                                .padding(vertical = 9.dp)
                                .wrapContentWidth(Alignment.CenterHorizontally),
                        )
                    }
                }
            }
            // The quote is a separate, explicit yes. Reads and writes its own
            // preference like the weekly goal below; only the receiver uses it.
            if (reminderOn) {
                var quotePast by remember {
                    mutableStateOf(com.dailyvox.app.system.Reminders.quotesPast(context))
                }
                Spacer(Modifier.height(12.dp))
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        androidx.compose.ui.res.stringResource(com.dailyvox.app.R.string.settings_reminder_quote),
                        fontSize = 12.sp, lineHeight = 17.sp,
                        fontWeight = FontWeight.Medium, color = scheme.onSurface,
                        modifier = Modifier.weight(1f).padding(end = 12.dp),
                    )
                    Switch(
                        checked = quotePast,
                        onCheckedChange = {
                            quotePast = it
                            com.dailyvox.app.system.Reminders.setQuotesPast(context, it)
                        },
                        colors = dvSwitchColors(),
                    )
                }
                Spacer(Modifier.height(4.dp))
                Text(
                    androidx.compose.ui.res.stringResource(com.dailyvox.app.R.string.settings_reminder_quote_note),
                    fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
                )
            }
            Spacer(Modifier.height(8.dp))
            // Both halves are claims the app has to actually honour: the receiver
            // reads today's entries and returns without notifying if one exists,
            // and there is no network permission for a push server to arrive on.
            Text(
                stringResource(R.string.settings_reminder_note),
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
        }

        // ── WEEKLY GOAL ────────────────────────────────────────────────────
        // iOS has had this since v1.0; Android did not. Reads and writes its own
        // preferences the way the vocabulary list above does, rather than being
        // threaded through MainActivity: nothing else in the app needs to know
        // the target, and a parameter no caller uses is a parameter that rots.
        SettingsCard {
            var goalOn by remember { mutableStateOf(com.dailyvox.app.system.Goals.isEnabled(context)) }
            var goalTarget by remember { mutableIntStateOf(com.dailyvox.app.system.Goals.target(context)) }
            var goalNotify by remember { mutableStateOf(com.dailyvox.app.system.Goals.notifies(context)) }
            Row(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                SectionLabel(stringResource(R.string.settings_goal_label), scheme.onSurfaceVariant)
                Switch(
                    checked = goalOn,
                    onCheckedChange = { goalOn = it; com.dailyvox.app.system.Goals.setEnabled(context, it) },
                    colors = dvSwitchColors(),
                )
            }
            if (goalOn) {
                Spacer(Modifier.height(11.dp))
                Text(
                    stringResource(R.string.settings_goal_prompt),
                    fontSize = 12.sp, lineHeight = 17.sp,
                    fontWeight = FontWeight.Medium, color = scheme.onSurface,
                )
                Spacer(Modifier.height(10.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    com.dailyvox.app.system.Goals.TARGETS.forEach { n ->
                        val on = n == goalTarget
                        Text(
                            "$n", fontSize = 11.sp, fontWeight = FontWeight.Bold,
                            color = if (on) scheme.onPrimary else scheme.onSurfaceVariant,
                            modifier = Modifier.weight(1f)
                                .clip(RoundedCornerShape(13.dp))
                                .then(
                                    if (on) Modifier.background(scheme.primary)
                                    else Modifier.border(1.5.dp,
                                        scheme.onSurfaceVariant.copy(alpha = 0.25f),
                                        RoundedCornerShape(13.dp))
                                )
                                .clickable {
                                    goalTarget = n
                                    com.dailyvox.app.system.Goals.setTarget(context, n)
                                }
                                .padding(vertical = 9.dp)
                                .wrapContentWidth(Alignment.CenterHorizontally),
                        )
                    }
                }
                Spacer(Modifier.height(10.dp))
                LedgerRow(stringResource(R.string.settings_goal_notify)) {
                    Switch(
                        checked = goalNotify,
                        onCheckedChange = {
                            goalNotify = it
                            com.dailyvox.app.system.Goals.setNotifies(context, it)
                        },
                    colors = dvSwitchColors(),
                    )
                }
                Spacer(Modifier.height(8.dp))
                // Counting nights rather than entries is the part worth stating:
                // it is what stops three recordings in one evening from clearing
                // a target of three.
                Text(
                    stringResource(R.string.settings_goal_note),
                    fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
                )
            }
        }

        // ── BACKUP & EXPORT ────────────────────────────────────────────────
        SettingsCard {
            SectionLabel(stringResource(R.string.settings_backup_label), scheme.onSurfaceVariant)
            Spacer(Modifier.height(11.dp))
            ChevronRow(stringResource(R.string.settings_export_pdf), stringResource(R.string.settings_export_pdf_hint), onExportPdf)
            ChevronRow(stringResource(R.string.settings_export_json), stringResource(R.string.settings_export_json_hint), onExport)
            ChevronRow(stringResource(R.string.settings_export_markdown), stringResource(R.string.settings_export_markdown_hint), onExportMarkdown)
            ChevronRow(stringResource(R.string.settings_export_csv), stringResource(R.string.settings_export_csv_hint), onExportCsv)
            ChevronRow(stringResource(R.string.settings_export_encrypted), stringResource(R.string.settings_export_encrypted_hint), onExportEncrypted)
            ChevronRow(stringResource(R.string.settings_import), stringResource(R.string.settings_import_hint), onImport)
        }

        // ── RESEARCH ───────────────────────────────────────────────────────
        // For study participants. The code reads its own preference, like the
        // weekly goal above: nothing else in the app needs it. It goes on the
        // consent form and rides every export, so it is shown beside the export
        // and copies in one tap -- hand-copying it is where typos come from.
        SettingsCard {
            SectionLabel(stringResource(R.string.settings_research_label), scheme.onSurfaceVariant)
            Spacer(Modifier.height(11.dp))
            val code = remember { com.dailyvox.app.system.Research.participantCode(context) }
            var copied by remember { mutableStateOf(false) }
            val codeLabel = stringResource(R.string.settings_participant_code)
            LedgerRow(codeLabel) {
                Text(
                    if (copied) stringResource(R.string.settings_participant_code_copied, code) else code,
                    fontFamily = com.dailyvox.app.ui.theme.DmMono, fontSize = 12.sp,
                    letterSpacing = 0.5.sp, fontWeight = FontWeight.SemiBold, color = goldText,
                    modifier = Modifier
                        .clip(RoundedCornerShape(11.dp))
                        .background(com.dailyvox.app.ui.theme.Gold.copy(alpha = 0.16f))
                        .clickable {
                            val cm = context.getSystemService(android.content.ClipboardManager::class.java)
                            cm?.setPrimaryClip(android.content.ClipData.newPlainText(codeLabel, code))
                            copied = true
                        }
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
            ChevronRow(stringResource(R.string.settings_export_research), stringResource(R.string.settings_export_research_hint), onExportResearch)
            // Same preference key as iOS. On Android the mood check already
            // follows every entry, so the switch does one thing here: every
            // third day, the question of the day is a plain "log your day".
            var pilot by remember { mutableStateOf(com.dailyvox.app.system.DailyQuestion.isPilot(context)) }
            val pilotLabel = androidx.compose.ui.res.stringResource(com.dailyvox.app.R.string.settings_pilot)
            LedgerRow(pilotLabel) {
                Switch(
                    modifier = Modifier.semantics { contentDescription = pilotLabel },
                    checked = pilot,
                    onCheckedChange = {
                        pilot = it
                        com.dailyvox.app.system.DailyQuestion.setPilot(context, it)
                    },
                    colors = dvSwitchColors(),
                )
            }
            Text(
                androidx.compose.ui.res.stringResource(com.dailyvox.app.R.string.settings_pilot_note),
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(8.dp))
            Text(
                stringResource(R.string.settings_research_note),
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
        }

        // ── LANGUAGE YOU SPEAK (B-8) ───────────────────────────────────────
        SettingsCard {
            SectionLabel(
                androidx.compose.ui.res.stringResource(com.dailyvox.app.R.string.speak_lang_title),
                scheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(6.dp))
            com.dailyvox.app.ui.components.SpeakingLanguagePicker()
        }

        SettingsCard {
            SectionLabel(stringResource(R.string.settings_words_label), scheme.onSurfaceVariant)
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
                    keyboardOptions = com.dailyvox.app.ui.components.PrivateKeyboard,
                    placeholder = { Text(stringResource(R.string.settings_words_placeholder), fontSize = 12.sp) },
                    singleLine = true, modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    stringResource(R.string.settings_words_add), fontSize = 12.sp, fontWeight = FontWeight.Bold,
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
                            stringResource(R.string.settings_words_chip, w), fontSize = 9.5.sp, letterSpacing = 0.5.sp,
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
                stringResource(R.string.settings_words_note),
                fontSize = 11.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant,
            )
        }

        // ── REVIEW PROMPT ──────────────────────────────────────────────────
        // Asking here rather than interrupting the app is deliberate: the iOS
        // build's rating prompt is gated behind [3, 12, 40] entries because a
        // prompt shown to someone who has not used the app yet buys a one-star.
        // A settings row is the version of that with zero interruptions.
        Spacer(Modifier.height(10.dp))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(scheme.surface)
                .padding(horizontal = 17.dp, vertical = 11.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(Modifier.weight(1f)) {
                Text(stringResource(R.string.settings_review_title), fontSize = 12.sp,
                     fontWeight = FontWeight.Medium, color = scheme.onSurface)
                Text(stringResource(R.string.settings_review_body), fontSize = 10.5.sp,
                     lineHeight = 15.sp, color = scheme.onSurfaceVariant)
            }
            Spacer(Modifier.width(12.dp))
            Text(
                stringResource(R.string.settings_review_rate), fontSize = 11.sp, fontWeight = FontWeight.ExtraBold,
                color = com.dailyvox.app.ui.theme.NightBackground,
                modifier = Modifier
                    .clip(RoundedCornerShape(13.dp))
                    .background(com.dailyvox.app.ui.theme.Gold)
                    // A market:// intent, not the Play in-app review library.
                    // That library is a closed-source Google dependency for a
                    // build that ships zero network permissions and is trying to
                    // stay under 10 MB; handing the Play Store app the deep link
                    // costs nothing and works the same.
                    .clickable {
                        val uri = android.net.Uri.parse(
                            "market://details?id=" + context.packageName)
                        val store = android.content.Intent(
                            android.content.Intent.ACTION_VIEW, uri)
                        val web = android.content.Intent(
                            android.content.Intent.ACTION_VIEW,
                            android.net.Uri.parse(
                                "https://play.google.com/store/apps/details?id=" +
                                    context.packageName))
                        // Phones without Play (and every emulator image without
                        // Play Services) throw ActivityNotFound on market://.
                        if (runCatching { context.startActivity(store) }.isFailure) {
                            runCatching { context.startActivity(web) }
                        }
                    }
                    .padding(horizontal = 14.dp, vertical = 9.dp),
            )
        }

        // Debug builds only: src/release compiles this to nothing (plan B-17).
        com.dailyvox.app.debug.RecognizerProbe.Card()

        Spacer(Modifier.height(10.dp))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            Text(stringResource(R.string.settings_footer_status), fontSize = 11.sp,
                 color = scheme.onSurfaceVariant)
            Text(pluralStringResource(R.plurals.settings_footer_entries, entryCount, entryCount), fontSize = 11.sp, color = scheme.onSurfaceVariant)
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
    Text(text, fontFamily = com.dailyvox.app.ui.theme.DmMono, fontSize = 10.5.sp, letterSpacing = 1.2.sp,
         fontWeight = FontWeight.SemiBold, color = color)
}

@Composable
private fun LedgerRow(label: String, trailing: @Composable () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 44.dp).padding(vertical = 6.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(label, fontSize = 15.sp, fontWeight = FontWeight.Medium,
             color = MaterialTheme.colorScheme.onSurface)
        trailing()
    }
}

@Composable
private fun Mono(text: String, color: androidx.compose.ui.graphics.Color) {
    Text(text, fontFamily = com.dailyvox.app.ui.theme.DmMono, fontSize = 12.sp, letterSpacing = 0.5.sp,
         fontWeight = FontWeight.SemiBold, color = color)
}

@Composable
private fun ChevronRow(label: String, hint: String, onClick: () -> Unit) {
    Row(
        Modifier.fillMaxWidth().heightIn(min = 44.dp).clickable(onClick = onClick).padding(vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, fontSize = 15.sp, fontWeight = FontWeight.Medium,
                 color = MaterialTheme.colorScheme.onSurface)
            Spacer(Modifier.width(5.dp))
            Text(hint, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
        Text(com.dailyvox.app.ui.components.forwardGlyph(), fontSize = 16.sp, style = com.dailyvox.app.ui.components.Directional.GlyphStyle,
             color = MaterialTheme.colorScheme.onSurfaceVariant)
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

/**
 * The reminder hour on a chip. English keeps 1.2's "9pm" and "noon" (the
 * strings below); every other language gets the platform's own hour format
 * (B-13), never a clock hand-built from English parts.
 */
@Composable
private fun hourLabel(h: Int): String {
    val english = when {
        h == 12 -> stringResource(R.string.settings_hour_noon)
        h > 12 -> stringResource(R.string.settings_hour_pm, h - 12)
        else -> stringResource(R.string.settings_hour_am, h)
    }
    return com.dailyvox.app.system.LocaleFormat.hourLabel(h, english)
}

/** Brand green track, cream thumb — not M3's baseline purple-tinted defaults. */
@Composable
private fun dvSwitchColors() = androidx.compose.material3.SwitchDefaults.colors(
    checkedTrackColor = MaterialTheme.colorScheme.primary,
    checkedThumbColor = MaterialTheme.colorScheme.onPrimary,
    uncheckedTrackColor = MaterialTheme.colorScheme.surfaceVariant,
    uncheckedBorderColor = MaterialTheme.colorScheme.outline.copy(alpha = 0.4f),
)
