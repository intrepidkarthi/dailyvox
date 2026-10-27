package com.dailyvox.app.data

import android.content.Context
import android.util.Log
import com.dailyvox.app.system.MoodSuggestion
import com.dailyvox.twin.Sentiment

/**
 * Reads the bundled VADER table out of assets and installs it into the engine.
 *
 * PLUMBING. The file is app-side because assets are an app concept; the scoring
 * that consumes it is proprietary and lives in the Twin engine.
 */
object Lexicon {

    private const val ASSET = "vader.txt"
    private const val TAG = "Lexicon"

    /**
     * The installed table, kept app-side as well. The engine scores a whole
     * entry and does not expose per-word scores, and [MoodSuggestion] needs
     * those to tell a mixed entry from a clear one.
     */
    @Volatile var table: Map<String, Float> = emptyMap()
        private set

    fun ensureLoaded(context: Context) {
        if (Sentiment.entryCount > 0 && table.isNotEmpty()) return
        val table = try {
            context.applicationContext.assets.open(ASSET).bufferedReader().useLines {
                Sentiment.parseLexicon(it)
            }
        } catch (t: Throwable) {
            // Loud, not silent. If this fires, every entry scores 0.00 and the
            // mood curve flatlines — a failure that looks exactly like someone
            // having had a neutral month.
            Log.e(TAG, "VADER lexicon failed to load; valence will be 0", t)
            emptyMap()
        }
        this.table = table
        Sentiment.install(table)
    }
}
