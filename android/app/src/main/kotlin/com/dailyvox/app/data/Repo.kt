package com.dailyvox.app.data

import android.content.Context
import androidx.room.Room
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.util.UUID

private val STOP = setOf(
    "the","and","for","was","were","this","that","with","from","have","has","had","not",
    "but","are","you","your","his","her","she","him","they","them","their","its","our",
    "about","just","then","than","when","what","who","how","why","all","some","been",
    "will","would","could","should","did","does","done","get","got","out","one","two",
)

class Repo private constructor(private val db: DailyVoxDb) {

    fun observeAll(): Flow<List<Entry>> = db.entries().observeAll()
    /**
     * Content-word overlap, ranked. Not embeddings yet -- but it IS the lexical
     * leg the iOS hybrid retriever already weights at 60%, so the "search by
     * meaning" label describes a real subset of shipped behaviour rather than
     * something the code does not do. Substring matching, which this replaces,
     * missed "nervous" for a query of "anxious about Sarah" while matching any
     * entry containing the letters in sequence.
     */
    fun search(q: String): Flow<List<Entry>> = db.entries().observeAll().map { all ->
        val terms = contentWords(q)
        if (terms.isEmpty()) return@map all
        all.map { e ->
            val hay = contentWords(e.text) + e.entityList.map { it.lowercase() }
            val overlap = terms.count { t -> hay.any { it.startsWith(t) || t.startsWith(it) } }
            e to overlap / terms.size.toFloat()
        }.filter { it.second > 0f }
         .sortedByDescending { it.second }
         .map { it.first }
    }

    private fun contentWords(t: String): Set<String> =
        t.lowercase().split(Regex("[^a-z0-9']+"))
            .filter { it.length >= 3 && it !in STOP }
            .toSet()
    fun allBlocking(): List<Entry> = db.entries().allBlocking()
    suspend fun byId(id: String) = db.entries().byId(id)

    suspend fun setSelfLabel(id: String, label: String?) {
        db.entries().byId(id)?.let { db.entries().upsert(it.copy(selfLabel = label)) }
    }

    suspend fun attachPhoto(id: String, path: String?) {
        db.entries().byId(id)?.let { db.entries().upsert(it.copy(photoPath = path)) }
    }

    /**
     * Import from a DailyVox JSON export -- either platform's.
     *
     * Deliberately ADDITIVE, never replacing. An import that wipes the journal
     * to match a file is one mis-tap from destroying twenty years of diary, and
     * the recovery story for that is nothing. Duplicates are filtered on
     * (timestamp, text) rather than id, because the iOS export writes Core Data
     * UUIDs this database has never seen.
     */
    suspend fun importJson(json: String): Int = withContext(Dispatchers.IO) {
        val arr = org.json.JSONObject(json).optJSONArray("entries") ?: return@withContext 0
        val existing = db.entries().allOnce().map { it.createdAt to it.text }.toSet()
        var added = 0
        for (i in 0 until arr.length()) {
            val o = arr.getJSONObject(i)
            val text = o.optString("text")
            val at = o.optLong("date", 0L)
            if (text.isBlank() || at == 0L || (at to text) in existing) continue
            db.entries().upsert(
                Entry(
                    id = UUID.randomUUID().toString(),
                    text = text,
                    createdAt = at,
                    durationSec = o.optInt("seconds", 0),
                    // Recompute rather than trust the file: a valence written by
                    // iOS came from a different lexicon, and mixing two scales in
                    // one mood curve would make the chart quietly meaningless.
                    valence = Sentiment.valence(text),
                    entities = o.optString("entities", ""),
                )
            )
            added++
        }
        added
    }
    suspend fun delete(id: String) = db.entries().delete(id)

    suspend fun add(text: String, durationSec: Int, audioPath: String? = null) = withContext(Dispatchers.IO) {
        val entities = NameDetector.detect(text, corpus = db.entries().allOnce())
        val now = System.currentTimeMillis()
        val cal = java.util.Calendar.getInstance().apply { timeInMillis = now }

        // Decoding and analysing the audio takes a few hundred ms, so it happens
        // here on IO rather than on the way to the UI. An entry must never wait
        // on its own prosody: if extraction fails the entry still saves, minus
        // the numbers.
        val prosody = audioPath
            ?.let { java.io.File(it) }
            ?.takeIf { it.exists() }
            ?.let {
                runCatching {
                    com.dailyvox.app.audio.Prosody.analyse(it, text.split(" ").size)
                }.getOrNull()
            }
            ?.takeIf { it.available }

        db.entries().upsert(
            Entry(
                id = UUID.randomUUID().toString(),
                text = text,
                createdAt = now,
                durationSec = durationSec,
                valence = Sentiment.valence(text),
                entities = entities.joinToString(","),
                audioPath = audioPath,
                speakingRate = prosody?.speakingRate?.toFloat(),
                pitchMean = prosody?.pitchMean?.toFloat(),
                pitchVariability = prosody?.pitchVariability?.toFloat(),
                energyMean = prosody?.energyMean?.toFloat(),
                pauseRatio = prosody?.pauseRatio?.toFloat(),
                longPauseCount = prosody?.longPauseCount,
                hourOfDay = cal.get(java.util.Calendar.HOUR_OF_DAY),
                dayOfWeek = cal.get(java.util.Calendar.DAY_OF_WEEK),
            )
        )
    }

    /** Streak in days, counting back from today while an entry exists each day. */
    suspend fun streakDays(): Int = withContext(Dispatchers.IO) {
        val days = db.entries().allOnce().map { it.createdAt / 86_400_000L }.toSet()
        if (days.isEmpty()) return@withContext 0
        val today = System.currentTimeMillis() / 86_400_000L
        var n = 0
        var d = if (days.contains(today)) today else today - 1
        while (days.contains(d)) { n++; d-- }
        n
    }

    /**
     * Twin resolution: how much of you the Twin can actually see. Deliberately
     * NOT a random number for the mock -- it is entry count against a 200-entry
     * horizon, tempered by how many distinct people and places recur, because a
     * Twin that has read 200 entries about one topic knows less than one that has
     * read 60 across a life. Shown as a percentage in the design's badge.
     */
    suspend fun resolution(): Int = withContext(Dispatchers.IO) {
        val all = db.entries().allOnce()
        if (all.isEmpty()) return@withContext 0
        val volume = (all.size / 200f).coerceAtMost(1f)
        val breadth = (all.flatMap { it.entityList }.toSet().size / 40f).coerceAtMost(1f)
        ((0.6f * volume + 0.4f * breadth) * 100).toInt().coerceIn(0, 100)
    }

    suspend fun seedIfEmpty(context: Context) {
        Sentiment.ensureLoaded(context)
        if (db.entries().count() > 0) return
        DummyData.entries().forEach { db.entries().upsert(it) }
    }

    companion object {
        @Volatile private var INSTANCE: Repo? = null
        fun get(context: Context): Repo = INSTANCE ?: synchronized(this) {
            // Before any write can score a valence.
            Sentiment.ensureLoaded(context)
            INSTANCE ?: Repo(
                Room.databaseBuilder(context.applicationContext, DailyVoxDb::class.java, "dailyvox.db")
                    .fallbackToDestructiveMigration()
                    .build()
            ).also { INSTANCE = it }
        }
    }
}
