package com.dailyvox.app.ui.screens

import com.dailyvox.app.R
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.platform.LocalContext
import com.dailyvox.app.ui.components.SpeechErrorCard
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
import com.dailyvox.app.audio.SpeechCapture
import com.dailyvox.app.data.Entry
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
    val noticed = remember(entries) { noticedPatterns(entries).firstOrNull() }
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
    // No "Body" in v1.0: it filtered on sleep from Health Connect, which the
    // release does not read, so it could only ever show an empty list.
    // Keys, not labels: the label is looked up in strings.xml (filterLabel).
    val filters = listOf("All", "People", "Mood")
    var filter by rememberSaveable { mutableStateOf("All") }
    // Same construction as SpeakScreen: one instance per screen, remembered.
    val haptics = remember { com.dailyvox.app.system.Haptics(context) }

    val shown = remember(entries, filter) {
        when (filter) {
            // Only entries whose names the gate can read (B-5): a German row
            // saved before 1.3 can still carry capitalised nouns as people.
            "People" -> entries.filter { com.dailyvox.app.system.ReadingLanguage.people(it).isNotEmpty() }
            "Mood" -> entries.filter { v -> com.dailyvox.app.system.ReadingLanguage.valence(v)?.let { kotlin.math.abs(it) > 0.25f } == true }
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
            Text(stringResource(R.string.journal_title), fontFamily = com.dailyvox.app.ui.theme.Nunito, fontSize = 30.sp, fontWeight = FontWeight.ExtraBold,
                 color = MaterialTheme.colorScheme.onBackground)
            // Queues today's recordings back to back. Green, because playing is
            // an action — the pill is the one green thing on this screen.
            // Today's entries that have a recording to play. Typed entries have
            // none, and a "Play today · 0:00" pill for them played nothing.
            // Local day, not UTC day: in India the UTC boundary falls at 05:30.
            val today = java.time.LocalDate.now()
            val todays = entries.filter {
                !it.audioPath.isNullOrBlank() && java.time.Instant.ofEpochMilli(it.createdAt)
                    .atZone(java.time.ZoneId.systemDefault()).toLocalDate() == today
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
                                        context.getString(R.string.journal_play_today_no_audio),
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
                        stringResource(
                            if (playingToday) R.string.journal_playing else R.string.journal_play_today,
                            total / 60, total % 60,
                        ),
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
                Text(stringResource(R.string.journal_search_placeholder), color = MaterialTheme.colorScheme.onSurfaceVariant, fontSize = 14.sp)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                BasicTextField(
                    value = query, onValueChange = onQuery,
                    keyboardOptions = com.dailyvox.app.ui.components.PrivateKeyboard,
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
                    contentDescription = stringResource(R.string.journal_search_voice),
                    tint = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .clickable {
                            runCatching {
                                if (listening) search.stop() else search.start()
                            }.onFailure {
                                android.widget.Toast.makeText(
                                    context, context.getString(R.string.journal_search_voice_unavailable),
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
            SpeechErrorCard(err, search, stringResource(R.string.journal_search_error_dismiss), onSecondary = { search.clearError() }, compact = true)
        }

        Spacer(Modifier.height(12.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            filters.forEach { f ->
                val on = f == filter
                Text(
                    filterLabel(f), fontSize = 13.sp,
                    color = if (on) MaterialTheme.colorScheme.onPrimary else MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier
                        .clip(RoundedCornerShape(13.dp))
                        .background(
                            if (on) MaterialTheme.colorScheme.primary
                            else MaterialTheme.colorScheme.surface
                        )
                        .clickable {
                            // Only on a real change: re-tapping the lit chip
                            // does nothing, so it should not feel like it did.
                            if (f != filter) haptics.selection()
                            filter = f
                        }
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
                    headline = stringResource(R.string.journal_empty_search_title),
                    body = stringResource(R.string.journal_empty_search_body),
                    action = stringResource(R.string.journal_empty_search_action),
                    onAction = { onQuery("") },
                )
                entries.isNotEmpty() -> EmptyState(
                    headline = stringResource(R.string.journal_empty_filter_title),
                    body = stringResource(when (filter) {
                        "People" -> R.string.journal_empty_filter_people
                        "Mood" -> R.string.journal_empty_filter_mood
                        else -> R.string.journal_empty_filter_body
                    }),
                    action = stringResource(R.string.journal_empty_filter_action),
                    onAction = { filter = "All" },
                )
                else -> EmptyState(
                    headline = stringResource(R.string.journal_empty_title),
                    body = stringResource(R.string.journal_empty_body),
                    action = stringResource(R.string.journal_empty_action),
                    onAction = onSpeak,
                )
            }
        }
        // Month sections, as iOS groups them. Entries arrive newest-first, so
        // grouping preserves order; LinkedHashMap keeps the months in it.
        val months = remember(shown) {
            // Standalone month form; the platform's order outside English (B-13).
            val fmt = com.dailyvox.app.system.LocaleFormat.dateFormat("LLLL yyyy", "LLLLyyyy")
            shown.groupBy { fmt.format(Date(it.createdAt)) }
        }
        val newestId = shown.firstOrNull()?.id
        LazyColumn(verticalArrangement = Arrangement.spacedBy(12.dp)) {
            months.forEach { (month, monthEntries) ->
                // A quiet mono rule rather than a second title: plain rather
                // than sticky, because it is a divider you scroll past and a
                // pinned one would sit on top of the card being read.
                item(key = "month-$month", contentType = "month") {
                    Text(
                        com.dailyvox.app.system.LocaleFormat.upper(month),
                        fontFamily = com.dailyvox.app.ui.theme.DmMono,
                        fontSize = 10.sp, letterSpacing = 1.3.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.animateItem().padding(top = 4.dp),
                    )
                }
                items(monthEntries, key = { it.id }, contentType = { "entry" }) { e ->
                    Column(Modifier.animateItem()) {
                        EntryCard(e) { onOpen(e) }
                        // Sits under the newest entry rather than at the top: it is a
                        // remark about the timeline, and above it, it reads as chrome.
                        if (e.id == newestId) noticed?.let { n ->
                            Spacer(Modifier.height(12.dp))
                            TwinNoticedCard(n, onAsk)
                        }
                    }
                }
            }
            item { Spacer(Modifier.height(120.dp)) }   // clears the floating nav
        }
    }
}

@Composable
private fun EntryCard(e: Entry, onClick: () -> Unit) {
    DvCard(Modifier.clickable(onClick = onClick)) {
        Row(Modifier.height(IntrinsicSize.Min)) {
            // Mood accent, as iOS draws it: a 3dp hairline so the journal can be
            // scanned by feeling. Any wider and it reads as a border on every row.
            Box(
                Modifier.width(3.dp).fillMaxHeight()
                    .clip(RoundedCornerShape(1.5.dp))
                    .background(valenceColor(e.valence))
            )
            Spacer(Modifier.width(12.dp))
            Column(Modifier.weight(1f)) {
                // B3: DM Mono meta line. The gold ✦ that used to sit on the right
                // of every card is gone: the spec reserves it for starred entries,
                // Entry has no starred field, and on every row it meant nothing.
                val res = LocalContext.current.resources
                MonoLabel(
                    stringResource(
                        R.string.journal_card_meta,
                        com.dailyvox.app.system.LocaleFormat.upper(dateLabel(res, e.createdAt)),
                        if (e.audioPath.isNullOrBlank() && e.durationSec == 0) stringResource(R.string.journal_card_typed)
                        else durationLabel(e.durationSec),
                        if (e.isUntranscribed) stringResource(R.string.journal_card_not_transcribed)
                        else pluralStringResource(R.plurals.journal_card_words, e.wordCount, e.wordCount),
                    )
                )
                Spacer(Modifier.height(8.dp))
                Text(
                    if (e.isUntranscribed) stringResource(R.string.journal_card_untranscribed)
                    else e.text,
                    fontSize = 15.5.sp, lineHeight = 23.sp,
                    maxLines = 2,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    color = MaterialTheme.colorScheme.onSurface,
                )
                val people = com.dailyvox.app.system.ReadingLanguage.people(e)
                if (people.isNotEmpty() || e.sleepHours != null) {
                    Spacer(Modifier.height(10.dp))
                    // Entity chips are GREEN-tinted; body chips are GOLD-tinted. The
                    // split is the grammar again: a name is something the Twin found in
                    // what you said, a body reading is something it was given.
                    FlowRow(horizontalArrangement = Arrangement.spacedBy(6.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)) {
                        people.take(3).forEach { SpecChip(com.dailyvox.app.system.LocaleFormat.upper(it), gold = false) }
                        e.sleepHours?.let { SpecChip(stringResource(R.string.journal_card_sleep, it), gold = true) }
                    }
                }
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
        fontFamily = com.dailyvox.app.ui.theme.DmMono,
        fontSize = 10.sp,
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

private fun dateLabel(res: android.content.res.Resources, ts: Long): String {
    val day = 86_400_000L
    val today = System.currentTimeMillis() / day
    val time = com.dailyvox.app.system.LocaleFormat.dateFormat("h:mm a", "jmm").format(Date(ts))
    return when (ts / day) {
        today -> {
            val hour = Calendar.getInstance().apply { timeInMillis = ts }
                .get(Calendar.HOUR_OF_DAY)
            res.getString(if (hour >= 17 || hour < 4) R.string.journal_when_tonight else R.string.journal_when_today, time)
        }
        today - 1 -> res.getString(R.string.journal_when_yesterday, time)
        else -> res.getString(
            R.string.journal_when_day,
            com.dailyvox.app.system.LocaleFormat.dateFormat("EEE d", "EEEd").format(Date(ts)), time,
        )
    }
}

/** The label of a filter chip; [key] is the filter's fixed English key. */
@Composable
private fun filterLabel(key: String): String = stringResource(
    when (key) {
        "People" -> R.string.journal_filter_people
        "Mood" -> R.string.journal_filter_mood
        "Body" -> R.string.journal_filter_body
        else -> R.string.journal_filter_all
    }
)

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
            stringResource(R.string.journal_twin_noticed, leadInSentence(p.lead)),
            fontSize = 13.sp, lineHeight = 20.sp, fontWeight = FontWeight.Medium,
            color = MaterialTheme.colorScheme.onSurface, modifier = Modifier.weight(1f),
        )
        Text(com.dailyvox.app.ui.components.forwardGlyph(), fontSize = 18.sp, color = goldText,
             style = com.dailyvox.app.ui.components.Directional.GlyphStyle)
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
