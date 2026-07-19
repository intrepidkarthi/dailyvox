//
//  PilotInviteCard.swift
//  solyn
//
//  The consented-pilot invitation (v1.7) — the app's only recruitment
//  surface, deliberately quiet:
//
//    • Shows ONLY to high-engagement users (≥15 entries, journaling ≥3
//      weeks): their diary is deep enough to be scientifically useful and
//      the ask feels earned, not extractive.
//    • One card, inline in the Twin tab. Never a popup, never a badge,
//      never a notification. "No thanks" hides it forever.
//    • The app itself still collects nothing — the card links to the
//      research page, where participation is an explicit, consent-first,
//      off-app process (email). "Data Not Collected" stands.
//
//  Launch argument -PilotCardDemo forces visibility (screenshot/testing
//  scaffold, same pattern as -BodyTwinInviteDemo).
//

import SwiftUI

struct PilotInviteCard: View {
    @ObservedObject private var themeManager = ThemeManager.shared
    @Environment(\.openURL) private var openURL
    @AppStorage("pilotInviteDismissed") private var dismissed = false

    let entryCount: Int
    let firstEntryDate: Date?

    private static let demoMode =
        ProcessInfo.processInfo.arguments.contains("-PilotCardDemo")

    private var isEligible: Bool {
        if Self.demoMode { return true }
        guard !dismissed, entryCount >= 15 else { return false }
        guard let first = firstEntryDate else { return false }
        return first <= Calendar.current.date(byAdding: .day, value: -21, to: Date()) ?? Date()
    }

    var body: some View {
        if isEligible {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(DS.Palette.gold.opacity(0.15))
                            .frame(width: 36, height: 36)
                        Image(systemName: "testtube.2")
                            .font(.subheadline)
                            .foregroundColor(DS.Palette.gold)
                    }
                    Text("Help make the Twin honest")
                        .font(.headline)
                        .foregroundColor(themeManager.textColor)
                    Spacer()
                }

                Text("DailyVox's Twin is validated against real, consented diaries — and there are only a handful so far. If you'd share yours for research, it would genuinely matter. Nothing leaves this app without your explicit, informed consent; participation happens over email, on your terms.")
                    .font(.subheadline)
                    .foregroundColor(themeManager.secondaryTextColor)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    Button {
                        if let url = URL(string: "https://getdailyvox.com/research") {
                            openURL(url)
                        }
                    } label: {
                        Text("Learn more")
                            .font(.subheadline.weight(.semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Capsule().fill(themeManager.accentColor))
                    }

                    Button {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dismissed = true
                        }
                    } label: {
                        Text("No thanks")
                            .font(.subheadline)
                            .foregroundColor(themeManager.secondaryTextColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                    }

                    Spacer()
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(themeManager.cardBackgroundColor)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .strokeBorder(DS.Palette.gold.opacity(0.25), lineWidth: 1)
            )
        }
    }
}
