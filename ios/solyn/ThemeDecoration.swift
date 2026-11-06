//
//  ThemeDecoration.swift
//  solyn
//
//  What a theme adds beyond colour: a header band, a small motif, how cards
//  are edged, how the record dial is dressed, something in the sky, and a mark
//  beside the streak. Drawn from the theme mockups (scratchpad themes/,
//  2026-11-06).
//
//  Rules every piece here keeps: flat fills and strokes only, no gradients;
//  nothing sits behind journal text (decoration lives in headers, around the
//  dial, in the sky and at card edges); mood colours are untouched; motion is
//  limited to the Today header and the sky, is slow, stops under Reduce Motion
//  and when off screen (TimelineView only runs while visible); VoiceOver
//  never sees any of it.
//

import SwiftUI

// MARK: - Description

enum ThemeMotif: Equatable {
    case none
    case horizon, lotus, brassRule, moon, ruled          // calm
    case petals, sun, rain, leaves, snow                 // seasons
    case lights, diyas, splashes, kolam, crescentLantern, starStrip   // festivals
}

enum ThemeAmbient: Equatable { case none, rain, snow, petals, leaves, twinkle }
enum ThemeCardEdge: Equatable { case soft, sticker, outlined }
enum ThemeDial: Equatable { case standard, sticker, ripples, bud, rangoli }
enum ThemeSkyMark: Equatable { case none, star, crescent, rain, snow }
enum ThemeStreakMark: Equatable { case none, sticker, lotus, petal, sun, boat, leaf, mug, ribbon, diya, pot, lantern, star }

struct ThemeDecor {
    /// The flat header band on Today (and Entry), by day. nil: no band.
    var band: UInt32? = nil
    var bandInk: UInt32 = 0xFFFFFF
    var bandInkSoft: UInt32 = 0xFFFFFF
    var bandGold: UInt32 = 0xFFFFFF
    var motif: ThemeMotif = .none
    var ambient: ThemeAmbient = .none
    var card: ThemeCardEdge = .soft
    var dial: ThemeDial = .standard
    var sky: ThemeSkyMark = .none
    var streak: ThemeStreakMark = .none
    /// Small accent colours the motifs draw with.
    var motifColors: [UInt32] = []

    var hasBand: Bool { band != nil }
}

extension ThemeID {
    var decor: ThemeDecor {
        switch self {
        case .standard:
            return ThemeDecor()
        case .sticker:
            return ThemeDecor(card: .sticker, dial: .sticker, streak: .sticker,
                              motifColors: [0xF2C14E, 0xE2553A, 0x3358C9, 0x1D1F24])
        case .highContrast:
            return ThemeDecor(card: .outlined)
        case .mist:
            return ThemeDecor(motif: .horizon, motifColors: [0x9A8CC4, 0x4F6F88])
        case .lotus:
            return ThemeDecor(motif: .lotus, streak: .lotus, motifColors: [0xD98BA0, 0x2F5B46, 0xC9A23F])
        case .sandalwood:
            return ThemeDecor(motif: .brassRule, motifColors: [0xB08D57, 0xE39B2D])
        case .hush:
            return ThemeDecor(motif: .moon, motifColors: [0xB38A3A, 0x6B4A7E])
        case .paperNotebook:
            return ThemeDecor(motif: .ruled, motifColors: [0xC0392B, 0x9AA3B5])
        case .spring:
            return ThemeDecor(band: 0xF8D7E0, bandInk: 0x3A1F28, bandInkSoft: 0x6A3F4E, bandGold: 0x7A4E0C,
                              motif: .petals, ambient: .petals, dial: .bud, streak: .petal,
                              motifColors: [0xF2A7BC, 0xFFFFFF, 0x3B7449])
        case .summer:
            return ThemeDecor(band: 0xF5B800, bandInk: 0x2A2418, bandInkSoft: 0x3F3312, bandGold: 0x2A2418,
                              motif: .sun, streak: .sun,
                              motifColors: [0xFFF4CF, 0xE5674E])
        case .monsoon:
            return ThemeDecor(band: 0x3E5466, bandInk: 0xFFFFFF, bandInkSoft: 0xDDE6EC, bandGold: 0xF6D36A,
                              motif: .rain, ambient: .rain, dial: .ripples, sky: .rain, streak: .boat,
                              motifColors: [0xC9D6E0, 0xF2B705])
        case .autumn:
            return ThemeDecor(band: 0xA6461E, bandInk: 0xFFF6EA, bandInkSoft: 0xFAE6D6, bandGold: 0xFBE6B0,
                              motif: .leaves, ambient: .leaves, streak: .leaf,
                              motifColors: [0xE0A93A, 0xF2C46A, 0x7A3E5A])
        case .winter:
            return ThemeDecor(band: 0x2F5E73, bandInk: 0xFFFFFF, bandInkSoft: 0xD5E6EF, bandGold: 0xF3D27A,
                              motif: .snow, ambient: .snow, sky: .snow, streak: .mug,
                              motifColors: [0xFFFFFF, 0xA3243F])
        case .christmas:
            return ThemeDecor(band: 0x1E5A3C, bandInk: 0xFFFFFF, bandInkSoft: 0xD8E6DC, bandGold: 0xF2D67A,
                              motif: .lights, ambient: .twinkle, sky: .star, streak: .ribbon,
                              motifColors: [0xF2D67A, 0xE2553A, 0xFFFFFF, 0x6FB2E0])
        case .diwali:
            return ThemeDecor(band: 0x2A2350, bandInk: 0xFFFFFF, bandInkSoft: 0xD9D4F0, bandGold: 0xF5B84A,
                              motif: .diyas, ambient: .twinkle, dial: .rangoli, streak: .diya,
                              motifColors: [0xB8572A, 0xF5B84A, 0xB5297A])
        case .holi:
            return ThemeDecor(motif: .splashes,
                              motifColors: [0xE84A8A, 0xF5C400, 0x2FB36A, 0x2F6FE0])
        case .pongal:
            return ThemeDecor(band: 0xF2C230, bandInk: 0x2A2210, bandInkSoft: 0x463812, bandGold: 0x6B370F,
                              motif: .kolam, streak: .pot,
                              motifColors: [0xFFFFFF, 0xB8572A, 0x3E7A2E])
        case .ramadan:
            return ThemeDecor(band: 0x123E44, bandInk: 0xFFFFFF, bandInkSoft: 0xCFE0DE, bandGold: 0xE8C46A,
                              motif: .crescentLantern, sky: .crescent, streak: .lantern,
                              motifColors: [0xE8C46A, 0xF4F3EE])
        case .eid:
            return ThemeDecor(motif: .starStrip, sky: .crescent, streak: .star,
                              motifColors: [0xB8912F, 0x1E6A50])
        }
    }
}

// MARK: - Following the system

/// Reports the phone's light/dark setting to `ThemeManager` while Auto is on.
/// The window's trait collection is read rather than the environment, which
/// the app's own `preferredColorScheme` overrides in every other mode.
struct SystemAppearanceReader: UIViewRepresentable {
    func makeUIView(context: Context) -> TraitView { TraitView() }
    func updateUIView(_ uiView: TraitView, context: Context) {}

    final class TraitView: UIView {
        override init(frame: CGRect) {
            super.init(frame: frame)
            isUserInteractionEnabled = false
            registerForTraitChanges([UITraitUserInterfaceStyle.self]) { (view: TraitView, _) in
                view.report()
            }
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            report()
        }

        private func report() {
            // The SCREEN's style is the system setting; the window's follows
            // whatever the app forced.
            let dark = (window?.windowScene?.screen.traitCollection ?? traitCollection)
                .userInterfaceStyle == .dark
            let manager = ThemeManager.shared
            guard manager.systemIsDark != dark else { return }
            DispatchQueue.main.async { manager.systemIsDark = dark }
        }
    }
}

// MARK: - Small drawings

/// One motif, drawn flat into whatever size it is given.
struct MotifGlyph: View {
    enum Kind { case lotus, petal, sun, boat, leaf, snowflake, mug, ribbon, diya, pot, lantern, crescent, star8, sticker }
    let kind: Kind
    let colors: [Color]

    private func c(_ i: Int) -> Color { colors.isEmpty ? .gray : colors[i % colors.count] }

    var body: some View {
        Canvas { ctx, size in draw(ctx, size) }
            .accessibilityHidden(true)
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize) {
        switch kind {
        case .lotus, .petal, .sun, .boat, .leaf, .snowflake, .mug: drawA(ctx, size)
        default: drawB(ctx, size)
        }
    }

    private func drawA(_ ctx: GraphicsContext, _ size: CGSize) {
            let w: CGFloat = size.width, h: CGFloat = size.height
            switch kind {
            case .lotus:
                for (dx, rot) in [(-0.22, -35.0), (0.22, 35.0), (0.0, 0.0)] {
                    var petal = Path(ellipseIn: CGRect(x: -w * 0.14, y: -h * 0.36, width: w * 0.28, height: h * 0.62))
                    petal = petal.applying(CGAffineTransform(rotationAngle: rot * .pi / 180))
                        .applying(CGAffineTransform(translationX: w * (0.5 + dx * 0.6), y: h * 0.58))
                    ctx.fill(petal, with: .color(c(0)))
                }
                ctx.fill(Path(CGRect(x: w * 0.2, y: h * 0.84, width: w * 0.6, height: h * 0.06)), with: .color(c(1)))
            case .petal:
                for i in 0..<5 {
                    let a = Double(i) / 5 * 2 * .pi
                    var p = Path(ellipseIn: CGRect(x: -w * 0.12, y: -h * 0.42, width: w * 0.24, height: h * 0.4))
                    p = p.applying(CGAffineTransform(rotationAngle: a)).applying(CGAffineTransform(translationX: w / 2, y: h / 2))
                    ctx.fill(p, with: .color(c(0)))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.4, y: h * 0.4, width: w * 0.2, height: h * 0.2)), with: .color(c(2)))
            case .sun:
                let r = min(w, h) * 0.26
                for i in 0..<8 {
                    let a = CGFloat(i) / 8 * 2 * CGFloat.pi
                    let dx: CGFloat = cos(a), dy: CGFloat = sin(a)
                    let r1: CGFloat = r * 1.35, r2: CGFloat = r * 1.85
                    var ray = Path()
                    ray.move(to: CGPoint(x: w / 2 + dx * r1, y: h / 2 + dy * r1))
                    ray.addLine(to: CGPoint(x: w / 2 + dx * r2, y: h / 2 + dy * r2))
                    ctx.stroke(ray, with: .color(c(0)), style: StrokeStyle(lineWidth: max(1.5, w * 0.07), lineCap: .round))
                }
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - r, y: h / 2 - r, width: r * 2, height: r * 2)), with: .color(c(0)))
            case .boat:
                var hull = Path()
                hull.move(to: CGPoint(x: w * 0.05, y: h * 0.55)); hull.addLine(to: CGPoint(x: w * 0.95, y: h * 0.55))
                hull.addLine(to: CGPoint(x: w * 0.75, y: h * 0.82)); hull.addLine(to: CGPoint(x: w * 0.25, y: h * 0.82)); hull.closeSubpath()
                var sail = Path()
                sail.move(to: CGPoint(x: w * 0.5, y: h * 0.12)); sail.addLine(to: CGPoint(x: w * 0.78, y: h * 0.55)); sail.addLine(to: CGPoint(x: w * 0.22, y: h * 0.55)); sail.closeSubpath()
                ctx.fill(sail, with: .color(c(0))); ctx.fill(hull, with: .color(c(1)))
            case .leaf:
                var leaf = Path()
                leaf.move(to: CGPoint(x: w * 0.15, y: h * 0.85))
                leaf.addQuadCurve(to: CGPoint(x: w * 0.88, y: h * 0.12), control: CGPoint(x: w * 0.05, y: h * 0.1))
                leaf.addQuadCurve(to: CGPoint(x: w * 0.15, y: h * 0.85), control: CGPoint(x: w * 0.95, y: h * 0.9))
                ctx.fill(leaf, with: .color(c(0)))
                var vein = Path(); vein.move(to: CGPoint(x: w * 0.15, y: h * 0.85)); vein.addLine(to: CGPoint(x: w * 0.7, y: h * 0.3))
                ctx.stroke(vein, with: .color(c(1)), lineWidth: max(1, w * 0.05))
            case .snowflake:
                for i in 0..<3 {
                    let a = CGFloat(i) / 3 * CGFloat.pi
                    let dx: CGFloat = cos(a) * w * 0.42, dy: CGFloat = sin(a) * h * 0.42
                    var p = Path()
                    p.move(to: CGPoint(x: w / 2 - dx, y: h / 2 - dy))
                    p.addLine(to: CGPoint(x: w / 2 + dx, y: h / 2 + dy))
                    ctx.stroke(p, with: .color(c(0)), style: StrokeStyle(lineWidth: max(1.2, w * 0.08), lineCap: .round))
                }
            case .mug:
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.12, y: h * 0.3, width: w * 0.56, height: h * 0.6), cornerRadius: w * 0.08), with: .color(c(1)))
                ctx.stroke(Path(ellipseIn: CGRect(x: w * 0.58, y: h * 0.42, width: w * 0.3, height: h * 0.3)), with: .color(c(1)), lineWidth: max(1.5, w * 0.08))
                var steam = Path(); steam.move(to: CGPoint(x: w * 0.4, y: h * 0.22)); steam.addQuadCurve(to: CGPoint(x: w * 0.4, y: h * 0.02), control: CGPoint(x: w * 0.55, y: h * 0.12))
                ctx.stroke(steam, with: .color(c(0)), style: StrokeStyle(lineWidth: max(1, w * 0.06), lineCap: .round))
            default:
                break
            }
    }

    private func drawB(_ ctx: GraphicsContext, _ size: CGSize) {
            let w: CGFloat = size.width, h: CGFloat = size.height
            switch kind {
            case .ribbon:
                var bowL = Path(); bowL.move(to: CGPoint(x: w / 2, y: h * 0.45)); bowL.addLine(to: CGPoint(x: w * 0.08, y: h * 0.18)); bowL.addLine(to: CGPoint(x: w * 0.08, y: h * 0.72)); bowL.closeSubpath()
                var bowR = Path(); bowR.move(to: CGPoint(x: w / 2, y: h * 0.45)); bowR.addLine(to: CGPoint(x: w * 0.92, y: h * 0.18)); bowR.addLine(to: CGPoint(x: w * 0.92, y: h * 0.72)); bowR.closeSubpath()
                ctx.fill(bowL, with: .color(c(0))); ctx.fill(bowR, with: .color(c(0)))
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.38, y: h * 0.33, width: w * 0.24, height: h * 0.24)), with: .color(c(1)))
            case .diya:
                var bowl = Path(); bowl.move(to: CGPoint(x: w * 0.08, y: h * 0.55))
                bowl.addQuadCurve(to: CGPoint(x: w * 0.92, y: h * 0.55), control: CGPoint(x: w / 2, y: h * 1.05)); bowl.closeSubpath()
                var flame = Path(); flame.move(to: CGPoint(x: w / 2, y: h * 0.05))
                flame.addQuadCurve(to: CGPoint(x: w / 2, y: h * 0.5), control: CGPoint(x: w * 0.72, y: h * 0.4))
                flame.addQuadCurve(to: CGPoint(x: w / 2, y: h * 0.05), control: CGPoint(x: w * 0.28, y: h * 0.4))
                ctx.fill(bowl, with: .color(c(0))); ctx.fill(flame, with: .color(c(1)))
            case .pot:
                ctx.fill(Path(ellipseIn: CGRect(x: w * 0.12, y: h * 0.3, width: w * 0.76, height: h * 0.64)), with: .color(c(1)))
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.26, y: h * 0.22, width: w * 0.48, height: h * 0.14), cornerRadius: 2), with: .color(c(1)))
                for i in 0..<3 { ctx.fill(Path(ellipseIn: CGRect(x: w * (0.24 + 0.17 * Double(i)), y: h * 0.06, width: w * 0.2, height: h * 0.2)), with: .color(c(0))) }
            case .lantern:
                var l = Path(); l.move(to: CGPoint(x: w / 2, y: h * 0.12)); l.addLine(to: CGPoint(x: w * 0.8, y: h * 0.42)); l.addLine(to: CGPoint(x: w * 0.68, y: h * 0.88)); l.addLine(to: CGPoint(x: w * 0.32, y: h * 0.88)); l.addLine(to: CGPoint(x: w * 0.2, y: h * 0.42)); l.closeSubpath()
                ctx.fill(l, with: .color(c(0)))
                ctx.fill(Path(roundedRect: CGRect(x: w * 0.4, y: h * 0.45, width: w * 0.2, height: h * 0.28), cornerRadius: 1.5), with: .color(c(1)))
                var cord = Path(); cord.move(to: CGPoint(x: w / 2, y: 0)); cord.addLine(to: CGPoint(x: w / 2, y: h * 0.12))
                ctx.stroke(cord, with: .color(c(0)), lineWidth: 1)
            case .crescent:
                let r = min(w, h) * 0.42
                var moon = Path(ellipseIn: CGRect(x: w / 2 - r, y: h / 2 - r, width: r * 2, height: r * 2))
                moon = moon.subtracting(Path(ellipseIn: CGRect(x: w / 2 - r * 0.45, y: h / 2 - r * 1.05, width: r * 2, height: r * 2)))
                ctx.fill(moon, with: .color(c(0)))
            case .star8:
                let s = min(w, h) * 0.62
                for a in [0.0, .pi / 4] {
                    let sq = Path(CGRect(x: -s / 2, y: -s / 2, width: s, height: s))
                        .applying(CGAffineTransform(rotationAngle: a)).applying(CGAffineTransform(translationX: w / 2, y: h / 2))
                    ctx.fill(sq, with: .color(c(0)))
                }
            case .sticker:
                // A round sunflower sticker with a white die-cut edge.
                let r = min(w, h) * 0.46
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - r + 2, y: h / 2 - r + 2.5, width: r * 2, height: r * 2)), with: .color(c(3)))
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - r, y: h / 2 - r, width: r * 2, height: r * 2)), with: .color(.white))
                ctx.fill(Path(ellipseIn: CGRect(x: w / 2 - r * 0.8, y: h / 2 - r * 0.8, width: r * 1.6, height: r * 1.6)), with: .color(c(0)))
            default:
                break
            }
    }
}

// MARK: - Band contents

/// The pattern inside (or, for calm themes, under) the Today header. Static
/// parts only; falling things are `AmbientLayer`.
struct HeaderMotifLayer: View {
    let decor: ThemeDecor
    var scale: CGFloat = 1

    private var colors: [Color] { decor.motifColors.map { Color(hex: $0) } }

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            ZStack(alignment: .topLeading) {
                switch decor.motif {
                case .horizon:
                    Rectangle().fill(colors[1].opacity(0.35)).frame(width: w, height: 1.5 * scale)
                        .position(x: w / 2, y: h - 3 * scale)
                    Circle().fill(colors[0].opacity(0.55)).frame(width: 10 * scale, height: 10 * scale)
                        .position(x: w * 0.82, y: h - 8 * scale)
                case .brassRule:
                    Rectangle().fill(colors[0]).frame(width: w - 32 * scale, height: 1.5 * scale)
                        .position(x: w / 2, y: h - 2 * scale)
                case .moon:
                    MotifGlyph(kind: .crescent, colors: [colors[0]]).frame(width: 16 * scale, height: 16 * scale)
                        .position(x: w * 0.42, y: 18 * scale)
                case .lotus:
                    MotifGlyph(kind: .lotus, colors: colors).frame(width: 18 * scale, height: 16 * scale)
                        .position(x: w * 0.47, y: 18 * scale)
                case .ruled:
                    ForEach(0..<Int(max(1, h / (14 * scale))), id: \.self) { i in
                        Rectangle().fill(colors[1].opacity(0.35)).frame(width: w, height: 1)
                            .position(x: w / 2, y: CGFloat(i + 1) * 14 * scale)
                    }
                    Rectangle().fill(colors[0].opacity(0.7)).frame(width: 1.5 * scale, height: h)
                        .position(x: 10 * scale, y: h / 2)
                case .sun:
                    MotifGlyph(kind: .sun, colors: [colors[0]]).frame(width: 30 * scale, height: 30 * scale)
                        .position(x: w * 0.47, y: h * 0.42)
                case .rain:
                    MotifGlyph(kind: .boat, colors: [Color.white, colors[1]]).frame(width: 18 * scale, height: 14 * scale)
                        .position(x: w * 0.47, y: h - 10 * scale)
                case .petals:
                    ForEach(0..<3, id: \.self) { i in
                        MotifGlyph(kind: .petal, colors: colors).frame(width: 12 * scale, height: 12 * scale)
                            .position(x: w * [0.36, 0.52, 0.66][i], y: h * [0.3, 0.62, 0.36][i])
                    }
                case .leaves:
                    MotifGlyph(kind: .leaf, colors: [colors[0], colors[2]]).frame(width: 16 * scale, height: 16 * scale)
                        .position(x: w * 0.47, y: h * 0.4)
                case .snow:
                    MotifGlyph(kind: .mug, colors: [Color.white, colors[1]]).frame(width: 16 * scale, height: 16 * scale)
                        .position(x: w * 0.47, y: h * 0.45)
                case .lights:
                    LightsString(colors: colors, width: w, scale: scale)
                        .position(x: w / 2, y: h - 6 * scale)
                case .diyas:
                    HStack(spacing: 18 * scale) {
                        ForEach(0..<5, id: \.self) { _ in
                            MotifGlyph(kind: .diya, colors: [colors[0], colors[1]]).frame(width: 14 * scale, height: 12 * scale)
                        }
                    }
                    .position(x: w / 2, y: h - 9 * scale)
                case .splashes:
                    Splash(color: colors[0]).frame(width: 46 * scale, height: 40 * scale).position(x: 6 * scale, y: 4 * scale)
                    Splash(color: colors[1]).frame(width: 34 * scale, height: 30 * scale).position(x: w * 0.55, y: -2 * scale)
                    Splash(color: colors[2]).frame(width: 40 * scale, height: 34 * scale).position(x: w - 4 * scale, y: 6 * scale)
                    Splash(color: colors[3]).frame(width: 22 * scale, height: 20 * scale).position(x: w * 0.82, y: h * 0.35)
                case .kolam:
                    HStack(spacing: 7 * scale) {
                        ForEach(0..<Int(w / (11 * scale)), id: \.self) { i in
                            Circle().fill(colors[i % 2 == 0 ? 0 : 1]).frame(width: 4 * scale, height: 4 * scale)
                        }
                    }
                    .position(x: w / 2, y: h - 4 * scale)
                case .crescentLantern:
                    MotifGlyph(kind: .crescent, colors: [colors[0]]).frame(width: 18 * scale, height: 18 * scale)
                        .position(x: w * 0.42, y: h * 0.32)
                    MotifGlyph(kind: .lantern, colors: [colors[0], colors[1]]).frame(width: 12 * scale, height: 20 * scale)
                        .position(x: w * 0.5, y: h * 0.45)
                case .starStrip:
                    HStack(spacing: 10 * scale) {
                        ForEach(0..<Int(w / (20 * scale)), id: \.self) { _ in
                            MotifGlyph(kind: .star8, colors: [colors[0]]).frame(width: 10 * scale, height: 10 * scale)
                        }
                    }
                    .position(x: w / 2, y: h - 5 * scale)
                case .none:
                    EmptyView()
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct LightsString: View {
    let colors: [Color]
    let width: CGFloat
    let scale: CGFloat

    var body: some View {
        let n = max(4, Int(width / (22 * scale)))
        ZStack {
            Path { p in
                p.move(to: CGPoint(x: 0, y: 0))
                for i in 0..<n {
                    let x0 = CGFloat(i) * width / CGFloat(n), x1 = CGFloat(i + 1) * width / CGFloat(n)
                    p.addQuadCurve(to: CGPoint(x: x1, y: 0), control: CGPoint(x: (x0 + x1) / 2, y: 6 * scale))
                }
            }
            .stroke(colors[2].opacity(0.6), lineWidth: 1)
            ForEach(0..<n, id: \.self) { i in
                Circle().fill(colors[i % 4 == 2 ? 3 : i % 2])
                    .frame(width: 5 * scale, height: 5 * scale)
                    .position(x: (CGFloat(i) + 0.5) * width / CGFloat(n), y: 4.5 * scale)
            }
        }
        .frame(width: width, height: 10 * scale)
    }
}

/// A flat colour splash: a few overlapping circles, no blur.
private struct Splash: View {
    let color: Color
    var body: some View {
        Canvas { ctx, size in
            let w = size.width, h = size.height
            for (x, y, r) in [(0.5, 0.5, 0.36), (0.25, 0.4, 0.2), (0.72, 0.62, 0.22), (0.55, 0.2, 0.14), (0.88, 0.3, 0.07), (0.12, 0.82, 0.06)] {
                let rr = min(w, h) * r
                ctx.fill(Path(ellipseIn: CGRect(x: w * x - rr, y: h * y - rr, width: rr * 2, height: rr * 2)), with: .color(color))
            }
        }
    }
}

// MARK: - Falling things

/// Slow rain, snow, petals or leaves inside a header band or the sky, and the
/// twinkle of lights. Runs only while on screen; still under Reduce Motion.
struct AmbientLayer: View {
    let ambient: ThemeAmbient
    let colors: [Color]
    var density: Int = 14
    /// A frozen frame, for thumbnails.
    var still: Bool = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if ambient == .none || ambient == .twinkle {
                EmptyView()
            } else if reduceMotion || still {
                Canvas { ctx, size in draw(ctx, size, 0) }
            } else {
                SwiftUI.TimelineView(.periodic(from: .now, by: 1.0 / 20)) { tl in
                    Canvas { ctx, size in draw(ctx, size, tl.date.timeIntervalSinceReferenceDate) }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: TimeInterval) {
        let n = density
        for i in 0..<n {
            let seed = Double(i) * 12.9898
            let x0 = (sin(seed) * 43758.5453).truncatingRemainder(dividingBy: 1)
            let fx = abs(x0)
            let speed: Double
            switch ambient {
            case .rain: speed = 0.55
            case .snow: speed = 0.08
            default: speed = 0.06
            }
            let phase = (t * speed + Double(i) / Double(n)).truncatingRemainder(dividingBy: 1)
            let y = phase * (size.height + 20) - 10
            let sway = (ambient == .rain) ? -phase * 10 : sin(t * 0.8 + seed) * 6
            let x = fx * size.width + sway
            switch ambient {
            case .rain:
                var p = Path(); p.move(to: CGPoint(x: x, y: y)); p.addLine(to: CGPoint(x: x - 2.5, y: y + 9))
                ctx.stroke(p, with: .color(colors[0].opacity(0.6)), style: StrokeStyle(lineWidth: 1.2, lineCap: .round))
            case .snow:
                let r = 1.4 + fx * 1.4
                ctx.fill(Path(ellipseIn: CGRect(x: x - r, y: y - r, width: r * 2, height: r * 2)), with: .color(colors[0].opacity(0.85)))
            case .petals, .leaves:
                let col = colors[i % max(1, min(2, colors.count))]
                var p = Path(ellipseIn: CGRect(x: -3, y: -1.6, width: 6, height: 3.2))
                p = p.applying(CGAffineTransform(rotationAngle: t * 0.6 + seed)).applying(CGAffineTransform(translationX: x, y: y))
                ctx.fill(p, with: .color(col.opacity(0.9)))
            default: break
            }
        }
    }
}

// MARK: - Today band

/// Behind the Today header, by day: the theme's band (filling up under the
/// status bar), its motif and its weather. Calm themes have no band, only
/// their small mark.
struct TodayHeaderDecoration: View {
    @Environment(\.dvTheme) private var theme
    var decor: ThemeDecor = ThemeManager.shared.appliedThemeID.decor

    var body: some View {
        if theme.isNight {
            EmptyView()
        } else {
            ZStack {
                if let band = decor.band {
                    Color(hex: band)
                    AmbientLayer(ambient: decor.ambient,
                                 colors: decor.ambient == .rain ? [Color(hex: decor.motifColors.first ?? 0xFFFFFF)]
                                 : decor.motifColors.map { Color(hex: $0) })
                }
                HeaderMotifLayer(decor: decor)
                    .padding(.top, decor.hasBand ? 0 : 0)
            }
            .clipped()
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}

extension ThemeDecor {
    /// Header text colours: the band's own inks by day, the theme's otherwise.
    func headerInk(_ theme: DVTheme) -> Color? {
        guard hasBand, !theme.isNight else { return nil }
        return Color(hex: bandInk)
    }
    func headerInkSoft(_ theme: DVTheme) -> Color? {
        guard hasBand, !theme.isNight else { return nil }
        return Color(hex: bandInkSoft)
    }
    func headerGold(_ theme: DVTheme) -> Color? {
        guard hasBand, !theme.isNight else { return nil }
        return Color(hex: bandGold)
    }
}

// MARK: - Card edges

extension View {
    /// Sticker: an ink outline and a hard offset shadow. High contrast: a 2pt
    /// outline. Everyone else: the soft shadow the app has always had.
    @ViewBuilder
    func themedCardEdge(cornerRadius: CGFloat = 20) -> some View {
        let decor = ThemeManager.shared.appliedThemeID.decor
        let ink = DS.Palette.ink
        switch decor.card {
        case .sticker:
            self
                .overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(ink, lineWidth: 2))
                .background(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(ink.opacity(0.9)).offset(x: 3, y: 4))
        case .outlined:
            self.overlay(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous).stroke(ink, lineWidth: 2))
        case .soft:
            self.dsShadowSoft()
        }
    }
}

// MARK: - Record dial dressing

/// Sits behind the dial's Canvas, 288pt square.
struct DialDecoration: View {
    let style: ThemeDial
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            switch style {
            case .standard:
                EmptyView()
            case .sticker:
                // A chunky white die-cut ring with a hard ink shadow.
                Circle().stroke(Color.black.opacity(0.55), lineWidth: 16).offset(x: 4, y: 5)
                Circle().stroke(Color.white, lineWidth: 16)
            case .ripples:
                if reduceMotion {
                    ForEach(0..<3, id: \.self) { i in
                        Circle().stroke(Color(hex: 0xC9D6E0).opacity(0.25 - Double(i) * 0.07), lineWidth: 1.2)
                            .scaleEffect(1.06 + CGFloat(i) * 0.08)
                    }
                } else {
                    SwiftUI.TimelineView(.periodic(from: .now, by: 1.0 / 20)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate
                        ZStack {
                            ForEach(0..<3, id: \.self) { i in
                                let ph = (t / 3.2 + Double(i) / 3).truncatingRemainder(dividingBy: 1)
                                Circle().stroke(Color(hex: 0xC9D6E0).opacity(0.35 * (1 - ph)), lineWidth: 1.4)
                                    .scaleEffect(1.02 + ph * 0.22)
                            }
                        }
                    }
                }
            case .bud:
                ForEach(0..<12, id: \.self) { i in
                    Ellipse().fill(Color(hex: 0xF5B3C6))
                        .frame(width: 9, height: 18)
                        .offset(y: -154)
                        .rotationEffect(.degrees(Double(i) * 30))
                }
            case .rangoli:
                ForEach(0..<36, id: \.self) { i in
                    Circle().fill(Color(hex: i % 3 == 0 ? 0xB5297A : (i % 3 == 1 ? 0xF5B84A : 0xF4F0FF)))
                        .frame(width: i % 3 == 0 ? 7 : 4.5, height: i % 3 == 0 ? 7 : 4.5)
                        .offset(y: -156)
                        .rotationEffect(.degrees(Double(i) * 10))
                }
            }
        }
        .frame(width: 288, height: 288)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Sky marks

/// Over the Twin sky: a star or crescent at the top, or slow rain or snow.
struct SkyDecoration: View {
    let decor: ThemeDecor

    var body: some View {
        ZStack(alignment: .top) {
            switch decor.sky {
            case .rain:
                AmbientLayer(ambient: .rain, colors: [Color(hex: 0xC9D6E0).opacity(0.7)], density: 22)
            case .snow:
                AmbientLayer(ambient: .snow, colors: [Color.white.opacity(0.8)], density: 24)
            case .star:
                MotifGlyph(kind: .star8, colors: [Color(hex: 0xF2D67A)])
                    .frame(width: 22, height: 22)
                    .padding(.top, 8)
            case .crescent:
                MotifGlyph(kind: .crescent, colors: [Color(hex: 0xE8C46A)])
                    .frame(width: 26, height: 26)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.top, 8).padding(.trailing, 28)
            case .none:
                EmptyView()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Streak mark

struct StreakMark: View {
    let mark: ThemeStreakMark
    let colors: [Color]

    var body: some View {
        Group {
            switch mark {
            case .none: EmptyView()
            case .sticker: MotifGlyph(kind: .sticker, colors: colors)
            case .lotus: MotifGlyph(kind: .lotus, colors: colors)
            case .petal: MotifGlyph(kind: .petal, colors: colors)
            case .sun: MotifGlyph(kind: .sun, colors: [colors.first ?? .orange])
            case .boat: MotifGlyph(kind: .boat, colors: [Color(hex: 0x3E5466), Color(hex: 0xF2B705)])
            case .leaf: MotifGlyph(kind: .leaf, colors: [Color(hex: 0xC9971F), Color(hex: 0x7A3E5A)])
            case .mug: MotifGlyph(kind: .mug, colors: [Color(hex: 0x9AB7C8), Color(hex: 0xA3243F)])
            case .ribbon: MotifGlyph(kind: .ribbon, colors: [Color(hex: 0x9B1F2E), Color(hex: 0xC8A13A)])
            case .diya: MotifGlyph(kind: .diya, colors: [Color(hex: 0xB8572A), Color(hex: 0xE8930C)])
            case .pot: MotifGlyph(kind: .pot, colors: [Color(hex: 0xFFFFFF), Color(hex: 0xB8572A)])
            case .lantern: MotifGlyph(kind: .lantern, colors: [Color(hex: 0xC9952A), Color(hex: 0xF4F3EE)])
            case .star: MotifGlyph(kind: .star8, colors: [Color(hex: 0xB8912F)])
            }
        }
        .frame(width: 26, height: 26)
        .accessibilityHidden(true)
    }
}
