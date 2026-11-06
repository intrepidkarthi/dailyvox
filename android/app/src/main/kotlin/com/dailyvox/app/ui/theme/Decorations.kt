package com.dailyvox.app.ui.theme

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.State
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Rect
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import kotlin.math.PI
import kotlin.math.cos
import kotlin.math.sin

/**
 * The decoration layer: the small flat drawings that make each theme itself
 * (a band and its weather, a lamp row, a crescent). Everything here is drawn,
 * never laid out, so TalkBack never meets it, and nothing is ever drawn behind
 * journal text: only headers, edges, the dial and the sky.
 *
 * Motion (rain, snow, petals, leaves, ripples) runs only on Today's header, the
 * recording dial and the sky, and only when the system animator scale is on.
 * Off-screen it stops by itself: an infinite transition only ticks while its
 * screen is composed.
 *
 * Shapes follow the theme mockups (Nov 2026), simplified for small sizes.
 */
val LocalThemeId = staticCompositionLocalOf { ThemeId.DEFAULT }

private val Ink = Color(0xFF1D1F24)
private val White = Color.White

/** True when this palette should carry the theme's decorations: every light
 *  palette, and the dark ones a theme was actually drawn with. The borrowed
 *  default night stays plain. */
fun decorated(id: ThemeId, p: DvPalette) = !p.isNight || id.hasOwnDark

// ── primitives ──────────────────────────────────────────────────────────────

fun DrawScope.petal(c: Offset, r: Float, color: Color, deg: Float) = rotate(deg, c) {
    drawOval(color, topLeft = Offset(c.x - r * .55f, c.y - r), size = Size(r * 1.1f, r * 2f))
}

fun DrawScope.leaf(c: Offset, r: Float, fill: Color, vein: Color, deg: Float) = rotate(deg, c) {
    val p = Path().apply {
        moveTo(c.x - r, c.y + r)
        cubicTo(c.x - r, c.y - r * .2f, c.x - r * .2f, c.y - r, c.x + r, c.y - r)
        cubicTo(c.x + r, c.y + r * .2f, c.x + r * .2f, c.y + r, c.x - r, c.y + r)
        close()
    }
    drawPath(p, fill)
    drawLine(vein, Offset(c.x - r, c.y + r), Offset(c.x + r * .45f, c.y - r * .45f), strokeWidth = r * .14f, cap = StrokeCap.Round)
}

fun DrawScope.snowflake(c: Offset, r: Float, color: Color) {
    repeat(3) { i ->
        val a = i * PI / 3
        val d = Offset((cos(a) * r).toFloat(), (sin(a) * r).toFloat())
        drawLine(color, c - d, c + d, strokeWidth = r * .28f, cap = StrokeCap.Round)
    }
}

fun DrawScope.sun(c: Offset, r: Float, disc: Color, rays: Color) {
    repeat(8) { i ->
        val a = i * PI / 4
        val u = Offset(cos(a).toFloat(), sin(a).toFloat())
        drawLine(rays, c + u * (r * 1.35f), c + u * (r * 1.85f), strokeWidth = r * .28f, cap = StrokeCap.Round)
    }
    drawCircle(disc, r, c)
}

fun DrawScope.crescent(c: Offset, r: Float, color: Color) {
    val p = Path().apply {
        addOval(Rect(c, r))
        val cut = Path().apply { addOval(Rect(c + Offset(r * .45f, -r * .3f), r * .88f)) }
        op(this, cut, androidx.compose.ui.graphics.PathOperation.Difference)
    }
    drawPath(p, color)
}

/** A five-point star (Christmas centre) or eight-point (Eid strip). */
fun DrawScope.star(c: Offset, r: Float, color: Color, points: Int = 5, inner: Float = .45f, outline: Color? = null) {
    val p = Path()
    for (i in 0 until points * 2) {
        val a = -PI / 2 + i * PI / points
        val rr = if (i % 2 == 0) r else r * inner
        val pt = Offset(c.x + (cos(a) * rr).toFloat(), c.y + (sin(a) * rr).toFloat())
        if (i == 0) p.moveTo(pt.x, pt.y) else p.lineTo(pt.x, pt.y)
    }
    p.close()
    if (outline != null) drawPath(p, outline, style = Stroke(r * .22f))
    drawPath(p, color)
}

fun DrawScope.lotus(c: Offset, r: Float, color: Color) {
    val s = Stroke(r * .13f)
    val mid = Path().apply { moveTo(c.x, c.y + r); quadraticBezierTo(c.x - r * .45f, c.y, c.x, c.y - r); quadraticBezierTo(c.x + r * .45f, c.y, c.x, c.y + r) }
    val left = Path().apply { moveTo(c.x, c.y + r); quadraticBezierTo(c.x - r * 1.2f, c.y + r * .3f, c.x - r * .9f, c.y - r * .45f); quadraticBezierTo(c.x - r * .35f, c.y + r * .1f, c.x, c.y + r) }
    val right = Path().apply { moveTo(c.x, c.y + r); quadraticBezierTo(c.x + r * 1.2f, c.y + r * .3f, c.x + r * .9f, c.y - r * .45f); quadraticBezierTo(c.x + r * .35f, c.y + r * .1f, c.x, c.y + r) }
    listOf(mid, left, right).forEach { drawPath(it, color, style = s) }
}

fun DrawScope.diya(c: Offset, w: Float, clay: Color, flame: Color) {
    val bowl = Path().apply {
        moveTo(c.x - w / 2, c.y); lineTo(c.x + w / 2, c.y)
        quadraticBezierTo(c.x + w / 2, c.y + w * .42f, c.x, c.y + w * .42f)
        quadraticBezierTo(c.x - w / 2, c.y + w * .42f, c.x - w / 2, c.y); close()
    }
    drawPath(bowl, clay)
    val f = Path().apply {
        moveTo(c.x, c.y - w * .55f)
        quadraticBezierTo(c.x + w * .2f, c.y - w * .15f, c.x, c.y)
        quadraticBezierTo(c.x - w * .2f, c.y - w * .15f, c.x, c.y - w * .55f); close()
    }
    drawPath(f, flame)
}

fun DrawScope.lantern(top: Offset, h: Float, body: Color, line: Color) {
    drawLine(line, top, top + Offset(0f, h * .3f), strokeWidth = h * .04f)
    val c = top + Offset(0f, h * .3f)
    val b = Path().apply {
        moveTo(c.x, c.y); lineTo(c.x + h * .22f, c.y + h * .18f); lineTo(c.x + h * .22f, c.y + h * .52f)
        lineTo(c.x, c.y + h * .68f); lineTo(c.x - h * .22f, c.y + h * .52f); lineTo(c.x - h * .22f, c.y + h * .18f); close()
    }
    drawPath(b, body)
    drawRect(line.copy(alpha = .5f), topLeft = c + Offset(-h * .1f, h * .24f), size = Size(h * .2f, h * .22f))
}

fun DrawScope.splash(c: Offset, r: Float, color: Color) {
    drawCircle(color, r, c)
    listOf(0.0, 1.3, 2.4, 3.6, 4.9).forEachIndexed { i, a ->
        val d = r * (1.05f + (i % 2) * .25f)
        drawCircle(color, r * (.38f - (i % 3) * .07f), c + Offset((cos(a) * d).toFloat(), (sin(a) * d).toFloat()))
    }
}

fun DrawScope.boat(c: Offset, w: Float, fill: Color, line: Color) {
    val hull = Path().apply {
        moveTo(c.x - w / 2, c.y); lineTo(c.x + w / 2, c.y); lineTo(c.x + w * .32f, c.y + w * .24f); lineTo(c.x - w * .32f, c.y + w * .24f); close()
    }
    val sail = Path().apply { moveTo(c.x - w * .05f, c.y - w * .02f); lineTo(c.x - w * .05f, c.y - w * .5f); lineTo(c.x + w * .3f, c.y - w * .02f); close() }
    drawPath(sail, fill.copy(alpha = .85f)); drawPath(sail, line, style = Stroke(w * .04f))
    drawPath(hull, fill); drawPath(hull, line, style = Stroke(w * .04f))
}

fun DrawScope.mug(c: Offset, w: Float, fill: Color) {
    drawRoundRect(fill, topLeft = c + Offset(-w / 2, -w * .35f), size = Size(w * .8f, w * .75f), cornerRadius = CornerRadius(w * .14f))
    drawArc(fill, -90f, 180f, false, topLeft = c + Offset(w * .12f, -w * .18f), size = Size(w * .38f, w * .38f), style = Stroke(w * .1f))
    repeat(2) { i -> drawLine(fill.copy(alpha = .5f), c + Offset(-w * .25f + i * w * .25f, -w * .5f), c + Offset(-w * .25f + i * w * .25f, -w * .75f), strokeWidth = w * .06f, cap = StrokeCap.Round) }
}

fun DrawScope.ribbon(c: Offset, w: Float, red: Color, knot: Color) {
    val l = Path().apply { moveTo(c.x, c.y); quadraticBezierTo(c.x - w * .5f, c.y - w * .45f, c.x - w * .5f, c.y - w * .05f); quadraticBezierTo(c.x - w * .5f, c.y + w * .2f, c.x, c.y); close() }
    val r = Path().apply { moveTo(c.x, c.y); quadraticBezierTo(c.x + w * .5f, c.y - w * .45f, c.x + w * .5f, c.y - w * .05f); quadraticBezierTo(c.x + w * .5f, c.y + w * .2f, c.x, c.y); close() }
    drawPath(l, red); drawPath(r, red)
    drawLine(red, c, c + Offset(-w * .2f, w * .45f), strokeWidth = w * .12f, cap = StrokeCap.Round)
    drawLine(red, c, c + Offset(w * .2f, w * .45f), strokeWidth = w * .12f, cap = StrokeCap.Round)
    drawCircle(knot, w * .1f, c)
}

fun DrawScope.pot(c: Offset, w: Float, clay: Color, rim: Color, froth: Color) {
    val body = Path().apply { moveTo(c.x - w / 2, c.y); lineTo(c.x + w / 2, c.y); quadraticBezierTo(c.x + w / 2, c.y + w * .62f, c.x, c.y + w * .62f); quadraticBezierTo(c.x - w / 2, c.y + w * .62f, c.x - w / 2, c.y); close() }
    drawPath(body, clay)
    drawRect(rim, topLeft = c + Offset(-w * .55f, -w * .12f), size = Size(w * 1.1f, w * .14f))
    drawCircle(froth, w * .16f, c + Offset(-w * .15f, -w * .18f)); drawCircle(froth, w * .2f, c + Offset(w * .1f, -w * .22f))
}

private operator fun Offset.times(f: Float) = Offset(x * f, y * f)

// ── per-theme pieces ────────────────────────────────────────────────────────

/** Deterministic particle field: n pieces, each with a column and a phase. */
private inline fun DrawScope.particles(area: Rect, n: Int, t: Float, speed: Float, piece: DrawScope.(Offset, Int) -> Unit) {
    for (i in 0 until n) {
        val fx = ((i * 0.618f + 0.13f) % 1f)
        val ph = ((i * 0.377f) % 1f)
        val y = area.top + ((ph + t * speed) % 1f) * area.height
        val x = area.left + fx * area.width + sin((t * 2 * PI + i).toFloat()) * 4f
        piece(Offset(x, y), i)
    }
}

/**
 * Today's header for a theme: the band (if the theme has one) plus its motif.
 * [area] is the band rectangle; [t] the 0..1 loop phase (0 when still).
 * [dense] is false for the tiny tile/preview versions.
 */
fun DrawScope.drawHeaderDecor(id: ThemeId, p: DvPalette, area: Rect, t: Float, dense: Boolean = true) {
    val u = area.height / 80f                       // one unit ≈ 1dp at full size
    p.band?.let { drawRect(it, area.topLeft, area.size) }
    val inBand = Rect(area.left, area.top, area.right, area.bottom)
    when (id) {
        ThemeId.SPRING -> particles(inBand, if (dense) 9 else 4, t, 1f) { c, i ->
            petal(c, 5f * u, if (i % 2 == 0) Color(0xFFF2A7BC) else Color(0xFFE88AA6), i * 40f + t * 360f)
        }
        ThemeId.SUMMER -> sun(Offset(area.right - 46f * u, area.top + 26f * u), 9f * u, White, White)
        ThemeId.MONSOON -> particles(inBand, if (dense) 18 else 8, t, 2f) { c, _ ->
            drawLine(White.copy(alpha = .45f), c, c + Offset(-3f * u, 9f * u), strokeWidth = 1.4f * u, cap = StrokeCap.Round)
        }
        ThemeId.AUTUMN -> particles(inBand, if (dense) 6 else 3, t, .8f) { c, i ->
            leaf(c, 5f * u, if (i % 2 == 0) Color(0xFFF7D27A) else Color(0xFFE9A15A), Color(0xFF8A3E1E), i * 55f + t * 200f)
        }
        ThemeId.WINTER -> particles(inBand, if (dense) 16 else 7, t, .7f) { c, i ->
            if (i % 4 == 0) snowflake(c, 3.6f * u, White) else drawCircle(White.copy(alpha = .9f), 1.8f * u, c)
        }
        ThemeId.CHRISTMAS -> {
            val y = area.bottom - 10f * u
            val wire = Path().apply {
                moveTo(area.left, y)
                var x = area.left
                while (x < area.right) { quadraticBezierTo(x + 20f * u, y + 9f * u, x + 40f * u, y); x += 40f * u }
            }
            drawPath(wire, Color(0xFF0F3324), style = Stroke(1.3f * u))
            val bulbs = listOf(Color(0xFFE2C25A), Color(0xFFC8323F), White, Color(0xFF7FC4A0))
            var x = area.left + 20f * u; var k = 0
            while (x < area.right) { drawCircle(bulbs[k % 4], 3.4f * u, Offset(x, y + 6f * u)); x += 40f * u; k++ }
            if (dense) particles(Rect(area.left, area.top, area.right, y - 6f * u), 7, t, .5f) { c, _ -> drawCircle(White.copy(alpha = .7f), 1.6f * u, c) }
        }
        ThemeId.DIWALI -> {
            val y = area.bottom - 12f * u
            val n = ((area.width / (58f * u)).toInt()).coerceAtLeast(3)
            for (i in 0 until n) diya(Offset(area.left + (i + .5f) * area.width / n, y), 18f * u, Color(0xFFC9692A), Color(0xFFF5B84A))
        }
        ThemeId.PONGAL -> {
            val y = area.bottom - 5f * u
            var x = area.left + 6f * u
            while (x < area.right) { drawCircle(Color(0xFF7A3F12), 2f * u, Offset(x, y)); x += 11f * u }
        }
        ThemeId.RAMADAN -> {
            crescent(Offset(area.right - 34f * u, area.top + 24f * u), 10f * u, Color(0xFFE8C46A))
            lantern(Offset(area.right - 70f * u, area.top), 46f * u, Color(0xFFE8C46A), Color(0xFFE8C46A))
        }
        ThemeId.HOLI -> {
            splash(Offset(area.left + 6f * u, area.top + 4f * u), 13f * u, Color(0xFFF06FA4))
            splash(Offset(area.right - 120f * u, area.top - 2f * u), 8f * u, Color(0xFFFFD23F))
            splash(Offset(area.right - 30f * u, area.top + 2f * u), 11f * u, Color(0xFF3FB86B))
            splash(Offset(area.right - 6f * u, area.top + 34f * u), 8f * u, Color(0xFF4C7FEA))
        }
        ThemeId.EID -> {
            val y = area.bottom - 6f * u
            drawLine(Color(0xFFD9C27E), Offset(area.left + 8f * u, y), Offset(area.right - 8f * u, y), strokeWidth = 1f * u)
            var x = area.left + 16f * u
            while (x < area.right - 8f * u) { star(Offset(x, y), 4.2f * u, Color(0xFFB8912F), points = 8, inner = .55f); x += 32f * u }
        }
        ThemeId.MIST -> drawLine(p.action.copy(alpha = .35f), Offset(area.left + 12f * u, area.bottom - 4f * u), Offset(area.right - 12f * u, area.bottom - 4f * u), strokeWidth = 1.2f * u)
        ThemeId.SANDALWOOD -> drawLine(Color(0xFFB08D57), Offset(area.left + 12f * u, area.bottom - 4f * u), Offset(area.right - 12f * u, area.bottom - 4f * u), strokeWidth = 2f * u)
        ThemeId.LOTUS -> lotus(Offset(area.right - 120f * u, area.top + 26f * u), 9f * u, Color(0xFFB0476B))
        ThemeId.HUSH -> crescent(Offset(area.left + 128f * u, area.top + 22f * u), 6f * u, Color(0xFFB9A3D6))
        ThemeId.PAPER_NOTEBOOK -> {
            drawLine(Color(0xFFC0392B).copy(alpha = .55f), Offset(area.left + 8f * u, area.top), Offset(area.left + 8f * u, area.bottom), strokeWidth = 1.2f * u)
            drawLine(Color(0xFF9AA3B5).copy(alpha = .5f), Offset(area.left, area.bottom - 3f * u), Offset(area.right, area.bottom - 3f * u), strokeWidth = 1f * u)
        }
        else -> Unit
    }
}

/** The loop phase for animated decorations, or a still 0 under reduced motion. */
@Composable
fun decorPhase(periodMs: Int = 9000): State<Float> {
    val still = com.dailyvox.app.ui.components.reduceMotion()
    if (still) return remember { mutableFloatStateOf(0.3f) }
    val tr = rememberInfiniteTransition(label = "decor")
    return tr.animateFloat(0f, 1f, infiniteRepeatable(tween(periodMs, easing = LinearEasing), RepeatMode.Restart), label = "decorT")
}

/**
 * Today's header decoration as a modifier on the header block: draws the band
 * full-bleed ([bleed] past each side) and up to the top of the screen, then the
 * motif. Returns the plain modifier for themes without a header treatment.
 */
@Composable
fun Modifier.themeHeader(bleed: Dp, bottomExtra: Dp = 10.dp): Modifier {
    val id = LocalThemeId.current
    val p = LocalDvPalette.current
    if (!decorated(id, p) || id in setOf(ThemeId.DEFAULT, ThemeId.STICKER, ThemeId.HIGH_CONTRAST)) return this
    val phase = decorPhase()
    return this.drawBehind {
        val b = bleed.toPx()
        // from above the header (under the status-bar gap) to just below it
        val area = Rect(-b, -40.dp.toPx(), size.width + b, size.height + bottomExtra.toPx())
        drawHeaderDecorAt(id, p, area, phase.value, density)
    }
}

/** [drawHeaderDecor] with its unit pinned to 1dp. */
fun DrawScope.drawHeaderDecorAt(id: ThemeId, p: DvPalette, area: Rect, t: Float, dpPx: Float, dense: Boolean = true) {
    // drawHeaderDecor derives its unit from height/80; feed it a rect whose unit is 1dp
    val unitArea = Rect(area.left, area.bottom - 80f * dpPx, area.right, area.bottom)
    p.band?.let { drawRect(it, area.topLeft, area.size) }
    drawHeaderDecor(id, p.copy(band = null), unitArea, t, dense)
}

/** The streak motif beside Insights' big number. */
fun DrawScope.drawStreakMotif(id: ThemeId, c: Offset, w: Float) {
    when (id) {
        ThemeId.MONSOON -> boat(c, w, Color(0xFFF2B705), Ink)
        ThemeId.WINTER -> mug(c, w, Color(0xFFA3243F))
        ThemeId.AUTUMN -> leaf(c, w * .45f, Color(0xFFF7D27A), Color(0xFFA6461E), -20f)
        ThemeId.CHRISTMAS -> ribbon(c, w, Color(0xFFC8323F), Color(0xFFE2C25A))
        ThemeId.PONGAL -> pot(c, w * .8f, Color(0xFFB8572A), Color(0xFF8E3A12), White)
        ThemeId.LOTUS -> lotus(c, w * .4f, Color(0xFFB0476B))
        else -> Unit
    }
}

fun hasStreakMotif(id: ThemeId) = id in setOf(ThemeId.MONSOON, ThemeId.WINTER, ThemeId.AUTUMN, ThemeId.CHRISTMAS, ThemeId.PONGAL, ThemeId.LOTUS)

/**
 * The recording dial's treatment, drawn around a dial of radius [r] at [c].
 * Sticker: a chunky die-cut ring. Monsoon: ripples. Spring: a bud of petals.
 * Diwali: a rangoli ring of dots.
 */
fun DrawScope.drawDialDecor(id: ThemeId, p: DvPalette, c: Offset, r: Float, t: Float) {
    when (id) {
        ThemeId.STICKER -> {
            val w = r * .12f
            drawCircle(Color.Black.copy(alpha = .55f), r, c + Offset(r * .03f, r * .04f), style = Stroke(w + r * .05f))
            drawCircle(White, r, c, style = Stroke(w + r * .05f))
            drawCircle(p.night.reward, r, c, style = Stroke(w))
            drawCircle(Ink, r + w / 2 + r * .025f, c, style = Stroke(r * .012f))
        }
        ThemeId.MONSOON -> repeat(3) { i ->
            val k = (t * 1.5f + i / 3f) % 1f
            drawCircle(p.night.reward.copy(alpha = .35f * (1f - k)), r * (1.02f + k * .22f), c, style = Stroke(r * .012f + 1f))
        }
        ThemeId.SPRING -> repeat(8) { i ->
            val a = i * 2 * PI / 8 - PI / 2
            val pc = c + Offset((cos(a) * r * 1.13f).toFloat(), (sin(a) * r * 1.13f).toFloat())
            petal(pc, r * .1f, if (i % 2 == 0) Color(0xFFF2A7BC) else Color(0xFFF8C9D6), (a * 180 / PI).toFloat() + 90f)
        }
        ThemeId.DIWALI -> {
            val cols = listOf(Color(0xFFF2A93B), Color(0xFFB5297A), Color(0xFFF5E6C8))
            repeat(24) { i ->
                val a = i * 2 * PI / 24
                drawCircle(cols[i % 3], r * (if (i % 2 == 0) .035f else .022f),
                           c + Offset((cos(a) * r * 1.12f).toFloat(), (sin(a) * r * 1.12f).toFloat()))
            }
        }
        else -> Unit
    }
}

fun hasAnimatedDial(id: ThemeId) = id == ThemeId.MONSOON

/** Sky extras: Christmas star at the core, Eid crescent, Monsoon rain, Winter snow. */
fun DrawScope.drawSkyDecor(id: ThemeId, p: DvPalette, core: Offset, t: Float) {
    when (id) {
        ThemeId.CHRISTMAS -> star(core, size.minDimension * .045f, Color(0xFFE2C25A), outline = White)
        ThemeId.EID -> crescent(Offset(size.width * .86f, size.height * .1f), size.minDimension * .05f, Color(0xFFE3C46A))
        ThemeId.RAMADAN -> crescent(Offset(size.width * .86f, size.height * .1f), size.minDimension * .045f, Color(0xFFE8C46A))
        ThemeId.MONSOON -> particles(Rect(0f, 0f, size.width, size.height), 26, t, 1.6f) { c, _ ->
            drawLine(White.copy(alpha = .16f), c, c + Offset(-4f, 14f), strokeWidth = 1.6f, cap = StrokeCap.Round)
        }
        ThemeId.WINTER -> particles(Rect(0f, 0f, size.width, size.height), 26, t, .5f) { c, i ->
            drawCircle(White.copy(alpha = if (i % 3 == 0) .5f else .28f), if (i % 3 == 0) 3f else 2f, c)
        }
        else -> Unit
    }
}

fun hasAnimatedSky(id: ThemeId) = id == ThemeId.MONSOON || id == ThemeId.WINTER

/**
 * A theme tile's little page: ground, band, the theme's signature at tile size.
 * Sticker draws a die-cut card with a hard shadow, High contrast black on white.
 */
fun DrawScope.drawTile(id: ThemeId, p: DvPalette, dpPx: Float) {
    val w = size.width; val h = size.height
    when (id) {
        ThemeId.STICKER -> {
            drawRect(p.ground)
            val card = Rect(w * .14f, h * .22f, w * .78f, h * .78f)
            drawRoundRect(Ink, card.topLeft + Offset(3f * dpPx, 3f * dpPx), card.size, CornerRadius(6f * dpPx))
            drawRoundRect(White, card.topLeft, card.size, CornerRadius(6f * dpPx))
            drawRoundRect(Ink, card.topLeft, card.size, CornerRadius(6f * dpPx), style = Stroke(1.6f * dpPx))
            drawCircle(Ink, 9.5f * dpPx, Offset(w * .6f, h * .24f))
            drawCircle(Color(0xFFF2C14E), 8f * dpPx, Offset(w * .6f, h * .24f))
            return
        }
        ThemeId.HIGH_CONTRAST -> {
            drawRect(White)
            drawRect(Color.Black, topLeft = Offset(w * .12f, h * .58f), size = Size(w * .5f, 5f * dpPx))
            drawRect(Color.Black, topLeft = Offset(w * .12f, h * .72f), size = Size(w * .34f, 5f * dpPx))
            drawCircle(Color(0xFF0047FF), 10f * dpPx, Offset(w * .58f, h * .38f))
            return
        }
        else -> Unit
    }
    drawRect(p.ground)
    val bandH = h * .42f
    if (p.band != null) drawRect(p.band, size = Size(w, bandH))
    // the theme's actor and reward, small, so tiles still hint at the palette
    drawCircle(p.action, 6f * dpPx, Offset(w * .2f, h * .78f))
    drawRoundRect(p.reward, topLeft = Offset(w * .34f, h * .75f), size = Size(w * .24f, 5f * dpPx), cornerRadius = CornerRadius(3f * dpPx))
    // the signature, scaled down: unit = 0.55dp
    val u = .55f * dpPx
    val area = Rect(0f, bandH - 80f * u, w, bandH)
    when (id) {
        ThemeId.SPRING -> listOf(Offset(w * .2f, h * .14f), Offset(w * .55f, h * .26f), Offset(w * .82f, h * .12f)).forEachIndexed { i, c -> petal(c, 5f * dpPx, if (i % 2 == 0) Color(0xFFE88AA6) else Color(0xFFF2A7BC), i * 50f) }
        ThemeId.SUMMER -> sun(Offset(w * .74f, h * .2f), 6f * dpPx, White, White)
        ThemeId.MONSOON -> for (i in 0 until 6) { val x = w * (.12f + i * .15f); drawLine(White.copy(alpha = .6f), Offset(x, h * .08f + (i % 2) * 6 * dpPx), Offset(x - 3 * dpPx, h * .08f + (i % 2) * 6 * dpPx + 9 * dpPx), strokeWidth = 1.4f * dpPx, cap = StrokeCap.Round) }
        ThemeId.AUTUMN -> { leaf(Offset(w * .3f, h * .2f), 6f * dpPx, Color(0xFFF7D27A), Color(0xFF8A3E1E), -30f); leaf(Offset(w * .72f, h * .16f), 5f * dpPx, Color(0xFFE9A15A), Color(0xFF8A3E1E), 40f) }
        ThemeId.WINTER -> { snowflake(Offset(w * .3f, h * .2f), 5f * dpPx, White); snowflake(Offset(w * .72f, h * .14f), 4f * dpPx, White); drawCircle(White, 1.6f * dpPx, Offset(w * .52f, h * .3f)) }
        ThemeId.CHRISTMAS -> { val y = bandH - 5 * dpPx; val b = listOf(Color(0xFFE2C25A), Color(0xFFC8323F), White, Color(0xFF7FC4A0)); for (i in 0 until 5) drawCircle(b[i % 4], 3.2f * dpPx, Offset(w * (.12f + i * .19f), y + (i % 2) * 2 * dpPx)) }
        ThemeId.DIWALI -> for (i in 0 until 3) diya(Offset(w * (.22f + i * .28f), bandH - 9 * dpPx), 13f * dpPx, Color(0xFFC9692A), Color(0xFFF5B84A))
        ThemeId.PONGAL -> { var x = 5 * dpPx; while (x < w) { drawCircle(Color(0xFF7A3F12), 1.6f * dpPx, Offset(x, bandH - 4 * dpPx)); x += 8 * dpPx } }
        ThemeId.RAMADAN -> { crescent(Offset(w * .74f, h * .2f), 7f * dpPx, Color(0xFFE8C46A)); lantern(Offset(w * .32f, 0f), bandH * .95f, Color(0xFFE8C46A), Color(0xFFE8C46A)) }
        ThemeId.HOLI -> { splash(Offset(w * .16f, h * .14f), 7f * dpPx, Color(0xFFF06FA4)); splash(Offset(w * .55f, h * .1f), 5f * dpPx, Color(0xFFFFD23F)); splash(Offset(w * .86f, h * .22f), 6f * dpPx, Color(0xFF4C7FEA)) }
        ThemeId.EID -> { val y = h * .3f; drawLine(Color(0xFFD9C27E), Offset(4 * dpPx, y), Offset(w - 4 * dpPx, y), strokeWidth = dpPx); for (i in 0 until 4) star(Offset(w * (.14f + i * .24f), y), 4.5f * dpPx, Color(0xFFB8912F), points = 8, inner = .55f) }
        ThemeId.MIST -> drawLine(p.action.copy(alpha = .5f), Offset(w * .1f, h * .3f), Offset(w * .9f, h * .3f), strokeWidth = 1.3f * dpPx)
        ThemeId.SANDALWOOD -> drawLine(Color(0xFFB08D57), Offset(w * .1f, h * .3f), Offset(w * .9f, h * .3f), strokeWidth = 2.2f * dpPx)
        ThemeId.LOTUS -> lotus(Offset(w * .5f, h * .3f), 9f * dpPx, Color(0xFFB0476B))
        ThemeId.HUSH -> crescent(Offset(w * .5f, h * .28f), 8f * dpPx, Color(0xFF9F86C4))
        ThemeId.PAPER_NOTEBOOK -> {
            for (i in 1..4) drawLine(Color(0xFF9AA3B5).copy(alpha = .6f), Offset(0f, h * i * .17f), Offset(w, h * i * .17f), strokeWidth = .8f * dpPx)
            drawLine(Color(0xFFC0392B).copy(alpha = .7f), Offset(w * .16f, 0f), Offset(w * .16f, h), strokeWidth = 1.2f * dpPx)
        }
        else -> Unit
    }
}
