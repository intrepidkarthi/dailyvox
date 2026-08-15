package com.dailyvox.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.activity.viewModels
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import com.dailyvox.app.data.Entry
import com.dailyvox.app.ui.AppViewModel
import com.dailyvox.app.ui.nav.DailyVoxNavBar
import com.dailyvox.app.ui.nav.Destination
import com.dailyvox.app.ui.screens.*
import com.dailyvox.app.ui.theme.DailyVoxTheme

class MainActivity : ComponentActivity() {

    private val vm: AppViewModel by viewModels()

    override fun onCreate(savedInstanceState: Bundle?) {
        // Before setContent, and not optional on targetSdk 36:
        // windowOptOutEdgeToEdgeEnforcement is deprecated and disabled.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { DailyVoxTheme { DailyVoxApp(vm) } }
    }
}

@Composable
private fun DailyVoxApp(vm: AppViewModel) {
    var current by rememberSaveable { mutableStateOf(Destination.SPEAK) }
    var openEntry by remember { mutableStateOf<Entry?>(null) }

    val entries by vm.entries.collectAsStateWithLifecycle()
    val query by vm.query.collectAsStateWithLifecycle()
    val streak by vm.streak.collectAsStateWithLifecycle()
    val resolution by vm.resolution.collectAsStateWithLifecycle()

    // Predictive back, state-driven rather than branched after the fact. On
    // targetSdk 36 onBackPressed() is not called and KEYCODE_BACK is not
    // dispatched, so back has to be DECLARED for each state that owns it:
    // a detail sheet closes first, then any tab returns to Speak, and only
    // Speak itself falls through and exits.
    BackHandler(enabled = openEntry != null) { openEntry = null }
    BackHandler(enabled = openEntry == null && current != Destination.SPEAK) {
        current = Destination.SPEAK
    }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = {
            if (openEntry == null) {
                DailyVoxNavBar(current = current, onSelect = { current = it })
            }
        },
    ) { padding ->
        val inner = Modifier.padding(padding)
        val detail = openEntry
        if (detail != null) {
            EntryDetailScreen(
                entry = detail,
                onBack = { openEntry = null },
                onDelete = { vm.delete(detail.id); openEntry = null },
                modifier = inner,
            )
        } else when (current) {
            Destination.SPEAK -> SpeakScreen(
                streak = streak,
                resolution = resolution,
                onSaved = { text, secs -> vm.add(text, secs) },
                modifier = inner,
            )
            Destination.JOURNAL -> JournalScreen(
                entries = entries,
                query = query,
                onQuery = vm::setQuery,
                onOpen = { openEntry = it },
                modifier = inner,
            )
            Destination.TWIN -> TwinScreen(entries = entries, resolution = resolution, modifier = inner)
            Destination.ASK -> AskScreen(entries = entries, modifier = inner)
        }
    }
}
