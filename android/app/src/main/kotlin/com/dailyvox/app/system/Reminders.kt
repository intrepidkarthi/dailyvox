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
import java.util.Calendar

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
 * setInexactRepeating needs no permission at all. It is also honest about what
 * it delivers: a window, not a minute. USE_EXACT_ALARM is a restricted
 * permission a journal does not qualify for, so the copy everywhere says
 * "around 9pm" rather than "at 9:00".
 *
 * Reboot clears alarms and RECEIVE_BOOT_COMPLETED is deliberately not declared,
 * so `rescheduleIfEnabled` runs on every app start instead. The cost is at most
 * one missed reminder between a reboot and the next launch, which is the right
 * side of the trade for a permission the ledger would have to explain.
 */
object Reminders {

    private const val CHANNEL = "dailyvox.reminder"
    private const val REQUEST = 4242
    const val PREF_ENABLED = "reminder"
    const val PREF_HOUR = "reminderHour"

    fun schedule(context: Context, hourOfDay: Int) {
        ensureChannel(context)
        val app = context.applicationContext
        val alarms = app.getSystemService(AlarmManager::class.java) ?: return

        val now = Calendar.getInstance()
        val next = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hourOfDay)
            set(Calendar.MINUTE, 0)
            set(Calendar.SECOND, 0)
            set(Calendar.MILLISECOND, 0)
            if (before(now)) add(Calendar.DAY_OF_YEAR, 1)
        }

        alarms.setInexactRepeating(
            AlarmManager.RTC_WAKEUP,
            next.timeInMillis,
            AlarmManager.INTERVAL_DAY,
            pending(app),
        )
    }

    fun cancel(context: Context) {
        val app = context.applicationContext
        app.getSystemService(AlarmManager::class.java)?.cancel(pending(app))
    }

    /** Called on every app start: alarms do not survive a reboot and we do not
     *  ask for the permission that would let them. */
    fun rescheduleIfEnabled(context: Context) {
        val prefs = context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)
        if (!prefs.getBoolean(PREF_ENABLED, false)) return
        if (!canPostNotifications(context)) return
        schedule(context, prefs.getInt(PREF_HOUR, 21))
    }

    /** On API 33+ a scheduled reminder with no permission is a switch that lies. */
    fun canPostNotifications(context: Context): Boolean =
        android.os.Build.VERSION.SDK_INT < 33 ||
            androidx.core.content.ContextCompat.checkSelfPermission(
                context, android.Manifest.permission.POST_NOTIFICATIONS
            ) == android.content.pm.PackageManager.PERMISSION_GRANTED

    private fun pending(context: Context): PendingIntent =
        PendingIntent.getBroadcast(
            context, REQUEST,
            Intent(context, ReminderReceiver::class.java),
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
                    val spokenToday = runCatching {
                        val today = System.currentTimeMillis() / 86_400_000L
                        com.dailyvox.app.data.Repo.get(context).allBlocking()
                            .any { it.createdAt / 86_400_000L == today }
                    }.getOrDefault(false)
                    if (!spokenToday) notify(context)
                } finally {
                    pending.finish()
                }
            }
        }

        private fun notify(context: Context) {
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
            val n = NotificationCompat.Builder(context, CHANNEL)
                .setSmallIcon(com.dailyvox.app.R.drawable.ic_nav_speak)
                .setContentTitle("Tonight's star is waiting")
                // No streak guilt. The empty states make a point of this and a
                // notification is the easiest place in the product to break it.
                .setContentText("Whenever you're ready. Forty-two seconds.")
                .setContentIntent(open)
                .setAutoCancel(true)
                .build()
            @Suppress("MissingPermission")  // checked at the top of this method
            runCatching { NotificationManagerCompat.from(context).notify(42, n) }
        }

        companion object {
            private val io = java.util.concurrent.Executors.newSingleThreadExecutor()
        }
    }
}
