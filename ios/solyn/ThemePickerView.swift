//
//  ThemePickerView.swift
//  solyn
//
//  Settings → Appearance → Colour theme. Every theme in its group, each with a
//  swatch of its own colours (not the colours in force), so the list is
//  readable whatever theme is applied.
//

import SwiftUI

struct ThemePickerView: View {
    @ObservedObject private var themeManager = ThemeManager.shared

    var body: some View {
        List {
            ForEach(ThemeGroup.allCases) { group in
                Section(group.rawValue) {
                    ForEach(group.themes) { theme in
                        Button {
                            themeManager.themeID = theme
                            HapticManager.shared.themeChanged()
                        } label: {
                            ThemeRow(theme: theme, isSelected: themeManager.themeID == theme)
                        }
                        .buttonStyle(.plain)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(theme.displayName)
                        .accessibilityAddTraits(themeManager.themeID == theme ? [.isButton, .isSelected] : .isButton)
                    }
                }
            }
            Section {
                EmptyView()
            } footer: {
                Text("Your new theme appears when you close Settings. Mood colours stay the same in every theme, so your history always reads the same way.")
            }
        }
        .navigationTitle("Colour theme")
        .navigationBarTitleDisplayMode(.inline)
    }
}

private struct ThemeRow: View {
    let theme: ThemeID
    let isSelected: Bool

    var body: some View {
        let p = theme.palette
        HStack(spacing: DS.Space.sm) {
            ThemeSwatch(palette: p)
            Text(theme.displayName)
                .font(.dsHeadline)
                .foregroundColor(.primary)
            Spacer()
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.dv(.body))
                .foregroundColor(isSelected ? .accentColor : .secondary.opacity(0.5))
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// Paper with a card on it, the action colour, the reward colour and the sky:
/// the four things that change most between themes.
struct ThemeSwatch: View {
    let palette: ThemePalette

    var body: some View {
        HStack(spacing: 0) {
            Color(hex: palette.ivory)
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: palette.ivory2))
                        .padding(5)
                )
            Color(hex: palette.sage)
            Color(hex: palette.gold)
            Color(hex: palette.navy)
        }
        .frame(width: 76, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .stroke(Color.primary.opacity(0.15), lineWidth: 1)
        )
        .accessibilityHidden(true)
    }
}
