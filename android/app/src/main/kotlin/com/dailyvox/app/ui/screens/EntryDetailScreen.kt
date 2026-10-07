package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.gestures.detectHorizontalDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import com.dailyvox.app.ui.theme.Nunito
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.style.TextDecoration
import com.dailyvox.app.ui.components.*
import java.text.SimpleDateFormat
import java.util.*

/**
 * "What your Twin filed" is the load-bearing idea on this screen and the reason
 * it exists at all: the user sees exactly what was derived from their words, in
 * the same place as the words. That is the mirror-not-oracle contract made
 * visible, and it is also the only honest way to ship a heuristic detector --
 * the user can see it was wrong.
 */
@Composable
fun EntryDetailScreen(
    entry: Entry,
    onBack: () -> Unit,
    onDelete: () -> Unit,
    onSelfLabel: (String?) -> Unit = {},
    onPhoto: (String?) -> Unit = {},
    /** B4: correct what the recogniser heard. Transcription is good, not right. */
    onEdit: (String) -> Unit = {},
    /** B4: open the Twin with this entry as the question. */
    onAsk: (String) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    var editing by remember { mutableStateOf(false) }

    // What "Ask about this" actually asks. Dated rather than quoted: retrieval
    // finds the entry from its date anyway, and pasting the transcript into the
    // question makes the answer echo the entry back instead of relating it to
    // everything around it.
    val askSeed = remember(entry.id) {
        val on = SimpleDateFormat("MMMM d", Locale.getDefault()).format(Date(entry.createdAt))
        val who = entry.entityList.firstOrNull()
        if (who != null) "What do my entries say about $who, around $on?"
        else "What was going on for me around $on?"
    }
    val speaker = remember { com.dailyvox.app.system.Speaker(context) }
    var speaking by remember { mutableStateOf(false) }
    DisposableEffect(Unit) { onDispose { speaker.release() } }

    // Photo picker, not READ_MEDIA_IMAGES. PickVisualMedia routes through the
    // system photo picker, which grants access to the single chosen image and
    // needs no permission at all -- asking a privacy-first journal's users for
    // the whole gallery to attach one picture would be indefensible.
    val pickPhoto = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia()
    ) { uri ->
        if (uri != null) {
            val dest = java.io.File(context.filesDir, "photo-${entry.id}.jpg")
            runCatching {
                context.contentResolver.openInputStream(uri)!!.use { input ->
                    dest.outputStream().use { input.copyTo(it) }
                }
                // COPIED, not referenced. A content:// URI dies when the source
                // photo is deleted or the grant lapses, and the entry would then
                // show a permanent broken image.
                onPhoto(dest.absolutePath)
            }
        }
    }
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(8.dp))
        var menu by remember { mutableStateOf(false) }
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("‹", fontSize = 30.sp, color = MaterialTheme.colorScheme.onBackground,
                 modifier = Modifier
                     .clip(CircleShape)
                     .clickable(onClick = onBack)
                     .defaultMinSize(48.dp, 48.dp)
                     .wrapContentSize())
            Spacer(Modifier.width(6.dp))
            Column(Modifier.weight(1f)) {
                Text(SimpleDateFormat("EEEE d MMMM", Locale.getDefault()).format(Date(entry.createdAt)),
                     fontSize = 21.sp, fontWeight = FontWeight.ExtraBold, fontFamily = Nunito,
                     color = MaterialTheme.colorScheme.onBackground)
                MonoLabel("${SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(entry.createdAt))} · ${if (entry.audioPath.isNullOrBlank() && entry.durationSec == 0) "typed" else "${entry.durationSec / 60}:${"%02d".format(entry.durationSec % 60)}"} · ${if (entry.isUntranscribed) "not transcribed" else "${entry.wordCount} words"}")
            }
            // Read aloud and Delete live here rather than in the action row.
            // Neither is what you came to the entry to do, and Delete sitting at
            // equal weight beside Ask made the destructive action the easy one.
            Box {
                var confirmDelete by remember { mutableStateOf(false) }
                DotsButton(onClick = { menu = true })
                DropdownMenu(expanded = menu, onDismissRequest = { menu = false }) {
                    DropdownMenuItem(
                        text = { Text(if (speaking) "Stop reading" else "Read aloud") },
                        onClick = { menu = false; speaker.toggle(entry.text); speaking = !speaking },
                    )
                    DropdownMenuItem(
                        text = { Text("Delete", color = MaterialTheme.colorScheme.error) },
                        onClick = { menu = false; confirmDelete = true },
                    )
                }
                // Deleting a diary entry is the one action here that cannot be
                // undone -- there is no account and no cloud copy to restore
                // it from -- so it asks once.
                if (confirmDelete) androidx.compose.material3.AlertDialog(
                    onDismissRequest = { confirmDelete = false },
                    title = { Text("Delete this entry?", fontFamily = Nunito, fontWeight = FontWeight.ExtraBold) },
                    text = { Text("The words and the recording are removed from this phone. This cannot be undone.") },
                    confirmButton = {
                        androidx.compose.material3.TextButton(onClick = { confirmDelete = false; onDelete() }) {
                            Text("Delete", color = MaterialTheme.colorScheme.error, fontWeight = FontWeight.SemiBold)
                        }
                    },
                    dismissButton = {
                        androidx.compose.material3.TextButton(onClick = { confirmDelete = false }) { Text("Keep it") }
                    },
                )
            }
        }

        // Audio, when the entry has it. Without this the transcript is the only
        // artifact and a voice journal quietly becomes a text journal.
        entry.audioPath?.let { path ->
            Spacer(Modifier.height(16.dp))
            AudioBar(path, seed = entry.id, fallbackMs = entry.durationSec * 1000)
        }

        entry.photoPath?.let { path ->
            Spacer(Modifier.height(16.dp))
            val bmp = remember(path) {
                runCatching { android.graphics.BitmapFactory.decodeFile(path) }.getOrNull()
            }
            bmp?.let {
                androidx.compose.foundation.Image(
                    bitmap = it.asImageBitmap(),
                    contentDescription = "Photo attached to this entry",
                    contentScale = androidx.compose.ui.layout.ContentScale.Crop,
                    modifier = Modifier.fillMaxWidth().height(180.dp)
                        .clip(RoundedCornerShape(20.dp)),
                )
            }
        }

        Spacer(Modifier.height(18.dp))
        // B4: the entities the Twin found are underlined in gold, inside the
        // transcript. Seeing them in place is the point — it is the difference
        // between "the app says it found Sarah" and "here is where."
        val night = MaterialTheme.colorScheme.background == com.dailyvox.app.ui.theme.NightBackground
        val goldTone = if (night) com.dailyvox.app.ui.theme.NightGoldText
                       else com.dailyvox.app.ui.theme.DayGoldText
        if (entry.isUntranscribed) {
            UntranscribedBlock(entry, onEdit)
            Spacer(Modifier.height(6.dp))
        }
        val marked = remember(entry.text, entry.entities) {
            buildAnnotatedString {
                var rest = entry.text
                val names = entry.entityList.sortedByDescending { it.length }
                if (names.isEmpty()) { append(rest); return@buildAnnotatedString }
                var idx = 0
                while (idx < rest.length) {
                    val hit = names
                        .mapNotNull { n ->
                            val at = rest.indexOf(n, idx, ignoreCase = true)
                            if (at >= 0) at to n else null
                        }
                        .minByOrNull { it.first }
                    if (hit == null) { append(rest.substring(idx)); break }
                    append(rest.substring(idx, hit.first))
                    withStyle(
                        SpanStyle(
                            color = goldTone,
                            fontWeight = FontWeight.SemiBold,
                            textDecoration = TextDecoration.Underline,
                        )
                    ) { append(rest.substring(hit.first, hit.first + hit.second.length)) }
                    idx = hit.first + hit.second.length
                }
            }
        }
        Text(marked, fontSize = 16.sp, lineHeight = 26.sp,
             color = MaterialTheme.colorScheme.onSurface)

        Spacer(Modifier.height(16.dp))
        MonoLabel("How did this actually feel?")
        Spacer(Modifier.height(8.dp))
        // The self-label. Deliberately optional and deliberately unprefilled:
        // seeding it with the detector's guess would contaminate the only column
        // in the database with ground truth in it, which is exactly the label an
        // N=20 study needs and the one the affect work found disagrees with
        // inferred valence.
        SelfLabelRow(current = entry.selfLabel, onPick = onSelfLabel)

        Spacer(Modifier.height(22.dp))
        MonoLabel("What your Twin filed ✦")
        Spacer(Modifier.height(8.dp))
        DvCard {
            FiledRow("Mood", valenceLabel(entry.valence), valenceColor(entry.valence))
            if (entry.entityList.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                FiledRow("People", entry.entityList.joinToString(", "), MaterialTheme.colorScheme.secondary)
            }
            // Each body field is independently optional, so each gets its own
            // row. Collapsing them would mean a phone with a pedometer and no
            // wearable shows nothing at all.
            entry.sleepHours?.let {
                Spacer(Modifier.height(10.dp))
                FiledRow("Slept", "%.1f hours".format(it), MaterialTheme.colorScheme.tertiary)
            }
            entry.hrvMs?.let {
                Spacer(Modifier.height(10.dp))
                FiledRow("HRV", "%.0f ms this morning".format(it), MaterialTheme.colorScheme.tertiary)
            }
            entry.restingHrBpm?.let {
                Spacer(Modifier.height(10.dp))
                FiledRow("Resting pulse", "%.0f bpm".format(it), MaterialTheme.colorScheme.tertiary)
            }
            entry.stepsToday?.takeIf { it > 0 }?.let {
                Spacer(Modifier.height(10.dp))
                FiledRow("Steps", "%,d today".format(it), MaterialTheme.colorScheme.tertiary)
            }
            // Pace is a property of speech; a typed entry has none.
            if (entry.durationSec > 0) {
                Spacer(Modifier.height(10.dp))
                FiledRow("Pace", "${(entry.wordCount * 60 / entry.durationSec)} wpm",
                         MaterialTheme.colorScheme.onSurfaceVariant)
            }

            // Prosody, only when the recording could actually be analysed. An
            // absent row is honest; a row of zeroes would read as "you spoke in
            // a monotone at zero hertz".
            entry.speakingRate?.let {
                Spacer(Modifier.height(10.dp))
                FiledRow("Voice", "%.1f words/sec spoken".format(it),
                         MaterialTheme.colorScheme.onSurfaceVariant)
            }
            entry.pitchMean?.takeIf { it > 0f }?.let {
                Spacer(Modifier.height(10.dp))
                FiledRow(
                    "Tone",
                    "%.0f Hz%s".format(it, entry.pitchVariability
                        ?.takeIf { v -> v > 0f }
                        ?.let { v -> " · %.0f Hz range".format(v) } ?: ""),
                    MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            entry.pauseRatio?.let { p ->
                Spacer(Modifier.height(10.dp))
                FiledRow(
                    "Pauses",
                    "%.0f%% quiet%s".format(p * 100,
                        entry.longPauseCount?.takeIf { it > 0 }?.let { " · $it long" } ?: ""),
                    MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            entry.hourOfDay?.let { h ->
                Spacer(Modifier.height(10.dp))
                FiledRow(
                    "When",
                    when {
                        h < 5 -> "the small hours"
                        h < 12 -> "morning"
                        h < 17 -> "afternoon"
                        h < 22 -> "evening"
                        else -> "late night"
                    },
                    MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        // B4's actions as one row with a hierarchy, matching iOS: Edit is the
        // quiet one, Ask is the thing this screen leads to, and Share sits
        // beside them where the thing worth sharing is. Close went with the old
        // grid — the header's back arrow already does it.
        //
        // Photo attachments are OUT OF SCOPE for v1 (FINAL-SPEC §9), so there is
        // no button for them. The column, the storage and the picker are all
        // still here and working, and any photo an early build saved renders above.
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp),
            verticalAlignment = Alignment.CenterVertically) {
            val shape = RoundedCornerShape(18.dp)
            Box(
                Modifier.weight(1f).height(52.dp).clip(shape)
                    .background(MaterialTheme.colorScheme.surfaceVariant)
                    .clickable { editing = true },
                contentAlignment = Alignment.Center,
            ) {
                Text("Edit", fontFamily = Nunito, fontSize = 17.sp, fontWeight = FontWeight.Bold,
                     color = MaterialTheme.colorScheme.onSurface)
            }
            Box(
                Modifier.weight(1f).height(52.dp).clip(shape)
                    .background(MaterialTheme.colorScheme.primary)
                    .clickable { onAsk(askSeed) },
                contentAlignment = Alignment.Center,
            ) {
                Text("\u2726  Ask about this", fontFamily = Nunito, fontSize = 17.sp,
                     fontWeight = FontWeight.Bold, maxLines = 1,
                     color = MaterialTheme.colorScheme.onPrimary)
            }
            Box(
                Modifier.size(52.dp).clip(CircleShape)
                    .background(com.dailyvox.app.ui.theme.Gold.copy(alpha = 0.16f))
                    .clickable {
                        val card = com.dailyvox.app.system.ShareCard.render(context, entry)
                        com.dailyvox.app.system.Exporters.share(context, card, "image/png")
                    }
                    .semantics { contentDescription = "Share this entry" },
                contentAlignment = Alignment.Center,
            ) {
                ShareGlyph(goldTone)
            }
        }

        if (editing) {
            EntryTextEditor(
                initial = entry.text,
                onCancel = { editing = false },
                onSave = { edited -> editing = false; onEdit(edited) },
            )
        }
        Spacer(Modifier.height(120.dp))
    }
}

/**
 * The transcript editor.
 *
 * A dialog rather than an inline field: editing is a deliberate act on a thing
 * the machine got wrong, and the entry stays readable behind it so you can see
 * what you are correcting against.
 */
@Composable
private fun EntryTextEditor(
    initial: String,
    onCancel: () -> Unit,
    onSave: (String) -> Unit,
) {
    var draft by remember { mutableStateOf(initial) }
    androidx.compose.material3.AlertDialog(
        onDismissRequest = onCancel,
        title = { Text("Edit transcript") },
        text = {
            androidx.compose.material3.OutlinedTextField(
                value = draft,
                keyboardOptions = com.dailyvox.app.ui.components.PrivateKeyboard,
                onValueChange = { draft = it },
                modifier = Modifier.fillMaxWidth(),
                minLines = 5,
            )
        },
        confirmButton = {
            androidx.compose.material3.TextButton(
                onClick = { onSave(draft.trim()) },
                enabled = draft.isNotBlank() && draft.trim() != initial,
            ) { Text("Save") }
        },
        dismissButton = {
            androidx.compose.material3.TextButton(onClick = onCancel) { Text("Cancel") }
        },
    )
}

/**
 * The preregistered canon, worded as on iOS (SelfLabels). A label saved under
 * the old Android set is shown on its canon chip when it has one (sad lights
 * Sadness); calm and tired have none, so they keep a chip of their own, as
 * they were, until the user picks something else or clears it.
 */
@Composable
private fun SelfLabelRow(current: String?, onPick: (String?) -> Unit) {
    val labels = com.dailyvox.app.system.SelfLabels
    val selected = labels.canonical(current) ?: current
    val legacy = current?.takeIf { labels.canonical(it) == null }
    val chips = labels.CANON + listOfNotNull(legacy?.let { it to it })
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
        chips.forEach { (label, word) ->
            val on = label == selected
            Text(
                word, fontSize = 15.sp,
                color = if (on) MaterialTheme.colorScheme.onPrimary
                        else MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(if (on) MaterialTheme.colorScheme.secondary
                                else MaterialTheme.colorScheme.surfaceVariant)
                    // Tapping the chosen label again clears it. Nothing here is
                    // a commitment the user cannot take back.
                    .clickable { onPick(if (on) null else label) }
                    .defaultMinSize(minHeight = 44.dp)
                    .padding(horizontal = 14.dp, vertical = 12.dp),
            )
        }
    }
}

/** iOS AudioPlayerView.barCount, so the two players draw the same density. */
private const val WAVE_BARS = 26

/**
 * B4's player: a NAVY card in both themes, a gold play disc and a waveform that
 * is also the scrubber — the spec draws its own control, not a media slider.
 *
 * The bars are a fixed pseudo-waveform, not the recording's envelope: entries
 * store no amplitude data, and decoding every clip on open to get one would buy
 * nothing the bars are for. Seeded from the entry id so a clip keeps its shape.
 */
@Composable
private fun AudioBar(path: String, seed: String, fallbackMs: Int) {
    val playback = remember { com.dailyvox.app.audio.AudioPlayback() }
    var playing by remember { mutableStateOf(false) }
    var pos by remember { mutableIntStateOf(0) }

    LaunchedEffect(playing) {
        while (playing) {
            pos = playback.positionMs
            kotlinx.coroutines.delay(200)
        }
    }
    DisposableEffect(Unit) { onDispose { playback.release() } }

    val heights = remember(seed) {
        val phase = (seed.hashCode() and 0xffff) / 6553.6
        List(WAVE_BARS) { i ->
            val a = kotlin.math.sin(i * 1.7 + phase) * 0.5 + 0.5
            val b = kotlin.math.sin(i * 0.6 + 1.1 + phase * 0.37) * 0.5 + 0.5
            (0.2 + (a * 0.6 + b * 0.4) * 0.8).toFloat()
        }
    }
    // The player has no duration until it is first prepared; the entry's own
    // length stands in so the label reads 1:42 rather than 0:00 before play.
    val total = playback.durationMs.takeIf { it > 0 } ?: fallbackMs.coerceAtLeast(1)
    val progress = (pos.toFloat() / total).coerceIn(0f, 1f)
    val night = com.dailyvox.app.ui.theme.NightText

    Row(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(20.dp))
            .background(com.dailyvox.app.ui.theme.NightSurface)
            .padding(horizontal = 14.dp, vertical = 12.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            Modifier.size(44.dp).clip(CircleShape)
                .background(com.dailyvox.app.ui.theme.Gold)
                .clickable {
                    playback.toggle(path) { playing = false; pos = 0 }
                    playing = playback.isPlaying
                }
                .semantics { contentDescription = if (playing) "Pause" else "Play" },
            contentAlignment = Alignment.Center,
        ) {
            // Drawn, not a text glyph: ▶ and ‖ render at different weights and
            // baselines per font, and on some OEMs as colour emoji.
            val ink = com.dailyvox.app.ui.theme.NightBackground
            androidx.compose.foundation.Canvas(Modifier.size(16.dp)) {
                if (playing) {
                    val bw = 4.dp.toPx()
                    val r = androidx.compose.ui.geometry.CornerRadius(1.5.dp.toPx())
                    listOf(size.width / 2f - bw - 1.5.dp.toPx(), size.width / 2f + 1.5.dp.toPx()).forEach { x ->
                        drawRoundRect(ink, topLeft = androidx.compose.ui.geometry.Offset(x, 0.5.dp.toPx()),
                            size = androidx.compose.ui.geometry.Size(bw, size.height - 1.dp.toPx()), cornerRadius = r)
                    }
                } else {
                    // Nudged right: a triangle's visual centre sits left of its box's.
                    val inset = 2.dp.toPx()
                    drawPath(androidx.compose.ui.graphics.Path().apply {
                        moveTo(inset + 1.dp.toPx(), 0f)
                        lineTo(size.width, size.height / 2f)
                        lineTo(inset + 1.dp.toPx(), size.height)
                        close()
                    }, ink)
                }
            }
        }
        Spacer(Modifier.width(14.dp))
        // The waveform IS the scrubber: bars fill gold as the audio passes and a
        // tap or drag seeks. Seeking needs a prepared player, so before the first
        // play it does nothing rather than inventing a position.
        fun seek(x: Float, width: Int) {
            val d = playback.durationMs
            if (d <= 0 || width <= 0) return
            val ms = ((x / width).coerceIn(0f, 1f) * d).toInt()
            playback.seekTo(ms); pos = ms
        }
        androidx.compose.foundation.Canvas(
            Modifier.weight(1f).height(30.dp)
                .pointerInput(path) { detectTapGestures { seek(it.x, size.width) } }
                .pointerInput(path) {
                    detectHorizontalDragGestures { change, _ -> seek(change.position.x, size.width) }
                }
        ) {
            val gap = 3.dp.toPx()
            val bw = ((size.width - gap * (WAVE_BARS - 1)) / WAVE_BARS).coerceAtLeast(1f)
            heights.forEachIndexed { i, hf ->
                val lit = i.toFloat() / WAVE_BARS <= progress && progress > 0f
                val bh = size.height * hf
                drawRoundRect(
                    if (lit) com.dailyvox.app.ui.theme.Gold else night.copy(alpha = 0.22f),
                    topLeft = androidx.compose.ui.geometry.Offset(i * (bw + gap), (size.height - bh) / 2f),
                    size = androidx.compose.ui.geometry.Size(bw, bh),
                    cornerRadius = androidx.compose.ui.geometry.CornerRadius(bw / 2f),
                )
            }
        }
        Spacer(Modifier.width(12.dp))
        // Elapsed while playing or paused mid-clip, total length otherwise — the
        // same rule as iOS.
        val shown = if (playing || pos > 0) pos else total
        Text(
            "%d:%02d".format(shown / 60000, (shown / 1000) % 60),
            fontFamily = com.dailyvox.app.ui.theme.DmMono, fontWeight = FontWeight.Medium,
            fontSize = 13.sp, color = night.copy(alpha = 0.7f),
        )
    }
}

/** Three stacked dots for the header's overflow menu, drawn to match the ‹. */
@Composable
private fun DotsButton(onClick: () -> Unit) {
    val ink = MaterialTheme.colorScheme.onBackground
    Box(
        Modifier.size(48.dp).clip(CircleShape).clickable(onClick = onClick)
            .semantics { contentDescription = "More actions" },
        contentAlignment = Alignment.Center,
    ) {
        androidx.compose.foundation.Canvas(Modifier.size(4.dp, 18.dp)) {
            val r = size.width / 2f
            listOf(r, size.height / 2f, size.height - r).forEach { y ->
                drawCircle(ink, r, androidx.compose.ui.geometry.Offset(r, y))
            }
        }
    }
}

/** The share mark — a tray with an arrow out of it — drawn, since the app
 *  ships no icon font. */
@Composable
private fun ShareGlyph(color: androidx.compose.ui.graphics.Color) {
    androidx.compose.foundation.Canvas(Modifier.size(20.dp)) {
        val s = androidx.compose.ui.graphics.drawscope.Stroke(
            width = 1.8.dp.toPx(),
            cap = androidx.compose.ui.graphics.StrokeCap.Round,
            join = androidx.compose.ui.graphics.StrokeJoin.Round,
        )
        val w = size.width; val h = size.height
        drawPath(androidx.compose.ui.graphics.Path().apply {
            moveTo(w * 0.32f, h * 0.42f); lineTo(w * 0.18f, h * 0.42f)
            lineTo(w * 0.18f, h * 0.94f); lineTo(w * 0.82f, h * 0.94f)
            lineTo(w * 0.82f, h * 0.42f); lineTo(w * 0.68f, h * 0.42f)
        }, color, style = s)
        drawPath(androidx.compose.ui.graphics.Path().apply {
            moveTo(w * 0.5f, h * 0.64f); lineTo(w * 0.5f, h * 0.06f)
            moveTo(w * 0.33f, h * 0.22f); lineTo(w * 0.5f, h * 0.06f); lineTo(w * 0.67f, h * 0.22f)
        }, color, style = s)
    }
}

/**
 * What the user sees when the recogniser failed but the microphone did not.
 *
 * Three requirements, in order:
 *
 *  - **Say the recording is safe, first.** The fear an empty entry creates is
 *    "the app lost what I said". Everything else is secondary to answering that.
 *  - **Blame the right thing.** It is this phone's speech service, not the
 *    user's diction and not their microphone. Wording that implies they mumbled
 *    is both wrong and the sort of thing people stop using an app over.
 *  - **Offer the two real routes out** — try the recogniser again against the
 *    saved audio, or type it — and no third one that does nothing.
 *
 * Deliberately a filled card rather than an error banner: this is a state the
 * entry is IN, not an event that just happened, and it is still true tomorrow.
 */
@Composable
private fun UntranscribedBlock(entry: Entry, onTranscribed: (String) -> Unit) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    var state by remember(entry.id) { mutableStateOf<TranscribeState>(TranscribeState.Idle) }

    Column(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(18.dp))
            .background(MaterialTheme.colorScheme.surfaceVariant)
            .padding(18.dp),
    ) {
        Text(
            "Your recording is saved",
            fontFamily = Nunito, fontSize = 17.sp, fontWeight = FontWeight.ExtraBold,
            color = MaterialTheme.colorScheme.onSurface,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            when (val s = state) {
                is TranscribeState.Failed -> s.reason
                TranscribeState.Running -> "Reading the recording\u2026 this can take a moment."
                else -> "This phone's speech service didn't turn it into words. " +
                    "The audio is here and can be played, and you can try again " +
                    "or write it out yourself."
            },
            fontSize = 15.sp, lineHeight = 22.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
        )
        Spacer(Modifier.height(14.dp))
        if (state is TranscribeState.Running) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                CircularProgressIndicator(
                    modifier = Modifier.size(18.dp), strokeWidth = 2.dp,
                    color = MaterialTheme.colorScheme.primary,
                )
                Spacer(Modifier.width(12.dp))
                Text("Transcribing", fontSize = 15.sp,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        } else {
            FilledTonalButton(
                onClick = {
                    val f = entry.audioPath?.let { java.io.File(it) } ?: return@FilledTonalButton
                    state = TranscribeState.Running
                    scope.launch {
                        state = when (val r = com.dailyvox.app.audio.FileTranscriber
                            .transcribe(context, f, null)) {
                            is com.dailyvox.app.audio.FileTranscriber.Result.Text -> {
                                onTranscribed(r.value); TranscribeState.Idle
                            }
                            // Named, not swallowed. A recogniser that ignored the
                            // file was listening to the ROOM, and saving that as
                            // somebody's diary entry is the worst outcome here.
                            com.dailyvox.app.audio.FileTranscriber.Result.IgnoredTheFile ->
                                TranscribeState.Failed(
                                    "This phone's recogniser can't read a saved " +
                                    "recording \u2014 it tried to listen live instead, " +
                                    "so nothing was used. Writing it out is the way " +
                                    "to keep these words."
                                )
                            is com.dailyvox.app.audio.FileTranscriber.Result.Failed ->
                                TranscribeState.Failed(r.reason)
                        }
                    }
                },
                modifier = Modifier.fillMaxWidth(),
            ) { Text("Try transcribing again") }
        }
    }
}

private sealed interface TranscribeState {
    data object Idle : TranscribeState
    data object Running : TranscribeState
    data class Failed(val reason: String) : TranscribeState
}

@Composable
private fun FiledRow(label: String, value: String, tint: androidx.compose.ui.graphics.Color) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        MonoLabel(label)
        Text(value, fontSize = 15.sp, color = tint, fontWeight = FontWeight.Medium)
    }
}

private fun valenceLabel(v: Float): String {
    val sign = if (v >= 0) "+" else ""
    val word = when {
        v > 0.3f -> "positive"
        v > 0f -> "calm-positive"
        v > -0.3f -> "flat"
        else -> "negative"
    }
    return "$sign${"%.2f".format(v)} · $word"
}
