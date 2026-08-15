package com.dailyvox.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
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

class MainActivity : ComponentActivity() {

    private val vm: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before setContent, and not optional on targetSdk 36:
        // windowOptOutEdgeToEdgeEnforcement is deprecated and disabled.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { DailyVoxApp(vm) }
    }
}

@Composable
private fun DailyVoxApp(vm: AppViewModel) {
    val context = LocalContext.current
    val prefs = remember { context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE) }

    var onboarded by rememberSaveable { mutableStateOf(prefs.getBoolean("onboarded", false)) }
    var theme by rememberSaveable { mutableStateOf(ThemeChoice.valueOf(prefs.getString("theme", "SYSTEM")!!)) }
    var current by rememberSaveable { mutableStateOf(Destination.SPEAK) }
    var overlay by rememberSaveable { mutableStateOf(Overlay.NONE) }
    var openEntry by remember { mutableStateOf<Entry?>(null) }

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
            OnboardingScreen(onDone = {
                prefs.edit().putBoolean("onboarded", true).apply()
                onboarded = true
            })
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
                    modifier = inner,
                )

                overlay == Overlay.INSIGHTS -> BackedScreen("Insights", { overlay = Overlay.NONE }, inner) { m ->
                    InsightsScreen(entries = entries, streak = streak, modifier = m)
                }

                overlay == Overlay.SETTINGS -> BackedScreen("Settings", { overlay = Overlay.NONE }, inner) { m ->
                    SettingsScreen(
                        entryCount = entries.size,
                        theme = theme,
                        onTheme = { theme = it; prefs.edit().putString("theme", it.name).apply() },
                        onExport = { vm.export(context) },
                        modifier = m,
                    )
                }

                else -> when (current) {
                    Destination.SPEAK -> SpeakScreen(
                        streak = streak,
                        resolution = resolution,
                        onSaved = { text, secs -> vm.add(text, secs) },
                        onInsights = { overlay = Overlay.INSIGHTS },
                        onSettings = { overlay = Overlay.SETTINGS },
                        modifier = inner,
                    )
                    Destination.JOURNAL -> JournalScreen(
                        entries = entries, query = query, onQuery = vm::setQuery,
                        onOpen = { openEntry = it }, modifier = inner,
                    )
                    Destination.TWIN -> TwinScreen(entries = entries, resolution = resolution, modifier = inner)
                    Destination.ASK -> AskScreen(entries = entries, modifier = inner)
                }
            }
        }
    }
}

/** Overlay screens keep their own back affordance, since the nav bar is hidden. */
@Composable
private fun BackedScreen(
    title: String,
    onBack: () -> Unit,
    modifier: Modifier,
    content: @Composable (Modifier) -> Unit,
) {
    Box(modifier.fillMaxSize()) {
        content(Modifier.fillMaxSize())
        androidx.compose.material3.Text(
            "‹ back",
            modifier = Modifier
                .align(androidx.compose.ui.Alignment.BottomCenter)
                .padding(bottom = 34.dp)
                .clip(androidx.compose.foundation.shape.RoundedCornerShape(20.dp))
                // Opaque: this floats over scrolling content, and without a
                // surface behind it the label collides with whatever is beneath.
                .background(androidx.compose.material3.MaterialTheme.colorScheme.surfaceVariant)
                .clickable(onClick = onBack)
                .defaultMinSize(minHeight = 48.dp)
                .padding(horizontal = 26.dp, vertical = 13.dp),
            color = androidx.compose.material3.MaterialTheme.colorScheme.onSurfaceVariant,
        )
    }
}
