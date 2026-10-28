package com.dailyvox.app

import com.dailyvox.app.audio.LanguageTags
import com.dailyvox.app.audio.SpeakingOption
import com.dailyvox.app.audio.fileTranscriptionTag
import com.dailyvox.app.audio.languageUnavailable
import com.dailyvox.app.audio.pickRecognizerLanguage
import com.dailyvox.app.audio.speakingOptions
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

/**
 * B-8: the speaking-language picker and the tag matching under it. The rule is
 * the plan's: the language the user speaks, or nothing -- never a pack in
 * another language, and never a pack in another SCRIPT.
 */
class SpeakingLanguageTest {

    private val zhCN = Locale.forLanguageTag("zh-CN")

    @Test
    fun `cmn-Hans-CN is zh-CN`() {
        assertTrue(LanguageTags.same("cmn-Hans-CN", "zh-CN"))
        assertTrue(LanguageTags.same("cmn-Hans-CN", "zh-Hans-CN"))
        assertEquals("cmn-Hans-CN", pickRecognizerLanguage(listOf("en-US", "cmn-Hans-CN"), zhCN))
    }

    @Test
    fun `Traditional Chinese is not served by a Simplified pack`() {
        assertFalse(LanguageTags.sameLanguage("cmn-Hans-CN", "zh-TW"))
        assertNull(pickRecognizerLanguage(listOf("cmn-Hans-CN"), Locale.forLanguageTag("zh-TW")))
        assertEquals("cmn-Hant-TW", pickRecognizerLanguage(listOf("cmn-Hans-CN", "cmn-Hant-TW"), Locale.forLanguageTag("zh-TW")))
    }

    @Test
    fun `Cantonese is not Mandarin`() {
        assertNull(pickRecognizerLanguage(listOf("yue-Hant-HK"), Locale.forLanguageTag("zh-HK")))
    }

    @Test
    fun `legacy and underscore spellings match`() {
        assertTrue(LanguageTags.same("iw-IL", "he-IL"))
        assertTrue(LanguageTags.same("in_ID", "id-ID"))
        assertEquals("pt_BR", pickRecognizerLanguage(listOf("pt_BR"), Locale.forLanguageTag("pt-BR")))
    }

    @Test
    fun `Tier 1 languages pick their own pack and nothing else`() {
        val packs = listOf("en-US", "es-ES", "fr-FR", "de-DE", "it-IT", "pt-BR", "hi-IN")
        mapOf("es-MX" to "es-ES", "fr-CA" to "fr-FR", "de-AT" to "de-DE", "it-IT" to "it-IT",
              "pt-BR" to "pt-BR", "hi-IN" to "hi-IN", "en-IN" to "en-US").forEach { (want, got) ->
            assertEquals(want, got, pickRecognizerLanguage(packs, Locale.forLanguageTag(want)))
        }
        assertNull(pickRecognizerLanguage(packs, Locale.forLanguageTag("ta-IN")))
    }

    @Test
    fun `saved audio goes to the entry's own language, not the phone's`() {
        // Spoken in Hindi, phone now set to English: the Hindi pack, not English.
        assertEquals("hi-IN", fileTranscriptionTag("hi-IN", listOf("en-US", "hi-IN"), Locale.US))
        // Spoken in Hindi, no Hindi pack: nothing. Never the English model.
        assertNull(fileTranscriptionTag("hi-IN", listOf("en-US"), Locale.US))
        // No entry language (pre-1.3): the language the user speaks now.
        assertEquals("en-US", fileTranscriptionTag(null, listOf("en-US"), Locale.forLanguageTag("en-GB")))
        assertNull(fileTranscriptionTag(null, listOf("en-US"), Locale.forLanguageTag("hi-IN")))
    }

    @Test
    fun `with no probe result the file path asks as 1_2 did`() {
        // English, unchanged: 1.2 sent the phone's locale tag.
        assertEquals("en-US", fileTranscriptionTag(null, emptyList(), Locale.US))
        assertEquals("hi-IN", fileTranscriptionTag("hi-IN", emptyList(), Locale.US))
    }

    @Test
    fun `picker lists the phone first, then every installable language, each once`() {
        val opts = speakingOptions(
            installed = listOf("en-US", "hi-IN"),
            supported = listOf("en-US", "es-ES", "pt-BR", "cmn-Hans-CN"),
            phone = Locale.US, uiLocale = Locale.US,
        )
        assertNull(opts.first().tag)
        assertEquals(SpeakingOption.State.ON_PHONE, opts.first().state)
        val rest = opts.drop(1)
        assertEquals(5, rest.size)   // en-US once, not twice
        assertEquals(rest.map { it.label }.sorted(), rest.map { it.label })
        assertEquals(SpeakingOption.State.ON_PHONE, rest.single { it.tag == "hi-IN" }.state)
        assertEquals(SpeakingOption.State.NEEDS_DOWNLOAD, rest.single { it.tag == "pt-BR" }.state)
        assertTrue(rest.single { it.tag == "cmn-Hans-CN" }.label.startsWith("Chinese"))
    }

    @Test
    fun `a phone language with no model anywhere is shown as unavailable, never as English`() {
        val opts = speakingOptions(listOf("en-US"), listOf("en-US", "es-ES"), Locale.forLanguageTag("ta-IN"), Locale.US)
        assertEquals(SpeakingOption.State.UNAVAILABLE, opts.first().state)
    }

    @Test
    fun `downloadable language gets the download copy`() {
        val e = languageUnavailable("hi-IN", listOf("en-US"), listOf("hi-IN", "en-US"), "Google", Locale.US)
        assertEquals("Hindi needs a one-time download from Google. After that, everything you say stays on this phone.", e.message)
        assertTrue(e.offerDownload)
        assertTrue(e.fix.contains("en-US"))
    }

    @Test
    fun `undownloadable language says so and offers no download`() {
        val e = languageUnavailable("ta-IN", listOf("en-US"), listOf("en-US", "hi-IN"), null, Locale.US)
        assertEquals("Your phone can't transcribe Tamil on-device yet.", e.message)
        assertFalse(e.offerDownload)
    }

    @Test
    fun `unknown support list keeps 1_2's offer to download`() {
        val e = languageUnavailable("en-US", emptyList(), emptyList(), null, Locale.US)
        assertTrue(e.offerDownload)
        assertTrue(e.message.startsWith("English needs a one-time download from your phone's speech service."))
    }
}
