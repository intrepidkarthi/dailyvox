//
//  BodyTwinCard.swift
//  solyn
//
//  The Body dimension on the Twin tab: how far your Twin has come in learning
//  what your body felt, and the doorway to the review queue. Deliberately
//  static — no timers, no repeat-forever animations — so the Twin tab can go
//  idle (the ScreenshotTests perf fix depends on it).
//

import SwiftUI
import DailyVoxTwinEngine

struct BodyTwinCard: View {
    @ObservedObject private var twin = DigitalTwinEngine.shared
    @ObservedObject private var healthKit = HealthKitService.shared
    @ObservedObject private var queue = PendingSnapshotQueue.shared
    @ObservedObject private var manager = BodyTwinManager.shared
    @State private var showReview = false
    @State private var isRequestingAccess = false

    var body: some View {
        // Absent entirely on devices without HealthKit, matching Settings.
        if healthKit.isAvailable {
            Button {
                if twin.bodyTwin.isActive {
                    showReview = true
                } else {
                    enableBodyTwin()
                }
            } label: {
                HStack(spacing: 16) {
                    meter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Body Twin")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.system(size: 13, weight: .regular, design: .rounded))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if twin.bodyTwin.isActive && queue.count > 0 {
                        DSTag(text: "\(queue.count) waiting", tint: DS.Palette.gold)
                    }
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary.opacity(0.5))
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground)))
            }
            .buttonStyle(.plain)
            .disabled(isRequestingAccess)
            .sheet(isPresented: $showReview) { BodyTwinReviewView() }
        }
    }

    private var subtitle: String {
        if isRequestingAccess {
            return "Asking Health for permission…"
        }
        guard twin.bodyTwin.isActive else {
            return "Your Twin can learn what your body felt. Tap to begin."
        }
        let kept = twin.bodyTwin.entriesWithSnapshot
        switch twin.bodyTwin.maturity {
        case .warmingUp:
            return kept == 0
                ? "Warming up — it learns only the moments you keep."
                : "Warming up — \(kept) \(kept == 1 ? "moment" : "moments") kept so far."
        case .learning:
            return "Learning your rhythms — \(kept) moments kept."
        case .ready:
            return "Ready — it knows your body's rhythms from \(kept) kept moments."
        }
    }

    private var meter: some View {
        ZStack {
            Circle()
                .stroke(DS.Palette.terracotta.opacity(0.15), lineWidth: 6)
                .frame(width: 58, height: 58)
            if twin.bodyTwin.isActive {
                // Quiet progress toward a stable baseline (30 kept moments).
                Circle()
                    .trim(from: 0, to: min(1, CGFloat(twin.bodyTwin.entriesWithSnapshot) / 30))
                    .stroke(LinearGradient(colors: [DS.Palette.terracotta, DS.Palette.gold],
                                           startPoint: .top, endPoint: .bottom),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 58, height: 58)
            }
            Image(systemName: "figure.mind.and.body")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(twin.bodyTwin.isActive ? DS.Palette.terracotta : DS.Palette.sage)
        }
    }

    /// Same enable flow as Settings → Health: the permission sheet completing
    /// is all read-only HealthKit lets us know, so completion counts as
    /// "asked" and the Twin turns on.
    private func enableBodyTwin() {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        Task { @MainActor in
            defer { isRequestingAccess = false }
            if !healthKit.isAuthorized {
                do {
                    try await healthKit.requestAuthorization()
                } catch {
                    return
                }
            }
            manager.recordAuthorizationRequested()
            manager.isEnabled = true
        }
    }
}
