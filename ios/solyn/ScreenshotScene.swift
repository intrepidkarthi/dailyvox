//
//  ScreenshotScene.swift
//  solyn
//
//  Reaching a surface from the command line, for App Store captures.
//

import Foundation

/// A surface a screenshot run needs to reach that no launch argument could
/// otherwise open.
///
/// `-StartTab` already exists for the same reason and carries the same
/// justification: the simulator has no way to tap a hand-built tab bar or a
/// list row from the command line, so the surfaces worth photographing —
/// an entry, the share sheet — were unreachable without a UI-test runner that
/// is not reliable on every machine.
///
/// This is inert unless `-ScreenshotMode` is also passed, so nothing here can
/// change what a real user sees. It exists so that regenerating the App Store
/// set is one script rather than an afternoon of tapping, which is the reason
/// the last set went four releases out of date.
enum ScreenshotScene: String {
    case entry
    case share
    case settings
    case insights
    case search
    case ask
    case recording
    /// Today with the typed composer open and a line already written: the
    /// "I can't talk right now" frame (1.12).
    case typing

    /// A canned query, so the search and Ask frames show a real answer rather
    /// than an empty field. Deliberately a sentence — the semantic index ranks
    /// short keyword queries poorly, and the store frame should show the
    /// feature working the way the UI asks you to use it.
    static var cannedQuery: String {
        ScreenshotSeed.current?.cannedQuery ?? "a quiet moment that made me feel grounded"
    }

    /// What the typing frame shows in the composer: the situation the feature
    /// was asked for, in the words a user would write.
    static var cannedTyped: String {
        ScreenshotSeed.current?.cannedTyped
            ?? "Long day. The team finally shipped, and I could not stop smiling on the train home. Mom called while I was making dinner."
    }

    /// The question the Ask frame sends. It has to be one the Twin can only
    /// answer from THIS journal, so the reply demonstrates the claim ("answers
    /// with receipts") instead of sounding like any chatbot.
    static var cannedAsk: String {
        ScreenshotSeed.current?.cannedAsk ?? "What do I keep avoiding saying out loud?"
    }

    static var current: ScreenshotScene? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ScreenshotMode"),
              let i = args.firstIndex(of: "-ScreenshotScene"), i + 1 < args.count
        else { return nil }
        return ScreenshotScene(rawValue: args[i + 1])
    }
}

/// A journal in another language for a localized screenshot run (1.14).
///
/// The English set is compiled in; the other languages are not, so a release
/// build carries no invented diaries in five languages. The run passes the
/// path of a JSON file on the Mac instead (`-ScreenshotSeedFile`), which a
/// simulator app can read directly. Like everything here it is inert without
/// `-ScreenshotMode`.
///
/// Each entry is stored with the seed's `locale` as its `transcriptLocale`,
/// exactly as a recogniser in that language would have left it, so the
/// language gate treats the journal the way it treats a real speaker's: the
/// features that cannot read the language stay quiet in the captures too.
struct ScreenshotSeed: Decodable {
    struct Entry: Decodable {
        let text: String
        let mood: String
        let daysAgo: Int
        let starred: Bool
        let duration: Double
    }

    let locale: String
    let cannedQuery: String
    let cannedAsk: String
    let cannedTyped: String
    let entries: [Entry]

    static let current: ScreenshotSeed? = {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ScreenshotMode"),
              let i = args.firstIndex(of: "-ScreenshotSeedFile"), i + 1 < args.count,
              let data = FileManager.default.contents(atPath: args[i + 1])
        else { return nil }
        return try? JSONDecoder().decode(ScreenshotSeed.self, from: data)
    }()
}
