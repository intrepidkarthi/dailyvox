package com.dailyvox.app.ui.components

import android.provider.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.remember
import androidx.compose.ui.platform.LocalContext

/**
 * Whether ambient animation should run — FINAL-SPEC §8.8.
 *
 * "Reduced-motion: replace flights/springs with fades; pause ambient sky/orbit
 * loops." Android has no `accessibilityReduceMotion` environment value the way
 * SwiftUI does; the platform signal is ANIMATOR_DURATION_SCALE, which the system
 * sets to 0 both when the user turns animations off in Developer options and
 * when Remove Animations is enabled in Accessibility.
 *
 * Read once per composition rather than observed: the setting changes about as
 * often as someone changes their wallpaper, and a ContentObserver on every
 * animated surface would cost more than it is worth.
 */
@Composable
fun reduceMotion(): Boolean {
    val context = LocalContext.current
    return remember {
        runCatching {
            Settings.Global.getFloat(
                context.contentResolver,
                Settings.Global.ANIMATOR_DURATION_SCALE,
                1f,
            ) == 0f
        }.getOrDefault(false)
    }
}
