package com.dailyvox.app.system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.dailyvox.app.MainActivity
import com.dailyvox.app.data.Entry
import java.util.Calendar

/**
 * Weekly journaling goals — the iOS `GoalManager`, ported.
 *
 * Counts **nights, not entries**, the same rule the milestone card already
 * uses: two entries in one evening is one night of showing up, and a target of
 * three should not be satisfiable by talking three times before bed.
 *
 * Off by default. A journal that opens by setting you a quota is a different
 * product from one that waits for you, and the reminder already covers the
 * "please come back" case for anyone who wants it.
 */
object Goals {

    private const val PREF_ENABLED = "dvx_goal_enabled"
    private const val PREF_TARGET = "dvx_goal_target"
    private const val PREF_NOTIFY = "dvx_goal_notify"
    private const val PREF_LAST_MILESTONE = "dvx_last_milestone"
    private const val PREF_LAST_CELEBRATED_WEEK = "dvx_goal_week"
    private const val CHANNEL = "goal"
    private const val NOTIFICATION_ID = 43

    /**
     * Deliberately NOT a second list. `Shareables.MILESTONES` is 42 / 100 / 365
     * on Android — 42 because it is the app's own number — while iOS's
     * `GoalManager` uses 7 / 14 / 30 / 50 / 100 / 200 / 365. The two platforms
     * already disagree about what counts as a milestone, and a user with both
     * phones would be congratulated on different nights.
     *
     * Adding a third list here would have hidden that. Android's share card and
     * Android's goal now agree with each other; the cross-platform difference is
     * real, unresolved, and recorded in ROADMAP.md rather than papered over.
     */
    val MILESTONES: List<Int> get() = Shareables.MILESTONES

    /** Selectable weekly targets. Seven is offered; it is not the default. */
    val TARGETS = listOf(1, 2, 3, 4, 5, 6, 7)

    private const val DEFAULT_TARGET = 3

    private fun prefs(context: Context) =
        context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)

    fun isEnabled(context: Context): Boolean = prefs(context).getBoolean(PREF_ENABLED, false)

    fun setEnabled(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean(PREF_ENABLED, on).apply()

    fun target(context: Context): Int =
        prefs(context).getInt(PREF_TARGET, DEFAULT_TARGET).coerceIn(1, 7)

    fun setTarget(context: Context, n: Int) =
        prefs(context).edit().putInt(PREF_TARGET, n.coerceIn(1, 7)).apply()

    fun notifies(context: Context): Boolean = prefs(context).getBoolean(PREF_NOTIFY, false)

    fun setNotifies(context: Context, on: Boolean) =
        prefs(context).edit().putBoolean(PREF_NOTIFY, on).apply()

    /**
     * Distinct days journalled since this week began, in the device's own
     * locale — `firstDayOfWeek` is Sunday in the US and Monday across most of
     * Europe and India, and a goal that resets on the wrong day is worse than
     * no goal.
     */
    fun nightsThisWeek(entries: List<Entry>, now: Long = System.currentTimeMillis()): Int {
        val start = weekStart(now)
        val cal = Calendar.getInstance()
        return entries.filter { it.createdAt >= start }
            .map {
                cal.timeInMillis = it.createdAt
                cal.get(Calendar.YEAR) * 1000 + cal.get(Calendar.DAY_OF_YEAR)
            }
            .distinct().size
    }

    fun progress(context: Context, entries: List<Entry>, now: Long = System.currentTimeMillis()): Float {
        val t = target(context)
        if (t <= 0) return 0f
        return (nightsThisWeek(entries, now).toFloat() / t).coerceIn(0f, 1f)
    }

    /** Days left in the current week, including today. */
    fun daysLeftInWeek(now: Long = System.currentTimeMillis()): Int {
        val cal = Calendar.getInstance().apply { timeInMillis = now }
        val first = cal.firstDayOfWeek
        val today = cal.get(Calendar.DAY_OF_WEEK)
        // Day-of-week is 1..7 and wraps, so the offset is taken modulo 7.
        val elapsed = ((today - first) + 7) % 7
        return 7 - elapsed
    }

    /**
     * The highest milestone this streak has crossed that has not been
     * celebrated, or null.
     *
     * Highest, not lowest, and recorded once: an ascending scan replayed every
     * historical milestone one visit at a time, so a 32-night streak opened
     * Insights with "7-Day Streak!". That bug shipped on iOS and was fixed in
     * v1.8; this port must not reintroduce it.
     */
    fun milestoneToCelebrate(context: Context, streak: Int): Int? {
        val last = prefs(context).getInt(PREF_LAST_MILESTONE, 0)
        val highest = MILESTONES.lastOrNull { streak >= it } ?: return null
        if (highest <= last) return null
        prefs(context).edit().putInt(PREF_LAST_MILESTONE, highest).apply()
        return highest
    }

    /**
     * Posts once per week, the first time the target is met.
     *
     * The week is stamped rather than a boolean flag: a flag would need
     * clearing on a schedule nothing runs, and the failure mode of forgetting
     * is a goal that congratulates you every time you open the app.
     */
    fun celebrateIfReached(context: Context, entries: List<Entry>, now: Long = System.currentTimeMillis()) {
        if (!isEnabled(context) || !notifies(context)) return
        if (!Reminders.canPostNotifications(context)) return
        val nights = nightsThisWeek(entries, now)
        val t = target(context)
        if (nights < t) return
        val week = weekStart(now)
        val p = prefs(context)
        if (p.getLong(PREF_LAST_CELEBRATED_WEEK, 0L) == week) return
        p.edit().putLong(PREF_LAST_CELEBRATED_WEEK, week).apply()
        post(context, nights, t)
    }

    /** Midnight at the start of the current locale week. */
    private fun weekStart(now: Long): Long {
        val cal = Calendar.getInstance().apply { timeInMillis = now }
        val elapsed = ((cal.get(Calendar.DAY_OF_WEEK) - cal.firstDayOfWeek) + 7) % 7
        cal.add(Calendar.DAY_OF_YEAR, -elapsed)
        cal.set(Calendar.HOUR_OF_DAY, 0); cal.set(Calendar.MINUTE, 0)
        cal.set(Calendar.SECOND, 0); cal.set(Calendar.MILLISECOND, 0)
        return cal.timeInMillis
    }

    @android.annotation.SuppressLint("MissingPermission")
    private fun post(context: Context, nights: Int, target: Int) {
        // Guarded in celebrateIfReached by Reminders.canPostNotifications,
        // which lint cannot follow into.
        ensureChannel(context)
        val open = PendingIntent.getActivity(
            context, 43, Intent(context, MainActivity::class.java),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val n = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(com.dailyvox.app.R.drawable.ic_nav_speak)
            .setContentTitle("That is your week.")
            // No exclamation, no "keep it up". The reminder copy makes a point
            // of not trading in streak guilt and this is the same product.
            .setContentText(
                if (nights == target) "$nights nights, which is what you set out to do."
                else "$nights nights this week, past the $target you set."
            )
            .setContentIntent(open)
            .setAutoCancel(true)
            .build()
        runCatching { NotificationManagerCompat.from(context).notify(NOTIFICATION_ID, n) }
    }

    private fun ensureChannel(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Weekly goal", NotificationManager.IMPORTANCE_LOW)
                    .apply { description = "Posted once, the week you reach your goal." }
            )
        }
    }
}
