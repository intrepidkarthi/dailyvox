//
//  TwinBrainManager.swift
//  solyn
//
//  Availability + preference gate for the v1.7 Foundation Models Twin. The
//  gate is purely framework-reported (SystemLanguageModel availability via
//  the engine's FoundationTwinChat) — no hardware-model sniffing, matching
//  the SpeechAnalyzer adoption pattern. Default ON where available: the
//  feature adds no new permissions or data flows (all on-device, zero
//  network), so the Settings toggle is a kill-switch back to the classic
//  template chat, not a permission.
//

import Foundation
import SwiftUI
import DailyVoxTwinEngine

@MainActor
final class TwinBrainManager: ObservableObject {
    static let shared = TwinBrainManager()

    enum Status: Equatable {
        /// iOS < 26 — the classic chat, no Settings section at all.
        case unsupportedOS
        /// iOS 26+ but hardware can't run Apple Intelligence — section omitted.
        case deviceNotEligible
        /// Eligible, but Apple Intelligence is off in system Settings.
        case appleIntelligenceOff
        /// Eligible and enabled; the OS is still preparing the model.
        case modelNotReady
        case ready
    }

    /// Kill-switch (default ON — see header). Stored, so it survives launches.
    @AppStorage("twinFoundationModelEnabled") var enabled = true

    private init() {}

    var status: Status {
        guard #available(iOS 26.0, *) else { return .unsupportedOS }
        #if canImport(FoundationModels)
        switch FoundationTwinChat.availability() {
        case .ready: return .ready
        case .modelNotReady: return .modelNotReady
        case .appleIntelligenceNotEnabled: return .appleIntelligenceOff
        case .deviceNotEligible: return .deviceNotEligible
        case .unavailable: return .deviceNotEligible
        }
        #else
        return .unsupportedOS
        #endif
    }

    /// Whether the Settings section should exist at all (healthSection
    /// pattern: absent entirely where the capability can't exist).
    var isSupportedHere: Bool {
        switch status {
        case .unsupportedOS, .deviceNotEligible: return false
        default: return true
        }
    }

    var isActive: Bool { status == .ready && enabled }

    /// Builds the FM pipeline wired to the live engine + Core Data adapter.
    /// Returned as `Any?` because stored properties can't be availability-
    /// gated on an iOS 17 type — callers downcast inside #available blocks.
    func makePipeline() -> Any? {
        guard isActive else { return nil }
        if #available(iOS 26.0, *) {
            #if canImport(FoundationModels)
            return FoundationTwinChat(twin: DigitalTwinEngine.shared,
                                      profile: TwinChatProfile(from: LocalAIEngine.shared.userProfile),
                                      evidence: TwinChatEvidenceAdapter())
            #else
            return nil
            #endif
        }
        return nil
    }
}
