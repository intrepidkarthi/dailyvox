package com.dailyvox.app.ui.theme

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider

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

/** Map a palette onto Material's roles. Green-acts / gold-rewards survives the
 *  mapping: the actor goes to primary, the reward only to secondary, so Material
 *  never hands gold to a component that asks for the action colour. Error stays
 *  the one fixed red: it is read as text ("Delete") and must not drift with a
 *  theme's paler recording disc. */
private fun DvPalette.toScheme() =
    if (isNight) darkColorScheme(
        primary = action, onPrimary = onAction,
        secondary = reward, onSecondary = ground,
        background = ground, onBackground = ink,
        surface = surface, onSurface = ink,
        surfaceVariant = chip, onSurfaceVariant = inkSoft,
        tertiary = positive,
        error = RecordRed,
    ) else lightColorScheme(
        primary = action, onPrimary = onAction,
        secondary = reward, onSecondary = ink,
        background = ground, onBackground = ink,
        surface = surface, onSurface = ink,
        surfaceVariant = chip, onSurfaceVariant = inkSoft,
        tertiary = positive,
        error = RecordRed,
    )

/**
 * The palette is provided as [LocalDvPalette] and mapped into MaterialTheme, so
 * screens can use either. Prefer the palette for anything the grammar names
 * (reward, night zone, record); Material for generic surfaces and text.
 */
@Composable
fun DailyVoxTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    themeId: ThemeId = ThemeId.DEFAULT,
    content: @Composable () -> Unit,
) {
    val palette = paletteFor(themeId, darkTheme)
    CompositionLocalProvider(LocalDvPalette provides palette, LocalThemeId provides themeId) {
        MaterialTheme(
            colorScheme = palette.toScheme(),
            typography = DailyVoxTypography,
            content = content,
        )
    }
}
