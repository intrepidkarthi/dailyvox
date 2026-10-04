//
//  TypedEntryComposer.swift
//  solyn
//
//  The typed escape hatch behind "I can't talk right now".
//
//  It started life inside onboarding, as the way to make a first star without
//  speaking. A user asked for it everywhere, and the reason was not dislike of
//  voice: it is that most of a day is spent around coworkers, customers and
//  family, where talking to your journal out loud is not an option. So the
//  same composer now serves both the onboarding beat and the Today screen —
//  one view, so the two can never drift into different products.
//

import SwiftUI

/// Colours for the composer. Onboarding is a fixed cream ground whatever the
/// theme; the app proper follows ThemeManager, so the sheet has to as well or
/// a night-theme user gets a white sheet sliding over a navy screen.
struct TypedEntryComposerStyle {
    var paper: Color
    var card: Color
    var ink: Color
    var inkMute: Color
    var rule: Color
    var accent: Color

    static let onboarding = TypedEntryComposerStyle(
        paper: DS.Palette.ivory,
        card: .white,
        ink: DS.Palette.navy,
        inkMute: DS.Palette.navy.opacity(0.40),
        rule: DS.Palette.navy.opacity(0.10),
        accent: DS.Palette.sage
    )

    /// Read at presentation time, so a Sunset theme that has turned over since
    /// launch is honoured.
    static var themed: TypedEntryComposerStyle {
        let t = ThemeManager.shared
        return TypedEntryComposerStyle(
            paper: t.backgroundColor,
            card: t.cardBackgroundColor,
            ink: t.textColor,
            inkMute: t.secondaryTextColor,
            rule: t.textColor.opacity(0.12),
            accent: t.accentColor
        )
    }
}

struct TypedEntryComposer: View {
    @Binding var text: String
    var title: String
    var prompt: String = "How was your day, really?"
    /// The privacy line under the editor. It is a parameter because the true
    /// sentence differs: during onboarding nothing has been synced yet, but in
    /// the app iCloud sync may be on, so "only on your phone" would overclaim.
    var footnote: String
    var style: TypedEntryComposerStyle
    var onSave: () -> Void
    var onCancel: () -> Void

    @FocusState private var focused: Bool

    private var isEmpty: Bool { text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button("Cancel", action: onCancel).foregroundColor(style.inkMute)
                Spacer()
                Text(title)
                    .font(.dv(.subheadline, design: .rounded, weight: .semibold))
                    .foregroundColor(style.ink)
                    .accessibilityAddTraits(.isHeader)
                Spacer()
                Button("Save", action: onSave)
                    .fontWeight(.semibold)
                    .foregroundColor(isEmpty ? style.inkMute : style.accent)
                    .disabled(isEmpty)
            }
            .font(.dv(.subheadline, design: .rounded))
            .padding()

            Text(prompt)
                .font(.dv(.title2, design: .rounded, weight: .bold))
                .foregroundColor(style.ink)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal)
                .padding(.top, 4)

            // Grows to the sheet rather than a fixed 200pt: a typed entry at a
            // desk can run long, and at large Dynamic Type sizes 200pt held
            // only a few lines.
            TextEditor(text: $text)
                .font(.dv(.body, design: .rounded))
                .foregroundColor(style.ink)
                .scrollContentBackground(.hidden)
                .padding(12)
                .background(style.card)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(style.rule, lineWidth: 1))
                .frame(minHeight: 200, maxHeight: .infinity)
                .padding()
                .focused($focused)
                .accessibilityLabel(prompt)

            Text(footnote)
                .font(.dv(.caption, design: .rounded))
                .foregroundColor(style.inkMute)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .background(style.paper.ignoresSafeArea())
        .onAppear { focused = true }
    }
}
