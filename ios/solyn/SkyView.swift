//
//  SkyView.swift
//  solyn
//
//  The Twin's living sky (design C2) — the Swift port of Android's `drawSky`.
//

import Foundation
import SwiftUI

/// One entry, as the sky needs it.
struct SkyEntry {
    let id: String
    let valence: Double
    /// Stable per-entry seed, so the same journal always draws the same sky.
    let seed: UInt64
}

/// The constellation, full-bleed and alive.
///
/// This replaces `ConstellationView` on the Twin tab. That one drew a bordered
/// navy CARD sitting on the page, and it did not move; Android's has no border,
/// fills the screen, follows the theme, and animates — orbits counter-rotating,
/// a comet on the outer ring, stars twinkling on staggered cycles. The two
/// platforms are meant to be the same object, so this is a deliberate port of
/// `TwinScreen.drawSky` rather than a second interpretation of the spec.
///
/// Every timing and ratio below matches the Kotlin. If one changes, both change.
struct SkyView: View {
    let entries: [SkyEntry]
    /// Up to three named stars, biggest first.
    let named: [String]

    @ObservedObject private var theme = ThemeManager.shared

    /// Matches Android's MAX_DRAWN_TWINKLES. One twinkle per entry meant a
    /// 1,000-entry journal animated a thousand circles a frame, and it got
    /// worse the longer someone used the app.
    static let maxDrawnTwinkles = 156

    init(entries: [SkyEntry], named: [String]) {
        self.entries = entries
        self.named = named
    }

    private var palette: (ink: Color, line: Color, core: Color, accent: Color) {
        theme.isNight
            ? (DS.Palette.navyText, DS.Palette.gold, DS.Palette.gold, DS.Palette.starBlue)
            // On cream the thin strokes need the darker gold; plain #D9A441 at
            // 1.4pt all but vanishes on #F7F3EA.
            : (DS.Palette.ink, DS.Palette.goldDay, DS.Palette.gold,
               Color(red: 0.298, green: 0.482, blue: 0.651))
    }

    var body: some View {
        // SwiftUI.TimelineView, spelled out: this app already has a
        // `TimelineView` — the Journal screen — and the unqualified name
        // resolves to that one, which reports as "argument passed to call that
        // takes no arguments" rather than as a collision.
        SwiftUI.TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate

            Canvas { context, size in
                draw(context: context, size: size, t: t)
            }
            .overlay(alignment: .topLeading) { labels(t: t) }
        }
        // NO background of its own. Painting one — even in the page colour —
        // gives the sky a rectangle, and the radial glow terminating at that
        // rectangle's edge is what read as a border. The page shows through.
    }

    // MARK: - Drawing

    private func draw(context: GraphicsContext, size: CGSize, t: TimeInterval) {
        let p = palette
        let minDim = min(size.width, size.height)
        let centre = CGPoint(x: size.width / 2, y: size.height * 0.47)

        // Phases, in the same periods as the Kotlin.
        let orbitInner = angle(t, period: 80)
        let orbitOuter = -angle(t, period: 130)
        let comet = angle(t, period: 18)
        let innerBody = -angle(t, period: 30)
        // 5s breathe, eased — 0.7…1.0.
        let coreGlow = 0.85 + 0.15 * Foundation.sin(t * .pi * 2 / 5)

        // Centre glow — sized to FIT.
        //
        // This is what "the sky still has borders" was, and it was never the
        // background or the padding. A Canvas clips to its bounds, so Android's
        // 0.62-of-min-dimension glow (fine there, where the sky is ~550pt tall)
        // became a 211pt circle inside a 340pt frame and got sliced flat on all
        // four sides. A radial gradient clipped to a rectangle IS a rectangle.
        //
        // Never larger than the distance to the nearest edge, so the gradient
        // always reaches transparent before it reaches a boundary.
        let fits = min(centre.x, size.width - centre.x, centre.y, size.height - centre.y)
        let glowR = min(minDim * 0.62, fits * 0.98)
        context.fill(
            Circle().path(in: CGRect(x: centre.x - glowR, y: centre.y - glowR,
                                     width: glowR * 2, height: glowR * 2)),
            with: .radialGradient(
                Gradient(colors: [p.core.opacity(0.22 * coreGlow), .clear]),
                center: centre, startRadius: 0, endRadius: glowR))

        // Two dashed orbit rings, counter-rotating. The dash PHASE carries the
        // rotation: rotating a circle is a no-op, so a rotation transform would
        // have produced a perfectly static ring.
        for (radius, phase) in [(minDim * 0.20, orbitInner), (minDim * 0.33, orbitOuter)] {
            let circumference = 2 * Double.pi * radius
            var ring = Path()
            ring.addEllipse(in: CGRect(x: centre.x - radius, y: centre.y - radius,
                                       width: radius * 2, height: radius * 2))
            context.stroke(
                ring,
                with: .color(p.ink.opacity(radius < minDim * 0.25 ? 0.16 : 0.10)),
                style: StrokeStyle(lineWidth: 1, dash: [1, 6],
                                   dashPhase: circumference * (phase / 360)))
        }

        // Twinkles: the rest of the journal, seeded so the sky is stable.
        for (i, e) in entries.dropFirst(4).prefix(Self.maxDrawnTwinkles).enumerated() {
            var rng = e.seed
            func next() -> Double {
                rng = rng &* 6364136223846793005 &+ 1442695040888963407
                return Double((rng >> 33) % 10000) / 10000
            }
            // Very slow parallax — a full pass takes over three minutes, and
            // near stars drift further than far ones. Too slow to watch happen,
            // fast enough that the field is never quite where you left it.
            let depth = 0.35 + Double(i % 5) * 0.16
            let drift = CGFloat((t / 200).truncatingRemainder(dividingBy: 1.0) * depth)
            var x = next() + drift
            if x > 1 { x -= 1 }
            let pt = CGPoint(x: CGFloat(x) * size.width, y: next() * size.height)
            // Keep the core legible.
            if abs(pt.x - centre.x) < size.width * 0.10,
               abs(pt.y - centre.y) < size.height * 0.12 { continue }

            // Nine staggered phases at 2.7–4.1s, so no two land together. That
            // stagger is what stops it reading as a pulsing diagram.
            let k = i % 9
            let period = 2.7 + Double(k) * 0.18
            let tw = 0.22 + 0.78 * (0.5 + 0.5 * Foundation.sin((t + Double(k) * 0.26) * .pi * 2 / period))
            let r = 1.6 + Double(i % 3) * 0.35
            context.fill(
                Circle().path(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                with: .color(valenceColour(e.valence).opacity(0.5 * tw)))
        }

        // Named stars: the four biggest, each on a curved link out of the core.
        let anchors = [
            CGPoint(x: centre.x - size.width * 0.23, y: centre.y - size.height * 0.21),
            CGPoint(x: centre.x + size.width * 0.24, y: centre.y - size.height * 0.16),
            CGPoint(x: centre.x - size.width * 0.17, y: centre.y + size.height * 0.28),
            CGPoint(x: centre.x + size.width * 0.22, y: centre.y + size.height * 0.23),
        ]
        for (i, anchor) in anchors.enumerated() where i < max(entries.count, 1) {
            // Control points pushed PERPENDICULAR to each core→star line.
            // Placed ON the line they give a mathematically valid quadratic
            // that is visually a straight segment — the curve has to bow.
            let mid = CGPoint(x: (centre.x + anchor.x) / 2, y: (centre.y + anchor.y) / 2)
            let d = CGPoint(x: anchor.x - centre.x, y: anchor.y - centre.y)
            let len = max(CGFloat(Foundation.sqrt(Double(d.x * d.x + d.y * d.y))), 1)
            // Alternate the bow so the four do not all sweep the same way,
            // which would read as a fan rather than a constellation.
            let bow = i % 2 == 0 ? 0.22 : -0.18
            let control = CGPoint(x: mid.x + (-d.y / len) * len * bow,
                                  y: mid.y + (d.x / len) * len * bow)

            var link = Path()
            link.move(to: centre)
            link.addQuadCurve(to: anchor, control: control)
            context.stroke(link,
                           with: .color(p.line.opacity(0.5 - Double(i) * 0.06)),
                           lineWidth: 1.4)

            let node = i == 1 ? p.accent : p.ink
            let halo = 11 - Double(i)
            context.fill(
                Circle().path(in: CGRect(x: anchor.x - halo, y: anchor.y - halo,
                                         width: halo * 2, height: halo * 2)),
                with: .color(node.opacity(0.15)))
            let nr = 6 - Double(i) * 0.5
            context.fill(
                Circle().path(in: CGRect(x: anchor.x - nr, y: anchor.y - nr,
                                         width: nr * 2, height: nr * 2)),
                with: .color(i == 3 ? p.core.opacity(0.85) : node))
        }

        // The core: a soft disc under a solid one.
        let soft = 18 * coreGlow
        context.fill(
            Circle().path(in: CGRect(x: centre.x - soft, y: centre.y - soft,
                                     width: soft * 2, height: soft * 2)),
            with: .color(p.core.opacity(0.2)))
        context.fill(
            Circle().path(in: CGRect(x: centre.x - 11, y: centre.y - 11, width: 22, height: 22)),
            with: .color(p.core))

        // Comet on the outer ring, with a tail.
        let rOuter = minDim * 0.33
        for k in 0..<6 {
            let a = (comet - 90 - Double(k) * 2.6) * .pi / 180
            let r = max(3.0 - Double(k) * 0.4, 0.6)
            let c = CGPoint(x: centre.x + rOuter * CGFloat(Foundation.cos(a)),
                            y: centre.y + rOuter * CGFloat(Foundation.sin(a)))
            context.fill(
                Circle().path(in: CGRect(x: c.x - r, y: c.y - r, width: r * 2, height: r * 2)),
                with: .color(p.line.opacity(0.28 * (1 - Double(k) / 6))))
        }
        let ca = (comet - 90) * .pi / 180
        let cp = CGPoint(x: centre.x + rOuter * CGFloat(Foundation.cos(ca)),
                         y: centre.y + rOuter * CGFloat(Foundation.sin(ca)))
        context.fill(Circle().path(in: CGRect(x: cp.x - 6, y: cp.y - 6, width: 12, height: 12)),
                     with: .color(p.core.opacity(0.25)))
        context.fill(Circle().path(in: CGRect(x: cp.x - 2.6, y: cp.y - 2.6, width: 5.2, height: 5.2)),
                     with: .color(p.core))

        // A blue body on the inner ring, the other way.
        let rInner = minDim * 0.20
        let ba = (innerBody - 90) * .pi / 180
        let bp = CGPoint(x: centre.x + rInner * CGFloat(Foundation.cos(ba)),
                         y: centre.y + rInner * CGFloat(Foundation.sin(ba)))
        context.fill(Circle().path(in: CGRect(x: bp.x - 2, y: bp.y - 2, width: 4, height: 4)),
                     with: .color(p.accent))

        drawShootingStar(context: context, size: size, t: t, palette: p)
    }

    /// A shooting star, rarely.
    ///
    /// The honest answer to "how do I make this interesting to watch for a long
    /// time": you cannot, with loops alone. Everything else here is periodic,
    /// so after a minute a viewer has seen the whole vocabulary and the motion
    /// becomes wallpaper. What holds attention is the possibility that
    /// SOMETHING MIGHT HAPPEN — so once every 47 seconds, for 1.4 of them, a
    /// star crosses.
    ///
    /// 47 is deliberately not a round number and shares no factor with the
    /// orbit periods (80, 130, 18, 30, 5). Nothing ever lines up twice, so the
    /// composition genuinely does not repeat rather than merely looking busy.
    private func drawShootingStar(context: GraphicsContext, size: CGSize,
                                  t: TimeInterval, palette p: (ink: Color, line: Color,
                                                               core: Color, accent: Color)) {
        let period = 47.0
        let duration = 1.4
        let cycle = t.truncatingRemainder(dividingBy: period)
        guard cycle < duration else { return }

        let progress = cycle / duration
        // A different entry angle each pass, from the cycle index, so it is not
        // the same streak on a timer.
        let index = Int(t / period)
        let seedAngle = Double((index &* 2654435761) % 360)
        let a = (seedAngle - 25) * .pi / 180

        // Travels a diagonal of the frame, entering off-screen.
        let span = CGFloat(Foundation.sqrt(Double(size.width * size.width
                                                  + size.height * size.height)))
        let dir = CGPoint(x: CGFloat(Foundation.cos(a)), y: CGFloat(Foundation.sin(a)))
        let entry = CGPoint(x: size.width / 2 - dir.x * span * 0.6,
                            y: size.height / 2 - dir.y * span * 0.6)
        let head = CGPoint(x: entry.x + dir.x * span * 1.2 * progress,
                           y: entry.y + dir.y * span * 1.2 * progress)

        // Fades in and out rather than popping; a hard cut reads as a glitch.
        let fade = Foundation.sin(progress * .pi)

        for k in 0..<10 {
            let back = Double(k) * 7.0
            let pt = CGPoint(x: head.x - dir.x * back, y: head.y - dir.y * back)
            let r = max(2.0 - Double(k) * 0.18, 0.4)
            context.fill(
                Circle().path(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                with: .color(p.core.opacity(0.55 * fade * (1 - Double(k) / 10))))
        }
    }

    /// Names sit in SwiftUI text above the Canvas — the sky is only meaningful
    /// if you can read who is in it.
    @ViewBuilder
    private func labels(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let goldText = theme.goldText
            ZStack(alignment: .topLeading) {
                if named.count > 0 {
                    Text(named[0].uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(goldText)
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(Capsule().fill(DS.Palette.gold.opacity(0.16)))
                        .position(x: 62, y: geo.size.height * 0.20)
                }
                if named.count > 1 {
                    Text(named[1].uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .position(x: geo.size.width - 62, y: geo.size.height * 0.26)
                }
                if named.count > 2 {
                    Text(named[2].uppercased())
                        .font(.system(size: 10, weight: .heavy, design: .rounded))
                        .foregroundColor(theme.secondaryTextColor)
                        .position(x: 74, y: geo.size.height * 0.82)
                }
            }
        }
    }

    // MARK: - Helpers

    private func angle(_ t: TimeInterval, period: Double) -> Double {
        (t.truncatingRemainder(dividingBy: period) / period) * 360
    }

    /// The same valence ramp the 30-night strip uses, so a good day is the same
    /// colour wherever it appears.
    private func valenceColour(_ v: Double) -> Color {
        if v > 0.2 { return DS.Palette.forest }
        if v > -0.2 { return DS.Palette.gold }
        return DS.Palette.coral
    }
}
