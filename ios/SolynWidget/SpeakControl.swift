//
//  SpeakControl.swift
//  SolynWidget
//
//  Control Centre / Lock Screen / Action Button — the iOS answer to Android's
//  Quick Settings tile (FINAL-SPEC §5).
//

import WidgetKit
import SwiftUI
import AppIntents

/// "Tap to speak", from Control Centre.
///
/// §5 lists a Quick Settings tile so that recording is two taps from any screen
/// including the lock screen. Android has had one since the port; iOS had no
/// equivalent because none existed — Control Centre was closed to third parties
/// until iOS 18's `ControlWidget`, and §7's mapping row could only offer
/// "WidgetKit + AppIntents", which is the home screen, not the shade.
///
/// The same control can be assigned to the Action Button, which is the closest
/// this product gets to a dedicated record key.
///
/// It opens the app rather than recording in place, for the reason set out on
/// `StartSpeakingIntent`: the microphone is only ever live with a screen in
/// front of it. Android's tile made exactly the same call, and there it was
/// forced by `BackgroundStartNotAllowed`; here it is a choice, and the same one.
@available(iOS 18.0, *)
struct SpeakControl: ControlWidget {
    static let kind = "com.dailyvox.app.SpeakControl"

    var body: some ControlWidgetConfiguration {
        StaticControlConfiguration(kind: Self.kind) {
            ControlWidgetButton(action: StartSpeakingIntent()) {
                Label("Speak", systemImage: "mic.fill")
            }
        }
        .displayName("Speak")
        // Also free of hardware names — see the note on `AskYourTwinIntent`.
        // This one was not in the rejection, but it would have been next.
        .description("Start a DailyVox entry. Nothing leaves your device.")
    }
}
