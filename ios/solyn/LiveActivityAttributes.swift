//
//  LiveActivityAttributes.swift
//  solyn
//
//  ActivityKit attribute definitions shared between the main app (which
//  starts/updates/ends activities) and the widget extension (which renders
//  Dynamic Island + Lock Screen presentations).
//
//  This file must be a member of BOTH targets:
//    - solyn (main app)
//    - DailyVoxWidgets (widget extension)
//

import Foundation
#if os(iOS)
import ActivityKit

// MARK: - Recording Activity

/// Live Activity shown while the user is recording a voice entry.
/// Lifecycle: started in AudioRecorder.startRecording(), updated on each
/// metering tick, ended on stopRecording.
@available(iOS 16.2, *)
struct RecordingActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Seconds elapsed since recording started.
        public var elapsed: TimeInterval
        /// Normalized audio level, 0.0 to 1.0 (for waveform glyph).
        public var level: Float
        /// True after elapsed has crossed the 42-second soft target.
        public var passedSoftTarget: Bool

        /// The tail of what is being heard, live. §E state ③'s transcript line.
        /// Empty when live transcription is unavailable — see `LiveTranscriber`.
        public var phrase: String = ""
        /// A name just caught by the graph. §E state ②. Nil most of the time;
        /// it is a moment, not a field.
        public var caughtName: String?
        /// -1…1 running valence. §E state ③'s gradient bar.
        public var valence: Double = 0
        /// True while paused, so the Island stops claiming to listen.
        public var paused: Bool = false
    }

    // IMPLEMENTED as of the live-transcription work; this note is kept because
    // the reasoning explains the shape of the fix.
    //
    // WAS NOT IMPLEMENTED, and the reason was architectural rather than cosmetic.
    //
    // Design §E state 2 — "a star is caught" — blinks a gold star with each
    // name the NER recognises WHILE you speak. iOS DailyVox cannot do that:
    // `SpeechTranscriber` runs over the finished audio file after recording
    // stops, so there is no partial transcript to run NER against while the
    // Island is on screen. The field and its rendering were built and then
    // removed rather than shipped as a state nothing could ever populate.
    //
    // It needed a streaming recogniser feeding partial results, which was a real
    // change to the capture path, not a Live Activity change. `LiveTranscriber`
    // is that change: an `AVAudioEngine` tap into an on-device
    // `SFSpeechAudioBufferRecognitionRequest`, running alongside the file
    // recorder and degrading silently to no live text if it cannot start.

    /// Wall-clock time recording began, for the timeline-based timer.
    public var startedAt: Date
    /// The soft target the user is encouraged to hit (default 42s).
    public var softTargetSeconds: TimeInterval
}

// MARK: - Star Birth Activity

/// Brief celebratory Live Activity shown for a few seconds after the user
/// completes a voice entry. Auto-dismisses.
@available(iOS 16.2, *)
struct StarBirthActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// The user's current streak after this entry, for the line copy.
        public var streak: Int
        /// Total stars in the user's inner sky after this entry.
        public var totalStars: Int
    }

    /// Raw mood string from the saved entry (e.g. "happy"). The widget maps
    /// this to the same colour the app uses for that mood, so we don't ship
    /// hex values across the activity payload.
    public var moodRaw: String
}

// MARK: - Streak Activity

/// Persistent Live Activity tracking the user's current journaling streak.
/// Opt-in via Settings. Refreshed on app foreground; ended when the user
/// disables the setting or when the streak breaks.
@available(iOS 16.2, *)
struct StreakActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var streak: Int
        public var hasEntryToday: Bool
        public var totalEntries: Int
    }

    /// Static configuration — empty for now, room for future personalization.
    public var startedAt: Date
}

#endif

