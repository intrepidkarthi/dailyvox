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
    case light = "Light"
    case sage = "Sage"
    case lavender = "Lavender"
    case rose = "Rose"
    case ocean = "Ocean"
    case warm = "Warm"
    case dark = "Dark"

    var id: String { rawValue }

    /// Display icon for theme picker
    var icon: String {
        switch self {
        case .system: return "circle.lefthalf.filled"
        case .light: return "sun.max"
        case .sage: return "leaf"
        case .lavender: return "sparkles"
        case .rose: return "heart"
        case .ocean: return "drop"
        case .warm: return "flame"
        case .dark: return "moon.stars"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .dark: return .dark
        default: return .light
        }
    }

    /// Primary accent color for buttons and highlights
    var accentColor: Color {
        switch self {
        case .system, .light:
            return Color(red: 0.4, green: 0.5, blue: 0.6)  // Soft blue-gray
        case .sage:
            return Color(red: 0.45, green: 0.58, blue: 0.5)  // Soft sage green
        case .lavender:
            return Color(red: 0.6, green: 0.5, blue: 0.7)  // Soft lavender
        case .rose:
            return Color(red: 0.75, green: 0.5, blue: 0.55)  // Soft rose
        case .ocean:
            return Color(red: 0.4, green: 0.6, blue: 0.7)  // Soft ocean blue
        case .warm:
            return Color(red: 0.75, green: 0.55, blue: 0.4)  // Soft terracotta
        case .dark:
            return Color(red: 0.6, green: 0.7, blue: 0.8)  // Soft blue for dark mode
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
        let saved = defaults.string(forKey: themeKey) ?? AppTheme.system.rawValue
        self.selectedTheme = AppTheme(rawValue: saved) ?? .system
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
}
