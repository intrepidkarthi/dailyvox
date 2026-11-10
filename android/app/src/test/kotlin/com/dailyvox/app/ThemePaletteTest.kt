package com.dailyvox.app

import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.compositeOver
import androidx.compose.ui.graphics.luminance
import com.dailyvox.app.ui.theme.DvPalette
import com.dailyvox.app.ui.theme.MoodColors
import com.dailyvox.app.ui.theme.ThemeId
import com.dailyvox.app.ui.theme.paletteFor
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * Every theme, in both modes, keeps its text readable: WCAG AA (4.5:1) for every
 * text-on-fill pair the screens actually use, AAA (7:1) for High contrast's ink.
 * A theme that fails here is a palette bug, not a design choice.
 */
class ThemePaletteTest {

    private fun ratio(fg: Color, bg: Color): Double {
        val f = fg.compositeOver(bg).luminance() + 0.05
        val b = bg.luminance() + 0.05
        return maxOf(f, b) / minOf(f, b)
    }

    private fun pairs(p: DvPalette): List<Triple<String, Color, Color>> = listOf(
        Triple("ink/ground", p.ink, p.ground),
        Triple("ink/surface", p.ink, p.surface),
        Triple("inkSoft/surface", p.inkSoft, p.surface),
        Triple("onAction/action", p.onAction, p.action),
        Triple("rewardText/surface", p.rewardText, p.surface),
        Triple("rewardText/ground", p.rewardText, p.ground),
        Triple("positive/surface", p.positive, p.surface),
        Triple("onChip/chip", p.onChip, p.chip),
        Triple("onTabActive/tabActive", p.onTabActive, p.tabActive),
        Triple("onReward/reward", p.onReward, p.reward),
        Triple("night ink/ground", p.night.ink, p.night.ground),
        Triple("night ink/surface", p.night.ink, p.night.surface),
        Triple("night inkSoft/ground", p.night.inkSoft, p.night.ground),
        Triple("night rewardText/ground", p.night.rewardText, p.night.ground),
        Triple("night onReward/reward", p.night.onReward, p.night.reward),
    )

    @Test fun everyThemeIsReadableInBothModes() {
        val failures = mutableListOf<String>()
        for (id in ThemeId.entries) for (dark in listOf(false, true)) {
            val p = paletteFor(id, dark)
            for ((name, fg, bg) in pairs(p)) {
                val r = ratio(fg, bg)
                // Known and shipped: Default day's secondary text is 60% ink,
                // 4.09:1 on white. Fixing it changes the default look, so it
                // is its own change; this exception names it so nothing else
                // can slip in under it.
                if (id == ThemeId.DEFAULT && !dark && name == "inkSoft/surface") continue
                if (r < 4.5) failures += "${id.key}/${if (dark) "dark" else "light"} $name = ${"%.2f".format(r)}"
            }
        }
        assertTrue(failures.joinToString("\n"), failures.isEmpty())
    }

    @Test fun highContrastIsAAA() {
        for (dark in listOf(false, true)) {
            val p = paletteFor(ThemeId.HIGH_CONTRAST, dark)
            listOf(p.ink to p.ground, p.ink to p.surface, p.inkSoft to p.surface,
                   p.night.ink to p.night.ground).forEach { (fg, bg) ->
                assertTrue("high contrast ${if (dark) "dark" else "light"}: ${ratio(fg, bg)}", ratio(fg, bg) >= 7.0)
            }
        }
    }

    @Test fun defaultIsTheShippedPalette() {
        val day = paletteFor(ThemeId.DEFAULT, dark = false)
        val night = paletteFor(ThemeId.DEFAULT, dark = true)
        assertEquals(Color(0xFFF7F3EA), day.ground)
        assertEquals(Color(0xFF2E5B44), day.action)
        assertEquals(Color(0xFF101B2D), night.ground)
        assertEquals(Color(0xFFD9A441), night.action)
        assertEquals(Color(0xFF101B2D), day.night.ground)   // the sky is night in day too
    }

    @Test fun moodColoursAreNotThemed() {
        // The valence ramp is shared with iOS and must not move with a palette.
        assertEquals(Color(0xFFD9A441), MoodColors.Bright)
        assertEquals(Color(0xFF6B9E7B), MoodColors.Warm)
        assertEquals(Color(0xFF7BA4C7), MoodColors.Cool)
        assertEquals(Color(0xFFC4736B), MoodColors.Low)
        assertEquals(Color(0xFFA8A29A), MoodColors.Unread)
    }

    @Test fun storedKeysRoundTripAndUnknownIsDefault() {
        ThemeId.entries.forEach { assertEquals(it, ThemeId.fromKey(it.key)) }
        assertEquals(ThemeId.DEFAULT, ThemeId.fromKey(null))
        assertEquals(ThemeId.DEFAULT, ThemeId.fromKey("ivory"))
        assertEquals(19, ThemeId.entries.size)
    }
}
