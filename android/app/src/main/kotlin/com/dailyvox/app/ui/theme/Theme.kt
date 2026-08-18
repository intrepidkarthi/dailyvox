package com.dailyvox.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Color

// Dynamic colour is deliberately absent, not forgotten.
//
// Material is explicit that dynamic colour is replace-everything -- "the actual
// colors may change, the color role mappings remain the same" -- so there is no
// setting where it leaves the brand hues alone. The design spec reaches the same
// conclusion independently: "Dynamic colour: off by default; opt-in accent only,
// never applied to the constellation."
//
// When the opt-in ships it belongs behind a user preference, and it must never
// reach the sky.

// Day: green acts. Gold is NOT mapped to primary here on purpose — mapping it
// would let Material hand gold to any component that asks for the action colour,
// and the grammar says gold is only ever for what the user made.
private val DayColors = lightColorScheme(
    primary = DayAction,
    onPrimary = DayOnAction,
    secondary = Gold,                    // rewards: stars, streaks, insights
    onSecondary = DayText,
    background = DayBackground,
    onBackground = DayText,
    surface = DaySurface,
    onSurface = DayText,
    surfaceVariant = DayGreenTint,
    onSurfaceVariant = DayTextSecondary,
    tertiary = DayPositive,
    // Recording is the only red in the product, and it means RECORDING rather
    // than failure — the design draws "Stop & keep" as a red disc.
    error = Color(0xFFC5533F),
)

// Night: gold acts, by the one documented exception in the grammar. Green has
// no presence on navy, so the actor role moves rather than the rule bending.
private val NightColors = darkColorScheme(
    primary = NightAction,
    onPrimary = NightOnAction,
    secondary = Gold,
    onSecondary = NightBackground,
    background = NightBackground,
    onBackground = NightText,
    surface = NightSurface,
    onSurface = NightText,
    surfaceVariant = NightSurface,
    onSurfaceVariant = NightTextSecondary,
    tertiary = NightPositive,
    error = Color(0xFFC5533F),
)

@Composable
fun DailyVoxTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) NightColors else DayColors,
        typography = DailyVoxTypography,
        content = content,
    )
}
