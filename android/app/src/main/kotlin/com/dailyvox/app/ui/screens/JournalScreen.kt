package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.itemsIndexed
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
import com.dailyvox.app.audio.SpeechCapture
import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.toChatEntry
import com.dailyvox.twin.Insights
import com.dailyvox.app.ui.theme.Gold
import androidx.compose.foundation.layout.FlowRow
import com.dailyvox.app.ui.components.*
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.*

@Composable
fun JournalScreen(
    entries: List<Entry>,
    query: String,
    onQuery: (String) -> Unit,
    onOpen: (Entry) -> Unit,
    onSpeak: () -> Unit = {},
    onAsk: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    // The strongest finding the Twin has, computed from the same code Insights
    // uses rather than a second copy of the thresholds. Null until the data
    // carries one, which is the point of the gates in Patterns.
    val noticed = remember(entries) { Insights.find(entries.map { it.toChatEntry() }).firstOrNull() }
    val queue = remember { com.dailyvox.app.audio.AudioQueue() }
    var playingToday by remember { mutableStateOf(false) }
    DisposableEffect(Unit) { onDispose { queue.stop() } }
    // Voice search. Same recogniser as the journal itself -- searching a voice
    // journal by typing was always the odd part.
    //
    // It used to launch ACTION_RECOGNIZE_SPEECH as an activity, which hands the
    // microphone to Google's voice-input UI: a different process, with its own
    // INTERNET permission, free to transcribe the query on a server. The query
    // is a line out of the user's diary ("what did I say about Ravi"), so that
    // was the same leak the recording path had, one screen over -- and iOS
    // shipped and fixed exactly this pair in v1.11.0.
    //
    // SpeechCapture instead: same on-device-only recognizer as recording, and
    // the partial results let the results filter as the sentence is spoken.
    val search = remember { SpeechCapture(context) }
    DisposableEffect(Unit) { onDispose { search.release() } }
    val searchState by search.state.collectAsState()
    val searchPartial by search.partial.collectAsState()
    val searchError by search.error.collectAsState()
    val listening = searchState != SpeechCapture.State.IDLE
    LaunchedEffect(searchPartial) { if (searchPartial.isNotBlank()) onQuery(searchPartial) }
    LaunchedEffect(Unit) { search.finished.collect { if (it.isNotBlank()) onQuery(it) } }
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
        Row(
            Modifier.fillMaxWidth().padding(bottom = 10.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("Journal", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold,
                 color = MaterialTheme.colorScheme.onBackground)
            // Queues today's recordings back to back. Green, because playing is
            // an action — the pill is the one green thing on this screen.
            val todays = entries.filter {
                it.createdAt / 86_400_000L == System.currentTimeMillis() / 86_400_000L
            }
            if (todays.isNotEmpty()) {
                val total = todays.sumOf { it.durationSec }
                Row(
                    Modifier
                        .clip(RoundedCornerShape(15.dp))
                        .background(MaterialTheme.colorScheme.primary)
                        .clickable {
                            if (playingToday) { queue.stop(); playingToday = false }
                            else {
                                val paths = todays.sortedBy { it.createdAt }
                                    .mapNotNull { it.audioPath }
                                if (paths.isEmpty()) {
                                    android.widget.Toast.makeText(
                                        context,
                                        "Today's entries have no audio saved.",
                                        android.widget.Toast.LENGTH_SHORT,
                                    ).show()
                                } else {
                                    playingToday = true
                                    queue.play(paths) { playingToday = false }
                                }
                            }
                        }
                        .padding(horizontal = 13.dp, vertical = 9.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp),
                ) {
                    Text(if (playingToday) "■" else "▶", fontSize = 10.sp,
                         color = MaterialTheme.colorScheme.onPrimary)
                    Text(
                        if (playingToday) "Playing · %d:%02d".format(total / 60, total % 60)
                        else "Play today · %d:%02d".format(total / 60, total % 60),
                        fontSize = 10.5.sp, fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.onPrimary,
                    )
                }
            }
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
                Text("Describe it — search what you meant", color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 12.5.sp)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                BasicTextField(
                    value = query, onValueChange = onQuery,
                    singleLine = true,
                    textStyle = TextStyle(color = MaterialTheme.colorScheme.onSurface, fontSize = 15.sp),
                    cursorBrush = androidx.compose.ui.graphics.SolidColor(MaterialTheme.colorScheme.secondary),
                    modifier = Modifier.weight(1f),
                )
                // Vector, not the 🎙 emoji this used to be. A colour emoji in a
                // monochrome ink/cream palette reads as a rendering bug, and it
                // is the same mistake the hand-drawn nav icons were.
                androidx.compose.material3.Icon(
                    painter = androidx.compose.ui.res.painterResource(com.dailyvox.app.R.drawable.ic_nav_speak),
                    contentDescription = "Search by voice",
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .clickable {
                            runCatching {
                                if (listening) search.stop() else search.start()
                            }.onFailure {
                                android.widget.Toast.makeText(
                                    context, "No voice input on this device.",
                                    android.widget.Toast.LENGTH_SHORT,
                                ).show()
                            }
                        }
                        .padding(10.dp)
                        .size(22.dp),
                )
            }
        }

        searchError?.let { err ->
            Spacer(Modifier.height(10.dp))
            Column(
                Modifier.fillMaxWidth()
                    .clip(RoundedCornerShape(14.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .clickable { search.clearError() }
                    .padding(14.dp),
            ) {
                Text(err.message, fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                     color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(5.dp))
                Text(err.fix, fontSize = 12.sp, lineHeight = 18.sp,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
                if (err.openLanguageSettings) {
                    Spacer(Modifier.height(10.dp))
                    Text(
                        "Open speech settings",
                        fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onPrimary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(13.dp))
                            .background(MaterialTheme.colorScheme.primary)
                            .clickable {
                                // Same three-step fallback the record screen
                                // uses: the voice-input screen is not on every
                                // OEM, so the general locale screen is the last
                                // resort rather than a dead button.
                                listOf(
                                    "com.android.settings.VOICE_INPUT_SETTINGS",
                                    android.provider.Settings.ACTION_VOICE_INPUT_SETTINGS,
                                    android.provider.Settings.ACTION_LOCALE_SETTINGS,
                                ).firstOrNull { action ->
                                    runCatching {
                                        context.startActivity(
                                            android.content.Intent(action)
                                                .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                        )
                                    }.isSuccess
                                }
                            }
                            .padding(horizontal = 12.dp, vertical = 7.dp),
                    )
                }
            }
        }

        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            filters.forEach { f ->
                val on = f == filter
                Text(
                    f, fontSize = 13.sp,
                    color = if (on) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .clip(RoundedCornerShape(13.dp))
                        .background(
                            if (on) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.surface
                        )
                        .clickable { filter = f }
                        .padding(horizontal = 12.dp, vertical = 7.dp)
                )
            }
        }

        Spacer(Modifier.height(14.dp))
        if (shown.isEmpty()) {
            // Three distinct empties, because they are three different
            // situations and one shared message would be wrong for two of them.
            when {
                query.isNotEmpty() -> EmptyState(
                    headline = "Nothing matches that",
                    body = "Search looks at the words in your entries and the people your Twin has filed. Try a name, or fewer words.",
                    action = "Clear the search",
                    onAction = { onQuery("") },
                )
                entries.isNotEmpty() -> EmptyState(
                    headline = "No entries in this filter",
                    body = when (filter) {
                        "People" -> "None of your entries mention a name your Twin recognised yet."
                        "Mood" -> "Nothing here reads strongly either way — that is its own kind of week."
                        else -> "No entry has body context attached yet."
                    },
                    action = "Show everything",
                    onAction = { filter = "All" },
                )
                else -> EmptyState(
                    headline = "Your first star is one tap away",
                    body = "Speak for forty-two seconds. It stays on this phone, and the Twin starts from there.",
                    action = "Speak tonight",
                    onAction = onSpeak,
                )
            }
        }
        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            itemsIndexed(shown, key = { _, e -> e.id }) { i, e ->
                EntryCard(e) { onOpen(e) }
                // Sits under the newest entry rather than at the top: it is a
                // remark about the timeline, and above it, it reads as chrome.
                if (i == 0) noticed?.let { n ->
                    Spacer(Modifier.height(12.dp))
                    TwinNoticedCard(n, onAsk)
                }
            }
            item { Spacer(Modifier.height(120.dp)) }   // clears the floating nav
        }
    }
}

@Composable
private fun EntryCard(e: Entry, onClick: () -> Unit) {
    DvCard(Modifier.clickable(onClick = onClick)) {
        // B3: DM Mono meta line, gold star on the right for a made thing.
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
            MonoLabel(
                "${dateLabel(e.createdAt).uppercase()} · ${durationLabel(e.durationSec)} · ${e.text.split(" ").size} WORDS"
            )
            Text("✦", fontSize = 12.sp, color = Gold)
        }
        Spacer(Modifier.height(8.dp))
        Text(
            e.text, fontSize = 13.sp, lineHeight = 20.sp,
            maxLines = 2,
            overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
            color = MaterialTheme.colorScheme.onSurface,
        )
        if (e.entityList.isNotEmpty() || e.sleepHours != null) {
            Spacer(Modifier.height(10.dp))
            // Entity chips are GREEN-tinted; body chips are GOLD-tinted. The
            // split is the grammar again: a name is something the Twin found in
            // what you said, a body reading is something it was given.
            FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)) {
                e.entityList.take(3).forEach { SpecChip(it.uppercase(), gold = false) }
                e.sleepHours?.let { SpecChip("%.1fH SLEEP".format(it), gold = true) }
            }
        }
    }
}

/** The design's chip: DM Mono 9.5, radius 10, green tint or gold tint. */
@Composable
private fun SpecChip(text: String, gold: Boolean) {
    val night = MaterialTheme.colorScheme.background == com.dailyvox.app.ui.theme.NightBackground
    Text(
        text,
        fontSize = 9.5.sp,
        letterSpacing = 0.6.sp,
        fontWeight = FontWeight.SemiBold,
        color = when {
            gold && night -> com.dailyvox.app.ui.theme.NightGoldText
            gold -> com.dailyvox.app.ui.theme.DayGoldText
            night -> MaterialTheme.colorScheme.onSurface
            else -> com.dailyvox.app.ui.theme.DayAction
        },
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(
                when {
                    gold && night -> Gold.copy(alpha = 0.16f)
                    gold -> com.dailyvox.app.ui.theme.DayGoldTint
                    night -> Gold.copy(alpha = 0.10f)
                    else -> com.dailyvox.app.ui.theme.DayGreenTint
                }
            )
            .padding(horizontal = 9.dp, vertical = 5.dp),
    )
}

private fun dateLabel(ts: Long): String {
    val day = 86_400_000L
    val today = System.currentTimeMillis() / day
    val time = SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(ts))
    return when (ts / day) {
        today -> {
            val hour = Calendar.getInstance().apply { timeInMillis = ts }
                .get(Calendar.HOUR_OF_DAY)
            if (hour >= 17 || hour < 4) "Tonight · $time" else "Today · $time"
        }
        today - 1 -> "Yesterday · $time"
        else -> SimpleDateFormat("EEE d · h:mm a", Locale.getDefault()).format(Date(ts))
    }
}

private fun durationLabel(s: Int): String = "%d:%02d".format(s / 60, s % 60)

/**
 * B3's gold-tint remark in the timeline. It is a pointer, not a finding: the
 * numbers live in Insights, and repeating them here would make the journal
 * argue with itself.
 */
@Composable
private fun TwinNoticedCard(p: Insights.Finding, onAsk: () -> Unit) {
    val night = MaterialTheme.colorScheme.background == com.dailyvox.app.ui.theme.NightBackground
    val goldText = if (night) com.dailyvox.app.ui.theme.NightGoldText
                   else com.dailyvox.app.ui.theme.DayGoldText
    Row(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(com.dailyvox.app.ui.theme.Gold.copy(alpha = if (night) 0.14f else 0.13f))
            .clickable(onClick = onAsk)
            .padding(15.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text("\u2726", fontSize = 14.sp, color = goldText)
        Spacer(Modifier.width(11.dp))
        Text(
            "Twin noticed: ${leadInSentence(p.lead)}. Ask about it.",
            fontSize = 13.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f),
        )
        Text("\u203A", fontSize = 18.sp, color = goldText)
    }
}


/**
 * Fold a finding's lead into the middle of a sentence.
 *
 * Lower-casing the first character unconditionally is wrong for half of them:
 * the person finding reads "Mumbai lifts you", and the card rendered it as
 * "Twin noticed: mumbai lifts you" -- lower-casing a proper noun, on a card
 * whose whole job is to look like the Twin knows who you are.
 *
 * Leads that start with a name are left alone. Everything else ("Saturdays run
 * high", "Sleep shows up") is sentence-cased as before. The test is whether the
 * SECOND character is upper case too, which no ordinary sentence opener has and
 * an acronym does, plus the weekday and part-of-day leads which are known.
 */
private fun leadInSentence(lead: String): String {
    val body = lead.trimEnd('.')
    val first = body.substringBefore(' ')
    val startsWithSentenceWord = first in SENTENCE_LEADS ||
        first.trimEnd('s') in SENTENCE_LEADS
    return if (startsWithSentenceWord) body.replaceFirstChar { it.lowercase() } else body
}

/**
 * The words a finding can open with that are ordinary vocabulary rather than
 * something out of the user's own life. Everything Insights can emit is here;
 * anything else reaching this function is a name, and names keep their capital.
 */
private val SENTENCE_LEADS = setOf(
    "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday",
    "Sleep", "Moving", "Busy", "Your",
)
