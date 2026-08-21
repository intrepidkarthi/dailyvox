//
//  SkyEncoding.swift
//  solyn
//
//  Where a star goes, and why. One definition, four call sites.
//

import Foundation
import CoreGraphics

/// The rule that turns a journal into a picture.
///
/// This exists because the rule was written **four times**: entry placement in
/// `SkyView.place`, again in `Shareables.drawTonight`; named-star placement in
/// `SkyView.draw`, again in `SkyView.labels`. They agreed on the day they were
/// written and would not have agreed for long — and the failure is silent. A
/// label drifts off its star; the share card stops matching the app; nobody sees
/// an error, the picture is just quietly wrong.
///
/// ## The encoding
///
///   DISTANCE from the core  = how long ago. Tonight sits closest; the first
///                             entry sits at the rim, so the sky grows outward
///                             and a long journal LOOKS like a long journal.
///   ANGLE around the core   = time of day, midnight at the top, clockwise. A
///                             usual hour becomes a visible band; a 3am entry
///                             sits alone, opposite.
///   SIZE                    = how long you spoke (callers apply this).
///   COLOUR                  = valence (callers apply this).
///
/// For a named person, distance is when they last came up and size is how often,
/// so the people currently in someone's life are close and bright and the ones
/// who have faded have drifted out.
enum SkyEncoding {

    /// Oldest and newest, for normalising age.
    struct Span {
        let oldest: Date
        let newest: Date

        init(dates: [Date]) {
            let newest = dates.max() ?? Date()
            self.newest = newest
            self.oldest = dates.min() ?? newest.addingTimeInterval(-86_400)
        }
    }

    /// 0 for the newest thing in the journal, 1 for the oldest.
    ///
    /// Guarded at a minute: a journal with one entry, or several in the same
    /// sitting, has no meaningful span and everything should sit at the centre
    /// rather than divide by ~0 and fly to the rim.
    static func age(_ date: Date, in span: Span) -> Double {
        let total = span.newest.timeIntervalSince(span.oldest)
        guard total > 60 else { return 0 }
        return min(max(span.newest.timeIntervalSince(date) / total, 0), 1)
    }

    /// Radius for a given age, eased so the inner rings do not crowd.
    ///
    /// A linear ramp puts too many recent stars on a small circumference; the
    /// 0.75 power spreads them without losing the "recent is close" reading.
    static func radius(age: Double, near: CGFloat, far: CGFloat) -> CGFloat {
        near + (far - near) * CGFloat(pow(age, 0.75))
    }

    /// Degrees for the hour something happened. Midnight at the top, clockwise.
    ///
    /// `jitter` spreads a cluster across ±14°. Without it someone who always
    /// journals at 21:00 draws every star on one exact ray — a spoke, not a sky.
    /// Fourteen degrees keeps the cluster obviously a cluster while letting it
    /// read as a constellation.
    static func degrees(for date: Date, jitter: UInt64 = 0,
                        calendar: Calendar = .current) -> Double {
        let h = Double(calendar.component(.hour, from: date))
        let m = Double(calendar.component(.minute, from: date))
        let dayFraction = (h + m / 60) / 24
        var degrees = dayFraction * 360 - 90
        if jitter != 0 {
            degrees += (Double(jitter % 2800) / 100) - 14
        }
        return degrees
    }

    /// Where one entry sits.
    static func entryPoint(date: Date, in span: Span, jitter: UInt64,
                           centre: CGPoint, near: CGFloat, far: CGFloat,
                           calendar: Calendar = .current) -> CGPoint {
        let r = radius(age: age(date, in: span), near: near, far: far)
        return point(centre: centre, radius: r,
                     degrees: degrees(for: date, jitter: jitter, calendar: calendar))
    }

    /// Where a named person sits.
    ///
    /// Angle comes from rank rather than from time: people are not events, and
    /// spreading them evenly keeps them off each other and off the entry bands.
    static func namedPoint(rank: Int, of total: Int, lastSeen: Date, in span: Span,
                           centre: CGPoint, near: CGFloat, far: CGFloat) -> CGPoint {
        let step = 360.0 / Double(max(total, 1))
        let deg = -60.0 + Double(rank) * step
        // A gentler ease than entries use: four points, so crowding is not the
        // risk — losing the recency reading at the near end is.
        let a = age(lastSeen, in: span)
        let r = near + (far - near) * CGFloat(pow(a, 0.7))
        return point(centre: centre, radius: r, degrees: deg)
    }

    /// The angle a named star sits at, for anything that needs to nudge outward
    /// from it — a label, for instance.
    static func namedDegrees(rank: Int, of total: Int) -> Double {
        -60.0 + Double(rank) * (360.0 / Double(max(total, 1)))
    }

    static func point(centre: CGPoint, radius: CGFloat, degrees: Double) -> CGPoint {
        let rad = degrees * .pi / 180
        return CGPoint(x: centre.x + radius * CGFloat(cos(rad)),
                       y: centre.y + radius * CGFloat(sin(rad)))
    }
}
