//
//  ShareCardTheme.swift
//  solyn
//
//  Shared palette for shareable social cards. Aligns the cards with the app's
//  Ivory theme (sage / gold / terracotta / coral) and the constellation
//  "inner sky" motif — a warm night sky with gold stars, not the previous
//  cold teal/purple-on-blue-black cosmic look.
//

import SwiftUI

enum ShareCardTheme {
    // Warm night-sky background (deep espresso/charcoal — warm, not cold blue-black)
    static let bgTop = Color(red: 0.118, green: 0.094, blue: 0.082)
    static let bgMid = Color(red: 0.157, green: 0.122, blue: 0.106)
    static let bgBottom = Color(red: 0.102, green: 0.082, blue: 0.075)

    // Brand accents (lightened for legibility on the dark card)
    static let gold = Color(red: 0.886, green: 0.706, blue: 0.345)        // constellation star gold
    static let sage = Color(red: 0.557, green: 0.698, blue: 0.604)        // sage green
    static let terracotta = Color(red: 0.847, green: 0.651, blue: 0.475)  // terracotta
    static let coral = Color(red: 0.894, green: 0.486, blue: 0.404)       // warm coral
    static let forest = Color(red: 0.502, green: 0.722, blue: 0.561)      // soft forest green
    static let amber = Color(red: 0.804, green: 0.659, blue: 0.420)       // muted amber

    // Warm card background gradient
    static let background = LinearGradient(
        colors: [bgTop, bgMid, bgBottom],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // Trait / progress bar fill — gold to sage
    static let barGradient = LinearGradient(
        colors: [gold, sage],
        startPoint: .leading,
        endPoint: .trailing
    )

    // Warm hairline border
    static let strokeGradient = LinearGradient(
        colors: [gold.opacity(0.30), terracotta.opacity(0.18)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}
