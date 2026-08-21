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
        case .sunset: return SolarClock.isAfterSunset()
        }
    }

    var colorScheme: ColorScheme? { isNight ? .dark : .light }

    /// GREEN ACTS. Gold is never returned here — see DS.Palette.
    var accentColor: Color { isNight ? DS.Palette.gold : DS.Palette.sage }

    var secondaryAccent: Color { DS.Palette.terracotta }

    var previewColor: Color { isNight ? DS.Palette.navy : DS.Palette.ivory }
}


/// When the sun actually sets here today.
///
/// The spec says Sunset "follows the real sun" (§2.8). This was a fixed
/// 19:00–06:00 window, which is wrong by more than an hour at the solstices and
/// wrong all year at latitude — the whole point of naming the theme after a
/// natural event is that it tracks one.
///
/// NOAA's low-precision sunrise/sunset algorithm, which is accurate to about a
/// minute and needs nothing but the date and a latitude/longitude. There is no
/// location permission here and there will not be one: a journal does not get to
/// ask where you are to pick a colour. It reads the *time zone* the phone is
/// already set to and uses its longitude, then assumes the mid-latitude of that
/// zone. That is good to within a few minutes for most people and degrades to
/// the old fixed window at the poles, where "sunset" stops being a daily event.
enum SolarClock {

    static func isAfterSunset(now: Date = Date(),
                              calendar: Calendar = .current,
                              timeZone: TimeZone = .current) -> Bool {
        guard let (sunrise, sunset) = sunTimes(on: now, calendar: calendar, timeZone: timeZone) else {
            let h = calendar.component(.hour, from: now)
            return h >= 19 || h < 6
        }
        return now >= sunset || now < sunrise
    }

    /// Longitude from the phone's UTC offset; latitude assumed mid-zone.
    /// Fifteen degrees of longitude per hour is the definition of a time zone.
    private static func coordinates(_ timeZone: TimeZone, _ now: Date) -> (lat: Double, lon: Double) {
        let hours = Double(timeZone.secondsFromGMT(for: now)) / 3600
        return (lat: 40, lon: (hours * 15).clampedLongitude)
    }

    private static func sunTimes(on date: Date,
                                 calendar: Calendar,
                                 timeZone: TimeZone) -> (Date, Date)? {
        let (lat, lon) = coordinates(timeZone, date)
        var cal = calendar
        cal.timeZone = timeZone
        let startOfDay = cal.startOfDay(for: date)
        guard let dayOfYear = cal.ordinality(of: .day, in: .year, for: date) else { return nil }

        // NOAA low-precision: fractional year, equation of time, declination,
        // then the hour angle at which the sun is 90.833° from vertical (the
        // extra 0.833° is refraction plus the solar disc's radius).
        let gamma = 2 * Double.pi / 365 * (Double(dayOfYear) - 1)
        let eqTime = 229.18 * (0.000075
            + 0.001868 * cos(gamma) - 0.032077 * sin(gamma)
            - 0.014615 * cos(2 * gamma) - 0.040849 * sin(2 * gamma))
        let decl = 0.006918
            - 0.399912 * cos(gamma) + 0.070257 * sin(gamma)
            - 0.006758 * cos(2 * gamma) + 0.000907 * sin(2 * gamma)
            - 0.002697 * cos(3 * gamma) + 0.00148 * sin(3 * gamma)

        let latRad = lat * .pi / 180
        let cosHa = (cos(90.833 * .pi / 180) / (cos(latRad) * cos(decl)))
            - tan(latRad) * tan(decl)
        // Polar day or polar night: there is no sunset to follow.
        guard cosHa >= -1, cosHa <= 1 else { return nil }
        let ha = acos(cosHa) * 180 / .pi

        let offsetMinutes = Double(timeZone.secondsFromGMT(for: date)) / 60
        let sunriseMin = 720 - 4 * (lon + ha) - eqTime + offsetMinutes
        let sunsetMin  = 720 - 4 * (lon - ha) - eqTime + offsetMinutes

        return (startOfDay.addingTimeInterval(sunriseMin * 60),
                startOfDay.addingTimeInterval(sunsetMin * 60))
    }
}

private extension Double {
    /// Time zones exist past the date line; longitude does not.
    var clampedLongitude: Double { Swift.min(Swift.max(self, -180), 180) }
}

/// A resolved theme as a VALUE rather than a singleton read.
///
/// This exists for one rule: **the Twin/constellation screen renders night
/// tokens under BOTH themes** (FINAL-SPEC §1 colour rules, §2.5, §8.4). Every
/// view used to reach for `ThemeManager.shared` directly, and a singleton
/// cannot be different for one branch of the view tree — so the sky either
/// followed the app theme or the whole app went dark. Passing the theme down
/// the environment makes "always night" a property of a subtree, which is what
/// the spec is actually describing.
///
/// The member names match `ThemeManager`'s exactly, so a view switches from one
/// to the other by changing its property wrapper and nothing else.
struct DVTheme {
    let isNight: Bool

    /// Pinned night — the sky, in daylight.
    static let night = DVTheme(isNight: true)

    /// Whatever the user has chosen right now.
    static var current: DVTheme { DVTheme(isNight: ThemeManager.shared.isNight) }

    var backgroundColor: Color { isNight ? DS.Palette.navy : DS.Palette.ivory }
    var textColor: Color { isNight ? DS.Palette.navyText : DS.Palette.ink }
    var secondaryTextColor: Color {
        isNight ? DS.Palette.navyText.opacity(0.6) : DS.Palette.inkSoft
    }
    var cardBackgroundColor: Color { isNight ? DS.Palette.navySurface : DS.Palette.ivory2 }

    /// GREEN ACTS. Gold by night, because on navy there is no green that reads.
    var accentColor: Color { isNight ? DS.Palette.gold : DS.Palette.sage }

    /// Gold TEXT, which differs by ground: #8A6A1F has contrast on cream,
    /// #EDCB86 has it on navy.
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

    /// Day and night have DIFFERENT greens — #8FBF77 has no contrast on cream.
    var successColor: Color { isNight ? DS.Palette.forest : DS.Palette.sagePositive }
}

private struct DVThemeKey: EnvironmentKey {
    /// Computed, not stored: a view outside the injected subtree (the lock
    /// screen, onboarding) still resolves the user's real theme rather than a
    /// value frozen at launch.
    static var defaultValue: DVTheme { .current }
}

extension EnvironmentValues {
    var dvTheme: DVTheme {
        get { self[DVThemeKey.self] }
        set { self[DVThemeKey.self] = newValue }
    }
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
    //
    // All of them delegate to `DVTheme` so there is exactly one definition of
    // what "night" looks like. A view that needs the theme of its SUBTREE
    // rather than the app's reads `@Environment(\.dvTheme)` instead of this
    // object — see the Twin screen.

    /// This manager's choice, as a value that can be handed down the tree.
    var palette: DVTheme { DVTheme(isNight: isNight) }

    var backgroundColor: Color { palette.backgroundColor }
    var textColor: Color { palette.textColor }
    var secondaryTextColor: Color { palette.secondaryTextColor }
    var cardBackgroundColor: Color { palette.cardBackgroundColor }
    var accentColor: Color { palette.accentColor }
    var goldText: Color { palette.goldText }
    var dataColor: Color { palette.dataColor }
    var warmBackground: Color { palette.warmBackground }
    var warmCardBackground: Color { palette.warmCardBackground }
    var warmSubtleFill: Color { palette.warmSubtleFill }
    var warmSecondaryAccent: Color { palette.warmSecondaryAccent }
    var recordingColor: Color { palette.recordingColor }
    var successColor: Color { palette.successColor }
}

extension View {
    /// Hands a presented sheet the USER'S theme back.
    ///
    /// The Twin screen pins its subtree to night (FINAL-SPEC §8.4) and SwiftUI
    /// sheets inherit the presenter's environment — so without this, opening
    /// Insights or a review sheet from a cream app produced a dark sheet with
    /// no explanation. Only the constellation screen is unconditional; every
    /// sheet launched from it is an ordinary screen again.
    func appThemedSheet() -> some View {
        self
            .environment(\.dvTheme, .current)
            .environment(\.colorScheme, ThemeManager.shared.isNight ? .dark : .light)
    }
}

// MARK: - Premium Warm Background

struct WarmBackground: View {
    /// The subtree's theme, not the app's: this is the page under the Twin
    /// screen, which is night in daylight.
    @Environment(\.dvTheme) private var themeManager

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

