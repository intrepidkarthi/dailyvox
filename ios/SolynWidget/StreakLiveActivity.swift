//
//  StreakLiveActivity.swift
//  DailyVoxWidgets
//
//  Persistent Live Activity showing the user's current journaling streak.
//  Started only when the user opts in via Settings → Live Activities.
//

import ActivityKit
import WidgetKit
import SwiftUI

@available(iOS 16.2, *)
struct StreakLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: StreakActivityAttributes.self) { context in
            StreakLockScreenView(context: context)
                .activityBackgroundTint(WP.cream)
                .activitySystemActionForegroundColor(WP.inkSoft)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .foregroundStyle(WP.gold)
                        Text("Day \(context.state.streak)")
                            .font(.headline)
                            .foregroundStyle(.primary)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.hasEntryToday {
                        Label("Today done", systemImage: "checkmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                    } else {
                        Label("Today open", systemImage: "circle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        Text("\(context.state.totalEntries) stars in your inner sky")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer()
                    }
                }
            } compactLeading: {
                Image(systemName: "star.fill")
                    .foregroundStyle(WP.gold)
            } compactTrailing: {
                Text("Day \(context.state.streak)")
                    .font(.caption2.weight(.semibold))
            } minimal: {
                Image(systemName: "star.fill")
                    .foregroundStyle(WP.gold)
            }
            .keylineTint(WP.gold)
        }
    }
}

@available(iOS 16.2, *)
private struct StreakLockScreenView: View {
    let context: ActivityViewContext<StreakActivityAttributes>

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(WP.gold.opacity(0.18))
                    .frame(width: 44, height: 44)
                Image(systemName: "star.fill")
                    .foregroundStyle(WP.gold)
                    .font(.title3)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("Day \(context.state.streak)")
                    .font(.headline)
                    .foregroundStyle(lsWarmInk)
                Text(context.state.hasEntryToday
                     ? "Today's entry is in. \(context.state.totalEntries) stars total."
                     : "Open today — keep the streak alive.")
                    .font(.caption)
                    .foregroundStyle(lsWarmInkMute)
            }

            Spacer()

            Image(systemName: context.state.hasEntryToday ? "checkmark.circle.fill" : "circle.dashed")
                .foregroundStyle(context.state.hasEntryToday ? lsWarmSage : lsWarmInkMute)
                .font(.title2)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}
