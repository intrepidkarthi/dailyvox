package com.dailyvox.app.ui.theme

import androidx.compose.ui.graphics.Color

/**
 * "Evergreen & Gold Hour" — research/design/final/FINAL-SPEC.md §1.
 *
 * Replaces the earlier ink/amber tokens wholesale. The colour grammar is the
 * point and it is strict:
 *
 *     GREEN ACTS.    Record, send, save, confirm. Never decoration.
 *     GOLD REWARDS.  Stars, streaks, insights, the Twin — what the user made.
 *     NAVY IS SKY.   The Twin screen and the night theme. Always night.
 *     CREAM IS PAPER. Day surfaces. Nothing else gets colour.
 *
 * Never swap green and gold. The one exception is written into the spec: at
 * night gold becomes the actor, because green on navy has no presence.
 *
 * No pure black and no pure white text, anywhere.
 */

// ── Day: cream paper + forest green ─────────────────────────────────────────
val DayBackground     = Color(0xFFF7F3EA)
val DaySurface        = Color(0xFFFFFFFF)
val DayText           = Color(0xFF1E2A26)
val DayTextSecondary  = Color(0x991E2A26)   // 60%
val DayAction         = Color(0xFF2E5B44)   // forest green — ACTIONS ONLY
val DayOnAction       = Color(0xFFF7F3EA)
val DayPositive       = Color(0xFF4A7C59)
val DayGreenTint      = Color(0xFFE4EDE4)   // chips
/** Gold on cream is decorative; gold TEXT on cream must use this for AA. */
val DayGoldText       = Color(0xFF8A6A1F)
val DayGoldTint       = Color(0xFFF3E7CD)

// ── Night: navy sky + gold ──────────────────────────────────────────────────
val NightBackground    = Color(0xFF101B2D)
val NightSurface       = Color(0xFF1C2A42)   // tonal, no border
val NightText          = Color(0xFFF1EDE2)
val NightTextSecondary = Color(0x99F1EDE2)   // 60%
val NightAction        = Color(0xFFD9A441)   // gold is the actor at night
val NightOnAction      = Color(0xFF101B2D)
val NightPositive      = Color(0xFF8FBF77)
val NightGoldText      = Color(0xFFEDCB86)
val NightGoldTint      = Color(0x29D9A441)   // 16%

// ── Shared ──────────────────────────────────────────────────────────────────
/** The one gold. Stars, streaks, ticks, anything the user made. */
val Gold        = Color(0xFFD9A441)
/** Constellation only — never UI chrome. */
val StarBlue    = Color(0xFF9DC1E4)
val StarGold    = Gold

/** The Twin screen renders night tokens under BOTH themes: the sky is always
 *  night (FINAL-SPEC §8.4). */
val SkyBackground = NightBackground
val SkySurface    = NightSurface
