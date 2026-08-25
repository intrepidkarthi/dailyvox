package com.dailyvox.app.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.background
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.toChatEntry
import com.dailyvox.twin.Insights
import com.dailyvox.app.ui.theme.Gold
import androidx.compose.ui.text.font.FontWeight
import com.dailyvox.app.ui.components.*
import com.dailyvox.app.ui.theme.StarGold
import java.util.*
import kotlin.math.abs

/**
 * Insights. Everything here is computed from the user's own entries — there is
 * no model in the loop and nothing is inferred that the numbers do not support.
 *
 * The patterns section is the one that could lie, so it is gated: a pattern is
 * only shown when it clears a support threshold. A confident sentence built on
 * three entries is exactly the failure the whole eval programme exists to catch,
 * and it is worse here than anywhere else in the app because it is phrased as
 * something the Twin noticed about the user.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun InsightsScreen(
    entries: List<Entry>,
    streak: Int,
    onBack: () -> Unit = {},
    onShareMilestone: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val context = androidx.compose.ui.platform.LocalContext.current
    // The one place the goal notification can fire from: Insights is where the
    // number lives, and posting from a background job would need a scheduler
    // this app deliberately does not run.
    LaunchedEffect(entries.size) {
        com.dailyvox.app.system.Goals.celebrateIfReached(context, entries)
    }
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState()).padding(horizontal = 20.dp)) {
        Spacer(Modifier.height(12.dp))
        ScreenTitle("Insights", onBack = onBack)

        val week = entries.filter { it.createdAt > System.currentTimeMillis() - 7L * 86_400_000 }
        val prior = entries.filter {
            it.createdAt in (System.currentTimeMillis() - 14L * 86_400_000)..(System.currentTimeMillis() - 7L * 86_400_000)
        }

        // B6 streak card: giant gold numeral, a 7-day bar strip, and the three
        // totals in DM Mono. The number is the reward, so it is gold — and gold
        // TEXT on cream must use the AA-safe tone, not the accent itself.
        val night = MaterialTheme.colorScheme.background == com.dailyvox.app.ui.theme.NightBackground
        val goldText = if (night) com.dailyvox.app.ui.theme.NightGoldText
                       else com.dailyvox.app.ui.theme.DayGoldText
        DvCard(
            // §F: the streak card is the milestone, so long-pressing it opens
            // the stamp. Nothing is minted here -- the card only exists once
            // the nights do.
            Modifier.combinedClickable(onClick = {}, onLongClick = onShareMilestone)
        ) {
            Row(verticalAlignment = Alignment.Bottom) {
                Text("$streak", fontSize = 36.sp, fontWeight = FontWeight.ExtraBold,
                     color = goldText)
                Spacer(Modifier.width(8.dp))
                Text(
                    if (streak > 0) "days in a row — your longest" else "no streak yet",
                    fontSize = 13.sp, fontWeight = FontWeight.Bold,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                    modifier = Modifier.padding(bottom = 3.dp),
                )
            }
            Spacer(Modifier.height(12.dp))
            // Seven bars, one per night. Intensity carries whether that night
            // was spoken and how it read — a night with nothing stays palest.
            val today = System.currentTimeMillis() / 86_400_000L
            val byDay = entries.groupBy { it.createdAt / 86_400_000L }
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                (6 downTo 0).forEach { back ->
                    val e = byDay[today - back]?.firstOrNull()
                    Box(
                        Modifier
                            .weight(1f)
                            .height(6.dp)
                            .clip(RoundedCornerShape(3.dp))
                            .background(
                                // valenceColor, not a gold ramp. The previous
                                // low-night colour was DayGoldText at 75% — a
                                // dark brown that read as mud against the golds
                                // beside it, and as a rendering fault rather
                                // than a bad day.
                                when (e) {
                                    null -> Gold.copy(alpha = 0.18f)
                                    else -> valenceColor(e.valence)
                                        .copy(alpha = 0.5f + (e.valence + 1f) / 2f * 0.5f)
                                }
                            )
                    )
                }
            }
            Spacer(Modifier.height(11.dp))
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                MonoLabel("longest $streak")
                MonoLabel("this month ${entries.count {
                    it.createdAt > System.currentTimeMillis() - 30L * 86_400_000
                }}")
                MonoLabel("total ${entries.size}")
            }
        }

        // Weekly goal, only once the user has asked for one. An always-present
        // progress bar would turn a journal into a habit tracker for everybody,
        // which is the opposite of what the empty states promise.
        if (com.dailyvox.app.system.Goals.isEnabled(context)) {
            val target = com.dailyvox.app.system.Goals.target(context)
            val nights = remember(entries) { com.dailyvox.app.system.Goals.nightsThisWeek(entries) }
            val met = nights >= target
            val left = com.dailyvox.app.system.Goals.daysLeftInWeek()
            Spacer(Modifier.height(12.dp))
            DvCard {
                Row(
                    Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.Bottom,
                ) {
                    Text("$nights of $target", fontSize = 20.sp,
                         fontWeight = FontWeight.ExtraBold, color = goldText)
                    MonoLabel(
                        // Never "you are behind". The only number the app will
                        // put next to a miss is how much week is left.
                        if (met) "this week" else "$left ${if (left == 1) "day" else "days"} left"
                    )
                }
                Spacer(Modifier.height(9.dp))
                Row(
                    Modifier.fillMaxWidth().height(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.16f))
                ) {
                    val filled = (nights.toFloat() / target).coerceIn(0f, 1f)
                    if (filled > 0f) {
                        Box(
                            Modifier.fillMaxHeight().fillMaxWidth(filled)
                                .background(com.dailyvox.app.ui.theme.Gold)
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    if (met) "That is your week. Anything else is extra."
                    else "Nights, not entries — one evening counts once.",
                    fontSize = 12.sp, lineHeight = 18.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        MonoLabel("Last 30 nights")
        Spacer(Modifier.height(4.dp))
        Text("Brighter stars were better days. Tonight is waiting.",
             fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(10.dp))
        NightStrip(entries)

        Spacer(Modifier.height(20.dp))
        DvCard {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                MonoLabel("Mood · last 14 days")
                // The design puts a delta beside this label. Stated against the
                // fortnight before, so it answers "compared to what" without the
                // reader having to guess.
                val cutoff = System.currentTimeMillis() - 14L * 86_400_000
                val recent = entries.filter { it.createdAt >= cutoff }
                val prior = entries.filter {
                    it.createdAt < cutoff && it.createdAt >= cutoff - 14L * 86_400_000
                }
                if (recent.size >= 3 && prior.size >= 3) {
                    val d = recent.map { it.valence }.average() - prior.map { it.valence }.average()
                    Text(
                        "%s %+.1f".format(if (d >= 0) "\u25B2" else "\u25BC", d),
                        fontSize = 11.sp, fontWeight = FontWeight.Bold,
                        color = if (d >= 0) goldText else MaterialTheme.colorScheme.error,
                    )
                }
            }
            Spacer(Modifier.height(10.dp))
            MoodCurve(entries)
        }

        Spacer(Modifier.height(24.dp))
        MonoLabel("Patterns your Twin noticed")
        Spacer(Modifier.height(10.dp))
        val patterns = Insights.find(entries.map { it.toChatEntry() })
        if (patterns.isEmpty()) {
            DvCard {
                Text(
                    "Not enough yet. Patterns appear once there is enough to be sure one is real rather than a coincidence.",
                    fontSize = 14.sp, lineHeight = 22.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                patterns.forEach { p ->
                    DvCard {
                        Row(verticalAlignment = Alignment.Top) {
                            Box(
                                Modifier.size(28.dp)
                                    .clip(RoundedCornerShape(9.dp))
                                    .background(Gold.copy(alpha = 0.16f)),
                                contentAlignment = Alignment.Center,
                            ) {
                                Text("\u2726", fontSize = 13.sp, color = goldText)
                            }
                            Spacer(Modifier.width(11.dp))
                            Column {
                                Text(p.lead, fontSize = 14.sp, lineHeight = 21.sp,
                                     fontWeight = FontWeight.Bold,
                                     color = MaterialTheme.colorScheme.onSurface)
                                Spacer(Modifier.height(2.dp))
                                Text(p.detail, fontSize = 13.sp, lineHeight = 20.sp,
                                     color = MaterialTheme.colorScheme.onSurfaceVariant)
                            }
                        }
                    }
                }
            }
        }
        Spacer(Modifier.height(130.dp))
    }
}

@Composable
private fun Stat(label: String, value: String, sub: String, modifier: Modifier = Modifier) {
    Column(
        modifier.clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(14.dp)
    ) {
        MonoLabel(label)
        Spacer(Modifier.height(6.dp))
        Text(value, style = MaterialTheme.typography.headlineSmall,
             color = MaterialTheme.colorScheme.onSurface)
        Text(sub, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** One dot per night. Filled and bright means an entry with positive valence;
 *  hollow means a night with nothing, including tonight. No guilt copy — the
 *  absence is shown, never scolded. */
@Composable
private fun NightStrip(entries: List<Entry>) {
    val today = System.currentTimeMillis() / 86_400_000L
    val byDay = entries.groupBy { it.createdAt / 86_400_000L }
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        (29 downTo 0).forEach { back ->
            val day = today - back
            val e = byDay[day]?.firstOrNull()
            Box(
                Modifier
                    .weight(1f)
                    .aspectRatio(1f)
                    .clip(CircleShape)
                    .background(
                        when {
                            e == null -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.16f)
                            else -> valenceColor(e.valence).copy(alpha = 0.45f + (e.valence + 1f) / 2f * 0.55f)
                        }
                    )
            )
        }
    }
}

/** 14-day valence line. Drawn rather than charted — one path, no dependency. */
@Composable
private fun MoodCurve(entries: List<Entry>) {
    val today = System.currentTimeMillis() / 86_400_000L
    val byDay = entries.groupBy { it.createdAt / 86_400_000L }
    val points = (13 downTo 0).map { back ->
        byDay[today - back]?.map { it.valence }?.average()?.toFloat()
    }
    val known = points.filterNotNull()
    if (known.size < 2) {
        Text("A curve needs a few more days.", fontSize = 13.sp,
             color = MaterialTheme.colorScheme.onSurfaceVariant)
        return
    }
    val accent = MaterialTheme.colorScheme.secondary
    Canvas(Modifier.fillMaxWidth().height(120.dp)) {
        val w = size.width; val h = size.height
        // Carry the last known value across gaps so the line stays continuous —
        // a broken line reads as missing data rather than a quiet day.
        var last = known.first()
        val ys = points.map { v -> (v ?: last).also { last = v ?: last } }
        fun px(i: Int) = w * i / (ys.size - 1f)
        fun py(v: Float) = h - ((v + 1f) / 2f) * h * 0.86f - h * 0.07f

        val line = Path().apply {
            moveTo(px(0), py(ys[0]))
            ys.forEachIndexed { i, v -> if (i > 0) lineTo(px(i), py(v)) }
        }
        val fill = Path().apply {
            addPath(line); lineTo(px(ys.size - 1), h); lineTo(0f, h); close()
        }
        drawPath(fill, Brush.verticalGradient(listOf(accent.copy(alpha = 0.22f), Color.Transparent)))
        drawPath(line, accent, style = androidx.compose.ui.graphics.drawscope.Stroke(2.5f))
        drawLine(MaterialTheme.run { accent.copy(alpha = 0.18f) },
                 Offset(0f, py(0f)), Offset(w, py(0f)), strokeWidth = 1f)
        ys.forEachIndexed { i, v -> drawCircle(accent, radius = 2.5f, center = Offset(px(i), py(v))) }
    }
}

/**
 * Patterns, each gated on enough support to be worth stating. The thresholds are
 * deliberately conservative: it is better to show nothing than to tell someone
 * something about themselves that the data does not carry.
 */
