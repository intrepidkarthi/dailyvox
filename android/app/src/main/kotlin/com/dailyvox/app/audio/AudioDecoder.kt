package com.dailyvox.app.audio

import android.media.MediaCodec
import android.media.MediaExtractor
import android.media.MediaFormat
import java.io.File
import java.nio.ByteOrder

/**
 * AAC/MP4 → 16-bit mono PCM.
 *
 * PLUMBING, deliberately. It moves bytes between a platform codec and a
 * ShortArray and computes nothing about the user, which is why it stays in the
 * app while the analysis that consumes it lives in the private Twin engine. The
 * same split exists on iOS: the app extracts with AVFoundation, the engine owns
 * the contract and the folding.
 */
object AudioDecoder {

    /** Null when the file is not decodable — a missing recording must degrade to
     *  "no prosody", never throw. */
    fun toPcm(file: File): Pair<ShortArray, Int>? = runCatching {
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
