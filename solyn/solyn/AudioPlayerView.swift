//
//  AudioPlayerView.swift
//  solyn
//
//  Enhanced audio player with progress bar, time display, and speed control.
//

import SwiftUI
import AVFoundation

// MARK: - Audio Playback Controller

final class AudioPlaybackController: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var duration: TimeInterval = 0
    @Published var playbackRate: Float = 1.0

    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    static let speedOptions: [Float] = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0]

    func load(url: URL) throws {
        let player = try AVAudioPlayer(contentsOf: url)
        player.enableRate = true
        player.delegate = self
        player.prepareToPlay()
        self.audioPlayer = player
        self.duration = player.duration
        self.currentTime = 0
    }

    func togglePlayback() {
        guard let player = audioPlayer else { return }
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.rate = playbackRate
            player.play()
            startTimer()
        }
        isPlaying = !isPlaying
    }

    func seek(to time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    func setSpeed(_ rate: Float) {
        playbackRate = rate
        if isPlaying {
            audioPlayer?.rate = rate
        }
    }

    // MARK: - Timer

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            self.currentTime = player.currentTime
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    // MARK: - AVAudioPlayerDelegate

    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        DispatchQueue.main.async {
            self.isPlaying = false
            self.currentTime = 0
            self.stopTimer()
        }
    }

    deinit {
        stopTimer()
        audioPlayer?.stop()
    }
}

// MARK: - Audio Player View

struct AudioPlayerView: View {
    let audioURL: URL

    @StateObject private var controller = AudioPlaybackController()
    @State private var loadError: String?

    var body: some View {
        // Compact single-row player: play · scrubber · tap-to-cycle speed.
        HStack(spacing: DS.Space.sm) {
            Button {
                controller.togglePlayback()
                HapticManager.shared.buttonTap()
            } label: {
                Image(systemName: controller.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 34))
                    .foregroundColor(DS.Palette.sage)
            }
            .buttonStyle(.plain)

            VStack(spacing: 3) {
                Slider(
                    value: Binding(
                        get: { controller.currentTime },
                        set: { controller.seek(to: $0) }
                    ),
                    in: 0...max(0.01, controller.duration)
                )
                .tint(DS.Palette.sage)

                HStack {
                    Text(formatTime(controller.currentTime))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(DS.Palette.inkMute)
                    Spacer()
                    Text(formatTime(controller.duration))
                        .font(.caption2.monospacedDigit())
                        .foregroundColor(DS.Palette.inkMute)
                }
            }

            // Speed — one pill that cycles 0.5x … 2x on tap (was a 6-chip row)
            Button {
                let opts = AudioPlaybackController.speedOptions
                let idx = opts.firstIndex(of: controller.playbackRate) ?? opts.firstIndex(of: 1.0) ?? 0
                controller.setSpeed(opts[(idx + 1) % opts.count])
                HapticManager.shared.selectionChanged()
            } label: {
                Text(speedLabel(controller.playbackRate))
                    .font(.caption.weight(.semibold).monospacedDigit())
                    .foregroundColor(DS.Palette.sageDeep)
                    .frame(minWidth: 38)
                    .padding(.vertical, 7)
                    .padding(.horizontal, 4)
                    .background(Capsule().fill(DS.Palette.sage.opacity(0.14)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Playback speed \(speedLabel(controller.playbackRate))")
        }
        .padding(.vertical, DS.Space.sm)
        .padding(.horizontal, DS.Space.md)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(ThemeManager.shared.warmCardBackground)
        )
        .dsShadowSoft()
        .onAppear {
            do {
                try controller.load(url: audioURL)
            } catch {
                loadError = "Unable to load audio."
            }
        }
        .overlay {
            if let error = loadError {
                Text(error)
                    .font(.caption)
                    .foregroundColor(DS.Palette.coral)
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func speedLabel(_ speed: Float) -> String {
        if speed == 1.0 { return "1x" }
        if speed == floor(speed) { return "\(Int(speed))x" }
        return String(format: "%.1fx", speed).replacingOccurrences(of: ".0x", with: "x")
    }
}
