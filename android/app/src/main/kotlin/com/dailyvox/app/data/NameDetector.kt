package com.dailyvox.app.data

/**
 * Name detection with no model, ported from the Swift heuristic in
 * TwinEvalCore/HeuristicNER.swift.
 *
 * Android has no OS name recogniser -- ML Kit's entity extraction explicitly does
 * not do person names -- and the good open NER models inherit CoNLL-2003 or
 * OntoNotes, both of which restrict commercial use. So this is not a stopgap for
 * a model we intend to add; it is the measured replacement.
 *
 * MEASURED, on 28 real transcribed diary entries with 111 hand-annotated gold
 * spans (docs/ner-on-real-diary-2026-08-15.md): 99.1% untyped recall at 62.4%
 * precision, against NLTagger's 94.6% / 32.5% -- and it found 100% of the
 * non-Anglo names where Apple's model found 97.7%. That corpus was Apple's
 * transcription output; whether Android's recogniser cases names the same way is
 * the one untested assumption, and this whole file rests on it.
 *
 * Three corpus-level signals, no weights:
 *   1. capitalised mid-sentence somewhere in the corpus
 *   2. never seen lowercase anywhere
 *   3. consecutive capitals are one entity
 */
object NameDetector {

    private val functionWords = setOf(
        "i","a","an","the","my","we","he","she","they","it","this","that","there","then",
        "and","but","or","so","if","when","while","after","before","today","tomorrow",
        "yesterday","no","yes","not","all","some","every","each","both","her","his","our",
        "your","their","its","you","me","him","them","us","what","who","how","why","where",
        "which","just","very","still","even","also","one","two","three","first","last",
        "next","another","much","many",
    )

    private data class Word(val text: String, val initial: Boolean)

    private fun words(text: String): List<Word> {
        val out = mutableListOf<Word>()
        var initial = true
        val cur = StringBuilder()
        fun flush() {
            if (cur.isNotEmpty()) { out.add(Word(cur.toString(), initial)); initial = false; cur.clear() }
        }
        for (ch in text) {
            if (ch.isLetter() || ch == '\'' || ch == '’') cur.append(ch)
            else { flush(); if (ch == '.' || ch == '!' || ch == '?' || ch == '\n') initial = true }
        }
        flush()
        return out
    }

    /** Pass 1: what the whole corpus says about each token. */
    fun vocabulary(texts: List<String>): Pair<Set<String>, Set<String>> {
        val midSentence = mutableSetOf<String>()
        val seenLower = mutableSetOf<String>()
        for (t in texts) for (w in words(t)) {
            val k = w.text.lowercase()
            if (w.text.firstOrNull()?.isUpperCase() == true) { if (!w.initial) midSentence.add(k) }
            else seenLower.add(k)
        }
        return midSentence to seenLower
    }

    fun detect(text: String, corpus: List<Entry>): List<String> {
        val (mid, lower) = vocabulary(corpus.map { it.text } + text)
        return extract(text, mid, lower)
    }

    fun extract(text: String, midSentence: Set<String>, seenLower: Set<String>): List<String> {
        val out = LinkedHashSet<String>()
        val run = mutableListOf<String>()
        var evidence = false
        fun flush() {
            if (run.isNotEmpty() && evidence) out.add(run.joinToString(" "))
            run.clear(); evidence = false
        }
        for (w in words(text)) {
            val k = w.text.lowercase()
            if (w.text.firstOrNull()?.isUpperCase() != true || k in functionWords) { flush(); continue }
            val neverLower = k !in seenLower
            run.add(w.text)
            // Relaxed arm: never-seen-lowercase alone counts. It recovers names
            // that only ever appear sentence-initially, which is common in short
            // spoken entries and invisible to the strict rule.
            if (neverLower || (midSentence.contains(k) && neverLower)) evidence = true
        }
        flush()
        return out.toList()
    }
}
