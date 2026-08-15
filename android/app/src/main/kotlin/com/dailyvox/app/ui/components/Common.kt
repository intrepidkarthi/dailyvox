package com.dailyvox.app.ui.components

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
    val dark = MaterialTheme.colorScheme.background == DarkBackground
    Column(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(24.dp))
            .background(MaterialTheme.colorScheme.surface)
            .then(if (dark) Modifier else Modifier.border(1.dp, LightOutline, RoundedCornerShape(24.dp)))
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
fun ScreenTitle(text: String, trailing: (@Composable () -> Unit)? = null) {
    Row(
        Modifier.fillMaxWidth().padding(bottom = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(text, fontSize = 30.sp, fontWeight = FontWeight.Bold,
             color = MaterialTheme.colorScheme.onBackground)
        trailing?.invoke()
    }
}
