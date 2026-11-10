package com.dailyvox.app.ui.nav

import androidx.annotation.StringRes
import com.dailyvox.app.R

/**
 * Four destinations: Speak · Journal · Twin · Ask — FINAL-SPEC §3.
 *
 * Insights is NOT a tab. It is a segment inside Twin, because it answers the
 * same question the Twin screen does ("what has it noticed about me?") and a
 * fifth tab pushed every label to the point of illegibility. An earlier build
 * promoted it to the bar to fix discoverability; the segment control solves
 * that without spending a slot.
 */
enum class Destination(@StringRes val label: Int, val route: String) {
    SPEAK(R.string.nav_speak, "speak"),
    JOURNAL(R.string.nav_journal, "journal"),
    TWIN(R.string.nav_twin, "twin"),
    ASK(R.string.nav_ask, "ask"),
}
