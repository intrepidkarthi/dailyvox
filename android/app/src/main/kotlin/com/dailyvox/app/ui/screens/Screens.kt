package com.dailyvox.app.ui.screens

import androidx.compose.foundation.layout.*
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp

/**
 * Placeholder destinations. Each carries the design package's actual headline so
 * the copy is settled before the UI is, and a max-width text column because
 * Play's Line_Length criterion is 45-75 characters -- a full-width Column on a
 * tablet blows past it immediately, and retrofitting is the expensive version.
 */
@Composable
private fun Placeholder(title: String, body: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxSize().padding(24.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Column(Modifier.widthIn(max = 600.dp)) {
            Text(title, style = MaterialTheme.typography.headlineMedium, color = MaterialTheme.colorScheme.onBackground)
            Spacer(Modifier.height(12.dp))
            Text(body, style = MaterialTheme.typography.bodyMedium, color = MaterialTheme.colorScheme.onSurfaceVariant, textAlign = TextAlign.Start)
        }
    }
}

@Composable fun SpeakScreen(m: Modifier = Modifier) =
    Placeholder("Tonight's forty-two seconds.", "Hold, or tap to start. Also on your home screen and Quick Settings.", m)

@Composable fun JournalScreen(m: Modifier = Modifier) =
    Placeholder("Journal", "Search by meaning, not keywords.", m)

@Composable fun TwinScreen(m: Modifier = Modifier) =
    Placeholder("Your Twin", "The sky is always night — this screen stays dark in both themes.", m)

@Composable fun AskScreen(m: Modifier = Modifier) =
    Placeholder("Ask your Twin", "On-device. Offline. Zero calls.", m)
