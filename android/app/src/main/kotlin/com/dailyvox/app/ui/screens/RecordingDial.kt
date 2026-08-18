package com.dailyvox.app.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.ui.components.MonoLabel
import com.dailyvox.app.ui.theme.Gold
import com.dailyvox.app.ui.theme.NightBackground
import com.dailyvox.app.ui.theme.NightGoldText
import com.dailyvox.app.ui.theme.NightText
import kotlin.math.cos
import kotlin.math.sin

/**
 * B2b — the full-screen recording dial.
 *
 * Every number here is lifted from the design's own markup rather than
 * approximated: r=104 in a 230 box, 42 faint ticks under a gold elapsed arc, a
 * gold body orbiting at 12s and a pale one counter-orbiting at 22s, a 2.4s
 * breathing glow, 14 waveform bars on a staggered 1s scaleY loop, and a
 * 1.6s blink on the status line.
 *
 * ALWAYS NAVY, whatever the theme. Recording is a night moment by the spec's
 * own logic — the sky is always night — and it also means the dial reads the
 * same at 8am and 11pm.
 */
@Composable
fun RecordingDial(
    elapsed: Int,
    level: Float,
    partial: String,
    lastEntity: String?,
    onStop: () -> Unit,
    onDiscard: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val t = rememberInfiniteTransition(label = "dial")

    // fsPulse — 2.4s, scale 1 -> 1.18, opacity .55 -> .15
    val glow by t.animateFloat(
        0f, 1f,
        infiniteRepeatable(tween(2400, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "glow",
    )
    // fsSpin — 12s forward, 22s reverse
    val orbitA by t.animateFloat(
        0f, 360f,
        infiniteRepeatable(tween(12_000, easing = LinearEasing), RepeatMode.Restart),
        label = "orbitA",
    )
    val orbitB by t.animateFloat(
        360f, 0f,
        infiniteRepeatable(tween(22_000, easing = LinearEasing), RepeatMode.Restart),
        label = "orbitB",
    )
    // fsBlink — 1.6s on the status line, 2.4s on the entity chip
    val blink by t.animateFloat(
        1f, 0.35f,
        infiniteRepeatable(tween(1600, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "blink",
    )
    val chipBlink by t.animateFloat(
        1f, 0.35f,
        infiniteRepeatable(tween(2400, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "chipBlink",
    )

    Column(
        modifier
            .fillMaxSize()
            .background(NightBackground)
            .padding(horizontal = 24.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(Modifier.height(20.dp))
        Text(
            "● RECORDING · ON-DEVICE · 0 B OUT",
            fontSize = 10.sp,
            letterSpacing = 1.6.sp,
            fontWeight = FontWeight.SemiBold,
            color = Gold.copy(alpha = blink),
        )

        Spacer(Modifier.weight(1f))

        Box(contentAlignment = Alignment.Center) {
            Canvas(Modifier.size(288.dp)) {
                val c = center
                val r = size.minDimension * 0.452f      // 104/230

                // Breathing radial glow behind everything.
                val gScale = 1f + 0.18f * glow
                drawCircle(
                    brush = Brush.radialGradient(
                        listOf(Gold.copy(alpha = 0.55f - 0.40f * glow), Color.Transparent),
                        center = c, radius = r * 0.92f * gScale,
                    ),
                    radius = r * 0.92f * gScale, center = c,
                )

                // 42 faint ticks, and the gold ones that have been earned.
                val lit = elapsed.coerceAtMost(42)
                repeat(42) { i ->
                    val a = Math.toRadians(i * (360.0 / 42.0) - 90.0)
                    val p = Offset(
                        c.x + (r * cos(a)).toFloat(),
                        c.y + (r * sin(a)).toFloat(),
                    )
                    drawCircle(
                        color = if (i < lit) Gold else NightText.copy(alpha = 0.16f),
                        radius = if (i < lit) 3.dp.toPx() else 2.5.dp.toPx(),
                        center = p,
                    )
                }

                // The elapsed arc over the ticks. Past 42 seconds it keeps
                // sweeping rather than stopping — 42 is a shape, not a cutoff,
                // and a bar that freezes would read as "stop talking".
                if (elapsed > 0) {
                    drawArc(
                        color = Gold,
                        startAngle = -90f,
                        sweepAngle = 360f * ((elapsed % 42) / 42f),
                        useCenter = false,
                        topLeft = Offset(c.x - r, c.y - r),
                        size = androidx.compose.ui.geometry.Size(r * 2, r * 2),
                        style = Stroke(5.5.dp.toPx(), cap = StrokeCap.Round),
                    )
                }

                // Two orbiting bodies — the solar system, sped up while speaking.
                val aA = Math.toRadians(orbitA - 90.0)
                val pA = Offset(
                    c.x + ((r + 8.dp.toPx()) * cos(aA)).toFloat(),
                    c.y + ((r + 8.dp.toPx()) * sin(aA)).toFloat(),
                )
                drawCircle(Gold.copy(alpha = 0.4f), radius = 9.dp.toPx(), center = pA)
                drawCircle(Gold, radius = 5.dp.toPx(), center = pA)

                val aB = Math.toRadians(orbitB - 90.0)
                val rB = r - 22.dp.toPx()
                drawCircle(
                    NightText.copy(alpha = 0.8f),
                    radius = 3.dp.toPx(),
                    center = Offset(
                        c.x + (rB * cos(aB)).toFloat(),
                        c.y + (rB * sin(aB)).toFloat(),
                    ),
                )
            }

            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(
                    "%d:%02d".format(elapsed / 60, elapsed % 60),
                    fontSize = 46.sp,
                    fontWeight = FontWeight.ExtraBold,
                    color = NightText,
                )
                Spacer(Modifier.height(7.dp))
                Text(
                    "OF 0:42 · ${elapsed.coerceAtMost(42)} TICKS LIT",
                    fontSize = 10.sp,
                    letterSpacing = 1.4.sp,
                    fontWeight = FontWeight.SemiBold,
                    color = NightText.copy(alpha = 0.55f),
                )
            }
        }

        Spacer(Modifier.height(18.dp))
        Waveform(level = level, transition = t)

        Spacer(Modifier.height(18.dp))
        Text(
            if (partial.isBlank()) "Listening…" else "“…$partial”",
            fontSize = 12.5.sp, lineHeight = 19.sp,
            color = NightText.copy(alpha = 0.75f),
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 16.dp),
        )

        // "SARAH ✦ FILED TO YOUR SKY" — the moment the graph catches a name.
        if (lastEntity != null) {
            Spacer(Modifier.height(14.dp))
            Text(
                "${lastEntity.uppercase()} ✦ FILED TO YOUR SKY",
                fontSize = 10.sp,
                fontWeight = FontWeight.ExtraBold,
                letterSpacing = 0.8.sp,
                color = NightGoldText.copy(alpha = chipBlink),
                modifier = Modifier
                    .clip(RoundedCornerShape(12.dp))
                    .background(Gold.copy(alpha = 0.16f))
                    .border(1.dp, Gold.copy(alpha = 0.4f), RoundedCornerShape(12.dp))
                    .padding(horizontal = 12.dp, vertical = 7.dp),
            )
        }

        Spacer(Modifier.weight(1f))

        Row(
            Modifier.fillMaxWidth().padding(bottom = 28.dp),
            horizontalArrangement = Arrangement.Center,
            // Top-aligned: the discs are 48/76/48, so centring them left the
            // three captions on three different baselines.
            verticalAlignment = Alignment.Top,
        ) {
            Box(Modifier.height(96.dp), contentAlignment = Alignment.BottomCenter) {
                DialAction("Discard", onDiscard) {
                    Text("✕", fontSize = 15.sp, color = NightText.copy(alpha = 0.7f))
                }
            }
            Spacer(Modifier.width(20.dp))
            // Stop is 76dp and red — the only red in the product, and it means
            // RECORDING rather than failure.
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier.height(96.dp),
                verticalArrangement = Arrangement.Bottom,
            ) {
                Box(
                    Modifier
                        .size(76.dp)
                        .clip(CircleShape)
                        .background(MaterialTheme.colorScheme.error)
                        .clickable(onClick = onStop),
                    contentAlignment = Alignment.Center,
                ) {
                    Box(
                        Modifier.size(23.dp)
                            .clip(RoundedCornerShape(6.dp))
                            .background(NightText),
                    )
                }
                Spacer(Modifier.height(6.dp))
                Text("Stop & keep ✦", fontSize = 10.sp,
                     fontWeight = FontWeight.ExtraBold, color = NightText)
            }
            Spacer(Modifier.width(20.dp))
            Box(Modifier.height(96.dp), contentAlignment = Alignment.BottomCenter) {
                DialAction("Pause", onStop) {
                Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                    repeat(2) {
                        Box(Modifier.size(4.dp, 15.dp)
                            .clip(RoundedCornerShape(1.5.dp))
                            .background(NightText.copy(alpha = 0.8f)))
                    }
                }
                }
            }
        }
    }
}

@Composable
private fun DialAction(label: String, onClick: () -> Unit, glyph: @Composable () -> Unit) {
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Box(
            Modifier
                .size(48.dp)
                .clip(CircleShape)
                .border(1.5.dp, NightText.copy(alpha = 0.3f), CircleShape)
                .clickable(onClick = onClick),
            contentAlignment = Alignment.Center,
        ) { glyph() }
        Spacer(Modifier.height(6.dp))
        Text(label, fontSize = 10.sp, fontWeight = FontWeight.Bold,
             color = NightText.copy(alpha = 0.55f))
    }
}

/**
 * 14 bars on a staggered 1s scaleY loop (fsWave: .35 -> 1), modulated by the
 * live mic level so it responds to the voice rather than just animating.
 */
@Composable
private fun Waveform(level: Float, transition: InfiniteTransition) {
    val heights = listOf(12, 20, 15, 24, 13, 22, 16, 24, 14, 21, 17, 23, 19, 14)
    val tones = listOf(0, 1, 2, 1, 0, 2, 1, 1, 2, 0, 1, 2, 1, 0)
    Row(
        horizontalArrangement = Arrangement.spacedBy(3.dp),
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.height(26.dp),
    ) {
        heights.forEachIndexed { i, h ->
            val phase by transition.animateFloat(
                0.35f, 1f,
                infiniteRepeatable(
                    tween(1000, delayMillis = i * 120, easing = FastOutSlowInEasing),
                    RepeatMode.Reverse,
                ),
                label = "wave$i",
            )
            val scale = phase * (0.55f + level * 0.65f)
            Box(
                Modifier
                    .width(4.dp)
                    .height((h * scale).dp.coerceAtLeast(3.dp))
                    .clip(RoundedCornerShape(2.dp))
                    .background(
                        when (tones[i]) {
                            0 -> Gold.copy(alpha = 0.6f)
                            1 -> Gold
                            else -> NightText.copy(alpha = 0.75f)
                        }
                    )
            )
        }
    }
}
