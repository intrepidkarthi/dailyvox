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
    }

    private fun assertMigrated(db: SupportSQLiteDatabase) {
        val cols = columns(db)
        listOf("speakingRate", "dayOfWeek", "hrvMs", "restingHrBpm", "stepsToday")
            .forEach { assertTrue("missing $it", it in cols) }
        db.query("SELECT text FROM entries WHERE id = 'a'").use { c ->
            assertTrue(c.moveToFirst()); assertEquals("Dinner with Priya", c.getString(0))
        }
    }

    @Test fun trueVersionOneMigrates() = open("v1-plain.db", base).let { migrateAll(it); assertMigrated(it) }

    @Test fun versionOneThatIsAlreadyAheadDoesNotCrash() =
        open("v1-ahead.db", base + prosody).let { migrateAll(it); assertMigrated(it) }

    @Test fun runningTwiceIsHarmless() =
        open("v1-twice.db", base).let { migrateAll(it); migrateAll(it); assertMigrated(it) }
}
