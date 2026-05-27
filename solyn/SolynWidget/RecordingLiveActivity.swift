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

@available(iOS 16.2, *)
struct RecordingLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RecordingActivityAttributes.self) { context in
            // Lock Screen / Notification banner presentation
            RecordingLockScreenView(context: context)
                .activityBackgroundTint(Color(red: 0.96, green: 0.94, blue: 0.89)) // ivory
                .activitySystemActionForegroundColor(Color(red: 0.32, green: 0.40, blue: 0.36)) // sage
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "mic.fill")
                            .foregroundStyle(.red)
                        Text("Recording")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(elapsedString(context.state.elapsed))
                        .font(.title3.monospacedDigit().weight(.semibold))
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        WaveformGlyph(level: CGFloat(context.state.level), bars: 22)
                            .frame(height: 28)
                        Text(progressLine(state: context.state, attributes: context.attributes))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 4)
                }
            } compactLeading: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            } compactTrailing: {
                Text(elapsedString(context.state.elapsed))
                    .font(.caption2.monospacedDigit().weight(.semibold))
                    .foregroundStyle(.primary)
            } minimal: {
                Image(systemName: "mic.fill")
                    .foregroundStyle(.red)
            }
            .keylineTint(Color(red: 0.831, green: 0.647, blue: 0.278)) // warm gold
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
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Recording your entry")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                WaveformGlyph(level: CGFloat(context.state.level), bars: 28)
                    .frame(height: 18)
            }

            Spacer()

            Text(elapsedString(context.state.elapsed))
                .font(.title2.monospacedDigit().weight(.semibold))
                .foregroundStyle(.primary)
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
                        .fill(Color(red: 0.831, green: 0.647, blue: 0.278)) // warm gold
                        .frame(width: barWidth, height: max(3, proxy.size.height * amplitude))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}
