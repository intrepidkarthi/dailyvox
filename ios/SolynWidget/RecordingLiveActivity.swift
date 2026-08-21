//
//  RecordingLiveActivity.swift
//  DailyVoxWidgets
//
//  Live Activity shown while the user is recording a voice entry.
//  - Lock Screen: warm card with elapsed time, soft target progress, waveform glyph.
//  - Dynamic Island compact: timer pill + small mic / waveform.
//  - Dynamic Island expanded: large timer + live waveform.
//  - Dynamic Island minimal: mic glyph only.
//

import ActivityKit
import WidgetKit
import SwiftUI

// Warm dark text for the light ivory Lock-Screen background. The system renders
// Live Activity `.primary`/`.secondary` text as white by default, which is
// unreadable on the ivory tint — so the Lock Screen views set these explicitly.
let lsWarmInk = WP.ink      // warm near-black
let lsWarmInkMute = WP.inkSoft     // warm muted
let lsWarmSage = WP.inkSoft        // sage


/// The 42-second ring — §E state ①.
///
/// Gold fills clockwise for the first 42 seconds and then simply stays full: a
/// ring that emptied, flashed, or turned red past the target would tell someone
/// mid-sentence that they had run over, which is the opposite of what a journal
/// with a "soft target" is for.

/// §E state ③'s valence bar.
///
/// A gradient from the negative end to the positive with a marker on it, rather
/// than a coloured fill: a bar that turned red would tell someone having a hard
/// night that they were doing it wrong. The gradient is always the whole range,
/// and the marker only says where in it this entry currently sits.
@available(iOS 16.2, *)
struct ValenceBar: View {
    let valence: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(LinearGradient(
                        colors: [WP.coral.opacity(0.55), WP.inkSoft.opacity(0.35), WP.gold],
                        startPoint: .leading, endPoint: .trailing))
                Circle()
                    .fill(.white)
                    .frame(width: 6, height: 6)
                    .offset(x: max(0, min(geo.size.width - 6,
                                          (geo.size.width - 6) * (valence + 1) / 2)))
            }
        }
        .accessibilityLabel("Mood so far")
        .accessibilityValue(valence > 0.2 ? "positive" : (valence < -0.2 ? "heavy" : "even"))
    }
}

@available(iOS 16.2, *)
struct RitualRing: View {
    let elapsed: TimeInterval
    let target: TimeInterval

    private var progress: Double {
        guard target > 0 else { return 0 }
        return min(elapsed / target, 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(WP.gold.opacity(0.22), lineWidth: 2.4)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(WP.gold, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
        .accessibilityLabel("Recording, \(Int(elapsed)) seconds")
    }
}

@available(iOS 16.2, *)
struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock Screen / Notification banner presentation
            RecordingLockScreenView(context: context)
                .activityBackgroundTint(WP.cream) // ivory
                .activitySystemActionForegroundColor(WP.inkSoft) // sage
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(context.state.paused ? WP.inkSoft : WP.coral)
                            .frame(width: 7, height: 7)
                        // "0:28 / 0:42" — elapsed against the ritual, which is
                        // what the canvas shows. Elapsed alone lost the only
                        // number that gives it meaning.
                        Text(elapsedString(context.state.elapsed)
                             + " / " + elapsedString(context.attributes.softTargetSeconds))
                            .font(.dv(size: 13, weight: .semibold, design: .monospaced))
                            .foregroundStyle(.primary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // Top-right, per the canvas — the claim sits at the edge of
                    // the island where it reads as a status, not a caption.
                    Text("0 BYTES OUT")
                        .font(.dv(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(WP.goldNight)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 8) {
                        // The phrase is the point of this view: proof it writes
                        // itself on the phone. It leads, at a readable size,
                        // with no waveform competing — the compact island
                        // already carries the waveform.
                        if !context.state.phrase.isEmpty {
                            Text("\u{201C}\(context.state.phrase)\u{201D}")
                                .font(.dv(size: 14))
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .multilineTextAlignment(.leading)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(context.state.paused ? "Paused" : "Listening\u{2026}")
                                .font(.dv(size: 14))
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        ValenceBar(valence: context.state.valence)
                            .frame(height: 4)

                        if #available(iOS 17.0, *) {
                            HStack(spacing: 10) {
                                Button(intent: DiscardRecordingIntent()) {
                                    Text("Discard")
                                        .font(.dv(size: 12, weight: .bold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                }
                                .tint(WP.navySurface)

                                Button(intent: FinishRecordingIntent()) {
                                    Text("Finish \u{2726}")
                                        .font(.dv(size: 12, weight: .bold, design: .rounded))
                                        .frame(maxWidth: .infinity)
                                }
                                .tint(WP.gold)
                            }
                            .buttonStyle(.borderedProminent)
                            .padding(.top, 2)
                        }
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                // §E1, read off the canvas: a gold DOT on the left, the 42-second
                // ring on the RIGHT — wrapped around the camera on that side —
                // with the waveform between them. This was built inverted, ring
                // left and waveform right, which put the dial on the wrong side
                // of the lens and lost the "recording" dot entirely.
                HStack(spacing: 4) {
                    Circle()
                        .fill(context.state.paused ? WP.inkSoft : WP.coral)
                        .frame(width: 7, height: 7)
                    WaveformGlyph(level: CGFloat(context.state.level), bars: 4)
                        .frame(width: 16, height: 12)
                }
            } compactTrailing: {
                // §E2: when the graph catches a name the island shows it, then
                // goes back to listening. `caughtName` clears itself after a
                // beat — see LiveTranscriber.announce.
                if let name = context.state.caughtName, !name.isEmpty {
                    HStack(spacing: 3) {
                        IslandStar(colour: WP.gold)
                            .frame(width: 11, height: 11)
                        Text(name)
                            .font(.dv(size: 12, weight: .bold, design: .rounded))
                            .foregroundStyle(WP.gold)
                            .lineLimit(1)
                    }
                } else {
                    RitualRing(elapsed: context.state.elapsed,
                               target: context.attributes.softTargetSeconds)
                        .frame(width: 18, height: 18)
                }
            } minimal: {
                RitualRing(elapsed: context.state.elapsed,
                           target: context.attributes.softTargetSeconds)
                    .frame(width: 18, height: 18)
            }
            .keylineTint(WP.gold) // warm gold
        }
    }
}

@available(iOS 16.2, *)
private struct RecordingLockScreenView: View {
    let context: ActivityViewContext<RecordingActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
                    .font(.dv(.title3))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recording your entry")
                    .font(.dv(.subheadline, weight: .semibold))
                    .foregroundStyle(lsWarmInk)
                Text(subtitle)
                    .font(.dv(.caption))
                    .foregroundStyle(lsWarmInkMute)
                WaveformGlyph(level: CGFloat(context.state.level), bars: 28)
                    .frame(height: 18)
            }

            Spacer()

            Text(elapsedString(context.state.elapsed))
                .font(.dv(.title2, design: .monospaced, weight: .semibold))
                .foregroundStyle(lsWarmInk)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var subtitle: String {
        if context.state.passedSoftTarget {
            return "Past your daily 42 — keep going as long as you like."
        }
        let remaining = max(0, Int(context.attributes.softTargetSeconds - context.state.elapsed))
        return "\(remaining)s to your daily 42"
    }
}

// MARK: - Helpers

@available(iOS 16.2, *)
private func elapsedString(_ elapsed: TimeInterval) -> String {
    let total = max(0, Int(elapsed.rounded()))
    let minutes = total / 60
    let seconds = total % 60
    return String(format: "%d:%02d", minutes, seconds)
}

@available(iOS 16.2, *)
private func progressLine(state: RecordingActivityAttributes.ContentState, attributes: RecordingActivityAttributes) -> String {
    if state.passedSoftTarget {
        return "You're past 42s. Tap the app to stop when ready."
    }
    let remaining = max(0, Int(attributes.softTargetSeconds - state.elapsed))
    return "\(remaining)s to your daily 42"
}

/// Lightweight sparkline of equal-width bars whose central bars are scaled by `level`.
/// No animation — driven entirely by ContentState updates.
struct WaveformGlyph: View {
    let level: CGFloat
    let bars: Int

    var body: some View {
        GeometryReader { proxy in
            let barWidth = max(2, (proxy.size.width / CGFloat(bars)) - 2)
            HStack(spacing: 2) {
                ForEach(0..<bars, id: \.self) { i in
                    let distance = abs(CGFloat(i) - CGFloat(bars) / 2) / (CGFloat(bars) / 2)
                    let envelope = 1 - distance * distance
                    let amplitude = max(0.15, level) * envelope
                    Capsule()
                        .fill(WP.gold) // warm gold
                        .frame(width: barWidth, height: max(3, proxy.size.height * amplitude))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
