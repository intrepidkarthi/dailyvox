package com.dailyvox.app.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.dailyvox.app.audio.AudioRecorder
import com.dailyvox.app.audio.SpeechCapture
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import com.dailyvox.app.ui.components.MonoLabel
import com.dailyvox.app.ui.theme.Gold
import com.dailyvox.app.ui.theme.StarGold
import kotlinx.coroutines.delay

/**
 * The record button is the app's most-seen control and is fully authored --
 * nothing here is a Material component wearing brand colours.
 *
 * Three states, three brand colours: idle is ink (Light) / amber (Dark),
 * recording is coral, processing is gold. Material's `error` role is bound to
 * coral for exactly this reason -- on iOS that colour means RECORDING, not
 * failure, and ThemeManager.swift refuses `.red` in a comment.
 *
 * THE 42-SECOND RING IS A SHAPE, NOT A CUTOFF. It fills to 42s and then keeps
 * counting, quietly. Every surface in the product treats 42 seconds as a soft
 * target, and a progress ring that stops there would invert the meaning of the
 * whole motif.
 */
@Composable
fun SpeakScreen(
    streak: Int,
    resolution: Int,
    /** Stars filed since 1 January — the right-hand chip in spec §2.2. */
    yearCount: Int = 0,
    todayEntry: com.dailyvox.app.data.Entry? = null,
    firstEver: Boolean = false,
    autoStart: Boolean = false,
    onAutoStarted: () -> Unit = {},
    onSaved: (String, Int, String?) -> Unit,
    onRecordingChanged: (Boolean) -> Unit = {},
    onInsights: () -> Unit = {},
    onSettings: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val goldText = if (MaterialTheme.colorScheme.background ==
                       com.dailyvox.app.ui.theme.NightBackground)
        com.dailyvox.app.ui.theme.NightGoldText else com.dailyvox.app.ui.theme.DayGoldText
    val capture = remember { SpeechCapture(context) }
    val recorder = remember { AudioRecorder(context) }
    val haptics = remember { com.dailyvox.app.system.Haptics(context) }
    var audioPath by remember { mutableStateOf<String?>(null) }
    var granted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    val state by capture.state.collectAsState()
    val captureError by capture.error.collectAsState()
    val partial by capture.partial.collectAsState()
    val level by capture.level.collectAsState()
    var elapsed by remember { mutableIntStateOf(0) }
    // The name most recently caught in the live partial, for the "filed to your
    // sky" chip. Recomputed from the partial rather than stored, so it always
    // reflects what is actually on screen.
    val caughtEntity = remember(partial) {
        if (partial.isBlank()) null
        else com.dailyvox.twin.NameDetector
            .detect(partial, corpus = listOf(partial))
            .lastOrNull()
    }

    LaunchedEffect(state) { onRecordingChanged(state == SpeechCapture.State.RECORDING) }

    LaunchedEffect(state) {
        if (state == SpeechCapture.State.RECORDING) {
            elapsed = 0
            com.dailyvox.app.system.RecordingLive.onFinishRequested = { capture.stop() }
            while (true) {
                com.dailyvox.app.system.RecordingLive.show(context, elapsed)
                delay(1000)
                elapsed++
            }
        } else {
            com.dailyvox.app.system.RecordingLive.hide(context)
            com.dailyvox.app.system.RecordingLive.onFinishRequested = null
        }
    }

    // Saving is driven by the capture's own terminal state rather than by the
    // tap handler, so a recognizer that ends on silence saves the same way a
    // deliberate stop does.
    LaunchedEffect(Unit) {
        capture.finished.collect { text ->
            val path = recorder.stop()?.absolutePath
            if (text.isNotBlank()) {
                onSaved(text, elapsed.coerceAtLeast(1), path)
                if (streak > 0 && (streak + 1) % 7 == 0) haptics.streakMilestone()
                else haptics.entrySaved()
            }
        }
    }

    // Arrived from the widget or the Quick Settings tile. Fires once, and only
    // with the permission already granted -- launching a permission dialog from
    // a home-screen tap, with no context for why, is how apps get denied
    // permanently.
    LaunchedEffect(autoStart, granted) {
        if (autoStart && granted && state == SpeechCapture.State.IDLE) {
            onAutoStarted()
            haptics.recordStart()
            recorder.start(); capture.start()
        } else if (autoStart && !granted) {
            onAutoStarted()
        }
    }

    // Leaving the screen must take the notification with it, or a cancelled
    // recording leaves a "Listening" chip that nothing will ever clear.
    DisposableEffect(Unit) {
        onDispose {
            capture.release()
            com.dailyvox.app.system.RecordingLive.hide(context)
            com.dailyvox.app.system.RecordingLive.onFinishRequested = null
        }
    }

    // Recording is a full-screen moment, not a state of this screen. The design
    // gives it its own navy dial (B2b), so hand off entirely rather than trying
    // to morph the idle layout around it.
    LaunchedEffect(state) { onRecordingChanged(state == SpeechCapture.State.RECORDING) }

    if (state == SpeechCapture.State.RECORDING) {
        RecordingDial(
            elapsed = elapsed,
            level = level,
            partial = partial,
            lastEntity = caughtEntity,
            onStop = { haptics.recordStop(); capture.stop() },
            onDiscard = { capture.stop(); recorder.stop() },
            modifier = modifier,
        )
        return
    }

    // Scrollable, and not merely defensively: Play's pre-launch report tests at
    // 200% non-linear font scale, where a fixed column silently clips its last
    // child. The privacy card was already being pushed off-screen at default
    // scale once the nav icons grew the bar.
    // On a 426x952dp phone the fixed spacers left roughly a third of the screen
    // empty below the privacy card, which read as an unfinished screen rather
    // than a calm one. The column now grows into the space it is given: on tall
    // devices the weights distribute it, on short ones they collapse to zero and
    // the scroll takes over exactly as before.
    val tall = androidx.compose.ui.platform.LocalConfiguration.current.screenHeightDp >= 780

    Column(
        modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(14.dp))
        // Spec §2.2: greeting + date on the left, streak and star chips on the
        // right. This read "Day 21 · 17% resolved" — a progress figure that
        // belongs to the Twin tab, on the screen whose whole job is to make
        // tonight feel unhurried.
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top) {
            Column {
                val cal = java.util.Calendar.getInstance()
                Text(
                    when (cal.get(java.util.Calendar.HOUR_OF_DAY)) {
                        in 0..4 -> "Still up"
                        in 5..11 -> "Good morning"
                        in 12..16 -> "Good afternoon"
                        else -> "Good evening"
                    },
                    fontSize = 15.sp, fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onBackground,
                )
                Spacer(Modifier.height(2.dp))
                Text(
                    java.text.SimpleDateFormat("EEEE, MMMM d", java.util.Locale.getDefault())
                        .format(java.util.Date()),
                    fontSize = 12.5.sp, color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
            Row(verticalAlignment = Alignment.Top) {
                Column(horizontalAlignment = Alignment.End,
                       modifier = Modifier.clip(RoundedCornerShape(12.dp))
                           .clickable(onClick = onInsights)
                           .padding(horizontal = 8.dp, vertical = 6.dp)) {
                    Text(
                        if (streak > 0) "$streak-day streak" else "no streak yet",
                        fontSize = 12.5.sp, fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onBackground,
                    )
                    Spacer(Modifier.height(2.dp))
                    Text(
                        "\u2726 $yearCount this year", fontSize = 11.sp,
                        fontWeight = FontWeight.SemiBold, color = goldText,
                    )
                }
                Text(
                    "\u22EF",
                    fontSize = 20.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.clip(RoundedCornerShape(12.dp))
                        .clickable(onClick = onSettings)
                        .defaultMinSize(minWidth = 44.dp, minHeight = 44.dp)
                        .wrapContentSize(),
                )
            }
        }

        Spacer(Modifier.height(if (tall) 56.dp else 28.dp))
        Text(
            when (state) {
                SpeechCapture.State.RECORDING -> "Listening."
                SpeechCapture.State.PROCESSING -> "Filing it."
                else -> "How was your day,\nreally?"
            },
            fontSize = 32.sp, lineHeight = 38.sp, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground,
        )

        Spacer(Modifier.height(if (tall) 44.dp else 20.dp))
        // Scaled to the window. At a fixed 232dp the button plus the headline
        // filled a 640dp-tall phone on its own and pushed the airplane-mode card
        // below the fold -- that card is the product's entire argument, and
        // burying it on small devices is the one thing this screen cannot do.
        RecordButton(
            diameter = androidx.compose.ui.platform.LocalConfiguration.current
                .screenHeightDp.dp.times(0.30f).coerceIn(168.dp, 232.dp),
            state = state,
            level = level,
            elapsed = elapsed,
            firstEver = firstEver,
            onTap = {
                if (!granted) ask.launch(Manifest.permission.RECORD_AUDIO)
                else if (state == SpeechCapture.State.RECORDING) { haptics.recordStop(); capture.stop() }
                else { capture.clearError(); haptics.recordStart(); recorder.start(); capture.start() }
            },
        )

        Spacer(Modifier.height(22.dp))
        Text(
            if (state == SpeechCapture.State.RECORDING) "%d:%02d".format(elapsed / 60, elapsed % 60)
            else if (!granted) "Allow the microphone to begin" else "Tap to record \u00B7 42 seconds",
            fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            if (partial.isNotBlank()) partial else "Also on your home screen and Quick Settings",
            fontSize = 13.sp, lineHeight = 19.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.widthIn(max = 420.dp),
        )

        // The failure, where the user is looking when it happens. Silently
        // returning to "Tap to start" taught people the button was broken.
        captureError?.let { err ->
            Spacer(Modifier.height(20.dp))
            Column(
                Modifier.fillMaxWidth()
                    .clip(RoundedCornerShape(18.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(16.dp),
            ) {
                Text(err.message, fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                     color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(6.dp))
                Text(err.fix, fontSize = 13.sp, lineHeight = 20.sp,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
                Spacer(Modifier.height(12.dp))
                Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
                    if (err.openLanguageSettings) {
                        Text(
                            "Open speech settings",
                            fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                            color = MaterialTheme.colorScheme.onPrimary,
                            modifier = Modifier
                                .clip(RoundedCornerShape(14.dp))
                                .background(MaterialTheme.colorScheme.primary)
                                .clickable {
                                    // Deep-link where it exists; the general
                                    // language screen is the fallback, since the
                                    // voice-input screen is not on every OEM.
                                    val tried = listOf(
                                        "com.android.settings.VOICE_INPUT_SETTINGS",
                                        android.provider.Settings.ACTION_VOICE_INPUT_SETTINGS,
                                        android.provider.Settings.ACTION_LOCALE_SETTINGS,
                                    )
                                    tried.firstOrNull { action ->
                                        runCatching {
                                            context.startActivity(
                                                android.content.Intent(action)
                                                    .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                                            )
                                        }.isSuccess
                                    }
                                }
                                .padding(horizontal = 16.dp, vertical = 11.dp),
                        )
                    }
                    Text(
                        "Dismiss", fontSize = 13.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .clickable { capture.clearError() }
                            .padding(horizontal = 16.dp, vertical = 11.dp),
                    )
                }
            }
        }

        // Today's entry, once it exists (B2). The design surfaces the star the
        // moment it has been made rather than waiting for the Journal tab.
        todayEntry?.let { e ->
            Spacer(Modifier.height(if (tall) 40.dp else 22.dp))
            Column(
                Modifier.fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(horizontal = 15.dp, vertical = 12.dp),
            ) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically) {
                    MonoLabel("today ✦ · ${java.text.SimpleDateFormat("h:mm a", java.util.Locale.getDefault()).format(java.util.Date(e.createdAt))}")
                    Text(
                        "▶ %d:%02d".format(e.durationSec / 60, e.durationSec % 60),
                        fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                        color = MaterialTheme.colorScheme.primary,
                        modifier = Modifier
                            .clip(RoundedCornerShape(11.dp))
                            .background(MaterialTheme.colorScheme.surfaceVariant)
                            .padding(horizontal = 10.dp, vertical = 6.dp),
                    )
                }
                Spacer(Modifier.height(7.dp))
                // One flowing line, not two Texts side by side. The previous
                // version put the summary and the valence in a Row, so a long
                // summary pushed the score off the edge and a short one left it
                // stranded mid-line — neither aligned with anything.
                Text(
                    buildAnnotatedString {
                        append(e.text.take(44).trim())
                        if (e.text.length > 44) append("… ") else append(" ")
                        withStyle(
                            SpanStyle(
                                color = MaterialTheme.colorScheme.tertiary,
                                fontWeight = FontWeight.SemiBold,
                            )
                        ) { append("%+.1f".format(e.valence)) }
                    },
                    fontSize = 12.sp, lineHeight = 18.sp,
                    color = MaterialTheme.colorScheme.onSurface.copy(alpha = 0.85f),
                )
            }
        }

        Spacer(Modifier.height(if (tall) 48.dp else 24.dp))
        // The privacy claim, in the one place a user can act on it. Not a badge
        // for its own sake: it is the product's whole argument, stated where the
        // recording happens.
        Row(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(18.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(Modifier.size(7.dp).clip(RoundedCornerShape(4.dp))
                .background(Color(0xFF4F7A3E)))
            Spacer(Modifier.width(10.dp))
            Text("Works in airplane mode. Nothing leaves this phone.",
                 fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface,
                 modifier = Modifier.weight(1f))
            MonoLabel("0 calls")
        }
        Spacer(Modifier.height(if (tall) 132.dp else 112.dp))   // clears the floating nav pill
    }
}

@Composable
private fun RecordButton(
    diameter: androidx.compose.ui.unit.Dp,
    state: SpeechCapture.State,
    level: Float,
    elapsed: Int,
    firstEver: Boolean,
    onTap: () -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val label = when (state) {
        SpeechCapture.State.RECORDING -> "Stop recording"
        SpeechCapture.State.PROCESSING -> "Processing"
        else -> "Start recording"
    }

    // FINAL-SPEC §2.2, read off the design's own markup rather than eyeballed:
    //   ring   r=70 in a 150 box, stroke 4.5, dasharray "0.1 10.37" -> 42 dots
    //   drift  120s / revolution
    //   star   9px gold, orbiting at 16s, inset -12
    //   mic    112dp disc, forest green, cream capsule glyph
    //
    // The dots are drawn individually rather than as a dashed stroke: Compose
    // has no stroke-linecap on a PathEffect dash, so a dashed circle renders as
    // 42 tiny rectangles instead of 42 round ticks.
    val spin = rememberInfiniteTransition(label = "ring")
    val drift by spin.animateFloat(
        0f, 360f,
        infiniteRepeatable(tween(120_000, easing = LinearEasing), RepeatMode.Restart),
        label = "drift",
    )
    val orbit by spin.animateFloat(
        0f, 360f,
        infiniteRepeatable(
            tween(if (state == SpeechCapture.State.RECORDING) 12_000 else 16_000,
                  easing = LinearEasing),
            RepeatMode.Restart,
        ),
        label = "orbit",
    )
    // Record start: mic scales 1 -> 1.08 on a spring (§4).
    val press by animateFloatAsState(
        if (state == SpeechCapture.State.RECORDING) 1.08f else 1f,
        spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow),
        label = "press",
    )

    Box(contentAlignment = Alignment.Center) {
        Canvas(
            Modifier
                .size(diameter)
                .semantics { contentDescription = label }
                .pointerInput(state) { detectTapGestures { onTap() } }
        ) {
            val c = center
            val ringR = size.minDimension * 0.467f      // 70/150
            val litTicks = elapsed.coerceAtMost(42)

            // 42 ticks. Gold and lit for each elapsed second while recording;
            // faint and evenly spaced at rest.
            repeat(42) { i ->
                val a = Math.toRadians((drift + i * (360.0 / 42.0)) - 90.0)
                val p = Offset(
                    c.x + (ringR * kotlin.math.cos(a)).toFloat(),
                    c.y + (ringR * kotlin.math.sin(a)).toFloat(),
                )
                val on = state == SpeechCapture.State.RECORDING && i < litTicks
                drawCircle(
                    color = if (on) Gold else Gold.copy(alpha = 0.28f),
                    radius = 2.25.dp.toPx(),
                    center = p,
                )
            }

            // The orbiting star — the "solar-system idle" the spec asks for.
            val oa = Math.toRadians(orbit - 90.0)
            val op = Offset(
                c.x + ((ringR + 6.dp.toPx()) * kotlin.math.cos(oa)).toFloat(),
                c.y + ((ringR + 6.dp.toPx()) * kotlin.math.sin(oa)).toFloat(),
            )
            drawCircle(Gold.copy(alpha = 0.35f), radius = 7.dp.toPx(), center = op)
            drawCircle(Gold, radius = 4.5.dp.toPx(), center = op)

            // The disc. Green acts in Day; at night the actor is gold, which is
            // already what colorScheme.primary resolves to.
            val discR = size.minDimension * 0.373f * press   // 112/300 of the box
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(scheme.primary.copy(alpha = 0.30f), Color.Transparent),
                    center = Offset(c.x, c.y + discR * 0.18f), radius = discR * 1.5f,
                ),
                radius = discR * 1.5f,
                center = Offset(c.x, c.y + discR * 0.18f),
            )
            drawCircle(
                color = if (state == SpeechCapture.State.RECORDING) scheme.error else scheme.primary,
                radius = discR,
                center = c,
            )
        }

        // Cream capsule glyph, 24x40 at the design's 112 disc.
        Canvas(Modifier.size(diameter * 0.21f)) {
            val w = size.width
            drawRoundRect(
                color = scheme.onPrimary,
                topLeft = Offset(w * 0.30f, 0f),
                size = androidx.compose.ui.geometry.Size(w * 0.40f, size.height),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.20f),
            )
        }
    }
}
