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
/**
 * The 4x2 variant (§5): mic circle, day line, seven-night strip, sky count.
 *
 * A separate provider rather than a resize of the 2x2, because the two show
 * different things — the small one is a star and nothing else, which is the
 * spec's own split.
 */
class WideStarWidget : AppWidgetProvider() {
    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        val pending = goAsync()
        StarWidget.io.execute {
            try {
                val views = StarWidget.buildWide(context)
                ids.forEach { manager.updateAppWidget(it, views) }
            } catch (t: Throwable) {
                android.util.Log.e("WideStarWidget", "widget update failed", t)
            } finally {
                pending.finish()
            }
        }
    }
}

class StarWidget : AppWidgetProvider() {

    override fun onUpdate(context: Context, manager: AppWidgetManager, ids: IntArray) {
        // goAsync, because the Room read below CANNOT happen on this thread.
        // onUpdate arrives via onReceive, which runs on the app's main thread,
        // and Room throws on a main-thread query unless allowMainThreadQueries
        // is set (it is not, deliberately).
        val pending = goAsync()
        io.execute {
            try {
                val views = build(context)
                ids.forEach { manager.updateAppWidget(it, views) }
            } catch (t: Throwable) {
                android.util.Log.e(TAG, "widget update failed", t)
            } finally {
                pending.finish()
            }
        }
    }

    companion object {
        private const val TAG = "StarWidget"
        internal val io = java.util.concurrent.Executors.newSingleThreadExecutor()

        /** Called after every write. Callers are on the main thread
         *  (viewModelScope), so the read is handed off here rather than there. */
        fun refresh(context: Context) {
            val manager = AppWidgetManager.getInstance(context)
            val ids = manager.getAppWidgetIds(ComponentName(context, StarWidget::class.java))
            val wideIds = manager.getAppWidgetIds(ComponentName(context, WideStarWidget::class.java))
            if (ids.isEmpty() && wideIds.isEmpty()) return
            val app = context.applicationContext
            io.execute {
                try {
                    if (wideIds.isNotEmpty()) {
                        val wideViews = build(app, wide = true)
                        wideIds.forEach { manager.updateAppWidget(it, wideViews) }
                    }
                    if (ids.isEmpty()) return@execute
                    val views = build(app)
                    ids.forEach { manager.updateAppWidget(it, views) }
                } catch (t: Throwable) {
                    android.util.Log.e(TAG, "widget refresh failed", t)
                }
            }
        }

        /**
         * Bundled type on a RemoteViews surface.
         *
         * `android:fontFamily` in the layout does not work here: a widget is
         * inflated in the LAUNCHER's process, which cannot resolve this app's
         * font resources, so it silently falls back to Roboto — which is what
         * the widget had been rendering in, against a spec that says the three
         * faces ship on both platforms and nothing falls back (§8.2).
         *
         * A `TypefaceSpan` carrying a real `Typeface` crosses the process
         * boundary inside the parcelled `Spanned`, so this is the only way.
         * API 28+ for the Typeface constructor; below that it degrades to the
         * platform face rather than failing.
         */
        private fun styled(context: Context, text: String, fontRes: Int): CharSequence {
            if (android.os.Build.VERSION.SDK_INT < 28) return text
            val typeface = runCatching {
                androidx.core.content.res.ResourcesCompat.getFont(context, fontRes)
            }.getOrNull() ?: return text
            return android.text.SpannableString(text).apply {
                setSpan(android.text.style.TypefaceSpan(typeface), 0, length,
                        android.text.Spannable.SPAN_EXCLUSIVE_EXCLUSIVE)
            }
        }

        private fun build(context: Context, wide: Boolean = false): RemoteViews {
            val views = RemoteViews(
                context.packageName,
                if (wide) R.layout.widget_star_wide else R.layout.widget_star,
            )

            // Deliberately NOT wrapped. An earlier version swallowed the read
            // into an empty list, which turned a main-thread violation into a
            // widget that rendered "tonight is waiting · 0" forever and reported
            // nothing anywhere. A throw here skips the update and leaves the
            // last good content on screen, which is the honest failure.
            val entries = Repo.get(context).allBlocking()
            val today = System.currentTimeMillis() / 86_400_000L
            val days = entries.map { it.createdAt / 86_400_000L }.toSet()
            val spokenTonight = today in days

            if (!wide) {
                views.setImageViewResource(
                    R.id.widget_star,
                    if (spokenTonight) R.drawable.ic_star_filled else R.drawable.ic_star_hollow,
                )
            }

            // No guilt copy. An empty night is stated, never scolded — the same
            // rule the in-app empty states follow.
            val streak = generateSequence(if (spokenTonight) today else today - 1) { it - 1 }
                .takeWhile { it in days }
                .count()
            val label = when {
                spokenTonight && streak > 0 -> "Day $streak · spoken"
                spokenTonight -> "Spoken tonight"
                streak > 0 -> "Day ${streak + 1} · speak tonight"
                else -> "Speak tonight"
            }
            views.setTextViewText(
                R.id.widget_label,
                styled(context, if (wide) label else
                    if (spokenTonight) "Tonight is filed" else "Tonight is waiting",
                    R.font.nunito_variable),
            )
            views.setTextViewText(
                R.id.widget_count,
                styled(context,
                       if (wide) "${entries.size} IN YOUR SKY" else "${entries.size}",
                       R.font.dm_mono_medium),
            )

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

        internal fun buildWide(context: Context): RemoteViews = build(context, wide = true)
    }
}
