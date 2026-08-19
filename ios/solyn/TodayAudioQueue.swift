//
//  TodayAudioQueue.swift
//  solyn
//
//  "Play today" (design §2.3) — every recording made today, back to back.
//

import AVFoundation
import CoreData
import Foundation

/// Plays the day's recordings in order, oldest first.
///
/// A voice journal that can only replay one entry at a time makes you tap
/// through your own evening. The pill in the Journal header states the total
/// duration up front, so the offer is "here is your day, it takes 3:12" rather
/// than an open-ended commitment.
///
/// Deliberately its own controller rather than a mode on `AudioPlaybackController`:
/// that one owns a single file's scrub position and rate for the detail screen,
/// and threading a queue through it would make two very different jobs share
/// one set of published state.
@MainActor
final class TodayAudioQueue: NSObject, ObservableObject, AVAudioPlayerDelegate {

    @Published private(set) var isPlaying = false
    /// Which item of the queue is sounding, for the pill's "2 of 5".
    @Published private(set) var index = 0
    @Published private(set) var count = 0

    private var urls: [URL] = []
    private var player: AVAudioPlayer?

    /// Total run time of today's recordings, or nil when there are none.
    ///
    /// `nonisolated` because it touches no actor state — it reads Core Data and
    /// the filesystem. Left MainActor-isolated by inheritance, the tests could
    /// not call it without hopping, which is a lot of ceremony for a pure
    /// function.
    nonisolated static func todayDuration(in context: NSManagedObjectContext) -> TimeInterval? {
        let urls = todayURLs(in: context)
        guard !urls.isEmpty else { return nil }
        // Read each file's real duration rather than the stored `duration`
        // field: an entry saved when transcription failed can carry a duration
        // with no audio behind it, and the pill would then promise time it
        // cannot play.
        let total = urls.reduce(0.0) { sum, url in
            sum + ((try? AVAudioPlayer(contentsOf: url))?.duration ?? 0)
        }
        return total > 0 ? total : nil
    }

    nonisolated static func todayURLs(in context: NSManagedObjectContext) -> [URL] {
        let cal = Calendar.current
        let start = cal.startOfDay(for: Date())
        let request = NSFetchRequest<DiaryEntry>(entityName: "DiaryEntry")
        request.predicate = NSPredicate(format: "date >= %@", start as NSDate)
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: true)]

        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("Recordings", isDirectory: true)

        return ((try? context.fetch(request)) ?? []).flatMap { entry in
            AudioFileList
                .parse(entry.value(forKey: "audioFileNames") as? String,
                       legacy: entry.value(forKey: "audioFileName") as? String)
                .map { dir.appendingPathComponent($0) }
                .filter { FileManager.default.fileExists(atPath: $0.path) }
        }
    }

    func start(in context: NSManagedObjectContext) {
        urls = Self.todayURLs(in: context)
        count = urls.count
        index = 0
        guard !urls.isEmpty else { return }
        // Spoken word, so .playback rather than .ambient: this should keep
        // sounding when the phone locks, and should not duck to silence
        // because the ringer switch is off.
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio)
        try? AVAudioSession.sharedInstance().setActive(true)
        #endif
        play(at: 0)
    }

    func stop() {
        player?.stop()
        player = nil
        isPlaying = false
        index = 0
        #if os(iOS)
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        #endif
    }

    func toggle(in context: NSManagedObjectContext) {
        isPlaying ? stop() : start(in: context)
    }

    private func play(at i: Int) {
        guard i < urls.count else { stop(); return }
        index = i
        do {
            let p = try AVAudioPlayer(contentsOf: urls[i])
            p.delegate = self
            p.prepareToPlay()
            p.play()
            player = p
            isPlaying = true
        } catch {
            // A missing or unreadable file skips rather than ending the queue —
            // one bad recording should not stop the rest of the day.
            play(at: i + 1)
        }
    }

    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            self.play(at: self.index + 1)
        }
    }
}
