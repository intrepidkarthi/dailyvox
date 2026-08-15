package com.dailyvox.app.system

import android.content.Context

/**
 * Custom vocabulary — the names and words the recogniser keeps getting wrong.
 *
 * This matters more here than in a generic dictation app. The Twin's entity
 * graph is built from transcribed names, so a recogniser that writes "Adyah" as
 * "idea" does not merely produce a typo — it silently drops a person from the
 * graph, and every later question about them returns nothing. The measured
 * 34.6% name gap on iOS is the same failure.
 *
 * Fed to the recogniser as biasing strings. Biasing is a HINT: it raises the
 * prior on these tokens, it does not guarantee them, and the UI copy says so
 * rather than promising a fix it cannot deliver.
 */
object Vocabulary {

    private const val KEY = "vocabulary"

    fun get(context: Context): List<String> =
        context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)
            .getString(KEY, "")!!
            .split(",").map { it.trim() }.filter { it.isNotEmpty() }

    fun set(context: Context, words: List<String>) {
        context.getSharedPreferences("dailyvox", Context.MODE_PRIVATE)
            .edit().putString(KEY, words.joinToString(",")).apply()
    }

    fun add(context: Context, word: String) {
        val w = word.trim()
        if (w.isEmpty()) return
        val cur = get(context)
        if (cur.any { it.equals(w, ignoreCase = true) }) return
        set(context, cur + w)
    }

    fun remove(context: Context, word: String) {
        set(context, get(context).filterNot { it.equals(word, ignoreCase = true) })
    }
}
