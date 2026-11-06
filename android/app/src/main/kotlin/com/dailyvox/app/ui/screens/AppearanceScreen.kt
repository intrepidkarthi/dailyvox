package com.dailyvox.app.ui.screens

import androidx.compose.animation.Crossfade
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.semantics.Role
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.heading
import androidx.compose.ui.semantics.role
import androidx.compose.ui.semantics.selected
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.ui.theme.DvPalette
import com.dailyvox.app.ui.theme.LocalDvPalette
import com.dailyvox.app.ui.theme.MoodColors
import com.dailyvox.app.ui.theme.Nunito
import com.dailyvox.app.ui.theme.ThemeGroup
import com.dailyvox.app.ui.theme.ThemeId
import com.dailyvox.app.ui.theme.paletteFor

/** Sunset is the automatic mode: night from the real sunset, day from sunrise. */
fun modeLabel(mode: ThemeChoice) = when (mode) {
    ThemeChoice.LIGHT -> "Day"
    ThemeChoice.DARK -> "Night"
    ThemeChoice.SUNSET -> "Sunset"
}

/** Three overlapping dots: the theme's page, its actor, its reward. */
@Composable
fun ThemeSwatch(id: ThemeId, size: Dp = 16.dp) {
    val p = paletteFor(id, dark = false)
    val ring = MaterialTheme.colorScheme.surface
    Row(horizontalArrangement = Arrangement.spacedBy(-(size / 3))) {
        listOf(p.ground, p.action, p.reward).forEach { c ->
            Box(
                Modifier.size(size).clip(CircleShape).background(c)
                    .border(1.5.dp, ring, CircleShape)
                    .border(0.5.dp, MaterialTheme.colorScheme.onSurface.copy(alpha = 0.15f), CircleShape)
            )
        }
    }
}

/**
 * Appearance: a live preview of Today, the Day / Night / Sunset mode, and the
 * nineteen themes as four rows you scroll sideways, so the choice never turns
 * Settings into a wall of colour. A tap applies at once; the whole app is the
 * second preview.
 */
@Composable
fun AppearanceScreen(
    themeId: ThemeId,
    onThemeId: (ThemeId) -> Unit,
    mode: ThemeChoice,
    onMode: (ThemeChoice) -> Unit,
    onBack: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val scheme = MaterialTheme.colorScheme
    val pal = LocalDvPalette.current
    Column(modifier.fillMaxSize().verticalScroll(rememberScrollState())) {
        Spacer(Modifier.height(14.dp))
        Row(
            Modifier.fillMaxWidth().padding(horizontal = 24.dp, vertical = 4.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text("‹", fontSize = 30.sp, color = scheme.onBackground,
                 modifier = Modifier.clip(RoundedCornerShape(24.dp)).clickable(onClick = onBack)
                     .semantics { contentDescription = "Back to Settings" }
                     .defaultMinSize(48.dp, 48.dp).wrapContentSize())
            Spacer(Modifier.width(4.dp))
            Text("Appearance", fontFamily = Nunito, fontSize = 30.sp, fontWeight = FontWeight.ExtraBold,
                 color = scheme.onBackground, modifier = Modifier.semantics { heading() })
        }

        Spacer(Modifier.height(10.dp))
        Crossfade(targetState = pal, animationSpec = tween(220), label = "preview") { p ->
            TodayPreview(p, Modifier.padding(horizontal = 24.dp))
        }

        Spacer(Modifier.height(14.dp))
        ModeControl(mode, onMode, Modifier.padding(horizontal = 24.dp))
        if (mode != ThemeChoice.LIGHT && !themeId.hasOwnDark) {
            Text(
                "${themeId.label} is drawn for daylight. At night it keeps the default navy with its own accent.",
                fontSize = 11.5.sp, lineHeight = 16.sp, color = scheme.onSurfaceVariant,
                modifier = Modifier.padding(horizontal = 28.dp, vertical = 8.dp),
            )
        }

        ThemeGroup.entries.forEach { group ->
            Spacer(Modifier.height(14.dp))
            Text(group.label, fontSize = 13.sp, fontWeight = FontWeight.Bold, color = scheme.onBackground,
                 modifier = Modifier.padding(horizontal = 24.dp).semantics { heading() })
            Spacer(Modifier.height(8.dp))
            val ids = ThemeId.entries.filter { it.group == group }
            // Open with the chosen tile in view, not off the edge of its row.
            val rowState = androidx.compose.foundation.lazy.rememberLazyListState(
                initialFirstVisibleItemIndex = (ids.indexOf(themeId) - 1).coerceAtLeast(0))
            LazyRow(
                state = rowState,
                contentPadding = PaddingValues(horizontal = 24.dp),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                items(ids, key = { it.key }) { id ->
                    ThemeTile(id, selected = id == themeId, onClick = { onThemeId(id) })
                }
            }
            if (group == ThemeGroup.FESTIVALS) {
                Text("Festival themes can be used any time.", fontSize = 11.5.sp,
                     color = scheme.onSurfaceVariant,
                     modifier = Modifier.padding(horizontal = 24.dp, vertical = 8.dp))
            }
        }
        Spacer(Modifier.height(40.dp))
    }
}

@Composable
private fun ModeControl(mode: ThemeChoice, onMode: (ThemeChoice) -> Unit, modifier: Modifier) {
    val scheme = MaterialTheme.colorScheme
    val pal = LocalDvPalette.current
    Row(
        modifier
            .fillMaxWidth()
            .clip(RoundedCornerShape(16.dp))
            .background(pal.surface)
            .then(pal.cardBorder?.let { Modifier.border(pal.cardBorderWidth, it, RoundedCornerShape(16.dp)) } ?: Modifier)
            .padding(4.dp),
    ) {
        ThemeChoice.entries.forEach { choice ->
            val on = choice == mode
            Text(
                modeLabel(choice),
                fontSize = 13.sp,
                fontWeight = if (on) FontWeight.ExtraBold else FontWeight.SemiBold,
                color = if (on) pal.onTabActive else scheme.onSurfaceVariant,
                textAlign = TextAlign.Center,
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(12.dp))
                    .then(if (on) Modifier.background(pal.tabActive) else Modifier)
                    .clickable { onMode(choice) }
                    .semantics {
                        role = Role.RadioButton
                        selected = on
                        contentDescription = when (choice) {
                            ThemeChoice.SUNSET -> "Sunset: night after the real sunset"
                            else -> modeLabel(choice)
                        }
                    }
                    .heightIn(min = 48.dp)
                    .wrapContentHeight(Alignment.CenterVertically),
            )
        }
    }
}

/** A theme as a little page: its ground, a disc in its actor, a bar in its reward. */
@Composable
private fun ThemeTile(id: ThemeId, selected: Boolean, onClick: () -> Unit) {
    val scheme = MaterialTheme.colorScheme
    val p = paletteFor(id, dark = false)
    val shape = RoundedCornerShape(16.dp)
    Column(
        Modifier
            .width(92.dp)
            .clip(shape)
            .clickable(onClick = onClick)
            .semantics(mergeDescendants = true) {
                role = Role.RadioButton
                this.selected = selected
                contentDescription = "${id.label} theme"
            },
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            Modifier
                .fillMaxWidth()
                .height(54.dp)
                .clip(shape)
                .background(p.ground)
                .border(
                    if (selected) 2.5.dp else 1.dp,
                    if (selected) scheme.primary else scheme.onSurface.copy(alpha = 0.14f),
                    shape,
                ),
        ) {
            // the header band themes carry, or the page's own top
            Box(Modifier.fillMaxWidth().height(14.dp).background(p.band ?: p.ground))
            Box(
                Modifier.align(Alignment.BottomStart).padding(start = 10.dp, bottom = 10.dp)
                    .size(24.dp).clip(CircleShape).background(p.action)
            )
            Box(
                Modifier.align(Alignment.BottomEnd).padding(end = 10.dp, bottom = 15.dp)
                    .width(30.dp).height(7.dp).clip(RoundedCornerShape(4.dp)).background(p.reward)
            )
            if (selected) Box(
                Modifier.align(Alignment.TopEnd).padding(5.dp).size(20.dp)
                    .clip(CircleShape).background(scheme.primary),
                contentAlignment = Alignment.Center,
            ) {
                Text("✓", fontSize = 12.sp, fontWeight = FontWeight.Bold, color = scheme.onPrimary)
            }
        }
        Text(
            id.label, fontSize = 12.sp, lineHeight = 15.sp,
            fontWeight = if (selected) FontWeight.Bold else FontWeight.Medium,
            color = scheme.onBackground, textAlign = TextAlign.Center,
            maxLines = 2, overflow = TextOverflow.Ellipsis,
            modifier = Modifier.padding(top = 6.dp, bottom = 4.dp).heightIn(min = 30.dp),
        )
    }
}

/**
 * Today in miniature, drawn from the palette alone: header, an entry card, the
 * mood chip, the mic and the tab bar. The mood chip keeps its fixed mood colour.
 */
@Composable
private fun TodayPreview(p: DvPalette, modifier: Modifier) {
    val shape = RoundedCornerShape(22.dp)
    Column(
        modifier
            .fillMaxWidth()
            .clip(shape)
            .background(p.ground)
            .border(1.dp, p.ink.copy(alpha = 0.10f), shape)
            .semantics(mergeDescendants = true) { contentDescription = "Preview of Today in this theme" }
            .padding(horizontal = 14.dp, vertical = 11.dp),
    ) {
        if (p.band != null) Box(
            Modifier.fillMaxWidth().height(6.dp).clip(RoundedCornerShape(3.dp)).background(p.band)
        )
        if (p.band != null) Spacer(Modifier.height(8.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text("Good morning", fontSize = 13.sp, fontWeight = FontWeight.Bold, color = p.ink)
                Text("Friday, November 6", fontSize = 10.5.sp, color = p.inkSoft)
            }
            Text("✦ 33 days", fontSize = 11.sp, fontWeight = FontWeight.Bold, color = p.rewardText)
        }
        Spacer(Modifier.height(8.dp))
        val card = RoundedCornerShape(14.dp)
        Column(
            Modifier.fillMaxWidth().clip(card).background(p.surface)
                .then(p.cardBorder?.let { Modifier.border(p.cardBorderWidth.coerceAtMost(1.5.dp), it, card) } ?: Modifier)
                .padding(10.dp),
        ) {
            Text("Sarah called on the drive home and I finally said it out loud.",
                 fontSize = 11.5.sp, lineHeight = 15.sp, color = p.ink, maxLines = 2)
            Spacer(Modifier.height(8.dp))
            Text(
                "Feeling calm", fontSize = 10.5.sp, fontWeight = FontWeight.SemiBold,
                color = p.ink,
                modifier = Modifier.clip(RoundedCornerShape(10.dp))
                    .background(MoodColors.Warm.copy(alpha = 0.22f))
                    .padding(horizontal = 9.dp, vertical = 4.dp),
            )
        }
        Spacer(Modifier.height(8.dp))
        Box(
            Modifier.align(Alignment.CenterHorizontally).size(38.dp).clip(CircleShape).background(p.action),
            contentAlignment = Alignment.Center,
        ) {
            Box(Modifier.width(9.dp).height(15.dp).clip(RoundedCornerShape(5.dp)).background(p.onAction))
        }
        Spacer(Modifier.height(8.dp))
        Row(
            Modifier.fillMaxWidth().clip(RoundedCornerShape(14.dp)).background(p.surface)
                .then(p.cardBorder?.let { Modifier.border(1.dp, it, RoundedCornerShape(14.dp)) } ?: Modifier)
                .padding(4.dp),
            horizontalArrangement = Arrangement.SpaceEvenly,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            listOf("Speak", "Journal", "Twin", "Ask").forEachIndexed { i, t ->
                Text(
                    t, fontSize = 10.5.sp, fontWeight = FontWeight.Bold,
                    color = if (i == 0) p.onTabActive else p.inkSoft,
                    modifier = Modifier.clip(RoundedCornerShape(10.dp))
                        .then(if (i == 0) Modifier.background(p.tabActive) else Modifier)
                        .padding(horizontal = 10.dp, vertical = 6.dp),
                )
            }
        }
    }
}
