//
//  BodyTwinTodayCards.swift
//  solyn
//
//  TodayView's two idle-state Body Twin cards, mutually exclusive by
//  construction (the whisper needs Health connected, the invite needs it
//  not-yet-asked):
//
//    • Body whisper — one calm line of body context, cached per calendar day
//      and recomputed at most every few hours, silent while in motion. It is
//      context for the mic, never competition.
//    • Permission invite — the one-time, value-framed doorway to HealthKit
//      after three entries of trust; declining never nags again
//      (Settings → Health stays the path back).
//

import SwiftUI
import UIKit
import DailyVoxTwinEngine

// MARK: - Body Whisper

/// One calm line of body context with its icon and tint.
struct BodyWhisper: Equatable {
    let icon: String
    let tint: Color
    let text: String
}

/// Computes and caches today's whisper. Static by design — no timers, no
/// repeat animations — so TodayView's idle state stays idle-able.
@MainActor
final class BodyWhisperProvider: ObservableObject {
    static let shared = BodyWhisperProvider()

    @Published private(set) var whisper: BodyWhisper?

    /// When today's whisper (or deliberate silence) was computed. Valid for
    /// the calendar day, recomputed after a few hours at most.
    private var computedAt: Date?
    private let recomputeAfter: TimeInterval = 3 * 60 * 60

    private init() {}

    func refreshIfNeeded(now: Date = Date()) async {
        // SCREENSHOT-ONLY: the simulator's Health store is always empty, so
        // composeSnapshot would yield permanent silence. Under -ScreenshotMode
        // (set exclusively by the UI-test harness) we pin the snapshot a real
        // 6h 54m night would produce and let the normal composer phrase it.
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-ScreenshotMode") && !arguments.contains("-BodyTwinInviteDemo") {
            setWhisper(Self.compose(from: HealthSnapshot(
                capturedAt: now,
                activityContext: .atRest,
                sleepHours: 6.9,
                activityConfidence: 0.95
            )))
            return
        }

        // Cold-launch re-sync: the engine's persisted isActive loads
        // synchronously at launch, but HealthKitService.isAuthorized starts
        // false until its async getRequestStatusForAuthorization round-trip
        // lands — and TodayView's .task reliably wins that race. Without
        // this, an authorized user's whisper is absent on every cold launch
        // until the app is backgrounded and foregrounded once.
        if DigitalTwinEngine.shared.bodyTwin.isActive,
           !HealthKitService.shared.isAuthorized {
            await HealthKitService.shared.refreshAuthorizationState()
        }

        guard DigitalTwinEngine.shared.bodyTwin.isActive,
              HealthKitService.shared.isAuthorized else {
            // Deliberately uncached: the moment Health is connected, the
            // next refresh may speak.
            computedAt = nil
            setWhisper(nil)
            return
        }
        if let computedAt,
           Calendar.current.isDate(computedAt, inSameDayAs: now),
           now.timeIntervalSince(computedAt) < recomputeAfter {
            return
        }
        computedAt = now

        let detector = ActivityContextDetector.shared
        let context = await detector.update()
        // Mid-motion is no moment for quiet context.
        guard context != .active else {
            setWhisper(nil)
            return
        }

        let manager = BodyTwinManager.shared
        var snapshot = await HealthKitService.shared.composeSnapshot(
            at: now,
            activityContext: context,
            activityConfidence: detector.currentConfidence,
            minutesSinceLastWorkout: detector.minutesSinceLastWorkout,
            includedSignals: manager.enabledSignals   // opt-outs filter the reads themselves
        )
        // Belt-and-braces behind the includedSignals mask, mirroring capture.
        if !manager.sleepEnabled     { snapshot.sleepHours = nil }
        if !manager.hrvEnabled       { snapshot.morningHRVMs = nil }
        if !manager.restingHREnabled { snapshot.restingHRBpm = nil }
        if !manager.stepsEnabled     { snapshot.stepsToday = nil }
        if !manager.mindfulEnabled   { snapshot.mindfulMinutesToday = nil }

        guard snapshot.hasUsefulData else {
            setWhisper(nil)
            return
        }
        setWhisper(Self.compose(from: snapshot))
    }

    /// Synchronously drops the cached whisper. Called when the user turns
    /// Body Twin off, so the health-derived line can never flash back on the
    /// Record tab after they said "stop" (the async refresh would only clear
    /// it a frame or two later).
    func invalidate() {
        computedAt = nil
        setWhisper(nil)
    }

    private func setWhisper(_ newWhisper: BodyWhisper?) {
        guard newWhisper != whisper else { return }
        if UIAccessibility.isReduceMotionEnabled {
            whisper = newWhisper
        } else {
            withAnimation(.spring(response: 0.4)) { whisper = newWhisper }
        }
    }

    /// Sleep first (most felt), then movement, then stillness. Heart numbers
    /// stay out of the whisper — a bare HRV reading reads clinical, and the
    /// whisper promises calm, not diagnosis.
    private static func compose(from snapshot: HealthSnapshot) -> BodyWhisper? {
        if let sleep = snapshot.sleepHours {
            let slept = formatHours(sleep)
            if sleep < 6 {
                return BodyWhisper(icon: "moon.zzz.fill", tint: DS.Palette.gold,
                                   text: "You slept \(slept). Take a breath before you speak.")
            }
            if sleep < 7 {
                return BodyWhisper(icon: "moon.zzz.fill", tint: DS.Palette.sage,
                                   text: "Slept \(slept) — ease into today gently.")
            }
            return BodyWhisper(icon: "moon.zzz.fill", tint: DS.Palette.sage,
                               text: "Slept \(slept) — your sky is clear.")
        }
        if let steps = snapshot.stepsToday, steps >= 6000 {
            return BodyWhisper(icon: "figure.walk", tint: DS.Palette.gold,
                               text: "\(steps.formatted()) steps already — your day is in motion.")
        }
        if let mindful = snapshot.mindfulMinutesToday, mindful > 0 {
            return BodyWhisper(icon: "leaf.fill", tint: DS.Palette.forest,
                               text: mindful == 1
                                   ? "1 quiet minute today — carry that calm in."
                                   : "\(mindful) quiet minutes today — carry that calm in.")
        }
        return nil
    }

    private static func formatHours(_ hours: Double) -> String {
        let totalMinutes = Int((hours * 60).rounded())
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }
}

// MARK: - Idle Cards (TodayView slot)

/// The single Body Twin slot between TodayView's header and entry card.
/// Renders the one-time invite, or today's whisper, or nothing.
struct BodyTwinIdleCards: View {
    @ObservedObject private var healthKit = HealthKitService.shared
    @ObservedObject private var manager = BodyTwinManager.shared
    @ObservedObject private var whisperProvider = BodyWhisperProvider.shared
    @ObservedObject private var twin = DigitalTwinEngine.shared
    @ObservedObject private var theme = ThemeManager.shared
    @State private var showInviteSheet = false

    // Fixed warm inks belong to the ivory theme only; every other theme sits
    // on system backgrounds, so text must use system adaptive colors or it
    // vanishes in Dark (ThemeManager's own `ivory ? warm : system` pattern).
    private var inkPrimary: Color   { theme.selectedTheme == .ivory ? DS.Palette.ink : .primary }
    private var inkSecondary: Color { theme.selectedTheme == .ivory ? DS.Palette.inkSoft : .primary }
    private var inkMuted: Color     { theme.selectedTheme == .ivory ? DS.Palette.inkMute : .secondary }

    var body: some View {
        // Absent entirely on devices without HealthKit, matching Settings.
        if healthKit.isAvailable {
            if manager.shouldOfferInvite {
                inviteCard
            } else if twin.bodyTwin.isActive, let whisper = whisperProvider.whisper {
                // Render-time gate on the engine flag: a cached whisper must
                // never appear after the user disabled Body Twin (the
                // provider is also invalidated on disable — belt and braces).
                whisperCard(whisper)
            }
        }
    }

    // MARK: Whisper card

    private func whisperCard(_ whisper: BodyWhisper) -> some View {
        HStack(spacing: 10) {
            Image(systemName: whisper.icon)
                .font(.system(.footnote).weight(.semibold))
                .foregroundColor(whisper.tint)
            Text(whisper.text)
                .font(.dsCallout)
                .foregroundColor(inkSecondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, DS.Space.md)
        .padding(.vertical, DS.Space.sm)
        .background(
            RoundedRectangle(cornerRadius: DS.Radius.md, style: .continuous)
                .fill(whisper.tint.opacity(0.10))
        )
        .transition(.opacity)
        .accessibilityElement(children: .combine)
    }

    // MARK: Invite card

    private var inviteCard: some View {
        Button {
            HapticManager.shared.buttonTap()
            showInviteSheet = true
        } label: {
            HStack(spacing: DS.Space.sm) {
                ZStack {
                    Circle()
                        .fill(DS.Palette.tintTerra)
                        .frame(width: 40, height: 40)
                    Image(systemName: "figure.mind.and.body")
                        .font(.system(.body).weight(.semibold))
                        .foregroundColor(DS.Palette.terracotta)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Your Twin can learn what your body felt")
                        .font(.dsCallout)
                        .foregroundColor(inkPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Sleep, steps, quiet minutes — you approve every signal first.")
                        .font(.dsCaption)
                        .foregroundColor(inkMuted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(.caption).weight(.semibold))
                    .foregroundColor(inkMuted.opacity(0.6))
            }
            .padding(DS.Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            // 20pt like the entry card stacked directly beneath it — the two
            // full-width Today cards should share one corner radius.
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(theme.warmCardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(DS.Palette.gold.opacity(0.25), lineWidth: 1)
            )
            .dsShadowSoft()
        }
        .buttonStyle(SpringPressStyle(scale: 0.97))
        .transition(.opacity)
        .sheet(isPresented: $showInviteSheet, onDismiss: {
            // Any way the sheet closes counts as seen — one gentle ask, ever.
            withAnimation(.spring(response: 0.4)) {
                manager.markInviteSeen()
            }
        }) {
            BodyTwinInviteSheet()
        }
    }
}

// MARK: - Invite Explainer Sheet

/// The five signals, the review-before-learning promise, and the
/// private-by-design line — then one soft yes and one soft no.
struct BodyTwinInviteSheet: View {
    @ObservedObject private var healthKit = HealthKitService.shared
    @ObservedObject private var manager = BodyTwinManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var isRequestingAccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    signalsList
                    promises
                    actions
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Your body's side of the story")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(DS.Palette.terracotta.opacity(0.15))
                    .frame(width: 64, height: 64)
                Image(systemName: "figure.mind.and.body")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(DS.Palette.terracotta)
            }
            Text("Your Twin can learn what your body felt")
                .font(.system(.title3, design: .rounded).weight(.bold))
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            Text("Some days the body speaks first — short sleep, a long walk, a quiet morning. Connect Health and your Twin can hear that side of you too.")
                .font(.system(.subheadline, design: .rounded))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    private var signalsList: some View {
        VStack(alignment: .leading, spacing: 14) {
            signalRow(icon: "moon.zzz.fill", color: DS.Palette.sage,
                      name: "Sleep", detail: "Hours of rest the night before")
            signalRow(icon: "waveform.path.ecg", color: DS.Palette.terracotta,
                      name: "Morning HRV", detail: "How your heart greeted the day")
            signalRow(icon: "heart.fill", color: DS.Palette.coral,
                      name: "Resting heart", detail: "Your calm baseline, not your peaks")
            signalRow(icon: "figure.walk", color: DS.Palette.gold,
                      name: "Steps", detail: "How far the day carried you")
            signalRow(icon: "leaf.fill", color: DS.Palette.forest,
                      name: "Mindful minutes", detail: "Quiet minutes you set aside")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func signalRow(icon: String, color: Color, name: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(.subheadline).weight(.semibold))
                .foregroundColor(color)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.system(.subheadline, design: .rounded).weight(.semibold))
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.system(.caption, design: .rounded))
                    .foregroundColor(.secondary)
            }
        }
    }

    private var promises: some View {
        VStack(alignment: .leading, spacing: 14) {
            promiseRow(icon: "sparkles", color: DS.Palette.gold,
                       text: "Review before your Twin learns. Every signal waits for you — Keep what feels true, let go of the rest.")
            promiseRow(icon: "lock.shield.fill", color: DS.Palette.sage,
                       text: "Private by design. Health and motion signals stay on this iPhone — never uploaded, never synced. iOS will also ask about motion, so moving days are read in context.")
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.secondarySystemGroupedBackground)))
    }

    private func promiseRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(.subheadline).weight(.semibold))
                .foregroundColor(color)
                .frame(width: 22)
            Text(text)
                .font(.system(.footnote, design: .rounded))
                .foregroundColor(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button {
                connectHealth()
            } label: {
                Text(isRequestingAccess ? "Asking Health…" : "Connect Health")
            }
            .buttonStyle(.dsPrimary)
            .disabled(isRequestingAccess)

            // The sheet's onDismiss marks the invite seen — asked once, ever.
            // Settings → Health stays the anytime path back.
            Button("Maybe later") {
                dismiss()
            }
            .font(.dsCallout)
            .foregroundColor(.secondary)
            .disabled(isRequestingAccess)
        }
    }

    /// Same enable flow as Settings → Health and the Twin-tab card: the
    /// permission sheet completing is all read-only HealthKit lets us know,
    /// so completion counts as "asked" and the Twin turns on.
    private func connectHealth() {
        guard !isRequestingAccess else { return }
        isRequestingAccess = true
        Task { @MainActor in
            defer { isRequestingAccess = false }
            if !healthKit.isAuthorized {
                do {
                    try await healthKit.requestAuthorization()
                } catch {
                    return // sheet failed to appear — stay, so they can retry
                }
            }
            manager.recordAuthorizationRequested()
            manager.isEnabled = true
            HapticManager.shared.entrySaved()
            dismiss()
            // The whisper may now have something to say for today.
            await BodyWhisperProvider.shared.refreshIfNeeded()
        }
    }
}
