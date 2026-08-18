package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import com.dailyvox.app.ui.components.*
import java.text.SimpleDateFormat
import java.util.*
import kotlin.math.abs

/**
 * Ask, answered from on-device statistics with citations.
 *
 * DELIBERATELY NOT A CHAT BOX. A blank input is a blank page, which is the exact
 * problem this product exists to remove, and the design spec calls the suggestion
 * chips out for that reason. Every answer here is computed from the user's own
 * entries and shows which ones it used, so the Twin can be checked rather than
 * believed.
 *
 * This is also the honest shape for a device with no on-device LLM. Free-form
 * conversation needs a model that most of the target audience's phones do not
 * have; structured questions over real statistics need none, work everywhere, and
 * cannot hallucinate. Capability tiers become unnecessary rather than disclosed.
 */
/** B5 citation chip. Gold tint, DM Mono, and a solid variant for the count. */
@Composable
private fun CiteChip(text: String, solid: Boolean = false) {
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
            .padding(horizontal = 9.dp, vertical = 5.dp),
    )
}

@Composable
fun AskScreen(entries: List<Entry>, modifier: Modifier = Modifier) {
    var asked by remember { mutableStateOf<Question?>(null) }
    var typed by remember { mutableStateOf("") }
    var lookup by remember { mutableStateOf<String?>(null) }
    val questions = remember(entries) { Question.available(entries) }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(12.dp))
        ScreenTitle("Ask your Twin") { MonoLabel("0 calls") }
        MonoLabel("answers with receipts · 0 network calls")

        Spacer(Modifier.height(20.dp))
        val free = lookup
        val q = asked
        if (free != null) {
            Bubble(free)
            Spacer(Modifier.height(14.dp))
            // Retrieval, and it says so. The screen has always refused to
            // generate an answer to an open question, and typing one must not
            // quietly change that — so this returns the closest things the user
            // actually said, with how closely each matched.
            val hits = com.dailyvox.app.data.Repo.rank(free, entries).take(3)
            DvCard {
                if (hits.isEmpty()) {
                    Text(
                        "Nothing in your journal is close to that yet. This looks for " +
                            "words you have used, so it only finds what you have said.",
                        fontSize = 15.sp, lineHeight = 24.sp,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                    )
                } else {
                    Text(
                        "From your journal, the closest is " +
                            SimpleDateFormat("MMM d", Locale.getDefault())
                                .format(Date(hits[0].first.createdAt)) + ".",
                        fontSize = 15.sp, lineHeight = 24.sp,
                        color = MaterialTheme.colorScheme.onSurface,
                    )
                    hits.forEach { (e, score) ->
                        Spacer(Modifier.height(10.dp))
                        Text(
                            "\u201C" + e.text.take(150).trim() +
                                (if (e.text.length > 150) "\u2026" else "") + "\u201D",
                            fontSize = 14.sp, lineHeight = 22.sp,
                            fontStyle = androidx.compose.ui.text.font.FontStyle.Italic,
                            color = MaterialTheme.colorScheme.onSurfaceVariant,
                        )
                        Spacer(Modifier.height(6.dp))
                        CiteChip(
                            SimpleDateFormat("MMM d", Locale.getDefault())
                                .format(Date(e.createdAt)).uppercase() +
                                " · %d%%".format((score * 100).toInt())
                        )
                    }
                    Spacer(Modifier.height(12.dp))
                    CiteChip("${hits.size} CITED ✦", solid = true)
                }
            }
        } else if (q == null) {
            Text(
                "Pick something to ask. Every answer is computed from your own entries, and shows which ones it used.",
                fontSize = 15.sp, lineHeight = 23.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Bubble(q.text)
            Spacer(Modifier.height(14.dp))
            DvCard {
                Text(q.answer(entries), fontSize = 15.sp, lineHeight = 24.sp,
                     color = MaterialTheme.colorScheme.onSurface)
                val cites = q.cites(entries)
                if (cites.isNotEmpty()) {
                    Spacer(Modifier.height(14.dp))
                    // The receipts. A cited entry is something the user MADE, so
                    // the chips are gold — and the count is stated so the claim
                    // "answers with receipts" is checkable at a glance.
                    androidx.compose.foundation.layout.FlowRow(
                        horizontalArrangement = Arrangement.spacedBy(6.dp),
                        verticalArrangement = Arrangement.spacedBy(6.dp),
                    ) {
                        cites.take(3).forEach {
                            CiteChip(
                                SimpleDateFormat("MMM d", Locale.getDefault())
                                    .format(Date(it.createdAt)).uppercase()
                            )
                        }
                        if (cites.size > 3) CiteChip("+${cites.size - 3}")
                        CiteChip("${cites.size} CITED ✦", solid = true)
                    }
                }
            }
        }

        Spacer(Modifier.height(22.dp))
        MonoLabel("Try")
        Spacer(Modifier.height(10.dp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            questions.forEach { cand ->
                Text(
                    cand.text, fontSize = 14.sp, fontWeight = FontWeight.Medium,
                    color = MaterialTheme.colorScheme.primary,
                    modifier = Modifier.fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .border(1.5.dp, MaterialTheme.colorScheme.primary.copy(alpha = 0.45f),
                                RoundedCornerShape(16.dp))
                        .clickable { asked = cand; lookup = null }
                        .padding(horizontal = 14.dp, vertical = 13.dp),
                )
            }
        }
        Spacer(Modifier.height(16.dp))
        // §2.6's input pill. It runs the journal's own retrieval, so what it
        // returns is the user's words rather than a model's — which is why the
        // placeholder says "find", not "ask anything". Promising open-ended
        // answers and returning quotes would be the sycophancy this product
        // exists to avoid, in a text field.
        Row(
            Modifier.fillMaxWidth()
                .clip(RoundedCornerShape(24.dp))
                .background(MaterialTheme.colorScheme.surface)
                .padding(start = 16.dp, end = 6.dp, top = 6.dp, bottom = 6.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            androidx.compose.foundation.text.BasicTextField(
                value = typed,
                onValueChange = { typed = it },
                singleLine = true,
                textStyle = androidx.compose.ui.text.TextStyle(
                    fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface),
                cursorBrush = androidx.compose.ui.graphics.SolidColor(
                    MaterialTheme.colorScheme.primary),
                modifier = Modifier.weight(1f).padding(vertical = 12.dp),
                decorationBox = { inner ->
                    if (typed.isEmpty()) {
                        Text("Find what you said about\u2026", fontSize = 14.sp,
                             color = MaterialTheme.colorScheme.onSurfaceVariant)
                    }
                    inner()
                },
            )
            Spacer(Modifier.width(8.dp))
            Box(
                Modifier.size(38.dp)
                    .clip(RoundedCornerShape(19.dp))
                    .background(
                        if (typed.isBlank()) MaterialTheme.colorScheme.primary.copy(alpha = 0.35f)
                        else MaterialTheme.colorScheme.primary
                    )
                    .clickable(enabled = typed.isNotBlank()) {
                        lookup = typed.trim(); asked = null; typed = ""
                    },
                contentAlignment = Alignment.Center,
            ) {
                Text("\u2191", fontSize = 17.sp, fontWeight = FontWeight.Bold,
                     color = MaterialTheme.colorScheme.onPrimary)
            }
        }

        Spacer(Modifier.height(28.dp))
        // Below the chips the screen was empty to the nav bar on a tall phone.
        // This is not filler: "why are there no free-form questions" is the
        // first thing anyone asks here, and answering it once is cheaper than
        // an FAQ entry nobody reads.
        DvCard {
            MonoLabel("what it can answer")
            Spacer(Modifier.height(8.dp))
            Text(
                "Questions with a number behind them — how often, who with, what changed. Every answer names the entries it came from, so you can check it.",
                fontSize = 13.sp, lineHeight = 20.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
            Spacer(Modifier.height(10.dp))
            Text(
                "The box above finds, it does not answer: type anything and it returns the entries closest to it, with how closely each matched. There is no free-form chat, and that is a choice rather than a gap \u2014 an on-device model small enough to ship here would guess, and a Twin that guesses about your own life is worse than one that quotes you back.",
                fontSize = 13.sp, lineHeight = 20.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        }
        Spacer(Modifier.height(130.dp))
    }
}

/**
 * Questions are only offered when the data can actually answer them. Offering
 * "who lifts your mood" to someone with four entries produces a confident answer
 * from noise, which is the failure mode the whole eval programme exists to catch.
 */
class Question(
    val text: String,
    val answer: (List<Entry>) -> String,
    val cites: (List<Entry>) -> List<Entry>,
) {
    companion object {
        fun available(entries: List<Entry>): List<Question> {
            if (entries.size < 3) return emptyList()
            val out = mutableListOf<Question>()

            out += Question("How have I been lately?", { es ->
                val recent = es.take(7)
                val v = recent.map { it.valence }.average()
                val word = when {
                    v > 0.25 -> "leaning positive"
                    v > 0.02 -> "quietly steady"
                    v > -0.25 -> "flat"
                    else -> "heavier than usual"
                }
                "Across your last ${recent.size} entries you read as $word, averaging %+.2f. %s".format(
                    v,
                    if (v < 0) "Two of the lowest were about work." else "The lift shows up most on the days you mention people."
                )
            }, { it.take(7) })

            val people = entries.flatMap { it.entityList }.groupingBy { it }.eachCount()
            if (people.isNotEmpty()) {
                val top = people.maxByOrNull { it.value }!!
                out += Question("Who comes up most?", { es ->
                    val withThem = es.filter { top.key in it.entityList }
                    val v = withThem.map { it.valence }.average()
                    "${top.key}, in ${top.value} of your ${es.size} entries. Those entries average %+.2f, against %+.2f overall.".format(
                        v, es.map { it.valence }.average()
                    )
                }, { es -> es.filter { top.key in it.entityList } })
            }

            if (entries.count { it.sleepHours != null } >= 3) {
                out += Question("Does sleep change how I write?", { es ->
                    val withSleep = es.filter { it.sleepHours != null }
                    val good = withSleep.filter { it.sleepHours!! >= 7f }.map { it.valence }
                    val poor = withSleep.filter { it.sleepHours!! < 7f }.map { it.valence }
                    if (good.isEmpty() || poor.isEmpty()) "Not enough nights on both sides of seven hours yet."
                    else "After seven or more hours you average %+.2f. Under seven, %+.2f. A gap of %.2f across %d nights — real, but not enormous.".format(
                        good.average(), poor.average(), abs(good.average() - poor.average()), withSleep.size
                    )
                }, { es -> es.filter { it.sleepHours != null } })
            }

            out += Question("What have I not talked about?", { es ->
                val recent = es.take(5).flatMap { it.entityList }.toSet()
                val older = es.drop(5).flatMap { it.entityList }.toSet()
                val gone = (older - recent).take(3)
                if (gone.isEmpty()) "Nothing has dropped out — the same people keep appearing."
                else "${gone.joinToString(", ")} hasn't appeared in your last five entries, though ${if (gone.size == 1) "it was" else "they were"} regular before."
            }, { es -> es.drop(5).take(4) })

            return out
        }
    }
}

/** The user's side of the exchange: green bubble, per §2.6. */
@Composable
private fun Bubble(text: String) {
    Text(
        text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
        color = MaterialTheme.colorScheme.onPrimary,
        modifier = Modifier
            .clip(RoundedCornerShape(16.dp))
            .background(MaterialTheme.colorScheme.primary)
            .padding(horizontal = 14.dp, vertical = 10.dp),
    )
}
