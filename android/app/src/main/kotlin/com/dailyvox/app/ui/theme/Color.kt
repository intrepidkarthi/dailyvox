package com.dailyvox.app.ui.theme

import androidx.compose.ui.graphics.Color

// Design tokens from research/design/package/DESIGN-SPEC.md system 3a.
// Light = cream paper, Dark = night sky, and the constellation is dark in both:
// "the sky is always night."
//
// NOTE, and it needs a decision: these differ from the SHIPPED iOS palette,
// which is sage #5B7C6B primary + gold #D4A547 (DesignSystem.swift:40-58, and
// carried on the website as --brand:#5B7C6B). The design spec's own §9 asks for
// exactly this sanity check, having been built without access to the real app.
// Building to the design package as given; see docs/android/05-palette-divergence.md.

// ── Light: cream paper ───────────────────────────────────────────────────────
val LightBackground     = Color(0xFFFAF8F5)
val LightSurface        = Color(0xFFFFFFFF)
val LightSurfaceVariant = Color(0xFFF1EDE6)   // nav
val LightOutline        = Color(0x170F140F)   // hairline, ~9% ink
val LightText           = Color(0xFF0F140F)
val LightTextSecondary  = Color(0x990F140F)   // 60%
val LightAccent         = Color(0xFF8A4A20)   // terracotta — amber fails contrast on cream
val LightAccentNegative = Color(0xFFB0533A)
val LightPositive       = Color(0xFF4F7A3E)

// ── Dark: night sky ──────────────────────────────────────────────────────────
val DarkBackground      = Color(0xFF0F140F)
val DarkSurface         = Color(0xFF1A211A)   // tonal, no borders
val DarkText            = Color(0xFFF2EFE9)
val DarkTextSecondary   = Color(0x99F2EFE9)
val DarkAccent          = Color(0xFFE0B15C)   // amber — dark-only
val DarkAccentNegative  = Color(0xFFC0705A)
val DarkPositive        = Color(0xFF9CCB85)

// ── Constellation: dark in BOTH themes, never wallpaper-themed ───────────────
val SkyTop    = Color(0xFF0F140F)
val SkyBottom = Color(0xFF16211A)
val StarGold  = Color(0xFFE0B15C)
