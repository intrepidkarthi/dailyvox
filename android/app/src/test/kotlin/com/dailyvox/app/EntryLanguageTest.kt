package com.dailyvox.app

import com.dailyvox.app.data.Repo
import com.dailyvox.app.system.Speaker
import com.dailyvox.app.system.TextLanguage
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * B-2: where an entry's language comes from, and B-13's read-aloud that
 * follows it. Quiet, never wrong: unsure is null, and null reads as 1.2 did.
 */
class EntryLanguageTest {

    private val never = { error("typed text only") }

    @Test
    fun `spoken entries take the recogniser's tag, never the classifier`() {
        assertEquals("hi-IN", Repo.entryLanguage("/a.m4a", 30, "hi-IN", never))
        // Audio saved with no words is still spoken in the asked-for language.
        assertEquals("es-ES", Repo.entryLanguage("/a.m4a", 0, "es-ES", never))
        // Nothing was asked for: unknown, not the phone's locale.
        assertNull(Repo.entryLanguage("/a.m4a", 12, null, never))
    }

    @Test
    fun `typed entries are classified on the phone`() {
        assertEquals("fr", Repo.entryLanguage(null, 0, "en-US") { "fr" })
        assertNull(Repo.entryLanguage("", 0, null) { null })
    }

    private val french = "Aujourd'hui j'ai marché longtemps au bord de la rivière avec ma soeur."

    @Test
    fun `a confident classifier answer is kept`() {
        assertEquals("fr", TextLanguage.detect({ listOf("fr" to 0.93f, "en" to 0.04f) }, french))
        assertEquals("pt-BR", TextLanguage.choose(french, listOf("pt_BR" to 0.8f)))
    }

    @Test
    fun `an unsure or tiny answer is unknown`() {
        assertNull(TextLanguage.choose(french, listOf("fr" to 0.45f, "it" to 0.40f)))
        assertNull(TextLanguage.choose("ok Sarah", listOf("en" to 0.99f)))
        assertNull(TextLanguage.choose(french, listOf("und" to 0.99f)))
        assertNull(TextLanguage.choose(french, emptyList()))
        assertNull(TextLanguage.detect({ error("must not be asked") }, "   "))
    }

    @Test
    fun `a Devanagari entry counts its letters, marks and all`() {
        val hindi = "आज मेरी दादी का देहांत हो गया।"
        assertEquals("hi", TextLanguage.choose(hindi, listOf("hi" to 0.97f)))
    }

    @Test
    fun `imported tags are kept only if they are real`() {
        assertEquals("hi-IN", TextLanguage.validTag("hi-IN"))
        assertEquals("en-US", TextLanguage.validTag("en_US"))
        assertNull(TextLanguage.validTag(""))
        assertNull(TextLanguage.validTag(null))
        assertNull(TextLanguage.validTag("!!"))
    }

    @Test
    fun `read-aloud uses the entry's language, and no tag means the phone's as in 1_2`() {
        assertNull(Speaker.voiceLocale(null))
        assertNull(Speaker.voiceLocale(""))
        assertEquals("hi", Speaker.voiceLocale("hi-IN")!!.language)
        assertEquals("IN", Speaker.voiceLocale("hi-IN")!!.country)
        assertEquals("zh", Speaker.voiceLocale("cmn-Hans-CN")!!.language)
    }

    @Test
    fun `no voice for the language means quiet, not another voice`() {
        assertTrue(Speaker.hasVoice(android.speech.tts.TextToSpeech.LANG_AVAILABLE))
        assertTrue(Speaker.hasVoice(android.speech.tts.TextToSpeech.LANG_COUNTRY_AVAILABLE))
        assertFalse(Speaker.hasVoice(android.speech.tts.TextToSpeech.LANG_MISSING_DATA))
        assertFalse(Speaker.hasVoice(android.speech.tts.TextToSpeech.LANG_NOT_SUPPORTED))
    }

    @Test
    fun `typed is what the Journal calls typed`() {
        assertTrue(Repo.isTyped(null, 0))
        assertTrue(Repo.isTyped("", 0))
        assertFalse(Repo.isTyped(null, 5))
        assertFalse(Repo.isTyped("/a.m4a", 0))
        assertEquals(Locale.ROOT, Locale.ROOT)
    }
}
