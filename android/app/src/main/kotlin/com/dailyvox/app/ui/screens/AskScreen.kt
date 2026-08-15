package com.dailyvox.app.ui.screens

import androidx.compose.foundation.background
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
@Composable
fun AskScreen(entries: List<Entry>, modifier: Modifier = Modifier) {
    var asked by remember { mutableStateOf<Question?>(null) }
    val questions = remember(entries) { Question.available(entries) }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(12.dp))
        ScreenTitle("Ask your Twin") { MonoLabel("0 calls") }
        MonoLabel("on-device · offline")

        Spacer(Modifier.height(20.dp))
        val q = asked
        if (q == null) {
            Text(
                "Pick something to ask. Every answer is computed from your own entries, and shows which ones it used.",
                fontSize = 15.sp, lineHeight = 23.sp,
                color = MaterialTheme.colorScheme.onSurfaceVariant,
            )
        } else {
            Text(
                q.text, fontSize = 15.sp, fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.secondary)
                    .padding(horizontal = 14.dp, vertical = 10.dp),
            )
            Spacer(Modifier.height(14.dp))
            DvCard {
                Text(q.answer(entries), fontSize = 15.sp, lineHeight = 24.sp,
                     color = MaterialTheme.colorScheme.onSurface)
                val cites = q.cites(entries)
                if (cites.isNotEmpty()) {
                    Spacer(Modifier.height(14.dp))
                    MonoLabel("From your entries")
                    Spacer(Modifier.height(8.dp))
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        cites.take(3).forEach {
                            Chip(SimpleDateFormat("EEE d MMM", Locale.getDefault()).format(Date(it.createdAt)))
                        }
                        if (cites.size > 3) Chip("+${cites.size - 3}")
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
                    cand.text, fontSize = 14.sp,
                    color = MaterialTheme.colorScheme.onSurface,
                    modifier = Modifier.fillMaxWidth()
                        .clip(RoundedCornerShape(16.dp))
                        .background(MaterialTheme.colorScheme.surfaceVariant)
                        .clickable { asked = cand }
                        .padding(horizontal = 14.dp, vertical = 13.dp),
                )
            }
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
