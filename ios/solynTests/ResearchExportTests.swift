//
//  ResearchExportTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// The research export is read by a tool that never sees the app, on a
/// laptop the app never talks to, alongside files written by the Android
/// build. A renamed key or a local-time date does not fail anything on the
/// phone — it fails on the participant's laptop, after they have already
/// done the hard part. So these read the encoded bytes back as untyped JSON
/// and check them against the contract, not against our own Codable types.
final class ResearchExportTests: XCTestCase {

    private func row(_ seconds: TimeInterval, label: String?, audio: Bool = true,
                     duration: Double = 42, text: String = "t") -> ResearchExportV1.Row {
        ResearchExportV1.Row(id: UUID(), createdAt: Date(timeIntervalSince1970: seconds),
                             text: text, selfLabel: label, hasAudio: audio, duration: duration)
    }

    private func encoded(_ rows: [ResearchExportV1.Row]) throws -> [String: Any] {
        let file = ResearchExportV1.build(
            rows: rows, participantCode: "DV-7K3Q-M9", appVersion: "1.12.0",
            osVersion: "iOS 26.3", deviceModel: "iPhone",
            exportedAt: Date(timeIntervalSince1970: 1_791_367_200) // 2026-10-07T10:00:00Z
        )
        let data = try ResearchExportV1.encode(file)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func testTopLevelKeysAndValuesMatchTheContract() throws {
        let json = try encoded([row(1_788_210_240, label: "joy")])

        XCTAssertEqual(Set(json.keys), [
            "schema", "consent_version", "participant_code", "platform", "app_version",
            "os_version", "device_model", "exported_at", "entry_count", "entries",
        ])
        XCTAssertEqual(json["schema"] as? String, "dailyvox-research-export/1")
        XCTAssertEqual(json["consent_version"] as? String, "3.0")
        XCTAssertEqual(json["platform"] as? String, "ios")
        XCTAssertEqual(json["exported_at"] as? String, "2026-10-07T10:00:00Z")
        XCTAssertEqual(json["entry_count"] as? Int, 1)
    }

    func testEntryKeysDatesAndInput() throws {
        let json = try encoded([
            row(1_788_296_640, label: "joy", audio: true, duration: 41.6),   // 2026-09-01T21:04:00Z
            row(1_788_383_040, label: "fear", audio: false, duration: 0),
        ])
        let entries = try XCTUnwrap(json["entries"] as? [[String: Any]])

        XCTAssertEqual(Set(entries[0].keys),
                       ["id", "created_at", "text", "self_label", "input", "duration_sec"])
        // UTC with a Z, whole seconds — never the phone's local offset.
        XCTAssertEqual(entries[0]["created_at"] as? String, "2026-09-01T21:04:00Z")
        XCTAssertEqual(entries[0]["input"] as? String, "voice")
        XCTAssertEqual(entries[0]["duration_sec"] as? Int, 42)
        XCTAssertEqual(entries[1]["input"] as? String, "typed")
        XCTAssertEqual(entries[1]["duration_sec"] as? Int, 0)
    }

    func testAudioWithoutDurationIsStillVoice() throws {
        // A recording whose duration was never measured is still a recording.
        let json = try encoded([row(1, label: "joy", audio: true, duration: 0)])
        let entries = try XCTUnwrap(json["entries"] as? [[String: Any]])
        XCTAssertEqual(entries[0]["input"] as? String, "voice")
    }

    func testOnlyCanonLabelledEntriesOldestFirst() throws {
        let json = try encoded([
            row(300, label: "sadness", text: "third"),
            row(100, label: "neutral", text: "first"),
            row(200, label: nil, text: "unlabelled"),
            row(250, label: "calm", text: "not in the canon"),
            row(150, label: "surprise", text: "second"),
        ])
        let entries = try XCTUnwrap(json["entries"] as? [[String: Any]])

        XCTAssertEqual(entries.compactMap { $0["text"] as? String }, ["first", "second", "third"])
        XCTAssertEqual(json["entry_count"] as? Int, 3)
        let canon: Set<String> = ["joy", "sadness", "anger", "fear", "surprise", "disgust", "neutral"]
        for e in entries {
            XCTAssertTrue(canon.contains(e["self_label"] as? String ?? ""))
        }
    }

    func testTheCanonIsTheSevenPreregisteredClasses() {
        XCTAssertEqual(Set(SelfLabelEmotion.allCases.map(\.rawValue)),
                       ["joy", "sadness", "anger", "fear", "surprise", "disgust", "neutral"])
    }

    func testParticipantCodeFormatAndPersistence() throws {
        for _ in 0..<200 {
            let code = ResearchParticipant.generate()
            XCTAssertTrue(ResearchParticipant.isValid(code), code)
            XCTAssertNotNil(code.range(of: "^DV-[A-HJ-NP-Z2-9]{4}-[A-HJ-NP-Z2-9]{2}$",
                                       options: .regularExpression), code)
        }

        let suite = "ResearchExportTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let first = ResearchParticipant.code(defaults: defaults)
        XCTAssertEqual(ResearchParticipant.code(defaults: defaults), first,
                       "generated once per install, not once per export")
    }
}
