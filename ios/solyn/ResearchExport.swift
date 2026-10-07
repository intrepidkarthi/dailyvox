//
//  ResearchExport.swift
//  solyn
//
//  The research export, format `dailyvox-research-export/1`.
//
//  Both apps write this file in exactly the same shape (keys, types, date
//  form; not key order or whitespace), because the
//  analysis runs on the participant's own laptop and the tool reading it does
//  not know or care which phone it came from. The Android twin of this file is
//  android/.../system/Research.kt — a change here that is not made there splits
//  the cohort into two datasets the tool cannot pool.
//
//  Kept free of Core Data and UIKit so the shape can be tested from plain
//  values; BackupService adapts DiaryEntry rows into `Row`s.
//

import Foundation

enum ResearchExportV1 {

    static let schema = "dailyvox-research-export/1"

    /// The consent text this build's export is covered by. "3.0" is the
    /// result-file-only consent: the participant runs the analysis locally and
    /// shares numbers, never this file. One constant, so a consent revision is
    /// a one-line change that every export picks up.
    static let consentVersion = "3.0"

    /// One entry as the exporter sees it, before filtering.
    struct Row {
        let id: UUID
        let createdAt: Date
        let text: String
        let selfLabel: String?
        let hasAudio: Bool
        let duration: Double
    }

    struct Entry: Codable, Equatable {
        let id: String
        let createdAt: Date
        let text: String
        let selfLabel: String
        let input: String
        let durationSec: Int

        enum CodingKeys: String, CodingKey {
            case id, text, input
            case createdAt = "created_at"
            case selfLabel = "self_label"
            case durationSec = "duration_sec"
        }
    }

    struct File: Codable, Equatable {
        let schema: String
        let consentVersion: String
        let participantCode: String
        let platform: String
        let appVersion: String
        let osVersion: String
        let deviceModel: String
        let exportedAt: Date
        let entryCount: Int
        let entries: [Entry]

        enum CodingKeys: String, CodingKey {
            case schema, platform, entries
            case consentVersion = "consent_version"
            case participantCode = "participant_code"
            case appVersion = "app_version"
            case osVersion = "os_version"
            case deviceModel = "device_model"
            case exportedAt = "exported_at"
            case entryCount = "entry_count"
        }
    }

    /// Labelled entries only, oldest first. The protocol splits each person's
    /// entries by time (adapt on the early ones, test on the late ones), so
    /// the order is part of the data, not a presentation choice. A label
    /// outside the 7-class canon is dropped rather than passed through: the
    /// tool would reject the whole file over one unknown class.
    static func build(rows: [Row],
                      participantCode: String,
                      appVersion: String,
                      osVersion: String,
                      deviceModel: String,
                      exportedAt: Date = Date()) -> File {
        let entries: [Entry] = rows
            .compactMap { row -> (Row, SelfLabelEmotion)? in
                guard let raw = row.selfLabel, let label = SelfLabelEmotion(rawValue: raw) else { return nil }
                return (row, label)
            }
            .sorted { $0.0.createdAt < $1.0.createdAt }
            .map { row, label in
                Entry(
                    // As stored (uppercase on iOS, lowercase on Android): an
                    // opaque key that must still match the participant's own
                    // backup if they join the two.
                    id: row.id.uuidString,
                    createdAt: row.createdAt,
                    text: row.text,
                    selfLabel: label.rawValue,
                    // Same rule as Android: no audio AND no duration is typed.
                    // Either one alone means something was recorded.
                    input: (!row.hasAudio && row.duration == 0) ? "typed" : "voice",
                    durationSec: Int(row.duration.rounded())
                )
            }
        return File(
            schema: schema,
            consentVersion: consentVersion,
            participantCode: participantCode,
            platform: "ios",
            appVersion: appVersion,
            osVersion: osVersion,
            deviceModel: deviceModel,
            exportedAt: exportedAt,
            entryCount: entries.count,
            entries: entries
        )
    }

    /// ISO-8601 in UTC with whole seconds ("2026-09-01T21:04:00Z") — the
    /// form Android's Instant formatting produces, so the tool sees one
    /// date format whichever phone wrote the file.
    static func encode(_ file: File) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(file)
    }
}

// MARK: - Participant code

/// A random, per-install study code, `DV-XXXX-XX`. It is what lets a result
/// file be matched to a consent form without either carrying a name: the
/// participant writes it on the form, and it rides the export. Nothing about
/// the person or device goes into it.
enum ResearchParticipant {

    private static let key = "researchParticipantCode"

    /// A–Z without I and O, 2–9 without 0 and 1: nothing that reads as
    /// another character when copied by hand onto a consent form.
    static let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")

    /// Generated on first read and then fixed for the life of the install.
    static func code(defaults: UserDefaults = .standard) -> String {
        if let existing = defaults.string(forKey: key), isValid(existing) {
            return existing
        }
        let fresh = generate()
        defaults.set(fresh, forKey: key)
        return fresh
    }

    static func generate<R: RandomNumberGenerator>(using rng: inout R) -> String {
        let chars = (0..<6).map { _ in alphabet.randomElement(using: &rng)! }
        return "DV-" + String(chars[0..<4]) + "-" + String(chars[4..<6])
    }

    static func generate() -> String {
        var rng = SystemRandomNumberGenerator()
        return generate(using: &rng)
    }

    static func isValid(_ code: String) -> Bool {
        let parts = code.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3, parts[0] == "DV", parts[1].count == 4, parts[2].count == 2 else { return false }
        return (parts[1] + parts[2]).allSatisfy { alphabet.contains($0) }
    }
}
