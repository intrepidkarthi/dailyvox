package com.dailyvox.app.data

import kotlin.math.abs

/**
 * Lexicon valence, the Android replacement for NLTagger's sentimentScore.
 *
 * Android has no OS sentiment API, and the licence-clean LEARNED replacement is
 * already known to fail: the GoEmotions-trained head lost its gate twice, and a
 * 10-configuration sweep found no passing setting (TwinFidelityReport S13). The
 * reason is register -- a head carries whatever prior its training corpus had.
 * A lexicon has no corpus, so it has no prior to mis-transfer, which is why this
 * approach transfers where the head did not.
 *
 * MEASURED against the same 1,459 human-labelled diary entries Apple's scorer was
 * measured on (docs/android-port-blockers-2026-08-14.md): VADER r = +0.663 and
 * 87.1% sign accuracy, against NLTagger's +0.594 and 79.8%. Both shuffled
 * controls collapsed to chance.
 *
 * THIS FILE IS NOW THAT RESULT. The full lexicon ships as `assets/vader.txt`
 * — 7,517 entries, 101 KB of text that deflates to 30 KB inside the APK — so
 * the scorer here is the one the +0.663 was measured on rather than a subset
 * standing in for it.
 *
 * The lexicon is DATA, not code, and deliberately stays a plain sorted TSV: it
 * shows up in a diff, anyone can check a word against the published table, and
 * the APK compresses it anyway. A binary blob would save ~10 KB and cost that.
 */
object Sentiment {

    private const val ASSET = "vader.txt"
    private const val TAG = "Sentiment"

    @Volatile private var lexicon: Map<String, Float> = emptyMap()

    /**
     * Parses the bundled TSV. Kept separate from asset loading so a JVM unit
     * test can read the very same file off disk — that test is what catches the
     * only realistic failure here, which is the asset not being packaged.
     */
    fun parseLexicon(lines: Sequence<String>): Map<String, Float> {
        val out = HashMap<String, Float>(8192)
        lines.forEach { line ->
            val tab = line.indexOf('\t')
            if (tab <= 0) return@forEach
            val word = line.substring(0, tab)
            val score = line.substring(tab + 1).trim().toFloatOrNull() ?: return@forEach
            out[word] = score
        }
        return out
    }

    /** Idempotent; safe to call from anywhere that has a Context. */
    fun ensureLoaded(context: android.content.Context) {
        if (lexicon.isNotEmpty()) return
        synchronized(this) {
            if (lexicon.isNotEmpty()) return
            lexicon = try {
                context.applicationContext.assets.open(ASSET).bufferedReader().useLines {
                    parseLexicon(it)
                }
            } catch (t: Throwable) {
                // Loud, not silent. If this ever fires every entry scores 0.00
                // and the mood curve flatlines, which is exactly the kind of
                // failure that looks like "the user had a neutral month".
                android.util.Log.e(TAG, "VADER lexicon failed to load; valence will be 0", t)
                emptyMap()
            }
        }
    }

    val entryCount: Int get() = lexicon.size

    private val negators = setOf("not", "no", "never", "cannot", "cant", "can't", "didnt", "didn't", "wasnt", "wasn't", "dont", "don't")
    private val boosters = mapOf("very" to 1.3f, "really" to 1.3f, "so" to 1.2f, "extremely" to 1.5f, "quite" to 1.1f, "slightly" to 0.7f, "a" to 1f)

    /** Compound valence in -1..1, VADER's normalisation: x / sqrt(x^2 + 15). */
    fun valence(text: String): Float = valence(text, lexicon)

    /** Testable overload — the scoring rules with an explicit table. */
    fun valence(text: String, table: Map<String, Float>): Float {
        val tokens = text.lowercase().split(Regex("[^a-z']+")).filter { it.isNotEmpty() }
        var sum = 0f
        tokens.forEachIndexed { i, t ->
            var v = table[t] ?: return@forEachIndexed
            if (i > 0) {
                boosters[tokens[i - 1]]?.let { v *= it }
                if (tokens[i - 1] in negators) v *= -0.74f       // VADER's negation factor
            }
            if (i > 1 && tokens[i - 2] in negators) v *= -0.74f
            sum += v
        }
        if (sum == 0f) return 0f
        return (sum / kotlin.math.sqrt(sum * sum + 15f)).coerceIn(-1f, 1f)
    }
}
