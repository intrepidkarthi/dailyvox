//
//  DVFont.swift
//  solyn
//
//  The three bundled faces — FINAL-SPEC §1 Type, acceptance criterion §8.2.
//

import SwiftUI
import UIKit
import CoreText

/// Nunito, Inter and DM Mono, shipped with the app.
///
/// The app was 100% SF before this: `DesignSystem.swift` mapped every role onto
/// `.system(design: .rounded)`, which is a *description* of Nunito rather than
/// Nunito. The spec is explicit in two places — "bundle all three; never fall
/// back to Roboto/SF" (§1) and "no Roboto anywhere ... Nunito/Inter/DM Mono
/// only" (§8.2) — and Android has shipped exactly these three files since the
/// port. These are byte-identical copies of the Android resources, so the two
/// platforms are not merely using the same typeface names, they are rasterising
/// the same outlines.
///
/// ## Variable fonts
///
/// Nunito and Inter are variable, and their DEFAULT instances are not what the
/// spec asks for: Nunito's default weight is 200 (ExtraLight) and Inter's is
/// 400. `Font.custom("Nunito-ExtraLight", size:).weight(.bold)` does not move
/// the `wght` axis — SwiftUI either ignores the weight or synthesises a smear —
/// so every weight here is produced by setting the axis on a `UIFontDescriptor`
/// and handing the resulting `UIFont` to SwiftUI. That is the only way to get a
/// real Nunito 800 out of this file.
enum DVFont {

    // Variation-axis identifiers are the four-character tags read as big-endian
    // UInt32: 'wght' and 'opsz'.
    private static let wghtAxis = 0x77676874
    private static let opszAxis = 0x6F70737A

    /// PostScript names, which are what `UIFontDescriptor` matches on. They are
    /// the DEFAULT instance's names, not the family's — see the note above.
    enum Face {
        static let nunito = "Nunito-ExtraLight"
        static let inter  = "Inter-Regular"
        static let mono   = "DMMono-Medium"
    }

    /// Registered lazily as well as via `UIAppFonts`.
    ///
    /// Belt and braces on purpose: if the Info.plist entry is ever dropped, or
    /// the resource lands in a subdirectory the plist does not name, the app
    /// would silently render in SF again — the exact failure this file exists to
    /// end, and one that no test catches because everything still lays out.
    /// `registerIfNeeded` makes that impossible to do quietly.
    private static let registered: Bool = {
        var ok = true
        for file in ["Nunito-Variable", "Inter-Variable", "DMMono-Medium"] {
            guard let url = Bundle.main.url(forResource: file, withExtension: "ttf") else { continue }
            var error: Unmanaged<CFError>?
            if !CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error) {
                // The common, benign failure is "already registered", because
                // UIAppFonts got there first — that is success as far as this
                // is concerned. Anything else is a real miss.
                let code = CFErrorGetCode(error?.takeUnretainedValue())
                if code != CTFontManagerError.alreadyRegistered.rawValue { ok = false }
            }
        }
        return ok
    }()

    /// True when all three faces resolve. Surfaced so a debug build can assert
    /// rather than quietly falling back to the system face.
    static var isAvailable: Bool {
        _ = registered
        return [Face.nunito, Face.inter, Face.mono].allSatisfy {
            UIFont(name: $0, size: 12) != nil
        }
    }

    // MARK: - Builders

    private static func varied(_ name: String, size: CGFloat,
                               axes: [Int: CGFloat]) -> UIFont {
        _ = registered
        var attrs: [UIFontDescriptor.AttributeName: Any] = [.name: name]
        if !axes.isEmpty {
            attrs[kCTFontVariationAttribute as UIFontDescriptor.AttributeName] = axes
        }
        let descriptor = UIFontDescriptor(fontAttributes: attrs)
        return UIFont(descriptor: descriptor, size: size)
    }

    /// SwiftUI `Font.Weight` has no numeric value, so the axis mapping is
    /// spelled out. Nunito's usable range is 200–1000 and Inter's 100–900; both
    /// are clamped by CoreText, so one table serves both.
    static func axisWeight(_ w: Font.Weight) -> CGFloat {
        switch w {
        case .ultraLight: return 200
        case .thin:       return 250
        case .light:      return 300
        case .regular:    return 400
        case .medium:     return 500
        case .semibold:   return 600
        case .bold:       return 700
        case .heavy:      return 800
        case .black:      return 900
        default:          return 400
        }
    }

    /// How far text is allowed to grow with the user's content-size setting.
    ///
    /// Every screen in this app was drawn at fixed point sizes and reviewed that
    /// way, so unbounded scaling would break layouts nobody has looked at. A cap
    /// is the honest middle: someone who needs larger text gets meaningfully
    /// larger text, and no card silently loses its last line at AX5. 1.6× is
    /// roughly the jump from Large to Accessibility Medium.
    private static let maxScale: CGFloat = 1.6

    /// Scaled against the text style whose default size is nearest, so a caption
    /// and a headline grow at the rates iOS expects rather than uniformly.
    private static func scaled(_ font: UIFont, base: CGFloat) -> UIFont {
        let style: UIFont.TextStyle
        switch base {
        case ..<12:  style = .caption2
        case ..<13:  style = .caption1
        case ..<15:  style = .footnote
        case ..<16:  style = .subheadline
        case ..<17:  style = .callout
        case ..<20:  style = .body
        case ..<23:  style = .title3
        case ..<28:  style = .title2
        default:     style = .title1
        }
        return UIFontMetrics(forTextStyle: style)
            .scaledFont(for: font, maximumPointSize: base * maxScale)
    }

    /// Nunito — display, screen titles, big numbers, buttons, nav, chips.
    static func nunito(_ size: CGFloat, _ weight: Font.Weight = .bold) -> UIFont {
        scaled(varied(Face.nunito, size: size, axes: [wghtAxis: axisWeight(weight)]), base: size)
    }

    /// Inter — body and UI. `opsz` is pinned to the point size so small text
    /// gets the wider, more open optical cut Inter ships for it.
    static func inter(_ size: CGFloat, _ weight: Font.Weight = .regular) -> UIFont {
        scaled(varied(Face.inter, size: size,
                      axes: [wghtAxis: axisWeight(weight),
                             opszAxis: min(max(size, 14), 32)]),
               base: size)
    }

    /// DM Mono — data labels, timestamps, privacy facts. Static, single weight,
    /// so a requested weight is honoured only as far as the file allows.
    static func mono(_ size: CGFloat) -> UIFont {
        scaled(varied(Face.mono, size: size, axes: [:]), base: size)
    }
}

// MARK: - SwiftUI surface

extension Font {

    /// Drop-in for `Font.system(size:weight:design:)`.
    ///
    /// Same signature on purpose: converting the app was then a rename at every
    /// call site rather than a judgement at every call site, and the compiler
    /// checked the whole sweep. `design` keeps its meaning — `.rounded` was
    /// always standing in for Nunito and `.monospaced` for DM Mono.
    static func dv(size: CGFloat,
                   weight: Font.Weight = .regular,
                   design: Font.Design = .default) -> Font {
        switch design {
        case .rounded:    return Font(DVFont.nunito(size, weight))
        case .monospaced: return Font(DVFont.mono(size))
        default:          return Font(DVFont.inter(size, weight))
        }
    }

    /// Drop-in for the text-style forms — `.font(.dv(.caption))`,
    /// `.font(.dv(.headline, design: .rounded))` and their `.weight(...)`
    /// chains.
    ///
    /// Sizes are Apple's default metrics at the Large content size, so a screen
    /// keeps the proportions it was built and reviewed at — and then scales from
    /// there with the user's content-size setting, capped (see `maxScale`).
    static func dv(_ style: Font.TextStyle,
                   design: Font.Design = .default,
                   weight: Font.Weight? = nil) -> Font {
        let (size, defaultWeight) = metrics(style)
        return dv(size: size, weight: weight ?? defaultWeight, design: design)
    }

    private static func metrics(_ style: Font.TextStyle) -> (CGFloat, Font.Weight) {
        switch style {
        case .largeTitle: return (34, .regular)
        case .title:      return (28, .regular)
        case .title2:     return (22, .regular)
        case .title3:     return (20, .regular)
        case .headline:   return (17, .semibold)
        case .body:       return (17, .regular)
        case .callout:    return (16, .regular)
        case .subheadline: return (15, .regular)
        case .footnote:   return (13, .regular)
        case .caption:    return (12, .regular)
        case .caption2:   return (11, .regular)
        @unknown default: return (17, .regular)
        }
    }
}
