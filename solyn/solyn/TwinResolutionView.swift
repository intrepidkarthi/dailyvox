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
    static let gold = Color(red: 0.831, green: 0.647, blue: 0.278)
    static let sage = Color(red: 0.357, green: 0.486, blue: 0.420)
    static let forest = Color(red: 0.420, green: 0.620, blue: 0.482)
    static let coral = Color(red: 0.769, green: 0.451, blue: 0.420)
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
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary.opacity(0.5))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(.secondarySystemBackground)))
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
        ZStack {
            Circle().stroke(TR.sage.opacity(0.15), lineWidth: 6).frame(width: 58, height: 58)
            if let r = manager.resolution {
                Circle().trim(from: 0, to: CGFloat(r))
                    .stroke(LinearGradient(colors: [TR.sage, TR.gold], startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
                Text("\(Int((r * 100).rounded()))%")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundColor(.primary)
            } else {
                Image(systemName: "questionmark")
                    .font(.system(size: 20, weight: .bold))
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
                .font(.system(size: 14, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20).padding(.top, 8)

            ForEach(manager.questions) { q in
                VStack(alignment: .leading, spacing: 10) {
                    Text(q.prompt)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundColor(.primary)
                    Slider(value: Binding(
                        get: { draft[q.id] ?? 0.5 },
                        set: { draft[q.id] = $0 }
                    ), in: 0...1)
                    .tint(TR.sage)
                    HStack {
                        Text(q.lowLabel); Spacer(); Text(q.highLabel)
                    }
                    .font(.system(size: 12, design: .rounded))
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
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
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
                        Text("match").font(.system(size: 13, design: .rounded)).foregroundColor(.secondary)
                    }
                }
                .padding(.top, 12)
                Text(verdict(r))
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 10) {
                ForEach(manager.answeredQuestions) { q in resultRow(q) }
            }
            .padding(.horizontal, 16)

            Text("Your Twin sharpens with every entry. Come back after journaling to watch this climb.")
                .font(.system(size: 13, design: .rounded))
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
                .font(.system(size: 20))
                .foregroundColor(agree >= 0.75 ? TR.forest : agree >= 0.5 ? TR.gold : TR.coral)
            VStack(alignment: .leading, spacing: 2) {
                Text(q.prompt).font(.system(size: 13, weight: .medium, design: .rounded))
                    .foregroundColor(.primary).lineLimit(1)
                Text("Twin guessed: \(twinGuess.lowercased())")
                    .font(.system(size: 12, design: .rounded)).foregroundColor(.secondary)
            }
            Spacer()
            Text("\(Int((agree * 100).rounded()))%")
                .font(.system(size: 14, weight: .bold, design: .rounded))
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
