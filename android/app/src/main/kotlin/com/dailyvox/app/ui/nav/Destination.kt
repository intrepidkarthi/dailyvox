package com.dailyvox.app.ui.nav

/**
 * Four destinations: Speak · Journal · Twin · Ask — FINAL-SPEC §3.
 *
 * Insights is NOT a tab. It is a segment inside Twin, because it answers the
 * same question the Twin screen does ("what has it noticed about me?") and a
 * fifth tab pushed every label to the point of illegibility. An earlier build
 * promoted it to the bar to fix discoverability; the segment control solves
 * that without spending a slot.
 */
enum class Destination(val label: String, val route: String) {
    SPEAK("Speak", "speak"),
    JOURNAL("Journal", "journal"),
    TWIN("Twin", "twin"),
    ASK("Ask", "ask"),
}
