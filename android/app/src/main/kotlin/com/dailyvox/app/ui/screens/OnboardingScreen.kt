package com.dailyvox.app.ui.screens

import com.dailyvox.app.ui.components.SpeechErrorCard
import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.ui.graphics.graphicsLayer
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
import com.dailyvox.app.audio.AudioRecorder
import com.dailyvox.app.audio.SpeechCapture
import com.dailyvox.app.ui.components.MonoLabel
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import com.dailyvox.app.ui.theme.NightBackground
import com.dailyvox.app.ui.theme.NightText
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
    onDone: (text: String, seconds: Int, audioPath: String?, remind: Boolean) -> Unit,
    modifier: Modifier = Modifier,
) {
    var beat by rememberSaveable { mutableIntStateOf(0) }
    var transcript by rememberSaveable { mutableStateOf("") }
    var seconds by rememberSaveable { mutableIntStateOf(0) }
    var audioPath by rememberSaveable { mutableStateOf<String?>(null) }

    // Back steps back a beat. Without this it left the app from beat two, and
    // a cold start then began the whole onboarding again.
    androidx.activity.compose.BackHandler(enabled = beat in 1..2) { beat -= 1 }

    // The four beats iOS runs: ledger, invite, speak, claim.
    androidx.compose.animation.Crossfade(
        targetState = beat,
        animationSpec = tween(450),
        label = "beat",
    ) { b ->
        when (b) {
            0 -> LedgerBeat(onNext = { beat = 1 })
            1 -> InviteBeat(onNext = { beat = 2 })
            2 -> SpeakBeat(
                onCaptured = { t, s, p ->
                    transcript = t; seconds = s; audioPath = p; beat = 3
                },
                // Skipping the recording must not skip the welcome. The claim
                // still runs, with "your sky is ready" instead of a quote.
                onSkip = { beat = 3 },
            )
            else -> ClaimBeat(
                transcript = transcript,
                onEnter = { remind -> onDone(transcript, seconds, audioPath, remind) },
            )
        }
    }
}

/* ---------------------------------------------------------------- beat 1 */

@Composable
private fun LedgerBeat(onNext: () -> Unit) {
    Column(
        Modifier.fillMaxSize()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 26.dp, vertical = 28.dp),
        verticalArrangement = Arrangement.Center,
    ) {
        MonoLabel("01 / 04 · permission")
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
        LedgerRow("Speech recognition", "on device", MaterialTheme.colorScheme.tertiary)
        Spacer(Modifier.height(8.dp))
        LedgerRow("Internet", "not requested", MaterialTheme.colorScheme.tertiary)
        Spacer(Modifier.height(8.dp))
        LedgerRow("Sent to DailyVox", "nothing, ever", MaterialTheme.colorScheme.tertiary)

        Spacer(Modifier.height(18.dp))
        // The proof card (B1). Navy on cream — the one dark object on the
        // screen, because it is the one thing being pointed at.
        //
        // The claim was a sentence in the body copy before this. That is the
        // difference between telling someone the app works offline and handing
        // them a way to check in ten seconds, and the design package calls this
        // "the site's strongest argument, currently absent from the app".
        // At night the page itself is navy, so the card lifts to the night
        // surface with a gold hairline -- navy on navy made it vanish.
        val nightPage = MaterialTheme.colorScheme.background == NightBackground
        Row(
            Modifier.fillMaxWidth().widthIn(max = 520.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(if (nightPage) MaterialTheme.colorScheme.surface else NightBackground)
                .then(if (nightPage) Modifier.border(1.dp, StarGold.copy(alpha = 0.28f), RoundedCornerShape(20.dp)) else Modifier)
                .padding(16.dp),
            verticalAlignment = Alignment.Top,
        ) {
            Box(
                Modifier.size(38.dp).clip(CircleShape).background(StarGold.copy(alpha = 0.18f)),
                contentAlignment = Alignment.Center,
            ) {
                Text("\u2708", fontSize = 15.sp, color = StarGold)
            }
            Spacer(Modifier.width(13.dp))
            Column {
                Text(
                    "Try it in airplane mode",
                    fontSize = 15.sp, fontWeight = FontWeight.Bold,
                    color = NightText,
                )
                Spacer(Modifier.height(5.dp))
                Text(
                    // Not "before your first entry", as iOS says: an Android
                    // phone may still need its offline speech pack, and that
                    // download is the one step that needs a connection.
                    "Turn the radios off and speak. The transcript, the mood, the star — all of it still happens, on the phone. If your phone needs its offline speech pack first, DailyVox will offer it.",
                    fontSize = 13.sp, lineHeight = 19.sp,
                    color = NightText.copy(alpha = 0.72f),
                )
            }
        }

        Spacer(Modifier.height(24.dp))
        // One action. There used to be a second, "See how it works first",
        // which showed nothing: it skipped the microphone request and landed on
        // a recording screen with no way to grant it. The ask now lives on the
        // invite beat, where iOS puts it.
        FilledAction("Continue", onNext)
    }
}

/* ---------------------------------------------------------------- beat 2 */

@Composable
private fun InviteBeat(onNext: () -> Unit) {
    // Continue either way. A journal that refuses to open because you said no
    // to the microphone is punishing caution, and caution is who this is for.
    val mic = com.dailyvox.app.system.rememberMicPermission { onNext() }
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }
    val appear by animateFloatAsState(if (shown) 1f else 0f, tween(900, delayMillis = 150), label = "appear")

    Column(
        Modifier.fillMaxSize().padding(horizontal = 30.dp, vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))
        MonoLabel("02 / 04 · your voice")
        Spacer(Modifier.height(26.dp))
        // Gold rings and a drawn waveform: iOS's invite mark, geometric per §8.9.
        Canvas(Modifier.size(140.dp)) {
            val c = center
            drawCircle(StarGold.copy(alpha = 0.14f * appear), radius = size.minDimension / 2 * (0.7f + 0.3f * appear))
            drawCircle(StarGold.copy(alpha = 0.22f * appear), radius = size.minDimension * 0.30f)
            val bars = listOf(0.35f, 0.7f, 1f, 0.6f, 0.85f, 0.45f)
            val gap = size.minDimension * 0.075f
            val x0 = c.x - gap * (bars.size - 1) / 2
            bars.forEachIndexed { i, h ->
                val half = size.minDimension * 0.13f * h
                drawLine(StarGold, Offset(x0 + i * gap, c.y - half), Offset(x0 + i * gap, c.y + half),
                         strokeWidth = size.minDimension * 0.035f, cap = androidx.compose.ui.graphics.StrokeCap.Round)
            }
        }
        Spacer(Modifier.height(30.dp))
        Text(
            "Your sky starts\nwith your voice",
            style = MaterialTheme.typography.displayMedium,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
            modifier = Modifier.graphicsLayer { alpha = appear; translationY = (1 - appear) * 40f },
        )
        Spacer(Modifier.height(14.dp))
        Text(
            "No forms, no sign-up. Just talk about your day, and watch your voice become the first star in a sky only you can see.",
            fontSize = 16.sp, lineHeight = 25.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.widthIn(max = 440.dp).graphicsLayer { alpha = appear },
        )
        Spacer(Modifier.weight(1.4f))
        // The microphone is asked for here, on the calm screen, so the system
        // dialog never interrupts the recording moment itself (as on iOS).
        FilledAction("I'm ready") {
            if (mic.granted || mic.permanentlyDenied) onNext() else mic.request()
        }
    }
}

/* ---------------------------------------------------------------- beat 3 */

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

    // Re-read when the app comes back to the foreground, so granting the
    // permission in Settings mid-onboarding is noticed here.
    val mic = com.dailyvox.app.system.rememberMicPermission()
    val granted = mic.granted
    // iOS's "I can't talk right now": the first entry, typed. Someone on a
    // train or next to a sleeping partner should not have to skip the moment
    // the whole onboarding is built around.
    var typing by rememberSaveable { mutableStateOf(false) }
    var typed by rememberSaveable { mutableStateOf("") }

    LaunchedEffect(state) {
        when (state) {
            SpeechCapture.State.RECORDING -> { phase = Phase.RECORDING; elapsed = 0
                while (true) { delay(1000); elapsed++ } }
            SpeechCapture.State.PROCESSING -> phase = Phase.PROCESSING
            SpeechCapture.State.IDLE -> if (phase != Phase.BORN) phase = Phase.IDLE
            // Onboarding offers no pause control; the branch exists so the
            // `when` stays exhaustive over the enum.
            SpeechCapture.State.PAUSED -> Unit
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
    // The recogniser failed but the microphone did not. On a phone like that,
    // this used to be where the user's very first entry was destroyed: only
    // `finished` was collected, so the audio sat in an open MediaRecorder until
    // the screen left and nothing ever stopped it. Keep it, and move on.
    LaunchedEffect(Unit) {
        capture.unrecognised.collect {
            if (elapsed < 2) { recorder.discard(); return@collect }
            path = recorder.stop()?.absolutePath ?: return@collect
            text = ""
            onCaptured("", elapsed.coerceAtLeast(1), path)
        }
    }
    // discard() is a no-op once stop() has handed the file over, so this only
    // ever deletes a recording nobody finished -- and releases the mic.
    DisposableEffect(Unit) { onDispose { recorder.discard(); capture.release() } }

    Column(
        Modifier.fillMaxSize().imePadding().padding(horizontal = 26.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        MonoLabel("03 / 04 · your first star")
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
        if (!typing) Text(
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

        // The star makes way for the keyboard when typing.
        if (!typing) {
            Spacer(Modifier.height(34.dp))
            VoiceStar(level = level, phase = phase)
        }
        Spacer(Modifier.height(if (typing) 22.dp else 34.dp))

        when {
            typing -> {
                androidx.compose.material3.OutlinedTextField(
                    value = typed,
                    keyboardOptions = com.dailyvox.app.ui.components.PrivateKeyboard,
                    onValueChange = { typed = it },
                    placeholder = { Text("How was your day, really?") },
                    minLines = 3,
                    shape = RoundedCornerShape(18.dp),
                    modifier = Modifier.fillMaxWidth().widthIn(max = 460.dp),
                )
                Spacer(Modifier.height(8.dp))
                MonoLabel("stored only on this phone")
                Spacer(Modifier.height(16.dp))
                FilledAction("Save my first star") {
                    if (typed.isNotBlank()) onCaptured(typed.trim(), 0, null)
                }
                Spacer(Modifier.height(8.dp))
                QuietAction("Back to speaking") { typing = false }
            }
            // Declined on the invite beat. Offer it again, rather than a screen
            // whose only way forward is to give up on the first entry.
            !granted -> {
                FilledAction(if (mic.permanentlyDenied) "Allow the microphone in Settings" else "Allow the microphone") {
                    if (mic.permanentlyDenied) context.startActivity(
                        android.content.Intent(android.provider.Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                            android.net.Uri.fromParts("package", context.packageName, null))
                            .addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                    ) else mic.request()
                }
                Spacer(Modifier.height(8.dp))
                QuietAction("I can't talk right now") { typing = true }
                QuietAction("Skip for now", onSkip)
            }
            phase == Phase.IDLE -> {
                FilledAction("Start speaking") { recorder.start(); capture.start() }
                Spacer(Modifier.height(8.dp))
                QuietAction("I can't talk right now") { typing = true }
                QuietAction("Skip for now", onSkip)
            }
            phase == Phase.RECORDING -> {
                FilledAction("%d:%02d  ·  Done".format(elapsed / 60, elapsed % 60)) { capture.stop() }
                Spacer(Modifier.height(12.dp))
                // Even mid-recording. If the recogniser dies without calling
                // onError — and OEM implementations do — this is the only exit.
                QuietAction("Skip for now") { capture.cancel(); recorder.discard(); onSkip() }
            }
            else -> Spacer(Modifier.height(56.dp))
        }

        captureError?.let { err ->
            Spacer(Modifier.height(22.dp))
            SpeechErrorCard(err, capture, "Continue anyway",
                onSecondary = { capture.clearError(); onSkip() },
                modifier = Modifier.widthIn(max = 420.dp))
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
private fun ClaimBeat(transcript: String, onEnter: (remind: Boolean) -> Unit) {
    val context = LocalContext.current
    // Ticked by default, as on iOS, but a choice the user can see and untick.
    // The reminder used to switch itself on and the notification dialog then
    // appeared over the app after unlock, with nothing on screen to explain it.
    var remind by rememberSaveable { mutableStateOf(true) }
    val askNotifications = androidx.activity.compose.rememberLauncherForActivityResult(
        androidx.activity.result.contract.ActivityResultContracts.RequestPermission()
    ) { granted -> onEnter(granted) }
    var shown by remember { mutableStateOf(false) }
    LaunchedEffect(Unit) { shown = true }
    val appear by animateFloatAsState(
        if (shown) 1f else 0f, spring(dampingRatio = 0.7f, stiffness = Spring.StiffnessLow), label = "claim",
    )

    Column(
        Modifier.fillMaxSize().padding(horizontal = 26.dp, vertical = 28.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.weight(1f))
        MonoLabel("04 / 04 · yours")
        Spacer(Modifier.height(22.dp))
        // The star, landed: a gold point with a white core in a soft halo.
        Canvas(Modifier.size(110.dp).graphicsLayer { scaleX = 0.6f + 0.4f * appear; scaleY = scaleX; alpha = appear }) {
            drawCircle(StarGold.copy(alpha = 0.14f))
            drawCircle(StarGold.copy(alpha = 0.35f), radius = size.minDimension * 0.17f)
            drawCircle(StarGold, radius = size.minDimension * 0.11f)
            drawCircle(Color.White, radius = size.minDimension * 0.036f)
        }
        Spacer(Modifier.height(24.dp))
        Text(
            if (transcript.isBlank()) "Your sky is ready." else "That star is yours.",
            style = MaterialTheme.typography.displayMedium,
            color = MaterialTheme.colorScheme.onBackground,
            textAlign = TextAlign.Center,
        )
        Spacer(Modifier.height(16.dp))
        if (transcript.isNotBlank()) {
            Text(
                "\u201C$transcript\u201D",
                fontSize = 16.sp, lineHeight = 25.sp,
                fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                color = MaterialTheme.colorScheme.onSurface,
                textAlign = TextAlign.Center,
                maxLines = 5,
                overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                modifier = Modifier
                    .widthIn(max = 460.dp)
                    .clip(RoundedCornerShape(18.dp))
                    .background(MaterialTheme.colorScheme.surface)
                    .padding(horizontal = 20.dp, vertical = 16.dp),
            )
            Spacer(Modifier.height(16.dp))
        }
        Text(
            if (transcript.isBlank()) "Speak whenever you are ready. Nothing is required of you tonight."
            else "It lives on your phone, nowhere else.\nSpeak again tomorrow, and your sky grows.",
            fontSize = 15.sp, lineHeight = 23.sp,
            color = MaterialTheme.colorScheme.onSurfaceVariant,
            textAlign = TextAlign.Center,
            modifier = Modifier.widthIn(max = 420.dp),
        )
        Spacer(Modifier.weight(1f))

        Row(
            Modifier
                .fillMaxWidth().widthIn(max = 460.dp)
                .clip(RoundedCornerShape(18.dp))
                .background(MaterialTheme.colorScheme.surface)
                .clickable { remind = !remind }
                .padding(horizontal = 18.dp, vertical = 14.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            val on = MaterialTheme.colorScheme.primary
            val off = MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.45f)
            Canvas(Modifier.size(26.dp)) {
                if (remind) {
                    drawCircle(on)
                    val p = Path().apply {
                        moveTo(size.width * 0.28f, size.height * 0.52f)
                        lineTo(size.width * 0.44f, size.height * 0.68f)
                        lineTo(size.width * 0.73f, size.height * 0.36f)
                    }
                    drawPath(p, Color.White, style = Stroke(size.width * 0.1f, cap = androidx.compose.ui.graphics.StrokeCap.Round,
                        join = androidx.compose.ui.graphics.StrokeJoin.Round))
                } else drawCircle(off, style = Stroke(size.width * 0.08f))
            }
            Spacer(Modifier.width(14.dp))
            Column {
                Text("Remind me each evening", fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                     color = MaterialTheme.colorScheme.onSurface)
                Text("One nudge at 9 pm. Change it any time in Settings.", fontSize = 13.sp,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
        }
        Spacer(Modifier.height(14.dp))
        FilledAction("Enter my sky") {
            val needsAsk = remind && android.os.Build.VERSION.SDK_INT >= 33 &&
                androidx.core.content.ContextCompat.checkSelfPermission(
                    context, android.Manifest.permission.POST_NOTIFICATIONS
                ) != android.content.pm.PackageManager.PERMISSION_GRANTED
            if (needsAsk) askNotifications.launch(android.Manifest.permission.POST_NOTIFICATIONS)
            else onEnter(remind)
        }
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
