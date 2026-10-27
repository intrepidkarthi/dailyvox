package com.dailyvox.app.ui.screens

import com.dailyvox.app.ui.components.SpeechErrorCard
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.focus.FocusRequester
import androidx.compose.ui.focus.focusRequester
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.LiveRegionMode
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.liveRegion
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.R
import com.dailyvox.app.audio.AudioRecorder
import com.dailyvox.app.system.DailyQuestion
import com.dailyvox.app.system.Reflection
import com.dailyvox.app.audio.SpeechCapture
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.text.SpanStyle
import com.dailyvox.app.ui.components.MonoLabel
import com.dailyvox.app.ui.components.MoodPicker
import com.dailyvox.app.ui.components.moodWord
import com.dailyvox.app.ui.components.PrivateKeyboard
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
    /** What the app read back from the entry just saved; null hides the card. */
    reflection: com.dailyvox.app.system.Reflection.Card? = null,
    onDismissReflection: () -> Unit = {},
    /** A mood picked on the reflection card, or null when it was cleared. */
    onReflectionMood: (String?) -> Unit = {},
    onRecordingChanged: (Boolean) -> Unit = {},
    onInsights: () -> Unit = {},
    onSettings: () -> Unit = {},
    /** The entry from about a week ago, quoted; null hides the card. */
    weekAgo: com.dailyvox.app.system.Resurface.Memory? = null,
    /** Same date, earlier months and years. Empty hides them. */
    onThisDay: List<com.dailyvox.app.system.Resurface.Memory> = emptyList(),
    /** Last week, counted. Only passed on recap day. */
    recap: com.dailyvox.app.system.Resurface.Recap? = null,
    onOpenEntry: (com.dailyvox.app.data.Entry) -> Unit = {},
    /** Today's question ([DailyQuestion]). The default is the original line. */
    question: DailyQuestion.Question = DailyQuestion.Question.Everyday(0),
    /** "Another question". Only ever changes the words above the button. */
    onAnotherQuestion: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val goldText = if (MaterialTheme.colorScheme.background ==
                       com.dailyvox.app.ui.theme.NightBackground)
        com.dailyvox.app.ui.theme.NightGoldText else com.dailyvox.app.ui.theme.DayGoldText
    val capture = remember { SpeechCapture(context) }
    val recorder = remember { AudioRecorder(context) }
    // The Today card's play chip. Same AudioQueue the Journal's "Play today"
    // pill uses, so the two behave identically.
    val todayQueue = remember { com.dailyvox.app.audio.AudioQueue() }
    var playingToday by remember { mutableStateOf(false) }
    val haptics = remember { com.dailyvox.app.system.Haptics(context) }
    var audioPath by remember { mutableStateOf<String?>(null) }
    // Handles the two cases the inline version could not: a permanent denial,
    // where re-launching the request is a silent no-op and the only way out is
    // app settings, and a permission granted in Settings while the app was
    // backgrounded, which nothing here used to notice.
    val mic = com.dailyvox.app.system.rememberMicPermission()
    val granted = mic.granted

    // "I can't talk right now" -- the onboarding escape hatch, kept for good.
    // Most of a day is spent around coworkers, customers or family, where
    // speaking to a journal aloud is not an option; a user asked for typing to
    // stay rather than vanish after the first star. Saveable, so a rotation or
    // a trip to another app mid-sentence does not lose the draft.
    var typing by rememberSaveable { mutableStateOf(false) }
    var typed by rememberSaveable { mutableStateOf("") }

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

    LaunchedEffect(state, typing) {
        onRecordingChanged(
            state == SpeechCapture.State.RECORDING || state == SpeechCapture.State.PAUSED || typing
        )
    }

    LaunchedEffect(state) {
        when (state) {
            SpeechCapture.State.RECORDING -> {
                // `elapsed` is reset where recording STARTS, not here. Resuming
                // from a pause re-enters this branch, and zeroing it there would
                // have thrown away the seconds already spoken.
                com.dailyvox.app.system.RecordingLive.onFinishRequested = { capture.stop() }
                while (true) {
                    com.dailyvox.app.system.RecordingLive.show(context, elapsed)
                    delay(1000)
                    elapsed++
                }
            }
            SpeechCapture.State.PAUSED -> {
                // The chip stays, frozen. A recording that is paused has not
                // ended, and clearing the notification would say it had.
                com.dailyvox.app.system.RecordingLive.onFinishRequested = { capture.stop() }
                com.dailyvox.app.system.RecordingLive.show(context, elapsed)
            }
            else -> {
                com.dailyvox.app.system.RecordingLive.hide(context)
                com.dailyvox.app.system.RecordingLive.onFinishRequested = null
            }
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

    // Transcription failed, but the microphone worked and the audio is on disk.
    //
    // Save it anyway. Losing the recording is a strictly worse outcome than an
    // entry with no words in it: the words can be recovered later, from the
    // audio, by a better recogniser or by the user typing them. A deleted file
    // cannot be recovered by anything.
    //
    // This is the whole difference between "the app did not transcribe that"
    // and "the app threw away what you said", and until now it was the second.
    LaunchedEffect(Unit) {
        capture.unrecognised.collect {
            // Under two seconds with no words is a pocket tap or a cough, not an
            // entry: filing it would put an empty, unplayable-looking row in the
            // journal. The error card still says nothing was caught.
            if (elapsed < MIN_KEPT_SECONDS) { recorder.discard(); return@collect }
            val path = recorder.stop()?.absolutePath ?: return@collect
            onSaved("", elapsed.coerceAtLeast(1), path)
            haptics.entrySaved()
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
            elapsed = 0
            recorder.start(); capture.start()
        } else if (autoStart && !granted) {
            onAutoStarted()
        }
    }

    // Leaving the screen must take the notification with it, or a cancelled
    // recording leaves a "Listening" chip that nothing will ever clear.
    DisposableEffect(Unit) {
        onDispose {
            todayQueue.stop()
            // `capture.release()` only ends the recogniser. A recording still
            // open when the screen goes away would leave MediaRecorder holding
            // the microphone — and now that Pause exists, "still open" includes
            // a paused entry the user walked away from.
            //
            // PROCESSING is different: the user already pressed stop, so the
            // entry is theirs and only the transcript is late. Walking away
            // during "Filing it." used to delete the audio and the words with
            // it. File what exists -- the audio, plus whatever partial was
            // heard -- and let the entry say it has no transcript.
            when (capture.state.value) {
                SpeechCapture.State.IDLE -> Unit
                SpeechCapture.State.PROCESSING -> {
                    val path = recorder.stop()?.absolutePath
                    val heard = capture.partial.value
                    if (path != null || heard.isNotBlank()) onSaved(heard, elapsed.coerceAtLeast(1), path)
                }
                else -> recorder.discard()
            }
            capture.release()
            com.dailyvox.app.system.RecordingLive.hide(context)
            com.dailyvox.app.system.RecordingLive.onFinishRequested = null
        }
    }

    // Recording is a full-screen moment, not a state of this screen. The design
    // gives it its own navy dial (B2b), so hand off entirely rather than trying
    // to morph the idle layout around it.
    LaunchedEffect(state, typing) {
        onRecordingChanged(
            state == SpeechCapture.State.RECORDING || state == SpeechCapture.State.PAUSED || typing
        )
    }

    // Back closes the composer rather than leaving the app; the draft stays.
    androidx.activity.compose.BackHandler(enabled = typing) { typing = false }

    if (state == SpeechCapture.State.RECORDING || state == SpeechCapture.State.PAUSED) {
        RecordingDial(
            elapsed = elapsed,
            level = level,
            partial = partial,
            lastEntity = caughtEntity,
            paused = state == SpeechCapture.State.PAUSED,
            onStop = { haptics.recordStop(); capture.stop() },
            // Discard used to call `capture.stop()`, which emits `finished`,
            // which the collector below SAVES. The entry the user threw away
            // was filed anyway, audio and all.
            onDiscard = {
                haptics.recordStop()
                capture.cancel()
                recorder.discard()
                elapsed = 0
            },
            onPause = { capture.pause(); recorder.pause() },
            onResume = { capture.resume(); recorder.resume() },
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
        modifier.fillMaxSize().imePadding().verticalScroll(rememberScrollState()).padding(horizontal = 24.dp),
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
        // The question of the day. An invitation, never a gate: the record
        // button below works the same whatever it says, and most nights it is
        // not read at all. At rest, a tap on it (or on "Another question")
        // asks something else; while recording it gives way to the state.
        val asked = dailyQuestionText(question)
        val atRest = state == SpeechCapture.State.IDLE
        val anotherLabel = stringResource(R.string.daily_question_another_action)
        Text(
            when (state) {
                SpeechCapture.State.RECORDING -> "Listening."
                SpeechCapture.State.PROCESSING -> "Filing it."
                // The signature question keeps the break it has always had.
                else -> if (question == DailyQuestion.Question.Everyday(0))
                    asked.replaceFirst(", ", ",\n") else asked
            },
            // A longer question steps down a size rather than filling the
            // screen; sp throughout, so the user's font scale still applies.
            fontSize = if (!atRest || asked.length <= 34) 32.sp else 26.sp,
            lineHeight = if (!atRest || asked.length <= 34) 38.sp else 32.sp,
            fontWeight = FontWeight.ExtraBold, fontFamily = com.dailyvox.app.ui.theme.Nunito,
            textAlign = androidx.compose.ui.text.style.TextAlign.Center,
            color = MaterialTheme.colorScheme.onBackground,
            modifier = Modifier
                .widthIn(max = 460.dp)
                .then(
                    if (atRest && !typing) Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .clickable(onClickLabel = anotherLabel, onClick = onAnotherQuestion)
                        .semantics { liveRegion = LiveRegionMode.Polite }
                    else Modifier
                ),
        )
        if (atRest && !typing) {
            Spacer(Modifier.height(6.dp))
            Text(
                stringResource(R.string.daily_question_another),
                fontSize = 13.sp, fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .clickable(onClick = onAnotherQuestion)
                    .semantics { role = Role.Button }
                    .defaultMinSize(minHeight = 44.dp)
                    .padding(horizontal = 12.dp)
                    .wrapContentHeight(Alignment.CenterVertically),
            )
        }

        if (typing) {
            Spacer(Modifier.height(if (tall) 28.dp else 16.dp))
            TypedComposer(
                hint = asked,
                text = typed,
                onText = { typed = it },
                onSave = {
                    val t = typed.trim()
                    if (t.isNotEmpty()) {
                        // The same path a spoken entry takes, with no seconds and
                        // no audio: Journal and Entry detail already read that
                        // pair as "typed", and the Today card shows no play chip.
                        onSaved(t, 0, null)
                        if (streak > 0 && (streak + 1) % 7 == 0) haptics.streakMilestone()
                        else haptics.entrySaved()
                        typed = ""
                        typing = false
                    }
                },
                onBack = { typing = false },
            )
        } else {
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
                    if (!granted) mic.request()
                    else if (state == SpeechCapture.State.RECORDING) { haptics.recordStop(); capture.stop() }
                    // Only from IDLE. A tap during PROCESSING used to reach here:
                    // capture.start() returned early, recorder.start() did not, and
                    // a second MediaRecorder opened over the entry being filed.
                    else if (state == SpeechCapture.State.IDLE) { onDismissReflection(); capture.clearError(); haptics.recordStart(); elapsed = 0; recorder.start(); capture.start() }
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

            // Quiet, and only at rest. Same words as onboarding so the two read
            // as one feature. Offered with the microphone denied too: that user
            // has the strongest reason to want it. Not during PROCESSING, when
            // the entry being filed is still the screen's business.
            if (state == SpeechCapture.State.IDLE) {
                Spacer(Modifier.height(10.dp))
                Text(
                    "I can't talk right now",
                    fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier
                        .clip(RoundedCornerShape(16.dp))
                        .clickable { onDismissReflection(); capture.clearError(); typing = true }
                        .semantics {
                            role = Role.Button
                            contentDescription = "Type an entry instead"
                        }
                        .defaultMinSize(minHeight = 48.dp)
                        .padding(horizontal = 14.dp)
                        .wrapContentHeight(Alignment.CenterVertically),
                )
            }
        }

        // The failure, where the user is looking when it happens. Silently
        // returning to "Tap to start" taught people the button was broken.
        captureError?.let { err ->
            Spacer(Modifier.height(20.dp))
            SpeechErrorCard(err, capture, "Dismiss", onSecondary = { capture.clearError() })
        }

        // Something back for what was just given. Only at rest: while the next
        // entry is being filed, that entry is the screen's business.
        if (reflection != null && state == SpeechCapture.State.IDLE && !typing) {
            Spacer(Modifier.height(if (tall) 28.dp else 18.dp))
            ReflectionCard(reflection, onDismiss = onDismissReflection,
                           onMood = onReflectionMood, goldText = goldText)
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
                    // It looked like a play button and was a label: no
                    // clickable, no player, nothing behind the triangle.
                    //
                    // The touch target sits on the Box, not on the chip. The
                    // chip is drawn at the design's size and would be a ~20dp
                    // target on its own — under the 48dp §8.6 asks for, and the
                    // one Play's pre-launch report measures.
                    //
                    // Only when there is audio: a typed entry showed "▶ 0:00",
                    // a play button with nothing behind it.
                    if (!e.audioPath.isNullOrBlank()) Box(
                        Modifier
                            .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                            .clickable {
                                if (playingToday) {
                                    todayQueue.stop(); playingToday = false
                                } else {
                                    val path = e.audioPath
                                    if (path.isNullOrBlank()) {
                                        android.widget.Toast.makeText(
                                            context,
                                            "This entry has no audio saved.",
                                            android.widget.Toast.LENGTH_SHORT,
                                        ).show()
                                    } else {
                                        playingToday = true
                                        todayQueue.play(listOf(path)) { playingToday = false }
                                    }
                                }
                            }
                            .semantics {
                                contentDescription =
                                    if (playingToday) "Stop playing today's entry"
                                    else "Play today's entry"
                            },
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            "%s %d:%02d".format(
                                if (playingToday) "■" else "▶",
                                e.durationSec / 60, e.durationSec % 60,
                            ),
                            fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                            color = MaterialTheme.colorScheme.primary,
                            modifier = Modifier
                                .clip(RoundedCornerShape(11.dp))
                                .background(MaterialTheme.colorScheme.surfaceVariant)
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                        )
                    }
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

        // The user's own past, quoted (the diary's payoff). At rest only, and
        // each card only when there is a real entry under it, so a new user
        // sees nothing here rather than an empty promise.
        if (state == SpeechCapture.State.IDLE && !typing) {
            recap?.let {
                Spacer(Modifier.height(if (tall) 28.dp else 18.dp))
                com.dailyvox.app.ui.components.RecapCard(it, goldText, onOpenEntry)
            }
            weekAgo?.let {
                Spacer(Modifier.height(if (tall) 28.dp else 18.dp))
                com.dailyvox.app.ui.components.PastCard(it, goldText, onOpenEntry)
            }
            onThisDay.forEach {
                Spacer(Modifier.height(12.dp))
                com.dailyvox.app.ui.components.PastCard(it, goldText, onOpenEntry)
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
            // scheme.tertiary, not the v1.0 hex this was pinned to.
            Box(Modifier.size(7.dp).clip(RoundedCornerShape(4.dp))
                .background(MaterialTheme.colorScheme.tertiary))
            Spacer(Modifier.width(10.dp))
            Text("Works in airplane mode. Nothing leaves this phone.",
                 fontSize = 13.sp, color = MaterialTheme.colorScheme.onSurface,
                 modifier = Modifier.weight(1f))
            MonoLabel("0 calls")
        }
        Spacer(Modifier.height(if (tall) 132.dp else 112.dp))   // clears the floating nav pill
    }
}

/**
 * The payoff for an entry: a few calm lines read off what was just saved.
 *
 * Every line comes from [Reflection], which only reads the entry's own valence,
 * names, length and words, so nothing on this card is a guess. Lines with
 * nothing under them are not drawn at all, and the "for tomorrow" line is the
 * user's own sentence, quoted, or absent.
 *
 * TalkBack reads the card as one unit and announces it when it appears, since
 * a saved entry otherwise gives a screen-reader user nothing but a haptic.
 *
 * The mood row is the one part that is a guess, so it is marked as one in the
 * words, in the chip's outline and in what TalkBack says. It sits outside the
 * merged unit so each chip can be reached and tapped on its own.
 */
@Composable
private fun ReflectionCard(
    card: Reflection.Card,
    onDismiss: () -> Unit,
    onMood: (String?) -> Unit,
    goldText: Color,
) {
    val scheme = MaterialTheme.colorScheme
    val res = LocalContext.current.resources
    val lines = buildList {
        if (card.wordless) add(res.getString(R.string.reflection_wordless))
        when (card.tone) {
            Reflection.Tone.LIGHT -> add(res.getString(R.string.reflection_tone_light))
            Reflection.Tone.EVEN -> add(res.getString(R.string.reflection_tone_even))
            Reflection.Tone.HEAVY -> add(res.getString(R.string.reflection_tone_heavy))
            null -> Unit
        }
        when (card.drift) {
            Reflection.Drift.LIGHTER -> add(res.getString(R.string.reflection_drift_lighter))
            Reflection.Drift.HEAVIER -> add(res.getString(R.string.reflection_drift_heavier))
            Reflection.Drift.SIMILAR -> add(res.getString(R.string.reflection_drift_similar))
            null -> Unit
        }
        card.person?.let { name ->
            add(
                if (card.personEarlier > 0) res.getQuantityString(
                    R.plurals.reflection_person_earlier, card.personEarlier, name, card.personEarlier)
                else res.getString(R.string.reflection_person, name)
            )
        }
    }
    val meta = buildList {
        if (!card.wordless) add(res.getQuantityString(R.plurals.reflection_words, card.words, card.words))
        if (card.typed) add(res.getString(R.string.reflection_typed))
        else add("%d:%02d".format(card.seconds / 60, card.seconds % 60))
    }.joinToString(" · ")
    val label = stringResource(R.string.reflection_label)
    val tomorrowLabel = stringResource(R.string.reflection_tomorrow_label)
    val tomorrowQuote = card.tomorrow?.let { stringResource(R.string.reflection_tomorrow_quote, it) }
    // Announced with the card as it first appeared, and frozen there: if the
    // live region's text changed on every chip tap, TalkBack would read the
    // whole card again each time. The chips announce their own state.
    val firstSuggestion = remember(card.entryId) { card.suggestedMood?.takeIf { card.moodIsSuggested } }
    val moodLine = firstSuggestion?.let {
        stringResource(R.string.reflection_mood_suggested_line, moodWord(it))
    }
    val spoken = (listOf("$label. $meta.") + lines +
        listOfNotNull(tomorrowQuote?.let { "$tomorrowLabel: $it" }, moodLine)).joinToString(" ")
    val doneDescription = stringResource(R.string.reflection_done_description)
    // Shown once there was a mood to show, and kept after a clear so the user
    // can still pick one; a section that vanished on "Clear" would take the
    // picker with it.
    val showMood = remember(card.entryId) { card.mood != null }

    Column(
        Modifier
            .fillMaxWidth()
            .widthIn(max = 460.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(scheme.surface)
            .padding(horizontal = 18.dp, vertical = 16.dp),
    ) {
        Column(
            Modifier.fillMaxWidth().semantics(mergeDescendants = true) {
                contentDescription = spoken
                liveRegion = LiveRegionMode.Polite
            },
        ) {
            Text(
                "✦ $label",
                fontSize = 13.sp, fontWeight = FontWeight.Bold, color = goldText,
            )
            Spacer(Modifier.height(4.dp))
            MonoLabel(meta)
            lines.forEach { line ->
                Spacer(Modifier.height(10.dp))
                Text(line, fontSize = 15.sp, lineHeight = 21.sp, color = scheme.onSurface)
            }
            tomorrowQuote?.let { quote ->
                Spacer(Modifier.height(14.dp))
                Text(
                    tomorrowLabel,
                    fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
                    color = scheme.onSurfaceVariant,
                )
                Spacer(Modifier.height(3.dp))
                Text(
                    quote, fontSize = 15.sp, lineHeight = 21.sp,
                    fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                    color = scheme.onSurface,
                )
            }
            Spacer(Modifier.height(12.dp))
            Text(
                stringResource(R.string.reflection_how_read),
                fontSize = 12.sp, lineHeight = 17.sp,
                color = scheme.onSurfaceVariant,
            )
        }
        if (showMood) {
            Spacer(Modifier.height(16.dp))
            ReflectionMood(card, onMood)
        }
        Spacer(Modifier.height(6.dp))
        // Same quiet text-button shape as "I can't talk right now", with the
        // touch target the size Play's pre-launch report measures.
        Text(
            stringResource(R.string.reflection_done),
            fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
            color = scheme.primary,
            modifier = Modifier
                .align(Alignment.End)
                .clip(RoundedCornerShape(16.dp))
                .clickable(onClick = onDismiss)
                .semantics {
                    role = Role.Button
                    contentDescription = doneDescription
                }
                .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                .padding(horizontal = 14.dp)
                .wrapContentHeight(Alignment.CenterVertically),
        )
    }
}

/**
 * The mood on the reflection card: the app's suggestion, plainly called one,
 * or the user's own pick once they have made it. The picker is the entry
 * page's, so a mood chosen here is the same label in the same column.
 *
 * Tapping the outlined chip keeps the suggestion as the user's own; tapping
 * any other picks that instead; Clear leaves the entry with no mood at all.
 */
@Composable
private fun ReflectionMood(card: Reflection.Card, onMood: (String?) -> Unit) {
    val scheme = MaterialTheme.colorScheme
    val mood = card.mood
    val (heading, body) = when {
        mood == null -> stringResource(R.string.reflection_mood_heading_mine) to
            stringResource(R.string.reflection_mood_none)
        card.moodIsSuggested -> stringResource(R.string.reflection_mood_heading_suggested) to
            stringResource(R.string.reflection_mood_suggested_body, moodWord(mood))
        else -> stringResource(R.string.reflection_mood_heading_mine) to
            stringResource(R.string.reflection_mood_chosen_body, moodWord(mood))
    }
    val clearDescription = stringResource(
        if (card.moodIsSuggested) R.string.reflection_mood_clear_suggested_description
        else R.string.reflection_mood_clear_description
    )

    Column(Modifier.fillMaxWidth()) {
        Column(Modifier.semantics(mergeDescendants = true) {}) {
            Text(heading, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
                 color = scheme.onSurfaceVariant)
            Spacer(Modifier.height(3.dp))
            Text(body, fontSize = 15.sp, lineHeight = 21.sp, color = scheme.onSurface)
        }
        Spacer(Modifier.height(10.dp))
        MoodPicker(current = card.chosenMood, suggested = card.suggestedMood, onPick = onMood)
        if (mood != null) {
            Text(
                stringResource(R.string.reflection_mood_clear),
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                color = scheme.primary,
                modifier = Modifier
                    .padding(top = 4.dp)
                    .clip(RoundedCornerShape(16.dp))
                    .clickable { onMood(null) }
                    .semantics {
                        role = Role.Button
                        contentDescription = clearDescription
                    }
                    .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                    .padding(horizontal = 14.dp)
                    .wrapContentHeight(Alignment.CenterVertically),
            )
        }
    }
}

/**
 * The typed composer. Onboarding's typed beat, lifted out for the Speak screen:
 * the same outlined field, the same mic-less keyboard, the same pair of
 * actions. It takes the record button's place rather than opening a sheet, so
 * the question above it is still the question being answered.
 */
@Composable
private fun TypedComposer(
    hint: String,
    text: String,
    onText: (String) -> Unit,
    onSave: () -> Unit,
    onBack: () -> Unit,
) {
    val scheme = MaterialTheme.colorScheme
    val focus = remember { FocusRequester() }
    LaunchedEffect(Unit) { focus.requestFocus() }
    val canSave = text.isNotBlank()

    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        OutlinedTextField(
            value = text,
            onValueChange = onText,
            keyboardOptions = PrivateKeyboard,
            placeholder = { Text(hint) },
            minLines = 4,
            shape = RoundedCornerShape(18.dp),
            modifier = Modifier.fillMaxWidth().widthIn(max = 460.dp).focusRequester(focus),
        )
        Spacer(Modifier.height(8.dp))
        MonoLabel("typed, not recorded \u00B7 stays on this phone")
        Spacer(Modifier.height(16.dp))
        Text(
            "Save to today",
            fontSize = 16.sp, fontWeight = FontWeight.Bold,
            color = if (canSave) scheme.onPrimary else scheme.onPrimary.copy(alpha = 0.6f),
            modifier = Modifier
                .fillMaxWidth()
                .widthIn(max = 460.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(if (canSave) scheme.primary else scheme.primary.copy(alpha = 0.35f))
                .clickable(enabled = canSave, onClick = onSave)
                .semantics { role = Role.Button }
                .padding(vertical = 18.dp)
                .wrapContentWidth(Alignment.CenterHorizontally),
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Back to speaking",
            fontSize = 14.sp,
            color = scheme.onSurfaceVariant,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(16.dp))
                .clickable(onClick = onBack)
                .semantics { role = Role.Button }
                .padding(vertical = 12.dp)
                .wrapContentWidth(Alignment.CenterHorizontally),
        )
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
    // §8.8: the solar-system idle is ambient, so it parks.
    val still = com.dailyvox.app.ui.components.reduceMotion()
    val spin = rememberInfiniteTransition(label = "ring")
    val driftRaw by spin.animateFloat(
        0f, 360f,
        infiniteRepeatable(tween(120_000, easing = LinearEasing), RepeatMode.Restart),
        label = "driftRaw",
    )
    val drift = if (still) 0f else driftRaw
    val orbitRaw by spin.animateFloat(
        0f, 360f,
        infiniteRepeatable(
            tween(if (state == SpeechCapture.State.RECORDING) 12_000 else 16_000,
                  easing = LinearEasing),
            RepeatMode.Restart,
        ),
        label = "orbitRaw",
    )
    val orbit = if (still) 0f else orbitRaw
    // Record start: mic scales 1 -> 1.08 on a spring (§4).
    // Finger down: 0.95, the same give iOS's button style has. Without it the
    // disc was a picture of a button until the tap landed.
    var pressed by remember { mutableStateOf(false) }
    val press by animateFloatAsState(
        when {
            pressed -> 0.95f
            state == SpeechCapture.State.RECORDING -> 1.08f
            else -> 1f
        },
        spring(dampingRatio = 0.55f, stiffness = Spring.StiffnessMediumLow),
        label = "press",
    )

    Box(contentAlignment = Alignment.Center) {
        Canvas(
            Modifier
                .size(diameter)
                .semantics { contentDescription = label }
                .pointerInput(state) {
                    detectTapGestures(
                        onPress = { pressed = true; tryAwaitRelease(); pressed = false },
                        onTap = { onTap() },
                    )
                }
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
            // Lit from above: a lighter crown falling to the base colour, so the
            // disc has the volume of the gold 3D mic in the brand mark rather
            // than reading as a flat sticker.
            val base = if (state == SpeechCapture.State.RECORDING) scheme.error else scheme.primary
            drawCircle(
                brush = Brush.verticalGradient(
                    listOf(androidx.compose.ui.graphics.lerp(base, Color.White, 0.16f), base),
                    startY = c.y - discR, endY = c.y + discR,
                ),
                radius = discR,
                center = c,
            )
        }

        // A microphone, drawn: capsule, the U-shaped holder, stem and foot.
        // The bare capsule read as a "0" or a pill; iOS shows mic.fill. Still
        // geometric strokes, per §8.9, and it rides the press scale.
        Canvas(Modifier.size(diameter * 0.25f * press)) {
            val w = size.width; val h = size.height
            val ink = scheme.onPrimary
            val stroke = w * 0.085f
            drawRoundRect(
                color = ink,
                topLeft = Offset(w * 0.34f, 0f),
                size = androidx.compose.ui.geometry.Size(w * 0.32f, h * 0.60f),
                cornerRadius = androidx.compose.ui.geometry.CornerRadius(w * 0.16f),
            )
            drawArc(
                color = ink, startAngle = 0f, sweepAngle = 180f, useCenter = false,
                topLeft = Offset(w * 0.20f, h * 0.22f),
                size = androidx.compose.ui.geometry.Size(w * 0.60f, h * 0.52f),
                style = androidx.compose.ui.graphics.drawscope.Stroke(stroke, cap = androidx.compose.ui.graphics.StrokeCap.Round),
            )
            drawLine(ink, Offset(w * 0.5f, h * 0.74f), Offset(w * 0.5f, h * 0.90f), stroke,
                     cap = androidx.compose.ui.graphics.StrokeCap.Round)
            drawLine(ink, Offset(w * 0.36f, h * 0.93f), Offset(w * 0.64f, h * 0.93f), stroke,
                     cap = androidx.compose.ui.graphics.StrokeCap.Round)
        }
    }
}

/** Shortest wordless recording worth keeping as an audio-only entry. */
private const val MIN_KEPT_SECONDS = 2

/**
 * The words for a [DailyQuestion.Question]. Picking is pure and lives in
 * DailyQuestion; the words live in strings.xml so they translate. An index
 * past the end of a list (a translation that ships fewer questions) falls back
 * to the original line rather than crashing the home screen.
 */
@Composable
internal fun dailyQuestionText(q: DailyQuestion.Question): String {
    val everyday = androidx.compose.ui.res.stringArrayResource(R.array.daily_questions)
    val plain = androidx.compose.ui.res.stringArrayResource(R.array.daily_questions_plain)
    val fallback = everyday.firstOrNull() ?: "How was your day, really?"
    return when (q) {
        is DailyQuestion.Question.Everyday -> everyday.getOrNull(q.index) ?: fallback
        is DailyQuestion.Question.Plain -> plain.getOrNull(q.index) ?: fallback
        is DailyQuestion.Question.Grounded -> stringResource(
            when {
                q.daysAgo <= 1 -> R.string.daily_question_grounded_yesterday
                q.daysAgo < 7 -> R.string.daily_question_grounded_days
                else -> R.string.daily_question_grounded_week
            },
            q.name,
        )
    }
}
