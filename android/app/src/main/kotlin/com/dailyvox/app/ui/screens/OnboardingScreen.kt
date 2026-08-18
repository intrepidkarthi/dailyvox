package com.dailyvox.app.ui.screens

import android.Manifest
import android.content.pm.PackageManager
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import com.dailyvox.app.audio.AudioRecorder
import com.dailyvox.app.audio.SpeechCapture
import com.dailyvox.app.ui.components.MonoLabel
import com.dailyvox.app.ui.theme.StarGold
import kotlinx.coroutines.delay

/**
 * Onboarding in three beats, matching the iOS shape rather than only its copy.
 *
 * The single screen this replaces was labelled "01 / 03" and had no 02 or 03 —
 * the counter was describing an intention rather than the app.
 *
 * iOS runs invite -> speak -> claim, and the load-bearing part is that beat two
 * records a REAL entry which `persistFirstStar()` saves. People arrive in the app
 * with their own star already in the sky rather than an empty one, and the third
 * beat can say "that star is yours" truthfully. That is ported here.
 *
 * Beat one is Android's own, from §4.1 of the design package: the permission
 * ledger, including the row for the permission NOT requested. That row is the
 * product's whole argument and it is the only claim a user can check
 * independently, so it stays first.
 */
@Composable
fun OnboardingScreen(
    onDone: (text: String, seconds: Int, audioPath: String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    var beat by rememberSaveable { mutableIntStateOf(0) }
    var transcript by rememberSaveable { mutableStateOf("") }
    var seconds by rememberSaveable { mutableIntStateOf(0) }
    var audioPath by rememberSaveable { mutableStateOf<String?>(null) }

    when (beat) {
        0 -> LedgerBeat(onNext = { beat = 1 })
        1 -> SpeakBeat(
            onCaptured = { t, s, p ->
                transcript = t; seconds = s; audioPath = p; beat = 2
            },
            // Skipping the recording must not skip the welcome. Beat 3 still
            // runs, just with the "your sky is ready" copy instead of a quote.
            onSkip = { beat = 2 },
        )
        else -> ClaimBeat(
            transcript = transcript,
            onEnter = { onDone(transcript, seconds, audioPath) },
        )
    }
}

/* ---------------------------------------------------------------- beat 1 */

@Composable
private fun LedgerBeat(onNext: () -> Unit) {
    val context = LocalContext.current
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        // Continue either way. A journal that refuses to open because you said no
        // to the microphone is punishing caution, and caution is who this is for.
        onNext()
    }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 26.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        MonoLabel("01 / 03 · permission")
        Spacer(Modifier.height(18.dp))
        Text(
            "Nothing you say leaves this phone.",
            style = MaterialTheme.typography.displayMedium,
            color = MaterialTheme.colorScheme.onBackground,
        )
        Spacer(Modifier.height(14.dp))
        Text(
            "Transcription runs on your device. No account, no server, no analytics SDK. " +
                "Prove it: switch on airplane mode and record your first entry.",
            fontSize = 15.sp, lineHeight = 24.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            modifier = Modifier.widthIn(max = 520.dp),
        )

        Spacer(Modifier.height(28.dp))
        LedgerRow("Microphone", "required", MaterialTheme.colorScheme.secondary)
        Spacer(Modifier.height(8.dp))
        LedgerRow("Health Connect", "optional", MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(8.dp))
        LedgerRow("Internet", "not requested", Color(0xFF4F7A3E))

        Spacer(Modifier.height(30.dp))
        FilledAction("Allow microphone") {
            if (ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
                PackageManager.PERMISSION_GRANTED
            ) onNext() else ask.launch(Manifest.permission.RECORD_AUDIO)
        }
        Spacer(Modifier.height(14.dp))
        QuietAction("See how it works first", onNext)
    }
}

/* ---------------------------------------------------------------- beat 2 */

private enum class Phase { IDLE, RECORDING, PROCESSING, BORN }

@Composable
private fun SpeakBeat(
    onCaptured: (String, Int, String?) -> Unit,
    onSkip: () -> Unit,
) {
    val context = LocalContext.current
    val capture = remember { SpeechCapture(context) }
    val recorder = remember { AudioRecorder(context) }
    val state by capture.state.collectAsState()
    val level by capture.level.collectAsState()
    // SpeechCapture has raised a real CaptureError since the silent-failure fix,
    // but this beat never read it — so a phone whose recogniser is missing,
    // busy, or has no language pack sat on "Listening" forever with Done as the
    // only control and no way into the app at all. Onboarding is the one screen
    // where swallowing this is fatal rather than annoying.
    val captureError by capture.error.collectAsState()
    var elapsed by remember { mutableIntStateOf(0) }
    var phase by remember { mutableStateOf(Phase.IDLE) }
    var text by remember { mutableStateOf("") }
    var path by remember { mutableStateOf<String?>(null) }

    val granted = ContextCompat.checkSelfPermission(context, Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED

    LaunchedEffect(state) {
        when (state) {
            SpeechCapture.State.RECORDING -> { phase = Phase.RECORDING; elapsed = 0
                while (true) { delay(1000); elapsed++ } }
            SpeechCapture.State.PROCESSING -> phase = Phase.PROCESSING
            SpeechCapture.State.IDLE -> if (phase != Phase.BORN) phase = Phase.IDLE
        }
    }
    LaunchedEffect(Unit) {
        capture.finished.collect { t ->
            path = recorder.stop()?.absolutePath
            text = t
            phase = Phase.BORN
            // Let the star land before moving on. The beat exists to be watched.
            delay(1600)
            onCaptured(t, elapsed.coerceAtLeast(1), path)
        }
    }
    DisposableEffect(Unit) { onDispose { capture.release() } }

    Column(
        Modifier.fillMaxSize().padding(horizontal = 26.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        MonoLabel("02 / 03 · your first star")
        Spacer(Modifier.height(18.dp))
        Text(
            when (phase) {
                Phase.BORN -> "A star is born."
                Phase.PROCESSING -> "Finding your words."
                else -> "How was your day,\nreally?"
            },
            style = MaterialTheme.typography.displayMedium,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(12.dp))
        Text(
            when (phase) {
                Phase.IDLE -> "Speak, don't type. Forty-two seconds is plenty — and it stays on this phone."
                Phase.RECORDING -> "Listening. Take as long as you like."
                Phase.PROCESSING -> "On-device. Nothing left your phone."
                Phase.BORN -> "Your voice, now a light in your sky."
            },
            fontSize = 15.sp, lineHeight = 23.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.widthIn(max = 420.dp),
        )

        Spacer(Modifier.height(34.dp))
        VoiceStar(level = level, phase = phase)
        Spacer(Modifier.height(34.dp))

        when {
            !granted -> QuietAction("Continue without the microphone", onSkip)
            phase == Phase.IDLE -> {
                FilledAction("Start speaking") { recorder.start(); capture.start() }
                Spacer(Modifier.height(12.dp))
                QuietAction("Skip for now", onSkip)
            }
            phase == Phase.RECORDING -> {
                FilledAction("%d:%02d  ·  Done".format(elapsed / 60, elapsed % 60)) { capture.stop() }
                Spacer(Modifier.height(12.dp))
                // Even mid-recording. If the recogniser dies without calling
                // onError — and OEM implementations do — this is the only exit.
                QuietAction("Skip for now") { capture.stop(); onSkip() }
            }
            else -> Spacer(Modifier.height(56.dp))
        }

        captureError?.let { err ->
            Spacer(Modifier.height(22.dp))
            Column(
                Modifier.fillMaxWidth().widthIn(max = 420.dp)
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
                        "Continue anyway", fontSize = 13.sp,
                        fontWeight = FontWeight.SemiBold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier
                            .clip(RoundedCornerShape(14.dp))
                            .clickable { capture.clearError(); onSkip() }
                            .padding(horizontal = 16.dp, vertical = 11.dp),
                    )
                }
            }
        }
    }
}

/**
 * The star that listens. Rings ride the mic level while recording and flare once
 * when the entry lands — the Android read of iOS's VoiceStar.
 */
@Composable
private fun VoiceStar(level: Float, phase: Phase) {
    val t = rememberInfiniteTransition(label = "star")
    val breath by t.animateFloat(
        0f, 1f,
        infiniteRepeatable(tween(2600, easing = LinearEasing), RepeatMode.Restart),
        label = "breath",
    )
    val flare by animateFloatAsState(
        if (phase == Phase.BORN) 1f else 0f,
        tween(900, easing = LinearOutSlowInEasing),
        label = "flare",
    )
    val amp by animateFloatAsState(
        if (phase == Phase.RECORDING) level else 0f,
        spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow),
        label = "amp",
    )

    Canvas(Modifier.size(220.dp)) {
        val c = center
        val r = size.minDimension / 2f

        drawCircle(
            brush = Brush.radialGradient(
                listOf(StarGold.copy(alpha = 0.18f + flare * 0.22f), Color.Transparent),
                center = c, radius = r,
            ),
            radius = r, center = c,
        )

        if (phase == Phase.RECORDING) {
            repeat(3) { i ->
                val p = ((breath + i * 0.33f) % 1f)
                drawCircle(
                    color = StarGold.copy(alpha = 0.30f * (1f - p)),
                    radius = r * (0.28f + 0.55f * p) * (1f + amp * 0.25f),
                    center = c,
                    style = Stroke(2.dp.toPx()),
                )
            }
        }

        // The four-point mark, the app's own, growing as the star is born.
        val s = r * (0.20f + amp * 0.05f + flare * 0.10f)
        val path = Path().apply {
            moveTo(c.x, c.y - s)
            cubicTo(c.x + s * .10f, c.y - s * .35f, c.x + s * .35f, c.y - s * .10f, c.x + s, c.y)
            cubicTo(c.x + s * .35f, c.y + s * .10f, c.x + s * .10f, c.y + s * .35f, c.x, c.y + s)
            cubicTo(c.x - s * .10f, c.y + s * .35f, c.x - s * .35f, c.y + s * .10f, c.x - s, c.y)
            cubicTo(c.x - s * .35f, c.y - s * .10f, c.x - s * .10f, c.y - s * .35f, c.x, c.y - s)
            close()
        }
        drawPath(path, StarGold.copy(alpha = 0.55f + flare * 0.45f))

        if (flare > 0f) {
            drawCircle(
                color = StarGold.copy(alpha = 0.5f * (1f - flare)),
                radius = r * (0.3f + 0.7f * flare),
                center = c,
                style = Stroke(2.dp.toPx()),
            )
        }
    }
}

/* ---------------------------------------------------------------- beat 3 */

@Composable
private fun ClaimBeat(transcript: String, onEnter: () -> Unit) {
    Column(
        Modifier.fillMaxSize().padding(horizontal = 26.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        MonoLabel("03 / 03 · yours")
        Spacer(Modifier.height(18.dp))
        Text(
            if (transcript.isBlank()) "Your sky is ready." else "That star is yours.",
            style = MaterialTheme.typography.displayMedium,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(16.dp))

        if (transcript.isNotBlank()) {
            Text(
                "“$transcript”",
                fontSize = 16.sp, lineHeight = 26.sp,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .widthIn(max = 460.dp)
                    .clip(RoundedCornerShape(22.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(20.dp),
            )
            Spacer(Modifier.height(16.dp))
        }

        Text(
            if (transcript.isBlank())
                "Speak whenever you are ready. Nothing is required of you tonight."
            else
                "It is already saved, on this phone only. Nothing was uploaded to write it down.",
            fontSize = 14.sp, lineHeight = 22.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.widthIn(max = 420.dp),
        )

        Spacer(Modifier.height(26.dp))
        // Widget priming, from §4.1 of the design package. Mentioned once, here,
        // rather than as a prompt that interrupts someone later.
        Row(
            Modifier
                .widthIn(max = 460.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Canvas(Modifier.size(26.dp)) {
                val c = center; val s = size.minDimension / 2.4f
                val p = Path().apply {
                    moveTo(c.x, c.y - s)
                    cubicTo(c.x + s * .1f, c.y - s * .35f, c.x + s * .35f, c.y - s * .1f, c.x + s, c.y)
                    cubicTo(c.x + s * .35f, c.y + s * .1f, c.x + s * .1f, c.y + s * .35f, c.x, c.y + s)
                    cubicTo(c.x - s * .1f, c.y + s * .35f, c.x - s * .35f, c.y + s * .1f, c.x - s, c.y)
                    cubicTo(c.x - s * .35f, c.y - s * .1f, c.x - s * .1f, c.y - s * .35f, c.x, c.y - s)
                    close()
                }
                drawPath(p, StarGold.copy(alpha = 0.5f), style = Stroke(1.4f))
            }
            Spacer(Modifier.width(12.dp))
            Text(
                "Add the DailyVox widget to your home screen and tonight's star is one tap away. It never shows what you wrote.",
                fontSize = 13.sp, lineHeight = 19.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }

        Spacer(Modifier.height(26.dp))
        FilledAction(if (transcript.isBlank()) "Enter" else "Enter your sky", onEnter)
    }
}

/* ---------------------------------------------------------------- shared */

@Composable
private fun FilledAction(label: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 16.sp, fontWeight = FontWeight.Bold,
        color = MaterialTheme.colorScheme.onPrimary,
        modifier = Modifier
            .fillMaxWidth()
            .widthIn(max = 460.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.primary)
            .clickable(onClick = onClick)
            .padding(vertical = 18.dp)
            .wrapContentWidth(Alignment.CenterHorizontally),
    )
}

@Composable
private fun QuietAction(label: String, onClick: () -> Unit) {
    Text(
        label,
        fontSize = 14.sp,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .clickable(onClick = onClick)
            .padding(vertical = 12.dp)
            .wrapContentWidth(Alignment.CenterHorizontally),
    )
}

@Composable
private fun LedgerRow(label: String, state: String, dot: Color) {
    Row(
        Modifier.fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(horizontal = 16.dp, vertical = 14.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(Modifier.size(8.dp).clip(CircleShape).background(dot))
        Spacer(Modifier.width(12.dp))
        Text(label, fontSize = 15.sp, color = MaterialTheme.colorScheme.onSurface,
             modifier = Modifier.weight(1f))
        MonoLabel(state)
    }
}
