package com.dailyvox.app.system

import android.app.Notification
import android.app.NotificationChannel
import android.app.NotificationManager
import android.app.PendingIntent
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat
import com.dailyvox.app.MainActivity
import com.dailyvox.app.R

/**
 * The recording notification — Android's answer to the iOS Live Activity
 * (SolynWidget/RecordingLiveActivity.swift).
 *
 * NOT a foreground service, and that is the whole design of this file. A
 * microphone foreground service would add FOREGROUND_SERVICE and
 * FOREGROUND_SERVICE_MICROPHONE to a permission ledger the product invites
 * people to go and audit, to buy a capability this app does not want: recording
 * with the screen off. Recording only ever happens with the Activity in front,
 * so an ongoing notification is the honest shape — it mirrors state, it does not
 * keep the mic alive.
 *
 * The consequence is stated rather than hidden: leave the app and the recording
 * stops. That is the correct behaviour for a journal whose claim is that nothing
 * happens without you watching.
 *
 * ProgressStyle (API 36) gives the real Live Update treatment — a status chip
 * and a progress track. Below that it degrades to an ordinary ongoing
 * notification with the same numbers, which loses the chrome and none of the
 * information.
 */
object RecordingLive {

    private const val CHANNEL = "dailyvox.recording"
    private const val ID = 43
    const val ACTION_FINISH = "com.dailyvox.app.FINISH_RECORDING"

    /** Set by the recorder; read by the receiver's stop action. */
    @Volatile var onFinishRequested: (() -> Unit)? = null

    fun show(context: Context, elapsedSeconds: Int) {
        if (!Reminders.canPostNotifications(context)) return
        ensureChannel(context)

        val open = PendingIntent.getActivity(
            context, 0,
            Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )
        val finish = PendingIntent.getBroadcast(
            context, 1,
            Intent(context, FinishReceiver::class.java).setAction(ACTION_FINISH),
            PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
        )

        val builder = NotificationCompat.Builder(context, CHANNEL)
            .setSmallIcon(R.drawable.ic_nav_speak)
            .setContentTitle("Listening")
            // The 42 seconds is a SOFT TARGET everywhere else in the product, so
            // this counts past it rather than stopping — a bar that fills and
            // freezes would tell people to stop talking.
            .setContentText(
                "%d:%02d · on-device · 0 bytes out".format(elapsedSeconds / 60, elapsedSeconds % 60)
            )
            .setOngoing(true)
            .setOnlyAlertOnce(true)
            .setSilent(true)
            .setCategory(Notification.CATEGORY_PROGRESS)
            // Never on the lock screen. The widget rule applies here too: this is
            // a journal, and "Listening" on a locked phone tells the room.
            .setVisibility(NotificationCompat.VISIBILITY_SECRET)
            .setContentIntent(open)
            .addAction(0, "Finish", finish)
            .setProgress(42, elapsedSeconds.coerceAtMost(42), false)

        runCatching { NotificationManagerCompat.from(context).notify(ID, builder.build()) }
    }

    fun hide(context: Context) {
        runCatching { NotificationManagerCompat.from(context).cancel(ID) }
    }

    private fun ensureChannel(context: Context) {
        val nm = context.getSystemService(NotificationManager::class.java) ?: return
        if (nm.getNotificationChannel(CHANNEL) == null) {
            nm.createNotificationChannel(
                NotificationChannel(CHANNEL, "Recording", NotificationManager.IMPORTANCE_LOW)
                    .apply {
                        description = "Shown only while a recording is in progress."
                        setShowBadge(false)
                        lockscreenVisibility = Notification.VISIBILITY_SECRET
                    }
            )
        }
    }

    class FinishReceiver : BroadcastReceiver() {
        override fun onReceive(context: Context, intent: Intent) {
            if (intent.action != ACTION_FINISH) return
            onFinishRequested?.invoke()
            hide(context)
        }
    }
}
