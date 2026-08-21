//
//  LiveTranscriber.swift
//  solyn
//
//  Live, on-device partial transcription — what §E states ② and ③ were waiting
//  for.
//

import Foundation
import AVFoundation
import Speech
import NaturalLanguage
import DailyVoxTwinEngine

/// Transcribes WHILE you speak, so the Dynamic Island and the recording dial can
/// show what is being heard.
///
/// The Island's "entity caught" state and its live transcript line were the two
/// pieces of the design this app could not draw, and the reason was never the
/// Island — it was that `SpeechTranscriber` runs over the finished audio file
/// after recording stops. There was nothing to show because nothing existed yet.
///
/// ## Why this does not replace the real transcription
///
/// The saved entry's text still comes from the file-based pass in
/// `SpeechTranscriber`, which is markedly more accurate on sustained speech and
/// on iOS 26 uses `SpeechAnalyzer`. This class exists only to make the recording
/// moment legible. Two consequences follow deliberately:
///
/// - Its output is never saved. A partial is a guess in progress, and storing it
///   would mean the entry sometimes disagreed with the audio.
/// - If it fails, **nothing else does**. Every failure path here is a silent
///   downgrade to no live text. Recording, saving and transcription are entirely
///   unaffected, which is the correct trade: the live line is a nicety and the
///   recording is the product.
///
/// ## On-device, always
///
/// Same rule as everywhere else — `requiresOnDeviceRecognition` is forced, and
/// where the device cannot do it, this simply does not run rather than sending
/// a live microphone feed to a server.

/// A thread-safe handle on the current recognition request.
///
/// Exists so the audio tap can hand buffers to whichever request is live without
/// touching main-actor state. Rotating the task swaps the value underneath a
/// running tap, so the tap itself never has to be removed and reinstalled —
/// which would drop audio at exactly the seam.
private final class RequestBox: @unchecked Sendable {
    private let lock = NSLock()
    private var value: SFSpeechAudioBufferRecognitionRequest?

    func set(_ request: SFSpeechAudioBufferRecognitionRequest?) {
        lock.lock(); value = request; lock.unlock()
    }

    func append(_ buffer: AVAudioPCMBuffer) {
        lock.lock()
        let request = value
        lock.unlock()
        // Appended OUTSIDE the lock: `append` does real work, and holding a lock
        // across it on an audio thread is how you get a glitch.
        request?.append(buffer)
    }
}

@MainActor
final class LiveTranscriber: ObservableObject {

    /// The most recent partial, trimmed to the last clause or so.
    @Published private(set) var phrase: String = ""
    /// A name the graph recognises, most recently heard. Drives §E state ②.
    @Published private(set) var caughtName: String?
    /// -1…1 running valence of what has been said. Drives §E state ③'s bar.
    @Published private(set) var valence: Double = 0
    /// True when a session is actually running, so callers can tell "silent" from
    /// "unavailable".
    @Published private(set) var isRunning = false

    private let engine = AVAudioEngine()

    /// The request the audio tap is currently feeding.
    ///
    /// Held in a lock-protected box rather than read off this `@MainActor` class,
    /// because the tap callback runs on a realtime audio thread. Reaching back to
    /// the main actor from there is not merely slow — `MainActor.assumeIsolated`
    /// TRAPS when the assumption is false, which is every single buffer. The box
    /// is the boring correct answer, and the lock is uncontended in practice: it
    /// is written once per task rotation, about once a minute.
    private let box = RequestBox()

    private var request: SFSpeechAudioBufferRecognitionRequest? {
        didSet { box.set(request) }
    }
    private var task: SFSpeechRecognitionTask?
    /// Same resolver the file-based path uses: current locale first, then the
    /// base language, then en-US — all of them required to be on-device.
    private let recognizer = SpeechTranscriber.onDeviceRecognizer()

    /// Analysis is debounced: partials arrive several times a second and
    /// `NLTagger` is not free. Names and mood do not change that fast.
    private var lastAnalysis = Date.distantPast
    private static let analysisInterval: TimeInterval = 0.7

    /// Names worth announcing, lowercased once per session.
    private var knownNames: [String] = []

    /// Names already announced this recording, so one mention blinks once.
    private var announced: Set<String> = []
    private var blinkTask: Task<Void, Never>?

    /// How long the caught name stays up.
    ///
    /// §E2 says "half a second, then back to listening". Taken literally that
    /// window would usually be missed entirely — the Live Activity is pushed at
    /// 2 Hz, so a 0.5s state has an even chance of never being sent. This is the
    /// shortest duration that reliably survives one push while still reading as
    /// a moment rather than a label.
    private static let blinkDuration: TimeInterval = 2.5

    /// How many times the recognition task has been rotated this recording.
    ///
    /// `SFSpeechRecognitionTask` stops on its own after roughly a minute. That
    /// is fine for dictation and wrong for this app: 42 seconds is a soft target
    /// the design explicitly describes as "a shape, not a cutoff", so the entries
    /// where the live line matters most are exactly the ones that outlive one
    /// task. Rotating keeps it alive for as long as someone is talking.
    private var rotations = 0

    /// A ceiling, so a recogniser that is failing instantly cannot spin.
    /// Twenty rotations is roughly twenty minutes of speech.
    private static let maxRotations = 20

    // MARK: - Lifecycle

    /// Best-effort. Returns without complaint if live transcription is not
    /// possible on this device, in this locale, or right now.
    func start() {
        guard !isRunning else { return }
        reset()

        guard SFSpeechRecognizer.authorizationStatus() == .authorized,
              let recognizer, recognizer.isAvailable else { return }

        knownNames = DigitalTwinEngine.shared.knowledgeGraph
            .topNodes(ofType: .person, limit: 40)
            .map { $0.label }
            .filter { $0.count > 1 }

        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        // A zero sample rate means the input is not actually available yet —
        // installing a tap on it throws, and there is no recovery worth the code.
        guard format.sampleRate > 0 else { return }

        // The tap reads `self.request` at call time rather than capturing one,
        // so rotating the request underneath it needs no tap surgery — audio
        // keeps flowing into whichever request is current.
        input.installTap(onBus: 0, bufferSize: 2048, format: format) { [box] buffer, _ in
            box.append(buffer)
        }

        do {
            engine.prepare()
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            return
        }

        isRunning = true
        rotations = 0
        startTask()
    }

    /// Start — or restart — the recognition task over the running engine.
    private func startTask() {
        guard isRunning, let recognizer else { return }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.requiresOnDeviceRecognition = true
        request.addsPunctuation = true
        self.request = request

        task = recognizer.recognitionTask(with: request) { [weak self] result, error in
            guard let self else { return }
            let finished = (result?.isFinal ?? false) || error != nil
            if let result {
                let text = result.bestTranscription.formattedString
                Task { @MainActor in self.ingest(text) }
            }
            if finished {
                Task { @MainActor in self.rotate() }
            }
        }
    }

    /// One task ended; if the microphone is still open, start another.
    private func rotate() {
        guard isRunning else { return }
        task = nil
        request?.endAudio()
        request = nil

        guard rotations < Self.maxRotations else {
            // Give up on the live line, not on the recording. The dial falls
            // back to "Listening…" and the entry is entirely unaffected.
            stop()
            return
        }
        rotations += 1
        // The phrase resets with the task — it is the tail of what is being
        // said, and a new task genuinely has not heard anything yet.
        phrase = ""
        startTask()
    }

    /// Stop appending audio but keep the last phrase on screen — a pause should
    /// not blank the line the user was watching.
    func pause() {
        guard isRunning else { return }
        engine.pause()
    }

    func resume() {
        guard isRunning else { return }
        try? engine.start()
    }

    func stop() {
        blinkTask?.cancel()
        blinkTask = nil
        // Cleared FIRST. Cancelling the task fires its callback with an error,
        // which asks for a rotation; `rotate()` guards on this flag, so setting
        // it last would leave the ordering correct only by accident.
        isRunning = false
        if engine.isRunning || engine.inputNode.engine != nil {
            engine.inputNode.removeTap(onBus: 0)
        }
        engine.stop()
        request?.endAudio()
        task?.cancel()
        request = nil
        task = nil
    }

    private func reset() {
        phrase = ""
        caughtName = nil
        valence = 0
        lastAnalysis = .distantPast
        announced.removeAll()
        blinkTask?.cancel()
        blinkTask = nil
    }

    // MARK: - Analysis
    //
    // The three helpers below are `nonisolated`: they are pure functions over a
    // string, they do `NLTagger` work that has no business on the main actor,
    // and keeping them off it means the recognition callback can call them
    // without a hop.

    private func ingest(_ full: String) {
        phrase = Self.lastClause(of: full)

        let now = Date()
        guard now.timeIntervalSince(lastAnalysis) >= Self.analysisInterval else { return }
        lastAnalysis = now

        if let name = Self.detectName(in: full, known: knownNames),
           !announced.contains(name.lowercased()) {
            announce(name)
        }
        valence = Self.valence(of: full)
    }

    /// Show a caught name, then put it away.
    ///
    /// It used to be set and never cleared, so the first name of a recording
    /// became a permanent label on the Dynamic Island — the opposite of the
    /// design's intent, which is that the Twin is seen catching something and
    /// then goes back to listening. Each name announces once per recording;
    /// hearing "Sarah" nine times is one event, not nine.
    private func announce(_ name: String) {
        announced.insert(name.lowercased())
        caughtName = name
        blinkTask?.cancel()
        blinkTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(Self.blinkDuration * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await MainActor.run { self?.caughtName = nil }
        }
    }

    /// The tail of what has been said, not the whole transcript.
    ///
    /// The Island has room for one line and the dial for two. Showing the head
    /// of a growing transcript means watching a sentence you finished a minute
    /// ago; showing the tail means watching yourself talk.
    nonisolated static func lastClause(of text: String, limit: Int = 90) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > limit else { return trimmed }
        let tail = String(trimmed.suffix(limit))
        // Start at a word boundary so it does not open mid-word.
        if let space = tail.firstIndex(of: " ") {
            return String(tail[tail.index(after: space)...])
        }
        return tail
    }

    /// A person's name, preferring ones the graph already knows.
    ///
    /// Graph-first is the point: "Sarah ✦ filed to your sky" is only true if
    /// Sarah is actually a node. `NLTagger` catches new names the graph has not
    /// met yet, which is the case where the moment is most worth showing.
    nonisolated static func detectName(in text: String, known: [String]) -> String? {
        let lowered = text.lowercased()
        if let hit = known.last(where: { lowered.contains($0.lowercased()) }) {
            return hit
        }

        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found: String?
        let options: NLTagger.Options = [.omitWhitespace, .omitPunctuation, .joinNames]
        tagger.enumerateTags(in: text.startIndex..<text.endIndex,
                             unit: .word, scheme: .nameType, options: options) { tag, range in
            if tag == .personalName {
                let candidate = String(text[range])
                // One-letter "names" are almost always a mis-tag on a filler word.
                if candidate.count > 1 { found = candidate }
            }
            return true
        }
        return found
    }

    /// -1…1, from Apple's on-device sentiment score.
    nonisolated static func valence(of text: String) -> Double {
        guard text.count > 12 else { return 0 }
        let tagger = NLTagger(tagSchemes: [.sentimentScore])
        tagger.string = text
        let (tag, _) = tagger.tag(at: text.startIndex, unit: .paragraph, scheme: .sentimentScore)
        guard let raw = tag?.rawValue, let score = Double(raw) else { return 0 }
        return max(-1, min(1, score))
    }
}
