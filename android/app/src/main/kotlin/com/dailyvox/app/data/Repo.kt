package com.dailyvox.app.data

import android.content.Context
import androidx.room.Room
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.withContext
import java.util.UUID


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
        rank(q, all).map { it.first }
    }

    private fun contentWords(t: String): Set<String> = rankWords(t)
    fun allBlocking(): List<Entry> = db.entries().allBlocking()
    suspend fun byId(id: String) = db.entries().byId(id)

    /** Re-analyses the corrected text so the Twin learns from the fix, not the flub. */
    suspend fun updateText(id: String, text: String) {
        db.entries().byId(id)?.let {
            db.entries().upsert(
                it.copy(
                    text = text,
                    valence = com.dailyvox.twin.Sentiment.valence(text),
                    entities = com.dailyvox.twin.NameDetector
                        .detect(text, corpus = listOf(text))
                        .joinToString(","),
                )
            )
        }
    }

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
                    valence = com.dailyvox.twin.Sentiment.valence(text),
                    entities = o.optString("entities", ""),
                )
            )
            added++
        }
        added
    }
    suspend fun delete(id: String) = db.entries().delete(id)

    suspend fun add(
        text: String,
        durationSec: Int,
        audioPath: String? = null,
        body: com.dailyvox.app.body.BodySignals.Snapshot? = null,
    ) = withContext(Dispatchers.IO) {
        val entities = com.dailyvox.twin.NameDetector.detect(
            text, corpus = db.entries().allOnce().map { it.text },
        )
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
                    com.dailyvox.app.audio.AudioDecoder.toPcm(it)?.let { (pcm, rate) ->
                        com.dailyvox.twin.Prosody.analyse(pcm, rate, text.split(" ").size)
                    }
                }.getOrNull()
            }
            ?.takeIf { it.available }

        db.entries().upsert(
            Entry(
                id = UUID.randomUUID().toString(),
                text = text,
                createdAt = now,
                durationSec = durationSec,
                valence = com.dailyvox.twin.Sentiment.valence(text),
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
                // Captured at write time, so the entry keeps the body context it
                // was actually spoken in. Reading it later would attach today's
                // sleep to last week's entry.
                sleepHours = body?.sleepHours?.toFloat(),
                hrvMs = body?.morningHrvMs?.toFloat(),
                restingHrBpm = body?.restingHrBpm?.toFloat(),
                stepsToday = body?.stepsToday,
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
        Lexicon.ensureLoaded(context)
        if (db.entries().count() > 0) return
        DummyData.entries().forEach { db.entries().upsert(it) }
    }

    companion object {

        /**
         * The same scoring the journal search uses, with the score kept rather
         * than thrown away. Ask needs it to show each citation's match strength,
         * and a second implementation of the scoring would drift from this one
         * the first time either is touched.
         */
        /**
         * Journal search ranking. No abstention threshold on purpose: searching
         * is browsing, and a weak match is still worth showing when the user is
         * the one deciding whether it is what they meant. Ask goes through
         * [com.dailyvox.twin.Retrieval.retrieve] instead, which does abstain,
         * because there the Twin is the one deciding.
         *
         * The scoring itself lives in the engine so the two surfaces cannot
         * drift into ranking the same journal differently.
         */
        fun rank(q: String, all: List<Entry>): List<Pair<Entry, Float>> {
            val byId = all.associateBy { it.id }
            return com.dailyvox.twin.Retrieval.rank(q, all.map { it.toChatEntry() })
                .mapNotNull { hit -> byId[hit.entryId]?.let { it to hit.score } }
        }

        fun rankWords(t: String): Set<String> = com.dailyvox.twin.Retrieval.words(t)


        /**
         * Adds the prosody and ambient columns. All nullable, so existing rows
         * take NULL and simply report "no prosody" — which is exactly what an
         * entry recorded before the feature existed should say.
         */
        val MIGRATION_1_2 = object : androidx.room.migration.Migration(1, 2) {
            override fun migrate(db: androidx.sqlite.db.SupportSQLiteDatabase) {
                listOf(
                    "speakingRate REAL", "pitchMean REAL", "pitchVariability REAL",
                    "energyMean REAL", "pauseRatio REAL", "longPauseCount INTEGER",
                    "hourOfDay INTEGER", "dayOfWeek INTEGER",
                ).forEach { column ->
                    db.execSQL("ALTER TABLE entries ADD COLUMN $column")
                }
            }
        }

        /** Body context. Nullable, so pre-Health-Connect entries stay honest
         *  about having none rather than reporting zero steps and no pulse. */
        val MIGRATION_2_3 = object : androidx.room.migration.Migration(2, 3) {
            override fun migrate(db: androidx.sqlite.db.SupportSQLiteDatabase) {
                listOf("hrvMs REAL", "restingHrBpm REAL", "stepsToday INTEGER").forEach {
                    db.execSQL("ALTER TABLE entries ADD COLUMN $it")
                }
            }
        }

        @Volatile private var INSTANCE: Repo? = null
        fun get(context: Context): Repo = INSTANCE ?: synchronized(this) {
            // Before any write can score a valence.
            Lexicon.ensureLoaded(context)
            INSTANCE ?: Repo(
                Room.databaseBuilder(context.applicationContext, DailyVoxDb::class.java, "dailyvox.db")
                    .addMigrations(MIGRATION_1_2, MIGRATION_2_3)
                    // NO fallbackToDestructiveMigration. On a journal app that
                    // reads as "if the schema confuses us, delete their diary".
                    // Every future schema change needs a real migration here;
                    // failing loudly in development is the correct pressure.
                    .build()
            ).also { INSTANCE = it }
        }
    }
}
