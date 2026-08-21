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


/// The four-point star, drawn rather than borrowed.
///
/// `star.fill` is Apple's five-point rating star and it means "favourite"
/// everywhere else on the phone. This mark means an entry exists, and it is the
/// same path the app, the widget and the share cards all draw.
@available(iOS 16.2, *)
struct IslandStar: View {
    let colour: Color

    var body: some View {
        Canvas { ctx, size in
            let c = CGPoint(x: size.width / 2, y: size.height / 2)
            let s = min(size.width, size.height) / 2
            var p = Path()
            p.move(to: CGPoint(x: c.x, y: c.y - s))
            p.addCurve(to: CGPoint(x: c.x + s, y: c.y),
                       control1: CGPoint(x: c.x + s * 0.055, y: c.y - s * 0.436),
                       control2: CGPoint(x: c.x + s * 0.436, y: c.y - s * 0.055))
            p.addCurve(to: CGPoint(x: c.x, y: c.y + s),
                       control1: CGPoint(x: c.x + s * 0.436, y: c.y + s * 0.055),
                       control2: CGPoint(x: c.x + s * 0.055, y: c.y + s * 0.436))
            p.addCurve(to: CGPoint(x: c.x - s, y: c.y),
                       control1: CGPoint(x: c.x - s * 0.055, y: c.y + s * 0.436),
                       control2: CGPoint(x: c.x - s * 0.436, y: c.y + s * 0.055))
            p.addCurve(to: CGPoint(x: c.x, y: c.y - s),
                       control1: CGPoint(x: c.x - s * 0.436, y: c.y - s * 0.055),
                       control2: CGPoint(x: c.x - s * 0.055, y: c.y - s * 0.436))
            p.closeSubpath()
            ctx.fill(p, with: .color(colour))
        }
    }
}

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
                    // The app's own four-point mark, not SF Symbols' `sparkles`.
                    // This is the star that just landed in the user's sky; it
                    // should be the same shape it will be on the Twin screen.
                    IslandStar(colour: starColor(for: context.attributes.moodRaw))
                        .frame(width: 22, height: 22)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    // §E4 shows the tick itself — "140→141" — not just the new
                    // total. The arrow is the whole point: you watch the sky get
                    // one bigger. A bare number is a stat; this is an event.
                    Text("\(max(context.state.totalStars - 1, 0))\u{2192}\(context.state.totalStars)")
                        .font(.dv(size: 13, weight: .semibold, design: .monospaced))
                        .foregroundStyle(WP.goldNight)
                        .contentTransition(.numericText())
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // The canvas's own words. "Kept" is the verb the rest of
                        // the product uses for saving an entry — "Stop & keep",
                        // "every word stays here" — so the moment it lands should
                        // use it too.
                        Text("Star \(context.state.totalStars) kept")
                            .font(.dv(.subheadline, weight: .semibold))
                            .foregroundStyle(.primary)
                        Text(streakLine(context.state))
                            .font(.dv(.caption))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.top, 2)
                }
            } compactLeading: {
                IslandStar(colour: starColor(for: context.attributes.moodRaw))
                    .frame(width: 16, height: 16)
            } compactTrailing: {
                Text("+1")
                    .font(.dv(.caption2, weight: .semibold))
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
                    .font(.dv(.title3))
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("A new star appeared in your sky")
                    .font(.dv(.subheadline, weight: .semibold))
                    .foregroundStyle(lsWarmInk)
                Text(streakLine(context.state))
                    .font(.dv(.caption))
                    .foregroundStyle(lsWarmInkMute)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 0) {
                Text("\(context.state.totalStars)")
                    .font(.dv(.title3, weight: .semibold))
                    .foregroundStyle(lsWarmInk)
                Text("stars")
                    .font(.dv(.caption2))
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
