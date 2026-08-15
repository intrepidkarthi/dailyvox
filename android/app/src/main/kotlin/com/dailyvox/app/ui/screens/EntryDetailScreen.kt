package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
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
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
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
            val dest = java.io.File(context.filesDir, "photo-${'$'}{entry.id}.jpg")
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
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text("‹", fontSize = 30.sp, color = MaterialTheme.colorScheme.onBackground,
                 modifier = Modifier
                     .clip(CircleShape)
                     .clickable(onClick = onBack)
                     .defaultMinSize(48.dp, 48.dp)
                     .wrapContentSize())
            Spacer(Modifier.width(6.dp))
            Column {
                Text(SimpleDateFormat("EEEE d MMMM", Locale.getDefault()).format(Date(entry.createdAt)),
                     fontSize = 18.sp, fontWeight = FontWeight.Bold,
                     color = MaterialTheme.colorScheme.onBackground)
                MonoLabel("${SimpleDateFormat("h:mm a", Locale.getDefault()).format(Date(entry.createdAt))} · ${entry.durationSec / 60}:${"%02d".format(entry.durationSec % 60)} · ${entry.text.split(" ").size} words")
            }
        }

        // Audio, when the entry has it. Without this the transcript is the only
        // artifact and a voice journal quietly becomes a text journal.
        entry.audioPath?.let { path ->
            Spacer(Modifier.height(16.dp))
            AudioBar(path)
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
        Text(entry.text, fontSize = 16.sp, lineHeight = 26.sp,
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
        MonoLabel("What your Twin filed")
        Spacer(Modifier.height(8.dp))
        DvCard {
            FiledRow("Mood", valenceLabel(entry.valence), valenceColor(entry.valence))
            if (entry.entityList.isNotEmpty()) {
                Spacer(Modifier.height(10.dp))
                FiledRow("People", entry.entityList.joinToString(", "), MaterialTheme.colorScheme.secondary)
            }
            entry.sleepHours?.let {
                Spacer(Modifier.height(10.dp))
                FiledRow("Body", "slept ${"%.1f".format(it)}h", MaterialTheme.colorScheme.tertiary)
            }
            Spacer(Modifier.height(10.dp))
            FiledRow("Pace", "${(entry.text.split(" ").size * 60 / entry.durationSec.coerceAtLeast(1))} wpm",
                     MaterialTheme.colorScheme.onSurfaceVariant)
        }

        Spacer(Modifier.height(20.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = { speaker.toggle(entry.text); speaking = !speaking },
                modifier = Modifier.weight(1f),
            ) { Text(if (speaking) "Stop" else "Read aloud") }
            OutlinedButton(
                onClick = {
                    val card = com.dailyvox.app.system.ShareCard.render(context, entry)
                    com.dailyvox.app.system.Exporters.share(context, card, "image/png")
                },
                modifier = Modifier.weight(1f),
            ) { Text("Share") }
        }
        Spacer(Modifier.height(10.dp))
        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            OutlinedButton(
                onClick = {
                    if (entry.photoPath != null) onPhoto(null)
                    else pickPhoto.launch(
                        androidx.activity.result.PickVisualMediaRequest(
                            androidx.activity.result.contract.ActivityResultContracts.PickVisualMedia.ImageOnly
                        )
                    )
                },
                modifier = Modifier.weight(1f),
            ) { Text(if (entry.photoPath != null) "Remove photo" else "Add photo") }
            OutlinedButton(onClick = onDelete, modifier = Modifier.weight(1f)) {
                Text("Delete", color = MaterialTheme.colorScheme.error)
            }
        }
        Spacer(Modifier.height(120.dp))
    }
}

/** The seven labels are the iOS self-label set, unchanged, so a cohort's
 *  responses stay comparable across platforms. */
private val SELF_LABELS = listOf("joy", "calm", "sad", "angry", "anxious", "tired", "neutral")

@Composable
private fun SelfLabelRow(current: String?, onPick: (String?) -> Unit) {
    FlowRow(horizontalArrangement = Arrangement.spacedBy(8.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp)) {
        SELF_LABELS.forEach { label ->
            val on = label == current
            Text(
                label, fontSize = 13.sp,
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

@Composable
private fun AudioBar(path: String) {
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

    val total = playback.durationMs.coerceAtLeast(1)
    DvCard {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Box(
                Modifier.size(44.dp).clip(CircleShape)
                    .background(MaterialTheme.colorScheme.secondary)
                    .clickable {
                        playback.toggle(path) { playing = false; pos = 0 }
                        playing = playback.isPlaying
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text(if (playing) "\u2016" else "\u25B6", fontSize = 15.sp,
                     color = MaterialTheme.colorScheme.onPrimary)
            }
            Spacer(Modifier.width(14.dp))
            Column(Modifier.weight(1f)) {
                Box(
                    Modifier.fillMaxWidth().height(4.dp)
                        .clip(RoundedCornerShape(2.dp))
                        .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.2f))
                ) {
                    Box(
                        Modifier.fillMaxWidth(pos.toFloat() / total).height(4.dp)
                            .clip(RoundedCornerShape(2.dp))
                            .background(MaterialTheme.colorScheme.secondary)
                    )
                }
                Spacer(Modifier.height(6.dp))
                MonoLabel("%d:%02d".format(pos / 60000, (pos / 1000) % 60))
            }
        }
    }
}

@Composable
private fun FiledRow(label: String, value: String, tint: androidx.compose.ui.graphics.Color) {
    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
        MonoLabel(label)
        Text(value, fontSize = 13.sp, color = tint, fontWeight = FontWeight.Medium)
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
