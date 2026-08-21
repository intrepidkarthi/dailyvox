//
//  LiveActivityManager.swift
//  solyn
//
//  Centralises start/update/end of all ActivityKit Live Activities so feature
//  code (AudioRecorder, TodayView, app lifecycle) doesn't have to deal with
//  availability checks, authorisation, or activity bookkeeping directly.
//

import Foundation
import os.log
#if os(iOS)
import ActivityKit
#endif

private let logger = Logger(subsystem: "com.dailyvox.app", category: "LiveActivity")

/// User defaults key for the streak Live Activity opt-in toggle (Settings).
let kStreakLiveActivityEnabledKey = "streakLiveActivityEnabled"

@MainActor
final class LiveActivityManager {
    static let shared = LiveActivityManager()
    private init() {}

    #if os(iOS)
    private var _recordingActivity: Any?
    private var _streakActivity: Any?

    @available(iOS 16.2, *)
    private var recordingActivity: Activity<RecordingActivityAttributes>? {
        get { _recordingActivity as? Activity<RecordingActivityAttributes> }
        set { _recordingActivity = newValue }
    }

    @available(iOS 16.2, *)
    private var streakActivity: Activity<StreakActivityAttributes>? {
        get { _streakActivity as? Activity<StreakActivityAttributes> }
        set { _streakActivity = newValue }
    }
    #endif

    /// True if the user has authorised Live Activities for this app.
    var areActivitiesEnabled: Bool {
        #if os(iOS)
        if #available(iOS 16.2, *) {
            return ActivityAuthorizationInfo().areActivitiesEnabled
        }
        #endif
        return false
    }

    // MARK: - Recording

    func startRecordingActivity(softTarget: TimeInterval = 42) {
        #if os(iOS)
        guard #available(iOS 16.2, *), areActivitiesEnabled else { return }
        guard recordingActivity == nil else { return }

        let attributes = RecordingActivityAttributes(startedAt: Date(), softTargetSeconds: softTarget)
        let initialState = RecordingActivityAttributes.ContentState(
            elapsed: 0, level: 0, passedSoftTarget: false)
        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            recordingActivity = try Activity.request(attributes: attributes, content: content, pushType: nil)
        } catch {
            logger.error("Failed to start recording Live Activity: \(error.localizedDescription)")
        }
        #endif
    }

    func updateRecordingActivity(elapsed: TimeInterval,
                                 level: Float,
                                 softTarget: TimeInterval = 42,
                                 phrase: String = "",
                                 caughtName: String? = nil,
                                 valence: Double = 0,
                                 paused: Bool = false) {
        #if os(iOS)
        guard #available(iOS 16.2, *), let activity = recordingActivity else { return }
        let state = RecordingActivityAttributes.ContentState(
            elapsed: elapsed,
            level: level,
            passedSoftTarget: elapsed >= softTarget,
            phrase: phrase,
            caughtName: caughtName,
            valence: valence,
            paused: paused
        )
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
        #endif
    }

    func endRecordingActivity() {
        #if os(iOS)
        guard #available(iOS 16.2, *), let activity = recordingActivity else { return }
        let finalState = RecordingActivityAttributes.ContentState(
            elapsed: activity.content.state.elapsed,
            level: 0,
            passedSoftTarget: activity.content.state.passedSoftTarget
        )
        Task {
            await activity.end(ActivityContent(state: finalState, staleDate: nil), dismissalPolicy: .immediate)
        }
        recordingActivity = nil
        #endif
    }

    // MARK: - Star Birth

    /// Fires a short-lived celebratory Live Activity after an entry is saved.
    /// Auto-dismisses after `dismissAfter` seconds.
    ///
    /// Sixty, not eight. §E state ④ has the island "settle to an amber ember"
    /// after the star lands — the point of the ember is that it is still there
    /// when you put the phone down and pick it up again, which is the whole
    /// difference between a notification and a keepsake. Eight seconds made it
    /// a notification.
    func fireStarBirthActivity(streak: Int, totalStars: Int, moodRaw: String, dismissAfter: TimeInterval = 60) {
        #if os(iOS)
        guard #available(iOS 16.2, *), areActivitiesEnabled else { return }

        // Never stack: end any Star Birth activity that's still on screen before
        // starting a new one. Belt-and-suspenders alongside the once-per-day gate
        // at the call site.
        for existing in Activity<StarBirthActivityAttributes>.activities {
            Task { await existing.end(nil, dismissalPolicy: .immediate) }
        }

        let attributes = StarBirthActivityAttributes(moodRaw: moodRaw)
        let state = StarBirthActivityAttributes.ContentState(streak: streak, totalStars: totalStars)
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(dismissAfter))

        do {
            let activity = try Activity.request(attributes: attributes, content: content, pushType: nil)
            Task {
                try? await Task.sleep(nanoseconds: UInt64(dismissAfter * 1_000_000_000))
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        } catch {
            logger.error("Failed to fire star birth Live Activity: \(error.localizedDescription)")
        }
        #endif
    }

    // MARK: - Streak (opt-in, persistent)

    /// Whether the user has opted into the persistent streak Live Activity.
    var isStreakActivityEnabled: Bool {
        UserDefaults.standard.bool(forKey: kStreakLiveActivityEnabledKey)
    }

    func refreshStreakActivity(streak: Int, hasEntryToday: Bool, totalEntries: Int) {
        #if os(iOS)
        guard #available(iOS 16.2, *), areActivitiesEnabled else { return }
        guard isStreakActivityEnabled, streak > 0 else {
            endStreakActivity()
            return
        }

        let state = StreakActivityAttributes.ContentState(
            streak: streak,
            hasEntryToday: hasEntryToday,
            totalEntries: totalEntries
        )

        if let activity = streakActivity {
            Task { await activity.update(ActivityContent(state: state, staleDate: nil)) }
        } else {
            let attributes = StreakActivityAttributes(startedAt: Date())
            do {
                streakActivity = try Activity.request(
                    attributes: attributes,
                    content: ActivityContent(state: state, staleDate: nil),
                    pushType: nil
                )
            } catch {
                logger.error("Failed to start streak Live Activity: \(error.localizedDescription)")
            }
        }
        #endif
    }

    func endStreakActivity() {
        #if os(iOS)
        guard #available(iOS 16.2, *), let activity = streakActivity else { return }
        Task {
            await activity.end(nil, dismissalPolicy: .immediate)
        }
        streakActivity = nil
        #endif
    }

    /// End every running activity. Call on logout / data reset.
    func endAllActivities() {
        #if os(iOS)
        guard #available(iOS 16.2, *) else { return }
        Task {
            for activity in Activity<RecordingActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            for activity in Activity<StarBirthActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
            for activity in Activity<StreakActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
        _recordingActivity = nil
        _streakActivity = nil
        #endif
    }
}
