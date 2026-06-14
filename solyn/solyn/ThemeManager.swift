//
//  ThemeManager.swift
//  solyn
//
//  Manages app appearance themes with soft, clean color palettes.
//

import SwiftUI

// MARK: - App Theme

enum AppTheme: String, CaseIterable, Identifiable {
    case system = "System"
    case ivory = "Ivory"    // Warm, premium default
    case light = "Light"
    case dark = "Dark"

    var id: String { rawValue }

    /// Display icon for theme picker
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .ivory: return "leaf.fill"
        case .light: return "sun.max"
        case .dark: return "moon.stars"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .ivory, .light: return .light
        case .dark: return .dark
        }
    }

    /// Primary accent color for buttons and highlights
    var accentColor: Color {
        switch self {
        case .system, .light:
            return Color(red: 0.357, green: 0.486, blue: 0.420)  // Sage green (updated from blue-gray)
        case .ivory:
            return Color(red: 0.357, green: 0.486, blue: 0.420)  // #5B7C6B sage green
        case .dark:
            return Color(red: 0.557, green: 0.698, blue: 0.604)  // Lightened sage — warm + on-brand on dark (was soft blue)
        }
    }

    /// Secondary color for subtle accents
    var secondaryAccent: Color {
        accentColor.opacity(0.15)
    }

    /// Preview color for theme picker
    var previewColor: Color {
        accentColor
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
        let saved = defaults.string(forKey: themeKey) ?? AppTheme.ivory.rawValue
        self.selectedTheme = AppTheme(rawValue: saved) ?? .ivory
    }

    // MARK: - Semantic Colors

    var backgroundColor: Color {
        Color(.systemGroupedBackground)
    }

    var textColor: Color {
        Color(.label)
    }

    var secondaryTextColor: Color {
        Color(.secondaryLabel)
    }

    var cardBackgroundColor: Color {
        Color(.secondarySystemGroupedBackground)
    }

    /// Theme-aware accent color for UI elements
    var accentColor: Color {
        selectedTheme.accentColor
    }

    /// Data visualization color (charts, meters, bars)
    var dataColor: Color {
        Color.teal
    }

    /// Warm background for Ivory theme, system default for others
    var warmBackground: Color {
        if selectedTheme == .ivory {
            return Color(red: 0.980, green: 0.973, blue: 0.961)  // #FAF8F5 warm ivory
        }
        return Color(.systemGroupedBackground)
    }

    /// Warm card background
    var warmCardBackground: Color {
        if selectedTheme == .ivory {
            return Color.white
        }
        return Color(.secondarySystemGroupedBackground)
    }

    /// Warm subtle fill for sections
    var warmSubtleFill: Color {
        if selectedTheme == .ivory {
            return Color(red: 0.949, green: 0.929, blue: 0.910)  // #F2EDE8 warm beige
        }
        return Color(.tertiarySystemGroupedBackground)
    }

    /// Secondary accent (terracotta for ivory, muted for others)
    var warmSecondaryAccent: Color {
        if selectedTheme == .ivory {
            return Color(red: 0.769, green: 0.584, blue: 0.416)  // #C4956A warm terracotta
        }
        return selectedTheme.accentColor.opacity(0.7)
    }

    /// Recording button color (warm coral for ivory, red for others)
    var recordingColor: Color {
        if selectedTheme == .ivory {
            return Color(red: 0.831, green: 0.388, blue: 0.294)  // #D4634B warm coral
        }
        return .red
    }

    /// Success/confirmation color
    var successColor: Color {
        if selectedTheme == .ivory {
            return Color(red: 0.420, green: 0.620, blue: 0.482)  // #6B9E7B soft forest green
        }
        return .green
    }
}

// MARK: - Premium Warm Background

struct WarmBackground: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        if themeManager.selectedTheme == .ivory {
            ZStack {
                // Base warm ivory
                Color(red: 0.980, green: 0.973, blue: 0.961)

                // Subtle radial warmth at top-right (like sunlight)
                RadialGradient(
                    colors: [
                        Color(red: 0.957, green: 0.929, blue: 0.878).opacity(0.4),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.85, y: 0.05),
                    startRadius: 20,
                    endRadius: 400
                )

                // Very subtle warm wash at bottom-left
                RadialGradient(
                    colors: [
                        Color(red: 0.357, green: 0.486, blue: 0.420).opacity(0.03),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.1, y: 0.95),
                    startRadius: 10,
                    endRadius: 300
                )
            }
            .ignoresSafeArea()
        } else if themeManager.selectedTheme == .dark {
            // Dark mode gets a subtle deep warmth instead of pure black
            ZStack {
                Color(.systemBackground)
                RadialGradient(
                    colors: [
                        Color(red: 0.12, green: 0.10, blue: 0.16).opacity(0.5),
                        Color.clear
                    ],
                    center: UnitPoint(x: 0.5, y: 0.3),
                    startRadius: 50,
                    endRadius: 500
                )
            }
            .ignoresSafeArea()
        } else {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()
        }
    }
}
