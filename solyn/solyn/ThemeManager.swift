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
