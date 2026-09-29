package com.dailyvox.app.ui.nav

import androidx.compose.animation.animateColorAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.layout.onGloballyPositioned
import androidx.compose.ui.layout.positionInParent
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import com.dailyvox.app.ui.theme.Gold
import com.dailyvox.app.ui.theme.NightBackground
import com.dailyvox.app.ui.theme.NightSurface
import com.dailyvox.app.ui.theme.NightText
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * The floating pill nav from the design package, not a stock NavigationBar.
 *
 * Stock M3 NavigationBar is edge-anchored, full-bleed and tonal. The design
 * specifies a FLOATING pill container with the active tab as a tinted pill --
 * that is brand, so it is authored rather than inherited.
 *
 * Accessibility is built in rather than retrofitted: 48dp minimum touch targets
 * (Play scans for this on every upload) and `selected` semantics with a Tab role,
 * so TalkBack announces state instead of just a label.
 */
@Composable
fun DailyVoxNavBar(
    /** True while the Twin tab is showing. The Twin screen is ALWAYS night
     *  (§8.4), and leaving a cream nav bar under a navy screen is what made it
     *  look broken rather than deliberate — the bar follows the screen. */
    night: Boolean = false,
    current: Destination,
    onSelect: (Destination) -> Unit,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    val context = androidx.compose.ui.platform.LocalContext.current
    val haptics = androidx.compose.runtime.remember { com.dailyvox.app.system.Haptics(context) }
    val density = androidx.compose.ui.platform.LocalDensity.current
    // Where each tab sits, so ONE indicator can travel between them. §4 asks
    // for the active pill to morph; four pills fading in and out in place is
    // a cross-fade, not a morph.
    val bounds = androidx.compose.runtime.remember { androidx.compose.runtime.mutableStateMapOf<Destination, Pair<Float, Float>>() }
    val target = bounds[current]
    val still = com.dailyvox.app.ui.components.reduceMotion()
    val springSpec = if (still) androidx.compose.animation.core.snap()
        else androidx.compose.animation.core.spring<androidx.compose.ui.unit.Dp>(dampingRatio = 0.8f, stiffness = 500f)
    val pillX by androidx.compose.animation.core.animateDpAsState(
        with(density) { (target?.first ?: 0f).toDp() }, springSpec, label = "pillX")
    val pillW by androidx.compose.animation.core.animateDpAsState(
        with(density) { (target?.second ?: 0f).toDp() }, springSpec, label = "pillW")
    val pillColor by animateColorAsState(if (night) Gold else scheme.primary, label = "pillColor")
    val shape = RoundedCornerShape(24.dp)

    // Centred and inset, then the pill wraps the row. Without fillMaxWidth the
    // Row wraps its content and Scaffold anchors it to the start, which left-
    // aligns the pill and clips it off the right edge -- caught on the emulator,
    // not in the source.
    Box(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            // Lifted off the page: a white bar on cream with no shadow barely
            // separated from the content scrolling under it (iOS: 12% shadow).
            .shadow(14.dp, shape, ambientColor = Color.Black.copy(alpha = 0.12f), spotColor = Color.Black.copy(alpha = 0.12f))
            .clip(shape)
            // Container is WHITE in day and #1C2A42 at night (§3).
            .background(if (night) NightSurface else scheme.surface)
            .padding(horizontal = 5.dp, vertical = 5.dp),
    ) {
        if (target != null) Box(
            Modifier
                .offset(x = pillX)
                .width(pillW)
                .height(48.dp)
                .align(Alignment.CenterStart)
                .clip(RoundedCornerShape(17.dp))
                .background(pillColor)
        )
        Row(
            Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Destination.entries.forEach { dest ->
                val selected = dest == current
                val labelColor by animateColorAsState(
                    when {
                        selected && night -> NightBackground
                        selected -> scheme.onPrimary
                        night -> NightText.copy(alpha = 0.6f)
                        else -> scheme.onSurfaceVariant
                    },
                    label = "navLabel",
                )
                Column(
                    modifier = Modifier
                        .onGloballyPositioned { c ->
                            bounds[dest] = c.positionInParent().x to c.size.width.toFloat()
                        }
                        .clip(RoundedCornerShape(17.dp))
                        .clickable(role = Role.Tab) {
                            if (!selected) haptics.selection()
                            onSelect(dest)
                        }
                        .semantics { this.selected = selected; this.role = Role.Tab }
                        .defaultMinSize(minWidth = 64.dp, minHeight = 48.dp)
                        .padding(horizontal = 12.dp, vertical = 6.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.Center,
                ) {
                    // LABELS ONLY -- the design's bar is four words in a pill,
                    // and iOS ships it that way. Nunito, heavier when active
                    // (ContentView.swift).
                    Text(
                        dest.label,
                        fontFamily = com.dailyvox.app.ui.theme.Nunito,
                        fontSize = 13.sp,
                        color = labelColor,
                        fontWeight = if (selected) androidx.compose.ui.text.font.FontWeight.ExtraBold
                            else androidx.compose.ui.text.font.FontWeight.Bold,
                    )
                }
            }
        }
    }
}
