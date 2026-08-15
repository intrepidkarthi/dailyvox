package com.dailyvox.app.system

import android.content.Context
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.graphics.Typeface
import android.graphics.pdf.PdfDocument
import androidx.core.content.FileProvider
import com.dailyvox.app.data.Entry
import java.io.File
import java.text.SimpleDateFormat
import java.util.*

/**
 * PDF export and share-sheet handoff.
 *
 * The PDF is the artifact people actually keep — iOS ships it and it is the one
 * export a non-technical user understands. A4 at 72dpi, brand colours, one
 * continuous flow with page breaks by measured height rather than a fixed
 * entries-per-page count, because entry length varies by an order of magnitude.
 */
object Exporters {

    private const val W = 595   // A4 @ 72dpi
    private const val H = 842
    private const val MARGIN = 48f

    fun pdf(context: Context, entries: List<Entry>, authorName: String): File {
        val doc = PdfDocument()
        val ink = Paint().apply { color = Color.parseColor("#0F140F"); isAntiAlias = true }
        val muted = Paint().apply { color = Color.parseColor("#8A8578"); isAntiAlias = true; textSize = 9f }
        val accent = Paint().apply { color = Color.parseColor("#8A4A20"); isAntiAlias = true; textSize = 10f }
        val title = Paint(ink).apply { textSize = 22f; typeface = Typeface.create(Typeface.SERIF, Typeface.BOLD) }
        val body = Paint(ink).apply { textSize = 11f }
        val date = Paint(ink).apply { textSize = 12f; typeface = Typeface.DEFAULT_BOLD }

        var page = doc.startPage(PdfDocument.PageInfo.Builder(W, H, 1).create())
        var canvas: Canvas = page.canvas
        var y = MARGIN + 20f
        var pageNo = 1

        canvas.drawText("DailyVox", MARGIN, y, title); y += 26f
        canvas.drawText(
            if (authorName.isBlank()) "${entries.size} entries" else "$authorName · ${entries.size} entries",
            MARGIN, y, muted
        )
        y += 30f

        fun newPage() {
            doc.finishPage(page); pageNo++
            page = doc.startPage(PdfDocument.PageInfo.Builder(W, H, pageNo).create())
            canvas = page.canvas; y = MARGIN
        }

        val fmt = SimpleDateFormat("EEEE d MMMM yyyy · h:mm a", Locale.getDefault())
        entries.forEach { e ->
            val lines = wrap(e.text, body, W - MARGIN * 2)
            // Page break measured against actual wrapped height, since an entry
            // can be one line or thirty.
            if (y + 34f + lines.size * 15f > H - MARGIN) newPage()
            canvas.drawText(fmt.format(Date(e.createdAt)), MARGIN, y, date); y += 15f
            val meta = buildString {
                append("%d:%02d".format(e.durationSec / 60, e.durationSec % 60))
                append("  ·  mood %+.2f".format(e.valence))
                if (e.entityList.isNotEmpty()) append("  ·  ").append(e.entityList.joinToString(", "))
            }
            canvas.drawText(meta, MARGIN, y, accent); y += 16f
            lines.forEach { canvas.drawText(it, MARGIN, y, body); y += 15f }
            y += 18f
        }
        doc.finishPage(page)

        val out = File(context.getExternalFilesDir(null), "dailyvox-journal.pdf")
        out.outputStream().use { doc.writeTo(it) }
        doc.close()
        return out
    }

    private fun wrap(text: String, paint: Paint, max: Float): List<String> {
        val out = mutableListOf<String>()
        var line = StringBuilder()
        text.split(" ").forEach { w ->
            val candidate = if (line.isEmpty()) w else "$line $w"
            if (paint.measureText(candidate) > max) { out.add(line.toString()); line = StringBuilder(w) }
            else { line = StringBuilder(candidate) }
        }
        if (line.isNotEmpty()) out.add(line.toString())
        return out
    }

    /**
     * Hands a file to the system share sheet via FileProvider — no file:// URIs,
     * which have been blocked since API 24 and throw FileUriExposedException.
     *
     * setClipData is the non-obvious half. EXTRA_STREAM plus a grant flag only
     * authorises the app the user eventually PICKS; the chooser itself runs as a
     * different uid and is denied when it tries to render the preview thumbnail.
     * The observed failure was a share sheet with a broken image where the card
     * should be — the share worked, it just looked broken, which for a card whose
     * entire purpose is to be looked at is the same thing.
     */
    fun share(context: Context, file: File, mime: String) {
        val uri = FileProvider.getUriForFile(context, "${context.packageName}.files", file)
        val intent = android.content.Intent(android.content.Intent.ACTION_SEND).apply {
            type = mime
            putExtra(android.content.Intent.EXTRA_STREAM, uri)
            clipData = android.content.ClipData.newRawUri(file.name, uri)
            addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        context.startActivity(
            android.content.Intent.createChooser(intent, "Share").apply {
                addFlags(android.content.Intent.FLAG_GRANT_READ_URI_PERMISSION)
                addFlags(android.content.Intent.FLAG_ACTIVITY_NEW_TASK)
            }
        )
    }
}
