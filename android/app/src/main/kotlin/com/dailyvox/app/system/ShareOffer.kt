package com.dailyvox.app.system

import android.content.Context
import java.time.ZoneId

/**
 * When to offer the Story card: once each after nights 7, 21 and 42.
 *
 * THE RULES, all in [due] so they are tested on the JVM:
 *
 *  - Nights are distinct LOCAL days with an entry -- the same count as the
 *    streak's "days spoken" and the milestone card ([Streak.localDay]).
 *  - It is offered after the save that MAKES that night: the saved entry has to
 *    land on a local day that had no entry yet, and bring the count to exactly
 *    7, 21 or 42. A second entry the same evening never re-offers, and a jump
 *    past a number (an imported backup) does not offer a stale "Seven nights".
 *  - Each number is offered at most once, ever. It is recorded as shown the
 *    moment it is put on screen, so Share, Not now, or simply leaving all
 *    count the same.
 *  - Never during onboarding.
 *  - Never when "Offer to share milestones" is off. It defaults to on.
 *
 * No streak guilt: nothing here reacts to a missed night, and there is no
 * reminder that an offer was declined.
 */
object ShareOffer {

    val NIGHTS = listOf(7, 21, 42)

    const val PREF_ENABLED = "dvx_share_offer_enabled"
    private const val PREF_SHOWN = "dvx_share_offers_shown"

    /**
     * The night to offer after saving an entry at [savedAt], or null.
     *
     * @param before createdAt of every entry that existed before this save.
     */
    fun due(
        before: Collection<Long>,
        savedAt: Long,
        zone: ZoneId,
        shown: Set<Int>,
        enabled: Boolean,
        onboarding: Boolean,
    ): Int? {
        if (!enabled || onboarding) return null
        val days = before.mapTo(HashSet()) { Streak.localDay(it, zone) }
        if (Streak.localDay(savedAt, zone) in days) return null
        val nights = days.size + 1
        return nights.takeIf { it in NIGHTS && it !in shown }
    }

    private fun prefs(context: Context) =
        context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean(PREF_ENABLED, true)

    fun setEnabled(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean(PREF_ENABLED, on).apply()

    fun shown(context: Context): Set<Int> =
        prefs(context).getStringSet(PREF_SHOWN, emptySet()).orEmpty()
            .mapNotNull { it.toIntOrNull() }.toSet()

    fun markShown(context: Context, night: Int) {
        val next = (shown(context) + night).map { it.toString() }.toSet()
        prefs(context).edit().putStringSet(PREF_SHOWN, next).apply()
    }
}
