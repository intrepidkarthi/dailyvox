package com.dailyvox.app

import com.dailyvox.app.debug.RecognizerProbe
import com.dailyvox.app.debug.RecognizerProbe.Support
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** B-17 (debug builds only): the probe's report says plainly what each tag is. */
class RecognizerProbeTest {

    private val s = Support(
        installed = listOf("en-US"),
        pending = listOf("pt-BR"),
        supported = listOf("en-US", "hi-IN", "pt-BR", "es-ES"),
        online = listOf("ta-IN"),
    )

    @Test fun `each watched tag gets one honest status`() {
        assertEquals("INSTALLED", RecognizerProbe.status("en-US", s))
        assertEquals("pending download", RecognizerProbe.status("pt-BR", s))
        assertEquals("supported, not installed", RecognizerProbe.status("hi-IN", s))
        assertTrue(RecognizerProbe.status("en-IN", s).startsWith("absent (same language: en-US"))
        assertTrue(RecognizerProbe.status("ta-IN", s).startsWith("online only"))
        assertEquals("absent", RecognizerProbe.status("bn-IN", s))
        assertEquals("INSTALLED", RecognizerProbe.status("en-US", s.copy(installed = listOf("en_US"))))
    }

    @Test fun `the report lists every list and every watched tag, hi-IN and pt-BR included`() {
        val r = RecognizerProbe.report(listOf("device: test"), s, null)
        listOf("installed (1)", "pending (1)", "supported on-device (4)", "online (1)",
               "hi-IN: supported, not installed", "pt-BR: pending download").forEach {
            assertTrue("missing '$it' in\n$r", it in r)
        }
        assertTrue(RecognizerProbe.report(emptyList(), null, "error 5").contains("error 5"))
    }
}
