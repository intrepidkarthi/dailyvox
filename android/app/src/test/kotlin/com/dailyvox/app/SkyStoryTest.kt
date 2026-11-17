package com.dailyvox.app

import android.content.Context
import android.graphics.BitmapFactory
import androidx.test.core.app.ApplicationProvider
import com.dailyvox.app.data.Entry
import com.dailyvox.app.system.Shareables
import com.dailyvox.app.system.SkyStory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config
import org.robolectric.annotation.GraphicsMode
import java.time.LocalDate
import java.time.ZoneId

/**
 * The Story card: "share your sky, never your words".
 *
 * Robolectric for the real string resources (the copy is plurals) and NATIVE
 * graphics so the card actually renders, which also writes the example PNG to
 * app/build/sky-cards/android-card.png for eyeballing.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
@GraphicsMode(GraphicsMode.Mode.NATIVE)
class SkyStoryTest {

    private val context: Context get() = ApplicationProvider.getApplicationContext()
    private val zone: ZoneId = ZoneId.systemDefault()

    /** A token that cannot occur in any string resource by accident. */
    private val token = "Qzxwvortle7731"

    private fun journal(nights: Int, perNight: Int = 1): List<Entry> {
        val start = LocalDate.now(zone).minusDays(nights.toLong())
        return (0 until nights).flatMap { d ->
            (0 until perNight).map { k ->
                Entry(
                    id = "e$d-$k",
                    createdAt = start.plusDays(d.toLong()).atTime(20, k * 7)
                        .atZone(zone).toInstant().toEpochMilli(),
                    text = "Walked with $token by the river, felt $token-ish. ${token.lowercase()}",
                    durationSec = 42,
                    valence = if (d % 2 == 0) 0.6f else -0.4f,
                    entities = "$token,Priya,Arun",
                    selfLabel = token,
                )
            }
        }
    }

    @Test
    fun `no entry text, name or mood reaches the card`() {
        val entries = journal(42, perNight = 2)
        val shape = SkyStory.shape(entries, zone)
        val copy = SkyStory.copy(context.resources, shape.nights)

        val everything = (copy.all + shape.toString()).joinToString("\n")
        listOf(token, token.lowercase(), "Priya", "Arun", "river").forEach {
            assertFalse("\"$it\" leaked into the card: $everything",
                        everything.contains(it, ignoreCase = true))
        }
        // The shape is numbers only: no field can carry a string at all.
        SkyStory.Shape::class.java.declaredFields
            .filterNot { java.lang.reflect.Modifier.isStatic(it.modifiers) }
            .forEach { f ->
                assertFalse("Shape.${f.name} is a String", f.type == String::class.java)
            }
    }

    @Test
    fun `the copy says the count, the line and the link`() {
        val copy = SkyStory.copy(context.resources, 42)
        assertEquals("42 nights kept.", copy.headline)
        assertEquals("DailyVox · getdailyvox.com/sky", copy.footer)
        assertEquals("My sky after 42 nights of DailyVox — getdailyvox.com/sky", copy.shareText)
        assertTrue(copy.description.contains("42"))

        val one = SkyStory.copy(context.resources, 1)
        assertEquals("1 night kept.", one.headline)
        assertEquals("My sky after 1 night of DailyVox — getdailyvox.com/sky", one.shareText)
    }

    @Test
    fun `nights on the card are local days, not entries`() {
        val shape = SkyStory.shape(journal(21, perNight = 3), zone)
        assertEquals(21, shape.nights)
        assertEquals(4, shape.brightStars)
    }

    @Test
    fun `renders a 1080 by 1920 story and saves an example`() {
        val entries = journal(42)
        val file = Shareables.render(context, Shareables.Card.STORY, entries, includeNames = true)
        val bmp = BitmapFactory.decodeFile(file.path)
        assertEquals(1080, bmp.width)
        assertEquals(1920, bmp.height)

        val out = java.io.File("build/sky-cards/android-card.png")
        out.parentFile?.mkdirs()
        file.copyTo(out, overwrite = true)
        assertTrue(out.length() > 10_000)
    }

    @Test
    fun `the story is offered in the share sheet as a portrait card`() {
        assertTrue(Shareables.portrait(Shareables.Card.STORY))
        assertTrue(Shareables.portrait(Shareables.Card.WALLPAPER))
        assertFalse(Shareables.portrait(Shareables.Card.MY_SKY))
    }
}
