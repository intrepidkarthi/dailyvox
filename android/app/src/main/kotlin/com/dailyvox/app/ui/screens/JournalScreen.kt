package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import com.dailyvox.app.ui.components.*
import java.text.SimpleDateFormat
import java.util.*

@Composable
fun JournalScreen(
    entries: List<Entry>,
    query: String,
    onQuery: (String) -> Unit,
    onOpen: (Entry) -> Unit,
    modifier: Modifier = Modifier,
) {
    val filters = listOf("All", "People", "Mood", "Body")
    var filter by rememberSaveable { mutableStateOf("All") }

    val shown = remember(entries, filter) {
        when (filter) {
            "People" -> entries.filter { it.entityList.isNotEmpty() }
            "Mood" -> entries.filter { kotlin.math.abs(it.valence) > 0.25f }
            "Body" -> entries.filter { it.sleepHours != null }
            else -> entries
        }
    }

    Column(modifier.fillMaxSize().padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(12.dp))
        ScreenTitle("Journal") {
            MonoLabel("${entries.size} entries")
        }

        // "Search by meaning" is the design's phrasing and the eventual engine
        // call. Today it is content-word overlap -- the same lexical leg the iOS
        // retriever already weights at 60% -- so the label is not a promise the
        // implementation breaks, just one it does not yet fully keep.
        Box(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(MaterialTheme.colorScheme.surfaceVariant)
                .padding(horizontal = 16.dp, vertical = 14.dp)
        ) {
            if (query.isEmpty()) {
                Text("Search by meaning", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 15.sp)
            }
            BasicTextField(
                value = query, onValueChange = onQuery,
                singleLine = true,
                textStyle = TextStyle(color = MaterialTheme.colorScheme.onSurface, fontSize = 15.sp),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(MaterialTheme.colorScheme.secondary),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            filters.forEach { f ->
                val on = f == filter
                Text(
                    f, fontSize = 13.sp,
                    color = if (on) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .clip(RoundedCornerShape(14.dp))
                        .background(if (on) MaterialTheme.colorScheme.secondary else MaterialTheme.colorScheme.surfaceVariant)
                        .clickable { filter = f }
                        .padding(horizontal = 14.dp, vertical = 8.dp)
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        if (shown.isEmpty()) {
            Box(Modifier.fillMaxWidth().padding(top = 60.dp), contentAlignment = Alignment.Center) {
                Text(
                    if (query.isNotEmpty()) "Nothing matches that yet."
                    else "Your first star is one tap away.",
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(shown, key = { it.id }) { e -> EntryCard(e) { onOpen(e) } }
            item { Spacer(Modifier.height(120.dp)) }   // clears the floating nav
        }
    }
}

@Composable
private fun EntryCard(e: Entry, onClick: () -> Unit) {
    DvCard(Modifier.clickable(onClick = onClick)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            ValenceDot(e.valence)
            Spacer(Modifier.width(8.dp))
            Text(
                dateLabel(e.createdAt),
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurface,
            )
            Spacer(Modifier.weight(1f))
            MonoLabel(durationLabel(e.durationSec))
        }
        Spacer(Modifier.height(8.dp))
        Text(
            e.text, fontSize = 15.sp, lineHeight = 23.sp,
            maxLines = 3,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurface,
        )
        if (e.entityList.isNotEmpty() || e.sleepHours != null) {
            Spacer(Modifier.height(10.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                e.entityList.take(3).forEach { Chip(it) }
                e.sleepHours?.let { Chip("slept ${"%.1f".format(it)}h", MaterialTheme.colorScheme.tertiary) }
            }
        }
    }
}

private fun dateLabel(ts: Long): String =
    SimpleDateFormat("EEE d · h:mm a", Locale.getDefault()).format(Date(ts))

private fun durationLabel(s: Int): String = "%d:%02d".format(s / 60, s % 60)
