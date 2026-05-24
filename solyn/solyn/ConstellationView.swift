//
//  ConstellationView.swift
//  solyn
//
//  A constellation visualization for the Digital Twin.
//  Each journal entry becomes a star. Over time, constellations form —
//  patterns in the night sky of your inner world.
//

import SwiftUI

// MARK: - Star Data Model

struct ConstellationStar: Identifiable {
    let id: Int
    let position: CGPoint      // Normalized 0-1
    let size: CGFloat           // 2-8 points
    let mood: Double            // -1 (stressed) to 1 (positive)
    let pulsePhase: Double      // 0-2π offset for async pulsing
    let brightness: Double      // 0.4-1.0
    let depth: Double           // 0-1 parallax layer
}

struct ConstellationConnection {
    let from: Int
    let to: Int
    let strength: Double  // 0-1 line opacity
}

// MARK: - Constellation View

struct ConstellationView: View {
    let starCount: Int
    let connections: [(Int, Int)]
    let starMoods: [Double]
    var showLabels: Bool = false
    var clusterLabels: [String] = []

    @State private var animationTime: Double = Date().timeIntervalSinceReferenceDate
    @State private var appeared = false
    private let timer = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    // Palette
    private let warmGold   = Color(red: 0.831, green: 0.647, blue: 0.278)  // #D4A547
    private let coolBlue   = Color(red: 0.482, green: 0.643, blue: 0.780)  // #7BA4C7
    private let softCoral  = Color(red: 0.769, green: 0.451, blue: 0.420)  // #C4736B
    private let sageGreen  = Color(red: 0.420, green: 0.620, blue: 0.482)  // #6B9E7B
    private let ivoryGlow  = Color(red: 0.957, green: 0.933, blue: 0.878)  // #F4EEE0

    private let bgDeep     = Color(red: 0.102, green: 0.102, blue: 0.180)  // #1A1A2E
    private let bgMid      = Color(red: 0.086, green: 0.129, blue: 0.243)  // #16213E
    private let bgWarm     = Color(red: 0.141, green: 0.118, blue: 0.180)  // #241E2E

    var body: some View {
        GeometryReader { geo in
            let size = geo.size
            let stars = generateStars(in: size)
            let conns = buildConnections(stars: stars)

            Canvas { context, canvasSize in
                let t = animationTime

                // Layer 1: Deep background
                drawBackground(context: context, size: canvasSize, time: t)

                // Layer 2: Nebula clouds
                drawNebulae(context: context, size: canvasSize, stars: stars, time: t)

                // Layer 3: Connection lines
                drawConnections(context: context, size: canvasSize, stars: stars, connections: conns, time: t)

                // Layer 4: Stars
                drawStars(context: context, size: canvasSize, stars: stars, time: t)

                // Layer 5: Core star (Digital Twin center)
                if starCount > 0 {
                    drawCoreStar(context: context, size: canvasSize, time: t)
                }
            }
            .onReceive(timer) { _ in
                animationTime = Date().timeIntervalSinceReferenceDate
            }
            .overlay {
                // Label overlays (SwiftUI text on top of Canvas)
                if starCount == 0 {
                    emptyState
                } else if showLabels && !clusterLabels.isEmpty {
                    clusterLabelOverlay(size: size, stars: stars)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .aspectRatio(1.0, contentMode: .fit)
        .onAppear {
            withAnimation(.easeOut(duration: 2.0)) {
                appeared = true
            }
        }
    }

    // MARK: - Star Generation (deterministic from count)

    private func generateStars(in size: CGSize) -> [ConstellationStar] {
        guard starCount > 0 else { return [] }

        var stars: [ConstellationStar] = []
        let seed: UInt64 = 42  // The answer, naturally

        for i in 0..<starCount {
            // Pseudo-random but deterministic positioning
            let hash = pseudoRandom(seed: seed &+ UInt64(i))
            let hash2 = pseudoRandom(seed: seed &+ UInt64(i) &+ 1000)
            let hash3 = pseudoRandom(seed: seed &+ UInt64(i) &+ 2000)

            // Cluster stars toward center with gaussian-like distribution
            let angle = hash * .pi * 2
            let radius = 0.15 + pow(hash2, 0.7) * 0.32  // Clustered center, sparse edges
            let x = 0.5 + cos(angle) * radius
            let y = 0.5 + sin(angle) * radius

            let mood = i < starMoods.count ? starMoods[i] : 0.0
            let maturityScale = min(1.0, Double(starCount) / 30.0)  // Denser with more entries

            let star = ConstellationStar(
                id: i,
                position: CGPoint(x: clamp(x, 0.08, 0.92), y: clamp(y, 0.08, 0.92)),
                size: CGFloat(2.5 + hash3 * 4.5 * maturityScale),
                mood: mood,
                pulsePhase: hash * .pi * 2,
                brightness: 0.5 + hash2 * 0.5,
                depth: hash3
            )
            stars.append(star)
        }
        return stars
    }

    // MARK: - Connection Building

    private func buildConnections(stars: [ConstellationStar]) -> [ConstellationConnection] {
        var conns: [ConstellationConnection] = []
        for (from, to) in connections {
            if from < stars.count && to < stars.count {
                let dx = stars[from].position.x - stars[to].position.x
                let dy = stars[from].position.y - stars[to].position.y
                let dist = sqrt(dx * dx + dy * dy)
                let strength = max(0.1, 1.0 - dist * 2.5)
                conns.append(ConstellationConnection(from: from, to: to, strength: strength))
            }
        }
        return conns
    }

    // MARK: - Drawing: Background

    private func drawBackground(context: GraphicsContext, size: CGSize, time: Double) {
        // Warm dark gradient — not cold black
        let bgRect = CGRect(origin: .zero, size: size)

        context.fill(
            Path(bgRect),
            with: .linearGradient(
                Gradient(colors: [bgDeep, bgMid]),
                startPoint: CGPoint(x: 0, y: 0),
                endPoint: CGPoint(x: size.width, y: size.height)
            )
        )

        // Subtle warm wash at bottom
        let warmWash = Path(ellipseIn: CGRect(
            x: size.width * 0.1,
            y: size.height * 0.5,
            width: size.width * 0.8,
            height: size.height * 0.6
        ))
        context.fill(warmWash, with: .color(bgWarm.opacity(0.3)))

        // Dust particles (very subtle small dots)
        for i in 0..<40 {
            let h = pseudoRandom(seed: UInt64(i) &+ 5000)
            let h2 = pseudoRandom(seed: UInt64(i) &+ 6000)
            let x = h * size.width
            let y = h2 * size.height
            let twinkle = sin(time * 0.5 + h * 10) * 0.3 + 0.3
            let dustPath = Path(ellipseIn: CGRect(x: x - 0.5, y: y - 0.5, width: 1, height: 1))
            context.fill(dustPath, with: .color(ivoryGlow.opacity(twinkle * 0.15)))
        }
    }

    // MARK: - Drawing: Nebulae

    private func drawNebulae(context: GraphicsContext, size: CGSize, stars: [ConstellationStar], time: Double) {
        guard stars.count >= 3 else { return }

        // Create 2-3 nebula clouds around star clusters
        let nebulaCount = min(3, stars.count / 5 + 1)

        for i in 0..<nebulaCount {
            let clusterCenter = stars[i * (stars.count / max(1, nebulaCount))]
            let cx = clusterCenter.position.x * size.width
            let cy = clusterCenter.position.y * size.height
            let breathe = sin(time * 0.15 + Double(i) * 2.0) * 0.08 + 1.0

            let nebulaSize = size.width * 0.35 * breathe
            let nebulaColor = moodColor(clusterCenter.mood)

            let nebula = Path(ellipseIn: CGRect(
                x: cx - nebulaSize / 2,
                y: cy - nebulaSize / 2,
                width: nebulaSize,
                height: nebulaSize * 0.85
            ))

            // Very subtle, diffuse glow
            context.fill(nebula, with: .color(nebulaColor.opacity(0.04)))

            // Inner brighter core
            let innerSize = nebulaSize * 0.4
            let inner = Path(ellipseIn: CGRect(
                x: cx - innerSize / 2,
                y: cy - innerSize / 2,
                width: innerSize,
                height: innerSize * 0.9
            ))
            context.fill(inner, with: .color(nebulaColor.opacity(0.06)))
        }
    }

    // MARK: - Drawing: Connections

    private func drawConnections(context: GraphicsContext, size: CGSize, stars: [ConstellationStar], connections: [ConstellationConnection], time: Double) {
        for conn in connections {
            let from = stars[conn.from]
            let to = stars[conn.to]

            let p1 = CGPoint(x: from.position.x * size.width, y: from.position.y * size.height)
            let p2 = CGPoint(x: to.position.x * size.width, y: to.position.y * size.height)

            var path = Path()
            path.move(to: p1)
            path.addLine(to: p2)

            // Animated dash pattern
            let dashPhase = time * 8.0
            let dashStyle = StrokeStyle(
                lineWidth: 0.6,
                lineCap: .round,
                dash: [3, 6],
                dashPhase: dashPhase
            )

            let fadeIn = appeared ? conn.strength : 0
            let lineColor = ivoryGlow.opacity(fadeIn * 0.2)

            context.stroke(path, with: .color(lineColor), style: dashStyle)
        }
    }

    // MARK: - Drawing: Stars

    private func drawStars(context: GraphicsContext, size: CGSize, stars: [ConstellationStar], time: Double) {
        for star in stars {
            let cx = star.position.x * size.width
            let cy = star.position.y * size.height

            // Gentle async pulsing
            let pulse = sin(time * 0.8 + star.pulsePhase) * 0.25 + 0.75
            let currentSize = star.size * pulse

            let color = moodColor(star.mood)
            let fadeIn = appeared ? star.brightness : 0

            // Outer glow (larger, very faint)
            let glowSize = currentSize * 4
            let glow = Path(ellipseIn: CGRect(
                x: cx - glowSize / 2,
                y: cy - glowSize / 2,
                width: glowSize,
                height: glowSize
            ))
            context.fill(glow, with: .color(color.opacity(fadeIn * 0.08)))

            // Mid glow
            let midSize = currentSize * 2.2
            let mid = Path(ellipseIn: CGRect(
                x: cx - midSize / 2,
                y: cy - midSize / 2,
                width: midSize,
                height: midSize
            ))
            context.fill(mid, with: .color(color.opacity(fadeIn * 0.15)))

            // Core (bright center)
            let core = Path(ellipseIn: CGRect(
                x: cx - currentSize / 2,
                y: cy - currentSize / 2,
                width: currentSize,
                height: currentSize
            ))
            context.fill(core, with: .color(color.opacity(fadeIn * 0.9)))

            // Hot center (white point)
            let hotSize = currentSize * 0.4
            let hot = Path(ellipseIn: CGRect(
                x: cx - hotSize / 2,
                y: cy - hotSize / 2,
                width: hotSize,
                height: hotSize
            ))
            context.fill(hot, with: .color(ivoryGlow.opacity(fadeIn * 0.7)))
        }
    }

    // MARK: - Drawing: Core Star (Digital Twin)

    private func drawCoreStar(context: GraphicsContext, size: CGSize, time: Double) {
        let cx = size.width * 0.5
        let cy = size.height * 0.48

        let breathe = sin(time * 0.4) * 0.12 + 1.0
        let coreColor = sageGreen

        // Outer aura — very large, very faint
        let auraSize: CGFloat = 60 * breathe
        let aura = Path(ellipseIn: CGRect(
            x: cx - auraSize, y: cy - auraSize,
            width: auraSize * 2, height: auraSize * 2
        ))
        context.fill(aura, with: .color(coreColor.opacity(0.04)))

        // Mid halo
        let haloSize: CGFloat = 30 * breathe
        let halo = Path(ellipseIn: CGRect(
            x: cx - haloSize, y: cy - haloSize,
            width: haloSize * 2, height: haloSize * 2
        ))
        context.fill(halo, with: .color(coreColor.opacity(0.08)))

        // Inner halo
        let innerSize: CGFloat = 16 * breathe
        let inner = Path(ellipseIn: CGRect(
            x: cx - innerSize, y: cy - innerSize,
            width: innerSize * 2, height: innerSize * 2
        ))
        context.fill(inner, with: .color(coreColor.opacity(0.15)))

        // Core
        let coreSize: CGFloat = 7
        let core = Path(ellipseIn: CGRect(
            x: cx - coreSize, y: cy - coreSize,
            width: coreSize * 2, height: coreSize * 2
        ))
        context.fill(core, with: .color(coreColor.opacity(0.9)))

        // White-hot center
        let hotSize: CGFloat = 3
        let hot = Path(ellipseIn: CGRect(
            x: cx - hotSize, y: cy - hotSize,
            width: hotSize * 2, height: hotSize * 2
        ))
        context.fill(hot, with: .color(ivoryGlow.opacity(0.85)))

        // Cross-flare effect (subtle)
        let flareLen: CGFloat = 18 * breathe
        var hFlare = Path()
        hFlare.move(to: CGPoint(x: cx - flareLen, y: cy))
        hFlare.addLine(to: CGPoint(x: cx + flareLen, y: cy))
        context.stroke(hFlare, with: .color(ivoryGlow.opacity(0.12)), style: StrokeStyle(lineWidth: 0.8))

        var vFlare = Path()
        vFlare.move(to: CGPoint(x: cx, y: cy - flareLen * 0.7))
        vFlare.addLine(to: CGPoint(x: cx, y: cy + flareLen * 0.7))
        context.stroke(vFlare, with: .color(ivoryGlow.opacity(0.08)), style: StrokeStyle(lineWidth: 0.6))
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 20) {
            Spacer()

            // Single dim star effect
            ZStack {
                Circle()
                    .fill(sageGreen.opacity(0.06))
                    .frame(width: 120, height: 120)

                Circle()
                    .fill(sageGreen.opacity(0.12))
                    .frame(width: 60, height: 60)

                Circle()
                    .fill(sageGreen.opacity(0.5))
                    .frame(width: 12, height: 12)

                Circle()
                    .fill(ivoryGlow.opacity(0.7))
                    .frame(width: 5, height: 5)
            }

            VStack(spacing: 8) {
                Text("Your first star")
                    .font(.system(size: 20, weight: .semibold, design: .rounded))
                    .foregroundColor(ivoryGlow.opacity(0.8))

                Text("Every journal entry adds a star to your constellation.\nSpeak for 42 seconds to begin.")
                    .font(.system(size: 14, weight: .regular, design: .rounded))
                    .foregroundColor(ivoryGlow.opacity(0.4))
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }

            Spacer()
            Spacer()
        }
        .padding(32)
    }

    // MARK: - Cluster Labels

    private func clusterLabelOverlay(size: CGSize, stars: [ConstellationStar]) -> some View {
        ZStack {
            ForEach(Array(clusterLabels.enumerated()), id: \.offset) { index, label in
                let starIndex = index * (stars.count / max(1, clusterLabels.count))
                if starIndex < stars.count {
                    let star = stars[starIndex]
                    Text(label.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .tracking(2)
                        .foregroundColor(ivoryGlow.opacity(0.3))
                        .position(
                            x: star.position.x * size.width,
                            y: star.position.y * size.height + 16
                        )
                }
            }
        }
    }

    // MARK: - Helpers

    private func moodColor(_ mood: Double) -> Color {
        if mood > 0.3  { return warmGold }
        if mood > 0.0  { return sageGreen }
        if mood > -0.3 { return coolBlue }
        return softCoral
    }

    private func pseudoRandom(seed: UInt64) -> Double {
        // Simple hash-based PRNG for deterministic positioning
        var s = seed
        s = s &* 6364136223846793005 &+ 1442695040888963407
        s = (s >> 33) ^ s
        s = s &* 0xff51afd7ed558ccd
        s = (s >> 33) ^ s
        return Double(s % 10000) / 10000.0
    }

    private func clamp(_ value: Double, _ lo: Double, _ hi: Double) -> Double {
        max(lo, min(hi, value))
    }
}

// MARK: - Convenience Initializer from Twin Data

extension ConstellationView {
    /// Create a constellation from Digital Twin data
    static func fromTwin(
        entryCount: Int,
        moods: [Double],
        knowledgeNodes: [(String, Int)],  // (label, mentions)
        connections: [(Int, Int)] = []
    ) -> ConstellationView {
        // Auto-generate connections between nearby entries if none provided
        var conns = connections
        if conns.isEmpty && entryCount > 1 {
            // Connect sequential entries
            for i in 0..<(entryCount - 1) {
                if i < entryCount - 1 {
                    conns.append((i, i + 1))
                }
            }
            // Add some cross-connections for visual interest
            for i in stride(from: 0, to: entryCount - 2, by: 3) {
                if i + 2 < entryCount {
                    conns.append((i, i + 2))
                }
            }
        }

        let labels = knowledgeNodes.prefix(4).map(\.0)

        return ConstellationView(
            starCount: entryCount,
            connections: conns,
            starMoods: moods,
            showLabels: !labels.isEmpty,
            clusterLabels: Array(labels)
        )
    }
}

// MARK: - Preview

#Preview("Mature Constellation") {
    ConstellationView(
        starCount: 25,
        connections: [
            (0,1), (1,2), (2,3), (3,4), (4,5),
            (5,6), (6,7), (7,8), (0,8), (2,5),
            (1,6), (3,7), (9,10), (10,11), (11,12),
            (12,13), (13,14), (14,15), (9,15),
            (16,17), (17,18), (18,19), (19,20),
            (20,21), (21,22), (22,23), (23,24), (16,24)
        ],
        starMoods: [
            0.8, 0.5, 0.2, -0.1, 0.6, 0.9, 0.3, -0.4, 0.1, 0.7,
            -0.2, 0.4, 0.6, -0.3, 0.8, 0.2, 0.5, -0.1, 0.7, 0.3,
            0.9, -0.2, 0.4, 0.6, 0.1
        ],
        showLabels: true,
        clusterLabels: ["Work", "Family", "Health", "Growth"]
    )
    .frame(width: 360, height: 360)
    .padding()
    .background(Color.black)
}

#Preview("New User") {
    ConstellationView(
        starCount: 0,
        connections: [],
        starMoods: []
    )
    .frame(width: 360, height: 360)
    .padding()
    .background(Color.black)
}

#Preview("Early Journal (5 entries)") {
    ConstellationView(
        starCount: 5,
        connections: [(0,1), (1,2), (2,3), (3,4)],
        starMoods: [0.5, 0.2, -0.3, 0.8, 0.1]
    )
    .frame(width: 360, height: 360)
    .padding()
    .background(Color.black)
}
