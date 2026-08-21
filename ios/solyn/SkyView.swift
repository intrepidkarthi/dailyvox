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
    /// When it was spoken. Drives BOTH polar coordinates — see `SkyView`.
    let date: Date
    /// Seconds spoken. Drives the star's size.
    let duration: Double
    /// Stable per-entry seed. Now only a small jitter, not the position itself.
    let seed: UInt64
}

/// A named star — a person or topic the graph knows.
struct SkyNamed {
    let label: String
    /// How many entries mention them. Drives size.
    let mentions: Int
    /// Last time they came up. Drives distance from the core.
    let lastSeen: Date
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
    let named: [SkyNamed]

    /// The subtree's theme. On the Twin tab that is night whatever the app
    /// theme says; the sky has no cream variant.
    @Environment(\.dvTheme) private var theme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The phase the still sky is frozen at. Not zero: at t=0 both orbit rings
    /// and the comet sit at the same angle, which draws a seam. Chosen so the
    /// three periods (80s / 130s / 18s) land well apart.
    private static let stillPhase: TimeInterval = 21

    /// Matches Android's MAX_DRAWN_TWINKLES. One twinkle per entry meant a
    /// 1,000-entry journal animated a thousand circles a frame, and it got
    /// worse the longer someone used the app.
    static let maxDrawnTwinkles = 156

    init(entries: [SkyEntry], named: [SkyNamed]) {
        self.entries = entries
        self.named = named
    }

    // The encoding itself lives in `SkyEncoding` — it was written here AND in
    // the share-card renderer AND twice more for named stars, and four copies of
    // a rule that drifts silently is not a rule.

    private var span: SkyEncoding.Span { SkyEncoding.Span(dates: entries.map(\.date)) }

    private func near(_ minDim: CGFloat) -> CGFloat { minDim * 0.14 }
    private func far(_ minDim: CGFloat) -> CGFloat { minDim * 0.47 }
    private func namedNear(_ minDim: CGFloat) -> CGFloat { minDim * 0.20 }
    private func namedFar(_ minDim: CGFloat) -> CGFloat { minDim * 0.44 }

    /// Every colour the sky draws with. On cream the thin strokes need the
    /// darker gold; plain #D9A441 at 1.4pt all but vanishes on #F7F3EA.
    private var palette: (ink: Color, line: Color, core: Color, accent: Color) {
        theme.isNight
            ? (DS.Palette.navyText, DS.Palette.gold, DS.Palette.gold, DS.Palette.starBlue)
            : (DS.Palette.ink, DS.Palette.goldDay, DS.Palette.gold,
               Color(red: 0.298, green: 0.482, blue: 0.651))
    }

    var body: some View {
        // §8.8: "pause ambient sky/orbit loops" under reduced motion. The sky
        // still DRAWS — the constellation is the content, not the animation —
        // it just stops at a fixed phase instead of drifting, twinkling and
        // running a comet. `.animation` schedules a redraw every frame, so the
        // guard has to be on the schedule itself, not inside the draw call.
        if reduceMotion {
            Canvas { context, size in
                draw(context: context, size: size, t: Self.stillPhase)
            }
            .overlay(alignment: .topLeading) { labels(t: Self.stillPhase) }
        } else {
            // SwiftUI.TimelineView, spelled out: this app already has a
            // `TimelineView` — the Journal screen — and the unqualified name
            // resolves to that one, which reports as "argument passed to call
            // that takes no arguments" rather than as a collision.
            SwiftUI.TimelineView(.animation) { timeline in
                let t = timeline.date.timeIntervalSinceReferenceDate

                Canvas { context, size in
                    draw(context: context, size: size, t: t)
                }
                .overlay(alignment: .topLeading) { labels(t: t) }
            }
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

        // Every entry, placed by WHEN — distance is how long ago, angle is the
        // hour it was spoken. See the encoding note above.
        let s = span
        for (i, e) in entries.prefix(Self.maxDrawnTwinkles).enumerated() {
            let a = SkyEncoding.age(e.date, in: s)
            let pt = SkyEncoding.entryPoint(date: e.date, in: s, jitter: e.seed,
                                            centre: centre,
                                            near: near(minDim), far: far(minDim))

            // Size is how long you spoke: a passing thought is a smaller star
            // than a night you needed twenty minutes for.
            let spoke = min(max(e.duration, 0) / 180, 1)
            let r = 1.7 + spoke * 2.6

            // Nine staggered phases at 2.7–4.1s, so no two land together — the
            // stagger is what stops it reading as a pulsing diagram. Recent
            // stars twinkle brighter; the far past is quieter.
            let k = i % 9
            let period = 2.7 + Double(k) * 0.18
            let tw = 0.22 + 0.78 * (0.5 + 0.5 * Foundation.sin((t + Double(k) * 0.26) * .pi * 2 / period))
            let recency = 1.0 - a * 0.55

            context.fill(
                Circle().path(in: CGRect(x: pt.x - r, y: pt.y - r, width: r * 2, height: r * 2)),
                with: .color(valenceColour(e.valence).opacity(0.85 * tw * recency)))
        }

        // Tonight, if it exists: the newest star, given a halo so you can find
        // the one you just made.
        if let newest = entries.min(by: { $0.date > $1.date }),
           Calendar.current.isDateInToday(newest.date) {
            let pt = SkyEncoding.entryPoint(date: newest.date, in: s, jitter: newest.seed,
                                            centre: centre,
                                            near: near(minDim), far: far(minDim))
            let pulse = 0.5 + 0.5 * Foundation.sin(t * .pi * 2 / 3.2)
            let halo = 9 + 3 * pulse
            context.fill(
                Circle().path(in: CGRect(x: pt.x - halo, y: pt.y - halo,
                                         width: halo * 2, height: halo * 2)),
                with: .color(p.core.opacity(0.18 + 0.10 * pulse)))
            context.fill(
                Circle().path(in: CGRect(x: pt.x - 3.4, y: pt.y - 3.4, width: 6.8, height: 6.8)),
                with: .color(p.core))
        }

        // Named stars, placed by MEANING rather than at four fixed anchors.
        //
        // Distance is how recently they came up, size is how often. Someone in
        // your life this week sits close and large; someone you have not
        // mentioned since spring has drifted to the rim and shrunk. The old
        // version pinned them to the same four corners forever, so the screen
        // said the same thing on day three as on day three hundred.
        let mostMentions = max(named.map(\.mentions).max() ?? 1, 1)
        for (i, person) in named.prefix(4).enumerated() {
            let personAge = SkyEncoding.age(person.lastSeen, in: s)
            let anchor = SkyEncoding.namedPoint(
                rank: i, of: named.prefix(4).count,
                lastSeen: person.lastSeen, in: s, centre: centre,
                near: namedNear(minDim), far: namedFar(minDim))
            // How big a part of the journal they are.
            let weight = Double(person.mentions) / Double(mostMentions)
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
                           with: .color(p.line.opacity(0.18 + 0.34 * (1 - personAge))),
                           lineWidth: 1.0 + CGFloat(weight) * 1.2)

            let node = i == 1 ? p.accent : p.ink
            // Size carries mentions; a recent person also burns brighter.
            let nr = 4.0 + weight * 5.0
            let halo = nr + 5.5
            context.fill(
                Circle().path(in: CGRect(x: anchor.x - halo, y: anchor.y - halo,
                                         width: halo * 2, height: halo * 2)),
                with: .color(node.opacity(0.10 + 0.14 * (1 - personAge))))
            context.fill(
                Circle().path(in: CGRect(x: anchor.x - nr, y: anchor.y - nr,
                                         width: nr * 2, height: nr * 2)),
                with: .color(node.opacity(0.55 + 0.45 * (1 - personAge))))
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
    /// Names, pinned to the stars they belong to.
    ///
    /// They used to sit at three hard-coded screen positions while the stars sat
    /// at four other hard-coded positions — so a label and its star had no
    /// relationship at all, and one name got a chip while the others did not for
    /// no reason a reader could infer. Now each name follows its own star, and
    /// all of them are drawn the same way.
    /// Names, pinned to the stars they belong to — using the SAME encoding the
    /// stars are drawn with, rather than a second copy of the maths that used to
    /// sit here and silently drift.
    private func labels(t: TimeInterval) -> some View {
        GeometryReader { geo in
            let minDim = min(geo.size.width, geo.size.height)
            let centre = CGPoint(x: geo.size.width / 2, y: geo.size.height * 0.47)
            let s = span
            let shown = Array(named.prefix(4).enumerated())

            ZStack(alignment: .topLeading) {
                ForEach(shown, id: \.element.label) { i, person in
                    let personAge = SkyEncoding.age(person.lastSeen, in: s)
                    let anchor = SkyEncoding.namedPoint(
                        rank: i, of: shown.count,
                        lastSeen: person.lastSeen, in: s, centre: centre,
                        near: namedNear(minDim), far: namedFar(minDim))
                    let rad = SkyEncoding.namedDegrees(rank: i, of: shown.count) * .pi / 180

                    Text(person.label.uppercased())
                        .font(.dv(size: 10, weight: .heavy, design: .rounded))
                        // A name not said in months is quieter, the same way its
                        // star is.
                        .foregroundColor(theme.goldText.opacity(0.55 + 0.45 * (1 - personAge)))
                        .fixedSize()
                        // Nudged outward along its own spoke so the text never
                        // sits on its node.
                        .position(x: anchor.x + CGFloat(Foundation.cos(rad)) * 34,
                                  y: anchor.y + CGFloat(Foundation.sin(rad)) * 20)
                }
            }
        }
        .allowsHitTesting(false)
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
