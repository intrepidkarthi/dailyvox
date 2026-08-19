//
//  WidgetPalette.swift
//  SolynWidget
//
//  The Evergreen tokens, for the widget/Live-Activity target.
//

import SwiftUI

/// A deliberate mirror of `DS.Palette`, not a second opinion.
///
/// The widget extension is its own target and does not compile the app's
/// `DesignSystem.swift`. Before this, each Live Activity carried its own hex
/// literals, which is how they ended up on the PREVIOUS gold (#D4A547) after
/// the app moved to #D9A441 — the surfaces most visible from the lock screen
/// were the last ones still wearing the old palette.
///
/// If a value changes in `DS.Palette` it must change here. That is the cost of
/// two targets; the alternative was every file inventing its own navy again.
enum WP {
    // Day — cream paper, forest ink.
    static let ink        = Color(red: 0.118, green: 0.165, blue: 0.149)   // #1E2A26
    static let inkSoft    = Color(red: 0.361, green: 0.416, blue: 0.392)   // #5C6A64
    static let cream      = Color(red: 0.969, green: 0.953, blue: 0.918)   // #F7F3EA

    /// GREEN ACTS.
    static let sage       = Color(red: 0.180, green: 0.357, blue: 0.267)   // #2E5B44

    /// GOLD REWARDS — stars, streaks, the things the user made.
    static let gold       = Color(red: 0.851, green: 0.643, blue: 0.255)   // #D9A441
    static let goldDay    = Color(red: 0.541, green: 0.416, blue: 0.122)   // #8A6A1F
    static let goldNight  = Color(red: 0.929, green: 0.796, blue: 0.525)   // #EDCB86

    /// NAVY IS SKY.
    static let navy       = Color(red: 0.063, green: 0.106, blue: 0.176)   // #101B2D
    static let navySurface = Color(red: 0.110, green: 0.165, blue: 0.259)  // #1C2A42
    static let navyText   = Color(red: 0.945, green: 0.929, blue: 0.886)   // #F1EDE2

    static let coral      = Color(red: 0.831, green: 0.310, blue: 0.271)   // #D44F45
}
