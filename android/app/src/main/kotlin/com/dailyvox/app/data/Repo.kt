package com.dailyvox.app.data

import android.content.Context
import androidx.room.Room
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.withContext
import java.util.UUID

class Repo private constructor(private val db: DailyVoxDb) {

    fun observeAll(): Flow<List<Entry>> = db.entries().observeAll()
    fun search(q: String): Flow<List<Entry>> = db.entries().search(q)
    suspend fun byId(id: String) = db.entries().byId(id)
    suspend fun delete(id: String) = db.entries().delete(id)

    suspend fun add(text: String, durationSec: Int, audioPath: String? = null) {
        val entities = NameDetector.detect(text, corpus = db.entries().allOnce())
        db.entries().upsert(
            Entry(
                id = UUID.randomUUID().toString(),
                text = text,
                createdAt = System.currentTimeMillis(),
                durationSec = durationSec,
                valence = Sentiment.valence(text),
                entities = entities.joinToString(","),
                audioPath = audioPath,
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
        if (db.entries().count() > 0) return
        DummyData.entries().forEach { db.entries().upsert(it) }
    }

    companion object {
        @Volatile private var INSTANCE: Repo? = null
        fun get(context: Context): Repo = INSTANCE ?: synchronized(this) {
            INSTANCE ?: Repo(
                Room.databaseBuilder(context.applicationContext, DailyVoxDb::class.java, "dailyvox.db")
                    .fallbackToDestructiveMigration()
                    .build()
            ).also { INSTANCE = it }
        }
    }
}
