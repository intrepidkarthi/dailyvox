package com.dailyvox.app.system

import android.content.Context
import com.dailyvox.app.data.Entry
import java.security.SecureRandom
import java.time.Instant
import java.time.format.DateTimeFormatter
import java.time.temporal.ChronoUnit

/**
 * The self-report vocabulary: the preregistered 7-class canon, identical to
 * iOS SelfLabelEmotion -- raw values AND the words on the chips.
 *
 * Android first shipped a different seven (calm, sad, angry, anxious, tired
 * alongside joy and neutral), under a comment claiming they were the iOS set.
 * They were not, and a cohort split across the two phones would have answered
 * two different questions. Stored labels from that set are mapped where the
 * meaning is the same; calm and tired have no counterpart in the canon and are
 * left as they are rather than guessed at.
 */
object SelfLabels {

    /** Raw value to the word the picker shows, in iOS picker order. */
    val CANON: List<Pair<String, String>> = listOf(
        "joy" to "Joy",
        "sadness" to "Sadness",
        "anger" to "Anger",
        "fear" to "Fear",
        "surprise" to "Surprise",
        "disgust" to "Disgust",
        "neutral" to "Neutral",
    )

    private val canonKeys = CANON.map { it.first }.toSet()

    private val LEGACY = mapOf(
        "sad" to "sadness",
        "angry" to "anger",
        "anxious" to "fear",
    )

    /** The canon label a stored value means, or null when it means none of them. */
    fun canonical(stored: String?): String? = when (stored) {
        null -> null
        in canonKeys -> stored
        else -> LEGACY[stored]
    }
}

/**
 * The research export, format `dailyvox-research-export/1`.
 *
 * Written in exactly the same shape as iOS ResearchExport.swift (same keys,
 * same date form; key order and whitespace may differ), because
 * the analysis runs on the participant's own laptop and the tool there reads
 * both phones' files without knowing which is which. A change here that is not
 * made there splits the cohort into two datasets that cannot be pooled.
 *
 * Nothing in this file touches the network: the JSON is handed to a
 * CreateDocument destination the user picks, and goes wherever they take it.
 */
object Research {

    const val SCHEMA = "dailyvox-research-export/1"

    /**
     * The consent text this build's export is covered by. "3.0" is the
     * result-file-only consent: the participant runs the analysis locally and
     * shares numbers, never this file. Same constant as iOS.
     */
    const val CONSENT_VERSION = "3.0"

    private const val PREF_CODE = "researchParticipantCode"

    /** A-Z without I and O, 2-9: nothing that misreads when copied by hand. */
    private const val ALPHABET = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789"
    private val CODE_PATTERN = Regex("^DV-[$ALPHABET]{4}-[$ALPHABET]{2}$")

    data class Device(
        val participantCode: String,
        val appVersion: String,
        val osVersion: String,
        val deviceModel: String,
    )

    /**
     * Random per install and then fixed: it is what joins a result file to a
     * consent form without either carrying a name. Nothing about the person or
     * phone goes into it.
     */
    fun participantCode(context: Context): String {
        val prefs = context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)
        prefs.getString(PREF_CODE, null)?.takeIf { isValidCode(it) }?.let { return it }
        val fresh = generateCode()
        prefs.edit().putString(PREF_CODE, fresh).apply()
        return fresh
    }

    fun generateCode(random: java.util.Random = SecureRandom()): String {
        val c = CharArray(6) { ALPHABET[random.nextInt(ALPHABET.length)] }
        return "DV-" + String(c, 0, 4) + "-" + String(c, 4, 2)
    }

    fun isValidCode(code: String): Boolean = CODE_PATTERN.matches(code)

    fun device(context: Context) = Device(
        participantCode = participantCode(context),
        appVersion = com.dailyvox.app.BuildConfig.VERSION_NAME,
        osVersion = "Android ${android.os.Build.VERSION.RELEASE}",
        deviceModel = "${android.os.Build.MANUFACTURER} ${android.os.Build.MODEL}",
    )

    /**
     * Typed means no audio AND no duration -- the same test the Journal uses
     * to print "TYPED". Either one alone means something was recorded.
     */
    fun input(e: Entry): String =
        if (e.audioPath.isNullOrBlank() && e.durationSec == 0) "typed" else "voice"

    /**
     * Labelled entries only, oldest first. The protocol splits each person's
     * entries by time, so the order is part of the data. An entry whose label
     * has no canon meaning (calm, tired) is left out as unlabelled.
     */
    fun export(entries: List<Entry>, device: Device, exportedAtMs: Long = System.currentTimeMillis()): String {
        val rows = entries
            .mapNotNull { e -> SelfLabels.canonical(e.selfLabel)?.let { e to it } }
            .sortedBy { it.first.createdAt }

        val sb = StringBuilder("{\n")
        fun field(key: String, value: String, last: Boolean = false) {
            sb.append("  ").append(q(key)).append(": ").append(value)
            sb.append(if (last) "\n" else ",\n")
        }
        field("schema", q(SCHEMA))
        field("consent_version", q(CONSENT_VERSION))
        field("participant_code", q(device.participantCode))
        field("platform", q("android"))
        field("app_version", q(device.appVersion))
        field("os_version", q(device.osVersion))
        field("device_model", q(device.deviceModel))
        field("exported_at", q(iso(exportedAtMs)))
        field("entry_count", rows.size.toString())
        sb.append("  ").append(q("entries")).append(": [")
        rows.forEachIndexed { i, (e, label) ->
            sb.append(if (i == 0) "\n" else ",\n")
            sb.append("    {")
            sb.append(q("id")).append(": ").append(q(e.id)).append(", ")
            sb.append(q("created_at")).append(": ").append(q(iso(e.createdAt))).append(", ")
            sb.append(q("text")).append(": ").append(q(e.text)).append(", ")
            sb.append(q("self_label")).append(": ").append(q(label)).append(", ")
            sb.append(q("input")).append(": ").append(q(input(e))).append(", ")
            sb.append(q("duration_sec")).append(": ").append(e.durationSec)
            sb.append("}")
        }
        sb.append(if (rows.isEmpty()) "]\n" else "\n  ]\n")
        sb.append("}\n")
        return sb.toString()
    }

    /**
     * UTC, whole seconds, trailing Z -- "2026-09-01T21:04:00Z", the form iOS's
     * JSONEncoder .iso8601 writes. Truncated so a millisecond fraction never
     * makes the two platforms' dates parse differently.
     */
    internal fun iso(ms: Long): String =
        DateTimeFormatter.ISO_INSTANT.format(Instant.ofEpochMilli(ms).truncatedTo(ChronoUnit.SECONDS))

    /**
     * JSON string literal, written by hand rather than with org.json so the
     * exporter runs in a plain JVM test. Transcripts carry quotes, newlines and
     * the odd control character from the recogniser; all are escaped.
     */
    internal fun q(s: String): String {
        val sb = StringBuilder(s.length + 2).append('"')
        for (ch in s) {
            when (ch) {
                '"' -> sb.append("\\\"")
                '\\' -> sb.append("\\\\")
                '\n' -> sb.append("\\n")
                '\r' -> sb.append("\\r")
                '\t' -> sb.append("\\t")
                '\b' -> sb.append("\\b")
                '\u000C' -> sb.append("\\f")
                else -> if (ch < ' ') sb.append("\\u%04x".format(ch.code)) else sb.append(ch)
            }
        }
        return sb.append('"').toString()
    }
}
