package com.dailyvox.app.ui.screens

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
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
@Composable
fun InsightsScreen(
    entries: List<Entry>,
    streak: Int,
    onBack: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
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
        DvCard {
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
        val patterns = Patterns.find(entries)
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
/** One finding: a short lead, the numbers behind it, and how big the effect is. */
internal data class Pattern(val lead: String, val detail: String, val effect: Double)

/**
 * Patterns, each gated on enough support to be worth stating. The thresholds are
 * deliberately conservative: it is better to show nothing than to tell someone
 * something about themselves that the data does not carry.
 *
 * Findings are ranked by effect size and the day-of-week family is capped at
 * two. Before that, `out.take(4)` returned whatever was appended first, and
 * weekdays are appended first and can produce seven — so the sleep, person and
 * voice findings, which are the ones only this app can make, were computed
 * every time and never once shown.
 */
internal object Patterns {
    private const val DOW_CAP = 2

    fun find(entries: List<Entry>): List<Pattern> {
        if (entries.size < 8) return emptyList()
        val dow = mutableListOf<Pattern>()
        val out = mutableListOf<Pattern>()

        val cal = Calendar.getInstance()
        val byDow = entries.groupBy { e ->
            cal.timeInMillis = e.createdAt; cal.get(Calendar.DAY_OF_WEEK)
        }
        val overall = entries.map { it.valence }.average()
        byDow.filter { it.value.size >= 3 }.forEach { (d, es) ->
            val v = es.map { it.valence }.average()
            if (abs(v - overall) > 0.22) {
                val name = SimpleNames.dow(d)
                dow += Pattern(
                    if (v < overall) "${name}s run low." else "${name}s run high.",
                    "%+.2f against your %+.2f average, across %d entries.".format(v, overall, es.size),
                    abs(v - overall),
                )
            }
        }
        out += dow.sortedByDescending { it.effect }.take(DOW_CAP)

        // Person effect: needs 3+ entries mentioning them.
        entries.flatMap { it.entityList }.groupingBy { it }.eachCount()
            .filter { it.value >= 3 }
            .forEach { (name, n) ->
                val v = entries.filter { name in it.entityList }.map { it.valence }.average()
                if (v - overall > 0.2)
                    out += Pattern(
                        "$name lifts you.",
                        "Entries mentioning them average %+.2f against your %+.2f overall, across %d of them."
                            .format(v, overall, n),
                        v - overall,
                    )
            }

        // Sleep effect: needs 3 nights on each side of 7 hours.
        val withSleep = entries.filter { it.sleepHours != null }
        val good = withSleep.filter { it.sleepHours!! >= 7f }
        val poor = withSleep.filter { it.sleepHours!! < 7f }
        if (good.size >= 3 && poor.size >= 3) {
            val gv = good.map { it.valence }.average(); val pv = poor.map { it.valence }.average()
            if (abs(gv - pv) > 0.2)
                out += Pattern(
                    if (gv > pv) "Sleep shows up." else "Sleep runs the other way.",
                    "After seven or more hours you write %+.2f; under seven, %+.2f. %d nights either side."
                        .format(gv, pv, withSleep.size),
                    abs(gv - pv),
                )
        }

        // Steps effect. Same gate as the rest: 4 either side of the median, and
        // a difference big enough to be worth saying out loud.
        val withSteps = entries.filter { (it.stepsToday ?: 0) > 0 }
        if (withSteps.size >= 8) {
            val median = withSteps.map { it.stepsToday!! }.sorted()[withSteps.size / 2]
            val more = withSteps.filter { it.stepsToday!! > median }
            val less = withSteps.filter { it.stepsToday!! <= median }
            if (more.size >= 4 && less.size >= 4) {
                val mv = more.map { it.valence }.average()
                val lv = less.map { it.valence }.average()
                if (abs(mv - lv) > 0.2)
                    out += Pattern(
                        if (mv > lv) "Moving helps." else "Busy days cost you.",
                        "On your more active days you read %+.2f; on quieter ones, %+.2f. Across %d days."
                            .format(mv, lv, withSteps.size),
                        abs(mv - lv),
                    )
            }
        }

        // Voice effect: needs 4 entries with prosody on each side of the median.
        val withRate = entries.filter { (it.speakingRate ?: 0f) > 0f }
        if (withRate.size >= 8) {
            val rates = withRate.map { it.speakingRate!! }.sorted()
            val median = rates[rates.size / 2]
            val fast = withRate.filter { it.speakingRate!! > median }
            val slow = withRate.filter { it.speakingRate!! <= median }
            if (fast.size >= 4 && slow.size >= 4) {
                val fv = fast.map { it.valence }.average()
                val sv = slow.map { it.valence }.average()
                if (abs(fv - sv) > 0.2)
                    out += Pattern(
                        "Your pace tracks it.",
                        "When you speak faster you read %+.2f; slower, %+.2f. Across %d recordings."
                            .format(fv, sv, withRate.size),
                        abs(fv - sv),
                    )
            }
        }

        // Time-of-day effect, from stored ambient context rather than re-parsed
        // timestamps.
        val byPartOfDay = entries.filter { it.hourOfDay != null }.groupBy { e ->
            when (e.hourOfDay!!) {
                in 0..4 -> "the small hours"; in 5..11 -> "mornings"
                in 12..16 -> "afternoons"; in 17..21 -> "evenings"
                else -> "late nights"
            }
        }
        byPartOfDay.filter { it.value.size >= 4 }.forEach { (part, es) ->
            val v = es.map { it.valence }.average()
            if (abs(v - overall) > 0.22)
                out += Pattern(
                    "Your $part " + if (v > overall) "read warmer." else "read cooler.",
                    "%+.2f against your %+.2f overall, across %d entries.".format(v, overall, es.size),
                    abs(v - overall),
                )
        }

        return out.sortedByDescending { it.effect }.take(4)
    }
}

internal object SimpleNames {
    fun dow(c: Int) = when (c) {
        Calendar.MONDAY -> "Monday"; Calendar.TUESDAY -> "Tuesday"
        Calendar.WEDNESDAY -> "Wednesday"; Calendar.THURSDAY -> "Thursday"
        Calendar.FRIDAY -> "Friday"; Calendar.SATURDAY -> "Saturday"
        else -> "Sunday"
    }
}
