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
    /// Screenshot mode only: the dial scene sets `recordingState` directly, so
    /// the notification that normally hides the bar never fires and the store
    /// frame showed a tab bar over a full-screen recording dial.
    @State private var chromeVisible = ScreenshotScene.current != .recording
    @StateObject private var keyboard = KeyboardObserver()

    var body: some View {
        ZStack(alignment: .bottom) {
            // The Twin tab is navy under both themes (§8.4), so the page behind
            // it is too — otherwise a cream band shows through around the sky.
            (current == .twin ? DS.Palette.navy : theme.backgroundColor)
                .ignoresSafeArea()

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

            // Hidden while the keyboard is up, for the same reason it hides
            // while recording: the screen belongs to one task at a time.
            //
            // This is the fix for "the tap goes to the thing behind the bar".
            // With a keyboard present SwiftUI lifts the bar as a sibling of the
            // focused view, and the lifted bar's hit region does not reliably
            // follow it — so there was a bar on screen that could not be
            // pressed. Dismissing the keyboard brings it straight back.
            if chromeVisible && !keyboard.isVisible {
                DailyVoxTabBar(current: $current)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        // Dark while the sky is showing, whatever the theme: the status bar sits
        // on navy there, and black glyphs on it are unreadable.
        // The bar is pinned to the real bottom of the screen and never lifted by
        // the keyboard; it is hidden instead. Without this SwiftUI still shifts
        // the ZStack while the bar is on its way out, which is the half-lifted
        // state that swallowed taps.
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .animation(.easeOut(duration: 0.22), value: keyboard.isVisible)
        .environment(\.dailyVoxKeyboardVisible, keyboard.isVisible)
        .preferredColorScheme(current == .twin ? .dark : theme.selectedTheme.colorScheme)
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

/// Whether a keyboard is on screen.
///
/// SwiftUI exposes no environment value for this, and the floating tab bar has
/// to know. Left to its own devices, SwiftUI applies keyboard avoidance to the
/// bar as a sibling of the focused content and lifts it into a position where it
/// is drawn but not reliably hit-tested — a bar you can see, tap, and have the
/// tap land on whatever is behind it.
///
/// Notification-based rather than a `GeometryReader` on the keyboard safe-area
/// inset: the inset is exactly the thing being suppressed below, so reading it
/// back would be circular.
private struct KeyboardVisibleKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    /// True while a keyboard is on screen. Read by `dailyVoxBarClearance` so a
    /// screen does not keep reserving room for a bar that is not there.
    var dailyVoxKeyboardVisible: Bool {
        get { self[KeyboardVisibleKey.self] }
        set { self[KeyboardVisibleKey.self] = newValue }
    }
}

final class KeyboardObserver: ObservableObject {
    @Published private(set) var isVisible = false

    private var observers: [NSObjectProtocol] = []

    init() {
        let centre = NotificationCenter.default
        observers.append(centre.addObserver(
            forName: UIResponder.keyboardWillShowNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.isVisible = true
        })
        observers.append(centre.addObserver(
            forName: UIResponder.keyboardWillHideNotification, object: nil, queue: .main
        ) { [weak self] _ in
            self?.isVisible = false
        })
    }

    deinit { observers.forEach(NotificationCenter.default.removeObserver) }
}

/// The floating pill bar (spec §3): inset 18, white container by day, #1C2A42 by
/// night, active tab a filled pill — green by day, gold by night — and labels
/// always visible.
///
/// Hand-built rather than a styled `TabView`. The system bar cannot be inset
/// from the screen edge, and on iOS 26 it renders Liquid Glass that ignores the
/// container colour entirely, so the two would never have matched.
struct DailyVoxTabBar: View {
    /// The pill: a 44pt tab row + 10 container padding + 10 bottom inset.
    ///
    /// This said 62 while the bar actually measured about 45, so every screen's
    /// clearance was computed from a number that was never true. It is derived
    /// from the parts now, and the parts are named.
    static let tabMinHeight: CGFloat = 44
    static let barHeight: CGFloat = tabMinHeight + 10 + 10

    /// What SCROLL CONTENT must clear — the bar plus the home-indicator strip
    /// it floats above. A docked view is already inside the safe area, so it
    /// wants `barHeight`; adding this to it stacks the safe area twice and
    /// leaves a visible band of nothing.
    static let reservedHeight: CGFloat = barHeight + 34

    @Binding var current: Destination
    @ObservedObject private var theme = ThemeManager.shared

    /// Night when the theme says so, OR when the Twin tab is showing.
    ///
    /// This is the seam that made always-night look like a bug the first time:
    /// the sky went navy and the bar underneath stayed cream, so the screen
    /// read as half-loaded rather than as a different kind of place.
    private var night: Bool { theme.isNight || current == .twin }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Destination.allCases) { d in
                tab(d)
            }
        }
        .padding(5)
        .background(container)
        .padding(.horizontal, 18)
        // 10, not 4. At 4 the pill sits inside the home-indicator strip, where
        // the system claims the first touch for its own swipe gesture — which
        // is why tabs needed tapping twice.
        .padding(.bottom, 10)
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
            ? (night ? DS.Palette.navy : Color.white)
            : (night ? DS.Palette.navyText.opacity(0.6) : theme.secondaryTextColor)

        Button {
            HapticManager.shared.selectionChanged()
            withAnimation(.spring(response: 0.32, dampingFraction: 0.82)) {
                current = d
            }
        } label: {
            Text(d.title)
                // The active/inactive weight was lost in the typography sweep:
                // the old call passed `active ? .heavy : .bold` and the
                // converter only understood literal weights, so it silently
                // dropped it and every tab rendered regular.
                .font(.dv(size: 11, weight: active ? .heavy : .bold, design: .rounded))
                .foregroundColor(fg)
                // 44pt minimum — Apple's floor, and the actual bug. The label
                // was 10.5pt plus 9 above and below, giving a 31pt target at the
                // very bottom of the screen. It was not that taps were being
                // handled wrongly; there was barely anything there to tap.
                .frame(maxWidth: .infinity, minHeight: Self.tabMinHeight)
                .background(
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(active ? (night ? DS.Palette.gold : theme.accentColor) : Color.clear)
                )
                // Without this the transparent part of an inactive tab is not
                // hit-testable, so three of the four tabs only responded on the
                // few pixels the glyphs actually covered.
                .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
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
                // An opaque base UNDER the glass. At .72 tint alone the journal
                // scrolled visibly through the bar and collided with the labels
                // — the spec's container is a solid pill, not a window.
                .fill(night ? DS.Palette.navySurface : Color.white)
                .glassEffect(
                    .regular.tint(night
                                  ? DS.Palette.navySurface.opacity(0.92)
                                  : Color.white.opacity(0.92)),
                    in: .rect(cornerRadius: 22)
                )
                .shadow(color: Color.black.opacity(night ? 0.34 : 0.12),
                        radius: 16, x: 0, y: 6)
        } else {
            shape
                .fill(night ? DS.Palette.navySurface : Color.white)
                .shadow(color: Color.black.opacity(night ? 0.32 : 0.10),
                        radius: 18, x: 0, y: 6)
        }
    }
}

#Preview {
    ContentView()
        .environment(\.managedObjectContext,
                     PersistenceController.preview.container.viewContext)
}

/// A fade behind the status bar, for screens that scroll under it.
///
/// Every destination hides the navigation bar so it can draw its own header,
/// which means there is nothing between scrolling content and the clock. On the
/// Record screen the greeting scrolled straight into "12:54" and the carrier
/// text and became unreadable — two sets of words occupying the same pixels.
///
/// A gradient rather than a solid: a hard band would read as a broken
/// navigation bar, and the page colour has a bloom in it that a flat fill would
/// cut a straight line across.
struct StatusBarScrim: View {
    @Environment(\.dvTheme) private var theme

    var body: some View {
        GeometryReader { geo in
            let inset = geo.safeAreaInsets.top
            LinearGradient(
                colors: [
                    theme.backgroundColor,
                    theme.backgroundColor,
                    theme.backgroundColor.opacity(0),
                ],
                startPoint: .top, endPoint: .bottom
            )
            .frame(height: inset + 10)
            .frame(maxHeight: .infinity, alignment: .top)
            .ignoresSafeArea(edges: .top)
            .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Keeps scrolling content from colliding with the clock. Applied as an
    /// overlay so it sits above the scroll view without taking part in layout.
    @ViewBuilder
    func dailyVoxStatusBarScrim(enabled: Bool = true) -> some View {
        if enabled {
            overlay(alignment: .top) { StatusBarScrim() }
        } else {
            self
        }
    }
}

/// Bottom room for the floating tab bar — and none when the bar is away.
private struct BarClearance: ViewModifier {
    /// `reservedHeight` normally; `barHeight` for content already docked inside
    /// the safe area.
    let amount: CGFloat
    @Environment(\.dailyVoxKeyboardVisible) private var keyboardVisible

    func body(content: Content) -> some View {
        // Collapses with the bar. Left at full height it reserved 98pt of
        // nothing between the content and the keyboard — most visibly on Ask,
        // where the input pill floated a bar's-worth above the keys it was
        // being typed into.
        content.padding(.bottom, keyboardVisible ? 0 : amount)
    }
}

extension View {
    /// Bottom room for the floating tab bar. Applied to a screen's scroll
    /// CONTENT rather than to the container: modifiers on the container do not
    /// reach through the NavigationStack that each destination sits in.
    func dailyVoxBarClearance() -> some View {
        modifier(BarClearance(amount: DailyVoxTabBar.reservedHeight))
    }

    /// The same, for content that is already docked inside the safe area and so
    /// wants the bar's height rather than the reserved total.
    func dailyVoxDockedBarClearance() -> some View {
        modifier(BarClearance(amount: DailyVoxTabBar.barHeight))
    }
}
