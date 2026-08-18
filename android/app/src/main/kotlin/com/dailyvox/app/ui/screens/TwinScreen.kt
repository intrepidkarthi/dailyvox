package com.dailyvox.app.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
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
import com.dailyvox.app.ui.components.DvCard
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
fun TwinScreen(
    entries: List<Entry>,
    resolution: Int,
    onAsk: () -> Unit = {},
    onInsights: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
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

    // The sky is ALIVE (FINAL-SPEC §2.5). Every period is the spec's own.
    val sky = rememberInfiniteTransition(label = "sky")
    val orbitOuter by sky.animateFloat(
        0f, 360f,
        infiniteRepeatable(tween(80_000, easing = LinearEasing), RepeatMode.Restart),
        label = "orbitOuter",
    )
    val orbitInner by sky.animateFloat(
        360f, 0f,   // counter-rotating
        infiniteRepeatable(tween(130_000, easing = LinearEasing), RepeatMode.Restart),
        label = "orbitInner",
    )
    val comet by sky.animateFloat(
        0f, 360f,
        infiniteRepeatable(tween(18_000, easing = LinearEasing), RepeatMode.Restart),
        label = "comet",
    )
    val innerBody by sky.animateFloat(
        360f, 0f,
        infiniteRepeatable(tween(30_000, easing = LinearEasing), RepeatMode.Restart),
        label = "innerBody",
    )
    val coreBreath by sky.animateFloat(
        0f, 1f,
        infiniteRepeatable(tween(5_000, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "coreBreath",
    )
    // Twinkle phases, staggered 3-4s so no two stars pulse together.
    val twinkle = (0 until 6).map { i ->
        sky.animateFloat(
            0.55f, 1f,
            infiniteRepeatable(
                tween(3000 + i * 200, delayMillis = i * 480, easing = FastOutSlowInEasing),
                RepeatMode.Reverse,
            ),
            label = "tw$i",
        )
    }

    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(skyHeight)
                .background(Brush.verticalGradient(listOf(SkyBackground, SkySurface)))
        ) {
            Canvas(Modifier.fillMaxSize()) {
                drawSky(
                    entries, breath,
                    orbitOuter = orbitOuter, orbitInner = orbitInner,
                    comet = comet, innerBody = innerBody,
                    coreBreath = coreBreath,
                    twinkle = twinkle.map { it.value },
                )
            }

            Row(
                Modifier.fillMaxWidth().padding(20.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text("Your Twin", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = NightText)
                Text(
                    "$resolution%",
                    fontSize = 13.sp, fontWeight = FontWeight.Bold, color = NightBackground,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .background(StarGold)
                        .padding(horizontal = 10.dp, vertical = 5.dp),
                )
            }
            Text(
                "${entries.size} stars · your inner sky deepens",
                fontSize = 11.sp, color = NightTextSecondary,
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
        Spacer(Modifier.height(20.dp))
        // The Twin screen shows what the Twin KNOWS; Ask is where you interrogate
        // it. Having no route between them meant the obvious next question after
        // reading "Sarah x3" had to be found in the nav bar, which is a strange
        // place to look for a follow-up to something you are already staring at.
        // Two routes out of this screen. Insights especially needed one: it was
        // reachable ONLY by tapping the "6% resolved" badge on Speak, which is a
        // percentage, not a signpost — a whole screen hidden behind a number.
        Column(Modifier.padding(horizontal = 20.dp)) {
            LinkCard(
                title = "Ask your Twin",
                body = if (entries.size < 3)
                    "A few more nights and it will have something to say."
                else
                    "Put a question to what it has read. Every answer cites the entries it used.",
                onClick = onAsk,
            )
            Spacer(Modifier.height(10.dp))
            LinkCard(
                title = "Insights",
                body = "Streaks, the last thirty nights, your mood curve, and the patterns it has noticed.",
                onClick = onInsights,
            )
        }
        Spacer(Modifier.height(130.dp))
    }
}

@Composable
private fun LinkCard(title: String, body: String, onClick: () -> Unit) {
    DvCard(Modifier.clickable(onClick = onClick)) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(title, fontSize = 16.sp, fontWeight = FontWeight.SemiBold,
                     color = MaterialTheme.colorScheme.onSurface)
                Spacer(Modifier.height(4.dp))
                Text(body, fontSize = 13.sp, lineHeight = 19.sp,
                     color = MaterialTheme.colorScheme.onSurfaceVariant)
            }
            Spacer(Modifier.width(12.dp))
            Text("\u203A", fontSize = 26.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
        }
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

private fun DrawScope.drawSky(
    entries: List<Entry>,
    breath: Float,
    orbitOuter: Float = 0f,
    orbitInner: Float = 0f,
    comet: Float = 0f,
    innerBody: Float = 0f,
    coreBreath: Float = 0f,
    twinkle: List<Float> = emptyList(),
) {
    val w = size.width; val h = size.height
    val cx = w / 2f; val cy = h / 2f

    // Dust: 40 faint points, seeded so the sky is the same every launch.
    repeat(40) { i ->
        val x = hash(i * 7L + 1) * w
        val y = hash(i * 13L + 2) * h
        drawCircle(NightText.copy(alpha = 0.05f + hash(i * 3L) * 0.05f), radius = 1.1f, center = Offset(x, y))
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

    // Two dashed orbit rings, counter-rotating. These are the structure the
    // comet and the inner body travel on, and they are what makes the sky read
    // as a system rather than a scatter.
    val cx0 = size.width / 2f
    val cy0 = size.height / 2f
    val rOuter = size.minDimension * 0.40f
    val rInner = size.minDimension * 0.255f
    listOf(rOuter to orbitOuter, rInner to orbitInner).forEach { (rad, rot) ->
        // The dash phase carries the rotation: spinning a perfect circle is a
        // no-op, so the ring only appears to drift if the dashes move along it.
        val circumference = (2.0 * Math.PI * rad).toFloat()
        drawCircle(
            color = StarGold.copy(alpha = 0.13f),
            radius = rad,
            center = Offset(cx0, cy0),
            style = Stroke(
                1.dp.toPx(),
                pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(
                    floatArrayOf(3.dp.toPx(), 9.dp.toPx()),
                    circumference * (rot / 360f),
                ),
            ),
        )
    }

    // The comet: gold, on the outer ring, with a short tail.
    val ca = Math.toRadians(comet - 90.0)
    val cp = Offset(
        cx0 + (rOuter * cos(ca)).toFloat(),
        cy0 + (rOuter * sin(ca)).toFloat(),
    )
    repeat(6) { k ->
        val ta = Math.toRadians(comet - 90.0 - k * 2.4)
        drawCircle(
            color = StarGold.copy(alpha = 0.30f * (1f - k / 6f)),
            radius = (3.2f - k * 0.42f).coerceAtLeast(0.6f).dp.toPx(),
            center = Offset(
                cx0 + (rOuter * cos(ta)).toFloat(),
                cy0 + (rOuter * sin(ta)).toFloat(),
            ),
        )
    }
    drawCircle(StarGold.copy(alpha = 0.5f), radius = 7.dp.toPx(), center = cp)
    drawCircle(StarGold, radius = 3.2.dp.toPx(), center = cp)

    // A small blue body on the inner ring, travelling the other way.
    val ba = Math.toRadians(innerBody - 90.0)
    drawCircle(
        StarBlue.copy(alpha = 0.85f),
        radius = 2.6.dp.toPx(),
        center = Offset(
            cx0 + (rInner * cos(ba)).toFloat(),
            cy0 + (rInner * sin(ba)).toFloat(),
        ),
    )

    // Stars: four concentric passes per star. Not a blur — stacked alpha.
    positions.forEachIndexed { idx, (p, e, base) ->
        val c = valenceColor(e.valence)
        // Staggered twinkle. Without it the sky is a static diagram; the spec
        // asks for 3-4s cycles that never land in phase.
        val tw = if (twinkle.isEmpty()) 1f else twinkle[idx % twinkle.size]
        val r = base * (0.55f + maturity * 0.45f) * tw
        drawCircle(c.copy(alpha = 0.08f), radius = r * 4f, center = p)
        drawCircle(c.copy(alpha = 0.15f), radius = r * 2.2f, center = p)
        drawCircle(c.copy(alpha = 0.90f), radius = r, center = p)
        drawCircle(Color.White.copy(alpha = 0.70f), radius = r * 0.4f, center = p)
    }

    // The Twin: breathing core star, sage-gold, always at centre.
    val pulse = 1f + sin(breath) * 0.06f + coreBreath * 0.05f
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
    drawCircle(NightBackground, radius = core * 0.42f, center = Offset(cx, cy))
    drawCircle(StarGold.copy(alpha = 0.5f), radius = core * 2.5f, center = Offset(cx, cy),
               style = Stroke(1f))
}
