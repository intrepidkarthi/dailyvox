package com.dailyvox.app.system

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import androidx.core.app.NotificationCompat
import androidx.work.*
import java.util.Calendar
import java.util.concurrent.TimeUnit

/**
 * The daily reminder — and on this product it is not a nicety. Retention is the
 * measured binding constraint, and the iOS reminder shipped defaulted OFF, which
 * is one of the few levers never actually pulled.
 *
 * WINDOWED, NOT EXACT, and the copy has to match. USE_EXACT_ALARM is restricted
 * and Play blocks apps that do not qualify, so this promises "around 9pm", never
 * "at 9:00". Promising a minute and delivering a window is how an app teaches
 * people to distrust its notifications.
 */
object Reminders {

    private const val CHANNEL = "dailyvox.reminder"
    private const val WORK = "dailyvox.daily-reminder"

    fun schedule(context: Context, hourOfDay: Int) {
        ensureChannel(context)
        val now = Calendar.getInstance()
        val next = (now.clone() as Calendar).apply {
            set(Calendar.HOUR_OF_DAY, hourOfDay); set(Calendar.MINUTE, 0); set(Calendar.SECOND, 0)
            if (before(now)) add(Calendar.DAY_OF_YEAR, 1)
        }
        val delay = next.timeInMillis - now.timeInMillis

        WorkManager.getInstance(context).enqueueUniquePeriodicWork(
            WORK,
            ExistingPeriodicWorkPolicy.UPDATE,
            PeriodicWorkRequestBuilder<ReminderWorker>(1, TimeUnit.DAYS)
                .setInitialDelay(delay, TimeUnit.MILLISECONDS)
                .build(),
        )
    }

    fun cancel(context: Context) {
        WorkManager.getInstance(context).cancelUniqueWork(WORK)
    }

    private fun ensureChannel(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java)
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Daily reminder", NotificationManager.IMPORTANCE_DEFAULT)
                    .apply { description = "A nudge to record tonight's entry." }
            )
        }
    }

    class ReminderWorker(ctx: Context, params: WorkerParameters) : Worker(ctx, params) {
        override fun doWork(): Result {
            ensureChannel(applicationContext)
            val n = NotificationCompat.Builder(applicationContext, CHANNEL)
                .setSmallIcon(com.dailyvox.app.R.drawable.ic_nav_speak)
                .setContentTitle("Tonight's forty-two seconds")
                // No streak guilt. The iOS empty states make a point of this and
                // a notification is the easiest place to break it.
                .setContentText("Whenever you're ready.")
                .setAutoCancel(true)
                .build()
            runCatching {
                androidx.core.app.NotificationManagerCompat.from(applicationContext).notify(42, n)
            }
            return Result.success()
        }
    }
}
