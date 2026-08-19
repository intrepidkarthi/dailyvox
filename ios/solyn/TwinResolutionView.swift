//
//  TwinResolutionView.swift
//  solyn
//
//  UI for Twin Resolution: a card in the Digital Twin tab that shows how well
//  your Twin knows you, and a questionnaire that reveals — question by question —
//  what the Twin guessed about you and whether it was right.
//

import SwiftUI

private enum TR {
    static let gold = DS.Palette.gold
    static let sage = DS.Palette.sage
    static let forest = DS.Palette.forest
    static let coral = DS.Palette.coral
}

// MARK: - Card (embedded in the Twin tab)

struct TwinResolutionCard: View {
    @ObservedObject private var manager = TwinResolutionManager.shared
    @State private var showSheet = false

    var body: some View {
        Button { showSheet = true } label: {
            HStack(spacing: 16) {
                meter
                VStack(alignment: .leading, spacing: 4) {
                    Text("Twin Resolution")
                        .font(.system(.callout, design: .rounded).weight(.bold))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(.footnote, design: .rounded).weight(.regular))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(.footnote).weight(.semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            // Grouped-secondary matches every neighboring Twin-tab card
            // (plain-secondary rendered cool gray on the warm ivory canvas
            // in light, and a darker off-shade in Dark).
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color(.secondarySystemGroupedBackground)))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showSheet) { TwinResolutionSheet() }
    }

    private var subtitle: String {
        if let r = manager.resolution {
            return "Your Twin matches your self-report \(pct(r)). Tap to refine."
        }
        return "How well does your Twin know you? Answer \(manager.totalCount) quick questions to find out."
    }

    private var meter: some View {
        meterBody
            // The ring is pure geometry: VoiceOver announced nothing at all here. Collapse it to
            // one element that speaks the score, since that number is the whole point of the card.
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Twin Resolution")
            .accessibilityValue(manager.resolution.map { "\(pct($0)) match with your self-report" }
                                ?? "Not measured yet. \(manager.totalCount) questions to answer.")
    }

    private var meterBody: some View {
        ZStack {
            Circle().stroke(TR.sage.opacity(0.15), lineWidth: 6).frame(width: 58, height: 58)
            if let r = manager.resolution {
                Circle().trim(from: 0, to: CGFloat(r))
                    .stroke(LinearGradient(colors: [TR.sage, TR.gold], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                Text("\(Int((r * 100).rounded()))%")
                    .font(.system(.subheadline, design: .rounded).weight(.bold))
                    .foregroundColor(.primary)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(.title3).weight(.bold))
                    .foregroundColor(TR.sage)
            }
        }
    }
}

// MARK: - Sheet (questionnaire + reveal)

struct TwinResolutionSheet: View {
    @ObservedObject private var manager = TwinResolutionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var draft: [String: Double] = [:]
    @State private var revealed = false

    var body: some View {
        NavigationStack {
            ScrollView {
                if revealed {
                    resultsView
                } else {
                    questionsView
                }
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle(revealed ? "How your Twin did" : "Twin Resolution")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .onAppear {
            for q in manager.questions where draft[q.id] == nil {
                draft[q.id] = manager.answers[q.id] ?? 0.5
            }
        }
    }

    // MARK: Questions

    private var questionsView: some View {
        VStack(spacing: 18) {
            Text("Answer honestly about yourself. Then see what your Twin — built only from your entries — guessed about you.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.top, 8)

            ForEach(manager.questions) { q in
                VStack(alignment: .leading, spacing: 10) {
                    Text(q.prompt)
                        .font(.system(.subheadline, design: .rounded).weight(.semibold))
                        .foregroundColor(.primary)
                    Slider(value: Binding(
                        get: { draft[q.id] ?? 0.5 },
                        set: { draft[q.id] = $0 }
                    ), in: 0...1)
                    .tint(TR.sage)
                    HStack {
                        Text(q.lowLabel); Spacer(); Text(q.highLabel)
                    }
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground)))
                .padding(.horizontal, 16)
            }

            Button {
                for q in manager.questions { manager.record(q.id, value: draft[q.id] ?? 0.5) }
                withAnimation(.spring(response: 0.5)) { revealed = true }
            } label: {
                Text("Reveal how well your Twin knows you")
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(LinearGradient(colors: [TR.sage, TR.sage.opacity(0.85)],
                                               startPoint: .leading, endPoint: .trailing))
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 16).padding(.vertical, 8)
        }
        .padding(.bottom, 24)
    }

    // MARK: Results

    private var resultsView: some View {
        VStack(spacing: 20) {
            if let r = manager.resolution {
                ZStack {
                    Circle().stroke(TR.sage.opacity(0.15), lineWidth: 12).frame(width: 150, height: 150)
                    Circle().trim(from: 0, to: CGFloat(r))
                        .stroke(LinearGradient(colors: [TR.sage, TR.gold], startPoint: .top, endPoint: .bottom),
                                style: StrokeStyle(lineWidth: 12, lineCap: .round))
                        .rotationEffect(.degrees(-90)).frame(width: 150, height: 150)
                    VStack(spacing: 2) {
                        Text("\(Int((r * 100).rounded()))%")
                            .font(.system(size: 40, weight: .bold, design: .rounded))
                        Text("match").font(.system(.footnote, design: .rounded)).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)
                Text(verdict(r))
                    .font(.system(.callout, design: .rounded).weight(.semibold))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                ForEach(manager.answeredQuestions) { q in resultRow(q) }
            }
            .padding(.horizontal, 16)

            Text("Your Twin sharpens with every entry. Come back after journaling to watch this climb.")
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 24).padding(.top, 4)
        }
        .padding(.bottom, 28)
    }

    private func resultRow(_ q: SelfPredictionQuestion) -> some View {
        let userVal = manager.answers[q.id] ?? 0.5
        let twinVal = q.twinValue()
        let agree = manager.agreement(for: q) ?? 0
        let twinGuess = twinVal >= 0.5 ? q.highLabel : q.lowLabel
        return HStack(spacing: 12) {
            Image(systemName: agree >= 0.75 ? "checkmark.circle.fill" : agree >= 0.5 ? "circle.lefthalf.filled" : "xmark.circle")
                .font(.system(.title3))
                .foregroundColor(agree >= 0.75 ? TR.forest : agree >= 0.5 ? TR.gold : TR.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text(q.prompt).font(.system(.footnote, design: .rounded).weight(.medium))
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text("Twin guessed: \(twinGuess.lowercased())")
                    .font(.system(.caption, design: .rounded)).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(Int((agree * 100).rounded()))%")
                .font(.system(.subheadline, design: .rounded).weight(.bold))
                .foregroundColor(agree >= 0.75 ? TR.forest : .secondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func verdict(_ r: Double) -> String {
        switch r {
        case 0.85...: return "Your Twin already reads you like a book."
        case 0.7..<0.85: return "Your Twin knows you well — and it's still early."
        case 0.5..<0.7: return "Your Twin is getting to know you. Keep journaling."
        default: return "Early days. The more you speak, the sharper your Twin gets."
        }
    }
}

private func pct(_ v: Double) -> String { "\(Int((v * 100).rounded()))%" }
