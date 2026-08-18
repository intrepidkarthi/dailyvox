package com.dailyvox.app

import android.content.Context
import android.os.Bundle
import androidx.fragment.app.FragmentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dailyvox.app.data.Entry
import com.dailyvox.app.ui.AppViewModel
import com.dailyvox.app.ui.nav.DailyVoxNavBar
import com.dailyvox.app.ui.nav.Destination
import com.dailyvox.app.ui.screens.*
import com.dailyvox.app.ui.theme.DailyVoxTheme

/** Overlay routes: full screens that are not nav destinations. */
private enum class Overlay { NONE, SETTINGS, INSIGHTS }

class MainActivity : FragmentActivity() {

    private val vm: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before setContent, and not optional on targetSdk 36:
        // windowOptOutEdgeToEdgeEnforcement is deprecated and disabled.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { DailyVoxApp(vm, this) }
    }
}

@Composable
private fun DailyVoxApp(vm: AppViewModel, activity: FragmentActivity) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE) }

    var onboarded by rememberSaveable { mutableStateOf(prefs.getBoolean("onboarded", false)) }
    val lockAvailableNow = remember { com.dailyvox.app.security.AppLock.available(activity) }
    // Lock defaults ON, but ONLY where the device can honour it. Defaulting true
    // on a phone with no screen lock would gate the app behind a prompt that can
    // never succeed — a self-inflicted lockout on first run.
    var lockEnabled by rememberSaveable {
        mutableStateOf(prefs.getBoolean("lock", lockAvailableNow))
    }
    var unlocked by rememberSaveable { mutableStateOf(false) }
    val lockAvailable = lockAvailableNow
    // DARK by default, not SYSTEM. The design package's recommended direction
    // (1c, "the middle path, and my recommendation") says it plainly: "dark by
    // default because the app is used at night". Defaulting to SYSTEM meant most
    // phones opened this on cream, which is the Light theme — technically in the
    // spec, and the reason the app read as beige and lifeless.
    var theme by rememberSaveable { mutableStateOf(ThemeChoice.valueOf(prefs.getString("theme", "SUNSET")!!)) }
    var current by rememberSaveable { mutableStateOf(Destination.SPEAK) }
    var overlay by rememberSaveable { mutableStateOf(Overlay.NONE) }
    var openEntry by remember { mutableStateOf<Entry?>(null) }
    // Recording takes the whole screen (B2b) — the tab bar would offer an exit
    // that silently discards what is being said.
    var isRecording by remember { mutableStateOf(false) }
    // Reminder defaults ON. Retention is the measured binding constraint and the
    // iOS reminder shipped OFF, so this is the lever that was never pulled. It
    // stays a switch the user can find in two taps, and the permission ask below
    // is the real consent gate.
    var reminderOn by rememberSaveable {
        mutableStateOf(prefs.getBoolean(com.dailyvox.app.system.Reminders.PREF_ENABLED, true))
    }
    var reminderHour by rememberSaveable { mutableStateOf(prefs.getInt("reminderHour", 21)) }

    // Launched from the widget or the Quick Settings tile. Read once and cleared,
    // so a configuration change does not re-arm the recorder behind the user.
    // A launcher shortcut's <extra android:value="true"/> arrives as the STRING
    // "true", not a boolean, so getBooleanExtra alone reads false and the
    // shortcut silently opens the app without recording. The widget and the tile
    // put a real boolean here, so both shapes have to be accepted.
    fun flag(name: String): Boolean {
        val i = activity.intent ?: return false
        val set = i.getBooleanExtra(name, false) || i.getStringExtra(name) == "true"
        i.removeExtra(name)
        return set
    }

    var autoRecord by remember { mutableStateOf(flag("start_recording")) }
    val openJournalOnLaunch = remember { flag("open_journal") }

    LaunchedEffect(openJournalOnLaunch) {
        if (openJournalOnLaunch) current = Destination.JOURNAL
    }

    val askNotifications = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted ->
        // The switch already flipped. If the permission is refused, put it back
        // rather than leaving a toggle on that will never produce a notification.
        if (granted) com.dailyvox.app.system.Reminders.schedule(context, reminderHour)
        else { reminderOn = false; prefs.edit().putBoolean("reminder", false).apply() }
    }

    // A passphrase is asked for at the moment it is needed, not stored anywhere.
    var pendingBackup by remember { mutableStateOf<android.net.Uri?>(null) }
    var pendingRestore by remember { mutableStateOf<android.net.Uri?>(null) }

    val pickBackup = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.OpenDocument()
    ) { uri ->
        if (uri != null) vm.importFrom(context, uri, onPassphraseNeeded = { pendingRestore = it })
    }

    // CreateDocument, so the user chooses the destination. Anything the app
    // picks itself lands in storage Android wipes on uninstall.
    val saveBackup = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.CreateDocument("application/octet-stream")
    ) { uri -> if (uri != null) pendingBackup = uri }

    val saveJson = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.CreateDocument("application/json")
    ) { uri -> if (uri != null) vm.writeExport(context, uri, passphrase = null) }


    val entries by vm.entries.collectAsStateWithLifecycle()

    // Plain-text exports write straight through the resolver: no temp file, so
    // nothing readable is left in app storage after the share.
    fun writeText(uri: android.net.Uri, body: String) {
        runCatching {
            context.contentResolver.openOutputStream(uri)?.use { it.write(body.toByteArray()) }
        }
    }
    val saveMd = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.CreateDocument("text/markdown")
    ) { uri -> if (uri != null) writeText(uri, com.dailyvox.app.system.Exporters.markdown(entries)) }
    val saveCsv = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.CreateDocument("text/csv")
    ) { uri -> if (uri != null) writeText(uri, com.dailyvox.app.system.Exporters.csv(entries)) }

    val query by vm.query.collectAsStateWithLifecycle()
    val streak by vm.streak.collectAsStateWithLifecycle()
    val resolution by vm.resolution.collectAsStateWithLifecycle()

    val dark = when (theme) {
        ThemeChoice.LIGHT -> false
        ThemeChoice.DARK -> true
        // Re-read on every recomposition rather than cached: the theme should
        // change when the evening arrives, not only on next launch.
        ThemeChoice.SUNSET -> java.util.Calendar.getInstance()
            .get(java.util.Calendar.HOUR_OF_DAY)
            .let { it >= 19 || it < 6 }
    }

    DailyVoxTheme(darkTheme = dark) {
        if (!onboarded) {
            OnboardingScreen(onDone = { text, secs, path ->
                // The first star is persisted as a REAL entry, exactly as iOS
                // does — so "that star is yours" is true and the app opens onto
                // a sky that already holds something.
                if (text.isNotBlank()) vm.add(text, secs, path)
                prefs.edit().putBoolean("onboarded", true).apply()
                onboarded = true
            })
            return@DailyVoxTheme
        }

        // Bootstrap, once onboarding is done: persist the defaults and arm the
        // alarm. Alarms do not survive a reboot and RECEIVE_BOOT_COMPLETED is
        // deliberately not declared, so this also serves as the reschedule.
        // Gated on being UNLOCKED, not merely onboarded. Firing the notification
        // dialog while BiometricPrompt is up cancels the prompt, and the user
        // lands on a bare "DailyVox is locked" screen on their very first run —
        // recoverable, but a stumble in the worst possible place. One dialog at
        // a time: unlock, then ask.
        LaunchedEffect(onboarded, unlocked, lockEnabled, reminderOn, reminderHour) {
            if (!onboarded) return@LaunchedEffect
            if (lockEnabled && lockAvailable && !unlocked) return@LaunchedEffect
            prefs.edit()
                .putBoolean(com.dailyvox.app.system.Reminders.PREF_ENABLED, reminderOn)
                .putInt(com.dailyvox.app.system.Reminders.PREF_HOUR, reminderHour)
                .putBoolean("lock", lockEnabled)
                .apply()
            if (!reminderOn) {
                com.dailyvox.app.system.Reminders.cancel(context)
            } else if (com.dailyvox.app.system.Reminders.canPostNotifications(context)) {
                com.dailyvox.app.system.Reminders.schedule(context, reminderHour)
            } else {
                askNotifications.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            }
        }

        // The lock gates EVERYTHING, before any entry text is composed. Prompting
        // over a screen that already rendered the journal would be theatre.
        //
        // `lockAvailable` is re-checked here, not just at the toggle. Someone can
        // enable the lock, then remove their screen lock in Android settings, and
        // come back to an app that would otherwise be permanently unopenable —
        // with no account and no cloud copy, that is unrecoverable data loss.
        if (lockEnabled && lockAvailable && !unlocked) {
            LockScreen(onUnlock = {
                com.dailyvox.app.security.AppLock.prompt(activity, onSuccess = { unlocked = true })
            })
            LaunchedEffect(Unit) {
                com.dailyvox.app.security.AppLock.prompt(activity, onSuccess = { unlocked = true })
            }
            return@DailyVoxTheme
        }

        // Predictive back, declared per state rather than branched after the
        // fact. On targetSdk 36 onBackPressed() is not called and KEYCODE_BACK is
        // not dispatched, so each layer that owns back has to say so: detail
        // first, then overlays, then any tab returns to Speak, and only Speak
        // falls through and exits.
        BackHandler(enabled = openEntry != null) { openEntry = null }
        BackHandler(enabled = openEntry == null && overlay != Overlay.NONE) { overlay = Overlay.NONE }
        BackHandler(enabled = openEntry == null && overlay == Overlay.NONE && current != Destination.SPEAK) {
            current = Destination.SPEAK
        }

        // Asked for at the moment it is needed, held only for this dialog, and
        // never written to prefs — a passphrase saved next to the file it
        // protects is decoration.
        pendingBackup?.let { uri ->
            PassphraseDialog(
                title = "Choose a passphrase",
                body = "This backup can be restored on any phone, including an iPhone, by anyone who knows this passphrase. There is no way to recover it — write it down somewhere safe.",
                confirmLabel = "Back up",
                requireLength = 8,
                onConfirm = { pass -> vm.writeExport(context, uri, pass); pendingBackup = null },
                onDismiss = { pendingBackup = null },
            )
        }

        pendingRestore?.let { uri ->
            PassphraseDialog(
                title = "Passphrase",
                body = "Enter the passphrase this backup was made with.",
                confirmLabel = "Restore",
                requireLength = 1,
                onConfirm = { pass ->
                    vm.importFrom(context, uri, passphrase = pass)
                    pendingRestore = null
                },
                onDismiss = { pendingRestore = null },
            )
        }

        val chromeVisible = openEntry == null && overlay == Overlay.NONE && !isRecording

        // Twin used to force navy in every theme, so the Scaffold container and
        // the nav bar had to be special-cased to match it. Now that the sky
        // follows the theme like every other screen, the special case is gone
        // and only the real theme drives the system bars.
        val view = androidx.compose.ui.platform.LocalView.current
        val darkTheme = androidx.compose.material3.MaterialTheme.colorScheme.background ==
            com.dailyvox.app.ui.theme.NightBackground
        androidx.compose.runtime.SideEffect {
            val window = (view.context as android.app.Activity).window
            androidx.core.view.WindowCompat.getInsetsController(window, view)
                .isAppearanceLightStatusBars = !darkTheme
        }

        Scaffold(
            modifier = Modifier.fillMaxSize(),
            bottomBar = {
                if (chromeVisible) DailyVoxNavBar(
                    night = darkTheme,
                    current = current,
                    onSelect = { current = it },
                )
            },
        ) { padding ->
            val inner = Modifier.padding(padding)
            val detail = openEntry

            when {
                detail != null -> EntryDetailScreen(
                    entry = detail,
                    onBack = { openEntry = null },
                    onDelete = { vm.delete(detail.id); openEntry = null },
                    onSelfLabel = { label ->
                        vm.setSelfLabel(detail.id, label)
                        openEntry = detail.copy(selfLabel = label)
                    },
                    onPhoto = { path ->
                        vm.attachPhoto(detail.id, path)
                        openEntry = detail.copy(photoPath = path)
                    },
                    modifier = inner,
                )

                overlay == Overlay.INSIGHTS ->
                    InsightsScreen(
                        entries = entries, streak = streak,
                        onBack = { overlay = Overlay.NONE },
                        modifier = inner,
                    )

                overlay == Overlay.SETTINGS -> run {
                    SettingsScreen(
                        onBack = { overlay = Overlay.NONE },
                        entryCount = entries.size,
                        lockEnabled = lockEnabled,
                        lockAvailable = lockAvailable,
                        onLock = { on ->
                            lockEnabled = on
                            prefs.edit().putBoolean("lock", on).apply()
                            if (on) unlocked = true      // do not lock the user out mid-session
                        },
                        theme = theme,
                        onTheme = { theme = it; prefs.edit().putString("theme", it.name).apply() },
                        onExport = { saveJson.launch("dailyvox-journal.json") },
                        onExportMarkdown = { saveMd.launch("dailyvox-journal.md") },
                        onExportCsv = { saveCsv.launch("dailyvox-journal.csv") },
                        onExportEncrypted = { saveBackup.launch("dailyvox-backup.dvx") },
                        onExportPdf = { vm.exportPdf(context) },
                        onImport = { pickBackup.launch(arrayOf("application/json", "text/plain", "*/*")) },
                        reminderOn = reminderOn,
                        reminderHour = reminderHour,
                        onReminder = { on, hour ->
                            reminderOn = on; reminderHour = hour
                            prefs.edit().putBoolean("reminder", on).putInt("reminderHour", hour).apply()
                            if (!on) com.dailyvox.app.system.Reminders.cancel(context)
                            else if (android.os.Build.VERSION.SDK_INT >= 33 &&
                                androidx.core.content.ContextCompat.checkSelfPermission(
                                    context, android.Manifest.permission.POST_NOTIFICATIONS
                                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
                            ) askNotifications.launch(android.Manifest.permission.POST_NOTIFICATIONS)
                            else com.dailyvox.app.system.Reminders.schedule(context, hour)
                        },
                        modifier = inner,
                    )
                }

                else -> when (current) {
                    Destination.SPEAK -> SpeakScreen(
                        streak = streak,
                        resolution = resolution,
                        yearCount = entries.count {
                            val c = java.util.Calendar.getInstance()
                            val thisYear = c.get(java.util.Calendar.YEAR)
                            c.timeInMillis = it.createdAt
                            c.get(java.util.Calendar.YEAR) == thisYear
                        },
                        firstEver = entries.isEmpty(),
                        todayEntry = entries.firstOrNull {
                            it.createdAt / 86_400_000L == System.currentTimeMillis() / 86_400_000L
                        },
                        autoStart = autoRecord,
                        onAutoStarted = { autoRecord = false },
                        onSaved = { text, secs, path -> vm.add(text, secs, path) },
                        onRecordingChanged = { isRecording = it },
                        onInsights = { overlay = Overlay.INSIGHTS },
                        onSettings = { overlay = Overlay.SETTINGS },
                        modifier = inner,
                    )
                    Destination.JOURNAL -> JournalScreen(
                        onAsk = { current = Destination.ASK },
                        entries = entries, query = query, onQuery = vm::setQuery,
                        onOpen = { openEntry = it },
                        onSpeak = { current = Destination.SPEAK },
                        modifier = inner,
                    )
                    Destination.TWIN -> TwinScreen(
                        entries = entries, resolution = resolution,
                        onAsk = { current = Destination.ASK },
                        onInsights = { overlay = Overlay.INSIGHTS },
                        modifier = inner,
                    )
                    Destination.ASK -> AskScreen(
                        entries = entries,
                        onOpenEntry = { openEntry = it },
                        modifier = inner,
                    )
                }
            }
        }
    }
}

@Composable
private fun PassphraseDialog(
    title: String,
    body: String,
    confirmLabel: String,
    requireLength: Int,
    onConfirm: (String) -> Unit,
    onDismiss: () -> Unit,
) {
    var value by remember { mutableStateOf("") }
    var visible by remember { mutableStateOf(false) }

    androidx.compose.material3.AlertDialog(
        onDismissRequest = onDismiss,
        title = { androidx.compose.material3.Text(title) },
        text = {
            Column {
                androidx.compose.material3.Text(body, fontSize = 13.sp, lineHeight = 19.sp)
                Spacer(Modifier.height(14.dp))
                androidx.compose.material3.OutlinedTextField(
                    value = value,
                    onValueChange = { value = it },
                    singleLine = true,
                    label = { androidx.compose.material3.Text("Passphrase") },
                    visualTransformation = if (visible)
                        androidx.compose.ui.text.input.VisualTransformation.None
                    else
                        androidx.compose.ui.text.input.PasswordVisualTransformation(),
                    trailingIcon = {
                        // Typing a long passphrase blind, twice, is how people end
                        // up choosing a short one.
                        androidx.compose.material3.TextButton(onClick = { visible = !visible }) {
                            androidx.compose.material3.Text(if (visible) "Hide" else "Show")
                        }
                    },
                )
            }
        },
        confirmButton = {
            androidx.compose.material3.TextButton(
                enabled = value.length >= requireLength,
                onClick = { onConfirm(value) },
            ) { androidx.compose.material3.Text(confirmLabel) }
        },
        dismissButton = {
            androidx.compose.material3.TextButton(onClick = onDismiss) {
                androidx.compose.material3.Text("Cancel")
            }
        },
    )
}

/** Shown while locked. Deliberately says nothing about the journal's contents. */
@Composable
private fun LockScreen(onUnlock: () -> Unit) {
    Box(Modifier.fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.Center) {
        Column(horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally) {
            androidx.compose.material3.Text(
                "DailyVox is locked",
                style = androidx.compose.material3.MaterialTheme.typography.headlineSmall,
                color = androidx.compose.material3.MaterialTheme.colorScheme.onBackground,
            )
            Spacer(Modifier.height(16.dp))
            androidx.compose.material3.Text(
                "Unlock",
                modifier = Modifier
                    .clip(androidx.compose.foundation.shape.RoundedCornerShape(18.dp))
                    .background(androidx.compose.material3.MaterialTheme.colorScheme.primary)
                    .clickable(onClick = onUnlock)
                    .padding(horizontal = 30.dp, vertical = 15.dp),
                color = androidx.compose.material3.MaterialTheme.colorScheme.onPrimary,
            )
        }
    }
}
