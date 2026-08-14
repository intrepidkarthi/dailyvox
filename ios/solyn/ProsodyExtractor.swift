import Foundation
import AVFoundation
import Accelerate
import DailyVoxTwinEngine

/// v1.6 voice biomarkers — extracts a `ProsodyFeatures` vector from a recorded
/// entry's audio, on-device, for the engine's arousal signal (activated vs your
/// own normal — never a diagnosis). The engine z-scores every feature per
/// person, so absolute units only need to be internally consistent across a
/// user's entries.
///
/// DEVICE-TEST GATE: the energy, pause, and rate features are robust; the pitch
/// (F0) estimate uses frame autocorrelation and should be calibrated on real
/// device audio before the arousal read is trusted. Pitch feeds only one of the
/// three arousal drivers and one baseline-only field, so a weak pitch estimate
/// degrades gracefully (rate + energy still carry the signal).
enum ProsodyExtractor {
    private static let frameLength = 1024      // ~46ms at 22kHz
    private static let hopLength = 512
    private static let silenceRMS: Float = 0.015   // below this a frame is a pause
    private static let longPauseFrames = 8         // ~0.19s of contiguous silence

    /// Extract features from an audio file. `wordCount` (from the transcript)
    /// drives speaking rate. Returns `.unavailable` for missing/too-short audio.
    static func features(from url: URL, wordCount: Int) -> ProsodyFeatures {
        guard let file = try? AVAudioFile(forReading: url) else { return .unavailable }
        let format = file.processingFormat
        let sampleRate = format.sampleRate
        let total = AVAudioFrameCount(file.length)
        guard total > 0,
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: total),
              (try? file.read(into: buffer)) != nil,
              let channel = buffer.floatChannelData?[0] else { return .unavailable }

        let n = Int(buffer.frameLength)
        let durationSeconds = Double(n) / sampleRate
        guard durationSeconds > 0.5 else { return .unavailable }

        // Frame-wise RMS energy + F0.
        var rms: [Float] = []
        var pitches: [Float] = []
        var i = 0
        while i + frameLength <= n {
            let frame = UnsafeBufferPointer(start: channel + i, count: frameLength)
            var energy: Float = 0
            vDSP_rmsqv(frame.baseAddress!, 1, &energy, vDSP_Length(frameLength))
            rms.append(energy)
            if energy >= silenceRMS, let f0 = estimateF0(frame, sampleRate: sampleRate) {
                pitches.append(f0)
            }
            i += hopLength
        }
        guard !rms.isEmpty else { return .unavailable }

        // Energy.
        let energyMean = mean(rms)
        let energyVariability = stddev(rms, mean: energyMean)

        // Pauses.
        let silentFrames = rms.filter { $0 < silenceRMS }.count
        let pauseRatio = Double(silentFrames) / Double(rms.count)
        let longPauseCount = countLongPauses(rms)

        // Voiced duration (frames above silence) → speaking rate from words.
        let voicedFrames = rms.count - silentFrames
        let voicedSeconds = max(0.1, Double(voicedFrames) * Double(hopLength) / sampleRate)
        let speakingRate = Double(wordCount) / voicedSeconds

        // Pitch.
        let pitchMean = pitches.isEmpty ? 0 : Double(mean(pitches))
        let pitchVariability = pitches.count > 1 ? Double(stddev(pitches, mean: Float(pitchMean))) : 0

        return ProsodyFeatures(
            speakingRate: speakingRate,
            pitchMean: pitchMean,
            pitchVariability: pitchVariability,
            energyMean: Double(energyMean),
            energyVariability: Double(energyVariability),
            pauseRatio: pauseRatio,
            longPauseCount: longPauseCount,
            durationSeconds: durationSeconds
        )
    }

    // MARK: - DSP helpers

    /// Frame F0 via normalized autocorrelation over the human speech band
    /// (~80–400 Hz). Coarse by design — calibrate on device audio.
    private static func estimateF0(_ frame: UnsafeBufferPointer<Float>, sampleRate: Double) -> Float? {
        let minLag = Int(sampleRate / 400.0)
        let maxLag = min(Int(sampleRate / 80.0), frame.count - 1)
        guard maxLag > minLag else { return nil }

        var bestLag = -1
        var bestCorr: Float = 0
        var zeroLagEnergy: Float = 0
        vDSP_measqv(frame.baseAddress!, 1, &zeroLagEnergy, vDSP_Length(frame.count))
        guard zeroLagEnergy > 0 else { return nil }

        for lag in minLag...maxLag {
            var corr: Float = 0
            vDSP_dotpr(frame.baseAddress!, 1, frame.baseAddress! + lag, 1, &corr, vDSP_Length(frame.count - lag))
            let normalized = corr / zeroLagEnergy
            if normalized > bestCorr { bestCorr = normalized; bestLag = lag }
        }
        // Require a reasonably periodic frame to accept a pitch.
        guard bestLag > 0, bestCorr > 0.3 else { return nil }
        return Float(sampleRate) / Float(bestLag)
    }

    private static func countLongPauses(_ rms: [Float]) -> Int {
        var count = 0, run = 0
        for e in rms {
            if e < silenceRMS { run += 1 } else { if run >= longPauseFrames { count += 1 }; run = 0 }
        }
        if run >= longPauseFrames { count += 1 }
        return count
    }

    private static func mean(_ x: [Float]) -> Float {
        var m: Float = 0; vDSP_meanv(x, 1, &m, vDSP_Length(x.count)); return m
    }
    private static func stddev(_ x: [Float], mean m: Float) -> Float {
        guard x.count > 1 else { return 0 }
        var acc: Float = 0
        for v in x { let d = v - m; acc += d * d }
        return (acc / Float(x.count - 1)).squareRoot()
    }
}
