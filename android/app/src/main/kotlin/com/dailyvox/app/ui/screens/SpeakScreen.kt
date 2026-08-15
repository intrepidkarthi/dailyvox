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
import androidx.compose.foundation.layout.*
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
    onSaved: (String, Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val capture = remember { SpeechCapture(context) }
    var granted by remember {
        mutableStateOf(
            ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
        )
    }
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) { granted = it }

    val state by capture.state.collectAsState()
    val partial by capture.partial.collectAsState()
    val level by capture.level.collectAsState()
    var elapsed by remember { mutableIntStateOf(0) }

    LaunchedEffect(state) {
        if (state == SpeechCapture.State.RECORDING) {
            elapsed = 0
            while (true) { delay(1000); elapsed++ }
        }
    }

    // Saving is driven by the capture's own terminal state rather than by the
    // tap handler, so a recognizer that ends on silence saves the same way a
    // deliberate stop does.
    LaunchedEffect(Unit) {
        capture.finished.collect { text ->
            if (text.isNotBlank()) onSaved(text, elapsed.coerceAtLeast(1))
        }
    }

    DisposableEffect(Unit) { onDispose { capture.release() } }

    Column(
        modifier.fillMaxSize().padding(horizontal = 24.dp),
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
            MonoLabel("$resolution% resolved")
        }

        Spacer(Modifier.height(28.dp))
        Text(
            when (state) {
                SpeechCapture.State.RECORDING -> "Listening."
                SpeechCapture.State.PROCESSING -> "Filing it."
                else -> "Tonight's forty-two seconds."
            },
            fontSize = 32.sp, lineHeight = 38.sp, fontWeight = FontWeight.Bold,
            color = MaterialTheme.colorScheme.onBackground,
        )

        Spacer(Modifier.weight(1f))
        RecordButton(
            state = state,
            level = level,
            elapsed = elapsed,
            onTap = {
                if (!granted) ask.launch(Manifest.permission.RECORD_AUDIO)
                else if (state == SpeechCapture.State.RECORDING) capture.stop() else capture.start()
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

        Spacer(Modifier.weight(1f))
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
        Spacer(Modifier.height(120.dp))
    }
}

@Composable
private fun RecordButton(
    state: SpeechCapture.State,
    level: Float,
    elapsed: Int,
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

    Box(contentAlignment = Alignment.Center) {
        Canvas(
            Modifier
                .size(232.dp)
                .semantics { contentDescription = label }
                .pointerInput(state) { detectTapGestures { onTap() } }
        ) {
            val r = size.minDimension / 2f
            // Concentric rings, faint — the "instrument" read from the design.
            for (i in 1..3) {
                drawCircle(color.copy(alpha = 0.06f), radius = r * (0.62f + i * 0.12f), style = Stroke(1.dp.toPx()))
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
        Canvas(Modifier.size(46.dp)) {
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


