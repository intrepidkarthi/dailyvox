//
//  TwinResolution.swift
//  solyn
//
//  "Twin Resolution" — a felt measure of how well your Digital Twin actually
//  knows you. We ask a few self-report questions that map to traits the Twin
//  already computes from your entries, then compare the Twin's estimate to your
//  own answer. The closer they match, the higher the resolution.
//
//  This is the self-prediction fidelity harness (Park et al. style) made
//  user-facing: no engine changes, no new permissions — it reads the Twin's
//  existing trait scores and scores agreement on-device.
//

import SwiftUI
import DailyVoxTwinEngine

// MARK: - Question

/// A self-report question whose answer is compared against the Twin's own
/// computed value for the same trait. `twinValue` returns the Twin's current
/// 0...1 estimate; the user answers on the same 0...1 scale.
struct SelfPredictionQuestion: Identifiable {
    let id: String
    let prompt: String
    let lowLabel: String        // anchors the 0 end
    let highLabel: String       // anchors the 1 end
    let twinValue: () -> Double  // the Twin's current estimate for this trait
}

// MARK: - Manager

@MainActor
final class TwinResolutionManager: ObservableObject {
    static let shared = TwinResolutionManager()

    private let answersKey = "twinResolution_answers"
    private let historyKey = "twinResolution_history"   // [ISO-date: resolution] snapshots over time

    /// questionId -> the user's self-report on a 0...1 scale.
    @Published private(set) var answers: [String: Double]

    private init() {
        answers = (UserDefaults.standard.dictionary(forKey: answersKey) as? [String: Double]) ?? [:]
    }

    /// The fixed question bank, each mapped to a trait the Twin exposes.
    /// (Same accessors TwinProfileGenerator already reads, so these are known-good.)
    var questions: [SelfPredictionQuestion] {
        let t = DigitalTwinEngine.shared
        return [
            SelfPredictionQuestion(
                id: "expressiveness",
                prompt: "How do you tend to express yourself?",
                lowLabel: "Reserved", highLabel: "Expressive",
                twinValue: { t.communicationStyle.expressiveness }),
            SelfPredictionQuestion(
                id: "directness",
                prompt: "When you say what you mean, you're usually…",
                lowLabel: "Nuanced", highLabel: "Direct",
                twinValue: { t.communicationStyle.directness }),
            SelfPredictionQuestion(
                id: "analytical",
                prompt: "You make sense of things more through…",
                lowLabel: "Intuition", highLabel: "Analysis",
                twinValue: { t.thoughtPatterns.analyticalScore }),
            SelfPredictionQuestion(
                id: "abstract",
                prompt: "Your thinking leans…",
                lowLabel: "Concrete", highLabel: "Abstract",
                twinValue: { t.thoughtPatterns.abstractScore }),
            SelfPredictionQuestion(
                id: "future",
                prompt: "Your mind spends more time on…",
                lowLabel: "The past", highLabel: "The future",
                twinValue: { t.thoughtPatterns.futureOriented }),
            SelfPredictionQuestion(
                id: "growth",
                prompt: "When something goes wrong, you tend to feel you can…",
                lowLabel: "Accept it", highLabel: "Grow from it",
                twinValue: { t.thoughtPatterns.growthMindsetScore }),
            SelfPredictionQuestion(
                id: "emotionalRange",
                prompt: "Across a week, your emotions are…",
                lowLabel: "Steady", highLabel: "Wide-ranging",
                twinValue: { t.emotionalSignature.emotionalRange }),
        ]
    }

    var answeredQuestions: [SelfPredictionQuestion] { questions.filter { answers[$0.id] != nil } }
    var unansweredQuestions: [SelfPredictionQuestion] { questions.filter { answers[$0.id] == nil } }
    var answeredCount: Int { answeredQuestions.count }
    var totalCount: Int { questions.count }
    var hasAnswered: Bool { !answers.isEmpty }

    /// 0...1 — how closely the Twin's estimates match your self-report.
    /// `nil` until you've answered at least one question.
    var resolution: Double? {
        let answered = answeredQuestions
        guard !answered.isEmpty else { return nil }
        let totalError = answered.reduce(0.0) { acc, q in
            acc + abs(q.twinValue() - (answers[q.id] ?? 0.5))
        }
        return max(0, 1 - totalError / Double(answered.count))
    }

    /// Per-question agreement, for showing where the Twin nails you vs. misses.
    func agreement(for q: SelfPredictionQuestion) -> Double? {
        guard let a = answers[q.id] else { return nil }
        return max(0, 1 - abs(q.twinValue() - a))
    }

    // MARK: Recording

    func record(_ questionId: String, value: Double) {
        answers[questionId] = min(1, max(0, value))
        UserDefaults.standard.set(answers, forKey: answersKey)
        snapshotResolution()
    }

    func reset() {
        answers = [:]
        UserDefaults.standard.removeObject(forKey: answersKey)
    }

    /// Record a dated snapshot of the current resolution, so we can show it
    /// climbing as the Twin learns (the test-retest curve the dossier describes).
    private func snapshotResolution() {
        guard let r = resolution else { return }
        var history = (UserDefaults.standard.dictionary(forKey: historyKey) as? [String: Double]) ?? [:]
        let day = ISO8601DateFormatter.dayFormatter.string(from: Date())
        history[day] = r
        UserDefaults.standard.set(history, forKey: historyKey)
    }

    var history: [(date: Date, resolution: Double)] {
        let dict = (UserDefaults.standard.dictionary(forKey: historyKey) as? [String: Double]) ?? [:]
        return dict.compactMap { key, value in
            ISO8601DateFormatter.dayFormatter.date(from: key).map { ($0, value) }
        }.sorted { $0.date < $1.date }
    }
}

private extension ISO8601DateFormatter {
    static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
