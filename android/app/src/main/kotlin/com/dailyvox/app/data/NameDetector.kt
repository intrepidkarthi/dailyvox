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
 * spans (docs/ner-on-real-diary-2026-08-15.md): 99.1% untyped recall at 61.6%
 * precision, against NLTagger's 94.6% / 32.5% -- and it found 100% of the
 * non-Anglo names where Apple's model found 97.7%. Both fixes below are in the
 * Swift arm too, and 61.6% is the re-measurement after them -- the pre-fix
 * algorithm scored 62.4%, and that doc explains why the higher number belongs to
 * the worse detector. That corpus was Apple's
 * transcription output; whether Android's recogniser cases names the same way is
 * the one untested assumption, and this whole file rests on it.
 *
 * Three corpus-level signals, no weights:
 *   1. capitalised mid-sentence somewhere in the corpus
 *   2. never seen lowercase anywhere
 *   3. consecutive capitals WITHIN ONE SENTENCE are one entity
 *
 * The known cost of signal 1 is small corpora. A first-ever mention that happens
 * to open its sentence ("Priya sent photos from the wedding.") is missed, because
 * nothing else in the corpus attests it. That self-corrects as the journal grows
 * -- across hundreds of entries a real name recurs mid-sentence, while "walked"
 * and "quiet" turn up lowercase and are excluded -- but on a fresh install the
 * detector is at its weakest, which is the opposite of what a new user expects.
 */
object NameDetector {

    private val functionWords = setOf(
        "i","a","an","the","my","we","he","she","they","it","this","that","there","then",
        "and","but","or","so","if","when","while","after","before","today","tomorrow",
        "yesterday","no","yes","not","all","some","every","each","both","her","his","our",
        "your","their","its","you","me","him","them","us","what","who","how","why","where",
        "which","just","very","still","even","also","one","two","three","first","last",
        "next","another","much","many",
        // Contractions tokenise as ONE word, so "i" in this list never matches
        // "I'm". Seeing "I'm" chipped as a person on the running app is what
        // surfaced this -- the measurement corpus happened not to start a
        // sentence with one.
        "i'm","i've","i'll","i'd","it's","that's","there's","they're","we're",
        "he's","she's","we've","you're","don't","didn't","can't","won't","isn't",
        // Calendar words are capitalised by convention and are never lowercase,
        // so every corpus signal this file has says they are names. "Quiet
        // Sunday. Cooked properly..." was filed as a PERSON on the running app.
        "monday","tuesday","wednesday","thursday","friday","saturday","sunday",
        "january","february","march","april","may","june","july","august",
        "september","october","november","december",
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
            val k = canonical(w.text.lowercase())
            if (w.text.firstOrNull()?.isUpperCase() == true) { if (!w.initial) midSentence.add(k) }
            else seenLower.add(k)
        }
        return midSentence to seenLower
    }

    fun detect(text: String, corpus: List<Entry>): List<String> {
        val (mid, lower) = vocabulary(corpus.map { it.text } + text)
        return extract(text, mid, lower)
    }

    /** "Sarah's" and "Sarah" are one person. Without this the graph silently
     *  splits them into two nodes and every count is wrong. */
    private fun canonical(w: String): String =
        w.removeSuffix("'s").removeSuffix("’s").removeSuffix("'").removeSuffix("’")

    fun extract(text: String, midSentence: Set<String>, seenLower: Set<String>): List<String> {
        val out = LinkedHashSet<String>()
        val run = mutableListOf<String>()
        fun flush() {
            if (run.isNotEmpty()) out.add(canonical(run.joinToString(" ")))
            run.clear()
        }
        for (w in words(text)) {
            // A name never spans a full stop. Without this the run survived the
            // sentence boundary and "Quiet Sunday. Cooked properly" came out as
            // the single entity "Quiet Sunday Cooked".
            if (w.initial) flush()

            val k = w.text.lowercase()
            if (w.text.firstOrNull()?.isUpperCase() != true || k in functionWords) { flush(); continue }
            val key = canonical(k)
            val neverLower = key !in seenLower

            // STRICT arm, now applied PER TOKEN rather than per run. Evidence
            // used to accumulate across the whole run, so one real name dragged
            // its neighbours in with it -- "Told Sarah about the job" was filed
            // as a person called "Told Sarah", because Sarah's evidence covered
            // the sentence-initial verb sitting in front of her.
            //
            // A capitalised token counts only if it is never seen lowercase AND
            // either sits mid-sentence here or is attested mid-sentence
            // elsewhere in the corpus. Sentence-initial capitalisation is
            // grammar, not evidence.
            val plausible = neverLower && (!w.initial || midSentence.contains(key))
            if (!plausible) { flush(); continue }
            run.add(w.text)
        }
        flush()
        return out.toList()
    }
}
