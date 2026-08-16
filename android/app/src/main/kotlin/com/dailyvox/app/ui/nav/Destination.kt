package com.dailyvox.app.ui.nav

/**
 * Five destinations: Speak · Journal · Twin · Insights · Ask.
 *
 * The design package (system 3a) drew four, promoting Ask to the bar and moving
 * Insights off it. That was followed literally at first and it was wrong in
 * practice: with Insights off the bar its only route was the "6% resolved" badge
 * on Speak, so an entire screen — streaks, the thirty-night strip, the mood
 * curve, the patterns — lived behind a percentage that does not look like a
 * button. iOS gives Insights a tab (ContentView.swift:49) and that is the call
 * being matched here.
 *
 * Settings stays off the bar, and that IS the design followed rather than
 * overruled: iOS spends a fifth tab on it, but on Android an overflow control in
 * the header is where people look for settings, and spending a nav slot on a
 * screen visited twice a year would cost Insights its place again.
 */
enum class Destination(val label: String, val route: String) {
    SPEAK("Speak", "speak"),
    JOURNAL("Journal", "journal"),
    TWIN("Twin", "twin"),
    INSIGHTS("Insights", "insights"),
    ASK("Ask", "ask"),
}
