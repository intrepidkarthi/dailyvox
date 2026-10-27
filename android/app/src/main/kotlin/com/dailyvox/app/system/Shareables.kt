package com.dailyvox.app.system

import com.dailyvox.app.R
import android.content.res.Resources
import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Path
import android.graphics.Typeface
import android.graphics.fonts.Font
import android.graphics.fonts.FontFamily
import android.graphics.fonts.FontStyle
import android.provider.Settings
import com.dailyvox.app.data.Entry
import java.io.File
import java.time.ZoneId
import java.text.SimpleDateFormat
import java.util.Calendar
import java.util.Date
import java.util.Locale
import java.util.Random
import kotlin.math.cos
import kotlin.math.sin

/**
 * The three cards a person might actually want to post (design §F).
 *
 * The strategy the design states, and the reason this file can exist at all:
 * DailyVox makes zero network calls, so every share is user-made, on-device,
 * through the OS share sheet. The app never uploads a card; it writes a PNG and
 * hands the URI to whatever the user picks. That constraint is the campaign.
 *
 * NAMES ARE REDACTED BY DEFAULT on every card that could carry one. A journal
 * app that makes it one tap to publish "Sarah · 61 nights" has built a
 * privacy incident with a share button, and the default has to be the safe one
 * because the unsafe one is irreversible the moment it is posted.
 *
 * Canvas rather than Compose capture, for the same reason ShareCard uses it:
 * PixelCopy needs a live Window, so a capture path cannot run from a widget or
 * a background share.
 */
object Shareables {

    private const val S = 1080

    // Night palette, fixed. These cards are posted, not themed: a card that
    // renders cream in day mode loses the one thing that makes the sky legible
    // as art in a feed.
    private const val INK = "#101B2D"
    private const val INK_SOFT = "#1C2A42"
    private const val CREAM = "#F1EDE2"
    private const val GOLD = "#D9A441"
    private const val GOLD_TEXT = "#EDCB86"

    enum class Card { MY_SKY, RECEIPT, YEAR_ONE, MILESTONE, WALLPAPER, GIFT }

    /** Nights that mint a one-time card. Scarcity without gamification guilt. */
    val MILESTONES = listOf(42, 100, 365)

    /** Portrait for the lock screen, square for feeds. */
    private fun size(card: Card): Pair<Int, Int> =
        if (card == Card.WALLPAPER) 1080 to 1920 else S to S

    /** The card's name on the share sheet's chips (a string resource). */
    @androidx.annotation.StringRes
    fun titleRes(card: Card): Int = when (card) {
        Card.MY_SKY -> R.string.share_title_my_sky
        Card.RECEIPT -> R.string.share_title_receipt
        Card.YEAR_ONE -> R.string.share_title_year_one
        Card.MILESTONE -> R.string.share_title_milestone
        Card.WALLPAPER -> R.string.share_title_wallpaper
        Card.GIFT -> R.string.share_title_gift
    }

    /** The line under the preview on the share sheet (a string resource). */
    @androidx.annotation.StringRes
    fun captionRes(card: Card): Int = when (card) {
        Card.MY_SKY -> R.string.share_caption_my_sky
        Card.RECEIPT -> R.string.share_caption_receipt
        Card.YEAR_ONE -> R.string.share_caption_year_one
        Card.MILESTONE -> R.string.share_caption_milestone
        Card.WALLPAPER -> R.string.share_caption_wallpaper
        Card.GIFT -> R.string.share_caption_gift
    }

    /**
     * The highest milestone this journal has passed, or null. Nights, not
     * entries: two entries in one evening is one night of showing up.
     */
    fun milestoneReached(entries: List<Entry>, zone: ZoneId = ZoneId.systemDefault()): Int? {
        val nights = nights(entries, zone)
        return MILESTONES.filter { it <= nights }.maxOrNull()
    }

    /**
     * True when the device is in airplane mode. Readable from Settings.Global
     * with no permission at all — which matters, because a card that claims
     * "on airplane mode" has to be checking rather than asserting.
     */
    fun airplaneMode(context: Context): Boolean =
        runCatching {
            Settings.Global.getInt(context.contentResolver, Settings.Global.AIRPLANE_MODE_ON) != 0
        }.getOrDefault(false)

    fun render(context: Context, card: Card, entries: List<Entry>, includeNames: Boolean): File {
        val (w, h) = size(card)
        val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)
        BrandFaces.init(context)
        // The words on a card are the app's, in the reader's language (B-15).
        val r = context.resources
        when (card) {
            Card.MY_SKY -> drawMySky(context, r, c, entries)
            Card.RECEIPT -> drawReceipt(r, c, entries)
            Card.YEAR_ONE -> drawYearOne(r, c, entries, includeNames)
            Card.MILESTONE -> drawMilestone(r, c, entries)
            Card.WALLPAPER -> drawWallpaper(c, entries, h)
            Card.GIFT -> drawGift(r, c, entries)
        }
        val out = File(context.getExternalFilesDir(null), "dailyvox-${card.name.lowercase()}.png")
        out.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bmp.recycle()
        return out
    }

    fun share(context: Context, file: File) = Exporters.share(context, file, "image/png")

    /**
     * Hands the image to whatever can set a wallpaper, via ACTION_ATTACH_DATA.
     *
     * Deliberately NOT WallpaperManager.setBitmap: that needs SET_WALLPAPER in
     * the manifest, and the Data Shield card lists this app's permissions in
     * full as a claim the user can check in Android Settings. Adding a fourth
     * permission to save one tap would cost more than it buys.
     */
    fun setAsWallpaper(context: Context, file: File) {
        val uri = androidx.core.content.FileProvider.getUriForFile(
            context, "${context.packageName}.files", file)
        val intent = android.content.Intent(android.content.Intent.ACTION_ATTACH_DATA).apply {
            setDataAndType(uri, "image/png")
            putExtra("mimeType", "image/png")
            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        runCatching {
            context.startActivity(
                android.content.Intent.createChooser(intent, context.getString(R.string.share_set_wallpaper)).apply {
                    addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                    addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
                }
            )
        }.onFailure { share(context, file) }
    }

    // ── F1 · My Sky ────────────────────────────────────────────────────────

    /**
     * The constellation, with no words on it at all. People post art, not
     * diaries — so this card deliberately carries no transcript, no entity
     * label and no mood, regardless of the redaction toggle. There is nothing
     * here to redact, which is the entire idea.
     */
    private fun drawMySky(context: Context, r: Resources, c: Canvas, entries: List<Entry>) {
        c.drawColor(Color.parseColor(INK))
        val rng = Random(entries.firstOrNull()?.createdAt ?: 42L)
        val dot = paint()

        repeat(140) {
            dot.color = Color.argb(18 + rng.nextInt(70), 241, 237, 226)
            c.drawCircle(rng.nextFloat() * S, 120f + rng.nextFloat() * (S - 420f),
                         1f + rng.nextFloat() * 2.2f, dot)
        }

        val cx = S / 2f
        val cy = S * 0.44f

        // Orbit rings.
        val ring = paint().apply {
            style = Paint.Style.STROKE; strokeWidth = 2f
            color = Color.argb(34, 241, 237, 226)
            pathEffect = android.graphics.DashPathEffect(floatArrayOf(3f, 18f), 0f)
        }
        c.drawCircle(cx, cy, S * 0.17f, ring)
        c.drawCircle(cx, cy, S * 0.28f, ring)

        // Named stars become anonymous points: position carries the shape, the
        // label is what would have carried the person.
        val link = paint().apply { style = Paint.Style.STROKE; strokeWidth = 3f }
        val node = paint()
        entries.take(4).forEachIndexed { i, _ ->
            val a = Math.toRadians(-58.0 + i * 88.0)
            val r = S * (0.23f + (i % 2) * 0.05f)
            val px = cx + (r * cos(a)).toFloat()
            val py = cy + (r * sin(a)).toFloat()
            link.color = Color.argb(120 - i * 14, 217, 164, 65)
            val path = Path().apply {
                moveTo(cx, cy)
                val mx = (cx + px) / 2f; val my = (cy + py) / 2f
                val dx = px - cx; val dy = py - cy
                val len = kotlin.math.sqrt(dx * dx + dy * dy).coerceAtLeast(1f)
                val bow = if (i % 2 == 0) 0.20f else -0.16f
                quadTo(mx + (-dy / len) * len * bow, my + (dx / len) * len * bow, px, py)
            }
            c.drawPath(path, link)
            node.color = Color.parseColor(if (i == 1) "#9DC1E4" else CREAM)
            c.drawCircle(px, py, 15f - i * 1.5f, node)
        }

        node.color = Color.argb(60, 217, 164, 65)
        c.drawCircle(cx, cy, 46f, node)
        node.color = Color.parseColor(GOLD)
        c.drawCircle(cx, cy, 26f, node)

        val nights = nights(entries)
        val label = mono(20f, GOLD_TEXT)
        c.drawText(r.getString(R.string.share_sky_label, nights), 84f, 120f, label)

        if (airplaneMode(context)) {
            // Only when it is actually true. A stamp that is decoration is a
            // lie, and this one is the whole point of the format.
            val stamp = mono(20f, GOLD_TEXT).apply { textAlign = Paint.Align.RIGHT }
            c.drawText(r.getString(R.string.share_sky_airplane), S - 84f, 120f, stamp)
        }

        val big = display(58f, CREAM)
        c.drawText(r.getQuantityString(R.plurals.share_sky_stars, entries.size, entries.size), 84f, S - 268f, big)
        c.drawText(r.getString(R.string.share_sky_zero_uploads), 84f, S - 196f, big)
        c.drawText(r.getString(R.string.share_sky_body), 84f, S - 138f, body(26f))

        footer(c, r.getString(R.string.share_sky_footer))
    }

    // ── F2 · Privacy receipt ───────────────────────────────────────────────

    private fun drawReceipt(r: Resources, c: Canvas, entries: List<Entry>) {
        c.drawColor(Color.parseColor(CREAM))
        val ink = Color.parseColor("#1E2A26")

        val head = mono(30f, "#1E2A26").apply {
            textAlign = Paint.Align.CENTER; letterSpacing = 0.18f
        }
        c.drawText("DAILYVOX", S / 2f, 130f, head)

        val sub = mono(20f, "#6B7A72").apply { textAlign = Paint.Align.CENTER }
        c.drawText(
            r.getString(
                R.string.share_receipt_subtitle,
                // The reader's language (B-13); 1.2 forced Locale.US on every phone.
                LocaleFormat.receiptDate(java.time.LocalDate.now()),
            ),
            S / 2f, 176f, sub,
        )
        dotted(c, 216f)

        val words = entries.sumOf { it.text.split(Regex("\\s+")).count { w -> w.isNotBlank() } }
        // Every figure is either counted from the journal or structurally zero.
        // Nothing on this card is aspirational: there is no network permission
        // in the manifest, so "0" is a fact about the build, not a promise.
        val rows = listOf(
            r.getString(R.string.share_receipt_entries) to "%,d".format(entries.size),
            r.getString(R.string.share_receipt_words) to "%,d".format(words),
            r.getString(R.string.share_receipt_streak) to "%,d".format(streak(entries)),
            r.getString(R.string.share_receipt_network) to "0",
            r.getString(R.string.share_receipt_bytes) to "0",
            r.getString(R.string.share_receipt_ads) to "0",
            r.getString(R.string.share_receipt_accounts) to "0",
            r.getString(R.string.share_receipt_subscription) to r.getString(R.string.share_receipt_free),
        )
        val left = mono(26f, "#1E2A26")
        val right = mono(26f, "#1E2A26").apply { textAlign = Paint.Align.RIGHT }
        var y = 296f
        rows.forEach { (k, v) ->
            c.drawText(k, 96f, y, left)
            c.drawText(v, S - 96f, y, right)
            y += 62f
        }

        dotted(c, y + 8f)
        y += 78f
        val kept = mono(28f, "#8A6A1F")
        c.drawText(r.getString(R.string.share_receipt_stayed_home), 96f, y, kept)
        star(c, S - 118f, y - 10f, 20f, Color.parseColor(GOLD))

        dotted(c, y + 40f)
        val thanks = mono(22f, "#6B7A72").apply { textAlign = Paint.Align.CENTER }
        c.drawText(r.getString(R.string.share_receipt_thanks), S / 2f, y + 108f, thanks)
        c.drawText(r.getString(R.string.share_receipt_footer), S / 2f, y + 150f, thanks)
        // Deliberately no "0 network calls" footer here: the receipt has already
        // itemised it twice, and a third claim starts to sound like protesting.
        // No trailing star either — centred at S-96 it landed on top of the
        // thank-you line.
    }

    // ── F3 · Year One ──────────────────────────────────────────────────────

    private fun drawYearOne(r: Resources, c: Canvas, entries: List<Entry>, includeNames: Boolean) {
        c.drawColor(Color.parseColor(INK))
        val rng = Random(entries.size.toLong() * 7919L)
        val dot = paint()
        repeat(70) {
            dot.color = Color.argb(16 + rng.nextInt(50), 241, 237, 226)
            c.drawCircle(rng.nextFloat() * S, rng.nextFloat() * S, 1f + rng.nextFloat() * 1.8f, dot)
        }

        c.drawText(r.getString(R.string.share_year_label), 84f, 130f, mono(22f, GOLD_TEXT))

        val nights = nights(entries)
        val big = display(66f, CREAM)
        c.drawText(r.getQuantityString(R.plurals.share_year_nights, nights, nights), 84f, 256f, big)
        c.drawText(r.getString(R.string.share_year_one_sky), 84f, 330f, big)

        val brightest = brightestStar(entries)
        val rows = listOf(
            r.getString(R.string.share_year_brightest) to when {
                brightest == null -> r.getString(R.string.share_year_brightest_none)
                // Redacted by default. The count still communicates the shape of
                // the year without naming a real person to a public feed.
                !includeNames -> r.getQuantityString(R.plurals.share_year_brightest_redacted, brightest.value, brightest.value)
                else -> r.getQuantityString(R.plurals.share_year_brightest_named, brightest.value, brightest.key, brightest.value)
            },
            r.getString(R.string.share_year_warmest) to warmestMonth(entries),
            r.getString(R.string.share_year_word) to
                (mostSaidWord(entries)?.let { r.getString(R.string.share_year_word_quoted, it) } ?: "—"),
            r.getString(R.string.share_year_computed) to r.getString(R.string.share_year_computed_value),
        )
        val k = body(26f, "#99F1EDE2")
        val v = body(26f, CREAM).apply { textAlign = Paint.Align.RIGHT; typeface = BrandFaces.inter(700) }
        var y = 470f
        rows.forEach { (key, value) ->
            c.drawText(key, 84f, y, k)
            c.drawText(value, S - 84f, y, v)
            val rule = paint().apply { color = Color.argb(26, 241, 237, 226); strokeWidth = 2f }
            c.drawLine(84f, y + 26f, S - 84f, y + 26f, rule)
            y += 92f
        }

        footer(c, r.getString(R.string.share_year_footer))
    }

    // ── F · milestone stamp ────────────────────────────────────────────────

    /**
     * Nights 42, 100, 365. Scarcity without gamification guilt: there is no
     * streak to protect and nothing is taken away for missing a night — the
     * card simply cannot exist until you have actually spoken that many times.
     */
    private fun drawMilestone(r: Resources, c: Canvas, entries: List<Entry>) {
        val night = milestoneReached(entries) ?: 42
        c.drawColor(Color.parseColor(INK))

        val rng = Random(night.toLong() * 7919L)
        val dot = paint()
        repeat(110) {
            dot.color = Color.argb(16 + rng.nextInt(64), 241, 237, 226)
            c.drawCircle(rng.nextFloat() * S, rng.nextFloat() * S, 1f + rng.nextFloat() * 2f, dot)
        }

        val cx = S / 2f
        val cy = S * 0.40f

        // A gold seal: concentric rings around the number.
        val ring = paint().apply { style = Paint.Style.STROKE }
        listOf(230f to 3f, 265f to 2f, 300f to 1.5f).forEach { (r, w) ->
            ring.strokeWidth = w
            ring.color = Color.argb((90 - (r - 230) / 2).toInt(), 217, 164, 65)
            c.drawCircle(cx, cy, r, ring)
        }
        c.drawCircle(cx, cy, 196f, paint().apply { color = Color.argb(28, 217, 164, 65) })

        val number = display(150f, GOLD).apply { textAlign = Paint.Align.CENTER }
        c.drawText("$night", cx, cy + 52f, number)

        val label = mono(24f, GOLD_TEXT).apply { textAlign = Paint.Align.CENTER }
        c.drawText(r.getQuantityString(R.plurals.share_milestone_spoken, night), cx, cy + 128f, label)

        val big = display(52f, CREAM).apply { textAlign = Paint.Align.CENTER }
        // Derived from the number on the seal, never a fallback string. A probe
        // with the gate forced open rendered a seal reading 1 under a headline
        // reading "Forty-two nights." — the else branch could disagree with the
        // figure above it, and adding a milestone would have shipped that.
        c.drawText(milestoneHeadline(r, night), cx, S - 236f, big)
        val sub = body(26f).apply { textAlign = Paint.Align.CENTER }
        c.drawText(r.getString(R.string.share_milestone_body), cx, S - 178f, sub)

        footer(c, r.getString(R.string.share_milestone_footer))
    }

    private fun milestoneHeadline(r: Resources, night: Int): String = when (night) {
        365 -> r.getString(R.string.share_milestone_365)
        100 -> r.getString(R.string.share_milestone_100)
        42 -> r.getString(R.string.share_milestone_42)
        1 -> r.getString(R.string.share_milestone_1)
        else -> r.getQuantityString(R.plurals.share_milestone_nights, night, night)
    }

    // ── F · sky wallpaper ──────────────────────────────────────────────────

    /**
     * Portrait, and deliberately quieter than the share card: this one lives
     * behind clock and notifications, so the constellation sits low and there
     * is no headline to be covered up.
     */
    private fun drawWallpaper(c: Canvas, entries: List<Entry>, h: Int) {
        c.drawColor(Color.parseColor(INK))
        val rng = Random(entries.firstOrNull()?.createdAt ?: 42L)
        val dot = paint()
        repeat(240) {
            dot.color = Color.argb(14 + rng.nextInt(64), 241, 237, 226)
            c.drawCircle(rng.nextFloat() * S, rng.nextFloat() * h, 1f + rng.nextFloat() * 2.2f, dot)
        }

        val cx = S / 2f
        // Low, so the clock and the notification stack sit on empty sky.
        val cy = h * 0.63f

        val ring = paint().apply {
            style = Paint.Style.STROKE; strokeWidth = 2f
            color = Color.argb(30, 241, 237, 226)
            pathEffect = android.graphics.DashPathEffect(floatArrayOf(3f, 20f), 0f)
        }
        c.drawCircle(cx, cy, S * 0.20f, ring)
        c.drawCircle(cx, cy, S * 0.32f, ring)

        val link = paint().apply { style = Paint.Style.STROKE; strokeWidth = 3f }
        val node = paint()
        entries.take(5).forEachIndexed { i, _ ->
            val a = Math.toRadians(-70.0 + i * 72.0)
            val r = S * (0.26f + (i % 2) * 0.06f)
            val px = cx + (r * cos(a)).toFloat()
            val py = cy + (r * sin(a)).toFloat()
            link.color = Color.argb(90 - i * 10, 217, 164, 65)
            c.drawPath(Path().apply {
                moveTo(cx, cy)
                val mx = (cx + px) / 2f; val my = (cy + py) / 2f
                val dx = px - cx; val dy = py - cy
                val len = kotlin.math.sqrt(dx * dx + dy * dy).coerceAtLeast(1f)
                val bow = if (i % 2 == 0) 0.18f else -0.15f
                quadTo(mx + (-dy / len) * len * bow, my + (dx / len) * len * bow, px, py)
            }, link)
            node.color = Color.parseColor(if (i == 2) "#9DC1E4" else CREAM)
            c.drawCircle(px, py, 13f - i, node)
        }
        node.color = Color.argb(56, 217, 164, 65)
        c.drawCircle(cx, cy, 52f, node)
        node.color = Color.parseColor(GOLD)
        c.drawCircle(cx, cy, 28f, node)

        // No wordmark, no claim, no count. A wallpaper that advertises at its
        // owner is one they take off within a week.
        val nights = nights(entries)
        val quiet = mono(20f, "#66F1EDE2").apply { textAlign = Paint.Align.CENTER }
        c.drawText("$nights", cx, h - 108f, quiet)
    }

    // ── F · gift a star ────────────────────────────────────────────────────

    private fun drawGift(r: Resources, c: Canvas, entries: List<Entry>) {
        c.drawColor(Color.parseColor(INK_SOFT))
        val cx = S / 2f

        star(c, cx, 300f, 74f, Color.parseColor(GOLD))

        val big = display(60f, CREAM).apply { textAlign = Paint.Align.CENTER }
        c.drawText(r.getQuantityString(R.plurals.share_gift_kept, entries.size, entries.size), cx, 490f, big)
        c.drawText(r.getString(R.string.share_gift_start), cx, 566f, big)

        val sub = body(27f).apply { textAlign = Paint.Align.CENTER }
        c.drawText(r.getString(R.string.share_gift_body_1), cx, 648f, sub)
        c.drawText(r.getString(R.string.share_gift_body_2), cx, 694f, sub)

        // Said out loud because it is unusual and checkable: there is no
        // referral code on this card, and no way to add one -- the app cannot
        // phone home to attribute anything.
        val note = mono(21f, GOLD_TEXT).apply { textAlign = Paint.Align.CENTER }
        c.drawText(r.getString(R.string.share_gift_note), cx, S - 300f, note)

        val url = display(34f, CREAM).apply { textAlign = Paint.Align.CENTER }
        c.drawText("getdailyvox.com", cx, S - 220f, url)

        footer(c, r.getString(R.string.share_gift_footer))
    }

    // ── shared bits ────────────────────────────────────────────────────────

    private fun footer(c: Canvas, claim: String) {
        c.drawText("DailyVox", 84f, S - 58f, display(30f, CREAM))
        star(c, 232f, S - 68f, 13f, Color.parseColor(GOLD))
        val right = mono(19f, "#99F1EDE2").apply { textAlign = Paint.Align.RIGHT }
        c.drawText(claim, S - 84f, S - 58f, right)
    }

    private fun dotted(c: Canvas, y: Float) {
        val p = paint().apply {
            color = Color.parseColor("#B9C4BC"); strokeWidth = 3f
            pathEffect = android.graphics.DashPathEffect(floatArrayOf(4f, 10f), 0f)
        }
        c.drawLine(96f, y, S - 96f, y, p)
    }

    /** The four-point mark, drawn as a path so the card needs no asset. */
    private fun star(c: Canvas, cx: Float, cy: Float, r: Float, colour: Int) {
        val p = Path().apply {
            moveTo(cx, cy - r)
            quadTo(cx + r * 0.18f, cy - r * 0.18f, cx + r, cy)
            quadTo(cx + r * 0.18f, cy + r * 0.18f, cx, cy + r)
            quadTo(cx - r * 0.18f, cy + r * 0.18f, cx - r, cy)
            quadTo(cx - r * 0.18f, cy - r * 0.18f, cx, cy - r)
            close()
        }
        c.drawPath(p, paint().apply { color = colour })
    }

    private fun paint() = Paint().apply { isAntiAlias = true }

    // The brand's three roles (spec §8.2): DM Mono for data, Nunito 800 for
    // headlines, Inter for body. These used to be the platform's MONOSPACE and
    // SANS_SERIF, i.e. Roboto, so every card left the app off-brand.
    private fun mono(size: Float, colour: String) = paint().apply {
        color = Color.parseColor(colour); textSize = size
        typeface = BrandFaces.mono()
        letterSpacing = 0.10f
    }

    private fun display(size: Float, colour: String) = paint().apply {
        color = Color.parseColor(colour); textSize = size
        typeface = BrandFaces.nunito(800)
    }

    private fun body(size: Float, colour: String = "#99F1EDE2") = paint().apply {
        color = Color.parseColor(colour); textSize = size
        typeface = BrandFaces.inter(400)
    }

    /**
     * The live run, by the same rules as every other surface ([Streak]): local
     * days and one grace day a week. A broken run prints 0 here rather than a
     * welcome back, because the receipt is a table of counts.
     */
    /**
     * Local days with an entry, the same count as the Insights "days spoken".
     * UTC days would put a 23:30 entry in California on tomorrow, so the card
     * and the screen it was shared from would disagree.
     */
    internal fun nights(entries: List<Entry>, zone: ZoneId = ZoneId.systemDefault()): Int =
        entries.map { Streak.localDay(it.createdAt, zone) }.distinct().size

    private fun streak(entries: List<Entry>): Int =
        Streak.of(entries.map { it.createdAt }, System.currentTimeMillis(),
                  java.time.ZoneId.systemDefault()).current

    /**
     * The person named on the most entries, from entries whose names the gate
     * can read (B-5). A German entry saved before the gate filed "Arbeit" as a
     * person; on a card titled "Brightest star" that is a claim about a life.
     */
    internal fun brightestStar(entries: List<Entry>): Map.Entry<String, Int>? =
        entries.flatMap { ReadingLanguage.people(it) }.groupingBy { it }.eachCount()
            .maxByOrNull { it.value }

    private fun warmestMonth(entries: List<Entry>): String {
        val best = warmestMonthIndex(entries) ?: return "—"
        // Standalone, in the reader's language (B-13). Was Locale.US.
        return LocaleFormat.monthName(best)
    }

    /**
     * The Calendar.MONTH with the highest mean valence, or null for "—".
     *
     * Only entries the lexicon actually read count, and only when their valence
     * VARIES. A journal the lexicon could not read (another language) used to
     * be all zeros, and the max of equal averages is whichever month came
     * first -- a "Warmest month" printed on a card about nothing.
     *
     * "Read" is the engine gate's word (B-5): a valence counts only where
     * SENTIMENT reads the entry's language ([ReadingLanguage.valence]).
     */
    internal fun warmestMonthIndex(entries: List<Entry>): Int? {
        val read = entries.mapNotNull { e -> ReadingLanguage.valence(e)?.let { e to it } }
        if (read.map { it.second }.distinct().size < 2) return null
        val cal = Calendar.getInstance()
        return read.groupBy { (e, _) ->
            cal.timeInMillis = e.createdAt; cal.get(Calendar.MONTH)
        }.filter { it.value.size >= 3 }
            .maxByOrNull { it.value.map { (_, v) -> v }.average() }
            ?.key
    }

    /**
     * The word this person reaches for. Stop words removed, and gated at three
     * uses so a single memorable entry cannot define someone's year.
     *
     * The tokens and the stop list are English, so only entries the gate reads
     * as English (TRAITS) are counted (B-5). Spanish "mamá" split on [^a-z']
     * was "mam", and Spanish "para" is glue, not a word of the year.
     */
    private fun mostSaidWord(entries: List<Entry>): String? {
        val stop = setOf(
            "the", "and", "for", "was", "were", "have", "has", "had", "with", "that",
            "this", "there", "then", "than", "from", "they", "them", "their", "what",
            "when", "which", "would", "could", "should", "about", "been", "being",
            "just", "like", "some", "more", "most", "much", "very", "into", "over",
            "again", "still", "even", "also", "back", "down", "but", "not", "now",
            "out", "our", "you", "your", "she", "him", "his", "her", "its", "one",
            "all", "any", "are", "can", "did", "get", "got", "how", "too", "who",
            "why", "way", "day", "days", "today", "myself", "really", "think",
            "know", "went", "said", "made", "time", "good", "bad",
            // Fillers. "nothing" is genuinely the most frequent word in some
            // journals, and a card that announces it as your word of the year
            // is a worse brag than no card at all.
            "nothing", "something", "anything", "everything", "thing", "things",
            "much", "many", "little", "lot", "bit", "kind", "sort", "stuff",
        )
        return entries.filter { ReadingLanguage.reads(com.dailyvox.twin.LanguageFeature.TRAITS, it) }.flatMap {
            it.text.lowercase().split(Regex("[^a-z']+")).filter { w -> w.length >= 4 }
        }.filter { it !in stop }
            .groupingBy { it }.eachCount()
            .filter { it.value >= 3 }
            .maxByOrNull { it.value }
            ?.key
    }
}

/**
 * The bundled brand faces, as android.graphics.Typeface for Canvas drawing.
 *
 * Nunito and Inter ship as VARIABLE fonts, and the obvious routes do not pick
 * a weight from one: ResourcesCompat.getFont hands back the file's default
 * instance (the same thin-weight bug Type.kt had), and Typeface.create(base,
 * 800, false) does not move the axis. The weight has to be set on 'wght',
 * which Font.Builder does (API 29; minSdk is 33).
 *
 * System fallback stays on: an entry in Tamil or with an emoji must still
 * render, in the platform face, rather than as tofu on a card someone posts.
 *
 * Cached per weight: building a Font reads the file, and a card asks for the
 * same three or four faces dozens of times.
 */
internal object BrandFaces {
    private lateinit var res: android.content.res.Resources
    private val cache = HashMap<String, Typeface>()

    fun init(context: Context) {
        if (!::res.isInitialized) res = context.applicationContext.resources
    }

    fun nunito(weight: Int) = variable("nunito", com.dailyvox.app.R.font.nunito_variable, weight)
    fun inter(weight: Int) = variable("inter", com.dailyvox.app.R.font.inter_variable, weight)
    /** DM Mono is a static Medium cut, so there is no axis to set. */
    fun mono(): Typeface = face("dmmono", com.dailyvox.app.R.font.dm_mono_medium, 500, null)

    private fun variable(name: String, id: Int, weight: Int) =
        face(name, id, weight, "'wght' $weight")

    @Synchronized
    private fun face(name: String, id: Int, weight: Int, axes: String?): Typeface =
        cache.getOrPut("$name:$weight") {
            runCatching {
                val font = Font.Builder(res, id)
                    .setWeight(weight)
                    .apply { if (axes != null) setFontVariationSettings(axes) }
                    .build()
                Typeface.CustomFallbackBuilder(FontFamily.Builder(font).build())
                    .setStyle(FontStyle(weight, FontStyle.FONT_SLANT_UPRIGHT))
                    .setSystemFallback(if (name == "dmmono") "monospace" else "sans-serif")
                    .build()
            }.getOrElse {
                // A card in the platform face beats no card at all.
                Typeface.create(Typeface.DEFAULT, weight, false)
            }
        }
}
