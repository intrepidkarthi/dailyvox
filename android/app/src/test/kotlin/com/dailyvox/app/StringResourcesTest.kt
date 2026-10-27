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

    // ── B-15 part B: the rest of the app ───────────────────────────────────

    @Test
    fun `app shell, nav and toasts read exactly as before`() {
        assertEquals("Choose a passphrase", s(R.string.backup_passphrase_title))
        assertEquals(
            "This backup can be restored on any phone, including an iPhone, by anyone who knows " +
                "this passphrase. There is no way to recover it — write it down somewhere safe.",
            s(R.string.backup_passphrase_body),
        )
        assertEquals("Back up", s(R.string.backup_passphrase_confirm))
        assertEquals("Enter the passphrase this backup was made with.", s(R.string.restore_passphrase_body))
        assertEquals("DailyVox is locked", s(R.string.lock_title))
        assertEquals("Unlock DailyVox", s(R.string.applock_prompt_title))
        assertEquals("Your journal is locked on this device", s(R.string.applock_prompt_subtitle))
        assertEquals(
            listOf("Speak", "Journal", "Twin", "Ask"),
            com.dailyvox.app.ui.nav.Destination.entries.map { s(it.label) },
        )
        assertEquals("Nothing new — those entries are already here.", s(R.string.toast_import_nothing_new))
        // 1.2 said "Added 1 entries."; this round does not change English.
        assertEquals("Added 1 entries.", p(R.plurals.toast_import_added, 1, 1))
        assertEquals("Added 5 entries.", p(R.plurals.toast_import_added, 5, 5))
        assertEquals("Backup written. You will need that passphrase to restore it.", s(R.string.toast_backup_written))
    }

    @Test
    fun `speak, journal, ask and the dial read exactly as before`() {
        assertEquals("Still up", s(R.string.speak_greeting_night))
        assertEquals("✦ 12 this year", p(R.plurals.speak_year_count, 12, 12))
        assertEquals("Tap to record · 42 seconds", s(R.string.speak_tap_to_record))
        assertEquals("I can't talk right now", s(R.string.speak_cant_talk))
        assertEquals("today ✦ · 9:41 PM", s(R.string.speak_today_label, "9:41 PM"))
        assertEquals("Stop playing today's entry", s(R.string.speak_today_stop_description))
        assertEquals("typed, not recorded · stays on this phone", s(R.string.speak_typed_stored))
        assertEquals("Filed to your sky. 12 words · 0:42.",
                     s(R.string.reflection_spoken_header, s(R.string.reflection_label), "12 words · 0:42"))
        assertEquals("For tomorrow, in your words: “Call Mum.”",
                     s(R.string.reflection_spoken_tomorrow, s(R.string.reflection_tomorrow_label), "“Call Mum.”"))

        assertEquals("Play today · 1:05", s(R.string.journal_play_today, 1, 5))
        assertEquals("Playing · 0:42", s(R.string.journal_playing, 0, 42))
        assertEquals("Today's entries have no audio saved.", s(R.string.journal_play_today_no_audio))
        assertEquals(
            "TONIGHT · 9:41 PM · 0:42 · 87 WORDS",
            s(R.string.journal_card_meta, "TONIGHT · 9:41 PM", "0:42", p(R.plurals.journal_card_words, 87, 87)),
        )
        // 1.2 printed "1 WORDS"; this round does not change English.
        assertEquals("1 WORDS", p(R.plurals.journal_card_words, 1, 1))
        assertEquals("7.5H SLEEP", s(R.string.journal_card_sleep, 7.5f))
        assertEquals("Yesterday · 9:41 PM", s(R.string.journal_when_yesterday, "9:41 PM"))
        assertEquals("Mon 26 · 9:41 PM", s(R.string.journal_when_day, "Mon 26", "9:41 PM"))
        assertEquals(
            "Recorded, but this phone did not transcribe it. The audio is saved — tap to play.",
            s(R.string.journal_card_untranscribed),
        )
        assertEquals("Nothing here reads strongly either way — that is its own kind of week.",
                     s(R.string.journal_empty_filter_mood))
        assertEquals("Twin noticed: sleep shows up. Ask about it.", s(R.string.journal_twin_noticed, "sleep shows up"))

        assertEquals("answers with receipts · 0 network calls", s(R.string.ask_subtitle))
        assertEquals(
            "Ask something, or pick one below. Every answer comes from your own entries and names " +
                "the ones it used. Anything else, it finds rather than answers: the closest entries, " +
                "quoted as you said them.",
            s(R.string.ask_intro),
        )
        assertEquals("OCT 26 · 87%", s(R.string.ask_cite_chip, "OCT 26", 87))
        assertEquals("1 CITED ✦", p(R.plurals.ask_cited, 1, 1))
        assertEquals("Ask, or find what you said about…", s(R.string.ask_placeholder))

        assertEquals("● RECORDING · ON-DEVICE · 0 B OUT", s(R.string.dial_status_recording))
        assertEquals("❙❙ PAUSED · ON-DEVICE · 0 B OUT", s(R.string.dial_status_paused))
        assertEquals("OF 0:42 · 17 TICKS LIT", s(R.string.dial_ticks_lit, 17))
        assertEquals("“…and then we walked”", s(R.string.dial_partial, "and then we walked"))
        assertEquals("SARAH ✦ FILED TO YOUR SKY", s(R.string.dial_filed, "SARAH"))
        assertEquals("Stop & keep ✦", s(R.string.dial_stop_keep))
    }

    @Test
    fun `twin, insights, share sheet and widgets read exactly as before`() {
        assertEquals("38 ✦ · EARLY", s(R.string.twin_star_count, 38, s(R.string.twin_depth_early)))
        assertEquals(
            "Who you are: warm, steady, expansive — from 12 entries.",
            p(R.plurals.twin_summary, 12, s(R.string.twin_tone_warm), s(R.string.twin_length_expansive), 12),
        )
        assertEquals(
            "Some names are reaching your journal spelled both ways — Ravi, Asha — so the Twin can't " +
                "count them as one person. Correcting a transcript on an entry teaches it the right spelling.",
            s(R.string.twin_casing_inconsistent, "Ravi, Asha"),
        )
        assertEquals(
            "No names have come through yet. Either you haven't spoken about anyone, or this phone's " +
                "speech recogniser isn't capitalising names — which is what the Twin reads them by.",
            s(R.string.twin_casing_none),
        )
        assertEquals("3 of 5", s(R.string.goal_progress, 3, 5))
        assertEquals("1 day left", p(R.plurals.goal_days_left, 1, 1))
        assertEquals("4 days left", p(R.plurals.goal_days_left, 4, 4))
        assertEquals("Nights, not entries — one evening counts once.", s(R.string.goal_counting_note))

        assertEquals("Rendered on this phone and handed to whatever you pick. DailyVox has no way to send it itself.",
                     s(R.string.share_sheet_intro))
        assertEquals("Off — the card says “someone”.", s(R.string.share_sheet_names_off))
        assertEquals("DAILYVOX  ·  RECORDED ON DEVICE", s(R.string.share_entry_card_footer))

        assertEquals("Downloading the speech pack · 40%", s(R.string.speech_pack_progress, 40))
        assertEquals("Asking your phone's speech service for the pack…", s(R.string.speech_pack_requested))

        assertEquals("5 nights, which is what you set out to do.", p(R.plurals.goal_notification_met, 5, 5))
        assertEquals("6 nights this week, past the 5 you set.", p(R.plurals.goal_notification_past, 6, 6, 5))
        assertEquals("1:05 · on-device · 0 bytes out", s(R.string.recording_notification_text, 1, 5))
        assertEquals("A nudge to record tonight's entry.", s(R.string.reminder_channel_description))
        assertEquals("38 IN YOUR SKY", p(R.plurals.widget_in_your_sky, 38, 38))
        assertEquals("0 IN YOUR SKY", s(R.string.widget_in_your_sky_placeholder))
        assertEquals("Tonight's star", s(R.string.widget_star_description))

        assertEquals("1 entries", p(R.plurals.export_pdf_entries, 1, 1))
        assertEquals("  ·  mood +0.35", s(R.string.export_pdf_mood, 0.35f))
        assertEquals("valence -0.20", s(R.string.export_md_valence, -0.2f))
        assertEquals("The recogniser returned no words for this recording.", s(R.string.transcribe_no_words))
    }

    @Test
    fun `mood words are the research canon's English words`() {
        // SelfLabels.CANON is the study contract; the picker now reads strings.xml.
        com.dailyvox.app.system.SelfLabels.CANON.forEach { (key, word) ->
            assertEquals(word, com.dailyvox.app.ui.components.moodWord(res, key))
        }
        // A label saved under the old Android set keeps its canon word...
        assertEquals("Sadness", com.dailyvox.app.ui.components.moodWord(res, "sad"))
        // ...and one with no canon counterpart is shown as it was stored.
        assertEquals("calm", com.dailyvox.app.ui.components.moodWord(res, "calm"))
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
