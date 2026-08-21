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

    /// The review queue stays reachable whenever anything is waiting — even
    /// with the master toggle off. Keep is still an explicit act and Let go
    /// must always be available; queued health data with no way to view or
    /// discard it would break the review-before-learning promise.
    private var opensReview: Bool {
        twin.bodyTwin.isActive || queue.count > 0
    }

    /// Authorized but switched off in Settings, nothing waiting: a quiet
    /// signpost, not a button. A tap here must NOT silently reverse an
    /// explicit Settings opt-out — re-enabling lives in Settings → Health.
    private var isQuietOffState: Bool {
        !twin.bodyTwin.isActive && twin.bodyTwin.isAuthorized && queue.count == 0
    }

    var body: some View {
        // Absent entirely on devices without HealthKit, matching Settings.
        if healthKit.isAvailable {
            Button {
                if opensReview {
                    showReview = true
                } else if !twin.bodyTwin.isAuthorized {
                    enableBodyTwin()
                }
                // isQuietOffState: deliberately inert.
            } label: {
                HStack(spacing: 16) {
                    meter
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Body Twin")
                            .font(.dv(.callout, design: .rounded, weight: .bold))
                            .foregroundColor(.primary)
                        Text(subtitle)
                            .font(.dv(.footnote, design: .rounded, weight: .regular))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer()
                    if queue.count > 0 {
                        DSTag(text: "\(queue.count) waiting", tint: DS.Palette.gold)
                    }
                    if !isQuietOffState {
                        Image(systemName: "chevron.right")
                            .font(.dv(.footnote, weight: .semibold))
                            .foregroundColor(.secondary.opacity(0.5))
                    }
                }
                .padding(16)
                // Grouped-secondary matches every neighboring Twin-tab card
                // (plain-secondary rendered cool gray on the warm ivory canvas
                // in light, and a darker off-shade in Dark).
                .background(RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color(.secondarySystemGroupedBackground)))
            }
            .buttonStyle(.plain)
            .disabled(isRequestingAccess)
            .sheet(isPresented: $showReview) { BodyTwinReviewView().appThemedSheet() }
        }
    }

    private var subtitle: String {
        if isRequestingAccess {
            return "Asking Health for permission…"
        }
        guard twin.bodyTwin.isActive else {
            if queue.count > 0 {
                // Off, but signals still await a decision — the tap opens
                // the review sheet (Keep stays explicit, Let go always works).
                return "Body Twin is off — tap to review or let go of what's still waiting."
            }
            if twin.bodyTwin.isAuthorized {
                // Explicitly switched off — respect it. Point to Settings
                // instead of re-enabling on a stray tap.
                return "Body Twin is off. You can turn it back on in Settings → Health."
            }
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
                .font(.dv(.title3, weight: .semibold))
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
            // Prime the Motion & Fitness prompt inside this connect moment,
            // not mid entry-save (first CMMotionActivity query triggers it).
            await ActivityContextDetector.shared.update()
        }
    }
}
