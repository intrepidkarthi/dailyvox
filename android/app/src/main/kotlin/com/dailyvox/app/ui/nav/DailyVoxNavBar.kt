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
    // Centred and inset, then the pill wraps the row. Without fillMaxWidth the
    // Row wraps its content and Scaffold anchors it to the start, which left-
    // aligns the pill and clips it off the right edge -- caught on the emulator,
    // not in the source.
    Row(
        modifier = modifier
            .fillMaxWidth()
            .navigationBarsPadding()
            .padding(horizontal = 16.dp, vertical = 12.dp)
            .clip(RoundedCornerShape(24.dp))
            // Container is WHITE in day and #1C2A42 at night (§3). It was the
            // green chip tint, which is why the bar read as a different app
            // from everything above it: nothing else on a day screen is green
            // except the one thing you are meant to press.
            .background(if (night) NightSurface else scheme.surface)
            .padding(horizontal = 5.dp, vertical = 5.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Destination.entries.forEach { dest ->
            val selected = dest == current
            // .22 in Dark, .14 in Light -- the design spec's tint values.
            val tint by animateColorAsState(
                // FINAL-SPEC §3: active tab is a FILLED pill — green in day,
                // gold at night. `primary` already resolves to the right one, and
                // using `secondary` here handed gold the active state in daylight,
                // which breaks the grammar: gold is for what the user made, not
                // for where they are.
                if (selected) (if (night) Gold else scheme.primary) else Color.Transparent,
                label = "navTint",
            )
            Column(
                modifier = Modifier
                    .clip(RoundedCornerShape(20.dp))
                    .background(tint)
                    .clickable(role = Role.Tab) { onSelect(dest) }
                    .semantics { this.selected = selected; this.role = Role.Tab }
                    .defaultMinSize(minWidth = 64.dp, minHeight = 48.dp)
                    .padding(horizontal = 12.dp, vertical = 6.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center,
            ) {
                NavIcon(
                    dest = dest,
                    active = selected,
                    tint = when {
                        selected && night -> NightBackground
                        selected -> scheme.onPrimary
                        night -> NightText.copy(alpha = 0.6f)
                        else -> scheme.onSurfaceVariant
                    },
                )
                Spacer(Modifier.height(5.dp))
                Text(
                    dest.label,
                    fontSize = 11.sp,
                    color = when {
                        selected && night -> NightBackground
                        selected -> scheme.onPrimary
                        night -> NightText.copy(alpha = 0.6f)
                        else -> scheme.onSurfaceVariant
                    },
                    fontWeight = androidx.compose.ui.text.font.FontWeight.Bold,
                )
            }
        }
    }
}
