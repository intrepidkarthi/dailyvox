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
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dailyvox.app.data.Entry
import com.dailyvox.app.ui.AppViewModel
import com.dailyvox.app.ui.nav.DailyVoxNavBar
import com.dailyvox.app.ui.nav.Destination
import com.dailyvox.app.ui.screens.*
import com.dailyvox.app.ui.theme.DailyVoxTheme

/** Overlay routes: full screens that are not nav destinations. */
private enum class Overlay { NONE, INSIGHTS, SETTINGS }

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
    var theme by rememberSaveable { mutableStateOf(ThemeChoice.valueOf(prefs.getString("theme", "SYSTEM")!!)) }
    var current by rememberSaveable { mutableStateOf(Destination.SPEAK) }
    var overlay by rememberSaveable { mutableStateOf(Overlay.NONE) }
    var openEntry by remember { mutableStateOf<Entry?>(null) }
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
    var autoRecord by remember {
        mutableStateOf(activity.intent?.getBooleanExtra("start_recording", false) == true)
            .also { activity.intent?.removeExtra("start_recording") }
    }

    val askNotifications = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted ->
        // The switch already flipped. If the permission is refused, put it back
        // rather than leaving a toggle on that will never produce a notification.
        if (granted) com.dailyvox.app.system.Reminders.schedule(context, reminderHour)
        else { reminderOn = false; prefs.edit().putBoolean("reminder", false).apply() }
    }

    val pickBackup = rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.OpenDocument()
    ) { uri -> if (uri != null) vm.importFrom(context, uri) }

    val entries by vm.entries.collectAsStateWithLifecycle()
    val query by vm.query.collectAsStateWithLifecycle()
    val streak by vm.streak.collectAsStateWithLifecycle()
    val resolution by vm.resolution.collectAsStateWithLifecycle()

    val dark = when (theme) {
        ThemeChoice.LIGHT -> false
        ThemeChoice.DARK -> true
        ThemeChoice.SYSTEM -> isSystemInDarkTheme()
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
        LaunchedEffect(onboarded, reminderOn, reminderHour) {
            if (!onboarded) return@LaunchedEffect
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

        val chromeVisible = openEntry == null && overlay == Overlay.NONE

        Scaffold(
            modifier = Modifier.fillMaxSize(),
            bottomBar = {
                if (chromeVisible) DailyVoxNavBar(current = current, onSelect = { current = it })
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
                        onExport = { vm.export(context) },
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
                        firstEver = entries.isEmpty(),
                        autoStart = autoRecord,
                        onAutoStarted = { autoRecord = false },
                        onSaved = { text, secs, path -> vm.add(text, secs, path) },
                        onInsights = { overlay = Overlay.INSIGHTS },
                        onSettings = { overlay = Overlay.SETTINGS },
                        modifier = inner,
                    )
                    Destination.JOURNAL -> JournalScreen(
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
                    Destination.ASK -> AskScreen(entries = entries, modifier = inner)
                }
            }
        }
    }
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
