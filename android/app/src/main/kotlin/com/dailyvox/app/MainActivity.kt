package com.dailyvox.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.BackHandler
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Scaffold
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Modifier
import com.dailyvox.app.ui.nav.DailyVoxNavBar
import com.dailyvox.app.ui.nav.Destination
import com.dailyvox.app.ui.screens.*
import com.dailyvox.app.ui.theme.DailyVoxTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Before setContent, and not optional on targetSdk 36:
        // windowOptOutEdgeToEdgeEnforcement is deprecated and disabled.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent { DailyVoxTheme { DailyVoxApp() } }
    }
}

@Composable
private fun DailyVoxApp() {
    var current by rememberSaveable { mutableStateOf(Destination.SPEAK) }

    // Predictive back, state-driven rather than branched after the fact.
    // On targetSdk 36 onBackPressed() is not called and KEYCODE_BACK is not
    // dispatched, so back behaviour has to be declared, not intercepted.
    // Enabled only when there is somewhere to go back TO: from any destination
    // back returns to Speak; from Speak it falls through and exits, which is
    // what Android users expect from a start destination.
    BackHandler(enabled = current != Destination.SPEAK) { current = Destination.SPEAK }

    Scaffold(
        modifier = Modifier.fillMaxSize(),
        bottomBar = { DailyVoxNavBar(current = current, onSelect = { current = it }) },
    ) { padding ->
        val inner = Modifier.padding(padding)
        when (current) {
            Destination.SPEAK -> SpeakScreen(inner)
            Destination.JOURNAL -> JournalScreen(inner)
            Destination.TWIN -> TwinScreen(inner)
            Destination.ASK -> AskScreen(inner)
        }
    }
}
