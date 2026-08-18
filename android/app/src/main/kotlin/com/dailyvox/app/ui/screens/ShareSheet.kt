package com.dailyvox.app.ui.screens

import androidx.compose.foundation.Image
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.layout.FlowRow
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Switch
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.asImageBitmap
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Shareables

/**
 * Card preview → OS share sheet (design §F, "share flow").
 *
 * The card is rendered on this device and handed to the chooser as a file URI.
 * The app never sends it anywhere: with no INTERNET permission it could not,
 * which is exactly the claim the cards are making.
 *
 * NAMES ARE OFF BY DEFAULT. The toggle exists because some people do want to
 * post "Sarah · 61 nights", but the default has to be the safe one — a shared
 * card is irreversible the moment it leaves, and the person named never got a
 * say.
 */
@OptIn(androidx.compose.material3.ExperimentalMaterial3Api::class)
@Composable
fun ShareSheet(
    entries: List<Entry>,
    initial: Shareables.Card = Shareables.Card.MY_SKY,
    onDismiss: () -> Unit,
) {
    val context = LocalContext.current
    val scheme = MaterialTheme.colorScheme
    val night = scheme.background == com.dailyvox.app.ui.theme.NightBackground
    val goldText = if (night) com.dailyvox.app.ui.theme.NightGoldText
                   else com.dailyvox.app.ui.theme.DayGoldText

    // The milestone card is only offered once it exists. Showing a locked
    // "night 42" chip to someone on night 9 turns a reward into a nag, which is
    // the gamification guilt the design explicitly rules out.
    val milestone = remember(entries) { Shareables.milestoneReached(entries) }
    val cards = remember(milestone) {
        Shareables.Card.entries.filter { it != Shareables.Card.MILESTONE || milestone != null }
    }
    var card by remember { mutableStateOf(if (initial in cards) initial else cards.first()) }
    var includeNames by remember { mutableStateOf(false) }

    // Re-rendered only when something that changes the pixels changes. The
    // bitmap is decoded from the same file the chooser will receive, so the
    // preview cannot drift from what gets shared.
    val file = remember(card, includeNames, entries) {
        runCatching { Shareables.render(context, card, entries, includeNames) }.getOrNull()
    }
    val bitmap = remember(file) {
        file?.let { runCatching { android.graphics.BitmapFactory.decodeFile(it.path) }.getOrNull() }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = scheme.background,
    ) {
        Column(
            Modifier.fillMaxWidth().verticalScroll(rememberScrollState())
                .padding(horizontal = 20.dp),
        ) {
            Text("Share", fontSize = 22.sp, fontWeight = FontWeight.ExtraBold,
                 color = scheme.onBackground)
            Spacer(Modifier.height(4.dp))
            Text(
                "Rendered on this phone and handed to whatever you pick. " +
                    "DailyVox has no way to send it itself.",
                fontSize = 12.5.sp, lineHeight = 18.sp, color = scheme.onSurfaceVariant,
            )

            Spacer(Modifier.height(14.dp))
            FlowRow(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                cards.forEach { c ->
                    val on = c == card
                    Text(
                        Shareables.title(c), fontSize = 12.sp,
                        fontWeight = if (on) FontWeight.ExtraBold else FontWeight.Bold,
                        color = if (on) scheme.onPrimary else scheme.onSurfaceVariant,
                        modifier = Modifier
                            .clip(RoundedCornerShape(15.dp))
                            .then(
                                if (on) Modifier.background(scheme.primary)
                                else Modifier.border(1.5.dp,
                                    scheme.onSurfaceVariant.copy(alpha = 0.25f),
                                    RoundedCornerShape(15.dp))
                            )
                            .clickable { card = c }
                            .padding(horizontal = 16.dp, vertical = 11.dp),
                    )
                }
            }

            Spacer(Modifier.height(14.dp))
            if (bitmap != null) {
                Image(
                    bitmap.asImageBitmap(), contentDescription = Shareables.title(card),
                    contentScale = ContentScale.Fit,
                    // The portrait card is sized by HEIGHT and lets width
                    // follow. Constraining width first and then applying a 9:16
                    // ratio makes the ratio win, which produced a preview twice
                    // the height of the sheet drawn over its own buttons —
                    // heightIn cannot clamp a size the ratio has already fixed.
                    modifier = (
                        if (card == Shareables.Card.WALLPAPER)
                            Modifier.height(380.dp).aspectRatio(9f / 16f)
                        else Modifier.fillMaxWidth().aspectRatio(1f)
                    )
                        .clip(RoundedCornerShape(20.dp))
                        .align(Alignment.CenterHorizontally),
                )
            } else {
                Box(
                    Modifier.fillMaxWidth().aspectRatio(1f)
                        .clip(RoundedCornerShape(20.dp))
                        .background(scheme.surface),
                    contentAlignment = Alignment.Center,
                ) {
                    Text("Could not render the card.", fontSize = 13.sp,
                         color = scheme.onSurfaceVariant)
                }
            }

            Spacer(Modifier.height(10.dp))
            Text(Shareables.caption(card), fontSize = 12.5.sp, lineHeight = 19.sp,
                 color = scheme.onSurfaceVariant)

            // Only Year One can carry a name; My Sky has no words on it by
            // design and the receipt is all counts, so offering the toggle
            // there would imply a risk that is not present.
            if (card == Shareables.Card.YEAR_ONE) {
                Spacer(Modifier.height(12.dp))
                Row(
                    Modifier.fillMaxWidth()
                        .clip(RoundedCornerShape(18.dp))
                        .background(scheme.surface)
                        .padding(horizontal = 16.dp, vertical = 12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Column(Modifier.weight(1f)) {
                        Text("Include names", fontSize = 13.sp, fontWeight = FontWeight.Medium,
                             color = scheme.onSurface)
                        Text(
                            if (includeNames) "The card will name a real person."
                            else "Off — the card says “someone”.",
                            fontSize = 11.sp, lineHeight = 16.sp,
                            color = if (includeNames) goldText else scheme.onSurfaceVariant,
                        )
                    }
                    Switch(checked = includeNames, onCheckedChange = { includeNames = it })
                }
            }

            if (card == Shareables.Card.MY_SKY && !Shareables.airplaneMode(context)) {
                Spacer(Modifier.height(10.dp))
                Text(
                    "Turn on airplane mode before sharing and the card stamps " +
                        "ON AIRPLANE MODE — because then it is true.",
                    fontSize = 11.5.sp, lineHeight = 17.sp, color = goldText,
                )
            }

            Spacer(Modifier.height(16.dp))
            if (card == Shareables.Card.WALLPAPER) {
                Text(
                    "Set as wallpaper", fontSize = 14.sp, fontWeight = FontWeight.ExtraBold,
                    color = scheme.onPrimary,
                    modifier = Modifier.fillMaxWidth()
                        .clip(RoundedCornerShape(20.dp))
                        .background(if (file == null) scheme.primary.copy(alpha = 0.4f)
                                    else scheme.primary)
                        .clickable(enabled = file != null) {
                            file?.let { Shareables.setAsWallpaper(context, it) }
                        }
                        .padding(vertical = 15.dp)
                        .wrapContentWidth(Alignment.CenterHorizontally),
                )
                Spacer(Modifier.height(8.dp))
            }
            Text(
                if (card == Shareables.Card.WALLPAPER) "Share the image instead" else "Share",
                fontSize = 14.sp, fontWeight = FontWeight.ExtraBold,
                color = if (card == Shareables.Card.WALLPAPER) scheme.primary
                        else scheme.onPrimary,
                modifier = Modifier.fillMaxWidth()
                    .clip(RoundedCornerShape(20.dp))
                    .then(
                        if (card == Shareables.Card.WALLPAPER)
                            Modifier.border(1.5.dp, scheme.primary.copy(alpha = 0.45f),
                                            RoundedCornerShape(20.dp))
                        else Modifier.background(
                            if (file == null) scheme.primary.copy(alpha = 0.4f) else scheme.primary)
                    )
                    .clickable(enabled = file != null) {
                        file?.let { Shareables.share(context, it) }
                    }
                    .padding(vertical = 15.dp)
                    .wrapContentWidth(Alignment.CenterHorizontally),
            )
            Spacer(Modifier.height(28.dp))
        }
    }
}
