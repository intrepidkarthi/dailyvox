//
//  StarBirthLiveActivity.swift
//  DailyVoxWidgets
//
//  Brief Live Activity that fires immediately after the user completes a voice
//  entry. Lives for ~8 seconds then auto-dismisses. Celebrates the "new star"
//  in the user's inner sky.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct StarBirthLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StarBirthActivityAttributes.self) { context in
            StarBirthLockScreenView(context: context)
                .activityBackgroundTint(WP.cream)
                .activitySystemActionForegroundColor(WP.inkSoft)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(starColor(for: context.attributes.moodRaw))
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("+1")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        Text("A new star appeared in your sky")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Text(streakLine(context.state))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                Image(systemName: "star.fill")
                    .foregroundStyle(starColor(for: context.attributes.moodRaw))
            } compactTrailing: {
                Text("+1")
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "star.fill")
                    .foregroundStyle(starColor(for: context.attributes.moodRaw))
            }
            .keylineTint(starColor(for: context.attributes.moodRaw))
        }
    }
}

@available(iOS 16.2, *)
private struct StarBirthLockScreenView: View {
    let context: ActivityViewContext<StarBirthActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(starColor(for: context.attributes.moodRaw).opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .foregroundStyle(starColor(for: context.attributes.moodRaw))
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("A new star appeared in your sky")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(lsWarmInk)
                Text(streakLine(context.state))
                    .font(.caption)
                    .foregroundStyle(lsWarmInkMute)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(context.state.totalStars)")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(lsWarmInk)
                Text("stars")
                    .font(.caption2)
                    .foregroundStyle(lsWarmInkMute)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

@available(iOS 16.2, *)
private func streakLine(_ state: StarBirthActivityAttributes.ContentState) -> String {
    if state.streak <= 1 {
        return "First star tonight. Your inner sky is forming."
    }
    return "Day \(state.streak) — your constellation is growing."
}

/// Mirrors Mood.color from the main app, scoped to the strings the app passes in.
@available(iOS 16.2, *)
func starColor(for moodRaw: String) -> Color {
    switch moodRaw {
    case "happy": return .yellow
    case "calm": return .mint
    case "grateful": return .pink
    case "excited": return .orange
    case "tired": return .purple
    case "anxious": return .indigo
    case "sad": return .blue
    case "angry": return .red
    default: return WP.gold // warm gold
    }
}
