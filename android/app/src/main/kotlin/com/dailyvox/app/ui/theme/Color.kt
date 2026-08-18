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
//
// Retuned for CONTRAST. The first pass was technically the spec's values and
// rendered as mud: cards at #1A211A sat almost on top of a #0F140F ground, so
// nothing had edges, and every accent was used at low opacity. Direction 1c —
// the design package's actual recommendation — is not subtle. It has a bright
// amber record disc, a solid amber nav pill and clearly lifted surfaces.
//
// The ground goes darker and the surfaces lighter so they separate; amber gets
// brighter so it reads as the action colour rather than a tint.
val DarkBackground      = Color(0xFF0A0D0A)   // deeper, so surfaces can lift
val DarkSurface         = Color(0xFF1C241C)   // clearly above the ground
val DarkSurfaceHigh     = Color(0xFF273127)   // pressed / active states
val DarkText            = Color(0xFFF4F1E8)
val DarkTextSecondary   = Color(0xB3F4F1E8)   // 70%, was 60% and read as grey mush
val DarkAccent          = Color(0xFFF0BE63)   // brighter amber — this is the ACTION colour
val DarkAccentDim       = Color(0xFF8A6E33)
val DarkAccentNegative  = Color(0xFFD4816A)
val DarkPositive        = Color(0xFFA8D98C)

// ── Constellation: dark in BOTH themes, never wallpaper-themed ───────────────
val SkyTop    = Color(0xFF0F140F)
val SkyBottom = Color(0xFF16211A)
val StarGold  = Color(0xFFF0BE63)
