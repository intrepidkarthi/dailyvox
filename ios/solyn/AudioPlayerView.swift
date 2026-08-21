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
    @Environment(\.dvTheme) private var theme
    let audioURL: URL

    private static let barCount = 26

    /// A fixed, plausible waveform rather than a decoded one.
    ///
    /// Reading the real envelope means decoding every clip on every appearance;
    /// the bars exist to make the track scrubbable and to say "this is a voice",
    /// and a stable shape does both without the cost. Deterministic, so a clip
    /// looks the same every time you open it.
    private static func barHeight(_ i: Int) -> CGFloat {
        let a = Foundation.sin(Double(i) * 1.7) * 0.5 + 0.5
        let b = Foundation.sin(Double(i) * 0.6 + 1.1) * 0.5 + 0.5
        return 6 + CGFloat(a * 0.6 + b * 0.4) * 18
    }

    @StateObject private var controller = AudioPlaybackController()
    @State private var loadError: String?

    var body: some View {
        // B4's player: a NAVY card with a gold play disc, a waveform track and
        // the elapsed time. It was a light card with a green circle, a system
        // Slider and a speed pill — an iOS media control sitting inside a design
        // that draws its own.
        //
        // Navy in BOTH themes, like the sky and the recording dial: playing your
        // own voice back is a night moment wherever it happens.
        HStack(spacing: 14) {
            Button {
                controller.togglePlayback()
                HapticManager.shared.buttonTap()
            } label: {
                ZStack {
                    Circle()
                        .fill(DS.Palette.gold)
                        .frame(width: 44, height: 44)
                    if controller.isPlaying {
                        HStack(spacing: 4) {
                            ForEach(0..<2, id: \.self) { _ in
                                RoundedRectangle(cornerRadius: 1.5)
                                    .fill(DS.Palette.navy)
                                    .frame(width: 4, height: 15)
                            }
                        }
                    } else {
                        PlayTriangle()
                            .fill(DS.Palette.navy)
                            .frame(width: 14, height: 16)
                            .offset(x: 1)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(controller.isPlaying ? "Pause" : "Play")

            // The waveform IS the scrubber. Bars fill gold as the audio passes
            // them; dragging seeks.
            GeometryReader { geo in
                let progress = controller.duration > 0
                    ? controller.currentTime / controller.duration : 0
                HStack(spacing: 3) {
                    ForEach(0..<Self.barCount, id: \.self) { i in
                        let lit = Double(i) / Double(Self.barCount) <= progress
                        Capsule()
                            .fill(lit ? DS.Palette.gold
                                      : DS.Palette.navyText.opacity(0.22))
                            .frame(height: Self.barHeight(i))
                    }
                }
                .frame(maxHeight: .infinity, alignment: .center)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0).onChanged { value in
                        let fraction = min(max(value.location.x / geo.size.width, 0), 1)
                        controller.seek(to: fraction * controller.duration)
                    }
                )
            }
            .frame(height: 30)

            Text(formatTime(controller.isPlaying || controller.currentTime > 0
                            ? controller.currentTime : controller.duration))
                .font(.dv(size: 12, weight: .semibold, design: .monospaced))
                .foregroundColor(DS.Palette.navyText.opacity(0.7))
                .monospacedDigit()

            // Speed stays — it is genuinely useful on a long entry — but as a
            // quiet mono label rather than a tinted pill competing with the play
            // button for the eye.
            Button {
                let opts = AudioPlaybackController.speedOptions
                let idx = opts.firstIndex(of: controller.playbackRate) ?? opts.firstIndex(of: 1.0) ?? 0
                controller.setSpeed(opts[(idx + 1) % opts.count])
                HapticManager.shared.selectionChanged()
            } label: {
                Text(speedLabel(controller.playbackRate))
                    .font(.dv(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundColor(DS.Palette.goldNight)
                    .frame(minWidth: 34, minHeight: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Playback speed \(speedLabel(controller.playbackRate))")
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(DS.Palette.navySurface)
        )
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
                    .font(.dv(.caption))
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


/// The play glyph, drawn — SF's `play.fill` sits optically off-centre inside a
/// circle and no amount of offset fixes it at every size.
private struct PlayTriangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
