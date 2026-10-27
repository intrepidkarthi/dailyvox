package com.dailyvox.app

import android.content.Context
import android.content.res.Resources
import androidx.test.core.app.ApplicationProvider
import com.dailyvox.app.system.LocaleFormat
import com.dailyvox.app.system.Shareables
import java.time.LocalDate
import java.time.ZoneId
import java.util.Date
import java.util.Locale
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import org.robolectric.RobolectricTestRunner
import org.robolectric.annotation.Config

/**
 * B-13 and B-15, the rule for this round: moving copy into strings.xml must not
 * change one character of the English UI. Every expected value below is the
 * literal the Kotlin held in 1.2/1.3-gate, pasted from the old source -- curly
 * quotes, em dashes, ellipses, double spaces and all.
 *
 * The other half: dates follow the reader's locale order outside English.
 */
@RunWith(RobolectricTestRunner::class)
@Config(sdk = [34], qualifiers = "en-rUS")
class StringResourcesTest {

    private val ctx: Context get() = ApplicationProvider.getApplicationContext()
    private val res: Resources get() = ctx.resources

    private fun s(id: Int, vararg args: Any) = res.getString(id, *args)
    private fun p(id: Int, n: Int, vararg args: Any) = res.getQuantityString(id, n, *args)

    @Test
    fun `onboarding reads exactly as before`() {
        assertEquals("01 / 04 · permission", s(R.string.onboarding_step_permission))
        assertEquals("04 / 04 · yours", s(R.string.onboarding_step_yours))
        assertEquals("Nothing you say leaves this phone.", s(R.string.onboarding_ledger_title))
        assertEquals(
            "Transcription runs on your device. No account, no server, no analytics SDK. " +
                "Prove it: switch on airplane mode and record your first entry.",
            s(R.string.onboarding_ledger_body),
        )
        assertEquals("not requested", s(R.string.onboarding_ledger_internet_state))
        assertEquals(
            "Turn the radios off and speak. The transcript, the mood, the star — all of it still happens, on the phone. If your phone needs its offline speech pack first, DailyVox will offer it.",
            s(R.string.onboarding_airplane_body),
        )
        assertEquals("Your sky starts\nwith your voice", s(R.string.onboarding_invite_title))
        assertEquals("I'm ready", s(R.string.onboarding_ready))
        assertEquals("How was your day,\nreally?", s(R.string.onboarding_speak_title))
        assertEquals("How was your day, really?", s(R.string.onboarding_typed_placeholder))
        assertEquals(
            "Speak, don't type. Forty-two seconds is plenty — and it stays on this phone.",
            s(R.string.onboarding_speak_body_idle),
        )
        assertEquals("I can't talk right now", s(R.string.onboarding_cant_talk))
        // Two spaces each side of the dot: aapt collapses whitespace unless quoted.
        assertEquals("1:05  ·  Done", s(R.string.onboarding_done_timer, 1, 5))
        assertEquals("0:42  ·  Done", s(R.string.onboarding_done_timer, 0, 42))
        assertEquals("“Slept well.”", s(R.string.onboarding_claim_quote, "Slept well."))
        assertEquals(
            "It lives on your phone, nowhere else.\nSpeak again tomorrow, and your sky grows.",
            s(R.string.onboarding_claim_body),
        )
        assertEquals("One nudge at 9 pm. Change it any time in Settings.", s(R.string.onboarding_remind_body))
    }

    @Test
    fun `settings reads exactly as before`() {
        assertEquals("0 · EVER", s(R.string.settings_shield_network_value))
        assertEquals(
            "The complete permission list: microphone, notifications, vibration, " +
                "biometrics. No network permission of any kind — check it in " +
                "Android Settings › Apps › DailyVox.",
            s(R.string.settings_shield_permissions),
        )
        assertEquals("“Tonight’s star is waiting”", s(R.string.settings_reminder_preview))
        assertEquals("Skips once you’ve spoken · scheduled on-device, no push servers.", s(R.string.settings_reminder_note))
        assertEquals(
            "Counts nights, not entries · once a week at most · never a reminder that you missed one.",
            s(R.string.settings_goal_note),
        )
        assertEquals("BACKUP & EXPORT", s(R.string.settings_backup_label))
        assertEquals("· Obsidian, Bear, anything", s(R.string.settings_export_markdown_hint))
        assertEquals("ABC123  ✓", s(R.string.settings_participant_code_copied, "ABC123"))
        assertEquals("Priya  ×", s(R.string.settings_words_chip, "Priya"))
        assertEquals("A review helps more than you’d think.", s(R.string.settings_review_body))
        assertEquals("Rate ✦", s(R.string.settings_review_rate))
        // 1.2 printed "1 entries"; this round does not change English.
        assertEquals("1 entries", p(R.plurals.settings_footer_entries, 1, 1))
        assertEquals("12 entries", p(R.plurals.settings_footer_entries, 12, 12))
        assertEquals("9pm", s(R.string.settings_hour_pm, 9))
        assertEquals("6am", s(R.string.settings_hour_am, 6))
        assertEquals("noon", s(R.string.settings_hour_noon))
    }

    @Test
    fun `entry page reads exactly as before`() {
        assertEquals("What do my entries say about Sam, around October 26?",
                     s(R.string.entry_ask_seed_person, "Sam", "October 26"))
        assertEquals("What was going on for me around October 26?", s(R.string.entry_ask_seed, "October 26"))
        assertEquals("9:41 PM · 1:42 · 12 words",
                     s(R.string.entry_header_meta, "9:41 PM", "1:42", p(R.plurals.entry_header_words, 12, 12)))
        assertEquals("9:41 PM · typed · 1 words",
                     s(R.string.entry_header_meta, "9:41 PM", s(R.string.entry_header_typed), p(R.plurals.entry_header_words, 1, 1)))
        assertEquals("This phone has no voice for Hindi yet. It can be added in Android Settings › Text-to-speech.",
                     s(R.string.entry_no_voice, "Hindi"))
        assertEquals("7.5 hours", s(R.string.entry_filed_slept_value, 7.5))
        assertEquals("48 ms this morning", s(R.string.entry_filed_hrv_value, 48.2))
        assertEquals("8,412 today", s(R.string.entry_filed_steps_value, 8412))
        assertEquals("142 wpm", s(R.string.entry_filed_pace_value, 142))
        assertEquals("2.4 words/sec spoken", s(R.string.entry_filed_voice_value, 2.4f))
        assertEquals("180 Hz", s(R.string.entry_filed_tone_value, 180f))
        assertEquals("180 Hz · 40 Hz range", s(R.string.entry_filed_tone_value_range, 180f, 40f))
        assertEquals("12% quiet", s(R.string.entry_filed_pauses_value, 12f))
        assertEquals("12% quiet · 3 long", s(R.string.entry_filed_pauses_value_long, 12f, 3))
        assertEquals("+0.42 · positive", s(R.string.entry_valence_value, "+0.42", s(R.string.entry_valence_positive)))
        assertEquals(", ", s(R.string.entry_filed_people_separator))
        assertEquals("✦  Ask about this", s(R.string.entry_action_ask))
        assertEquals("Reading the recording… this can take a moment.", s(R.string.entry_untranscribed_running))
        assertEquals(
            "This phone's speech service didn't turn it into words. " +
                "The audio is here and can be played, and you can try again " +
                "or write it out yourself.",
            s(R.string.entry_untranscribed_body),
        )
        assertEquals(
            "This phone's recogniser can't read a saved " +
                "recording — it tried to listen live instead, " +
                "so nothing was used. Writing it out is the way " +
                "to keep these words.",
            s(R.string.entry_untranscribed_ignored_file),
        )
        assertEquals(
            "Your phone can't transcribe Tamil on-device yet. " +
                "Your recording is saved, and you can transcribe it later if a model becomes available.",
            com.dailyvox.app.ui.screens.noModelCopy(ctx, "ta-IN"),
        )
    }

    @Test
    fun `speech errors read exactly as before`() {
        assertEquals(
            "Tap to try again. If it keeps happening, check that Android's speech " +
                "service (Settings › Apps › Default apps › Digital assistant app, " +
                "or Speech Recognition & Synthesis in the app list) is enabled and not " +
                "battery-restricted -- some OEM builds ship it disabled.",
            s(R.string.speech_error_silent_fix),
        )
        assertEquals(
            "Tap to try again. If it keeps happening, this phone's speech " +
                "service is not transcribing — check that Speech Recognition & " +
                "Synthesis is enabled and not battery-restricted in Android " +
                "Settings › Apps, and that an offline language is installed under " +
                "System › Languages › Speech.",
            s(R.string.speech_error_empty_fix),
        )
        assertEquals("Android Settings › Apps › DailyVox › Permissions.", s(R.string.speech_error_permission_fix))
        val down = com.dailyvox.app.audio.languageUnavailable(ctx, "hi-IN", listOf("en-US", "en-GB"), listOf("hi-IN"), null, Locale.US)
        assertEquals("Hindi needs a one-time download from your phone's speech service. After that, everything you say stays on this phone.", down.message)
        assertEquals("DailyVox still has no internet permission and sends nothing -- the pack comes to your phone, your voice never leaves it. This phone has: en-US, en-GB.", down.fix)
        val none = com.dailyvox.app.audio.languageUnavailable(ctx, "ta-IN", emptyList(), listOf("en-US"), null, Locale.US)
        assertEquals("DailyVox will not send it anywhere to make up for that. Pick another language under " +
                     "Settings › Language you speak, or type tonight's entry.", none.fix)
    }

    @Test
    fun `share cards read exactly as before`() {
        assertEquals("My Sky", s(Shareables.titleRes(Shareables.Card.MY_SKY)))
        assertEquals("Gift a star", s(Shareables.titleRes(Shareables.Card.GIFT)))
        assertEquals(
            "Minted once, at nights 42, 100 and 365. You cannot buy it or " +
                "rush it — you can only have spoken that many times.",
            s(Shareables.captionRes(Shareables.Card.MILESTONE)),
        )
        assertEquals("MY SKY · NIGHT 61", s(R.string.share_sky_label, 61))
        assertEquals("1 stars.", p(R.plurals.share_sky_stars, 1, 1))
        assertEquals("38 stars.", p(R.plurals.share_sky_stars, 38, 38))
        assertEquals("PRIVACY RECEIPT · OCTOBER 26, 2026", s(R.string.share_receipt_subtitle, "OCTOBER 26, 2026"))
        assertEquals("someone · 12 nights", p(R.plurals.share_year_brightest_redacted, 12, 12))
        assertEquals("Sarah · 1 nights", p(R.plurals.share_year_brightest_named, 1, "Sarah", 1))
        assertEquals("\"reservoir\"", s(R.string.share_year_word_quoted, "reservoir"))
        assertEquals("NIGHT SPOKEN", res.getQuantityString(R.plurals.share_milestone_spoken, 1))
        assertEquals("NIGHTS SPOKEN", res.getQuantityString(R.plurals.share_milestone_spoken, 42))
        assertEquals("I kept 7 stars.", p(R.plurals.share_gift_kept, 7, 7))
    }

    // ── B-13: dates in the reader's order ──────────────────────────────────

    private val day = LocalDate.of(2026, 10, 26)
    private val date = Date.from(day.atTime(21, 41).atZone(ZoneId.systemDefault()).toInstant())

    @Test
    fun `English dates are exactly 1_2's`() {
        assertEquals("26 October 2026", LocaleFormat.dateFormat("d MMMM yyyy", "dMMMMyyyy", Locale.US).format(date))
        assertEquals("Monday, 26 October 2026", LocaleFormat.dateFormat("EEEE, d MMMM yyyy", "EEEEdMMMMyyyy", Locale.US).format(date))
        assertEquals("9:41 PM", LocaleFormat.dateFormat("h:mm a", "jmm", Locale.US).format(date))
        assertEquals("OCTOBER 26, 2026", LocaleFormat.receiptDate(day, Locale.US))
        assertEquals("9pm", LocaleFormat.hourLabel(21, "9pm", Locale.US))
    }

    @Test
    fun `German dates put the day first, with German words`() {
        val de = Locale.GERMANY
        val long = LocaleFormat.dateFormat("d MMMM yyyy", "dMMMMyyyy", de).format(date)
        assertTrue(long, long.contains("Oktober") && long.indexOf("26") < long.indexOf("Oktober"))
        val weekday = LocaleFormat.dateFormat("EEEE d MMMM", "EEEEdMMMM", de).format(date)
        assertTrue(weekday, weekday.startsWith("Montag") && weekday.indexOf("26") < weekday.indexOf("Oktober"))
        // 24-hour clock, no English AM/PM.
        assertEquals("21:41", LocaleFormat.dateFormat("h:mm a", "jmm", de).format(date))
        assertTrue(LocaleFormat.hourLabel(21, "9pm", de).startsWith("21"))
    }

    @Test
    fun `Hindi dates put the day first, in Hindi`() {
        val hi = Locale.forLanguageTag("hi-IN")
        val long = LocaleFormat.dateFormat("d MMMM yyyy", "dMMMMyyyy", hi).format(date)
        // "26 अक्तूबर 2026": day, then the month in Devanagari, then the year.
        assertTrue(long, long.startsWith("26") && !long.contains("October"))
        assertTrue(long, long.any { Character.UnicodeBlock.of(it) == Character.UnicodeBlock.DEVANAGARI })
        assertTrue(LocaleFormat.hourLabel(21, "9pm", hi) != "9pm")
    }
}
