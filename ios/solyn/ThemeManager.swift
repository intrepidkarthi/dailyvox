//
//  ThemeManager.swift
//  solyn
//
//  Manages app appearance themes with soft, clean color palettes.
//

import SwiftUI

// MARK: - App Theme

/// Day · Night · **Sunset** (design spec §2.8). Sunset is the default and
/// follows the real sun: paper by day, sky by night.
///
/// The old cases (`system`, `ivory`, `light`, `dark`) are still decodable so an
/// upgrade does not throw away a stored preference and silently reset someone's
/// app — `ivory`/`light` land on `.day`, `dark` on `.night`, `system` on the
/// closest thing we now have to it, which is Sunset.
enum AppTheme: String, CaseIterable, Identifiable {
    case day = "Day"
    case night = "Night"
    case sunset = "Sunset"

    var id: String { rawValue }

    /// Only the three current cases are offered in Settings.
    static var allCases: [AppTheme] { [.day, .night, .sunset] }

    static func decode(_ raw: String) -> AppTheme {
        switch raw {
        case "Day", "Ivory", "Light": return .day
        case "Night", "Dark": return .night
        default: return .sunset
        }
    }

    var icon: String {
        switch self {
        case .day: return "sun.max"
        case .night: return "moon.stars"
        case .sunset: return "circle.lefthalf.filled"
        }
    }

    /// Re-read on every access rather than cached: Sunset should turn over when
    /// the evening arrives, not on next launch.
    var isNight: Bool {
        switch self {
        case .day: return false
        case .night: return true
        case .sunset:
            let h = Calendar.current.component(.hour, from: Date())
            return h >= 19 || h < 6
        }
    }

    var colorScheme: ColorScheme? { isNight ? .dark : .light }

    /// GREEN ACTS. Gold is never returned here — see DS.Palette.
    var accentColor: Color { isNight ? DS.Palette.gold : DS.Palette.sage }

    var secondaryAccent: Color { DS.Palette.terracotta }

    var previewColor: Color { isNight ? DS.Palette.navy : DS.Palette.ivory }
}

final class ThemeManager: ObservableObject {
    static let shared = ThemeManager()

    private let defaults = UserDefaults.standard
    private let themeKey = "selectedTheme"

    @Published var selectedTheme: AppTheme {
        didSet {
            defaults.set(selectedTheme.rawValue, forKey: themeKey)
        }
    }

    private init() {
        let saved = defaults.string(forKey: themeKey) ?? AppTheme.sunset.rawValue
        self.selectedTheme = AppTheme.decode(saved)
    }

    /// Every screen asks this rather than reading the case, so Sunset works
    /// everywhere without each view re-deriving the hour.
    var isNight: Bool { selectedTheme.isNight }

    // MARK: - Semantic Colors

    var backgroundColor: Color { isNight ? DS.Palette.navy : DS.Palette.ivory }
    var textColor: Color { isNight ? DS.Palette.navyText : DS.Palette.ink }
    var secondaryTextColor: Color {
        isNight ? DS.Palette.navyText.opacity(0.6) : DS.Palette.inkSoft
    }
    var cardBackgroundColor: Color { isNight ? DS.Palette.navySurface : DS.Palette.ivory2 }

    /// The action colour. Green by day, gold by night — the one place the
    /// grammar allows gold to act, because on navy there is no green that reads.
    var accentColor: Color { selectedTheme.accentColor }

    /// Gold TEXT, which differs by ground: #8A6A1F has contrast on cream,
    /// #EDCB86 has contrast on navy. Using one for both fails legibility on the
    /// other, and it is the mistake the Android build shipped first.
    var goldText: Color { isNight ? DS.Palette.goldNight : DS.Palette.goldDay }

    var dataColor: Color { DS.Palette.sage }

    var warmBackground: Color { backgroundColor }
    var warmCardBackground: Color { cardBackgroundColor }
    var warmSubtleFill: Color {
        isNight ? DS.Palette.navyText.opacity(0.08) : DS.Palette.tintSage
    }
    var warmSecondaryAccent: Color { DS.Palette.terracotta }

    /// Recording is coral in both themes: stop has to read as stop.
    var recordingColor: Color { DS.Palette.coral }

    var successColor: Color { DS.Palette.forest }
}

// MARK: - Premium Warm Background

struct WarmBackground: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        ZStack {
            themeManager.backgroundColor

            // One warm bloom, placed where the light would come from. Night gets
            // gold at low alpha (the sky glowing), day gets a paper warmth.
            RadialGradient(
                colors: [
                    (themeManager.isNight ? DS.Palette.gold : DS.Palette.terracotta)
                        .opacity(themeManager.isNight ? 0.10 : 0.16),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.85, y: 0.05),
                startRadius: 20,
                endRadius: 420
            )

            RadialGradient(
                colors: [
                    (themeManager.isNight ? DS.Palette.starBlue : DS.Palette.sage)
                        .opacity(themeManager.isNight ? 0.06 : 0.04),
                    Color.clear,
                ],
                center: UnitPoint(x: 0.1, y: 0.95),
                startRadius: 10,
                endRadius: 320
            )
        }
        .ignoresSafeArea()
    }
}

