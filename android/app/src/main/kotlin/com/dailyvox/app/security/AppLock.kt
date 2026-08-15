package com.dailyvox.app.security

import androidx.biometric.BiometricManager
import androidx.biometric.BiometricManager.Authenticators.BIOMETRIC_STRONG
import androidx.biometric.BiometricManager.Authenticators.DEVICE_CREDENTIAL
import androidx.biometric.BiometricPrompt
import androidx.fragment.app.FragmentActivity

/**
 * App lock via BiometricPrompt.
 *
 * This is the one place Android is arguably STRONGER than the iOS original. On
 * iOS, AppLockManager hand-rolls a ladder: try Face ID, catch the failure, fall
 * back to the passcode, handle each error case. Here that whole ladder collapses
 * into one setAllowedAuthenticators call — the system handles biometric, then
 * device credential, then lockout, with no branching on our side.
 *
 * The trap, and it is easy to hit: setNegativeButtonText() CANNOT be combined
 * with DEVICE_CREDENTIAL. Setting both throws at runtime rather than at compile
 * time, so the cancel affordance is deliberately absent — the device credential
 * screen provides its own.
 */
object AppLock {

    private const val AUTHENTICATORS = BIOMETRIC_STRONG or DEVICE_CREDENTIAL

    /** True when the device can actually lock — no point offering a toggle that does nothing. */
    fun available(activity: FragmentActivity): Boolean =
        BiometricManager.from(activity).canAuthenticate(AUTHENTICATORS) ==
            BiometricManager.BIOMETRIC_SUCCESS

    fun prompt(activity: FragmentActivity, onSuccess: () -> Unit, onFail: () -> Unit = {}) {
        val prompt = BiometricPrompt(
            activity,
            androidx.core.content.ContextCompat.getMainExecutor(activity),
            object : BiometricPrompt.AuthenticationCallback() {
                override fun onAuthenticationSucceeded(result: BiometricPrompt.AuthenticationResult) = onSuccess()
                override fun onAuthenticationError(code: Int, msg: CharSequence) = onFail()
            },
        )
        prompt.authenticate(
            BiometricPrompt.PromptInfo.Builder()
                .setTitle("Unlock DailyVox")
                .setSubtitle("Your journal is locked on this device")
                .setAllowedAuthenticators(AUTHENTICATORS)
                // No setNegativeButtonText: illegal with DEVICE_CREDENTIAL.
                .build()
        )
    }
}
