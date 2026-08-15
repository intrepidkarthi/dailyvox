package com.dailyvox.app.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
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
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import com.dailyvox.app.ui.components.MonoLabel
import com.dailyvox.app.ui.components.valenceColor
import com.dailyvox.app.ui.theme.*
import kotlin.math.*

/**
 * The constellation. One entry, one star; the Twin is the breathing core.
 *
 * THE SKY IS ALWAYS NIGHT -- this surface stays dark in both themes. The
 * inversion is the point: it is what makes this screen feel like looking up, and
 * collapsing it into the system theme would delete the metaphor to satisfy a
 * convention nobody asked for.
 *
 * The layout PRNG is ported bit-for-bit from ConstellationView.swift:483-491
 * (splitmix, seed 42). Determinism is user-visible: the same journal must produce
 * the same sky on every device and every launch, or "this is *my* sky" is not
 * true. A different random source would look fine and be wrong.
 *
 * The glow is four stacked translucent circles, not a blur. That is both the look
 * and the cheap path -- RenderEffect would cost more and match less.
 */
@Composable
fun TwinScreen(entries: List<Entry>, resolution: Int, modifier: Modifier = Modifier) {
    val breath by rememberInfiniteTransition(label = "breath").animateFloat(
        initialValue = 0f, targetValue = (2 * PI).toFloat(),
        animationSpec = infiniteRepeatable(tween(9000, easing = LinearEasing)),
        label = "breathPhase",
    )

    // The sky is sized against the window, not fixed. At a flat 430dp it ate two
    // thirds of a 640dp-tall phone and pushed Mind/Heart/Body entirely below the
    // fold, so the screen read as a wallpaper with a nav bar on it.
    val skyHeight = androidx.compose.ui.platform.LocalConfiguration.current
        .screenHeightDp.dp.times(0.52f).coerceIn(280.dp, 430.dp)

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(skyHeight)
                .background(Brush.verticalGradient(listOf(SkyTop, SkyBottom)))
        ) {
            Canvas(Modifier.fillMaxSize()) { drawSky(entries, breath) }

            Row(
                Modifier.fillMaxWidth().padding(20.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Your Twin", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = DarkText)
                Text(
                    "$resolution%",
                    fontSize = 13.sp, fontWeight = FontWeight.Bold, color = DarkBackground,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(StarGold)
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                )
            }
            Text(
                "${entries.size} stars · your inner sky deepens",
                fontSize = 11.sp, color = DarkTextSecondary,
                modifier = Modifier.align(Alignment.BottomStart).padding(20.dp),
            )
        }

        Spacer(Modifier.height(18.dp))
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            val avgValence = entries.map { it.valence }.average().takeIf { !it.isNaN() } ?: 0.0
            val avgSleep = entries.mapNotNull { it.sleepHours }.average().takeIf { !it.isNaN() }
            DimensionCard("Mind", "%.2f".format(reflectionScore(entries)), "reflection", Modifier.weight(1f))
            DimensionCard("Heart", "%+.2f".format(avgValence), "valence", Modifier.weight(1f),
                          valueColor = valenceColor(avgValence.toFloat()))
            DimensionCard("Body", avgSleep?.let { "%.0fh%02d".format(floor(it), ((it % 1) * 60).toInt()) } ?: "—",
                          "slept", Modifier.weight(1f))
        }

        Spacer(Modifier.height(14.dp))
        val people = entries.flatMap { it.entityList }.groupingBy { it }.eachCount()
            .entries.sortedByDescending { it.value }.take(6)
        if (people.isNotEmpty()) {
            Column(Modifier.padding(horizontal = 20.dp)) {
                MonoLabel("Who your Twin knows")
                Spacer(Modifier.height(8.dp))
                people.forEach { (name, n) ->
                    Row(Modifier.fillMaxWidth().padding(vertical = 5.dp),
                        horizontalArrangement = Arrangement.SpaceBetween) {
                        Text(name, fontSize = 14.sp, color = MaterialTheme.colorScheme.onSurface)
                        MonoLabel("×$n")
                    }
                }
            }
        }
        Spacer(Modifier.height(130.dp))
    }
}

@Composable
private fun DimensionCard(
    label: String, value: String, sub: String,
    modifier: Modifier = Modifier,
    valueColor: Color = MaterialTheme.colorScheme.onSurface,
) {
    Column(
        modifier.clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surface)
            .padding(14.dp)
    ) {
        MonoLabel(label)
        Spacer(Modifier.height(6.dp))
        Text(value, fontSize = 22.sp, fontWeight = FontWeight.Bold, color = valueColor)
        Text(sub, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/** Type-token ratio over the corpus — the same "reflection" proxy iOS uses. */
private fun reflectionScore(entries: List<Entry>): Float {
    val words = entries.flatMap { it.text.lowercase().split(Regex("[^a-z']+")) }.filter { it.length > 2 }
    if (words.isEmpty()) return 0f
    return (words.toSet().size.toFloat() / words.size).coerceIn(0f, 1f)
}

// ── the sky ──────────────────────────────────────────────────────────────────

/** splitmix64, ported from ConstellationView.swift:483-491. Bit-for-bit. */
private fun hash(seed: Long): Float {
    var z = seed + -0x61c8864680b583ebL
    z = (z xor (z ushr 30)) * -0x40a7b892e31b1a47L
    z = (z xor (z ushr 27)) * -0x6b2fb644ecceee15L
    z = z xor (z ushr 31)
    return ((z ushr 11).toDouble() / (1L shl 53).toDouble()).toFloat()
}

private fun DrawScope.drawSky(entries: List<Entry>, breath: Float) {
    val w = size.width; val h = size.height
    val cx = w / 2f; val cy = h / 2f

    // Dust: 40 faint points, seeded so the sky is the same every launch.
    repeat(40) { i ->
        val x = hash(i * 7L + 1) * w
        val y = hash(i * 13L + 2) * h
        drawCircle(DarkText.copy(alpha = 0.05f + hash(i * 3L) * 0.05f), radius = 1.1f, center = Offset(x, y))
    }

    val maturity = min(1f, entries.size / 30f)
    val positions = entries.mapIndexed { i, e ->
        val a = hash(i * 2L + 42) * (2 * PI).toFloat()
        val rr = (0.15f + hash(i * 5L + 42).pow(0.7f) * 0.32f)
        val x = (0.5f + cos(a) * rr).coerceIn(0.08f, 0.92f) * w
        val y = (0.5f + sin(a) * rr).coerceIn(0.10f, 0.90f) * h
        Triple(Offset(x, y), e, 2.5f + hash(i * 11L) * 4.5f)
    }

    // Connections: nearest-neighbour threads, faint, so clusters read as shapes.
    positions.forEachIndexed { i, (p, _, _) ->
        positions.drop(i + 1).take(2).forEach { (q, _, _) ->
            val d = (p - q).getDistance()
            if (d < w * 0.34f) {
                drawLine(StarGold.copy(alpha = 0.13f), p, q, strokeWidth = 1f)
            }
        }
    }

    // Stars: four concentric passes per star. Not a blur — stacked alpha.
    positions.forEach { (p, e, base) ->
        val c = valenceColor(e.valence)
        val r = base * (0.55f + maturity * 0.45f)
        drawCircle(c.copy(alpha = 0.08f), radius = r * 4f, center = p)
        drawCircle(c.copy(alpha = 0.15f), radius = r * 2.2f, center = p)
        drawCircle(c.copy(alpha = 0.90f), radius = r, center = p)
        drawCircle(Color.White.copy(alpha = 0.70f), radius = r * 0.4f, center = p)
    }

    // The Twin: breathing core star, sage-gold, always at centre.
    val pulse = 1f + sin(breath) * 0.06f
    val core = 26f * pulse
    drawCircle(
        brush = Brush.radialGradient(
            listOf(StarGold.copy(alpha = 0.32f), Color.Transparent),
            center = Offset(cx, cy), radius = core * 3.4f,
        ),
        radius = core * 3.4f, center = Offset(cx, cy),
    )
    drawCircle(StarGold.copy(alpha = 0.22f), radius = core * 1.7f, center = Offset(cx, cy))
    drawCircle(StarGold, radius = core, center = Offset(cx, cy))
    drawCircle(DarkBackground, radius = core * 0.42f, center = Offset(cx, cy))
    drawCircle(StarGold.copy(alpha = 0.5f), radius = core * 2.5f, center = Offset(cx, cy),
               style = Stroke(1f))
}
