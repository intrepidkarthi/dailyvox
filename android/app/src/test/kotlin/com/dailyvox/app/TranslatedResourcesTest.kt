package com.dailyvox.app

import android.content.Context
import android.content.res.Configuration
import android.content.res.Resources
import androidx.test.core.app.ApplicationProvider
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * C-2/C-3: the translations are machine drafts awaiting native review, so this
 * does not pin their wording. It pins what would crash or garble at runtime:
 * every string, plural and array in every shipped language resolves, and every
 * one the English formats takes the English arguments without throwing (a
 * translation that swapped %1$s for %1$d, or lost a %%, fails here).
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34])
class TranslatedResourcesTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()

    private fun res(tag: String): Resources {
        val config = Configuration(ctx.resources.configuration)
        config.setLocale(Locale.forLanguageTag(tag))
        return ctx.createConfigurationContext(config).resources
    }

    private val english: Resources get() = res("en-US")

    private val spec = Regex("""%(?:(\d+)\$)?[-#+ 0,(]*\d*(?:\.\d+)?([a-zA-Z%])""")

    /** Arguments shaped like the English placeholders: a count, a name, a score. */
    private fun argsFor(englishText: String, count: Int): Array<Any> {
        val byPosition = sortedMapOf<Int, Any>()
        var next = 1
        for (m in spec.findAll(englishText)) {
            val conv = m.groupValues[2]
            if (conv == "%" || conv == "n") continue
            val pos = m.groupValues[1].toIntOrNull() ?: next++
            byPosition[pos] = when (conv.lowercase()) {
                "d", "x", "o" -> count
                "f", "e", "g" -> 0.25
                else -> "Asha"
            }
        }
        return byPosition.values.toTypedArray()
    }

    private fun ids(kind: Class<*>): List<Pair<String, Int>> =
        kind.fields.map { it.name to it.getInt(null) }

    private fun everythingResolves(tag: String) {
        val r = res(tag)
        var translated = 0
        for ((name, id) in ids(R.string::class.java)) {
            val en = english.getString(id)
            val text = r.getString(id)
            assertTrue("$tag $name is empty", text.isNotBlank())
            if (text != en) translated++
            if (spec.containsMatchIn(en)) {
                val args = argsFor(en, 3)
                String.format(Locale.forLanguageTag(tag), text, *args) // throws on a bad specifier
            }
        }
        // Brand-only keys (app_name) stay the same; nearly everything else moves.
        assertTrue("$tag: only $translated strings differ from English", translated > 400)
        for ((name, id) in ids(R.plurals::class.java)) {
            val en = english.getQuantityText(id, 5).toString()
            for (n in listOf(0, 1, 2, 5, 21, 1_000_000)) {
                val args = argsFor(en, n)
                val text = r.getQuantityString(id, n, *args)
                assertTrue("$tag $name($n) is empty", text.isNotBlank())
            }
        }
        for ((name, id) in ids(R.array::class.java)) {
            assertEquals("$tag $name length", english.getStringArray(id).size, r.getStringArray(id).size)
        }
    }

    @Test
    fun `German, Spanish, French and Italian resolve and format`() {
        listOf("de-DE", "es-ES", "fr-FR", "it-IT").forEach(::everythingResolves)
    }

    @Test
    fun `German reads its own words, with the English arguments in place`() {
        val de = res("de-DE")
        assertEquals("Nichts, was du sagst, verlässt dieses Telefon.", de.getString(R.string.onboarding_ledger_title))
        assertEquals("DailyVox", de.getString(R.string.app_name))
        assertEquals("1:05  ·  Fertig", de.getString(R.string.onboarding_done_timer, 1, 5))
        assertEquals("Gestern hast du Asha erwähnt. Wie läuft es?", de.getString(R.string.daily_question_grounded_yesterday, "Asha"))
        assertEquals(
            "Asha kommt hier vor, und in 1 anderen Eintrag der letzten 30 Tage.",
            de.getQuantityString(R.plurals.reflection_person_earlier, 1, "Asha", 1),
        )
        assertEquals(
            "Asha kommt hier vor, und in 4 anderen Einträgen der letzten 30 Tage.",
            de.getQuantityString(R.plurals.reflection_person_earlier, 4, "Asha", 4),
        )
        assertEquals("Vor einem Tag hast du gesagt", de.getQuantityString(R.plurals.past_days_ago, 1, 1))
        assertEquals("Vor 3 Tagen hast du gesagt", de.getQuantityString(R.plurals.past_days_ago, 3, 3))
        // Two spaces each side of the dot survive, as in English.
        assertTrue(de.getString(R.string.export_pdf_mood, 0.25).startsWith("  ·  Stimmung +0"))
        assertNotEquals(english.getStringArray(R.array.daily_questions)[0], de.getStringArray(R.array.daily_questions)[0])
    }

    @Test
    fun `Brazilian Portuguese resolves and formats`() {
        everythingResolves("pt-BR")
        val pt = res("pt-BR")
        assertEquals("Este celular tem: inglês.", pt.getString(R.string.speech_installed_packs, "inglês").trim())
    }

    @Test
    fun `Hindi resolves and formats, in Devanagari with Western digits`() {
        everythingResolves("hi-IN")
        val hi = res("hi-IN")
        assertEquals("आपकी कही कोई बात इस फ़ोन से बाहर नहीं जाती।", hi.getString(R.string.onboarding_ledger_title))
        assertEquals("DailyVox", hi.getString(R.string.app_name))
        assertEquals("1:05  ·  हो गया", hi.getString(R.string.onboarding_done_timer, 1, 5))
        assertEquals("कल आपने Asha का ज़िक्र किया था। सब कैसा चल रहा है?", hi.getString(R.string.daily_question_grounded_yesterday, "Asha"))
        assertEquals(
            "इसमें Asha का ज़िक्र है, और पिछले 30 दिनों की 4 और एंट्रियों में भी।",
            hi.getQuantityString(R.plurals.reflection_person_earlier, 4, "Asha", 4),
        )
        assertEquals("3 दिन पहले आपने कहा", hi.getQuantityString(R.plurals.past_days_ago, 3, 3))
    }
}
