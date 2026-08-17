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
import com.dailyvox.app.ui.components.MonoLabel
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
    firstEver: Boolean = false,
    autoStart: Boolean = false,
    onAutoStarted: () -> Unit = {},
    onSaved: (String, Int, String?) -> Unit,
    onInsights: () -> Unit = {},
    onSettings: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
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
        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(Modifier.size(8.dp).clip(RoundedCornerShape(4.dp)).background(StarGold))
                Spacer(Modifier.width(8.dp))
                Text("Day ${streak.coerceAtLeast(1)}", fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                     color = MaterialTheme.colorScheme.onBackground)
            }
            Row(verticalAlignment = Alignment.CenterVertically) {
                MonoLabel(
                    "$resolution% resolved",
                    Modifier.clip(RoundedCornerShape(10.dp))
                        .clickable(onClick = onInsights)
                        .defaultMinSize(minHeight = 44.dp)
                        .padding(horizontal = 8.dp, vertical = 13.dp),
                )
                Spacer(Modifier.width(4.dp))
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
                else -> "Tonight's forty-two seconds."
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
            else if (!granted) "Allow the microphone to begin" else "Tap to start",
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

        Spacer(Modifier.height(if (tall) 72.dp else 28.dp))
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
    val target = when (state) {
        SpeechCapture.State.RECORDING -> scheme.error          // coral
        SpeechCapture.State.PROCESSING -> StarGold
        else -> scheme.primary
    }
    val color by animateColorAsState(target, spring(stiffness = Spring.StiffnessLow), label = "recColor")
    // Underdamped on purpose. 0.52 is what makes it pop; a default spring is limp.
    val pulse by animateFloatAsState(
        if (state == SpeechCapture.State.RECORDING) 1f + level * 0.16f else 1f,
        spring(dampingRatio = 0.52f, stiffness = Spring.StiffnessMediumLow),
        label = "pulse",
    )
    val label = when (state) {
        SpeechCapture.State.RECORDING -> "Stop recording"
        SpeechCapture.State.PROCESSING -> "Processing"
        else -> "Start recording"
    }

    // The iOS button carries THREE animation layers and Android had one. Ported
    // with the same numbers rather than approximations, because the timings are
    // what make it read as the same object: rings expand to 1.8x over 1.8s and
    // fade to nothing, staggered 0.6s apart so one is always mid-flight.
    val ripple = rememberInfiniteTransition(label = "ripple")
    val ringPhase = (0..2).map { i ->
        ripple.animateFloat(
            initialValue = 0f, targetValue = 1f,
            animationSpec = infiniteRepeatable(
                animation = tween(1800, delayMillis = i * 600, easing = LinearOutSlowInEasing),
                repeatMode = RepeatMode.Restart,
            ),
            label = "ring$i",
        )
    }

    // The first-time invitation: a single slow ring on an app with no entries
    // yet. It is the only thing on the screen asking to be touched, and it stops
    // for good once there is one star in the sky.
    val invite = ripple.animateFloat(
        initialValue = 0f, targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(2000, easing = LinearOutSlowInEasing),
            repeatMode = RepeatMode.Restart,
        ),
        label = "invite",
    )

    Box(contentAlignment = Alignment.Center) {
        Canvas(
            Modifier
                .size(diameter)
                .semantics { contentDescription = label }
                .pointerInput(state) { detectTapGestures { onTap() } }
        ) {
            val r = size.minDimension / 2f

            // Concentric rings, faint — the "instrument" read from the design.
            for (i in 1..3) {
                drawCircle(color.copy(alpha = 0.06f), radius = r * (0.62f + i * 0.12f), style = Stroke(1.dp.toPx()))
            }

            // Layer 1: first-run invitation. 1.0 -> 1.3, fading out.
            if (firstEver && state == SpeechCapture.State.IDLE) {
                val t = invite.value
                drawCircle(
                    color = color.copy(alpha = 0.25f * (1f - t)),
                    radius = r * 0.52f * (1f + 0.3f * t),
                    style = Stroke(2.dp.toPx()),
                )
            }

            // Layer 2: recording ripples. Three, expanding to 1.8x and fading.
            if (state == SpeechCapture.State.RECORDING) {
                ringPhase.forEach { phase ->
                    val t = phase.value
                    drawCircle(
                        color = color.copy(alpha = 0.35f * (1f - t)),
                        radius = r * 0.5f * (1f + 0.8f * t),
                        style = Stroke(2.dp.toPx()),
                    )
                }
            }
            // 42-second arc: fills once, then keeps sweeping. A shape, not a limit.
            val progress = (elapsed % 42) / 42f
            if (elapsed > 0) {
                drawArc(
                    color = StarGold.copy(alpha = 0.9f),
                    startAngle = -90f,
                    sweepAngle = 360f * progress,
                    useCenter = false,
                    style = Stroke(3.dp.toPx()),
                    topLeft = Offset(r * 0.10f, r * 0.10f),
                    size = androidx.compose.ui.geometry.Size(size.width - r * 0.20f, size.height - r * 0.20f),
                )
            }
            // Glow, then core. Stacked translucent circles rather than a blur —
            // the same technique the iOS constellation uses, and far cheaper.
            drawCircle(
                brush = Brush.radialGradient(
                    listOf(color.copy(alpha = 0.34f), Color.Transparent),
                    center = center, radius = r * 0.92f * pulse,
                ),
                radius = r * 0.92f * pulse,
            )
            drawCircle(color, radius = r * 0.46f * pulse)
        }
        // The mic glyph, drawn rather than an icon font, so it needs no asset.
        val micColor = if (state == SpeechCapture.State.IDLE) scheme.onPrimary else Color(0xFF0F140F)
        Canvas(Modifier.size(diameter * 0.20f)) {
            val w = size.width
            drawRoundRect(
                color = micColor,
                topLeft = Offset(w * 0.34f, w * 0.16f),
                size = androidx.compose.ui.geometry.Size(w * 0.32f, w * 0.50f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.16f),
            )
        }
    }
}


