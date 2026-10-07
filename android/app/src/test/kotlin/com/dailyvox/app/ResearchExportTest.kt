package com.dailyvox.app

import androidx.test.core.app.ApplicationProvider
import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Research
import com.dailyvox.app.system.SelfLabels
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The research export is read by a tool that never sees this app, on the
 * participant's laptop, next to files the iPhone build wrote. A renamed key, a
 * local-time date or an off-canon label fails nothing on the phone -- it fails
 * there, after the participant has done the hard part. So the output is parsed
 * back and checked against the contract (dailyvox-research-export/1), not
 * string-matched against the writer.
 *
 * Robolectric only for org.json, the parser; the writer itself is plain JVM.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class ResearchExportTest {

    private val device = Research.Device("DV-7K3Q-M9", "1.1", "Android 15", "Google Pixel 9")

    // 2026-09-01T21:04:00Z
    private val t0 = 1_788_296_640_000L

    private fun entry(
        id: String, at: Long, label: String?, text: String = id,
        seconds: Int = 42, audio: String? = "a.m4a",
    ) = Entry(id = id, text = text, createdAt = at, durationSec = seconds, valence = 0f,
              audioPath = audio, selfLabel = label)

    private fun export(vararg e: Entry) =
        JSONObject(Research.export(e.toList(), device, exportedAtMs = 1_791_367_200_000L))

    @Test
    fun `top level matches the contract`() {
        val json = export(entry("a", t0, "joy"))
        assertEquals(
            setOf("schema", "consent_version", "participant_code", "platform", "app_version",
                  "os_version", "device_model", "exported_at", "entry_count", "entries"),
            json.keys().asSequence().toSet(),
        )
        assertEquals("dailyvox-research-export/1", json.getString("schema"))
        assertEquals("3.0", json.getString("consent_version"))
        assertEquals("DV-7K3Q-M9", json.getString("participant_code"))
        assertEquals("android", json.getString("platform"))
        assertEquals("1.1", json.getString("app_version"))
        assertEquals("Android 15", json.getString("os_version"))
        assertEquals("Google Pixel 9", json.getString("device_model"))
        assertEquals("2026-10-07T10:00:00Z", json.getString("exported_at"))
        assertEquals(1, json.getInt("entry_count"))
    }

    @Test
    fun `entries carry exactly the contract fields, in UTC`() {
        // Milliseconds are truncated: iOS writes whole seconds.
        val e = export(entry("a", t0 + 999, "joy")).getJSONArray("entries").getJSONObject(0)
        assertEquals(setOf("id", "created_at", "text", "self_label", "input", "duration_sec"),
                     e.keys().asSequence().toSet())
        assertEquals("a", e.getString("id"))
        assertEquals("2026-09-01T21:04:00Z", e.getString("created_at"))
        assertEquals("joy", e.getString("self_label"))
        assertEquals(42, e.getInt("duration_sec"))
    }

    @Test
    fun `labelled only, oldest first, canon only`() {
        val json = export(
            entry("third", t0 + 3_000, "sadness"),
            entry("first", t0 + 1_000, "neutral"),
            entry("unlabelled", t0 + 2_000, null),
            entry("calm", t0 + 2_500, "calm"),
            entry("tired", t0 + 2_600, "tired"),
            entry("second", t0 + 1_500, "anxious"),
        )
        val arr = json.getJSONArray("entries")
        val ids = (0 until arr.length()).map { arr.getJSONObject(it).getString("id") }
        assertEquals(listOf("first", "second", "third"), ids)
        assertEquals(3, json.getInt("entry_count"))
        val canon = setOf("joy", "sadness", "anger", "fear", "surprise", "disgust", "neutral")
        (0 until arr.length()).forEach {
            assertTrue(arr.getJSONObject(it).getString("self_label") in canon)
        }
        assertEquals("anxious exports as fear", "fear", arr.getJSONObject(1).getString("self_label"))
    }

    @Test
    fun `typed only when there is no audio and no duration`() {
        val arr = export(
            entry("typed", t0, "joy", seconds = 0, audio = null),
            entry("voice", t0 + 1, "joy", seconds = 30, audio = "v.m4a"),
            entry("audio-no-duration", t0 + 2, "joy", seconds = 0, audio = "v.m4a"),
            entry("duration-no-audio", t0 + 3, "joy", seconds = 12, audio = null),
        ).getJSONArray("entries")
        val inputs = (0 until arr.length()).map { arr.getJSONObject(it).getString("input") }
        assertEquals(listOf("typed", "voice", "voice", "voice"), inputs)
    }

    @Test
    fun `transcripts with quotes, newlines and control characters round-trip`() {
        val nasty = "She said \"fine\", \\ really.\nThen\ttab\u0001done"
        val e = export(entry("a", t0, "anger", text = nasty))
            .getJSONArray("entries").getJSONObject(0)
        assertEquals(nasty, e.getString("text"))
    }

    @Test
    fun `empty export is still valid JSON`() {
        val json = export(entry("a", t0, null))
        assertEquals(0, json.getInt("entry_count"))
        assertEquals(0, json.getJSONArray("entries").length())
    }

    @Test
    fun `old Android labels map to the canon where the meaning is the same`() {
        assertEquals("joy", SelfLabels.canonical("joy"))
        assertEquals("sadness", SelfLabels.canonical("sad"))
        assertEquals("anger", SelfLabels.canonical("angry"))
        assertEquals("fear", SelfLabels.canonical("anxious"))
        assertEquals("neutral", SelfLabels.canonical("neutral"))
        // No canon counterpart: unlabelled for research, never guessed.
        assertNull(SelfLabels.canonical("calm"))
        assertNull(SelfLabels.canonical("tired"))
        assertNull(SelfLabels.canonical(null))
        // The canon passes through unchanged.
        SelfLabels.CANON.forEach { (raw, _) -> assertEquals(raw, SelfLabels.canonical(raw)) }
    }

    @Test
    fun `the picker offers the iOS canon in the iOS words`() {
        assertEquals(
            listOf("joy" to "Joy", "sadness" to "Sadness", "anger" to "Anger", "fear" to "Fear",
                   "surprise" to "Surprise", "disgust" to "Disgust", "neutral" to "Neutral"),
            SelfLabels.CANON,
        )
    }

    @Test
    fun `participant code is the contract format and fixed per install`() {
        val pattern = Regex("^DV-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{2}$")
        repeat(500) {
            val c = Research.generateCode()
            assertTrue(c, pattern.matches(c))
            assertTrue(Research.isValidCode(c))
        }
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        val first = Research.participantCode(ctx)
        assertEquals("generated once, not once per export", first, Research.participantCode(ctx))
    }
}
