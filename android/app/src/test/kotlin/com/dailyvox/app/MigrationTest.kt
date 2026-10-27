package com.dailyvox.app

import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.sqlite.db.SupportSQLiteOpenHelper
import androidx.sqlite.db.framework.FrameworkSQLiteOpenHelperFactory
import androidx.test.core.app.ApplicationProvider
import com.dailyvox.app.data.Repo
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * The migrations must run against BOTH shapes a version-1 database can have.
 *
 * schemas/1.json already contains the prosody columns -- a build shipped them
 * while `version` was still 1 -- so a real install at version 1 may or may not
 * have them. A bare ADD COLUMN on the second shape is "duplicate column name",
 * and with no destructive fallback that is a crash on every launch.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class MigrationTest {

    private val base = "`id` TEXT NOT NULL, `text` TEXT NOT NULL, `createdAt` INTEGER NOT NULL, " +
        "`durationSec` INTEGER NOT NULL, `valence` REAL NOT NULL, `entities` TEXT NOT NULL, " +
        "`sleepHours` REAL, `audioPath` TEXT, `photoPath` TEXT, `selfLabel` TEXT"
    private val prosody = ", `speakingRate` REAL, `pitchMean` REAL, `pitchVariability` REAL, " +
        "`energyMean` REAL, `pauseRatio` REAL, `longPauseCount` INTEGER, `hourOfDay` INTEGER, `dayOfWeek` INTEGER"

    private fun open(name: String, createSql: String): SupportSQLiteDatabase {
        val ctx = ApplicationProvider.getApplicationContext<android.content.Context>()
        ctx.deleteDatabase(name)
        val cfg = SupportSQLiteOpenHelper.Configuration.builder(ctx).name(name)
            .callback(object : SupportSQLiteOpenHelper.Callback(1) {
                override fun onCreate(db: SupportSQLiteDatabase) {
                    db.execSQL("CREATE TABLE entries ($createSql, PRIMARY KEY(`id`))")
                    db.execSQL("INSERT INTO entries (id, text, createdAt, durationSec, valence, entities) " +
                        "VALUES ('a', 'Dinner with Priya', 1, 42, 0.4, '[]')")
                }
                override fun onUpgrade(db: SupportSQLiteDatabase, oldVersion: Int, newVersion: Int) {}
            }).build()
        return FrameworkSQLiteOpenHelperFactory().create(cfg).writableDatabase
    }

    private fun columns(db: SupportSQLiteDatabase): Set<String> =
        db.query("PRAGMA table_info(entries)").use { c ->
            buildSet { while (c.moveToNext()) add(c.getString(c.getColumnIndexOrThrow("name"))) }
        }

    private fun migrateAll(db: SupportSQLiteDatabase) {
        Repo.MIGRATION_1_2.migrate(db)
        Repo.MIGRATION_2_3.migrate(db)
        Repo.MIGRATION_3_4.migrate(db)
    }

    private fun assertMigrated(db: SupportSQLiteDatabase) {
        val cols = columns(db)
        listOf("speakingRate", "dayOfWeek", "hrvMs", "restingHrBpm", "stepsToday", "suggestedMood")
            .forEach { assertTrue("missing $it", it in cols) }
        db.query("SELECT text FROM entries WHERE id = 'a'").use { c ->
            assertTrue(c.moveToFirst()); assertEquals("Dinner with Priya", c.getString(0))
        }
        // Existing entries are not re-scored: no suggestion, and no label.
        db.query("SELECT suggestedMood, selfLabel FROM entries WHERE id = 'a'").use { c ->
            assertTrue(c.moveToFirst()); assertTrue(c.isNull(0)); assertTrue(c.isNull(1))
        }
    }

    @Test fun trueVersionOneMigrates() = open("v1-plain.db", base).let { migrateAll(it); assertMigrated(it) }

    @Test fun versionOneThatIsAlreadyAheadDoesNotCrash() =
        open("v1-ahead.db", base + prosody).let { migrateAll(it); assertMigrated(it) }

    @Test fun runningTwiceIsHarmless() =
        open("v1-twice.db", base).let { migrateAll(it); migrateAll(it); assertMigrated(it) }

    private fun valenceNotNull(db: SupportSQLiteDatabase): Boolean =
        db.query("PRAGMA table_info(entries)").use { c ->
            while (c.moveToNext()) {
                if (c.getString(c.getColumnIndexOrThrow("name")) == "valence")
                    return c.getInt(c.getColumnIndexOrThrow("notnull")) == 1
            }
            error("no valence column")
        }

    /**
     * 4 -> 5 drops NOT NULL from valence by rebuilding the table. Run against
     * the shape a real upgraded install has (columns in ADD COLUMN order, not
     * the entity's), every value must survive and NULL must then be storable.
     */
    @Test fun versionFiveMakesValenceNullableAndKeepsEveryRow() =
        open("v4-from-v1.db", base).let { db ->
            migrateAll(db)
            db.execSQL("UPDATE entries SET selfLabel = 'joy', suggestedMood = 'joy', hrvMs = 41.5 WHERE id = 'a'")
            assertTrue(valenceNotNull(db))
            Repo.MIGRATION_4_5.migrate(db)
            assertTrue(!valenceNotNull(db))
            assertMigrated(db.also {
                // assertMigrated expects no label; check the copied values first.
                it.query("SELECT valence, selfLabel, suggestedMood, hrvMs, durationSec, entities FROM entries WHERE id = 'a'").use { c ->
                    assertTrue(c.moveToFirst())
                    assertEquals(0.4, c.getDouble(0), 1e-6)
                    assertEquals("joy", c.getString(1)); assertEquals("joy", c.getString(2))
                    assertEquals(41.5, c.getDouble(3), 1e-6); assertEquals(42, c.getInt(4))
                    assertEquals("[]", c.getString(5))
                }
                it.execSQL("UPDATE entries SET selfLabel = NULL, suggestedMood = NULL WHERE id = 'a'")
            })
            db.execSQL("INSERT INTO entries (id, text, createdAt, durationSec, valence, entities) " +
                "VALUES ('b', 'आज', 2, 10, NULL, '')")
            db.query("SELECT valence FROM entries WHERE id = 'b'").use { c ->
                assertTrue(c.moveToFirst()); assertTrue(c.isNull(0))
            }
        }

    /** A version-3 database, the shape before this column, keeps its label. */
    @Test fun versionThreeKeepsItsSelfLabel() {
        val v3 = base + prosody + ", `hrvMs` REAL, `restingHrBpm` REAL, `stepsToday` INTEGER"
        open("v3.db", v3).let { db ->
            db.execSQL("UPDATE entries SET selfLabel = 'joy' WHERE id = 'a'")
            Repo.MIGRATION_3_4.migrate(db)
            assertTrue("suggestedMood" in columns(db))
            db.query("SELECT selfLabel, suggestedMood FROM entries WHERE id = 'a'").use { c ->
                assertTrue(c.moveToFirst()); assertEquals("joy", c.getString(0)); assertTrue(c.isNull(1))
            }
        }
    }
}
