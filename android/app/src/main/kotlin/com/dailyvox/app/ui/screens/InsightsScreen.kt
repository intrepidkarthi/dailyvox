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

        Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            Stat("Streak", "$streak", "days", Modifier.weight(1f))
            Stat("This week", "${week.size}", "entries", Modifier.weight(1f))
            val delta = if (prior.isEmpty()) null else week.size - prior.size
            Stat("vs last", delta?.let { "${if (it >= 0) "+" else ""}$it" } ?: "—", "entries", Modifier.weight(1f))
        }

        Spacer(Modifier.height(20.dp))
        MonoLabel("Last 30 nights")
        Spacer(Modifier.height(4.dp))
        Text("Brighter stars were better days. Tonight is waiting.",
             fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(10.dp))
        NightStrip(entries)

        Spacer(Modifier.height(24.dp))
        MonoLabel("Mood · last 14 days")
        Spacer(Modifier.height(10.dp))
        MoodCurve(entries)

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
                        Text(p, fontSize = 14.sp, lineHeight = 22.sp,
                             color = MaterialTheme.colorScheme.onSurface)
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
private object Patterns {
    fun find(entries: List<Entry>): List<String> {
        if (entries.size < 8) return emptyList()
        val out = mutableListOf<String>()

        // Day-of-week effect: needs 3+ entries on the day and a real gap.
        val cal = Calendar.getInstance()
        val byDow = entries.groupBy { e ->
            cal.timeInMillis = e.createdAt; cal.get(Calendar.DAY_OF_WEEK)
        }
        val overall = entries.map { it.valence }.average()
        byDow.filter { it.value.size >= 3 }.forEach { (dow, es) ->
            val v = es.map { it.valence }.average()
            if (abs(v - overall) > 0.22) {
                val name = SimpleNames.dow(dow)
                out += if (v < overall)
                    "%ss read lower than your average — %+.2f against %+.2f, across %d entries.".format(name, v, overall, es.size)
                else
                    "%ss read higher than your average — %+.2f against %+.2f, across %d entries.".format(name, v, overall, es.size)
            }
        }

        // Person effect: needs 3+ entries mentioning them.
        entries.flatMap { it.entityList }.groupingBy { it }.eachCount()
            .filter { it.value >= 3 }
            .forEach { (name, n) ->
                val v = entries.filter { name in it.entityList }.map { it.valence }.average()
                if (v - overall > 0.2)
                    out += "Entries mentioning $name average %+.2f, above your %+.2f overall — across %d of them.".format(v, overall, n)
            }

        // Sleep effect: needs 3 nights on each side of 7 hours.
        val withSleep = entries.filter { it.sleepHours != null }
        val good = withSleep.filter { it.sleepHours!! >= 7f }
        val poor = withSleep.filter { it.sleepHours!! < 7f }
        if (good.size >= 3 && poor.size >= 3) {
            val gv = good.map { it.valence }.average(); val pv = poor.map { it.valence }.average()
            if (abs(gv - pv) > 0.2)
                out += "After seven or more hours you write %+.2f; under seven, %+.2f. %d nights either side.".format(gv, pv, withSleep.size)
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
                    out += "When you speak faster you read %+.2f; slower, %+.2f. Across %d recordings.".format(fv, sv, withRate.size)
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
                out += "Your %s read %+.2f against your %+.2f overall, across %d entries.".format(part, v, overall, es.size)
        }

        return out.take(4)
    }
}

private object SimpleNames {
    fun dow(c: Int) = when (c) {
        Calendar.MONDAY -> "Monday"; Calendar.TUESDAY -> "Tuesday"
        Calendar.WEDNESDAY -> "Wednesday"; Calendar.THURSDAY -> "Thursday"
        Calendar.FRIDAY -> "Friday"; Calendar.SATURDAY -> "Saturday"
        else -> "Sunday"
    }
}
