//
//  RecordingControlIntents.swift
//  solyn
//
//  §E state ③ — Finish and Discard, from the Dynamic Island.
//

import AppIntents
import Foundation

/// Posted when a Live Activity button asks the app to end a recording.
///
/// A notification rather than a direct call because the intent runs in the app
/// process but has no handle on the view that owns the recorder. `TodayView`
/// listens; if it is not on screen there is no recording to end and nothing
/// happens, which is the correct outcome rather than a special case.
public extension Notification.Name {
    static let dailyVoxFinishRecording = Notification.Name("dailyVoxFinishRecording")
    static let dailyVoxDiscardRecording = Notification.Name("dailyVoxDiscardRecording")
    /// Object is `true` when a call or alarm paused the recording, `false` when
    /// it resumed. The dial reads it so the pause is visible rather than mysterious.
    static let dailyVoxRecordingInterrupted = Notification.Name("dailyVoxRecordingInterrupted")
}

/// Start speaking, from anywhere the system will put a button.
///
/// Lives here rather than in `AppIntents.swift` because this file is compiled
/// into the widget extension too, and `AppIntents.swift` pulls in Core Data and
/// the Twin engine — a lot of weight for an extension whose job is to draw a
/// star.
///
/// `openAppWhenRun` is true and that is not a compromise: recording needs the
/// microphone, and iOS only grants it to a foregrounded app. An intent that
/// claimed to record from the Lock Screen would either fail silently or need a
/// background-audio entitlement this app has deliberately not taken. One tap,
/// the app opens already recording, and the mic is only ever live with a screen
/// in front of it — which is the version an audience that chose this app for its
/// privacy claims would want anyway.
@available(iOS 17.0, *)
struct StartSpeakingIntent: AppIntent {
    static var title: LocalizedStringResource = "Speak"
    static var description = IntentDescription("Open DailyVox and start recording an entry.")
    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        // The same flag Siri sets. `solynApp` drains it on every foreground, not
        // only at launch, so this works whether the app was running or not.
        UserDefaults.standard.set(true, forKey: "shouldStartRecording")
        return .result()
    }
}

/// Keep it.
///
/// `LiveActivityIntent` is what makes this possible without opening the app:
/// the system runs `perform()` in the app's process while it is backgrounded,
/// so the button on the Island is the same action as the button on the dial
/// rather than a deep link that makes you unlock first.
@available(iOS 17.0, *)
struct FinishRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Finish recording"
    static var description = IntentDescription("Stop recording and keep the entry.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .dailyVoxFinishRecording, object: nil)
        }
        return .result()
    }
}

/// Throw it away.
///
/// Deliberately NOT confirmed from the Island. A confirmation sheet on the Lock
/// Screen would be a second thing to read at the exact moment someone wants the
/// recording gone — and the entry has not been saved yet, so discarding is the
/// same as never having spoken.
@available(iOS 17.0, *)
struct DiscardRecordingIntent: LiveActivityIntent {
    static var title: LocalizedStringResource = "Discard recording"
    static var description = IntentDescription("Throw this recording away without saving it.")
    static var openAppWhenRun: Bool = false

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .dailyVoxDiscardRecording, object: nil)
        }
        return .result()
    }
}
