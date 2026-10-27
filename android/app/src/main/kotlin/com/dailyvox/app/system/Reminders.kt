package com.dailyvox.app.system

import android.app.AlarmManager
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import java.time.ZoneId

/**
 * The daily reminder. Not a nicety on this product: retention is the measured
 * binding constraint, and the iOS reminder shipped defaulted OFF, which makes it
 * one of the few levers never actually pulled.
 *
 * AlarmManager, NOT WorkManager — and that is a permission decision, not a
 * technical preference. Pulling in androidx.work adds four permissions to the
 * merged manifest that this app has no use for:
 *
 *     ACCESS_NETWORK_STATE, WAKE_LOCK, RECEIVE_BOOT_COMPLETED, FOREGROUND_SERVICE
 *
 * ACCESS_NETWORK_STATE is the one that matters. The Settings ledger invites the
 * user to go and check Android's app info, and a privacy-first journal listing a
 * network permission there loses the argument before anyone reads the
 * explanation — even though INTERNET is genuinely absent and no call is ever
 * made. Paying four permissions for one nightly notification is a bad trade.
 *
 * An inexact one-shot alarm needs no permission at all, and it is honest
 * about what it delivers: a window, not a minute. USE_EXACT_ALARM is a
 * restricted permission a journal does not qualify for, so the copy everywhere
 * says "around 9pm" rather than "at 9:00".
 *
 * ONE ALARM AT A TIME, RE-ARMED FROM THE RECEIVER. This used to be
 * setInexactRepeating, which fired every night for as long as the phone stayed
 * up, whether or not the user had opened the app in a month, and slid an hour
 * across every DST change because a repeat is an interval in milliseconds, not
 * a wall-clock time. [ReminderPlan] now decides each next slot from the local
 * calendar and from when the app was last opened.
 *
 * Reboot clears alarms and RECEIVE_BOOT_COMPLETED is deliberately not declared,
 * so the chain is re-armed on every app resume instead. The cost is that a
 * reboot pauses reminders until the next launch, which is the right side of the
 * trade for a permission the ledger would have to explain. A time-zone or clock
 * change needs no permission to hear about, so that one re-arms immediately.
 */
object Reminders {

    private const val CHANNEL = "dailyvox.reminder"
    private const val REQUEST = 4242
    private const val EXTRA_KIND = "kind"
    /** Every notification id this file can post. Cancel walks all of them. */
    private const val ID_DAILY = 42
    // Not 43: the recording chip (and, separately, Goals) already post there,
    // and cancel() must never take down a recording in progress.
    private const val ID_WELCOME_BACK = 44
    const val PREF_ENABLED = "reminder"
    const val PREF_HOUR = "reminderHour"
    /** When the app was last opened; the horizon is counted from here. */
    const val PREF_LAST_OPENED = "reminderLastOpened"
    /**
     * Quote a line from a week ago in the daily reminder. OFF by default and
     * only ever on because the user turned it on: a notification is readable
     * on a locked phone, and a journal's words do not go there unasked.
     */
    const val PREF_QUOTE_PAST = "reminderQuotePast"

    fun quotesPast(context: Context): Boolean = prefs(context).getBoolean(PREF_QUOTE_PAST, false)

    /**
     * Turning the quote off also takes down a reminder already showing one.
     * The switch is about what can be read on the lock screen, and a quote
     * left sitting there after "off" would make the switch a liar. The
     * pending alarm needs nothing: the text is chosen when it fires.
     */
    fun setQuotesPast(context: Context, on: Boolean) {
        prefs(context).edit().putBoolean(PREF_QUOTE_PAST, on).apply()
        if (!on) NotificationManagerCompat.from(context.applicationContext).cancel(ID_DAILY)
    }

    /** Called from the app's own UI, so it is also an "opened" moment. */
    fun schedule(context: Context, hourOfDay: Int) {
        val prefs = prefs(context)
        prefs.edit().putLong(PREF_LAST_OPENED, System.currentTimeMillis()).apply()
        arm(context, hourOfDay)
    }

    /**
     * Turning reminders off takes EVERYTHING with it: the pending alarm, and any
     * reminder already sitting in the shade. A switch that says off while last
     * night's "Tonight's star is waiting" is still on the lock screen is a switch
     * the user stops believing.
     */
    fun cancel(context: Context) {
        val app = context.applicationContext
        app.getSystemService(AlarmManager::class.java)?.cancel(pending(app, null))
        val nm = NotificationManagerCompat.from(app)
        nm.cancel(ID_DAILY)
        nm.cancel(ID_WELCOME_BACK)
    }

    /**
     * Called on every app resume: alarms do not survive a reboot and we do not
     * ask for the permission that would let them. Stamps the open first, so the
     * seven-evening horizon always runs from the most recent visit.
     */
    fun rescheduleIfEnabled(context: Context) {
        val prefs = prefs(context)
        prefs.edit().putLong(PREF_LAST_OPENED, System.currentTimeMillis()).apply()
        if (!prefs.getBoolean(PREF_ENABLED, false)) return
        if (!canPostNotifications(context)) return
        arm(context, prefs.getInt(PREF_HOUR, 21))
    }

    /** On API 33+ a scheduled reminder with no permission is a switch that lies. */
    fun canPostNotifications(context: Context): Boolean =
        android.os.Build.VERSION.SDK_INT < 33 ||
            androidx.core.content.ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.POST_NOTIFICATIONS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED

    /**
     * Sets the ONE pending alarm to whatever [ReminderPlan] says comes next, or
     * clears it when the plan has run out. Does not stamp an open: the receiver
     * calls this too, and a reminder firing is not the user coming back.
     *
     * Same PendingIntent identity as the old repeating alarm, so on an upgrade
     * the first arm replaces it rather than leaving it running alongside.
     */
    internal fun arm(context: Context, hourOfDay: Int, nowMillis: Long = System.currentTimeMillis()) {
        ensureChannel(context)
        val app = context.applicationContext
        val alarms = app.getSystemService(AlarmManager::class.java) ?: return
        val prefs = prefs(app)
        val opened = prefs.getLong(PREF_LAST_OPENED, 0L).takeIf { it > 0L } ?: nowMillis.also {
            // An install upgraded from the repeating alarm has no stamp yet.
            // Count from now rather than from 1970, which would read as lapsed.
            prefs.edit().putLong(PREF_LAST_OPENED, it).apply()
        }

        val fire = ReminderPlan.next(nowMillis, opened, hourOfDay, ZoneId.systemDefault())
        if (fire == null) {
            alarms.cancel(pending(app, null))
            return
        }
        // AllowWhileIdle so Doze defers it by minutes rather than until morning.
        // Still inexact, still no permission.
        alarms.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, fire.atMillis, pending(app, fire.kind))
    }

    private fun prefs(context: Context) =
        context.applicationContext.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)

    /** Extras are not part of PendingIntent identity, so a null kind cancels any. */
    private fun pending(context: Context, kind: ReminderPlan.Kind?): PendingIntent =
        PendingIntent.getBroadcast(
            context, REQUEST,
            Intent(context, ReminderReceiver::class.java)
                .apply { if (kind != null) putExtra(EXTRA_KIND, kind.name) },
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

    private fun ensureChannel(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Daily reminder", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { description = "A nudge to record tonight's entry." }
            )
        }
    }

    class ReminderReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            val prefs = prefs(context)
            val enabled = prefs.getBoolean(PREF_ENABLED, false)
            val hour = prefs.getInt(PREF_HOUR, 21)

            // The clock or the zone moved under a pending alarm. Re-arm for the
            // new local evening; nothing is posted.
            if (intent.action == Intent.ACTION_TIMEZONE_CHANGED ||
                intent.action == Intent.ACTION_TIME_CHANGED) {
                if (enabled && canPostNotifications(context)) arm(context, hour)
                return
            }

            // Reminders were switched off after this alarm was set. cancel()
            // already cleared it; this is the belt to that braces.
            if (!enabled) return

            val kind = intent.getStringExtra(EXTRA_KIND)
                ?.let { runCatching { ReminderPlan.Kind.valueOf(it) }.getOrNull() }
                ?: ReminderPlan.Kind.DAILY

            // SKIP IF ALREADY SPOKEN — FINAL-SPEC C4, "Skips once you've spoken".
            //
            // This is the difference between a reminder and a nag. Firing at
            // 9:30 to tell someone to do the thing they did at 8:15 is how an
            // app teaches people to swipe its notifications away without
            // reading them, and this product's binding constraint is retention.
            //
            // goAsync because the Room read cannot happen on the broadcast
            // thread — the same trap the widget fell into.
            val pending = goAsync()
            io.execute {
                try {
                    val now = System.currentTimeMillis()
                    val zone = ZoneId.systemDefault()
                    val all = runCatching {
                        com.dailyvox.app.data.Repo.get(context).allBlocking()
                    }.getOrDefault(emptyList())
                    val spokenToday = all.any { ReminderPlan.sameLocalDay(it.createdAt, now, zone) }
                    // Read at fire time from the live table, so an entry
                    // deleted since the alarm was set is never quoted.
                    val quote = if (kind == ReminderPlan.Kind.DAILY && prefs.getBoolean(PREF_QUOTE_PAST, false))
                        runCatching { Resurface.weekAgo(all, now, zone)?.excerpt }.getOrNull()
                    else null
                    if (!spokenToday) notify(context, kind, quote)
                    // The chain: one alarm at a time, so the next one is set
                    // here. A minute ahead, so an alarm delivered a hair early
                    // cannot pick tonight's slot a second time.
                    arm(context, hour, now + 60_000L)
                } finally {
                    pending.finish()
                }
            }
        }

        /** [quote] is a verbatim line from a week ago, or null for the generic copy. */
        private fun notify(context: Context, kind: ReminderPlan.Kind, quote: String? = null) {
            // Checked here rather than only at schedule time. The alarm is set
            // while the permission is held and fires days later -- long enough
            // for the user to have revoked notifications, or for Android to have
            // revoked them itself under "manage app if unused", which the
            // permissions screenshot in the README shows switched on by default.
            if (!canPostNotifications(context)) return
            ensureChannel(context)
            val open = PendingIntent.getActivity(
                context, 0,
                Intent(context, com.dailyvox.app.MainActivity::class.java)
                    .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
            )
            // No streak guilt. The empty states make a point of this and a
            // notification is the easiest place in the product to break it.
            // The welcome-back especially: it never says how long it has been.
            val (title, text, id) = when (kind) {
                ReminderPlan.Kind.DAILY -> Triple(
                    com.dailyvox.app.R.string.reminder_title,
                    com.dailyvox.app.R.string.reminder_text, ID_DAILY)
                ReminderPlan.Kind.WELCOME_BACK -> Triple(
                    com.dailyvox.app.R.string.reminder_welcome_back_title,
                    com.dailyvox.app.R.string.reminder_welcome_back_text, ID_WELCOME_BACK)
            }
            val body = quote?.let {
                context.getString(com.dailyvox.app.R.string.reminder_past_text,
                    androidx.core.text.BidiFormatter.getInstance().unicodeWrap(it))
            } ?: context.getString(text)
            val n = NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(com.dailyvox.app.R.drawable.ic_nav_speak)
                .setContentTitle(context.getString(title))
                .setContentText(body)
                .apply { if (quote != null) setStyle(NotificationCompat.BigTextStyle().bigText(body)) }
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            @Suppress("MissingPermission")  // checked at the top of this method
            runCatching { NotificationManagerCompat.from(context).notify(id, n) }
        }

        companion object {
            private val io = java.util.concurrent.Executors.newSingleThreadExecutor()
        }
    }
}
