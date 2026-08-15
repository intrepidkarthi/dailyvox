package com.dailyvox.app.system

import android.content.Context
import android.os.Build
import android.os.VibrationEffect
import android.os.Vibrator
import android.os.VibratorManager

/**
 * Haptics, mapped by MEANING rather than by number.
 *
 * iOS HapticManager uses ten graded intensities (0.4-0.8). Android's
 * HapticFeedbackConstants are action-based with no intensity parameter, so a
 * literal port is impossible; what transfers is the relative weight of each event.
 *
 * The trap this guards: a VibrationEffect composition plays NOTHING AT ALL if any
 * primitive in it is unsupported — it does not degrade, it silently vanishes. So
 * every composition is capability-checked and falls back to a plain one-shot,
 * or the streak celebration simply never fires on mid-range hardware.
 */
class Haptics(context: Context) {

    private val vibrator: Vibrator? = runCatching {
        if (Build.VERSION.SDK_INT >= 31) {
            (context.getSystemService(Context.VIBRATOR_MANAGER_SERVICE) as VibratorManager).defaultVibrator
        } else {
            @Suppress("DEPRECATION") context.getSystemService(Context.VIBRATOR_SERVICE) as Vibrator
        }
    }.getOrNull()

    private val hasAmplitude = vibrator?.hasAmplitudeControl() == true

    // Every call site is wrapped. Haptics are decoration; there is no failure
    // here worth taking the app down for, and a SecurityException from a missing
    // VIBRATE declaration already did exactly that once.
    private fun oneShot(ms: Long, amplitude: Int) {
        val v = vibrator ?: return
        runCatching {
            if (!v.hasVibrator()) return
            v.vibrate(
                if (hasAmplitude) VibrationEffect.createOneShot(ms, amplitude)
                else VibrationEffect.createOneShot(ms, VibrationEffect.DEFAULT_AMPLITUDE)
            )
        }
    }

    fun recordStart() = oneShot(18, 140)
    fun recordStop() = oneShot(26, 190)
    fun entrySaved() = oneShot(14, 110)
    fun selection() = oneShot(8, 70)
    fun deleted() = oneShot(34, 210)

    /** Two-beat celebration. Composed where supported, one-shot where not. */
    fun streakMilestone() {
        val v = vibrator ?: return
        runCatching {
        if (Build.VERSION.SDK_INT >= 30 &&
            v.areAllPrimitivesSupported(
                VibrationEffect.Composition.PRIMITIVE_TICK,
                VibrationEffect.Composition.PRIMITIVE_THUD,
            )
        ) {
            v.vibrate(
                VibrationEffect.startComposition()
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_TICK, 0.8f)
                    .addPrimitive(VibrationEffect.Composition.PRIMITIVE_THUD, 0.6f, 100)
                    .compose()
            )
        } else {
            oneShot(40, 200)
        }
        }
    }
}
