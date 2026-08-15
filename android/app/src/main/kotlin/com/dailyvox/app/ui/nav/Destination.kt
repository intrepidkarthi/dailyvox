package com.dailyvox.app.ui.nav

/**
 * Four destinations, per the design package (system 3a): Speak · Journal · Twin · Ask.
 *
 * This is NOT the iOS set. iOS ships five tabs (Record/Journal/Twin/Insights/Settings,
 * ContentView.swift:24-59); the Android design promotes Ask to the bar and moves
 * Insights and Settings off it. Following the design package deliberately -- the
 * decision is recorded rather than drifted into.
 */
enum class Destination(val label: String, val route: String) {
    SPEAK("Speak", "speak"),
    JOURNAL("Journal", "journal"),
    TWIN("Twin", "twin"),
    ASK("Ask", "ask"),
}
