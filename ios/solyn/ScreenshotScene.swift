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

    /// A canned query, so the search and Ask frames show a real answer rather
    /// than an empty field. Deliberately a sentence — the semantic index ranks
    /// short keyword queries poorly, and the store frame should show the
    /// feature working the way the UI asks you to use it.
    static let cannedQuery = "a quiet moment that made me feel grounded"

    static var current: ScreenshotScene? {
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("-ScreenshotMode"),
              let i = args.firstIndex(of: "-ScreenshotScene"), i + 1 < args.count
        else { return nil }
        return ScreenshotScene(rawValue: args[i + 1])
    }
}
