package com.dailyvox.app.audio

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteBuffer
import java.nio.ByteOrder
import kotlin.math.abs
import kotlin.math.sqrt

/**
 * Prosody extracted from the recording — the Android half of the engine's
 * `ProsodyFeatures` contract (DailyVoxTwinEngine/ProsodyFeatures.swift:50).
 *
 * Field names and units are copied from that file deliberately. The engine folds
 * these as DELTA FROM BASELINE, so absolute values only have to be internally
 * consistent per person; what must not drift is the definition of each number,
 * because an Android "speakingRate" that meant something different from the iOS
 * one would corrupt a shared baseline without ever looking wrong.
 *
 * Everything here is platform: MediaExtractor and MediaCodec decode the AAC,
 * and the DSP is a few hundred lines of arithmetic. No dependency, no model, and
 * nothing that needs the network — which is the same standard the rest of the
 * app is held to.
 */
data class ProsodyFeatures(
    val speakingRate: Double,
    val pitchMean: Double,
    val pitchVariability: Double,
    val energyMean: Double,
    val energyVariability: Double,
    val pauseRatio: Double,
    val longPauseCount: Int,
    val durationSeconds: Double,
) {
    val available: Boolean get() = durationSeconds > 0.0

    companion object {
        val UNAVAILABLE = ProsodyFeatures(0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0, 0.0)
    }
}

object Prosody {

    private const val FRAME_MS = 25
    private const val HOP_MS = 10
    private const val LONG_PAUSE_MS = 500

    // Human speech F0. Below 70Hz is almost always a halving error, above 400Hz
    // an octave error, so the search is bounded rather than trusting the peak.
    private const val F0_MIN = 70.0
    private const val F0_MAX = 400.0

    /**
     * @param wordCount from the transcript, so speaking rate is words per second
     *   of VOICED audio rather than per second of wall clock — a long silence
     *   should not make someone look like a slow talker.
     */
    fun analyse(file: File, wordCount: Int): ProsodyFeatures {
        val (pcm, sampleRate) = decode(file) ?: return ProsodyFeatures.UNAVAILABLE
        return analyse(pcm, sampleRate, wordCount)
    }

    /**
     * The DSP, split from decoding so it can be tested on the JVM. MediaCodec
     * only exists on a device, and without this split the entire pitch, energy
     * and pause analysis would be verifiable only by ear on an emulator that
     * has no microphone.
     */
    fun analyse(pcm: ShortArray, sampleRate: Int, wordCount: Int): ProsodyFeatures {
        if (pcm.isEmpty() || sampleRate <= 0) return ProsodyFeatures.UNAVAILABLE

        val frame = sampleRate * FRAME_MS / 1000
        val hop = sampleRate * HOP_MS / 1000
        if (pcm.size < frame * 2) return ProsodyFeatures.UNAVAILABLE

        val rms = ArrayList<Double>((pcm.size - frame) / hop + 1)
        var i = 0
        while (i + frame <= pcm.size) {
            var sum = 0.0
            for (j in i until i + frame) { val s = pcm[j] / 32768.0; sum += s * s }
            rms.add(sqrt(sum / frame))
            i += hop
        }
        if (rms.isEmpty()) return ProsodyFeatures.UNAVAILABLE

        // Adaptive floor. A fixed threshold fails on both a whisper and a noisy
        // room; the 20th percentile approximates this recording's own noise
        // floor, and voiced frames have to clear it by a real margin.
        val sorted = rms.sorted()
        val floor = sorted[(sorted.size * 0.20).toInt().coerceIn(0, sorted.size - 1)]
        val peak = sorted[(sorted.size * 0.95).toInt().coerceIn(0, sorted.size - 1)]

        // Below this the clip is silence, however the percentiles fall.
        if (peak < 1e-3) return ProsodyFeatures.UNAVAILABLE

        // The percentile interpolation assumes the recording CONTAINS silence to
        // measure. When it does not — someone talking steadily start to finish —
        // the 20th and 95th percentiles collapse onto the same value, the
        // threshold lands at the signal's own level, and not one frame clears
        // it: a continuous take was reported as having no speech in it at all.
        // Caught by a synthetic constant-amplitude tone, which is the degenerate
        // form of exactly that recording.
        val dynamicRange = peak / floor.coerceAtLeast(1e-9)
        val threshold = if (dynamicRange < 2.0) peak * 0.25
                        else (floor + (peak - floor) * 0.15).coerceAtLeast(1e-4)

        val voiced = rms.map { it > threshold }
        val voicedFrames = voiced.count { it }
        if (voicedFrames < 5) return ProsodyFeatures.UNAVAILABLE

        val voicedSeconds = voicedFrames * HOP_MS / 1000.0
        val totalSeconds = rms.size * HOP_MS / 1000.0

        // Pause structure: runs of unvoiced frames.
        var longPauses = 0
        var run = 0
        voiced.forEach { v ->
            if (!v) run++ else { if (run * HOP_MS >= LONG_PAUSE_MS) longPauses++; run = 0 }
        }
        if (run * HOP_MS >= LONG_PAUSE_MS) longPauses++

        val energies = rms.filterIndexed { idx, _ -> voiced[idx] }
        val energyMean = energies.average()
        val energySd = sd(energies, energyMean)

        // F0 per voiced frame, autocorrelation.
        val pitches = ArrayList<Double>(voicedFrames)
        i = 0
        var f = 0
        while (i + frame <= pcm.size && f < voiced.size) {
            if (voiced[f]) pitch(pcm, i, frame, sampleRate)?.let { pitches.add(it) }
            i += hop; f++
        }
        val pitchMean = if (pitches.isEmpty()) 0.0 else pitches.average()
        val pitchSd = if (pitches.size < 2) 0.0 else sd(pitches, pitchMean)

        return ProsodyFeatures(
            speakingRate = if (voicedSeconds > 0) wordCount / voicedSeconds else 0.0,
            pitchMean = pitchMean,
            pitchVariability = pitchSd,
            energyMean = energyMean,
            energyVariability = energySd,
            pauseRatio = ((rms.size - voicedFrames).toDouble() / rms.size).coerceIn(0.0, 1.0),
            longPauseCount = longPauses,
            durationSeconds = totalSeconds,
        )
    }

    private fun sd(xs: List<Double>, mean: Double): Double =
        if (xs.size < 2) 0.0
        else sqrt(xs.sumOf { (it - mean) * (it - mean) } / (xs.size - 1))

    /**
     * F0 by normalised autocorrelation over the plausible pitch band.
     *
     * Clarity-gated: a frame whose best correlation is weak is unvoiced noise
     * that cleared the energy threshold, and letting it through would drag
     * pitchMean toward whatever the room was doing.
     */
    private fun pitch(pcm: ShortArray, offset: Int, length: Int, sampleRate: Int): Double? {
        val minLag = (sampleRate / F0_MAX).toInt().coerceAtLeast(2)
        val maxLag = (sampleRate / F0_MIN).toInt().coerceAtMost(length - 1)
        if (maxLag <= minLag) return null

        var energy = 0.0
        for (j in 0 until length) { val s = pcm[offset + j].toDouble(); energy += s * s }
        if (energy <= 0.0) return null

        var bestLag = -1
        var bestScore = 0.0
        for (lag in minLag..maxLag) {
            var corr = 0.0
            var lagEnergy = 0.0
            for (j in 0 until length - lag) {
                val a = pcm[offset + j].toDouble()
                val b = pcm[offset + j + lag].toDouble()
                corr += a * b
                lagEnergy += b * b
            }
            if (lagEnergy <= 0.0) continue
            val score = corr / sqrt(energy * lagEnergy)
            if (score > bestScore) { bestScore = score; bestLag = lag }
        }
        if (bestLag <= 0 || bestScore < 0.35) return null
        return sampleRate.toDouble() / bestLag
    }

    /** Decode the AAC/MP4 to 16-bit mono PCM. Returns null if the file is not
     *  decodable — a missing recording must degrade to "no prosody", never throw. */
    private fun decode(file: File): Pair<ShortArray, Int>? = runCatching {
        val extractor = MediaExtractor()
        extractor.setDataSource(file.absolutePath)

        var track = -1
        var format: MediaFormat? = null
        for (t in 0 until extractor.trackCount) {
            val fmt = extractor.getTrackFormat(t)
            if (fmt.getString(MediaFormat.KEY_MIME)?.startsWith("audio/") == true) {
                track = t; format = fmt; break
            }
        }
        if (track < 0 || format == null) return null
        extractor.selectTrack(track)

        val sampleRate = format.getInteger(MediaFormat.KEY_SAMPLE_RATE)
        val channels = format.getInteger(MediaFormat.KEY_CHANNEL_COUNT)
        val codec = MediaCodec.createDecoderByType(format.getString(MediaFormat.KEY_MIME)!!)
        codec.configure(format, null, null, 0)
        codec.start()

        val out = ArrayList<Short>(sampleRate * 60)
        val info = MediaCodec.BufferInfo()
        var sawInputEnd = false
        var sawOutputEnd = false

        while (!sawOutputEnd) {
            if (!sawInputEnd) {
                val inIndex = codec.dequeueInputBuffer(10_000)
                if (inIndex >= 0) {
                    val buf = codec.getInputBuffer(inIndex)!!
                    val size = extractor.readSampleData(buf, 0)
                    if (size < 0) {
                        codec.queueInputBuffer(inIndex, 0, 0, 0, MediaCodec.BUFFER_FLAG_END_OF_STREAM)
                        sawInputEnd = true
                    } else {
                        codec.queueInputBuffer(inIndex, 0, size, extractor.sampleTime, 0)
                        extractor.advance()
                    }
                }
            }
            val outIndex = codec.dequeueOutputBuffer(info, 10_000)
            if (outIndex >= 0) {
                val buf = codec.getOutputBuffer(outIndex)!!
                val shorts = buf.order(ByteOrder.nativeOrder()).asShortBuffer()
                val chunk = ShortArray(shorts.remaining())
                shorts.get(chunk)
                // Downmix to mono: pitch and energy are per-speaker, and a stereo
                // interleave would read as an octave artefact.
                if (channels > 1) {
                    var k = 0
                    while (k + channels <= chunk.size) {
                        var acc = 0
                        for (c in 0 until channels) acc += chunk[k + c]
                        out.add((acc / channels).toShort())
                        k += channels
                    }
                } else {
                    chunk.forEach { out.add(it) }
                }
                codec.releaseOutputBuffer(outIndex, false)
            }
            if (info.flags and MediaCodec.BUFFER_FLAG_END_OF_STREAM != 0) sawOutputEnd = true
        }

        codec.stop(); codec.release(); extractor.release()
        ShortArray(out.size) { out[it] } to sampleRate
    }.getOrNull()
}
