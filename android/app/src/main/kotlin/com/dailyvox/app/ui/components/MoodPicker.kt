package com.dailyvox.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.semantics.stateDescription
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.R
import com.dailyvox.app.system.SelfLabels

/** The word the picker shows for a stored label, or the label itself (calm, tired). */
fun moodWord(label: String): String {
    val key = SelfLabels.canonical(label) ?: label
    return SelfLabels.CANON.firstOrNull { it.first == key }?.second ?: label
}

/**
 * The mood picker: the preregistered canon, worded as on iOS (SelfLabels).
 * One picker for the entry page and the reflection card, so the two cannot
 * drift into offering different words.
 *
 * Three looks, and they must stay distinct. The user's own label is a filled
 * chip; tapping it again clears it. The app's suggestion is an OUTLINED chip
 * marked "suggested" -- never filled, because a filled chip reads as a choice
 * the user made, and they did not make this one. Tapping it keeps it. Every
 * other chip is plain.
 *
 * A label saved under the old Android set is shown on its canon chip when it
 * has one (sad lights Sadness); calm and tired have none, so they keep a chip
 * of their own, as they were, until the user picks something else or clears it.
 */
@Composable
fun MoodPicker(
    current: String?,
    suggested: String?,
    onPick: (String?) -> Unit,
    modifier: Modifier = Modifier,
) {
    val selected = SelfLabels.canonical(current) ?: current
    // A suggestion only shows while there is no choice. Once the user has
    // picked, theirs is the only mood on the entry.
    val hint = if (current == null) SelfLabels.canonical(suggested) else null
    val legacy = current?.takeIf { SelfLabels.canonical(it) == null }
    val chips = SelfLabels.CANON + listOfNotNull(legacy?.let { it to it })
    val scheme = MaterialTheme.colorScheme

    FlowRow(
        modifier,
        horizontalArrangement = Arrangement.spacedBy(8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        chips.forEach { (label, word) ->
            val on = label == selected
            val isHint = label == hint
            val text = if (isHint) stringResource(R.string.mood_chip_suggested, word) else word
            // TalkBack hears the word, then whose mood it is, then what a
            // double-tap will do. "Suggested" must be spoken, not only drawn.
            val state = when {
                on -> stringResource(R.string.mood_chip_state_chosen)
                isHint -> stringResource(R.string.mood_chip_state_suggested)
                else -> null
            }
            val action = stringResource(
                when {
                    on -> R.string.mood_chip_action_clear
                    isHint -> R.string.mood_chip_action_keep
                    else -> R.string.mood_chip_action_choose
                }
            )
            Text(
                text, fontSize = 15.sp,
                fontStyle = if (isHint) FontStyle.Italic else FontStyle.Normal,
                color = when {
                    on -> scheme.onPrimary
                    isHint -> scheme.onSurface
                    else -> scheme.onSurfaceVariant
                },
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(
                        when {
                            on -> scheme.secondary
                            isHint -> Color.Transparent
                            else -> scheme.surfaceVariant
                        }
                    )
                    .then(
                        if (isHint) Modifier.border(1.5.dp, scheme.secondary, RoundedCornerShape(12.dp))
                        else Modifier
                    )
                    // Tapping the chosen label again clears it. Nothing here is
                    // a commitment the user cannot take back.
                    .clickable(onClickLabel = action, role = Role.Button) {
                        onPick(if (on) null else label)
                    }
                    .semantics {
                        contentDescription = word
                        state?.let { stateDescription = it }
                    }
                    .defaultMinSize(minHeight = 44.dp)
                    .padding(horizontal = 14.dp, vertical = 12.dp),
            )
        }
    }
}
