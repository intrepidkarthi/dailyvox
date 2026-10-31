package com.dailyvox.app.system

import java.time.LocalDate
import java.time.Month
import java.time.format.DateTimeFormatter
import java.time.format.FormatStyle
import java.time.format.TextStyle
import java.util.Locale

/**
 * Dates, months and capitals in the reader's language (plan B-13).
 *
 * Two rules, and the second is the one that keeps this safe to ship:
 *
 *  1. Outside English, the PLATFORM decides the shape: `ofLocalizedDate` and
 *     `getBestDateTimePattern` know that German writes "26. Oktober 2026" and
 *     Hindi uses a 12-hour clock with its own day-period words. A fixed
 *     English pattern fed a German locale gives "Oktober 26, 2026", which is
 *     no one's way of writing a date.
 *  2. In English, every surface prints EXACTLY what it printed in 1.2. The
 *     patterns there are design decisions ("MMMM d, yyyy" on the receipt),
 *     and an English user must not see their app change because another
 *     language was added. The tests pin both halves.
 *
 * Machine formats (the CSV's ISO stamp, the research export) are not here and
 * must never be: they use Locale.ROOT so a file reads the same on every phone.
 */
object LocaleFormat {

    private fun isEnglish(locale: Locale) = locale.language == "en"

    /**
     * Capitals for display, in the reader's rules. Kotlin's bare `uppercase()`
     * is Locale.ROOT: Turkish "istanbul" then becomes "ISTANBUL" with a dotless
     * I, which is a different letter there. Identical to `uppercase()` for every
     * English string.
     */
    fun upper(text: String, locale: Locale = Locale.getDefault()): String = text.uppercase(locale)

    /**
     * The privacy receipt's date line. 1.2 forced Locale.US ("OCTOBER 26,
     * 2026") on every phone, so a French user's card had an English month.
     */
    fun receiptDate(date: LocalDate, locale: Locale = Locale.getDefault()): String {
        val formatter = if (isEnglish(locale)) DateTimeFormatter.ofPattern("MMMM d, yyyy", locale)
                        else DateTimeFormatter.ofLocalizedDate(FormatStyle.LONG).withLocale(locale)
        return upper(date.format(formatter), locale)
    }

    /**
     * A month on its own ("Warmest month: March"). The STANDALONE form: Slavic
     * and Baltic languages decline a month inside a date ("marca") and not on
     * its own ("marzec"), and "MMMM" is the in-a-date form.
     */
    fun monthName(month: Month, locale: Locale = Locale.getDefault()): String {
        val name = month.getDisplayName(TextStyle.FULL_STANDALONE, locale)
        // Some locales (es, fr, it, pt) write months lower-case; on a card it is a heading.
        return name.replaceFirstChar { if (it.isLowerCase()) it.titlecase(locale) else it.toString() }
    }

    /** [monthName] from a `Calendar.MONTH` index (0 = January). */
    fun monthName(calendarMonth: Int, locale: Locale = Locale.getDefault()): String =
        monthName(Month.of(calendarMonth + 1), locale)

    /**
     * A SimpleDateFormat pattern for [skeleton] in [locale]: [englishPattern]
     * unchanged in English, the platform's best pattern otherwise. [best] is
     * `android.text.format.DateFormat::getBestDateTimePattern`, injected so the
     * English half is provable without a phone.
     */
    fun pattern(
        englishPattern: String,
        skeleton: String,
        locale: Locale = Locale.getDefault(),
        best: (Locale, String) -> String = { l, s -> android.text.format.DateFormat.getBestDateTimePattern(l, s) },
    ): String = if (isEnglish(locale)) englishPattern
                else runCatching { best(locale, skeleton) }.getOrDefault(englishPattern)

    /**
     * An hour on its own, as on the reminder chips. [english] is the label the
     * English UI has always shown ("9pm", "noon") and is returned unchanged in
     * English; elsewhere the platform's hour skeleton decides ("21 Uhr",
     * "रात 9 बजे"), so no clock is assembled from English parts.
     */
    fun hourLabel(
        hour: Int,
        english: String,
        locale: Locale = Locale.getDefault(),
        best: (Locale, String) -> String = { l, s -> android.text.format.DateFormat.getBestDateTimePattern(l, s) },
    ): String {
        if (isEnglish(locale)) return english
        val p = runCatching { best(locale, "j") }.getOrNull() ?: return english
        return runCatching {
            java.time.LocalTime.of(hour, 0).format(DateTimeFormatter.ofPattern(p, locale))
        }.getOrDefault(english)
    }

    /** A ready formatter for [pattern]. */
    fun dateFormat(englishPattern: String, skeleton: String, locale: Locale = Locale.getDefault()) =
        java.text.SimpleDateFormat(pattern(englishPattern, skeleton, locale), locale)
}
