package com.dailyvox.app.data

import androidx.room.*
import kotlinx.coroutines.flow.Flow

/**
 * One journal entry. Mirrors the iOS Core Data DiaryEntry closely enough that a
 * `.twin` export written by either platform can be read by the other -- that
 * portability promise is older than the Android port and outranks convenience.
 *
 * `valence` is -1..1 and drives the mood dot in Journal and the star colour in
 * the constellation. `entities` is the comma-joined output of the name detector,
 * kept denormalised because every read wants all of them and no query filters on
 * one alone.
 */
@Entity(tableName = "entries")
data class Entry(
    @PrimaryKey val id: String,
    val text: String,
    val createdAt: Long,
    val durationSec: Int,
    val valence: Float,
    val entities: String = "",
    val sleepHours: Float? = null,
    val audioPath: String? = null,
    val photoPath: String? = null,
    /**
     * The user's OWN word for how the entry felt, never the detector's.
     * Kept separate from `valence` on purpose: the affect programme's whole
     * finding was that inferred emotion and self-reported emotion disagree, and
     * collapsing them into one column would destroy the only label with ground
     * truth in it -- the one that makes an N=20 cohort worth running.
     */
    val selfLabel: String? = null,
) {
    val entityList: List<String>
        get() = entities.split(",").map { it.trim() }.filter { it.isNotEmpty() }
}

@Dao
interface EntryDao {
    @Query("SELECT * FROM entries ORDER BY createdAt DESC")
    fun observeAll(): Flow<List<Entry>>

    @Query("SELECT * FROM entries ORDER BY createdAt DESC")
    suspend fun allOnce(): List<Entry>

    /** Synchronous read, for the widget's broadcast thread only. */
    @Query("SELECT * FROM entries ORDER BY createdAt DESC")
    fun allBlocking(): List<Entry>

    @Query("SELECT * FROM entries WHERE id = :id")
    suspend fun byId(id: String): Entry?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(entry: Entry)

    @Query("DELETE FROM entries WHERE id = :id")
    suspend fun delete(id: String)

    @Query("SELECT COUNT(*) FROM entries")
    suspend fun count(): Int

    /**
     * Search by meaning is the design's phrasing and the eventual engine call.
     * Until the embedder is wired this is content-word overlap, which is the
     * SAME lexical leg the iOS retriever already blends at 60% weight -- so it is
     * a real subset of the shipped behaviour, not a stub pretending to be one.
     */
    @Query("SELECT * FROM entries WHERE text LIKE '%' || :q || '%' OR entities LIKE '%' || :q || '%' ORDER BY createdAt DESC")
    fun search(q: String): Flow<List<Entry>>
}

@Database(entities = [Entry::class], version = 1, exportSchema = true)
abstract class DailyVoxDb : RoomDatabase() {
    abstract fun entries(): EntryDao
}
