//
//  AppearanceView.swift
//  solyn
//
//  Settings → Appearance. One calm page: a live preview of Today in the theme
//  you are looking at, the light/dark mode, and the themes as four short rows
//  of cards. Settings itself carries a single row that leads here.
//
//  This screen draws from the SELECTED theme's palette directly rather than
//  from `DS.Palette`, so it changes the instant a card is tapped without being
//  rebuilt — the rest of the app (and the Settings list behind this page)
//  crossfades to the new theme at the same moment.
//

import SwiftUI

// MARK: - Presenting Settings

enum SettingsRoute: Hashable {
    case appearance
}

/// Settings is presented from the app root, above the view that a new theme
/// rebuilds, so changing theme never closes the sheet you changed it in.
final class SettingsPresenter: ObservableObject {
    static let shared = SettingsPresenter()

    @Published var isPresented: Bool
    @Published var path: [SettingsRoute]

    private init() {
        // Screenshot mode can open Settings, and optionally the Appearance page.
        let args = ProcessInfo.processInfo.arguments
        let screenshot = ScreenshotScene.current == .settings
        isPresented = screenshot
        path = screenshot && args.contains("-ScreenshotAppearance") ? [.appearance] : []
    }

    func open() { isPresented = true }
}

/// The sheet's contents. The Settings list is rebuilt with the theme (it reads
/// `DS.Palette` throughout); the navigation path lives above it, so a pushed
/// Appearance page stays where it is.
struct SettingsSheet: View {
    @ObservedObject private var presenter = SettingsPresenter.shared
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        NavigationStack(path: $presenter.path) {
            SettingsView()
                .id(themeManager.appliedThemeID)
                .navigationDestination(for: SettingsRoute.self) { route in
                    switch route {
                    case .appearance: AppearanceView()
                    }
                }
        }
    }
}

// MARK: - Colours for a palette, by mode

/// The handful of roles these screens need, resolved for day or night.
struct ResolvedPalette {
    let ground: Color, card: Color, ink: Color, inkSoft: Color
    let action: Color, onAction: Color, reward: Color, rule: Color

    init(_ p: ThemePalette, isNight: Bool) {
        ground = Color(hex: isNight ? p.navy : p.ivory)
        card = Color(hex: isNight ? p.navySurface : p.ivory2)
        ink = Color(hex: isNight ? p.navyText : p.ink)
        inkSoft = Color(hex: isNight ? p.navyText : p.inkSoft).opacity(isNight ? 0.72 : 1)
        // Green acts by day; by night the action colour is gold (DVTheme rule).
        action = Color(hex: isNight ? p.gold : p.sage)
        onAction = isNight ? Color(hex: p.navy) : .white
        reward = Color(hex: p.gold)
        rule = Color(hex: isNight ? p.navyText : p.ink).opacity(0.12)
    }
}

// MARK: - Appearance

struct AppearanceView: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isNight: Bool { themeManager.isNight }
    private var palette: ThemePalette { themeManager.themeID.palette(isNight: isNight) }
    private var c: ResolvedPalette { ResolvedPalette(palette, isNight: isNight) }

    var body: some View {
        ScrollViewReader { page in
        ScrollView {
            VStack(alignment: .leading, spacing: DS.Space.xl) {
                MiniTodayPreview(palette: palette, isNight: isNight, decor: themeManager.themeID.decor)
                    .frame(maxWidth: .infinity)
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("Preview of Today in the \(themeManager.themeID.displayName) theme")

                modePicker

                ForEach(ThemeGroup.allCases) { group in
                    themeRow(group)
                        .id(group)
                }
            }
            .padding(.vertical, DS.Space.lg)
        }
        // Opens where the chosen theme is: a Seasons or Festivals choice is
        // below the fold otherwise.
        .onAppear {
            let group = themeManager.themeID.group
            guard group != .bold else { return }
            DispatchQueue.main.async { page.scrollTo(group, anchor: .bottom) }
        }
        }
        .background(c.ground.ignoresSafeArea())
        .navigationTitle("Appearance")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(c.ground, for: .navigationBar)
    }

    // Mode

    private var modePicker: some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            sectionTitle("Mode")
            Picker("Mode", selection: Binding(
                get: { themeManager.selectedTheme },
                set: { new in
                    withAnimation(.easeInOut(duration: 0.25)) { themeManager.selectedTheme = new }
                    HapticManager.shared.themeChanged()
                })
            ) {
                ForEach(AppTheme.allCases) { mode in
                    Text(mode.label).tag(mode)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DS.Space.md)
            Text(themeManager.selectedTheme.explanation)
                .font(.dsCaption)
                .foregroundColor(c.inkSoft)
                .padding(.horizontal, DS.Space.md)
        }
    }

    // Themes

    private func themeRow(_ group: ThemeGroup) -> some View {
        VStack(alignment: .leading, spacing: DS.Space.xs) {
            sectionTitle(group.rawValue)
            ScrollViewReader { row in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: DS.Space.sm) {
                    ForEach(group.themes) { theme in
                        ThemeCard(theme: theme,
                                  isSelected: themeManager.themeID == theme,
                                  labelColor: c.ink,
                                  groundColor: c.ground) {
                            choose(theme)
                        }
                        .id(theme)
                    }
                }
                .padding(.horizontal, DS.Space.md)
                .padding(.vertical, 2)
            }
            // A row whose selected theme is past the edge brings it into view.
            .onAppear {
                if themeManager.themeID.group == group {
                    row.scrollTo(themeManager.themeID, anchor: .center)
                }
            }
            }
            if group == .festivals {
                Text("Festival themes can be used any time.")
                    .font(.dsCaption)
                    .foregroundColor(c.inkSoft)
                    .padding(.horizontal, DS.Space.md)
            }
        }
    }

    private func sectionTitle(_ s: String) -> some View {
        Text(s)
            .font(.dv(.headline, design: .rounded, weight: .bold))
            .foregroundColor(c.ink)
            .padding(.horizontal, DS.Space.md)
            .accessibilityAddTraits(.isHeader)
    }

    private func choose(_ theme: ThemeID) {
        guard theme != themeManager.themeID else { return }
        HapticManager.shared.themeChanged()
        themeManager.themeID = theme
        // The page behind and the rest of the app crossfade to the new theme.
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.3)) {
            themeManager.applyPendingTheme()
        }
    }
}

// MARK: - Theme card

struct ThemeCard: View {
    let theme: ThemeID
    let isSelected: Bool
    let labelColor: Color
    /// The page colour, for the tick inside the selected badge.
    var groundColor: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack(alignment: .topTrailing) {
                    ThemeCardArt(theme: theme)
                    .frame(width: 84, height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(isSelected ? labelColor : labelColor.opacity(0.14),
                                    lineWidth: isSelected ? 2.5 : 1)
                    )

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(groundColor, labelColor)
                            .offset(x: 6, y: -6)
                    }
                }
                Text(theme.displayName)
                    .font(.dv(.caption, weight: isSelected ? .bold : .medium))
                    .foregroundColor(labelColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(width: 88)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.top, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(theme.displayName) theme")
        .accessibilityValue(isSelected ? "selected" : "")
        .accessibilityAddTraits(.isButton)
    }
}

// MARK: - Card art

/// A theme in miniature, with its signature: the band and motif for seasons
/// and festivals, the small mark for calm themes, the die-cut edge for
/// Sticker, black and white for High contrast.
struct ThemeCardArt: View {
    let theme: ThemeID

    var body: some View {
        let p = theme.palette
        let d = theme.decor
        ZStack(alignment: .top) {
            Color(hex: p.ivory)
            VStack(spacing: 0) {
                ZStack {
                    if let band = d.band { Color(hex: band) }
                    if d.hasBand {
                        AmbientLayer(ambient: d.ambient,
                                     colors: d.motifColors.map { Color(hex: $0) },
                                     density: 9, still: true)
                    }
                    HeaderMotifLayer(decor: d, scale: 0.7)
                }
                .frame(height: 24)
                .clipped()
                VStack(spacing: 6) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color(hex: p.ivory2))
                        .frame(height: 13)
                        .overlay(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .stroke(Color(hex: p.ink).opacity(d.card == .soft ? 0.10 : 1),
                                        lineWidth: d.card == .soft ? 1 : 1.5))
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color(hex: p.ink).opacity(d.card == .sticker ? 0.9 : 0))
                                .offset(x: 1.5, y: 2))
                    HStack(spacing: 6) {
                        Circle().fill(Color(hex: p.sage)).frame(width: 17, height: 17)
                            .overlay(Circle().stroke(Color(hex: p.ink), lineWidth: d.card == .sticker ? 1.5 : 0))
                        Circle().fill(Color(hex: d.card == .sticker ? 0xF2C14E : p.gold)).frame(width: 9, height: 9)
                    }
                }
                .padding(.horizontal, 10)
                .padding(.top, 6)
                Spacer(minLength: 0)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Mini Today

/// A small, faithful sketch of the Today screen in a given palette: header,
/// the latest entry, the mood chip, the question, the mic and the tab bar.
struct MiniTodayPreview: View {
    let palette: ThemePalette
    let isNight: Bool
    var decor: ThemeDecor = ThemeDecor()

    var body: some View {
        let c = ResolvedPalette(palette, isNight: isNight)
        let banded = decor.hasBand && !isNight
        let headInk = banded ? Color(hex: decor.bandInk) : c.ink
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("Good morning").font(.dv(size: 11, weight: .bold, design: .rounded))
                        .foregroundColor(banded ? headInk : c.action)
                    Text("Friday").font(.dv(size: 9))
                        .foregroundColor(banded ? Color(hex: decor.bandInkSoft) : c.inkSoft)
                }
                Spacer()
                HStack(spacing: 3) {
                    if !isNight && decor.streak != .none {
                        StreakMark(mark: decor.streak, colors: decor.motifColors.map { Color(hex: $0) })
                            .scaleEffect(0.55).frame(width: 15, height: 15)
                    }
                    Text("33-day streak").font(.dv(size: 9, weight: .bold)).foregroundColor(headInk)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, banded ? 10 : 0)
            .background(alignment: .top) {
                if !isNight {
                    ZStack {
                        if let band = decor.band { Color(hex: band) }
                        HeaderMotifLayer(decor: decor, scale: 0.6)
                    }
                    .clipped()
                }
            }
            .padding(.horizontal, -12)
            .padding(.top, -12)

            VStack(alignment: .leading, spacing: 3) {
                Text("TODAY · 8:54 AM").font(.dv(size: 7, design: .monospaced)).foregroundColor(c.inkSoft)
                Text("Sarah called on the drive home and I said it out loud.")
                    .font(.dv(size: 9)).foregroundColor(c.ink).lineLimit(2)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous).fill(c.card))
            .overlay(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .stroke(c.ink, lineWidth: decor.card == .soft ? 0 : 1.5))
            .background(RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(c.ink.opacity(decor.card == .sticker ? 0.9 : 0)).offset(x: 2, y: 2.5))

            HStack(spacing: 5) {
                Circle().fill(DS.Brand.forest).frame(width: 7, height: 7)
                Text("Feeling calm").font(.dv(size: 9, weight: .semibold)).foregroundColor(c.ink)
                Spacer()
            }
            .padding(.horizontal, 8).padding(.vertical, 6)
            .background(RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(isNight ? c.card : Color(hex: palette.tintSage)))

            Text("How are things with Sarah?")
                .font(.dv(size: 12, weight: .bold, design: .rounded)).foregroundColor(c.ink)
                .frame(maxWidth: .infinity)
                .multilineTextAlignment(.center)
                .padding(.top, 2)

            ZStack {
                Circle().stroke(c.reward.opacity(0.55), style: StrokeStyle(lineWidth: 2, dash: [1.5, 3]))
                    .frame(width: 50, height: 50)
                Circle().fill(c.action).frame(width: 36, height: 36)
                Image(systemName: "mic.fill").font(.system(size: 13, weight: .semibold)).foregroundColor(c.onAction)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 0) {
                Text("Speak").font(.dv(size: 8, weight: .bold)).foregroundColor(c.onAction)
                    .lineLimit(1).fixedSize()
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Capsule().fill(c.action))
                ForEach(["Journal", "Twin", "Ask"], id: \.self) { t in
                    Text(t).font(.dv(size: 8, weight: .medium)).foregroundColor(c.ink)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(4)
            .background(Capsule().fill(c.card))
        }
        .padding(12)
        .frame(width: 200)
        .background(c.ground)
        .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 26, style: .continuous).stroke(c.ink.opacity(0.85), lineWidth: 5))
    }
}

/// Three dots for a Settings row: paper, action, reward.
struct ThemeDots: View {
    let palette: ThemePalette

    var body: some View {
        HStack(spacing: -4) {
            ForEach([palette.ivory, palette.sage, palette.gold], id: \.self) { hex in
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 14, height: 14)
                    .overlay(Circle().stroke(Color.primary.opacity(0.18), lineWidth: 1))
            }
        }
        .accessibilityHidden(true)
    }
}
