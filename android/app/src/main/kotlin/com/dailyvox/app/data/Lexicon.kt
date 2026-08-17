package com.dailyvox.app.data

import android.content.Context
import android.util.Log
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

    fun ensureLoaded(context: Context) {
        if (Sentiment.entryCount > 0) return
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
        Sentiment.install(table)
    }
}
