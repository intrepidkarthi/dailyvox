//
//  RecordingDialView.swift
//  solyn
//
//  B2b — the full-screen recording dial. The Swift port of Android's
//  `RecordingDial.kt`; every timing and ratio below matches the Kotlin.
//

import SwiftUI

/// Recording is a moment, not a state of the Record screen.
///
/// iOS used to record *inline*: a timer and a row of bars appeared under the mic
/// and the rest of the screen sat there unchanged — greeting, streak chips,
/// privacy card, tab bar. The design gives recording its own surface, and the
/// reason is not decoration. There are exactly three things to decide while you
/// are talking (keep it, pause it, throw it away) and a screen that keeps
/// offering the other twelve is asking you to think about the app instead of
/// about your day.
///
/// ALWAYS NAVY, whatever the theme — recording is a night moment by the same
/// logic that makes the sky always night, and it means the dial reads the same
/// at 8am and 11pm.
struct RecordingDialView: View {
    let elapsed: Int
    let level: CGFloat
    /// True between Pause and Resume.
    let paused: Bool
    /// Observed directly rather than passed as plain values.
    ///
    /// `LiveTranscriber` hangs off `AudioRecorder`, and a nested
    /// `ObservableObject` does not propagate — the recorder's own `objectWillChange`
    /// never fires for a change to `live.phrase`, so the line would have been
    /// written and then never updated. This is the bug that would have looked
    /// like "live transcription doesn't work" on device.
    @ObservedObject var live: LiveTranscriber
    let onStop: () -> Void
    let onDiscard: () -> Void
    let onPause: () -> Void
    let onResume: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The ritual, in seconds. Also the number of ticks.
    private static let ritual = 42

    var body: some View {
        ZStack {
            DS.Palette.navy.ignoresSafeArea()

            VStack(spacing: 0) {
                statusLine
                    .padding(.top, 20)

                Spacer()

                dial

                Spacer().frame(height: 18)
                waveform
                Spacer().frame(height: 18)

                Text(listeningLine)
                    .font(.dv(size: 12.5))
                    .foregroundColor(DS.Palette.navyText.opacity(0.75))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, 16)
                    .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: live.phrase)

                // "SARAH ✦ FILED TO YOUR SKY" — the moment the graph catches a
                // name. It is the only place in the product where you can watch
                // the Twin understand something as it happens.
                if let caughtName = live.caughtName, !caughtName.isEmpty {
                    Spacer().frame(height: 14)
                    Text("\(caughtName.uppercased()) \u{2726} FILED TO YOUR SKY")
                        .font(.dv(size: 10, weight: .heavy, design: .rounded))
                        .tracking(0.8)
                        .foregroundColor(DS.Palette.goldNight)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(
                            Capsule()
                                .fill(DS.Palette.gold.opacity(0.16))
                                .overlay(Capsule().stroke(DS.Palette.gold.opacity(0.4), lineWidth: 1))
                        )
                        .transition(.scale.combined(with: .opacity))
                }

                Spacer()

                controls
                    .padding(.bottom, 28)
            }
            .padding(.horizontal, 24)
        }
        // The dial owns the screen, so the status bar has to agree with it.
        .preferredColorScheme(.dark)
        .statusBarHidden(false)
    }

    // MARK: - Status line

    /// What the dial says under the waveform.
    ///
    /// The live phrase when there is one, and an honest placeholder when there
    /// is not — on a device without on-device streaming recognition this line
    /// never fills, and "Listening…" is true either way.
    private var listeningLine: String {
        if paused { return "Paused. Tap resume and keep going." }
        if live.phrase.isEmpty { return "Listening\u{2026}" }
        return "\u{201C}\(live.phrase)\u{201D}"
    }

    private var statusText: String {
        paused
            ? "\u{2759}\u{2759} PAUSED \u{00B7} ON-DEVICE \u{00B7} 0 B OUT"
            : "\u{25CF} RECORDING \u{00B7} ON-DEVICE \u{00B7} 0 B OUT"
    }

    // Spelled out, because this app has its own `TimelineView` — the Journal
    // screen — and the unqualified name resolves to that one.
    @ViewBuilder
    private var statusLine: some View {
        // Blink means LIVE. A paused dial that kept pulsing would say the
        // microphone was still open, which is the one thing it must not say.
        if paused || reduceMotion {
            statusLabel(opacity: 0.55)
        } else {
            SwiftUI.TimelineView(.periodic(from: .now, by: 0.05)) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                statusLabel(opacity: 0.35 + 0.65 * abs(sin(t * .pi / 1.6)))
            }
        }
    }

    private func statusLabel(opacity: Double) -> some View {
        Text(statusText)
            .font(.dv(size: 10, weight: .semibold, design: .monospaced))
            .tracking(1.6)
            .foregroundColor(DS.Palette.gold.opacity(opacity))
            .frame(height: 14)
    }

    // MARK: - The dial

    private var dial: some View {
        ZStack {
            // §8.8: under reduced motion the dial still SHOWS everything — the
            // ticks, the arc, the elapsed time — it just stops orbiting and
            // breathing. The information was never in the movement.
            Group {
                if reduceMotion {
                    Canvas { ctx, size in draw(ctx, size, 0) }
                } else {
                    SwiftUI.TimelineView(.animation) { context in
                        Canvas { ctx, size in
                            draw(ctx, size, context.date.timeIntervalSinceReferenceDate)
                        }
                    }
                }
            }
            .frame(width: 288, height: 288)

            VStack(spacing: 7) {
                Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
                    .font(.dv(size: 46, weight: .heavy, design: .rounded))
                    .foregroundColor(DS.Palette.navyText)
                    .monospacedDigit()
                Text(ticksLine)
                    .font(.dv(size: 10, weight: .semibold, design: .monospaced))
                    .tracking(1.4)
                    .foregroundColor(DS.Palette.navyText.opacity(0.55))
            }
        }
    }

    /// "OF 0:42 · 1 TICK LIT" — singular when it is one. A counter that reads
    /// "1 TICKS" on the very first second of every recording is the first thing
    /// the screen says to you.
    private var ticksLine: String {
        let lit = min(elapsed, Self.ritual)
        return "OF 0:42 \u{00B7} \(lit) TICK\(lit == 1 ? "" : "S") LIT"
    }

    private func draw(_ ctx: GraphicsContext, _ size: CGSize, _ t: TimeInterval) {
        let c = CGPoint(x: size.width / 2, y: size.height / 2)
        let r = min(size.width, size.height) * 0.452      // 104/230, off the design

        // Breathing glow, 2.4s.
        let glow = 0.5 + 0.5 * sin(t * Double.pi / 1.2)
        let gRadius = r * 0.92 * CGFloat(1 + 0.18 * glow)
        ctx.fill(
            Path(ellipseIn: CGRect(x: c.x - gRadius, y: c.y - gRadius,
                                   width: gRadius * 2, height: gRadius * 2)),
            with: .radialGradient(
                Gradient(colors: [DS.Palette.gold.opacity(0.55 - 0.40 * glow), .clear]),
                center: c, startRadius: 0, endRadius: gRadius)
        )

        // 42 ticks, gold for each second earned.
        let lit = min(elapsed, Self.ritual)
        for i in 0..<Self.ritual {
            let a = Double(i) * (2 * .pi / Double(Self.ritual)) - .pi / 2
            let p = CGPoint(x: c.x + CGFloat(Double(r) * cos(a)),
                            y: c.y + CGFloat(Double(r) * sin(a)))
            let dotR: CGFloat = i < lit ? 3 : 2.5
            ctx.fill(
                Path(ellipseIn: CGRect(x: p.x - dotR, y: p.y - dotR,
                                       width: dotR * 2, height: dotR * 2)),
                with: .color(i < lit ? DS.Palette.gold : DS.Palette.navyText.opacity(0.16))
            )
        }

        // The elapsed arc. Past 42 it keeps sweeping rather than stopping —
        // 42 is a shape, not a cutoff, and a bar that froze there would read as
        // "stop talking", which inverts the whole motif.
        if elapsed > 0 {
            var arc = Path()
            arc.addArc(center: c, radius: r,
                       startAngle: .degrees(-90),
                       endAngle: .degrees(-90 + 360 * Double(elapsed % Self.ritual) / Double(Self.ritual)),
                       clockwise: false)
            ctx.stroke(arc, with: .color(DS.Palette.gold),
                       style: StrokeStyle(lineWidth: 5.5, lineCap: .round))
        }

        // Two orbiting bodies — 12s forward, 22s reverse. The solar system
        // speeds up while you speak.
        let aA = t * 2 * .pi / 12 - .pi / 2
        let orbitR = Double(r) + 8
        let pA = CGPoint(x: c.x + CGFloat(orbitR * cos(aA)),
                         y: c.y + CGFloat(orbitR * sin(aA)))
        ctx.fill(Path(ellipseIn: CGRect(x: pA.x - 9, y: pA.y - 9, width: 18, height: 18)),
                 with: .color(DS.Palette.gold.opacity(0.4)))
        ctx.fill(Path(ellipseIn: CGRect(x: pA.x - 5, y: pA.y - 5, width: 10, height: 10)),
                 with: .color(DS.Palette.gold))

        let aB = -t * 2 * .pi / 22 - .pi / 2
        let rB = Double(r) - 22
        let pB = CGPoint(x: c.x + CGFloat(rB * cos(aB)),
                         y: c.y + CGFloat(rB * sin(aB)))
        ctx.fill(Path(ellipseIn: CGRect(x: pB.x - 3, y: pB.y - 3, width: 6, height: 6)),
                 with: .color(DS.Palette.navyText.opacity(0.8)))
    }

    // MARK: - Waveform

    private var waveform: some View {
        HStack(spacing: 4) {
            ForEach(0..<14, id: \.self) { i in
                Capsule()
                    .fill(DS.Palette.gold.opacity(paused ? 0.25 : 0.85))
                    .frame(width: 4, height: barHeight(i))
            }
        }
        .frame(height: 34)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.12), value: level)
    }

    private func barHeight(_ i: Int) -> CGFloat {
        guard !paused else { return 4 }
        // Staggered so the row reads as a waveform rather than a level meter
        // moving as one block.
        let stagger = 0.55 + 0.45 * sin(Double(i) * 0.9)
        return max(4, min(34, 4 + level * 30 * CGFloat(stagger)))
    }

    // MARK: - Controls

    private var controls: some View {
        HStack(alignment: .top, spacing: 20) {
            dialAction(label: "Discard", action: onDiscard) {
                Text("\u{2715}")
                    .font(.dv(size: 15))
                    .foregroundColor(DS.Palette.navyText.opacity(0.7))
            }

            // Stop is 76pt and red — the only red in the product, and it means
            // RECORDING rather than failure.
            VStack(spacing: 6) {
                Button(action: onStop) {
                    ZStack {
                        Circle()
                            .fill(DS.Palette.coral)
                            .frame(width: 76, height: 76)
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color.white)
                            .frame(width: 24, height: 24)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Stop and keep this entry")
                Text("Stop & keep \u{2726}")
                    .font(.dv(size: 10, weight: .heavy, design: .rounded))
                    .foregroundColor(DS.Palette.navyText)
            }

            dialAction(label: paused ? "Resume" : "Pause",
                       action: paused ? onResume : onPause) {
                if paused {
                    // Drawn, not typed: ▶ in a text run sits off-centre in its
                    // own box and no amount of padding fixes it.
                    Triangle()
                        .fill(DS.Palette.navyText.opacity(0.8))
                        .frame(width: 13, height: 15)
                } else {
                    HStack(spacing: 4) {
                        ForEach(0..<2, id: \.self) { _ in
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(DS.Palette.navyText.opacity(0.8))
                                .frame(width: 4, height: 15)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dialAction<Glyph: View>(label: String,
                                         action: @escaping () -> Void,
                                         @ViewBuilder glyph: () -> Glyph) -> some View {
        VStack(spacing: 6) {
            Spacer().frame(height: 14)   // aligns the three captions on one baseline
            Button(action: action) {
                ZStack {
                    Circle()
                        .fill(DS.Palette.navyText.opacity(0.10))
                        .frame(width: 48, height: 48)
                    glyph()
                }
            }
            .buttonStyle(.plain)
            Text(label)
                .font(.dv(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(DS.Palette.navyText.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
    }
}

/// A right-pointing triangle, for Resume.
private struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        p.addLine(to: CGPoint(x: rect.minX + rect.width * 0.18, y: rect.maxY))
        p.closeSubpath()
        return p
    }
}
