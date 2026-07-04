//
//  BodyTwinManager.swift
//  solyn
//
//  App-side coordinator for the Body Twin (v1.5): user preferences, the
//  after-three-entries invite gate, snapshot capture into the review queue,
//  the Keep / Let go decisions, and the wipe-everything escape hatch.
//  All health data stays on this iPhone — see BodyTwinStores.swift.
//

import SwiftUI
import DailyVoxTwinEngine

@MainActor
final class BodyTwinManager: ObservableObject {
    static let shared = BodyTwinManager()

    private let defaults = UserDefaults.standard

    private enum Keys {
        static let enabled          = "bodyTwin_enabled"
        static let signalSleep      = "bodyTwin_signalSleep"
        static let signalHRV        = "bodyTwin_signalHRV"
        static let signalRestingHR  = "bodyTwin_signalRestingHR"
        static let signalSteps      = "bodyTwin_signalSteps"
        static let signalMindful    = "bodyTwin_signalMindful"
        static let hasSeenInvite    = "bodyTwin_hasSeenInvite"
        /// ReviewManager's saved-entry counter — the app's existing source of
        /// truth for how many entries this person has made.
        static let entryCount       = "reviewManager_entryCount"
    }

    // MARK: - Preferences

    /// Master toggle, mirrored into the engine (`BodyTwin.isEnabledByUser`)
    /// through the setter so pref and engine state move together. Defaults on
    /// to match the engine — the real gate is authorization, which only the
    /// user can grant.
    @Published var isEnabled: Bool {
        didSet {
            defaults.set(isEnabled, forKey: Keys.enabled)
            DigitalTwinEngine.shared.setBodyTwinEnabled(isEnabled)
        }
    }

    /// Per-signal opt-outs. A signal switched off is nil-ed out of every
    /// snapshot before it even reaches the review queue.
    @Published var sleepEnabled: Bool     { didSet { defaults.set(sleepEnabled, forKey: Keys.signalSleep) } }
    @Published var hrvEnabled: Bool       { didSet { defaults.set(hrvEnabled, forKey: Keys.signalHRV) } }
    @Published var restingHREnabled: Bool { didSet { defaults.set(restingHREnabled, forKey: Keys.signalRestingHR) } }
    @Published var stepsEnabled: Bool     { didSet { defaults.set(stepsEnabled, forKey: Keys.signalSteps) } }
    @Published var mindfulEnabled: Bool   { didSet { defaults.set(mindfulEnabled, forKey: Keys.signalMindful) } }

    @Published private(set) var hasSeenInvite: Bool {
        didSet { defaults.set(hasSeenInvite, forKey: Keys.hasSeenInvite) }
    }

    private init() {
        isEnabled        = Self.bool(Keys.enabled, default: true)
        sleepEnabled     = Self.bool(Keys.signalSleep, default: true)
        hrvEnabled       = Self.bool(Keys.signalHRV, default: true)
        restingHREnabled = Self.bool(Keys.signalRestingHR, default: true)
        stepsEnabled     = Self.bool(Keys.signalSteps, default: true)
        mindfulEnabled   = Self.bool(Keys.signalMindful, default: true)
        hasSeenInvite    = UserDefaults.standard.bool(forKey: Keys.hasSeenInvite)
    }

    private static func bool(_ key: String, default fallback: Bool) -> Bool {
        UserDefaults.standard.object(forKey: key) == nil
            ? fallback
            : UserDefaults.standard.bool(forKey: key)
    }

    // MARK: - Invite Gate

    var savedEntryCount: Int { defaults.integer(forKey: Keys.entryCount) }

    /// One-time "your Twin can learn what your body felt" invite: shown only
    /// after three entries of history, and never again once seen or once
    /// HealthKit has been asked (Settings → Health remains the anytime path).
    var shouldOfferInvite: Bool {
        !hasSeenInvite
            && !DigitalTwinEngine.shared.bodyTwin.isAuthorized
            && savedEntryCount >= 3
    }

    func markInviteSeen() {
        hasSeenInvite = true
    }

    /// Call after `HealthKitService.requestAuthorization()` completes so the
    /// engine remembers the user has been asked (read grants are unknowable
    /// by HealthKit design).
    func recordAuthorizationRequested() {
        DigitalTwinEngine.shared.setBodyTwinAuthorized(true)
    }

    // MARK: - Capture

    /// Monotonic counter bumped by `wipeAllHealthData()`. A capture Task
    /// suspends across several HealthKit round-trips; if the user completes
    /// the destructive wipe inside that window, the resumed task must not
    /// enqueue a fresh snapshot into the queue the wipe just promised to
    /// clear. (The master toggle is covered by re-checking `isActive`.)
    private var captureGeneration = 0

    /// Composes a background-context snapshot and, when it carries anything
    /// useful, adds it to the review queue — your Twin learns nothing until
    /// you tap Keep. Wired into TodayView's save flow after phase-1 save;
    /// never called for onboarding seeds, Siri intents, imports, or edits.
    func captureSnapshotIfEligible(at moment: Date = Date()) async {
        guard DigitalTwinEngine.shared.bodyTwin.isActive,
              HealthKitService.shared.isAuthorized else { return }
        let generation = captureGeneration

        let detector = ActivityContextDetector.shared
        let context = await detector.update()
        var snapshot = await HealthKitService.shared.composeSnapshot(
            at: moment,
            activityContext: context,
            activityConfidence: detector.currentConfidence,
            minutesSinceLastWorkout: detector.minutesSinceLastWorkout,
            includedSignals: enabledSignals   // disabled signals are never queried
        )

        // Belt-and-braces behind the includedSignals mask: nothing a user
        // switched off may survive into the queue even if a read slips through.
        if !sleepEnabled     { snapshot.sleepHours = nil }
        if !hrvEnabled       { snapshot.morningHRVMs = nil }
        if !restingHREnabled { snapshot.restingHRBpm = nil }
        if !stepsEnabled     { snapshot.stepsToday = nil }
        if !mindfulEnabled   { snapshot.mindfulMinutesToday = nil }

        guard snapshot.hasUsefulData else { return }
        // Re-check the gate after the awaits: a wipe or toggle-off completed
        // mid-capture wins over the in-flight snapshot.
        guard DigitalTwinEngine.shared.bodyTwin.isActive,
              generation == captureGeneration else { return }
        PendingSnapshotQueue.shared.enqueue(snapshot)
    }

    /// The per-signal opt-outs as a `HealthSignalSet`, so composeSnapshot
    /// only queries HealthKit for what the user left on.
    var enabledSignals: HealthSignalSet {
        var signals: HealthSignalSet = []
        if sleepEnabled     { signals.insert(.sleep) }
        if hrvEnabled       { signals.insert(.hrv) }
        if restingHREnabled { signals.insert(.restingHR) }
        if stepsEnabled     { signals.insert(.steps) }
        if mindfulEnabled   { signals.insert(.mindful) }
        return signals
    }

    // MARK: - Review Decisions

    /// Keep — the only path by which a snapshot ever reaches the Twin.
    func keepSnapshot(id: UUID) {
        guard let snapshot = PendingSnapshotQueue.shared.keep(id: id) else { return }
        // Fold-once invariant, belt-and-braces: if this id somehow re-entered
        // the queue after already being kept (a duplicate slipping past the
        // restore filters), drop it silently rather than double-fold the
        // baseline. KeptSnapshotStore.append's own dedupe can't help here —
        // it runs AFTER the fold.
        guard !KeptSnapshotStore.shared.contains(id: id) else { return }
        DigitalTwinEngine.shared.foldHealthSnapshot(snapshot)
        KeptSnapshotStore.shared.append(id: id, snapshot: snapshot)
    }

    /// Let go — deleted before the Twin ever saw it.
    func discardSnapshot(id: UUID) {
        PendingSnapshotQueue.shared.remove(id: id)
    }

    // MARK: - Backup Restore

    /// Restores Body Twin data from an encrypted backup (BackupService).
    /// Snapshots land verbatim in their stores, deduped by id, and nothing is
    /// ever re-folded or re-captured — a Keep decided on the old device stays
    /// decided. The learned state is adopted only when the backup's Twin has
    /// folded more than this device's, so a stale backup can never erase live
    /// learning. Consent flags stay local: HealthKit authorization is
    /// per-device and must be asked here anew.
    ///
    /// Order matters: the kept store is restored FIRST so the pending merge
    /// can drop anything already reviewed — a snapshot that was pending when
    /// the backup was made but has been Kept since must not re-enter the
    /// queue (a second Keep would double-fold it). Let-go decisions are
    /// covered by the queue's own tombstone filter.
    func restoreFromBackup(_ payload: ExportableBodyTwin) {
        KeptSnapshotStore.shared.restore(payload.keptSnapshots)
        let keptIds = KeptSnapshotStore.shared.ids
        PendingSnapshotQueue.shared.restore(
            payload.pendingSnapshots.filter { !keptIds.contains($0.id) })

        guard var imported = payload.state else { return }
        let local = DigitalTwinEngine.shared.bodyTwin
        guard imported.entriesWithSnapshot > local.entriesWithSnapshot else { return }
        imported.isAuthorized = local.isAuthorized
        imported.isEnabledByUser = local.isEnabledByUser
        let store = FileBodyTwinStateStore()
        store.saveBodyTwin(imported)
        DigitalTwinEngine.configureBodyTwinStore(store)
    }

    // MARK: - Wipe

    /// Settings' "Wipe all health snapshots": clears the review queue, the
    /// kept store, and everything the Body Twin has learned. The engine has
    /// no single reset call, so this persists a pristine `BodyTwin` carrying
    /// only the two consent flags, then re-configures the store — which
    /// reloads the pristine state into the engine's published sub-model.
    func wipeAllHealthData() {
        // Invalidate any capture Task currently suspended mid-HealthKit-read
        // so it cannot enqueue into the queue this wipe clears.
        captureGeneration += 1
        PendingSnapshotQueue.shared.wipe()
        KeptSnapshotStore.shared.wipe()

        let consent = DigitalTwinEngine.shared.bodyTwin
        let store = FileBodyTwinStateStore()
        store.saveBodyTwin(BodyTwin(isAuthorized: consent.isAuthorized,
                                    isEnabledByUser: consent.isEnabledByUser))
        DigitalTwinEngine.configureBodyTwinStore(store)
    }
}
