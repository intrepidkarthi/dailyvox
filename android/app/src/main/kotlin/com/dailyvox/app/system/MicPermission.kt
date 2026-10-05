package com.dailyvox.app.system

import android.Manifest
import android.app.Activity
import android.content.Context
import android.content.Intent
import android.content.pm.PackageManager
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.*
import androidx.compose.ui.platform.LocalContext
import androidx.core.app.ActivityCompat
import androidx.core.content.ContextCompat
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner

/**
 * The microphone permission, including the two states the screens did not model.
 *
 * Each screen used to hold `var granted by remember { checkSelfPermission(..) }`
 * and a launcher, and tapping the button when `!granted` simply re-launched the
 * request. That is correct exactly once. Two things break it, and both end with
 * a button that does nothing at all:
 *
 *   PERMANENTLY DENIED. From Android 11 a second denial is final, and the
 *   system stops showing the dialog -- `launch` returns immediately with a
 *   denial and nothing appears on screen. Every subsequent tap is a silent
 *   no-op, and the only route back is app settings, which nothing offered.
 *
 *   STALE AFTER SETTINGS. `remember` caches the answer for the life of the
 *   composition, so a user who granted the permission in Settings came back to
 *   a screen that still believed it was denied. Nothing re-read it, anywhere in
 *   the app.
 *
 * `shouldShowRequestPermissionRationale` cannot separate "never asked" from
 * "permanently denied" -- it is false for both -- so the fact that we asked is
 * recorded rather than inferred.
 */
class MicPermission internal constructor(
    val granted: Boolean,
    /**
     * Asked before, refused, and the system will not show the dialog again.
     *
     * Exposed rather than handled uniformly because the right response differs
     * by screen: the Speak button has to offer app settings, since recording is
     * the whole point and there is nothing else to do; onboarding has to walk
     * on past, because a first-run flow that traps someone on a screen they
     * cannot satisfy is worse than a journal with no microphone.
     */
    val permanentlyDenied: Boolean,
    private val onRequest: () -> Unit,
) {
    /** Ask, or send the user where asking is still possible. */
    fun request() = onRequest()
}

@Composable
fun rememberMicPermission(onResult: (Boolean) -> Unit = {}): MicPermission {
    val context = LocalContext.current
    val lifecycleOwner = LocalLifecycleOwner.current
    var granted by remember { mutableStateOf(context.hasMic()) }

    // Re-read on every return to the foreground. This is the half that makes
    // "Open settings" actually work: without it the user grants the permission,
    // comes back, and the button is still dead.
    DisposableEffect(lifecycleOwner) {
        val observer = LifecycleEventObserver { _, event ->
            if (event == Lifecycle.Event.ON_RESUME) granted = context.hasMic()
        }
        lifecycleOwner.lifecycle.addObserver(observer)
        onDispose { lifecycleOwner.lifecycle.removeObserver(observer) }
    }

    val latestOnResult by rememberUpdatedState(onResult)
    val ask = rememberLauncherForActivityResult(ActivityResultContracts.RequestPermission()) {
        granted = it
        latestOnResult(it)
    }

    val activity = context.findActivity()
    val asked = context.prefs().getBoolean(ASKED, false)
    val canPrompt = activity != null && ActivityCompat
        .shouldShowRequestPermissionRationale(activity, Manifest.permission.RECORD_AUDIO)

    return MicPermission(granted, permanentlyDenied = !granted && asked && !canPrompt) {
        if (!asked || canPrompt) {
            context.prefs().edit().putBoolean(ASKED, true).apply()
            ask.launch(Manifest.permission.RECORD_AUDIO)
        } else {
            // Asked before, and the system will no longer show the dialog.
            // Launching it again is the silent no-op; this is the only door left.
            context.startActivity(
                Intent(
                    Settings.ACTION_APPLICATION_DETAILS_SETTINGS,
                    Uri.fromParts("package", context.packageName, null),
                ).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK)
            )
        }
    }
}

/** True once the permission dialog has been shown, so a later denial is final. */
private const val ASKED = "mic_permission_asked"

private fun Context.prefs() = getSharedPreferences("dailyvox", Context.MODE_PRIVATE)

private fun Context.hasMic() =
    ContextCompat.checkSelfPermission(this, Manifest.permission.RECORD_AUDIO) ==
        PackageManager.PERMISSION_GRANTED

private tailrec fun Context.findActivity(): Activity? = when (this) {
    is Activity -> this
    is android.content.ContextWrapper -> baseContext.findActivity()
    else -> null
}
