package com.dailyvox.app.ui.screens

import androidx.compose.animation.core.*
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.clickable
import androidx.compose.foundation.combinedClickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
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
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import com.dailyvox.app.ui.components.valenceColor
import com.dailyvox.app.ui.theme.*
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * C2 — "Your sky".
 *
 * ALWAYS NAVY, in both themes (§8.4). Not a dark band on a cream screen: the
 * whole surface is night, including under the sky, because this is the one
 * screen the spec makes unconditional.
 *
 * The earlier build got the structure wrong in four ways worth naming, since
 * each was a decision rather than an oversight: it was titled "Your Twin" with
 * a resolution percentage badge, it drew straight lines between arbitrary
 * stars, it carried MIND/HEART/BODY stat cards, and everything below the sky
 * was cream. The design has none of that. It is a title, a star count, a sky
 * whose links CURVE out from the core, and one sentence about who you are.
 */
@OptIn(ExperimentalFoundationApi::class)
@Composable
fun TwinScreen(
    entries: List<Entry>,
    resolution: Int,
    onAsk: () -> Unit = {},
    onInsights: () -> Unit = {},
    onShare: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val sky = rememberInfiniteTransition(label = "sky")
    val orbitInner by sky.animateFloat(
        0f, 360f,
        infiniteRepeatable(tween(80_000, easing = LinearEasing), RepeatMode.Restart),
        label = "orbitInner",
    )
    val orbitOuter by sky.animateFloat(
        360f, 0f,
        infiniteRepeatable(tween(130_000, easing = LinearEasing), RepeatMode.Restart),
        label = "orbitOuter",
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
    val coreGlow by sky.animateFloat(
        0.7f, 1f,
        infiniteRepeatable(tween(5_000, easing = FastOutSlowInEasing), RepeatMode.Reverse),
        label = "coreGlow",
    )
    // Nine twinkle phases at the spec's 2.7-4.1s, each offset so no two land
    // together — that stagger is what stops it reading as a pulsing diagram.
    val twinkle = List(9) { i ->
        sky.animateFloat(
            1f, 0.22f,
            infiniteRepeatable(
                tween(2700 + i * 180, delayMillis = i * 260, easing = FastOutSlowInEasing),
                RepeatMode.Reverse,
            ),
            label = "tw$i",
        )
    }

    val named = remember(entries) {
        entries.flatMap { it.entityList }
            .groupingBy { it }.eachCount()
            .entries.sortedByDescending { it.value }
            .take(3).map { it.key to it.value }
    }
    val depth = when {
        entries.size >= 120 -> "DEEP"
        entries.size >= 60 -> "FORMING"
        entries.size >= 20 -> "EARLY"
        else -> "NEW"
    }

    // Sized against what is BELOW it rather than as a fraction of the screen.
    // At 46% capped to 440dp, a 950dp phone showed the sky ending two thirds of
    // the way down with a band of empty navy under the cards — the one screen
    // where empty space reads as a failure to render rather than as room.
    // ~405dp is the header, summary card, link row, gaps and the nav pill,
    // measured on a 952dp screen rather than estimated. At 460 the sky stopped
    // two thirds down and left a band of empty navy; at 358 the link row sat
    // under the nav pill.
    val skyHeight = (androidx.compose.ui.platform.LocalConfiguration.current
        .screenHeightDp.dp - 405.dp).coerceIn(280.dp, 620.dp)

    val scheme = MaterialTheme.colorScheme
    val night = scheme.background == NightBackground
    // On cream the thin link strokes and orbit rings need the darker gold and
    // the page ink; plain Gold at 1.4dp all but vanishes on #F7F3EA.
    val palette = SkyPalette(
        ink = if (night) NightText else scheme.onBackground,
        line = if (night) Gold else DayGoldText,
        core = Gold,
        accent = if (night) StarBlue else Color(0xFF4C7BA6),
    )
    val goldText = if (night) NightGoldText else DayGoldText

    Column(
        modifier
            .fillMaxSize()
            .background(scheme.background)
            .verticalScroll(rememberScrollState()),
    ) {
        Spacer(Modifier.height(14.dp))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Bottom,
        ) {
            Text("Your sky", fontSize = 28.sp, fontWeight = FontWeight.ExtraBold,
                 color = scheme.onBackground)
            Row(verticalAlignment = Alignment.CenterVertically) {
                // Star count, not a percentage. The number is what the user made.
                Text(
                    "${entries.size} ✦ · $depth",
                    fontSize = 13.sp, fontWeight = FontWeight.ExtraBold,
                    letterSpacing = 0.5.sp, color = goldText,
                )
                Spacer(Modifier.width(6.dp))
                Text(
                    "↗", fontSize = 17.sp, fontWeight = FontWeight.Bold, color = goldText,
                    modifier = Modifier
                        .clip(RoundedCornerShape(12.dp))
                        .clickable(onClick = onShare)
                        .defaultMinSize(minWidth = 40.dp, minHeight = 40.dp)
                        .wrapContentSize(),
                )
            }
        }

        // Grows into whatever the phone gives it. A fixed 300dp left a third of
        // a 952dp screen as empty navy under the cards.
        Box(
            Modifier
                .fillMaxWidth()
                .height(skyHeight)
                // §F: the sky is a share target in its own right, not only via
                // the header arrow. Long-press rather than tap, so exploring
                // the constellation never fires a share sheet by accident.
                .combinedClickable(onClick = {}, onLongClick = onShare)
        ) {
            Canvas(Modifier.fillMaxSize()) {
                drawSky(
                    palette, entries, orbitInner, orbitOuter, comet, innerBody, coreGlow,
                    twinkle.map { it.value },
                )
            }
            // Named stars, labelled in place — the sky is only meaningful if you
            // can read who is in it.
            named.getOrNull(0)?.let { (n, _) ->
                Text(
                    n.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                    color = goldText,
                    modifier = Modifier
                        .align(Alignment.TopStart)
                        .offset(x = 26.dp, y = skyHeight * 0.13f)
                        .clip(RoundedCornerShape(11.dp))
                        .background(Gold.copy(alpha = 0.16f))
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
            named.getOrNull(1)?.let { (n, _) ->
                Text(n.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                     color = scheme.onSurfaceVariant,
                     modifier = Modifier.align(Alignment.TopEnd)
                         .offset(x = (-26).dp, y = skyHeight * 0.19f))
            }
            named.getOrNull(2)?.let { (n, _) ->
                Text(n.uppercase(), fontSize = 10.sp, fontWeight = FontWeight.ExtraBold,
                     color = scheme.onSurfaceVariant,
                     modifier = Modifier.align(Alignment.BottomStart)
                         .offset(x = 34.dp, y = -skyHeight * 0.10f))
            }
        }

        // The one sentence. Everything the Twin has concluded, in a line, with
        // the count it rests on — so it can never sound more certain than it is.
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 16.dp)
                .clip(RoundedCornerShape(20.dp))
                .background(scheme.surface)
                .padding(horizontal = 16.dp, vertical = 13.dp),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.spacedBy(11.dp),
        ) {
            Box(
                Modifier.size(34.dp).clip(CircleShape).background(Gold),
                contentAlignment = Alignment.Center,
            ) {
                Text("✦", fontSize = 14.sp, fontWeight = FontWeight.ExtraBold,
                     color = NightBackground)   // ink on the gold disc, both themes
            }
            Text(
                summary(entries),
                fontSize = 12.sp, lineHeight = 17.sp, fontWeight = FontWeight.Medium,
                color = scheme.onSurface,
            )
        }

        Spacer(Modifier.height(10.dp))
        // Insights is a SEGMENT of this tab (§3), not a fifth destination.
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp),
            horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            SkyLink("Insights", "streak, mood, patterns", onInsights, Modifier.weight(1f))
            SkyLink("Ask", "answers with receipts", onAsk, Modifier.weight(1f))
        }
        Spacer(Modifier.height(120.dp))
    }
}

private fun summary(entries: List<Entry>): String {
    if (entries.size < 5) return "Still listening. A few more nights and there will be something to say."
    val v = entries.map { it.valence }.average()
    val tone = when {
        v > 0.25 -> "warm, steady"
        v > 0.05 -> "even-handed"
        v > -0.15 -> "measured"
        else -> "candid, unsparing"
    }
    val words = entries.sumOf { it.text.split(" ").size } / entries.size
    val length = if (words > 40) "expansive" else "economical"
    return "Who you are: $tone, $length — from ${entries.size} entries."
}

@Composable
private fun SkyLink(title: String, sub: String, onClick: () -> Unit, modifier: Modifier) {
    Column(
        modifier
            .clip(RoundedCornerShape(20.dp))
            .background(MaterialTheme.colorScheme.surface)
            .clickable(onClick = onClick)
            .padding(horizontal = 15.dp, vertical = 14.dp),
    ) {
        Text(title, fontSize = 14.sp, fontWeight = FontWeight.ExtraBold,
             color = MaterialTheme.colorScheme.onSurface)
        Spacer(Modifier.height(3.dp))
        Text(sub, fontSize = 11.sp, color = MaterialTheme.colorScheme.onSurfaceVariant)
    }
}

/**
 * Every colour the sky draws with, so the constellation follows the app theme
 * instead of being navy on a cream app.
 *
 * The design spec calls the Twin tab "always night". Shipped that way it was
 * the one screen in a different world from the other three, and read as a bug
 * rather than a mood — which is the note that came back twice. Night is now a
 * theme, not a property of this screen.
 */
private data class SkyPalette(
    /** Orbit rings and unnamed stars — the ink of the sky. */
    val ink: Color,
    /** Link strokes and the comet tail. Thin, so it needs contrast. */
    val line: Color,
    /** The core disc and comet head: the user, and a made thing, so gold. */
    val core: Color,
    val accent: Color,
)

/**
 * The sky itself. Links CURVE out of the core as quadratic beziers, which is
 * what makes it read as a constellation rather than a network diagram.
 */
private fun DrawScope.drawSky(
    palette: SkyPalette,
    entries: List<Entry>,
    orbitInner: Float,
    orbitOuter: Float,
    comet: Float,
    innerBody: Float,
    coreGlow: Float,
    twinkle: List<Float>,
) {
    val cx = size.width / 2f
    val cy = size.height * 0.47f
    val core = Offset(cx, cy)

    // Centre glow, breathing at 5s.
    drawCircle(
        brush = Brush.radialGradient(
            listOf(palette.core.copy(alpha = 0.22f * coreGlow), Color.Transparent),
            center = core, radius = size.minDimension * 0.62f,
        ),
        radius = size.minDimension * 0.62f, center = core,
    )

    // Two dashed orbit rings, counter-rotating. The dash PHASE carries the
    // rotation — spinning a circle is a no-op, so a rotation transform would
    // have produced a perfectly static ring.
    listOf(
        (size.minDimension * 0.20f) to orbitInner,
        (size.minDimension * 0.33f) to orbitOuter,
    ).forEach { (rad, rot) ->
        val circumference = (2.0 * Math.PI * rad).toFloat()
        drawCircle(
            color = palette.ink.copy(alpha = if (rad < size.minDimension * 0.25f) 0.16f else 0.10f),
            radius = rad, center = core,
            style = Stroke(
                1.dp.toPx(),
                pathEffect = androidx.compose.ui.graphics.PathEffect.dashPathEffect(
                    floatArrayOf(1.dp.toPx(), 6.dp.toPx()), circumference * (rot / 360f),
                ),
            ),
        )
    }

    // Named stars: the four biggest, each on a curved link out of the core.
    val big = entries.take(4)
    val anchors = listOf(
        Offset(cx - size.width * 0.23f, cy - size.height * 0.21f),
        Offset(cx + size.width * 0.24f, cy - size.height * 0.16f),
        Offset(cx - size.width * 0.17f, cy + size.height * 0.28f),
        Offset(cx + size.width * 0.22f, cy + size.height * 0.23f),
    )
    // Control points pushed PERPENDICULAR to each core->star line. Placing them
    // on the line (as the first version did) produces a mathematically valid
    // quadratic that is visually a straight segment — the curve has to bow.
    val controls = anchors.mapIndexed { i, p ->
        val mx = (core.x + p.x) / 2f
        val my = (core.y + p.y) / 2f
        val dx = p.x - core.x
        val dy = p.y - core.y
        val len = kotlin.math.sqrt(dx * dx + dy * dy).coerceAtLeast(1f)
        // Alternate the bow direction so the four links do not all sweep the
        // same way, which would read as a fan rather than a constellation.
        val bow = if (i % 2 == 0) 0.22f else -0.18f
        Offset(mx + (-dy / len) * len * bow, my + (dx / len) * len * bow)
    }
    big.forEachIndexed { i, e ->
        val p = anchors[i]
        drawPath(
            Path().apply {
                moveTo(core.x, core.y)
                quadraticBezierTo(controls[i].x, controls[i].y, p.x, p.y)
            },
            color = palette.line.copy(alpha = 0.5f - i * 0.06f),
            style = Stroke(1.4.dp.toPx()),
        )
        val c = if (i == 1) palette.accent else palette.ink
        drawCircle(c.copy(alpha = 0.15f), radius = (11 - i).dp.toPx(), center = p)
        drawCircle(
            if (i == 3) palette.core.copy(alpha = 0.85f) else c,
            radius = (6 - i * 0.5f).dp.toPx(), center = p,
        )
    }

    // The core: a soft disc under a solid one.
    drawCircle(palette.core.copy(alpha = 0.2f), radius = 18.dp.toPx() * coreGlow, center = core)
    drawCircle(palette.core, radius = 11.dp.toPx(), center = core)

    // Comet on the outer ring, with a tail.
    val rOuter = size.minDimension * 0.33f
    repeat(6) { k ->
        val a = Math.toRadians(comet - 90.0 - k * 2.6)
        drawCircle(
            palette.line.copy(alpha = 0.28f * (1f - k / 6f)),
            radius = (3.0f - k * 0.4f).coerceAtLeast(0.6f).dp.toPx(),
            center = Offset(
                cx + (rOuter * cos(a)).toFloat(),
                cy + (rOuter * sin(a)).toFloat(),
            ),
        )
    }
    val ca = Math.toRadians(comet - 90.0)
    val cp = Offset(cx + (rOuter * cos(ca)).toFloat(), cy + (rOuter * sin(ca)).toFloat())
    drawCircle(palette.core.copy(alpha = 0.25f), radius = 6.dp.toPx(), center = cp)
    drawCircle(palette.core, radius = 2.6.dp.toPx(), center = cp)

    // A blue body on the inner ring, the other way.
    val rInner = size.minDimension * 0.20f
    val ba = Math.toRadians(innerBody - 90.0)
    drawCircle(
        palette.accent, radius = 2.dp.toPx(),
        center = Offset(cx + (rInner * cos(ba)).toFloat(), cy + (rInner * sin(ba)).toFloat()),
    )

    // The rest of the journal as small twinkling stars, seeded off each entry so
    // the same sky is drawn every time.
    entries.drop(4).forEachIndexed { i, e ->
        var s = (e.createdAt xor (i * 7919L))
        fun rnd(): Float { s = s * 6364136223846793005L + 1442695040888963407L
                           return ((s ushr 33) % 10000) / 10000f }
        val p = Offset(rnd() * size.width, rnd() * size.height)
        // Keep the core legible.
        if (abs(p.x - cx) < size.width * 0.10f && abs(p.y - cy) < size.height * 0.12f) return@forEachIndexed
        val tw = if (twinkle.isEmpty()) 1f else twinkle[i % twinkle.size]
        drawCircle(
            valenceColor(e.valence).copy(alpha = 0.5f * tw),
            radius = (1.6f + (i % 3) * 0.35f).dp.toPx(),
            center = p,
        )
    }
}
