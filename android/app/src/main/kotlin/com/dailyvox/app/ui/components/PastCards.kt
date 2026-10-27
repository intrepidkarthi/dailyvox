package com.dailyvox.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.pluralStringResource
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.R
import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Resurface
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle

/**
 * The user's own words from another day, quoted, with a tap through to the
 * entry. Calm on purpose: no counts, no "you haven't…", nothing to live up to.
 *
 * The quote goes through BidiFormatter, so a Hebrew or Arabic line inside the
 * English quote marks keeps its own direction instead of having its final
 * full stop thrown to the wrong end.
 *
 * TalkBack reads the card as one button: what it is, the quote, and that a
 * tap opens the entry.
 */
@Composable
fun PastCard(memory: Resurface.Memory, goldText: Color, onOpen: (Entry) -> Unit) {
    val label = when (memory.span) {
        Resurface.Span.DAYS ->
            if (memory.ago == 7) stringResource(R.string.past_week_ago)
            else pluralStringResource(R.plurals.past_days_ago, memory.ago, memory.ago)
        Resurface.Span.MONTHS -> pluralStringResource(R.plurals.past_months_ago, memory.ago, memory.ago)
        Resurface.Span.YEARS -> pluralStringResource(R.plurals.past_years_ago, memory.ago, memory.ago)
    }
    QuoteCard(label, memory.entry, memory.excerpt, goldText,
              stringResource(R.string.past_card_description, label, memory.excerpt), onOpen)
}

/**
 * The week, counted from its entries: how many, on how many days, a name only
 * when it really came up more than once, and one line in the user's words.
 */
@Composable
fun RecapCard(recap: Resurface.Recap, goldText: Color, onOpen: (Entry) -> Unit) {
    val scheme = MaterialTheme.colorScheme
    val fmt = DateTimeFormatter.ofLocalizedDate(FormatStyle.MEDIUM)
    val counts = pluralStringResource(R.plurals.recap_entries, recap.entries, recap.entries) + " " +
        pluralStringResource(R.plurals.recap_days, recap.daysSpoken, recap.daysSpoken)
    val name = recap.name?.let {
        pluralStringResource(R.plurals.recap_name, recap.nameEntries, bidi(it), recap.nameEntries)
    }
    val label = stringResource(R.string.recap_label)
    val range = stringResource(R.string.recap_range, recap.from.format(fmt), recap.to.format(fmt))
    val how = stringResource(R.string.recap_how_counted)
    val description = stringResource(R.string.recap_description, label, range, counts)

    Column(
        Modifier
            .fillMaxWidth()
            .widthIn(max = 460.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(scheme.surface)
            .padding(horizontal = 18.dp, vertical = 16.dp),
    ) {
        Column(Modifier.semantics(mergeDescendants = true) {
            contentDescription = listOfNotNull(description, name).joinToString(" ")
        }) {
            Text("✦ $label", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = goldText)
            Spacer(Modifier.height(4.dp))
            MonoLabel(range)
            Spacer(Modifier.height(10.dp))
            Text(counts, fontSize = 15.sp, lineHeight = 21.sp, color = scheme.onSurface)
            name?.let {
                Spacer(Modifier.height(6.dp))
                Text(it, fontSize = 15.sp, lineHeight = 21.sp, color = scheme.onSurface)
            }
        }
        recap.line?.let { line ->
            Spacer(Modifier.height(12.dp))
            val lineLabel = stringResource(R.string.recap_line_label)
            QuoteBody(
                lineLabel, line.entry, line.excerpt,
                stringResource(R.string.recap_line_description, line.excerpt), onOpen,
            )
        }
        Spacer(Modifier.height(10.dp))
        Text(how, fontSize = 12.sp, lineHeight = 17.sp, color = scheme.onSurfaceVariant)
    }
}

@Composable
private fun QuoteCard(
    label: String,
    entry: Entry,
    excerpt: String,
    goldText: Color,
    description: String,
    onOpen: (Entry) -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .widthIn(max = 460.dp)
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surface)
            .clickable { onOpen(entry) }
            .semantics(mergeDescendants = true) {
                role = Role.Button
                contentDescription = description
            }
            .padding(horizontal = 18.dp, vertical = 16.dp),
    ) {
        Text("✦ $label", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = goldText)
        Spacer(Modifier.height(4.dp))
        MonoLabel(entryDate(entry))
        Spacer(Modifier.height(10.dp))
        Quote(excerpt)
    }
}

/** The recap's line: same quote, its own touch target inside the card. */
@Composable
private fun QuoteBody(
    label: String,
    entry: Entry,
    excerpt: String,
    description: String,
    onOpen: (Entry) -> Unit,
) {
    Column(
        Modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(14.dp))
            .clickable { onOpen(entry) }
            .semantics(mergeDescendants = true) {
                role = Role.Button
                contentDescription = description
            }
            .defaultMinSize(minHeight = 48.dp)
            .padding(vertical = 4.dp),
    ) {
        Text(label, fontSize = 12.5.sp, fontWeight = FontWeight.SemiBold,
             color = MaterialTheme.colorScheme.onSurfaceVariant)
        Spacer(Modifier.height(3.dp))
        Quote(excerpt)
        Spacer(Modifier.height(3.dp))
        MonoLabel(entryDate(entry))
    }
}

@Composable
private fun Quote(excerpt: String) {
    Text(
        stringResource(R.string.past_quote, bidi(excerpt)),
        fontSize = 15.sp, lineHeight = 21.sp, fontStyle = FontStyle.Italic,
        color = MaterialTheme.colorScheme.onSurface,
    )
}

@Composable
private fun entryDate(entry: Entry): String {
    val locale = androidx.compose.ui.platform.LocalConfiguration.current.locales[0]
    return java.text.DateFormat.getDateInstance(java.text.DateFormat.MEDIUM, locale)
        .format(java.util.Date(entry.createdAt))
}

/** Wraps text whose direction may differ from the UI's, so it renders as written. */
fun bidi(text: String): String = androidx.core.text.BidiFormatter.getInstance().unicodeWrap(text)
