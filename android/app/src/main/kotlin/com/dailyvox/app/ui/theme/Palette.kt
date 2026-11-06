package com.dailyvox.app.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.luminance
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp

/**
 * A theme is data: one [DvPalette] per theme and mode, read through
 * [LocalDvPalette]. Screens ask the palette for a role ("the reward colour as
 * text", "the night ground") instead of reaching for a hex constant, so a new
 * theme is a new palette and nothing else.
 *
 * Two zones, because the product has two skies:
 *  - the PAGE (Speak, Journal, Insights, Ask, Settings) follows the mode, and
 *  - the NIGHT zone (recording, the Twin sky, onboarding's dark panels) is
 *    night in every mode (FINAL-SPEC §8.4). Each theme brings its own night.
 *
 * Mood colours are NOT here. They live in [MoodColors] and never change with
 * the theme, so a star and its entry mean the same thing in every palette.
 *
 * Values for the new themes come from the theme mockups (Nov 2026). They are
 * light-only for now except Sticker, Monsoon and High contrast, which were
 * drawn in both modes; the rest fall back to the default night with their own
 * night accent ([fallbackNight]) until their dark variants are designed.
 */
@Immutable
data class DvPalette(
    val isNight: Boolean,
    // ── page ──
    val ground: Color,
    val surface: Color,
    val ink: Color,
    val inkSoft: Color,
    /** Green acts in Default: record, save, confirm. Each theme's actor. */
    val action: Color,
    val onAction: Color,
    /** Ledger ticks, "kept" states. Text-safe on [surface]. */
    val positive: Color,
    val chip: Color,
    val onChip: Color,
    /** What the user made: stars, streaks, insights. Decorative fills. */
    val reward: Color,
    /** [reward] when it has to be read as text on [ground]/[surface]. */
    val rewardText: Color,
    val rewardTint: Color,
    /** The recording disc. Recording is the only red in the product. */
    val record: Color,
    val tabActive: Color,
    val onTabActive: Color,
    /** Outline drawn round cards; null keeps Default's hairline/no-border. */
    val cardBorder: Color? = null,
    val cardBorderWidth: Dp = 1.dp,
    /** Header band for themes that have one (seasons, banded festivals).
     *  Hook for the decorations step; nothing draws it yet. */
    val band: Color? = null,
    val onBand: Color? = null,
    // ── night zone ──
    val night: NightPalette,
) {
    /** Text or a glyph drawn ON a [reward] fill (the gold disc, the rate chip).
     *  Navy on Default's gold; white once a theme's reward is dark (High contrast). */
    val onReward: Color get() = if (reward.luminance() > 0.18f) NightBackground else Color.White
}

@Immutable
data class NightPalette(
    val ground: Color,
    val surface: Color,
    val ink: Color,
    val inkSoft: Color,
    /** The dial, the core star, the active tab under the sky. */
    val reward: Color,
    val rewardText: Color,
    /** Text/glyphs drawn on [reward]. */
    val onReward: Color,
)

/** Fixed across every theme: the valence ramp shared with iOS's constellation. */
object MoodColors {
    val Unread = Color(0xFFA8A29A)
    val Bright = Color(0xFFD9A441)   // > +0.3, the one gold
    val Warm = Color(0xFF6B9E7B)     // > 0
    val Cool = Color(0xFF7BA4C7)     // > -0.3
    val Low = Color(0xFFC4736B)
}

enum class ThemeGroup(val label: String) {
    BOLD("Bold"),
    CALM("Calm & soulful"),
    SEASONS("Seasons"),
    FESTIVALS("Festivals"),
}

/**
 * Stored by [key] in prefs ("themeId"), separately from the Day/Night/Sunset
 * mode ("theme"), so every existing install reads as DEFAULT with the mode it
 * already had.
 */
enum class ThemeId(val key: String, val label: String, val group: ThemeGroup) {
    DEFAULT("default", "Default", ThemeGroup.BOLD),
    STICKER("sticker", "Sticker", ThemeGroup.BOLD),
    HIGH_CONTRAST("high_contrast", "High contrast", ThemeGroup.BOLD),
    MIST("mist", "Mist", ThemeGroup.CALM),
    LOTUS("lotus", "Lotus", ThemeGroup.CALM),
    SANDALWOOD("sandalwood", "Sandalwood", ThemeGroup.CALM),
    HUSH("hush", "Hush", ThemeGroup.CALM),
    PAPER_NOTEBOOK("paper_notebook", "Paper notebook", ThemeGroup.CALM),
    SPRING("spring", "Spring", ThemeGroup.SEASONS),
    SUMMER("summer", "Summer", ThemeGroup.SEASONS),
    MONSOON("monsoon", "Monsoon", ThemeGroup.SEASONS),
    AUTUMN("autumn", "Autumn", ThemeGroup.SEASONS),
    WINTER("winter", "Winter", ThemeGroup.SEASONS),
    CHRISTMAS("christmas", "Christmas", ThemeGroup.FESTIVALS),
    DIWALI("diwali", "Diwali", ThemeGroup.FESTIVALS),
    HOLI("holi", "Holi", ThemeGroup.FESTIVALS),
    PONGAL("pongal", "Pongal / Sankranti", ThemeGroup.FESTIVALS),
    RAMADAN("ramadan", "Ramadan", ThemeGroup.FESTIVALS),
    EID("eid", "Eid", ThemeGroup.FESTIVALS);

    /** True when the theme has its own night palette rather than the fallback. */
    val hasOwnDark: Boolean get() = this in setOf(DEFAULT, STICKER, HIGH_CONTRAST, MONSOON)

    companion object {
        fun fromKey(key: String?): ThemeId = entries.firstOrNull { it.key == key } ?: DEFAULT
    }
}

val LocalDvPalette = staticCompositionLocalOf { DefaultDay }

fun paletteFor(id: ThemeId, dark: Boolean): DvPalette =
    if (dark) darkPalettes[id] ?: fallbackNight(lightPalettes.getValue(id)) else lightPalettes.getValue(id)

// ── Default: exactly the shipped colours ────────────────────────────────────

private val DefaultNightZone = NightPalette(
    ground = NightBackground, surface = NightSurface, ink = NightText, inkSoft = NightTextSecondary,
    reward = Gold, rewardText = NightGoldText, onReward = NightBackground,
)

val DefaultDay = DvPalette(
    isNight = false,
    ground = DayBackground, surface = DaySurface, ink = DayText, inkSoft = DayTextSecondary,
    action = DayAction, onAction = DayOnAction, positive = DayPositive,
    chip = DayGreenTint, onChip = DayAction,
    reward = Gold, rewardText = DayGoldText, rewardTint = DayGoldTint,
    record = RecordRed, tabActive = DayAction, onTabActive = DayOnAction,
    night = DefaultNightZone,
)

val DefaultNight = DvPalette(
    isNight = true,
    ground = NightBackground, surface = NightSurface, ink = NightText, inkSoft = NightTextSecondary,
    action = NightAction, onAction = NightOnAction, positive = NightPositive,
    chip = NightSurface, onChip = NightGoldText,
    reward = Gold, rewardText = NightGoldText, rewardTint = NightGoldTint,
    record = RecordRed, tabActive = Gold, onTabActive = NightBackground,
    night = DefaultNightZone,
)

/** Until a theme's dark variant is drawn: Default's night throughout (page
 *  and sky, so the two never meet as two different navies), with the theme's
 *  own night accent as the actor, the tab and the dial. */
private fun fallbackNight(light: DvPalette): DvPalette {
    val accent = light.night.reward
    return DefaultNight.copy(
        action = accent, onAction = NightBackground,
        tabActive = accent, onTabActive = NightBackground,
        night = DefaultNightZone.copy(reward = accent, rewardText = accent, onReward = NightBackground),
    )
}

// ── Builder for the mockup themes ───────────────────────────────────────────

private fun c(hex: Long) = Color(0xFF000000 or hex)

private fun mock(
    night: Boolean = false,
    bg: Long, card: Long, line: Long?, lineWidth: Dp = 1.dp,
    ink: Long, ink2: Long,
    accent: Long, accentInk: Long, accentText: Long,
    gold: Long, goldText: Long, goldSoft: Long,
    pill: Long, pillInk: Long,
    tabOn: Long, tabOnInk: Long, rec: Long,
    sky: Long, sky2: Long, skyInk: Long, skyInk2: Long, dial: Long, dialInk: Long,
    band: Long? = null, bandInk: Long? = null,
) = DvPalette(
    isNight = night,
    ground = c(bg), surface = c(card), ink = c(ink), inkSoft = c(ink2),
    action = c(accent), onAction = c(accentInk), positive = c(accentText),
    chip = c(pill), onChip = c(pillInk),
    reward = c(gold), rewardText = c(goldText), rewardTint = c(goldSoft),
    record = c(rec), tabActive = c(tabOn), onTabActive = c(tabOnInk),
    cardBorder = line?.let(::c), cardBorderWidth = lineWidth,
    band = band?.let(::c), onBand = bandInk?.let(::c),
    night = NightPalette(
        ground = c(sky), surface = c(sky2), ink = c(skyInk), inkSoft = c(skyInk2),
        reward = c(dial), rewardText = c(dial), onReward = c(dialInk),
    ),
)

private val lightPalettes: Map<ThemeId, DvPalette> = mapOf(
    ThemeId.DEFAULT to DefaultDay,
    ThemeId.STICKER to mock(
        bg = 0xF4F5F1, card = 0xFFFFFF, line = 0x1D1F24, lineWidth = 2.dp,
        ink = 0x1D1F24, ink2 = 0x3E424B, accent = 0x1F5A43, accentInk = 0xFFFFFF, accentText = 0x1F5A43,
        gold = 0xF2C14E, goldText = 0x7A5800, goldSoft = 0xFCEFC9, pill = 0x3358C9, pillInk = 0xFFFFFF,
        tabOn = 0xF2C14E, tabOnInk = 0x1D1F24, rec = 0xE2553A,
        sky = 0x1D1F24, sky2 = 0x2E3139, skyInk = 0xFFFFFF, skyInk2 = 0xB9BDC6, dial = 0xF2C14E, dialInk = 0x1D1F24,
    ),
    ThemeId.HIGH_CONTRAST to mock(
        bg = 0xFFFFFF, card = 0xFFFFFF, line = 0x000000, lineWidth = 2.dp,
        ink = 0x000000, ink2 = 0x000000, accent = 0x0047FF, accentInk = 0xFFFFFF, accentText = 0x0033B8,
        gold = 0x000000, goldText = 0x000000, goldSoft = 0xFFFFFF, pill = 0x000000, pillInk = 0xFFFFFF,
        tabOn = 0x0047FF, tabOnInk = 0xFFFFFF, rec = 0xFF3B30,
        sky = 0x000000, sky2 = 0x1A1A1A, skyInk = 0xFFFFFF, skyInk2 = 0xE6E6E6, dial = 0xFFD60A, dialInk = 0x000000,
    ),
    ThemeId.MIST to mock(
        bg = 0xEEF2F4, card = 0xFFFFFF, line = 0xDCE3E8,
        ink = 0x2C3A45, ink2 = 0x4E5D69, accent = 0x4F6F88, accentInk = 0xFFFFFF, accentText = 0x4F6F88,
        gold = 0xB8892B, goldText = 0x7D5E17, goldSoft = 0xF5EEDC, pill = 0xE2E8F0, pillInk = 0x3E5A72,
        tabOn = 0x4F6F88, tabOnInk = 0xFFFFFF, rec = 0xC8665A,
        sky = 0x2B3946, sky2 = 0x3A4A58, skyInk = 0xEEF2F4, skyInk2 = 0xB4C0CA, dial = 0xCDBFEF, dialInk = 0x2B3946,
    ),
    ThemeId.LOTUS to mock(
        bg = 0xFBF1F2, card = 0xFFFFFF, line = 0xF0DDE1,
        ink = 0x2E2A2B, ink2 = 0x5A4E52, accent = 0x2F5B46, accentInk = 0xFFFFFF, accentText = 0x2F5B46,
        gold = 0xB88A2E, goldText = 0x7A5A14, goldSoft = 0xFAF0DA, pill = 0xF7DDE3, pillInk = 0x8E3A55,
        tabOn = 0x2F5B46, tabOnInk = 0xFFFFFF, rec = 0xC8546E,
        sky = 0x22342C, sky2 = 0x2F463B, skyInk = 0xFBF1F2, skyInk2 = 0xC2CFC7, dial = 0xF2B8C6, dialInk = 0x22342C,
    ),
    ThemeId.SANDALWOOD to mock(
        bg = 0xF6EEE2, card = 0xFFFDF9, line = 0xE8DCC8,
        ink = 0x3B2A1E, ink2 = 0x5E4636, accent = 0xE39B2D, accentInk = 0x3B2A1E, accentText = 0x8F520C,
        gold = 0xB08D57, goldText = 0x7A5C2A, goldSoft = 0xF3E6CC, pill = 0xF1E2C8, pillInk = 0x6B4A1E,
        tabOn = 0x3B2A1E, tabOnInk = 0xF6EEE2, rec = 0xC2553A,
        sky = 0x2E2118, sky2 = 0x3F2F23, skyInk = 0xF6EEE2, skyInk2 = 0xCBB9A4, dial = 0xE39B2D, dialInk = 0x2E2118,
    ),
    ThemeId.HUSH to mock(
        bg = 0xF3EFF8, card = 0xFFFFFF, line = 0xE4DCEF,
        ink = 0x3A2A45, ink2 = 0x5A4A66, accent = 0x6B4A7E, accentInk = 0xFFFFFF, accentText = 0x6B4A7E,
        gold = 0xB38A3A, goldText = 0x7A5C1C, goldSoft = 0xF6EEDC, pill = 0xEAE1F3, pillInk = 0x5A3D6B,
        tabOn = 0x6B4A7E, tabOnInk = 0xFFFFFF, rec = 0xC45C78,
        sky = 0x2A2236, sky2 = 0x3A3049, skyInk = 0xF3EFF8, skyInk2 = 0xC4B9D3, dial = 0xD7C2F0, dialInk = 0x2A2236,
    ),
    ThemeId.PAPER_NOTEBOOK to mock(
        bg = 0xFBFAF5, card = 0xFFFFFF, line = 0xD6D3C8,
        ink = 0x1F2A44, ink2 = 0x444C5E, accent = 0x23408E, accentInk = 0xFFFFFF, accentText = 0x23408E,
        gold = 0xB8862A, goldText = 0x7A5A14, goldSoft = 0xF7EFDB, pill = 0xE6EAF4, pillInk = 0x23408E,
        tabOn = 0x23408E, tabOnInk = 0xFFFFFF, rec = 0xC0392B,
        sky = 0x1F2A44, sky2 = 0x2E3A57, skyInk = 0xFBFAF5, skyInk2 = 0xBFC6D4, dial = 0xF0C24E, dialInk = 0x1F2A44,
    ),
    ThemeId.SPRING to mock(
        bg = 0xF4F7F1, card = 0xFFFFFF, line = 0xDDE6D8,
        ink = 0x233127, ink2 = 0x4A5A4E, accent = 0x3B7449, accentInk = 0xFFFFFF, accentText = 0x3B7449,
        gold = 0xC99A2E, goldText = 0x7A5A14, goldSoft = 0xF7EFD6, pill = 0xDCEBF7, pillInk = 0x2C5E8A,
        tabOn = 0xF2A7BC, tabOnInk = 0x3A1F28, rec = 0xD9536E,
        sky = 0x1F3550, sky2 = 0x2D4766, skyInk = 0xF4F7F1, skyInk2 = 0xB9C8D8, dial = 0xF5B3C6, dialInk = 0x1F3550,
        band = 0xF8D7E0, bandInk = 0x3A1F28,
    ),
    ThemeId.SUMMER to mock(
        bg = 0xFFF9EE, card = 0xFFFFFF, line = 0xF1E3C6,
        ink = 0x2A2418, ink2 = 0x544A36, accent = 0x0F7471, accentInk = 0xFFFFFF, accentText = 0x0F6E6C,
        gold = 0xE0A100, goldText = 0x7A5600, goldSoft = 0xFFF0C2, pill = 0xD7F0EE, pillInk = 0x0F5E5C,
        tabOn = 0xF5B800, tabOnInk = 0x2A2418, rec = 0xE5674E,
        sky = 0x0E3B4A, sky2 = 0x19505F, skyInk = 0xFFF9EE, skyInk2 = 0xB5D2D6, dial = 0xF5B800, dialInk = 0x0E3B4A,
        band = 0xF5B800, bandInk = 0x2A2418,
    ),
    ThemeId.MONSOON to mock(
        bg = 0xE6ECEF, card = 0xFFFFFF, line = 0xC3CFD8,
        ink = 0x1E2A33, ink2 = 0x44535F, accent = 0x2E6A55, accentInk = 0xFFFFFF, accentText = 0x2E6A55,
        gold = 0xE8A900, goldText = 0x7C5A00, goldSoft = 0xFFF1C7, pill = 0xDCE6EE, pillInk = 0x2F4E68,
        tabOn = 0xF2B705, tabOnInk = 0x1E2A33, rec = 0xC7613A,
        sky = 0x26354A, sky2 = 0x34465E, skyInk = 0xEEF2F4, skyInk2 = 0xA8B6C4, dial = 0xF2B705, dialInk = 0x1E2A33,
        band = 0x3E5466, bandInk = 0xFFFFFF,
    ),
    ThemeId.AUTUMN to mock(
        bg = 0xF8F1E7, card = 0xFFFFFF, line = 0xEAD9C3,
        ink = 0x2F2220, ink2 = 0x57433C, accent = 0x7A3E5A, accentInk = 0xFFFFFF, accentText = 0x7A3E5A,
        gold = 0xC9971F, goldText = 0x7A5A0E, goldSoft = 0xF7EBCB, pill = 0xF3E0D2, pillInk = 0x8A3E1E,
        tabOn = 0xA6461E, tabOnInk = 0xFFFFFF, rec = 0xC0502A,
        sky = 0x2C1E24, sky2 = 0x3E2B33, skyInk = 0xF8F1E7, skyInk2 = 0xCDBBB4, dial = 0xE0A93A, dialInk = 0x2C1E24,
        band = 0xA6461E, bandInk = 0xFFF6EA,
    ),
    ThemeId.WINTER to mock(
        bg = 0xF1F6F9, card = 0xFFFFFF, line = 0xD8E5EC,
        ink = 0x1D2B33, ink2 = 0x43535D, accent = 0x1F5A48, accentInk = 0xFFFFFF, accentText = 0x1F5A48,
        gold = 0xC29A3A, goldText = 0x7A5C14, goldSoft = 0xF6EEDA, pill = 0xDCEBF4, pillInk = 0x2A5874,
        tabOn = 0xA3243F, tabOnInk = 0xFFFFFF, rec = 0xC23B55,
        sky = 0x142634, sky2 = 0x213A4C, skyInk = 0xF1F6F9, skyInk2 = 0xB8CBD8, dial = 0xCFE6F3, dialInk = 0x142634,
        band = 0x2F5E73, bandInk = 0xFFFFFF,
    ),
    ThemeId.CHRISTMAS to mock(
        bg = 0xF7F4EE, card = 0xFFFFFF, line = 0xE5DED2,
        ink = 0x23201C, ink2 = 0x4C463E, accent = 0x1E5A3C, accentInk = 0xFFFFFF, accentText = 0x1E5A3C,
        gold = 0xC8A13A, goldText = 0x7A5E14, goldSoft = 0xF6EDD3, pill = 0xF6DCDC, pillInk = 0x9B1F2E,
        tabOn = 0x9B1F2E, tabOnInk = 0xFFFFFF, rec = 0xC0392B,
        sky = 0x14271E, sky2 = 0x213A2E, skyInk = 0xF7F4EE, skyInk2 = 0xBFCFC5, dial = 0xE2C25A, dialInk = 0x14271E,
        band = 0x1E5A3C, bandInk = 0xFFFFFF,
    ),
    ThemeId.DIWALI to mock(
        bg = 0xFBF6EE, card = 0xFFFFFF, line = 0xEEDFC8,
        ink = 0x2A1F1A, ink2 = 0x56463C, accent = 0xB5297A, accentInk = 0xFFFFFF, accentText = 0xA0236B,
        gold = 0xE8930C, goldText = 0x7A4E06, goldSoft = 0xFCEBCF, pill = 0xF6DDEB, pillInk = 0x8A1F5C,
        tabOn = 0xE8930C, tabOnInk = 0x2A1F1A, rec = 0xD2452E,
        sky = 0x211B42, sky2 = 0x312A5C, skyInk = 0xFBF6EE, skyInk2 = 0xC6C0E0, dial = 0xF2A93B, dialInk = 0x211B42,
        band = 0x2A2350, bandInk = 0xFFFFFF,
    ),
    ThemeId.HOLI to mock(
        bg = 0xFFFFFF, card = 0xFFFFFF, line = 0xE6E6EA,
        ink = 0x1F1D2B, ink2 = 0x4A4858, accent = 0xC2185B, accentInk = 0xFFFFFF, accentText = 0xB0154F,
        gold = 0xE0A100, goldText = 0x7A5600, goldSoft = 0xFFF3C4, pill = 0xDCE6FB, pillInk = 0x2547A8,
        tabOn = 0xC2185B, tabOnInk = 0xFFFFFF, rec = 0xE5484D,
        sky = 0x24183C, sky2 = 0x352553, skyInk = 0xFFFFFF, skyInk2 = 0xCDC3E0, dial = 0xFFD23F, dialInk = 0x24183C,
    ),
    ThemeId.PONGAL to mock(
        bg = 0xFBF7EC, card = 0xFFFFFF, line = 0xEBE1C6,
        ink = 0x2A2210, ink2 = 0x544A30, accent = 0x3E7A2E, accentInk = 0xFFFFFF, accentText = 0x3A722B,
        gold = 0xE0A800, goldText = 0x7A5800, goldSoft = 0xFBEFC8, pill = 0xF3E4CF, pillInk = 0x7A3F12,
        tabOn = 0x3E7A2E, tabOnInk = 0xFFFFFF, rec = 0xC2502A,
        sky = 0x1E2B17, sky2 = 0x2D3E23, skyInk = 0xFBF7EC, skyInk2 = 0xC7D1BB, dial = 0xF2C230, dialInk = 0x1E2B17,
        band = 0xF2C230, bandInk = 0x2A2210,
    ),
    ThemeId.RAMADAN to mock(
        bg = 0xF4F3EE, card = 0xFFFFFF, line = 0xE2DFD4,
        ink = 0x1F2A2B, ink2 = 0x44514F, accent = 0x145C5E, accentInk = 0xFFFFFF, accentText = 0x145C5E,
        gold = 0xC9952A, goldText = 0x7A5A12, goldSoft = 0xF5ECD4, pill = 0xDDEBEA, pillInk = 0x145C5E,
        tabOn = 0x145C5E, tabOnInk = 0xFFFFFF, rec = 0xC2553A,
        sky = 0x0F2E33, sky2 = 0x1A4147, skyInk = 0xF4F3EE, skyInk2 = 0xB9CDCB, dial = 0xE1B655, dialInk = 0x0F2E33,
        band = 0x123E44, bandInk = 0xFFFFFF,
    ),
    ThemeId.EID to mock(
        bg = 0xF3F8F3, card = 0xFFFFFF, line = 0xDCE8DE,
        ink = 0x1F2B25, ink2 = 0x44534B, accent = 0x1E6A50, accentInk = 0xFFFFFF, accentText = 0x1E6A50,
        gold = 0xB8912F, goldText = 0x7A5C14, goldSoft = 0xF6EFD9, pill = 0xE3F0E8, pillInk = 0x1E6A50,
        tabOn = 0x1E6A50, tabOnInk = 0xFFFFFF, rec = 0xC2553A,
        sky = 0x12332A, sky2 = 0x1E4639, skyInk = 0xF3F8F3, skyInk2 = 0xBCD2C6, dial = 0xE3C46A, dialInk = 0x12332A,
    ),
)

private val darkPalettes: Map<ThemeId, DvPalette> = mapOf(
    ThemeId.DEFAULT to DefaultNight,
    ThemeId.STICKER to mock(
        night = true,
        bg = 0x1D1F24, card = 0x2A2D34, line = 0xF4F5F1, lineWidth = 2.dp,
        ink = 0xF4F5F1, ink2 = 0xD3D6DC, accent = 0x2E7A5C, accentInk = 0xFFFFFF, accentText = 0x7FD1AE,
        gold = 0xF2C14E, goldText = 0xF2C14E, goldSoft = 0x3A3322, pill = 0x4568DA, pillInk = 0xFFFFFF, // mockup 4F72E0: 4.36:1 under white
        tabOn = 0xF2C14E, tabOnInk = 0x1D1F24, rec = 0xE2553A,
        sky = 0x14161A, sky2 = 0x2A2D34, skyInk = 0xFFFFFF, skyInk2 = 0xB9BDC6, dial = 0xF2C14E, dialInk = 0x1D1F24,
    ),
    ThemeId.HIGH_CONTRAST to mock(
        night = true,
        bg = 0x000000, card = 0x000000, line = 0xFFFFFF, lineWidth = 2.dp,
        ink = 0xFFFFFF, ink2 = 0xFFFFFF, accent = 0xFFD60A, accentInk = 0x000000, accentText = 0xFFD60A,
        gold = 0xFFD60A, goldText = 0xFFD60A, goldSoft = 0x000000, pill = 0xFFFFFF, pillInk = 0x000000,
        tabOn = 0xFFD60A, tabOnInk = 0x000000, rec = 0xFF453A,
        sky = 0x000000, sky2 = 0x1A1A1A, skyInk = 0xFFFFFF, skyInk2 = 0xEDEDED, dial = 0xFFD60A, dialInk = 0x000000,
    ),
    ThemeId.MONSOON to mock(
        night = true,
        bg = 0x121A22, card = 0x1C2731, line = 0x283744,
        ink = 0xE6ECEF, ink2 = 0xB9C5CE, accent = 0x367D63, accentInk = 0xFFFFFF, accentText = 0x8FD0B5, // mockup 3F8A6E: 4.14:1
        gold = 0xF2B705, goldText = 0xF2C744, goldSoft = 0x2D2A1A, pill = 0x253545, pillInk = 0xA9C7E2,
        tabOn = 0xF2B705, tabOnInk = 0x121A22, rec = 0xC7613A,
        sky = 0x0E151C, sky2 = 0x1C2731, skyInk = 0xEEF2F4, skyInk2 = 0xA8B6C4, dial = 0xF2B705, dialInk = 0x121A22,
        band = 0x22303D, bandInk = 0xEEF2F4,
    ),
)
