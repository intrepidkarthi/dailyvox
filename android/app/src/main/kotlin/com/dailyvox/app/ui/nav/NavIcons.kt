package com.dailyvox.app.ui.nav

import androidx.compose.foundation.layout.size
import androidx.compose.material3.Icon
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.res.painterResource
import androidx.compose.ui.unit.dp
import com.dailyvox.app.R

/**
 * Material Symbols Rounded (Apache-2.0), shipped as vector drawables.
 *
 * These replace hand-drawn Canvas paths, which looked exactly as crude as they
 * were: icon design at 20dp is a craft, and approximating it in a few drawCircle
 * calls does not survive contact with a real screen. Rounded is the variant that
 * sits with Nunito rather than fighting it.
 *
 * `androidx.compose.material.icons` is discontinued and no longer a transitive
 * dependency of material3, so these are vendored as assets rather than pulled
 * from a library — which also means they cannot change under us on a version bump.
 */
@Composable
fun NavIcon(dest: Destination, active: Boolean, tint: Color, size: Int = 22) {
    val res = when (dest) {
        Destination.SPEAK -> R.drawable.ic_nav_speak
        Destination.JOURNAL -> R.drawable.ic_nav_journal
        Destination.TWIN -> R.drawable.ic_nav_twin
        Destination.INSIGHTS -> R.drawable.ic_nav_insights
        Destination.ASK -> R.drawable.ic_nav_ask
    }
    Icon(
        painter = painterResource(res),
        contentDescription = null,   // the label beneath carries the name
        tint = tint,
        modifier = Modifier.size(size.dp),
    )
}
