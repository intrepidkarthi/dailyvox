package com.dailyvox.app

import com.dailyvox.app.data.DummyData
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * The demo journal shipped to real users once. It reached the released APK
 * because `Repo.seedIfEmpty` wrote it unconditionally and nothing anywhere
 * asserted that it should not — so a new install opened on 38 invented entries
 * about invented people, sitting in the one screen whose entire promise is that
 * it holds only what you said.
 *
 * The seeding is now gated on BuildConfig, which a unit test cannot observe
 * across variants. What a unit test CAN hold is the invariant the recovery
 * depends on: `Repo.purgeDemoData` deletes by exact text, so the list it
 * deletes has to be the list the seeder writes. Add a paragraph to the seeder
 * and forget the accessor, and every phone that already has the demo data keeps
 * the new entry forever with no way to identify it.
 */
class DemoDataTest {

    @Test
    fun `purge list covers every entry the seeder writes`() {
        val written = DummyData.entries().map { it.text }.toSet()
        val purged = DummyData.demoTexts().toSet()
        assertEquals(
            "Texts the seeder writes but the purge would leave behind",
            emptySet<String>(),
            written - purged,
        )
    }

    @Test
    fun `purge list is exactly the seed corpus, with nothing invented`() {
        val written = DummyData.entries().map { it.text }.toSet()
        assertEquals(
            "Texts the purge would delete that the seeder never wrote — these " +
                "would be deleted out of a real journal if a user ever typed one",
            emptySet<String>(),
            DummyData.demoTexts().toSet() - written,
        )
    }

    /**
     * Deleting by text is only safe while the texts are long enough that nobody
     * dictates one by accident. A one-word demo entry would make the purge a
     * data-loss bug rather than a fix.
     */
    @Test
    fun `every demo text is too long to be typed by coincidence`() {
        val short = DummyData.demoTexts().filter { it.length < 60 }
        assertTrue("Demo texts short enough to collide with a real entry: $short", short.isEmpty())
    }
}
