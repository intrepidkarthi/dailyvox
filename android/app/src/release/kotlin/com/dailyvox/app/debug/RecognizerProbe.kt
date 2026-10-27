package com.dailyvox.app.debug

import androidx.compose.runtime.Composable

/**
 * Release stub. The recogniser probe (multilingual plan B-17) exists only in
 * src/debug; a release build compiles this empty card and nothing else, so no
 * probe code, strings or Settings row can reach the Play build.
 */
object RecognizerProbe {
    @Composable
    fun Card() = Unit
}
