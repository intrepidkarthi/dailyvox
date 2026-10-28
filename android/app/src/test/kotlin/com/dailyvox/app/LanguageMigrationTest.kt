package com.dailyvox.app

import android.content.Context
import androidx.room.Room
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.dailyvox.app.data.DailyVoxDb
import com.dailyvox.app.data.Repo
import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * B-2: version 6 adds `language`. The proof that matters is not "the column
 * exists" but "Room opens a real version-5 journal after the migration": Room
 * checks the migrated table against the entity and refuses to open on any
 * mismatch -- which, with no destructive fallback, is a crash on launch for
 * every user upgrading from 1.2.1. So this builds a database exactly as 1.2.1
 * left it (schema and identity hash from schemas/5.json), then opens it with
 * the app's own migrations through Room.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class LanguageMigrationTest {

    private val ctx = ApplicationProvider.getApplicationContext<Context>()

    private fun schema(version: Int): JSONObject = JSONObject(
        java.io.File("schemas/com.dailyvox.app.data.DailyVoxDb/$version.json").readText()
    ).getJSONObject("database")

    /** A database file in exactly the shape 1.2.1 (schema 5) wrote. */
    private fun versionFive(name: String, seed: (SupportSQLiteDatabase) -> Unit) =
        exported(5, name, seed)

    /**
     * A database file in exactly the shape the build that exported schema
     * [version] wrote: its createSql, and its identity hash in
     * room_master_table, so Room treats it as that version and migrates.
     */
    private fun exported(version: Int, name: String, seed: (SupportSQLiteDatabase) -> Unit) {
        ctx.deleteDatabase(name)
        val v = schema(version)
        val cfg = SupportSQLiteOpenHelper.Configuration.builder(ctx).name(name)
            .callback(object : SupportSQLiteOpenHelper.Callback(version) {
                override fun onCreate(db: SupportSQLiteDatabase) {
                    val entity = v.getJSONArray("entities").getJSONObject(0)
                    db.execSQL(entity.getString("createSql").replace("\${TABLE_NAME}", entity.getString("tableName")))
                    val setup = v.getJSONArray("setupQueries")
                    for (i in 0 until setup.length()) db.execSQL(setup.getString(i))
                    seed(db)
                }
                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {}
            }).build()
        FrameworkSQLiteOpenHelperFactory().create(cfg).also { it.writableDatabase; it.close() }
    }

    private fun openWithRoom(name: String): DailyVoxDb =
        Room.databaseBuilder(ctx, DailyVoxDb::class.java, name)
            .addMigrations(Repo.MIGRATION_1_2, Repo.MIGRATION_2_3, Repo.MIGRATION_3_4,
                           Repo.MIGRATION_4_5, Repo.MIGRATION_5_6)
            .allowMainThreadQueries()
            .build()

    @Test
    fun `a 1_2_1 journal opens in Room after the migration, every row intact, language unknown`() {
        versionFive("v5-to-v6.db") { db ->
            db.execSQL(
                "INSERT INTO entries (id, text, createdAt, durationSec, valence, entities, selfLabel, " +
                    "suggestedMood, hrvMs, audioPath) VALUES ('a', 'Dinner with Priya', 1, 42, 0.4, 'Priya', " +
                    "'joy', 'joy', 41.5, '/x/a.m4a')"
            )
            db.execSQL(
                "INSERT INTO entries (id, text, createdAt, durationSec, valence, entities) " +
                    "VALUES ('b', 'आज बहुत अच्छा दिन था', 2, 10, NULL, '')"
            )
        }
        val room = openWithRoom("v5-to-v6.db")
        try {
            val rows = runBlocking { room.entries().allOnce() }.associateBy { it.id }
            assertEquals(2, rows.size)
            val a = rows.getValue("a")
            assertEquals("Dinner with Priya", a.text)
            assertEquals(0.4f, a.valence!!, 1e-6f)
            assertEquals("joy", a.selfLabel); assertEquals("joy", a.suggestedMood)
            assertEquals(41.5f, a.hrvMs!!, 1e-6f); assertEquals(42, a.durationSec)
            assertEquals("/x/a.m4a", a.audioPath); assertEquals("Priya", a.entities)
            // Not backfilled: old entries say "unknown", never a guess.
            assertNull(a.language)
            assertNull(rows.getValue("b").language)
            assertNull(rows.getValue("b").valence)

            // And the new column takes a value.
            runBlocking { room.entries().upsert(a.copy(language = "hi-IN")) }
            assertEquals("hi-IN", runBlocking { room.entries().byId("a") }!!.language)
        } finally { room.close() }
    }

    /**
     * The upgrade Play will actually deliver. 1.2 (versionCode 6) shipped
     * schema 4 and 1.2.1 never shipped, so every upgrading phone goes 4 -> 5
     * -> 6 in one launch: the table rebuild that makes valence nullable, then
     * the language column. Room validates the result against the entity.
     */
    @Test
    fun `a 1_2 journal (schema 4) opens in Room on 1_3, every row intact`() {
        exported(4, "v4-to-v6.db") { db ->
            db.execSQL(
                "INSERT INTO entries (id, text, createdAt, durationSec, valence, entities, selfLabel, " +
                    "suggestedMood, hrvMs, audioPath, speakingRate) VALUES ('a', 'Dinner with Priya', 1, 42, " +
                    "0.4, 'Priya', 'joy', 'joy', 41.5, '/x/a.m4a', 2.5)"
            )
            db.execSQL(
                "INSERT INTO entries (id, text, createdAt, durationSec, valence, entities) " +
                    "VALUES ('b', 'Heute war ein guter Tag', 2, 10, 0.0, '')"
            )
        }
        val room = openWithRoom("v4-to-v6.db")
        try {
            val rows = runBlocking { room.entries().allOnce() }.associateBy { it.id }
            assertEquals(2, rows.size)
            val a = rows.getValue("a")
            assertEquals("Dinner with Priya", a.text)
            assertEquals(0.4f, a.valence!!, 1e-6f)
            assertEquals("joy", a.selfLabel); assertEquals("joy", a.suggestedMood)
            assertEquals(41.5f, a.hrvMs!!, 1e-6f); assertEquals(42, a.durationSec)
            assertEquals(2.5f, a.speakingRate!!, 1e-6f)
            assertEquals("/x/a.m4a", a.audioPath); assertEquals("Priya", a.entities)
            assertNull(a.language)
            // The migration copies values unchanged; clearing unread valence
            // is Repo's launch pass, not the migration's.
            assertEquals(0f, rows.getValue("b").valence!!, 0f)
            // Schema 5's change: valence now takes NULL.
            runBlocking { room.entries().upsert(rows.getValue("b").copy(valence = null, language = "de-DE")) }
            val b = runBlocking { room.entries().byId("b") }!!
            assertNull(b.valence); assertEquals("de-DE", b.language)
        } finally { room.close() }
    }

    @Test
    fun `the migration is safe to run twice`() {
        versionFive("v5-twice.db") {}
        val helper = FrameworkSQLiteOpenHelperFactory().create(
            SupportSQLiteOpenHelper.Configuration.builder(ctx).name("v5-twice.db")
                .callback(object : SupportSQLiteOpenHelper.Callback(5) {
                    override fun onCreate(db: SupportSQLiteDatabase) {}
                    override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {}
                }).build()
        )
        val db = helper.writableDatabase
        Repo.MIGRATION_5_6.migrate(db)
        Repo.MIGRATION_5_6.migrate(db)
        val cols = db.query("PRAGMA table_info(entries)").use { c ->
            buildList { while (c.moveToNext()) add(c.getString(c.getColumnIndexOrThrow("name"))) }
        }
        assertEquals(1, cols.count { it == "language" })
        helper.close()
    }

    @Test
    fun `schema 6 is schema 5 plus one nullable language column`() {
        fun fields(v: Int) = schema(v).getJSONArray("entities").getJSONObject(0).getJSONArray("fields").let { a ->
            (0 until a.length()).associate { a.getJSONObject(it).getString("columnName") to a.getJSONObject(it) }
        }
        val five = fields(5); val six = fields(6)
        assertEquals(five.keys + "language", six.keys)
        val lang = six.getValue("language")
        assertEquals("TEXT", lang.getString("affinity"))
        assertTrue("language must be nullable", !lang.optBoolean("notNull", false))
    }
}
