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
import com.dailyvox.app.R
import androidx.compose.foundation.layout.ExperimentalLayoutApi
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import java.util.*
import kotlin.math.abs

/**
 * "Your Twin noticed": the engine's findings over every entry, each read in
 * its own language (B-5). The engine leaves out every valence the gate cannot
 * read (SENTIMENT: English on Android), and [toChatEntry] drops people from
 * entries whose names cannot be read (German, caseless scripts), so neither a
 * valence finding nor "X lifts you" can be built from a misreading. An English
 * journal gets exactly the findings it got in 1.2.1, which filtered to read
 * valences here; the engine now does that filtering itself.
 */
internal fun noticedPatterns(entries: List<Entry>): List<Insights.Finding> =
    Insights.find(entries.map { it.toChatEntry() })

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
@OptIn(ExperimentalFoundationApi::class, ExperimentalLayoutApi::class)
@Composable
fun InsightsScreen(
    entries: List<Entry>,
    streak: com.dailyvox.app.system.Streak.State,
    onBack: () -> Unit = {},
    onShareMilestone: () -> Unit = {},
    /** Last full week, counted from its entries. Null when it had none. */
    recap: com.dailyvox.app.system.Resurface.Recap? = null,
    onOpenEntry: (Entry) -> Unit = {},
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
        ScreenTitle(stringResource(R.string.insights_title), onBack = onBack)

        // The weekly recap lives here every day of the week, and on Today
        // only on recap day.
        recap?.let {
            val n = MaterialTheme.colorScheme.background == com.dailyvox.app.ui.theme.NightBackground
            com.dailyvox.app.ui.components.RecapCard(
                it,
                if (n) com.dailyvox.app.ui.theme.NightGoldText else com.dailyvox.app.ui.theme.DayGoldText,
                onOpenEntry,
            )
            Spacer(Modifier.height(12.dp))
        }

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
        val zone = remember { java.time.ZoneId.systemDefault() }
        val today = com.dailyvox.app.system.Streak.localDay(System.currentTimeMillis(), zone)
        val byDay = remember(entries, zone) {
            entries.groupBy { com.dailyvox.app.system.Streak.localDay(it.createdAt, zone) }
        }
        val streakDescription = when (streak.kind) {
            com.dailyvox.app.system.Streak.Kind.ACTIVE -> pluralStringResource(
                R.plurals.streak_description_active, streak.current,
                streak.current, streak.longest, streak.daysSpoken)
            com.dailyvox.app.system.Streak.Kind.RETURNING -> pluralStringResource(
                R.plurals.streak_description_returning, streak.daysSpoken, streak.longest, streak.daysSpoken)
            com.dailyvox.app.system.Streak.Kind.NEW -> stringResource(R.string.streak_description_new)
        }
        DvCard(
            // §F: the streak card is the milestone, so long-pressing it opens
            // the stamp. Nothing is minted here -- the card only exists once
            // the nights do.
            Modifier
                .combinedClickable(onClick = {}, onLongClick = onShareMilestone)
                .semantics(mergeDescendants = true) { contentDescription = streakDescription }
        ) {
            if (streak.kind == com.dailyvox.app.system.Streak.Kind.RETURNING) {
                // Welcome back, never a zero. What they kept is right below it.
                Text(
                    stringResource(R.string.streak_welcome_back),
                    fontFamily = com.dailyvox.app.ui.theme.Nunito, fontSize = 20.sp, lineHeight = 26.sp,
                    fontWeight = FontWeight.ExtraBold, color = goldText,
                )
            } else {
                Row(verticalAlignment = Alignment.Bottom) {
                    Text("${streak.current}", fontFamily = com.dailyvox.app.ui.theme.Nunito, fontSize = 40.sp, fontWeight = FontWeight.ExtraBold,
                         color = goldText)
                    Spacer(Modifier.width(8.dp))
                    Text(
                        when {
                            streak.kind == com.dailyvox.app.system.Streak.Kind.NEW ->
                                stringResource(R.string.streak_none_yet)
                            // Only called the longest when it is.
                            streak.current >= streak.longest -> pluralStringResource(
                                R.plurals.streak_days_in_a_row_longest, streak.current)
                            else -> pluralStringResource(R.plurals.streak_days_in_a_row, streak.current)
                        },
                        fontSize = 13.sp, fontWeight = FontWeight.Bold,
                        color = MaterialTheme.colorScheme.onSurfaceVariant,
                        modifier = Modifier.padding(bottom = 3.dp),
                    )
                }
            }
            Spacer(Modifier.height(12.dp))
            // Seven bars, one per night. Intensity carries whether that night
            // was spoken and how it read — a night with nothing stays palest.
            // Local days, the same ones the streak counts.
            Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                (6 downTo 0).forEach { back ->
                    val e = byDay[today.minusDays(back.toLong())]?.firstOrNull()
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
                                        .copy(alpha = 0.5f + ((e.valence ?: 0f) + 1f) / 2f * 0.5f)
                                }
                            )
                    )
                }
            }
            Spacer(Modifier.height(11.dp))
            // A flow rather than a fixed row, so the labels wrap instead of
            // colliding at the largest font sizes.
            FlowRow(
                Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                MonoLabel(stringResource(R.string.streak_longest, streak.longest))
                MonoLabel(stringResource(R.string.streak_days_spoken, streak.daysSpoken))
                MonoLabel(stringResource(R.string.streak_this_month, entries.count {
                    it.createdAt > System.currentTimeMillis() - 30L * 86_400_000
                }))
                MonoLabel(stringResource(R.string.streak_total, entries.size))
            }
            if (streak.kind != com.dailyvox.app.system.Streak.Kind.NEW) {
                Spacer(Modifier.height(8.dp))
                // The grace rule, stated once, where the number is.
                Text(
                    stringResource(R.string.streak_grace_rule),
                    fontSize = 12.sp, lineHeight = 18.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
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
                    Text(stringResource(R.string.goal_progress, nights, target), fontFamily = com.dailyvox.app.ui.theme.Nunito, fontSize = 20.sp,
                         fontWeight = FontWeight.ExtraBold, color = goldText)
                    MonoLabel(
                        // Never "you are behind". The only number the app will
                        // put next to a miss is how much week is left.
                        if (met) stringResource(R.string.goal_this_week) else pluralStringResource(R.plurals.goal_days_left, left, left)
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
                    stringResource(if (met) R.string.goal_met_note else R.string.goal_counting_note),
                    fontSize = 12.sp, lineHeight = 18.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        }

        Spacer(Modifier.height(20.dp))
        MonoLabel(stringResource(R.string.insights_last_30))
        Spacer(Modifier.height(4.dp))
        Text(stringResource(R.string.insights_last_30_note),
             fontSize = 12.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(10.dp))
        NightStrip(entries)

        Spacer(Modifier.height(20.dp))
        DvCard {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically) {
                MonoLabel(stringResource(R.string.insights_mood_14))
                // The design puts a delta beside this label. Stated against the
                // fortnight before, so it answers "compared to what" without the
                // reader having to guess.
                val cutoff = System.currentTimeMillis() - 14L * 86_400_000
                // Unread entries (null valence, or a language the gate does not
                // read for SENTIMENT) are left out, not averaged in as 0.
                val recent = entries.filter { it.createdAt >= cutoff }
                    .mapNotNull { com.dailyvox.app.system.ReadingLanguage.valence(it) }
                val prior = entries.filter {
                    it.createdAt < cutoff && it.createdAt >= cutoff - 14L * 86_400_000
                }.mapNotNull { com.dailyvox.app.system.ReadingLanguage.valence(it) }
                if (recent.size >= 3 && prior.size >= 3) {
                    val d = recent.average() - prior.average()
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
        val patterns = noticedPatterns(entries)
        // Week one. Below the patterns threshold, early signals take the
        // place of "not enough yet"; from it on they give way to the real
        // patterns (EarlySignals.kt).
        val early = remember(entries, zone) { com.dailyvox.app.system.EarlySignals.of(entries, zone) }
        if (early != null) {
            EarlySignalsCard(early, EarlySignalsColors.day(goldText))
        } else if (patterns.isEmpty()) {
            MonoLabel(stringResource(R.string.patterns_label))
            Spacer(Modifier.height(10.dp))
            DvCard {
                Text(
                    stringResource(
                        if (entries.size < com.dailyvox.app.system.EarlySignals.MIN_ENTRIES)
                            R.string.patterns_not_enough_early
                        else R.string.patterns_not_enough
                    ),
                    fontSize = 14.sp, lineHeight = 22.sp,
                    color = MaterialTheme.colorScheme.onSurfaceVariant,
                )
            }
        } else {
            MonoLabel(stringResource(R.string.patterns_label))
            Spacer(Modifier.height(10.dp))
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
    val zone = java.time.ZoneId.systemDefault()
    val today = com.dailyvox.app.system.Streak.localDay(System.currentTimeMillis(), zone)
    val byDay = entries.groupBy { com.dailyvox.app.system.Streak.localDay(it.createdAt, zone) }
    Row(
        Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        (29 downTo 0).forEach { back ->
            val e = byDay[today.minusDays(back.toLong())]?.firstOrNull()
            Box(
                Modifier
                    .weight(1f)
                    .aspectRatio(1f)
                    .clip(CircleShape)
                    .background(
                        when {
                            e == null -> MaterialTheme.colorScheme.onSurfaceVariant.copy(alpha = 0.16f)
                            else -> valenceColor(e.valence).copy(alpha = 0.45f + ((e.valence ?: 0f) + 1f) / 2f * 0.55f)
                        }
                    )
            )
        }
    }
}

/** 14-day valence line. Drawn rather than charted — one path, no dependency. */
@Composable
private fun MoodCurve(entries: List<Entry>) {
    val zone = java.time.ZoneId.systemDefault()
    val today = com.dailyvox.app.system.Streak.localDay(System.currentTimeMillis(), zone)
    val byDay = entries.groupBy { com.dailyvox.app.system.Streak.localDay(it.createdAt, zone) }
    val points = (13 downTo 0).map { back ->
        byDay[today.minusDays(back.toLong())]?.mapNotNull { com.dailyvox.app.system.ReadingLanguage.valence(it) }?.takeIf { it.isNotEmpty() }?.average()?.toFloat()
    }
    val known = points.filterNotNull()
    if (known.size < 2) {
        Text(stringResource(R.string.insights_curve_not_enough), fontSize = 13.sp,
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
