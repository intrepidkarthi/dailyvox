package com.dailyvox.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.ui.theme.*

/**
 * Cards are hairline-on-white in Light and tonal-no-border in Dark. That split is
 * from the design spec and it is not arbitrary: a drop shadow on cream reads as
 * grey smudge, so Light gets a 1px border instead and Dark gets a lifted surface.
 */
@Composable
fun DvCard(modifier: Modifier = Modifier, content: @Composable ColumnScope.() -> Unit) {
    val dark = MaterialTheme.colorScheme.background == NightBackground
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(MaterialTheme.colorScheme.surface)
            .then(if (dark) Modifier else Modifier.border(1.dp, DayTextSecondary, RoundedCornerShape(24.dp)))
            .padding(18.dp),
        content = content,
    )
}

/** Entity chip — the name the detector found, shown so the user can see what was filed. */
@Composable
fun Chip(text: String, tint: Color = MaterialTheme.colorScheme.secondary) {
    Text(
        text,
        fontSize = 12.sp,
        color = tint,
        modifier = Modifier
            .clip(RoundedCornerShape(10.dp))
            .background(tint.copy(alpha = 0.14f))
            .padding(horizontal = 10.dp, vertical = 5.dp),
    )
}

/** Valence dot. Gold above +0.3, sage above 0, cool blue above -0.3, else coral —
 *  the same four thresholds the iOS constellation uses, so a star and its entry
 *  can never disagree about mood. */
@Composable
fun ValenceDot(valence: Float, size: Int = 8) {
    Box(
        Modifier
            .size(size.dp)
            .clip(CircleShape)
            .background(valenceColor(valence))
    )
}

fun valenceColor(v: Float): Color = when {
    v > 0.3f -> StarGold
    v > 0f -> Color(0xFF6B9E7B)
    v > -0.3f -> Color(0xFF7BA4C7)
    else -> Color(0xFFC4736B)
}

/** Uppercase mono label — the design's DM Mono data-label role. */
@Composable
fun MonoLabel(text: String, modifier: Modifier = Modifier) {
    Text(
        text.uppercase(),
        fontSize = 10.sp,
        letterSpacing = 1.2.sp,
        fontWeight = FontWeight.Medium,
        color = MaterialTheme.colorScheme.onSurfaceVariant,
        modifier = modifier,
    )
}

@Composable
fun ScreenTitle(
    text: String,
    onBack: (() -> Unit)? = null,
    trailing: (@Composable () -> Unit)? = null,
) {
    Row(
        Modifier.fillMaxWidth().padding(bottom = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            // Inline, next to the title. The earlier version floated a pill over
            // the bottom of the screen, which on a scrolling settings page sat
            // directly on top of "Export as PDF" -- a back control that hides a
            // real one is worse than no chrome at all.
            if (onBack != null) {
                Text(
                    "\u2039", fontSize = 30.sp,
                    color = MaterialTheme.colorScheme.onBackground,
                    modifier = Modifier
                        .clip(CircleShape)
                        .clickable(onClick = onBack)
                        .defaultMinSize(48.dp, 48.dp)
                        .wrapContentSize(),
                )
                Spacer(Modifier.width(4.dp))
            }
            Text(text, fontSize = 30.sp, fontWeight = FontWeight.Bold,
                 color = MaterialTheme.colorScheme.onBackground)
        }
        trailing?.invoke()
    }
}

/**
 * Empty state. There is one rule here and the whole product's tone rests on it:
 * NO GUILT. A journal that greets a missed night with "you broke your streak"
 * teaches people to avoid opening it, which is precisely the retention failure
 * this app already measures. Every string below states the absence and offers
 * the next action, and none of them scold.
 */
@Composable
fun EmptyState(
    headline: String,
    body: String,
    action: String? = null,
    onAction: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    Column(
        modifier.fillMaxWidth().padding(horizontal = 28.dp, vertical = 48.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        // The hollow star: the same mark the widget uses for a night not yet
        // spoken, so absence looks identical everywhere in the product.
        androidx.compose.foundation.Canvas(Modifier.size(46.dp)) {
            val r = size.minDimension / 2f
            val path = androidx.compose.ui.graphics.Path().apply {
                moveTo(center.x, center.y - r)
                cubicTo(center.x + r * .1f, center.y - r * .35f, center.x + r * .35f, center.y - r * .1f, center.x + r, center.y)
                cubicTo(center.x + r * .35f, center.y + r * .1f, center.x + r * .1f, center.y + r * .35f, center.x, center.y + r)
                cubicTo(center.x - r * .1f, center.y + r * .35f, center.x - r * .35f, center.y + r * .1f, center.x - r, center.y)
                cubicTo(center.x - r * .35f, center.y - r * .1f, center.x - r * .1f, center.y - r * .35f, center.x, center.y - r)
                close()
            }
            drawPath(path, StarGold.copy(alpha = 0.4f),
                     style = androidx.compose.ui.graphics.drawscope.Stroke(1.4.dp.toPx()))
        }
        Spacer(Modifier.height(18.dp))
        Text(headline, style = MaterialTheme.typography.titleMedium,
             color = MaterialTheme.colorScheme.onBackground,
             textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        Spacer(Modifier.height(8.dp))
        Text(body, fontSize = 14.sp, lineHeight = 21.sp,
             color = MaterialTheme.colorScheme.onSurfaceVariant,
             textAlign = androidx.compose.ui.text.style.TextAlign.Center)
        if (action != null && onAction != null) {
            Spacer(Modifier.height(20.dp))
            Text(
                action,
                fontSize = 14.sp, fontWeight = FontWeight.SemiBold,
                color = MaterialTheme.colorScheme.onPrimary,
                modifier = Modifier
                    .clip(RoundedCornerShape(16.dp))
                    .background(MaterialTheme.colorScheme.primary)
                    .clickable(onClick = onAction)
                    .padding(horizontal = 24.dp, vertical = 13.dp),
            )
        }
    }
}
