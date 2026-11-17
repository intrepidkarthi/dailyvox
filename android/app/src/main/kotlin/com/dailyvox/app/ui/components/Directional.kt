package com.dailyvox.app.ui.components

import androidx.compose.runtime.Composable
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.style.TextDirection
import androidx.compose.ui.unit.LayoutDirection

/**
 * Back and forward chevrons that point the right way in a right-to-left UI
 * (plan B-16, Android half).
 *
 * The app draws them as text, "‹" and "›". Those two characters are
 * Bidi_Mirrored, so in an RTL paragraph the renderer flips them -- which means
 * 1.2 happened to be right in Arabic or Hebrew, but only by an accident of
 * paragraph direction: a "‹" that ended up in an LTR run beside Latin text
 * would point the wrong way, and one in an RTL run would be flipped AGAIN by
 * anyone who "fixed" it by swapping the glyph.
 *
 * So the choice is made once, explicitly, from the layout direction, and the
 * glyph is drawn in a forced-LTR paragraph ([GlyphStyle]) so nothing mirrors it
 * a second time. In LTR this is exactly 1.2's "‹" and "›".
 */
object Directional {
    private const val LEFT = "‹"
    private const val RIGHT = "›"

    /** Points toward where you came from: left in LTR, right in RTL. */
    fun back(rtl: Boolean): String = if (rtl) RIGHT else LEFT

    /** Points onward: right in LTR, left in RTL. */
    fun forward(rtl: Boolean): String = if (rtl) LEFT else RIGHT

    /** Draw the chosen glyph as-is; never let bidi mirroring flip it again. */
    val GlyphStyle = TextStyle(textDirection = TextDirection.Ltr)
}

@Composable
fun backGlyph(): String = Directional.back(LocalLayoutDirection.current == LayoutDirection.Rtl)

@Composable
fun forwardGlyph(): String = Directional.forward(LocalLayoutDirection.current == LayoutDirection.Rtl)
