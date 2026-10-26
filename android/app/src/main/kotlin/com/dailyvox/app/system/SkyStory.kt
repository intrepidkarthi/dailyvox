package com.dailyvox.app.system

import android.content.res.Resources
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import com.dailyvox.app.R
import com.dailyvox.app.data.Entry
import java.time.ZoneId
import java.util.Random
import kotlin.math.abs
import kotlin.math.cos
import kotlin.math.sin

/**
 * "Share your sky, never your words": the constellation as a 9:16 Story card,
 * sized for Instagram Stories and WhatsApp Status (1080 x 1920).
 *
 * THE CARD CANNOT SEE THE JOURNAL. Drawing is split into two steps on purpose:
 *
 *  1. [shape] reads the entries and keeps NUMBERS ONLY -- how many nights, how
 *     many named stars the Twin sky would draw, and the timestamps that seed
 *     where the small stars fall. No text, no names, no moods.
 *  2. [draw] takes that [Shape] plus the fixed [Copy] and nothing else.
 *
 * So there is no path by which an entry's words reach a pixel: the function
 * that draws never receives an Entry. The tests feed an entry with a unique
 * token and check it appears nowhere in the shape, the copy or the TalkBack
 * description.
 *
 * Moods are left out too. The Twin screen tints each small star by valence; on
 * a public card that tint would be a mood chart, so every star here is cream.
 *
 * Rendered on the phone with Canvas (same reason as [Shareables]: no Window
 * needed) and handed to the system share sheet. The app sends nothing.
 */
object SkyStory {

    const val WIDTH = 1080
    const val HEIGHT = 1920

    /** Where the card points. Printed on it and in the share text. */
    const val URL = "getdailyvox.com/sky"

    /** Same cap as the Twin sky and iOS ConstellationView.maxDrawnStars. */
    private const val MAX_TWINKLES = 156

    /** What the card is allowed to know about a journal. Numbers only. */
    data class Shape(
        /** Distinct local days with an entry -- the streak's "days spoken". */
        val nights: Int,
        /** Bright stars around the core, as on the Twin screen (at most 4). */
        val brightStars: Int,
        /** Timestamps seeding where the small stars fall. Never printed. */
        val twinkleSeeds: List<Long>,
    )

    /** Every word the card can carry, all from string resources. */
    data class Copy(
        val eyebrow: String,
        val headline: String,
        val line: String,
        val footer: String,
        /** Read by TalkBack for the preview image. */
        val description: String,
        /** Goes beside the image in the system share sheet. */
        val shareText: String,
    ) {
        /** Everything that is ever drawn or spoken, for the privacy test. */
        val all: List<String> get() = listOf(eyebrow, headline, line, footer, description, shareText)
    }

    fun shape(entries: List<Entry>, zone: ZoneId = ZoneId.systemDefault()): Shape {
        // The Twin sky's rule: one bright star per entry up to four, and at
        // least one per named person in the top three, so the card is the
        // shape the user already knows. Only the COUNT of names survives.
        val named = entries.flatMap { it.entityList }.toSet().size.coerceAtMost(3)
        return Shape(
            nights = Shareables.nights(entries, zone),
            brightStars = maxOf(minOf(entries.size, 4), named).coerceAtMost(4),
            twinkleSeeds = entries.sortedBy { it.createdAt }.drop(4)
                .take(MAX_TWINKLES).map { it.createdAt },
        )
    }

    fun copy(res: Resources, nights: Int): Copy = Copy(
        eyebrow = res.getString(R.string.sky_story_eyebrow),
        headline = res.getQuantityString(R.plurals.sky_story_headline, nights, nights),
        line = res.getString(R.string.sky_story_line),
        footer = res.getString(R.string.sky_story_footer, URL),
        description = res.getQuantityString(R.plurals.sky_story_description, nights, nights),
        shareText = res.getQuantityString(R.plurals.sky_story_share_text, nights, nights, URL),
    )

    // ── drawing ────────────────────────────────────────────────────────────

    private const val INK = "#101B2D"
    private const val CREAM = "#F1EDE2"
    private const val GOLD = "#D9A441"
    private const val GOLD_TEXT = "#EDCB86"
    private const val BLUE = "#9DC1E4"

    // Instagram and WhatsApp draw their own chrome over roughly the top 250 px
    // and the bottom 300 px of a Story. Nothing that has to be read sits there.
    private const val SAFE_TOP = 300f
    private const val SKY_TOP = 340f
    private const val SKY_H = 980f
    private const val MARGIN = 96f

    /**
     * Draws the card. Takes a [Shape] and a [Copy] only -- never an Entry --
     * which is the structural half of "never your words".
     */
    fun draw(c: Canvas, shape: Shape, copy: Copy) {
        val w = WIDTH.toFloat()
        val h = HEIGHT.toFloat()
        c.drawColor(Color.parseColor(INK))

        // Background dust, seeded so the same journal always draws the same card.
        val rng = Random(shape.twinkleSeeds.firstOrNull() ?: (shape.nights * 7919L + 42L))
        val dot = Shareables.paint()
        repeat(260) {
            dot.color = Color.argb(14 + rng.nextInt(60), 241, 237, 226)
            c.drawCircle(rng.nextFloat() * w, rng.nextFloat() * h, 1f + rng.nextFloat() * 2f, dot)
        }

        drawConstellation(c, shape)

        val eyebrow = Shareables.mono(26f, GOLD_TEXT).apply { textAlign = Paint.Align.CENTER }
        c.drawText(copy.eyebrow, w / 2f, SAFE_TOP, eyebrow)

        val headline = Shareables.display(104f, CREAM).apply { textAlign = Paint.Align.CENTER }
        fitWidth(headline, copy.headline, w - 2 * MARGIN)
        val headY = SKY_TOP + SKY_H + 100f
        c.drawText(copy.headline, w / 2f, headY, headline)

        val line = Shareables.body(34f).apply { textAlign = Paint.Align.CENTER }
        var y = headY + 80f
        balanced(copy.line, line, w - 2 * MARGIN).take(3).forEach {
            c.drawText(it, w / 2f, y, line); y += 48f
        }

        // The quiet footer: the mark, then "DailyVox · getdailyvox.com/sky".
        // Below the words, and above the strip Stories covers with its reply bar.
        val footer = Shareables.mono(26f, "#B3F1EDE2").apply { textAlign = Paint.Align.CENTER }
        fitWidth(footer, copy.footer, w - 2 * MARGIN - 60f)
        val fy = maxOf(y + 60f, h - 260f)
        val fw = footer.measureText(copy.footer)
        Shareables.star(c, w / 2f - fw / 2f - 30f, fy - 9f, 14f, Color.parseColor(GOLD))
        c.drawText(copy.footer, w / 2f + 10f, fy, footer)
    }

    /**
     * The Twin screen's sky, on Canvas: two dashed orbit rings, bright stars on
     * curved links out of a gold core, a comet and a blue body on the rings, and
     * the rest of the journal as small stars. Same anchors, same bows, same cap.
     * Static, since a PNG cannot twinkle.
     */
    private fun drawConstellation(c: Canvas, shape: Shape) {
        val w = WIDTH.toFloat()
        val h = SKY_H
        val cx = w / 2f
        val cy = SKY_TOP + h * 0.47f
        val minDim = minOf(w, h)

        // The Twin sky's centre glow, as it looks on screen: gold at 22% fading
        // to nothing. Part of the sky art, not UI chrome.
        val glowR = minDim * 0.62f
        c.drawCircle(cx, cy, glowR, Shareables.paint().apply {
            shader = android.graphics.RadialGradient(
                cx, cy, glowR, Color.argb(56, 217, 164, 65), Color.TRANSPARENT,
                android.graphics.Shader.TileMode.CLAMP)
        })

        val ring = Shareables.paint().apply {
            style = Paint.Style.STROKE; strokeWidth = 2.5f
            pathEffect = android.graphics.DashPathEffect(floatArrayOf(3f, 18f), 0f)
        }
        val rInner = minDim * 0.20f
        val rOuter = minDim * 0.33f
        ring.color = Color.argb(46, 241, 237, 226); c.drawCircle(cx, cy, rInner, ring)
        ring.color = Color.argb(30, 241, 237, 226); c.drawCircle(cx, cy, rOuter, ring)

        // Small stars first, so the bright ones sit on top.
        val dot = Shareables.paint()
        shape.twinkleSeeds.forEachIndexed { i, seed ->
            var s = seed xor (i * 7919L)
            fun rnd(): Float {
                s = s * 6364136223846793005L + 1442695040888963407L
                return ((s ushr 33) % 10000) / 10000f
            }
            val px = rnd() * w
            val py = SKY_TOP + rnd() * h
            if (abs(px - cx) < w * 0.10f && abs(py - cy) < h * 0.12f) return@forEachIndexed
            dot.color = Color.argb(150, 241, 237, 226)
            c.drawCircle(px, py, 3.2f + (i % 3) * 0.9f, dot)
        }

        val anchors = listOf(
            (cx - w * 0.23f) to (cy - h * 0.21f),
            (cx + w * 0.24f) to (cy - h * 0.16f),
            (cx - w * 0.17f) to (cy + h * 0.28f),
            (cx + w * 0.22f) to (cy + h * 0.23f),
        )
        val link = Shareables.paint().apply { style = Paint.Style.STROKE; strokeWidth = 3.5f }
        val node = Shareables.paint()
        repeat(shape.brightStars.coerceIn(0, anchors.size)) { i ->
            val (px, py) = anchors[i]
            val mx = (cx + px) / 2f; val my = (cy + py) / 2f
            val dx = px - cx; val dy = py - cy
            val len = kotlin.math.sqrt(dx * dx + dy * dy).coerceAtLeast(1f)
            val bow = if (i % 2 == 0) 0.22f else -0.18f
            link.color = Color.argb(128 - i * 15, 217, 164, 65)
            c.drawPath(Path().apply {
                moveTo(cx, cy)
                quadTo(mx + (-dy / len) * len * bow, my + (dx / len) * len * bow, px, py)
            }, link)
            val colour = when (i) { 1 -> BLUE; 3 -> GOLD; else -> CREAM }
            node.color = Color.parseColor(colour)
            node.alpha = 38
            c.drawCircle(px, py, 30f - i * 2.5f, node)
            node.alpha = 255
            c.drawCircle(px, py, 16f - i * 1.4f, node)
        }

        node.color = Color.argb(56, 217, 164, 65)
        c.drawCircle(cx, cy, 50f, node)
        node.color = Color.parseColor(GOLD)
        c.drawCircle(cx, cy, 30f, node)

        // Comet on the outer ring, tail behind it; a blue body on the inner one.
        val comet = 38.0
        repeat(6) { k ->
            val a = Math.toRadians(comet - 90.0 - k * 2.6)
            node.color = Color.argb((70 * (1f - k / 6f)).toInt(), 217, 164, 65)
            c.drawCircle(cx + (rOuter * cos(a)).toFloat(), cy + (rOuter * sin(a)).toFloat(),
                         (8f - k * 1.1f).coerceAtLeast(1.6f), node)
        }
        val ca = Math.toRadians(comet - 90.0)
        node.color = Color.parseColor(GOLD)
        c.drawCircle(cx + (rOuter * cos(ca)).toFloat(), cy + (rOuter * sin(ca)).toFloat(), 7f, node)
        val ba = Math.toRadians(212.0 - 90.0)
        node.color = Color.parseColor(BLUE)
        c.drawCircle(cx + (rInner * cos(ba)).toFloat(), cy + (rInner * sin(ba)).toFloat(), 5.5f, node)
    }

    /** Shrinks a paint until [text] fits, for long translations and "365". */
    private fun fitWidth(p: Paint, text: String, max: Float) {
        while (p.measureText(text) > max && p.textSize > 18f) p.textSize -= 2f
    }

    /**
     * Wraps into as few lines as [max] allows, then narrows the width while the
     * line count holds, so the last line is not a lone word.
     */
    private fun balanced(text: String, p: Paint, max: Float): List<String> {
        val lines = wrap(text, p, max)
        var width = max
        var best = lines
        while (width > max / 2f) {
            val next = wrap(text, p, width - 10f)
            if (next.size != lines.size) break
            best = next; width -= 10f
        }
        return best
    }

    private fun wrap(text: String, p: Paint, max: Float): List<String> {
        val out = mutableListOf<String>()
        var line = ""
        text.split(" ").forEach { word ->
            val next = if (line.isEmpty()) word else "$line $word"
            if (p.measureText(next) <= max || line.isEmpty()) line = next
            else { out += line; line = word }
        }
        if (line.isNotEmpty()) out += line
        return out
    }
}
