package com.dailyvox.app.ui.screens

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.text.BasicTextField
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.SolidColor
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.toChatEntry
import com.dailyvox.app.data.Repo
import com.dailyvox.app.ui.components.DvCard
import com.dailyvox.app.ui.components.MonoLabel
import com.dailyvox.app.ui.components.ScreenTitle
import com.dailyvox.twin.ChatEntry
import com.dailyvox.twin.RetrievalAnswerComposer
import com.dailyvox.twin.TwinChatEvidence
import com.dailyvox.twin.TwinFacts
import com.dailyvox.twin.TwinQuestion
import com.dailyvox.twin.TwinResponseGenerator
import kotlinx.coroutines.delay
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Ask Your Twin — the Android read of iOS's TwinChatView, feature for feature.
 *
 * A conversation rather than a one-shot answer: the thread persists for the
 * session, every reply carries the entries it drew from, each answer can be
 * read aloud, and each answer offers two ways onward. Two answer paths, both
 * from the engine and both on-device:
 *
 *   - the closed template bank (ten questions, answered from Twin state)
 *   - free text, answered by retrieval — the closest entries, quoted verbatim
 *
 * WHAT ANDROID DOES NOT HAVE is iOS's third path: on Apple-Intelligence
 * hardware, iOS 26 generates a grounded answer through the foundation model and
 * audits it before render. There is no equivalent that fits in a 10 MB APK with
 * no network permission. The copy on this screen therefore never promises an
 * answer it cannot produce, and the retrieval path says plainly that it is
 * quoting rather than reasoning.
 */
@Composable
fun AskScreen(
    entries: List<Entry>,
    onOpenEntry: (Entry) -> Unit = {},
    /**
     * A question to ask on arrival, from B4's "Ask about this".
     *
     * The chat is the same chat either way — seeding it just means you land on
     * an answer instead of an empty box, which is the same argument the
     * suggestion chips are making.
     */
    seedQuestion: String? = null,
    onSeedConsumed: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = LocalContext.current
    val scheme = MaterialTheme.colorScheme
    val night = scheme.background == com.dailyvox.app.ui.theme.NightBackground
    val goldText = if (night) com.dailyvox.app.ui.theme.NightGoldText
                   else com.dailyvox.app.ui.theme.DayGoldText

    val speaker = remember { com.dailyvox.app.system.Speaker(context) }
    DisposableEffect(Unit) { onDispose { speaker.release() } }

    // The aggregate is derived from the whole journal, so it is recomputed only
    // when the journal changes rather than on every keystroke.
    val facts = remember(entries) { TwinFacts.from(entries.map { it.toChatEntry() }) }
    val bank = remember(facts) { TwinQuestion.available(facts) }

    var messages by remember { mutableStateOf(listOf<Msg>()) }
    var asked by remember { mutableStateOf(setOf<TwinQuestion>()) }
    var typed by remember { mutableStateOf("") }
    var thinking by remember { mutableStateOf(false) }
    var speakingId by remember { mutableStateOf<Long?>(null) }
    var seq by remember { mutableLongStateOf(0L) }

    val listState = rememberLazyListState()

    fun push(m: Msg) { messages = messages + m }

    fun send(text: String) {
        if (thinking) return
        val q = text.trim()
        if (q.isEmpty()) return
        seq += 1
        push(Msg(seq, q, isUser = true))
        TwinQuestion.matching(q)?.let { asked = asked + it }
        thinking = true
    }

    // Fires once per seed. Keyed on the seed itself rather than a flag, so
    // asking about a second entry works without the screen being torn down.
    LaunchedEffect(seedQuestion) {
        val seed = seedQuestion ?: return@LaunchedEffect
        if (messages.isEmpty()) send(seed)
        onSeedConsumed()
    }

    // The answer is produced in an effect rather than inline so the user's
    // bubble paints first and the thinking row is actually visible. iOS delays
    // the template path 0.4s for the same reason.
    LaunchedEffect(thinking) {
        if (!thinking) return@LaunchedEffect
        val question = messages.lastOrNull { it.isUser }?.text ?: return@LaunchedEffect
        delay(420)
        val hits = Repo.rank(question, entries).take(3).map { (e, score) ->
            TwinChatEvidence(e.id, e.createdAt, e.text, score)
        }
        val turn = RetrievalAnswerComposer.compose(question, hits, facts)
        seq += 1
        push(Msg(seq, turn.answer, isUser = false,
                 citations = turn.citations, followUps = turn.suggestedFollowUps))
        thinking = false
    }

    LaunchedEffect(messages.size, thinking) {
        // The newest message, not past it. `messages.size` is one index beyond
        // the last bubble, which landed the view on the question bank with the
        // answer scrolled off the top.
        if (messages.isNotEmpty()) listState.animateScrollToItem(messages.lastIndex)
    }

    Column(modifier.fillMaxSize()) {
        Column(Modifier.padding(horizontal = 20.dp)) {
            Spacer(Modifier.height(12.dp))
            ScreenTitle("Ask your Twin") { MonoLabel("0 calls") }
            MonoLabel("answers with receipts · 0 network calls")
            Spacer(Modifier.height(14.dp))
        }

        LazyColumn(
            state = listState,
            modifier = Modifier.weight(1f).padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            if (messages.isEmpty()) {
                item {
                    Text(
                        if (facts.hasEnoughData)
                            "Ask something, or pick one below. Every answer is computed from " +
                                "your own entries and names the ones it used."
                        else
                            "A few more entries and the Twin will have something worth saying. " +
                                "It only speaks from what you have actually said.",
                        fontSize = 15.sp, lineHeight = 23.sp, color = scheme.onSurfaceVariant,
                    )
                }
            }

            items(messages, key = { it.id }) { m ->
                if (m.isUser) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                        Text(
                            m.text, fontSize = 15.sp, lineHeight = 22.sp,
                            fontWeight = FontWeight.SemiBold, color = scheme.onPrimary,
                            modifier = Modifier.widthIn(max = 300.dp)
                                .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp,
                                                         bottomStart = 16.dp, bottomEnd = 4.dp))
                                .background(scheme.primary)
                                .padding(horizontal = 14.dp, vertical = 10.dp),
                        )
                    }
                } else {
                    DvCard {
                        Text(m.text, fontSize = 15.sp, lineHeight = 24.sp,
                             color = scheme.onSurface)

                        if (m.citations.isNotEmpty()) {
                            Spacer(Modifier.height(12.dp))
                            // Receipts. Tappable: a citation you cannot open is
                            // a claim, not evidence.
                            androidx.compose.foundation.layout.FlowRow(
                                horizontalArrangement = Arrangement.spacedBy(6.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp),
                            ) {
                                m.citations.forEach { c ->
                                    val entry = entries.firstOrNull { it.id == c.entryId }
                                    CiteChip(
                                        SimpleDateFormat("MMM d", Locale.getDefault())
                                            .format(Date(c.date)).uppercase() +
                                            " · %d%%".format((c.score * 100).toInt()),
                                        onClick = { entry?.let(onOpenEntry) },
                                    )
                                }
                                CiteChip("${m.citations.size} CITED ✦", solid = true)
                            }
                        }

                        Spacer(Modifier.height(10.dp))
                        Text(
                            if (speakingId == m.id) "Stop" else "Read aloud",
                            fontSize = 12.sp, fontWeight = FontWeight.SemiBold,
                            color = scheme.primary,
                            modifier = Modifier
                                .clip(RoundedCornerShape(12.dp))
                                .clickable {
                                    speaker.toggle(m.text)
                                    speakingId = if (speakingId == m.id) null else m.id
                                }
                                .padding(horizontal = 10.dp, vertical = 6.dp),
                        )

                        if (m.followUps.isNotEmpty()) {
                            Spacer(Modifier.height(4.dp))
                            m.followUps.forEach { f ->
                                Spacer(Modifier.height(6.dp))
                                Text(
                                    f, fontSize = 13.sp, fontWeight = FontWeight.Medium,
                                    color = goldText,
                                    modifier = Modifier
                                        .clip(RoundedCornerShape(13.dp))
                                        .background(com.dailyvox.app.ui.theme.Gold
                                            .copy(alpha = 0.14f))
                                        .clickable { send(f) }
                                        .padding(horizontal = 12.dp, vertical = 9.dp),
                                )
                            }
                        }
                    }
                }
            }

            if (thinking) item { ThinkingRow() }

            // Unasked questions only, so the bank shrinks as the conversation
            // grows rather than repeating what was just answered.
            val remaining = bank.filter { it !in asked }
            if (remaining.isNotEmpty()) {
                item {
                    Column {
                        Spacer(Modifier.height(8.dp))
                        MonoLabel(if (messages.isEmpty()) "Try" else "Also")
                        Spacer(Modifier.height(10.dp))
                        remaining.take(if (messages.isEmpty()) 5 else 3).forEach { q ->
                            Text(
                                q.text, fontSize = 14.sp, fontWeight = FontWeight.Medium,
                                color = scheme.primary,
                                modifier = Modifier.fillMaxWidth()
                                    .padding(bottom = 8.dp)
                                    .clip(RoundedCornerShape(16.dp))
                                    .border(1.5.dp, scheme.primary.copy(alpha = 0.45f),
                                            RoundedCornerShape(16.dp))
                                    .clickable { send(q.text) }
                                    .padding(horizontal = 14.dp, vertical = 13.dp),
                            )
                        }
                    }
                }
            }

            item {
                Spacer(Modifier.height(12.dp))
                DvCard {
                    MonoLabel("what it can answer")
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "The questions above are computed from your journal — mood, people, " +
                            "topics, habits — and every number comes with the entries behind it.",
                        fontSize = 13.sp, lineHeight = 20.sp, color = scheme.onSurfaceVariant,
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Type anything else and it finds rather than answers: the closest " +
                            "entries, quoted as you said them. There is no free-form chat, and " +
                            "that is a choice rather than a gap — a model small enough to ship " +
                            "here would guess, and a Twin that guesses about your own life is " +
                            "worse than one that quotes you back.",
                        fontSize = 13.sp, lineHeight = 20.sp, color = scheme.onSurfaceVariant,
                    )
                }
                Spacer(Modifier.height(4.dp))
            }
        }

        // The input pill, pinned. A chat whose input scrolls away with the
        // history is a list, not a conversation.
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)
                .clip(RoundedCornerShape(24.dp))
                .background(scheme.surface)
                .padding(start = 16.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            BasicTextField(
                value = typed,
                onValueChange = { typed = it },
                singleLine = true,
                textStyle = TextStyle(fontSize = 14.sp, color = scheme.onSurface),
                cursorBrush = SolidColor(scheme.primary),
                modifier = Modifier.weight(1f).padding(vertical = 12.dp),
                decorationBox = { inner ->
                    if (typed.isEmpty()) {
                        Text("Ask, or find what you said about…", fontSize = 14.sp,
                             color = scheme.onSurfaceVariant)
                    }
                    inner()
                },
            )
            Spacer(Modifier.width(8.dp))
            Box(
                Modifier.size(38.dp)
                    .clip(RoundedCornerShape(19.dp))
                    .background(
                        if (typed.isBlank() || thinking) scheme.primary.copy(alpha = 0.35f)
                        else scheme.primary
                    )
                    .clickable(enabled = typed.isNotBlank() && !thinking) {
                        send(typed); typed = ""
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text("↑", fontSize = 17.sp, fontWeight = FontWeight.Bold,
                     color = scheme.onPrimary)
            }
        }
        // No trailing spacer: `modifier` already carries the Scaffold's bottom
        // inset for the floating nav bar. Adding 96dp on top of it pushed the
        // input pill up into the card above and left a dead band beneath.
        Spacer(Modifier.height(8.dp))
    }
}

/** One line in the thread. */
private data class Msg(
    val id: Long,
    val text: String,
    val isUser: Boolean,
    val citations: List<TwinChatEvidence> = emptyList(),
    val followUps: List<String> = emptyList(),
)

/** Three dots, so a 420ms wait reads as thought rather than a dropped tap. */
@Composable
private fun ThinkingRow() {
    val t = rememberInfiniteTransition(label = "think")
    Row(
        Modifier.padding(start = 6.dp, top = 2.dp),
        horizontalArrangement = Arrangement.spacedBy(5.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        repeat(3) { i ->
            val a by t.animateFloat(
                initialValue = 0.25f, targetValue = 0.9f,
                animationSpec = infiniteRepeatable(
                    tween(600, delayMillis = i * 160), RepeatMode.Reverse),
                label = "dot$i",
            )
            Box(
                Modifier.size(7.dp)
                    .clip(RoundedCornerShape(4.dp))
                    .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = a))
            )
        }
    }
}

/**
 * A receipt. Tappable when it points at an entry — a citation you cannot open
 * is a claim rather than evidence.
 */
@Composable
private fun CiteChip(text: String, solid: Boolean = false, onClick: (() -> Unit)? = null) {
    val night = MaterialTheme.colorScheme.background == com.dailyvox.app.ui.theme.NightBackground
    val goldText = if (night) com.dailyvox.app.ui.theme.NightGoldText
                   else com.dailyvox.app.ui.theme.DayGoldText
    Text(
        text,
        fontSize = 9.5.sp, letterSpacing = 0.6.sp, fontWeight = FontWeight.SemiBold,
        color = if (solid && !night) com.dailyvox.app.ui.theme.DayGoldText else goldText,
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(
                if (solid) com.dailyvox.app.ui.theme.Gold.copy(alpha = if (night) 0.28f else 0.38f)
                else com.dailyvox.app.ui.theme.Gold.copy(alpha = if (night) 0.16f else 0.20f)
            )
            .then(if (onClick != null) Modifier.clickable(onClick = onClick) else Modifier)
            .padding(horizontal = 9.dp, vertical = 5.dp),
    )
}
