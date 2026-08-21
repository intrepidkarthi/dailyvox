//
//  SkyEncodingTests.swift
//  solynTests
//

import XCTest
import CoreGraphics
@testable import solyn

/// The sky's failure mode is that it still draws.
///
/// A wrong encoding produces a picture — a perfectly pleasant one — that simply
/// does not describe the journal. Nothing throws, nothing looks broken, and the
/// only way to notice is to already know where a star should have been. So the
/// rule gets pinned here.
final class SkyEncodingTests: XCTestCase {

    private let centre = CGPoint(x: 200, y: 200)
    private func date(_ iso: String) -> Date {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.date(from: iso)!
    }

    // MARK: - Distance is how long ago

    func testNewestSitsAtTheCore() {
        let span = SkyEncoding.Span(dates: [date("2026-01-01T12:00:00Z"),
                                            date("2026-08-01T12:00:00Z")])
        XCTAssertEqual(SkyEncoding.age(date("2026-08-01T12:00:00Z"), in: span), 0, accuracy: 0.001)
    }

    func testOldestSitsAtTheRim() {
        let span = SkyEncoding.Span(dates: [date("2026-01-01T12:00:00Z"),
                                            date("2026-08-01T12:00:00Z")])
        XCTAssertEqual(SkyEncoding.age(date("2026-01-01T12:00:00Z"), in: span), 1, accuracy: 0.001)
    }

    func testRadiusGrowsWithAge() {
        let near: CGFloat = 20, far: CGFloat = 100
        let recent = SkyEncoding.radius(age: 0.1, near: near, far: far)
        let old = SkyEncoding.radius(age: 0.9, near: near, far: far)
        XCTAssertLessThan(recent, old, "the sky must grow OUTWARD over time")
        XCTAssertGreaterThanOrEqual(recent, near)
        XCTAssertLessThanOrEqual(old, far)
    }

    /// A journal with one entry — or three in one sitting — has no span. Without
    /// the guard the normalisation divides by ~0 and every star flies to the rim.
    func testSingleSittingCollapsesToTheCore() {
        let t = date("2026-08-01T21:00:00Z")
        let span = SkyEncoding.Span(dates: [t, t.addingTimeInterval(30)])
        XCTAssertEqual(SkyEncoding.age(t, in: span), 0, accuracy: 0.001)
        XCTAssertEqual(SkyEncoding.age(t.addingTimeInterval(30), in: span), 0, accuracy: 0.001)
    }

    // MARK: - Angle is the hour

    func testMidnightIsAtTheTop() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let deg = SkyEncoding.degrees(for: date("2026-08-01T00:00:00Z"), calendar: cal)
        XCTAssertEqual(deg, -90, accuracy: 0.001, "midnight should point straight up")
    }

    func testNoonIsOpposite() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let deg = SkyEncoding.degrees(for: date("2026-08-01T12:00:00Z"), calendar: cal)
        XCTAssertEqual(deg, 90, accuracy: 0.001)
    }

    /// The same hour on different days must land on the same ray — that is the
    /// whole point of encoding the hour, and it is what makes a usual bedtime
    /// visible as a band.
    func testSameHourDifferentDaysShareARay() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let a = SkyEncoding.degrees(for: date("2026-08-01T21:00:00Z"), calendar: cal)
        let b = SkyEncoding.degrees(for: date("2026-03-14T21:00:00Z"), calendar: cal)
        XCTAssertEqual(a, b, accuracy: 0.001)
    }

    /// Without jitter, someone who always journals at 21:00 draws a spoke.
    func testJitterSpreadsAClusterButKeepsIt() {
        var cal = Calendar(identifier: .gregorian)
        cal.timeZone = TimeZone(identifier: "UTC")!
        let base = SkyEncoding.degrees(for: date("2026-08-01T21:00:00Z"), calendar: cal)
        for seed in [UInt64(1), 99, 12_345, 987_654_321] {
            let jittered = SkyEncoding.degrees(for: date("2026-08-01T21:00:00Z"),
                                               jitter: seed, calendar: cal)
            XCTAssertLessThanOrEqual(abs(jittered - base), 14.01,
                                     "jitter must stay inside ±14° or the cluster stops reading as one")
        }
    }

    // MARK: - Named people

    func testRecentlyMentionedSitsCloserThanFaded() {
        let span = SkyEncoding.Span(dates: [date("2026-01-01T12:00:00Z"),
                                            date("2026-08-01T12:00:00Z")])
        let recent = SkyEncoding.namedPoint(rank: 0, of: 2,
                                            lastSeen: date("2026-07-30T12:00:00Z"),
                                            in: span, centre: centre, near: 40, far: 120)
        let faded = SkyEncoding.namedPoint(rank: 0, of: 2,
                                           lastSeen: date("2026-02-01T12:00:00Z"),
                                           in: span, centre: centre, near: 40, far: 120)
        func dist(_ p: CGPoint) -> CGFloat {
            hypot(p.x - centre.x, p.y - centre.y)
        }
        XCTAssertLessThan(dist(recent), dist(faded),
                          "someone in your life this week must sit closer than someone who has faded")
    }

    /// A label is nudged out along its own spoke, so it has to agree with the
    /// star's angle exactly — this is the pair that silently drifted before.
    func testLabelAngleMatchesItsStar() {
        let span = SkyEncoding.Span(dates: [date("2026-01-01T12:00:00Z"),
                                            date("2026-08-01T12:00:00Z")])
        for rank in 0..<4 {
            let star = SkyEncoding.namedPoint(rank: rank, of: 4,
                                              lastSeen: date("2026-05-01T12:00:00Z"),
                                              in: span, centre: centre, near: 40, far: 120)
            let deg = SkyEncoding.namedDegrees(rank: rank, of: 4)
            let starAngle = atan2(star.y - centre.y, star.x - centre.x) * 180 / .pi
            let expected = deg.truncatingRemainder(dividingBy: 360)
            let delta = abs((starAngle - expected).truncatingRemainder(dividingBy: 360))
            XCTAssertTrue(delta < 0.01 || abs(delta - 360) < 0.01,
                          "rank \(rank): label spoke \(expected)° vs star \(starAngle)°")
        }
    }

    func testNamedPeopleDoNotShareASpoke() {
        var seen = Set<Int>()
        for rank in 0..<4 {
            let deg = Int(SkyEncoding.namedDegrees(rank: rank, of: 4).rounded())
            XCTAssertTrue(seen.insert(deg).inserted, "two people landed on the same ray")
        }
    }
}
