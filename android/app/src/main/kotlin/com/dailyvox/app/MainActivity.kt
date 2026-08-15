package com.dailyvox.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.*
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import com.dailyvox.app.ui.theme.DailyVoxTheme

class MainActivity : ComponentActivity() {
    override fun onCreate(savedInstanceState: Bundle?) {
        // Edge-to-edge is called BEFORE setContent and is not optional on
        // targetSdk 36: windowOptOutEdgeToEdgeEnforcement is deprecated and
        // disabled. Every screen consumes WindowInsets explicitly from here on.
        enableEdgeToEdge()
        super.onCreate(savedInstanceState)
        setContent {
            DailyVoxTheme {
                Scaffold(modifier = Modifier.fillMaxSize()) { padding ->
                    Placeholder(Modifier.padding(padding))
                }
            }
        }
    }
}

@Composable
private fun Placeholder(modifier: Modifier = Modifier) {
    Box(modifier.fillMaxSize().safeDrawingPadding(), contentAlignment = androidx.compose.ui.Alignment.Center) {
        Text("Nothing you say leaves this phone.")
    }
}
