package com.dailyvox.app.ui.components

import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.ui.text.input.PlatformImeOptions

/**
 * Keyboard options for every text field in the app: no voice-typing key.
 *
 * The keyboard's own mic (Gboard's, on most phones) is Google's dictation,
 * which may transcribe on a server. It is the same leak as the speech network
 * fallback and the old voice-search intent, arriving through the one door the
 * app does not own. `nm` and `noMicrophoneKey` are the private IME options Gboard
 * reads to hide that key; other keyboards ignore them, harmlessly. DailyVox's
 * own mic buttons, which stay on the device, are the way to speak into it.
 */
val PrivateKeyboard = KeyboardOptions(
    platformImeOptions = PlatformImeOptions("nm,com.google.android.inputmethod.latin.noMicrophoneKey"),
)
