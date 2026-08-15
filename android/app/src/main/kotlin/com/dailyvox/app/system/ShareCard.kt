package com.dailyvox.app.system

import android.content.Context
import android.graphics.*
import com.dailyvox.app.data.Entry
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * A shareable card for one entry — the night-sky card iOS ships.
 *
 * Rendered to a Bitmap with plain Canvas rather than composed and captured:
 * PixelCopy needs a Window, so a Compose capture path only works while the
 * screen is on-screen and fails outright from a widget or a share intent.
 *
 * Long entries are TRUNCATED, not shrunk. Scaling type down to fit means the
 * card is unreadable at thumbnail size in exactly the feeds it exists for.
 */
object ShareCard {

    private const val W = 1080
    private const val H = 1080

    fun render(context: Context, entry: Entry): File {
        val bmp = Bitmap.createBitmap(W, H, Bitmap.Config.ARGB_8888)
        val c = Canvas(bmp)

        c.drawColor(Color.parseColor("#0F140F"))
        // A faint scatter of stars. Seeded from the entry's own timestamp so the
        // same entry always renders the same card — a card that changes between
        // shares looks broken.
        val rng = Random(entry.createdAt)
        val star = Paint().apply { isAntiAlias = true }
        repeat(90) {
            star.color = Color.argb(20 + rng.nextInt(60), 242, 239, 233)
            c.drawCircle(rng.nextFloat() * W, rng.nextFloat() * H * 0.75f, 1f + rng.nextFloat() * 1.6f, star)
        }

        val amber = Paint().apply {
            isAntiAlias = true; color = Color.parseColor("#E0B15C")
        }
        // The four-point mark, drawn as a path so it needs no asset.
        val p = Path().apply {
            val cx = W / 2f; val cy = 250f; val r = 46f
            moveTo(cx, cy - r)
            cubicTo(cx + r * 0.1f, cy - r * 0.35f, cx + r * 0.35f, cy - r * 0.1f, cx + r, cy)
            cubicTo(cx + r * 0.35f, cy + r * 0.1f, cx + r * 0.1f, cy + r * 0.35f, cx, cy + r)
            cubicTo(cx - r * 0.1f, cy + r * 0.35f, cx - r * 0.35f, cy + r * 0.1f, cx - r, cy)
            cubicTo(cx - r * 0.35f, cy - r * 0.1f, cx - r * 0.1f, cy - r * 0.35f, cx, cy - r)
            close()
        }
        c.drawPath(p, amber)

        val body = Paint().apply {
            isAntiAlias = true; color = Color.parseColor("#F2EFE9")
            textSize = 46f; typeface = Typeface.create(Typeface.SERIF, Typeface.NORMAL)
        }
        val meta = Paint().apply {
            isAntiAlias = true; color = Color.parseColor("#99F2EFE9")
            textSize = 26f; textAlign = Paint.Align.CENTER
        }

        val lines = wrap(entry.text, body, W - 200f).take(9)
        var y = 430f
        lines.forEach { c.drawText(it, 100f, y, body); y += 62f }
        if (wrap(entry.text, body, W - 200f).size > 9) {
            c.drawText("…", 100f, y, body)
        }

        c.drawText(
            SimpleDateFormat("d MMMM yyyy", Locale.getDefault()).format(Date(entry.createdAt)),
            W / 2f, H - 150f, meta,
        )
        meta.color = Color.parseColor("#E0B15C")
        meta.textSize = 22f
        c.drawText("DAILYVOX  ·  RECORDED ON DEVICE", W / 2f, H - 96f, meta)

        val out = File(context.getExternalFilesDir(null), "dailyvox-card.png")
        out.outputStream().use { bmp.compress(Bitmap.CompressFormat.PNG, 100, it) }
        bmp.recycle()
        return out
    }

    private fun wrap(text: String, paint: Paint, max: Float): List<String> {
        val out = mutableListOf<String>()
        var line = StringBuilder()
        text.split(" ").forEach { w ->
            val cand = if (line.isEmpty()) w else "$line $w"
            if (paint.measureText(cand) > max) { out.add(line.toString()); line = StringBuilder(w) }
            else line = StringBuilder(cand)
        }
        if (line.isNotEmpty()) out.add(line.toString())
        return out
    }
}
