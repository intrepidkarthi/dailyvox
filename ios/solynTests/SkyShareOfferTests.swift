//
//  SkyShareOfferTests.swift
//  solynTests
//

import XCTest
@testable import solyn

/// The offer at nights 7, 21 and 42 is a growth surface sitting inside a
/// journal, so the ways it can go wrong are all ways of nagging: firing twice,
/// firing for a restored journal, firing during onboarding, firing after the
/// user said no in Settings. Each is pinned here.
final class SkyShareOfferTests: XCTestCase {

    private var defaults: UserDefaults!
    private var suite: String!

    private let kolkata: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "Asia/Kolkata")!
        return c
    }()

    /// 2025-08-22 12:00 UTC.
    private let now = Date(timeIntervalSince1970: 1_755_864_000)

    override func setUp() {
        super.setUp()
        suite = "SkyShareOfferTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suite)
        defaults.set(true, forKey: SkyShareOffer.onboardingKey)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// One entry a day for `n` consecutive days ending today, at 21:00 local.
    private func nights(_ n: Int, perNight: Int = 1) -> [Date] {
        let today = kolkata.startOfDay(for: now)
        return (0..<n).flatMap { back -> [Date] in
            let day = kolkata.date(byAdding: .day, value: -back, to: today)!
            return (0..<perNight).map { day.addingTimeInterval(21 * 3_600 + Double($0) * 60) }
        }
    }

    private func consume(_ dates: [Date]) -> Int? {
        SkyShareOffer.consume(dates: dates, defaults: defaults, now: now, calendar: kolkata)
    }

    // MARK: - The pure rule

    func testOffersExactlyAtSevenTwentyOneFortyTwo() {
        for n in 0...60 {
            let got = SkyShareOffer.nightToOffer(daysSpoken: n, alreadyOffered: [],
                                                 enabled: true, onboardingComplete: true)
            XCTAssertEqual(got, [7, 21, 42].contains(n) ? n : nil, "night \(n)")
        }
    }

    func testNeverTwiceForTheSameNight() {
        XCTAssertNil(SkyShareOffer.nightToOffer(daysSpoken: 7, alreadyOffered: [7],
                                                enabled: true, onboardingComplete: true))
        XCTAssertEqual(SkyShareOffer.nightToOffer(daysSpoken: 21, alreadyOffered: [7],
                                                  enabled: true, onboardingComplete: true), 21)
    }

    func testSettingOffSuppressesEveryNight() {
        for n in SkyShareOffer.nights {
            XCTAssertNil(SkyShareOffer.nightToOffer(daysSpoken: n, alreadyOffered: [],
                                                    enabled: false, onboardingComplete: true))
        }
    }

    func testNeverDuringOnboarding() {
        for n in SkyShareOffer.nights {
            XCTAssertNil(SkyShareOffer.nightToOffer(daysSpoken: n, alreadyOffered: [],
                                                    enabled: true, onboardingComplete: false))
        }
    }

    // MARK: - Counting nights

    func testTwoEntriesOnOneNightAreOneNight() {
        XCTAssertEqual(SkyShareOffer.daysSpoken(dates: nights(7, perNight: 3),
                                                now: now, calendar: kolkata), 7)
    }

    /// 23:30 and 00:30 local are two nights even though they are an hour apart
    /// — and in UTC they would be the SAME day for Kolkata (+05:30). The count
    /// is local days, the same as the streak's.
    func testCountsLocalDaysNotUTCDays() {
        let today = kolkata.startOfDay(for: now)
        let lateYesterday = today.addingTimeInterval(-30 * 60)       // 23:30 yesterday
        let earlyToday = today.addingTimeInterval(30 * 60)           // 00:30 today
        XCTAssertEqual(SkyShareOffer.daysSpoken(dates: [lateYesterday, earlyToday],
                                                now: now, calendar: kolkata), 2)
    }

    func testMatchesTheStreakCount() {
        let dates = nights(21) + nights(3, perNight: 2)
        XCTAssertEqual(SkyShareOffer.daysSpoken(dates: dates, now: now, calendar: kolkata),
                       Streak.status(dates: dates, now: now, calendar: kolkata).daysSpoken)
    }

    // MARK: - End to end through storage

    func testEachMilestoneFiresOnceEver() {
        var fired: [Int] = []
        for n in 1...50 {
            // Two saves on the milestone night: the second must not re-offer.
            if let got = consume(nights(n)) { fired.append(got) }
            if let got = consume(nights(n, perNight: 2)) { fired.append(got) }
        }
        XCTAssertEqual(fired, [7, 21, 42])
        // And again from the top, as after a relaunch: nothing.
        for n in SkyShareOffer.nights { XCTAssertNil(consume(nights(n))) }
    }

    func testDefaultsToOnWhenNeverSet() {
        XCTAssertNil(defaults.object(forKey: SkyShareOffer.enabledKey))
        XCTAssertTrue(SkyShareOffer.isEnabled(defaults))
        XCTAssertEqual(consume(nights(7)), 7)
    }

    func testSettingOffEndToEnd() {
        defaults.set(false, forKey: SkyShareOffer.enabledKey)
        XCTAssertNil(consume(nights(7)))
        // Not marked offered while off, so turning it back on before night 21
        // still gets 21.
        XCTAssertFalse(SkyShareOffer.offered(defaults).contains(7))
        defaults.set(true, forKey: SkyShareOffer.enabledKey)
        XCTAssertEqual(consume(nights(21)), 21)
    }

    func testOnboardingNotFinishedEndToEnd() {
        defaults.set(false, forKey: SkyShareOffer.onboardingKey)
        XCTAssertNil(consume(nights(7)))
        defaults.removeObject(forKey: SkyShareOffer.onboardingKey)
        XCTAssertNil(consume(nights(7)))
    }

    func testJournalThatJumpsPastAMilestoneIsNotChased() {
        // A restore that lands at 30 nights: nothing now, and 42 still later.
        XCTAssertNil(consume(nights(30)))
        XCTAssertEqual(consume(nights(42)), 42)
    }

    func testHeadlineForSevenIsTheCalmOne() {
        XCTAssertEqual(SkyShareOffer.headline(7),
                       "Seven nights. Your sky is taking shape \u{2014} share it?")
    }
}
