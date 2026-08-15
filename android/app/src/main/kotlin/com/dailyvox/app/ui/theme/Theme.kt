package com.dailyvox.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable

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

private val LightColors = lightColorScheme(
    primary = LightText,                 // ink is the primary action in Light
    onPrimary = LightBackground,
    secondary = LightAccent,
    background = LightBackground,
    onBackground = LightText,
    surface = LightSurface,
    onSurface = LightText,
    surfaceVariant = LightSurfaceVariant,
    onSurfaceVariant = LightTextSecondary,
    outline = LightOutline,
    // error is coral/terracotta, NOT Material red: on iOS this colour means
    // RECORDING, not failure, and that mapping is an authored decision
    // (ThemeManager.swift:142-147 refuses `.red` in a comment).
    error = LightAccentNegative,
)

private val DarkColors = darkColorScheme(
    primary = DarkAccent,                // amber is the primary action in Dark
    onPrimary = DarkBackground,
    secondary = DarkAccent,
    background = DarkBackground,
    onBackground = DarkText,
    surface = DarkSurface,
    onSurface = DarkText,
    surfaceVariant = DarkSurface,
    onSurfaceVariant = DarkTextSecondary,
    error = DarkAccentNegative,
)

@Composable
fun DailyVoxTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit,
) {
    MaterialTheme(
        colorScheme = if (darkTheme) DarkColors else LightColors,
        content = content,
    )
}
