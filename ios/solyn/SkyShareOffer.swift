//
//  SkyShareOffer.swift
//  solyn
//
//  When the app offers, once, to make a picture of someone's sky.
//

import Foundation

/// "Share your sky, never your words."
///
/// At nights 7, 21 and 42 the Today screen offers — once each, ever — to turn
/// the constellation into a Story-sized card. The offer is a quiet card with
/// Share and Not now, never a sheet that blocks the screen, and the card it
/// offers carries no word anyone said.
///
/// The rule is pure so it can be pinned by tests; the storage around it is
/// three UserDefaults keys and nothing else.
///
/// ## The rule
///
/// - NIGHTS are distinct local days with at least one entry — `Streak`'s
///   `daysSpoken`, the same count the milestone card and the streak use, so the
///   offer can never say "seven nights" to someone the app elsewhere says has
///   kept six.
/// - It fires only when the count EQUALS a milestone, on the save that made it.
///   A journal restored from iCloud that lands at 30 nights is not offered 7
///   and 21 retroactively; someone who passed 21 last week is not chased.
/// - Each milestone at most once. It is marked offered the moment it is shown,
///   so killing the app with the card up does not bring it back.
/// - Never before onboarding has finished.
/// - Never when "Offer to share milestones" is off. It defaults on.
enum SkyShareOffer {

    static let nights = [7, 21, 42]

    /// The Settings toggle. Absent means on.
    static let enabledKey = "offerMilestoneShares"
    /// Milestones already offered, as a comma-separated list.
    static let offeredKey = "skyShareOfferedNights"
    /// Written by onboarding; read here, never written.
    static let onboardingKey = "hasCompletedOnboarding"

    // MARK: - The rule

    /// The milestone to offer after this save, or nil.
    static func nightToOffer(daysSpoken: Int,
                             alreadyOffered: Set<Int>,
                             enabled: Bool,
                             onboardingComplete: Bool) -> Int? {
        guard enabled, onboardingComplete else { return nil }
        guard nights.contains(daysSpoken), !alreadyOffered.contains(daysSpoken) else { return nil }
        return daysSpoken
    }

    /// Distinct local days spoken, by the streak's own day rule.
    static func daysSpoken(dates: [Date], now: Date = Date(),
                           calendar: Calendar = .current) -> Int {
        Streak.status(dates: dates, now: now, calendar: calendar).daysSpoken
    }

    // MARK: - Storage

    static func isEnabled(_ defaults: UserDefaults = .standard) -> Bool {
        defaults.object(forKey: enabledKey) as? Bool ?? true
    }

    static func offered(_ defaults: UserDefaults = .standard) -> Set<Int> {
        let raw = defaults.string(forKey: offeredKey) ?? ""
        return Set(raw.split(separator: ",").compactMap { Int($0) })
    }

    static func markOffered(_ night: Int, _ defaults: UserDefaults = .standard) {
        let all = offered(defaults).union([night]).sorted()
        defaults.set(all.map(String.init).joined(separator: ","), forKey: offeredKey)
    }

    /// The whole decision for one save: reads the setting, onboarding and what
    /// has been offered, and — if it returns a night — records it as offered.
    static func consume(dates: [Date], defaults: UserDefaults = .standard,
                        now: Date = Date(), calendar: Calendar = .current) -> Int? {
        let night = nightToOffer(
            daysSpoken: daysSpoken(dates: dates, now: now, calendar: calendar),
            alreadyOffered: offered(defaults),
            enabled: isEnabled(defaults),
            onboardingComplete: defaults.bool(forKey: onboardingKey))
        if let night { markOffered(night, defaults) }
        return night
    }

    // MARK: - Words

    /// The offer card's line. Calm, no exclamation marks, nothing to lose by
    /// saying no.
    static func headline(_ night: Int) -> String {
        switch night {
        case 7:
            return String(localized: "Seven nights. Your sky is taking shape \u{2014} share it?",
                          comment: "One-time offer to share a picture of the user's constellation after 7 nights of entries.")
        case 21:
            return String(localized: "Twenty-one nights. Your sky is filling in \u{2014} share it?",
                          comment: "One-time offer to share a picture of the user's constellation after 21 nights of entries.")
        case 42:
            return String(localized: "Forty-two nights. Your sky is its own now \u{2014} share it?",
                          comment: "One-time offer to share a picture of the user's constellation after 42 nights of entries.")
        default:
            return String(localized: "\(night) nights. Your sky is taking shape \u{2014} share it?",
                          comment: "One-time offer to share a picture of the user's constellation. The number is nights with at least one entry.")
        }
    }
}
