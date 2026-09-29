package com.dailyvox.app.ui.theme

import androidx.compose.material3.Typography
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontVariation
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.sp
import com.dailyvox.app.R

/**
 * Three faces, bundled — never falling back to Roboto.
 *
 * Nunito carries the brand. It is already the website's display face, which is
 * the same brand-by-demonstration test that settled the palette: an element that
 * already survived a jump to a non-Apple surface is brand, not iOS convention.
 * SF Rounded was only ever the iOS instantiation of "soft warm geometric-rounded
 * display at bold".
 *
 * All three are OFL and bundled rather than downloaded, because a journal that
 * works in airplane mode cannot have its typography depend on a network fetch.
 *
 * Stable M3 Typography has no defaultFontFamily, so every style is written out.
 * That is not boilerplate for its own sake -- it is the only way to give body and
 * display different families, which is the whole point of the pairing.
 */
/**
 * One Font per weight, each pinning the variable font's `wght` axis.
 *
 * `Font(resId, weight)` alone only TELLS the matcher which weight this entry
 * serves -- it does not move the axis, so every entry rendered the file's
 * default instance: Nunito at 200 (ExtraLight, a hairline) and Inter at 400.
 * Every "Bold" title in the app was drawn at the thinnest weight the font has.
 * iOS hit the same trap and fixed it in DVFont.swift.
 */
@OptIn(androidx.compose.ui.text.ExperimentalTextApi::class)
private fun variable(res: Int, vararg weights: Int) = FontFamily(
    weights.map { w ->
        Font(res, FontWeight(w), variationSettings = FontVariation.Settings(FontVariation.weight(w)))
    }
)

val Nunito = variable(R.font.nunito_variable, 400, 500, 600, 700, 800, 900)

val Inter = variable(R.font.inter_variable, 400, 500, 600, 700)

val DmMono = FontFamily(Font(R.font.dm_mono_medium, FontWeight.Medium))

val DailyVoxTypography = Typography(
    displayLarge = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.ExtraBold, fontSize = 34.sp, lineHeight = 40.sp),
    displayMedium = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.ExtraBold, fontSize = 30.sp, lineHeight = 36.sp),
    displaySmall = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.Bold, fontSize = 26.sp, lineHeight = 32.sp),
    headlineLarge = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.ExtraBold, fontSize = 30.sp, lineHeight = 37.sp),
    headlineMedium = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.Bold, fontSize = 26.sp, lineHeight = 32.sp),
    headlineSmall = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.Bold, fontSize = 21.sp, lineHeight = 27.sp),
    titleLarge = TextStyle(fontFamily = Nunito, fontWeight = FontWeight.Bold, fontSize = 20.sp, lineHeight = 26.sp),
    titleMedium = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 16.sp, lineHeight = 22.sp),
    titleSmall = TextStyle(fontFamily = Inter, fontWeight = FontWeight.SemiBold, fontSize = 14.sp, lineHeight = 20.sp),
    bodyLarge = TextStyle(fontFamily = Inter, fontSize = 16.sp, lineHeight = 26.sp),
    bodyMedium = TextStyle(fontFamily = Inter, fontSize = 15.sp, lineHeight = 24.sp),
    bodySmall = TextStyle(fontFamily = Inter, fontSize = 13.sp, lineHeight = 20.sp),
    labelLarge = TextStyle(fontFamily = Inter, fontWeight = FontWeight.Medium, fontSize = 14.sp),
    labelMedium = TextStyle(fontFamily = DmMono, fontWeight = FontWeight.Medium, fontSize = 11.sp, letterSpacing = 1.1.sp),
    labelSmall = TextStyle(fontFamily = DmMono, fontWeight = FontWeight.Medium, fontSize = 10.sp, letterSpacing = 1.2.sp),
)
