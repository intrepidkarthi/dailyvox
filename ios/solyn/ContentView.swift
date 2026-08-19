//
//  ContentView.swift
//  solyn
//
//  Main navigation container for the app.
//
//  Created by Karthikeyan NG on 01/12/25.
//

import SwiftUI
import CoreData

/// The four destinations of design spec §3.
///
/// This was five tabs — Record, Journal, Twin, **Insights**, **Settings**. The
/// spec folds Insights into Twin as a segment (it is a reading of the Twin, not
/// a peer of it) and moves Settings behind the Speak header, which is where a
/// setting is actually wanted: while you are looking at the thing it configures.
/// Four is also the point at which a floating pill bar stops needing to shrink
/// its labels to fit.
enum Destination: String, CaseIterable, Identifiable {
    case speak, journal, twin, ask

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speak: return "Speak"
        case .journal: return "Journal"
        case .twin: return "Twin"
        case .ask: return "Ask"
        }
    }

}

struct ContentView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject private var theme = ThemeManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \DiaryEntry.date, ascending: false)],
        animation: .default)
    private var entries: FetchedResults<DiaryEntry>

    /// `-StartTab twin` opens straight onto a destination. Screenshot runs need
    /// to reach a tab without driving taps, and the simulator has no reliable
    /// way to tap a hand-built bar from the command line.
    @State private var current: Destination = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-StartTab"), i + 1 < args.count,
              let d = Destination(rawValue: args[i + 1]) else { return .speak }
        return d
    }()
    /// Hidden while recording, so the dial owns the whole screen (spec §2.2).
    @State private var chromeVisible = true

    var body: some View {
        ZStack(alignment: .bottom) {
            theme.backgroundColor.ignoresSafeArea()

            Group {
                switch current {
                case .speak:
                    NavigationStack { TodayView() }
                case .journal:
                    NavigationStack { TimelineView() }
                case .twin:
                    NavigationStack { DigitalTwinView() }
                case .ask:
                    NavigationStack { TwinChatView() }
                }
            }
            // NOTE: clearance for the floating bar is applied per screen, on
            // the scroll content itself (`.dailyVoxBarClearance()`). Both
            // `safeAreaInset` and `contentMargins` were tried here first and
            // neither survives the NavigationStack in between — the scroll
            // views kept running under the pill.

            if chromeVisible {
                DailyVoxTabBar(current: $current)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .preferredColorScheme(theme.selectedTheme.colorScheme)
        .onReceive(NotificationCenter.default.publisher(for: .dailyVoxRecordingChanged)) { note in
            withAnimation(.easeInOut(duration: 0.22)) {
                chromeVisible = (note.object as? Bool) == false
            }
        }
    }
}

/// Posted by the record screen so the bar can get out of the way.
extension Notification.Name {
    static let dailyVoxRecordingChanged = Notification.Name("dailyVoxRecordingChanged")
}

/// The floating pill bar (spec §3): inset 18, white container by day, #1C2A42 by
/// night, active tab a filled pill — green by day, gold by night — and labels
/// always visible.
///
/// Hand-built rather than a styled `TabView`. The system bar cannot be inset
/// from the screen edge, and on iOS 26 it renders Liquid Glass that ignores the
/// container colour entirely, so the two would never have matched.
struct DailyVoxTabBar: View {
    /// The pill itself: 10.5pt label + 18 vertical padding + 10 container
    /// padding + 4 bottom inset.
    static let barHeight: CGFloat = 62

    /// What SCROLL CONTENT must clear — the bar plus the home-indicator strip
    /// it floats above. A docked view is already inside the safe area, so it
    /// wants `barHeight`; adding this to it stacks the safe area twice and
    /// leaves a visible band of nothing.
    static let reservedHeight: CGFloat = barHeight + 34

    @Binding var current: Destination
    @ObservedObject private var theme = ThemeManager.shared

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Destination.allCases) { d in
                tab(d)
            }
        }
        .padding(5)
        .background(container)
        .padding(.horizontal, 18)
        .padding(.bottom, 4)
    }

    /// Extracted from `body`. Inline, the whole bar was one expression and the
    /// compiler reported it as unable to type-check in reasonable time — the
    /// same failure TimelineView hit, and it does not announce itself until
    /// some unrelated edit tips it over.
    ///
    /// LABELS ONLY. The spec's bar is four words in a pill and nothing else;
    /// the SF Symbols here before were mine, not the design's, and they made a
    /// quiet bar look like a stock tab bar wearing a costume.
    @ViewBuilder
    private func tab(_ d: Destination) -> some View {
        let active = d == current
        let fg: Color = active
            ? (theme.isNight ? DS.Palette.navy : Color.white)
            : theme.secondaryTextColor

        Button {
            HapticManager.shared.selectionChanged()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                current = d
            }
        } label: {
            Text(d.title)
                .font(.system(size: 10.5, weight: active ? .heavy : .bold, design: .rounded))
                .foregroundColor(fg)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 9)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(active ? theme.accentColor : Color.clear)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(d.title)
        .accessibilityAddTraits(active ? [.isSelected, .isButton] : .isButton)
    }

    /// Liquid Glass on iOS 26, a tinted solid before it.
    ///
    /// The glass is tinted rather than clear: the design specifies a white
    /// container by day and #1C2A42 by night, and plain `.regular` glass over a
    /// cream page renders near-white anyway by day but goes muddy over the navy
    /// sky. Tinting keeps the spec's two grounds while still refracting what
    /// scrolls underneath.
    @ViewBuilder
    private var container: some View {
        let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)
        if #available(iOS 26.0, *) {
            shape
                .fill(.clear)
                .glassEffect(
                    .regular.tint(theme.isNight
                                  ? DS.Palette.navySurface.opacity(0.72)
                                  : Color.white.opacity(0.72)),
                    in: .rect(cornerRadius: 22)
                )
        } else {
            shape
                .fill(theme.isNight ? DS.Palette.navySurface : Color.white)
                .shadow(color: Color.black.opacity(theme.isNight ? 0.32 : 0.10),
                        radius: 18, x: 0, y: 6)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext,
                     PersistenceController.preview.container.viewContext)
}

extension View {
    /// Bottom room for the floating tab bar. Applied to a screen's scroll
    /// CONTENT rather than to the container: modifiers on the container do not
    /// reach through the NavigationStack that each destination sits in.
    func dailyVoxBarClearance() -> some View {
        padding(.bottom, DailyVoxTabBar.reservedHeight)
    }
}
