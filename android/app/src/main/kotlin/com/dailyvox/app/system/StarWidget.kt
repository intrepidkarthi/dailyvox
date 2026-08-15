package com.dailyvox.app.system

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.ComponentName
import android.content.Context
import android.content.Intent
import android.widget.RemoteViews
import com.dailyvox.app.MainActivity
import com.dailyvox.app.R
import com.dailyvox.app.data.Repo

/**
 * "Tonight's star" home-screen widget.
 *
 * Built on RemoteViews rather than Glance, and that is a size decision, not a
 * taste one: glance-appwidget pulls Compose runtime into a separate process for
 * roughly 1.5MB of APK, against a hard <10MB budget that iOS meets. The widget
 * draws a star, a seven-night dot strip and a count — RemoteViews covers all of
 * it for the cost of two XML layouts.
 *
 * IT NEVER RENDERS ENTRY TEXT. Widgets are visible on the lock screen, so a
 * journal that shows a sentence there has broken its own privacy claim in the
 * most public place on the device. Star, dots, counts. Nothing readable.
 */
class StarWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        ids.forEach { id -> manager.updateAppWidget(id, build(context)) }
    }

    companion object {
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, StarWidget::class.java))
            if (ids.isEmpty()) return
            val views = build(context)
            ids.forEach { manager.updateAppWidget(it, views) }
        }

        private fun build(context: Context): RemoteViews {
            val views = RemoteViews(context.packageName, R.layout.widget_star)

            // Read straight from Room on the broadcast thread. onUpdate already
            // runs off the main thread, and a widget that renders empty while a
            // coroutine resolves is worse than one that blocks for 3ms.
            val entries = runCatching { Repo.get(context).allBlocking() }.getOrDefault(emptyList())
            val today = System.currentTimeMillis() / 86_400_000L
            val days = entries.map { it.createdAt / 86_400_000L }.toSet()
            val spokenTonight = today in days

            views.setImageViewResource(
                R.id.widget_star,
                if (spokenTonight) R.drawable.ic_star_filled else R.drawable.ic_star_hollow,
            )
            // No guilt copy. An empty night is stated, never scolded — the same
            // rule the in-app empty states follow.
            views.setTextViewText(
                R.id.widget_label,
                if (spokenTonight) "Tonight is filed" else "Tonight is waiting",
            )
            views.setTextViewText(R.id.widget_count, "${entries.size}")

            val dots = intArrayOf(R.id.d0, R.id.d1, R.id.d2, R.id.d3, R.id.d4, R.id.d5, R.id.d6)
            (0..6).forEach { i ->
                views.setImageViewResource(
                    dots[i],
                    if ((today - (6 - i)) in days) R.drawable.dot_full else R.drawable.dot_empty,
                )
            }

            views.setOnClickPendingIntent(
                R.id.widget_root,
                PendingIntent.getActivity(
                    context, 0,
                    Intent(context, MainActivity::class.java)
                        .putExtra("start_recording", true)
                        .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK or Intent.FLAG_ACTIVITY_CLEAR_TOP),
                    PendingIntent.FLAG_IMMUTABLE or PendingIntent.FLAG_UPDATE_CURRENT,
                ),
            )
            return views
        }
    }
}
