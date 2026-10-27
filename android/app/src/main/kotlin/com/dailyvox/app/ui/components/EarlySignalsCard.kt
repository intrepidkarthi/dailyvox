package com.dailyvox.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.R
import com.dailyvox.app.system.EarlySignals
import com.dailyvox.app.ui.theme.*

/** The card's colours: day ones on Insights, night ones under the sky. */
data class EarlySignalsColors(
    /** Null draws a [DvCard], which already knows its theme. */
    val surface: Color?,
    val text: Color,
    val secondary: Color,
    val accent: Color,
) {
    companion object {
        @Composable @ReadOnlyComposable
        fun day(accent: Color) = EarlySignalsColors(
            surface = null,
            text = MaterialTheme.colorScheme.onSurface,
            secondary = MaterialTheme.colorScheme.onSurfaceVariant,
            accent = accent,
        )

        /** The Twin tab is always night (§8.4), in both themes. */
        val night = EarlySignalsColors(NightSurface, NightText, NightTextSecondary, NightGoldText)
    }
}

/**
 * Week one's card (EarlySignals.kt). Labelled early in its heading and again
 * in its last line, so nobody reads three entries' worth of counting as the
 * Twin having worked them out.
 *
 * Every line is one sentence the user can check against their own journal.
 * A line with nothing under it is not drawn; if none has, the card says so
 * rather than reaching.
 */
@Composable
fun EarlySignalsCard(signals: EarlySignals.Signals, colors: EarlySignalsColors, modifier: Modifier = Modifier) {
    val lines = earlyLines(signals)
    val body: @Composable ColumnScope.() -> Unit = {
        Text(
            pluralStringResource(R.plurals.early_heading, signals.entries, signals.entries),
            fontFamily = Nunito, fontSize = 16.sp, lineHeight = 22.sp, fontWeight = FontWeight.ExtraBold,
            color = colors.accent,
            modifier = Modifier.semantics { heading() },
        )
        Spacer(Modifier.height(2.dp))
        Text(
            stringResource(R.string.early_firm_up),
            fontSize = 12.5.sp, lineHeight = 18.sp, color = colors.secondary,
        )
        Spacer(Modifier.height(10.dp))
        Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
            (lines.ifEmpty { listOf(stringResource(R.string.early_nothing_yet)) }).forEach { line ->
                Row {
                    Text("✦", fontSize = 12.sp, color = colors.accent,
                         modifier = Modifier.padding(top = 2.dp))
                    Spacer(Modifier.width(9.dp))
                    Text(line, fontSize = 14.sp, lineHeight = 21.sp, color = colors.text)
                }
            }
        }
        Spacer(Modifier.height(10.dp))
        Text(
            stringResource(R.string.early_counted_here),
            fontSize = 11.5.sp, lineHeight = 16.sp, color = colors.secondary,
        )
    }
    if (colors.surface == null) {
        DvCard(modifier, body)
    } else {
        Column(
            modifier.fillMaxWidth()
                .clip(RoundedCornerShape(20.dp))
                .background(colors.surface)
                .padding(horizontal = 16.dp, vertical = 14.dp),
            content = body,
        )
    }
}

@Composable
private fun earlyLines(s: EarlySignals.Signals): List<String> = buildList {
    s.timeOfDay?.let { t ->
        val part = stringResource(when (t.part) {
            EarlySignals.Part.SMALL_HOURS -> R.string.early_part_small_hours
            EarlySignals.Part.MORNING -> R.string.early_part_morning
            EarlySignals.Part.AFTERNOON -> R.string.early_part_afternoon
            EarlySignals.Part.EVENING -> R.string.early_part_evening
            EarlySignals.Part.LATE_NIGHT -> R.string.early_part_late_night
        })
        add(stringResource(R.string.early_time_of_day, part, t.count, t.of))
    }
    s.length?.let { l ->
        add(pluralStringResource(R.plurals.early_length_average, l.averageWords, l.averageWords))
        add(when (l.trend) {
            EarlySignals.Trend.STEADY -> stringResource(R.string.early_length_steady)
            EarlySignals.Trend.LONGER ->
                if (l.half == 1) stringResource(R.string.early_length_longer_one, l.later, l.earlier)
                else stringResource(R.string.early_length_longer_many, l.later, l.earlier, l.half)
            EarlySignals.Trend.SHORTER ->
                if (l.half == 1) stringResource(R.string.early_length_shorter_one, l.later, l.earlier)
                else stringResource(R.string.early_length_shorter_many, l.later, l.earlier, l.half)
        })
    }
    s.recurring.forEach { r ->
        add(pluralStringResource(R.plurals.early_recurring, r.entries, r.word, r.entries))
    }
    s.moods?.let { m ->
        val res = androidx.compose.ui.platform.LocalContext.current.resources
        fun list(counts: List<Pair<String, Int>>) =
            counts.joinToString(", ") { (k, n) -> res.getString(R.string.early_mood_count, moodWord(k), n) }
        if (m.chosen.isNotEmpty()) {
            add(stringResource(R.string.early_moods_chosen,
                list(m.chosen)))
        }
        // Suggestions are the app's reading, so they say so in the line itself.
        if (m.suggested.isNotEmpty()) {
            add(stringResource(R.string.early_moods_suggested,
                list(m.suggested)))
        }
    }
}
