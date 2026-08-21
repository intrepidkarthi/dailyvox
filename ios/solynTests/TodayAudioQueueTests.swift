//
//  TodayAudioQueueTests.swift
//  solynTests
//

import CoreData
import XCTest
@testable import solyn

/// The Play-today pill states a duration before you commit to listening, so
/// the number has to be honest. These tests are mostly about the pill NOT
/// appearing: an entry saved when transcription failed can carry a stored
/// duration with no audio behind it, and a pill promising 3:12 of a day that
/// has nothing to play is worse than no pill.
final class TodayAudioQueueTests: XCTestCase {

    private var container: NSPersistentContainer!
    private var context: NSManagedObjectContext { container.viewContext }
    private var recordingsDir: URL!

    override func setUpWithError() throws {
        container = PersistenceController(inMemory: true).container
        let base = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        recordingsDir = base.appendingPathComponent("Recordings", isDirectory: true)
        try? FileManager.default.createDirectory(at: recordingsDir,
                                                 withIntermediateDirectories: true)
    }

    @discardableResult
    private func entry(daysAgo: Int, audio: [String]) -> DiaryEntry {
        let e = DiaryEntry(context: context)
        e.id = UUID()
        e.date = Calendar.current.date(byAdding: .day, value: -daysAgo, to: Date())!
        e.text = "An entry."
        e.setValue(audio.joined(separator: "\n"), forKey: "audioFileNames")
        try? context.save()
        return e
    }

    /// Writes a real, playable file so `fileExists` and AVAudioPlayer agree.
    private func writeSilentClip(_ name: String) throws {
        // A minimal but structurally valid m4a is awkward to synthesise, so the
        // existence-filtering tests use a placeholder and the duration test is
        // the one that needs real audio — see `testDurationIgnoresUnplayable`.
        try Data([0x00]).write(to: recordingsDir.appendingPathComponent(name))
    }

    override func tearDownWithError() throws {
        for f in (try? FileManager.default.contentsOfDirectory(atPath: recordingsDir.path)) ?? [] {
            try? FileManager.default.removeItem(at: recordingsDir.appendingPathComponent(f))
        }
    }

    func testYesterdayIsNotToday() throws {
        try writeSilentClip("old.m4a")
        entry(daysAgo: 1, audio: ["old.m4a"])
        XCTAssertTrue(TodayAudioQueue.todayURLs(in: context).isEmpty,
                      "the pill plays TODAY, not the most recent day with audio")
    }

    func testEntryWithoutAudioContributesNothing() throws {
        entry(daysAgo: 0, audio: [])
        XCTAssertTrue(TodayAudioQueue.todayURLs(in: context).isEmpty)
        XCTAssertNil(TodayAudioQueue.todayDuration(in: context),
                     "a text-only day must hide the pill rather than offer 0:00")
    }

    func testMissingFileIsSkipped() throws {
        // The row references a recording that is not on this device — restored
        // from a JSON export, or removed to free space. It must not be offered.
        entry(daysAgo: 0, audio: ["absent.m4a"])
        XCTAssertTrue(TodayAudioQueue.todayURLs(in: context).isEmpty)
    }

    func testTodayCollectsEveryRecordingInOrder() throws {
        try writeSilentClip("a.m4a")
        try writeSilentClip("b.m4a")
        try writeSilentClip("c.m4a")
        // Two entries today, the first carrying two recordings.
        //
        // Anchored to the START OF TODAY rather than offset back from "now".
        // `Date() - 3h` is yesterday whenever the clock reads before 03:00, so
        // this test failed every night between midnight and 3am and passed every
        // other hour — the worst kind of red, since it looks like whatever you
        // happened to change that evening.
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: Date())
        let e1 = entry(daysAgo: 0, audio: ["a.m4a", "b.m4a"])
        e1.date = startOfToday
        let e2 = entry(daysAgo: 0, audio: ["c.m4a"])
        e2.date = startOfToday.addingTimeInterval(60)
        try context.save()

        let urls = TodayAudioQueue.todayURLs(in: context)
        XCTAssertEqual(urls.map(\.lastPathComponent), ["a.m4a", "b.m4a", "c.m4a"],
                       "oldest first, and multi-recording entries expand in place")
    }

    func testDurationIgnoresUnplayableFiles() throws {
        // The bytes exist but are not decodable audio. Duration must come from
        // what AVAudioPlayer can actually open, so the pill never advertises
        // time it cannot play.
        try writeSilentClip("corrupt.m4a")
        entry(daysAgo: 0, audio: ["corrupt.m4a"])
        XCTAssertNil(TodayAudioQueue.todayDuration(in: context))
    }

    func testClockFormatsMinutesAndSeconds() {
        XCTAssertEqual(TimelineView.clock(192), "3:12")
        XCTAssertEqual(TimelineView.clock(9), "0:09")
        XCTAssertEqual(TimelineView.clock(0), "0:00")
    }
}
