//
//  DesignSystem.swift
//  solyn
//
//  The canonical design language for DailyVox — "warm calm wellness".
//  One source of truth for spacing, radii, shadows, typography, brand color,
//  and the reusable card / button / stat components every screen should use.
//  Theme-aware surfaces still come from ThemeManager; the fixed brand palette
//  and the structural tokens live here.
//

import SwiftUI

// MARK: - Tokens

enum DS {

    /// 4-pt spacing scale. Use these instead of magic numbers.
    enum Space {
        static let xxs: CGFloat = 4
        static let xs:  CGFloat = 8
        static let sm:  CGFloat = 12
        static let md:  CGFloat = 16
        static let lg:  CGFloat = 20
        static let xl:  CGFloat = 28
        static let xxl: CGFloat = 40
        static let xxxl: CGFloat = 56
    }

    /// Corner radii. Continuous (squircle) corners everywhere for the soft feel.
    enum Radius {
        static let sm:   CGFloat = 12
        static let md:   CGFloat = 18
        static let lg:   CGFloat = 24
        static let xl:   CGFloat = 32
        static let pill: CGFloat = 999
    }

    /// The Evergreen & Gold Hour palette (design system v2.0).
    ///
    /// COLOUR GRAMMAR, and it is the whole system: **green acts, gold rewards,
    /// navy is sky, cream is paper.** Green is every action the user takes —
    /// record, send, save. Gold is every thing they have made — stars, streaks,
    /// insights. They are never swapped, which is why `gold` is deliberately not
    /// reachable as a day accent: if it were, a Material-style component could
    /// request it for a button and the grammar would break silently.
    ///
    /// Token NAMES are unchanged from the sage palette on purpose. Twenty files
    /// read them, and renaming would have meant twenty diffs where the real
    /// change is a set of hex values.
    enum Palette {
        // Day — cream paper, forest ink.
        static let ink        = Color(red: 0.118, green: 0.165, blue: 0.149)   // #1E2A26
        static let inkSoft    = Color(red: 0.361, green: 0.416, blue: 0.392)   // #5C6A64
        static let inkMute    = Color(red: 0.545, green: 0.588, blue: 0.565)   // #8B9690
        static let ivory      = Color(red: 0.969, green: 0.953, blue: 0.918)   // #F7F3EA page
        static let ivory2     = Color(red: 1.0,   green: 1.0,   blue: 1.0)     // #FFFFFF card

        // Green ACTS.
        static let sage       = Color(red: 0.180, green: 0.357, blue: 0.267)   // #2E5B44 action
        static let sageDeep   = Color(red: 0.129, green: 0.267, blue: 0.196)   // #214432
        static let forest     = Color(red: 0.561, green: 0.749, blue: 0.467)   // #8FBF77 positive

        // Gold REWARDS. Never an action colour.
        static let gold       = Color(red: 0.851, green: 0.643, blue: 0.255)   // #D9A441
        static let goldDay    = Color(red: 0.541, green: 0.416, blue: 0.122)   // #8A6A1F on cream
        static let goldNight  = Color(red: 0.929, green: 0.796, blue: 0.525)   // #EDCB86 on navy

        // Navy is SKY.
        static let navy       = Color(red: 0.063, green: 0.106, blue: 0.176)   // #101B2D
        static let navySurface = Color(red: 0.110, green: 0.165, blue: 0.259)  // #1C2A42
        static let navyText   = Color(red: 0.945, green: 0.929, blue: 0.886)   // #F1EDE2
        static let starBlue   = Color(red: 0.616, green: 0.757, blue: 0.894)   // #9DC1E4

        static let terracotta = Color(red: 0.769, green: 0.584, blue: 0.416)   // #C4956A
        static let coral      = Color(red: 0.831, green: 0.310, blue: 0.271)   // #D44F45 recording

        // Soft card tints
        static let tintSage   = Color(red: 0.894, green: 0.929, blue: 0.894)   // #E4EDE4
        static let tintGold   = Color(red: 0.953, green: 0.906, blue: 0.804)   // #F3E7CD
        static let tintTerra  = Color(red: 0.953, green: 0.910, blue: 0.863)
        static let tintCoral  = Color(red: 0.973, green: 0.898, blue: 0.875)
    }
}

// MARK: - Typography (SF Rounded display for warmth; system body for legibility)

extension Font {
    static func dsDisplay(_ size: CGFloat = 32) -> Font { .system(size: size, weight: .bold, design: .rounded) }
    static let dsTitle    = Font.system(size: 24, weight: .bold,     design: .rounded)
    static let dsTitle2   = Font.system(size: 19, weight: .semibold, design: .rounded)
    static let dsHeadline = Font.system(size: 17, weight: .semibold, design: .rounded)
    static let dsBody     = Font.system(size: 16, weight: .regular)
    static let dsCallout  = Font.system(size: 15, weight: .medium,   design: .rounded)
    static let dsCaption  = Font.system(size: 13, weight: .medium,   design: .rounded)
    static let dsCaption2 = Font.system(size: 11, weight: .semibold, design: .rounded)
    static let dsStat      = Font.system(size: 30, weight: .bold,    design: .rounded)
    static let dsMono     = Font.system(size: 12, weight: .medium,   design: .monospaced)
}

// MARK: - Shadows (warm-tinted, soft, layered — the "smooth" feel)

extension View {
    /// Soft resting elevation for cards.
    func dsShadowSoft() -> some View {
        shadow(color: Color(red: 0.357, green: 0.298, blue: 0.227).opacity(0.06), radius: 8, x: 0, y: 3)
    }
    /// Medium elevation for primary surfaces / hovered cards.
    func dsShadowMedium() -> some View {
        shadow(color: Color(red: 0.357, green: 0.298, blue: 0.227).opacity(0.12), radius: 22, x: 0, y: 10)
    }
    /// Accent glow (e.g., the record button).
    func dsGlow(_ color: Color, radius: CGFloat = 18) -> some View {
        shadow(color: color.opacity(0.45), radius: radius, x: 0, y: 8)
    }
}

// MARK: - Card

struct DSCard<Content: View>: View {
    @ObservedObject private var theme = ThemeManager.shared
    var padding: CGFloat = DS.Space.lg
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .fill(theme.warmCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: DS.Radius.lg, style: .continuous)
                    .stroke(DS.Palette.ink.opacity(0.04), lineWidth: 1)
            )
            .dsShadowSoft()
    }
}

extension View {
    /// Apply the standard card surface to any view.
    func dsCard(padding: CGFloat = DS.Space.lg) -> some View {
        DSCard(padding: padding) { self }
    }
}

// MARK: - Stat card (the white number+label tile used across the app)

struct DSStatCard: View {
    let value: String
    let label: String
    var tint: Color = DS.Palette.sage

    var body: some View {
        VStack(spacing: DS.Space.xxs) {
            Text(value)
                .font(.dsStat)
                .foregroundColor(tint)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.dsCaption)
                .foregroundColor(DS.Palette.inkMute)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DS.Space.md)
        .padding(.horizontal, DS.Space.xs)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(ThemeManager.shared.warmCardBackground)
        )
        .dsShadowSoft()
    }
}

// MARK: - Section header

struct DSSectionHeader: View {
    let title: String
    var subtitle: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: DS.Space.xxs) {
            Text(title).font(.dsTitle2).foregroundColor(DS.Palette.ink)
            if let subtitle {
                Text(subtitle).font(.dsCaption).foregroundColor(DS.Palette.inkMute)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Buttons (pill, the primary CTA shape)

struct DSPrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsHeadline)
            .foregroundColor(.white)
            .padding(.vertical, 15)
            .padding(.horizontal, DS.Space.xl)
            .frame(maxWidth: .infinity)
            .background(
                Capsule().fill(
                    LinearGradient(colors: [DS.Palette.sage, DS.Palette.sageDeep],
                                   startPoint: .top, endPoint: .bottom)
                )
            )
            .dsGlow(DS.Palette.sage, radius: configuration.isPressed ? 6 : 16)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

struct DSSecondaryButtonStyle: ButtonStyle {
    @ObservedObject private var theme = ThemeManager.shared
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.dsHeadline)
            .foregroundColor(DS.Palette.ink)
            .padding(.vertical, 15)
            .padding(.horizontal, DS.Space.xl)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(theme.warmCardBackground))
            .overlay(Capsule().stroke(DS.Palette.ink.opacity(0.06), lineWidth: 1))
            .dsShadowSoft()
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == DSPrimaryButtonStyle {
    static var dsPrimary: DSPrimaryButtonStyle { .init() }
}
extension ButtonStyle where Self == DSSecondaryButtonStyle {
    static var dsSecondary: DSSecondaryButtonStyle { .init() }
}

// MARK: - Pill tag / chip

struct DSTag: View {
    let text: String
    var tint: Color = DS.Palette.sage
    var body: some View {
        Text(text)
            .font(.dsCaption2)
            .foregroundColor(tint)
            .padding(.horizontal, DS.Space.sm)
            .padding(.vertical, 6)
            .background(Capsule().fill(tint.opacity(0.12)))
    }
}

#if DEBUG
struct DesignSystem_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: DS.Space.lg) {
                DSSectionHeader(title: "Your week", subtitle: "Built from 47 entries")
                HStack(spacing: DS.Space.sm) {
                    DSStatCard(value: "47", label: "Stars earned", tint: DS.Palette.gold)
                    DSStatCard(value: "5", label: "Clusters", tint: DS.Palette.sage)
                    DSStatCard(value: "4", label: "Moods", tint: DS.Palette.terracotta)
                }
                VStack(alignment: .leading, spacing: DS.Space.xs) {
                    Text("A quieter day").font(.dsHeadline)
                    Text("Reflective · 1m 12s").font(.dsCaption).foregroundColor(DS.Palette.inkMute)
                }.dsCard()
                HStack { DSTag(text: "On-device", tint: DS.Palette.sage); DSTag(text: "Voice-first", tint: DS.Palette.gold) }
                Button("Start your sky tonight") {}.buttonStyle(.dsPrimary)
                Button("See how it works") {}.buttonStyle(.dsSecondary)
            }
            .padding(DS.Space.lg)
        }
        .background(WarmBackground().ignoresSafeArea())
    }
}
#endif
