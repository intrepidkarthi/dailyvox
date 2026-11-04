package com.dailyvox.app

import com.dailyvox.app.audio.pickRecognizerLanguage
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

/**
 * A0-2. The recogniser is asked for the phone's language or for nothing.
 * Asking an English pack to hear Hindi produces English words that were never
 * said, which is worse than no transcript at all.
 */
class RecognizerLanguageTest {

    @Test
    fun `exact tag wins`() {
        assertEquals("en-IN", pickRecognizerLanguage(listOf("en-US", "en-IN"), Locale.forLanguageTag("en-IN")))
    }

    @Test
    fun `same language in another region is still English, unchanged`() {
        assertEquals("en-US", pickRecognizerLanguage(listOf("en-US"), Locale.forLanguageTag("en-IN")))
        assertEquals("en_US", pickRecognizerLanguage(listOf("en_US"), Locale.forLanguageTag("en-GB")))
        assertEquals("en-US", pickRecognizerLanguage(listOf("en-US"), Locale.US))
    }

    @Test
    fun `a Hindi phone with only an English pack gets nothing, not English`() {
        assertNull(pickRecognizerLanguage(listOf("en-US"), Locale.forLanguageTag("hi-IN")))
    }

    @Test
    fun `a Portuguese phone with English and Spanish packs gets nothing`() {
        assertNull(pickRecognizerLanguage(listOf("en-US", "es-ES"), Locale.forLanguageTag("pt-BR")))
    }

    @Test
    fun `a Hindi phone with the Hindi pack gets Hindi`() {
        assertEquals("hi-IN", pickRecognizerLanguage(listOf("en-US", "hi-IN"), Locale.forLanguageTag("hi-IN")))
    }

    @Test
    fun `no packs means no pick`() {
        assertNull(pickRecognizerLanguage(emptyList(), Locale.US))
    }
}
