package com.dailyvox.app.audio

import java.util.Locale

/**
 * Comparing the language tags a recogniser reports against the one the user
 * speaks (plan B-8).
 *
 * Recognisers do not spell languages the way `Locale` does. Google's on-device
 * service reports Mandarin as `cmn-Hans-CN` while a phone set to Chinese says
 * `zh-CN`; older packs use `en_US` with an underscore; Java still hands out the
 * legacy `iw` / `in` for Hebrew and Indonesian on some paths. A plain string
 * compare calls all of those "not installed", and the user is told to download
 * a pack they already have.
 *
 * What this will NOT do is call two different writing systems the same
 * language. A phone set to Traditional Chinese (zh-TW) is not served by a
 * Simplified pack: the words would come back in the wrong script, which is the
 * "confident, wrong entry" the whole port refuses. Unknown script on either side
 * stays compatible, because most languages only have one.
 */
internal object LanguageTags {

    data class Parts(val language: String, val script: String?, val region: String?)

    /** ISO 639-3 or legacy codes a recogniser may report, to the code a Locale uses. */
    private val LANGUAGE_ALIASES = mapOf(
        "cmn" to "zh",   // Mandarin, as Google's recogniser spells it
        "iw" to "he",
        "in" to "id",
        "ji" to "yi",
    )

    fun parts(tag: String): Parts {
        val loc = Locale.forLanguageTag(tag.trim().replace('_', '-'))
        val raw = loc.language.lowercase(Locale.ROOT)
        val language = LANGUAGE_ALIASES[raw] ?: raw
        val region = loc.country.uppercase(Locale.ROOT).ifEmpty { null }
        val script = loc.script.ifEmpty { null }?.let {
            it.substring(0, 1).uppercase(Locale.ROOT) + it.substring(1).lowercase(Locale.ROOT)
        } ?: impliedScript(language, region)
        return Parts(language, script, region)
    }

    fun parts(locale: Locale): Parts = parts(locale.toLanguageTag())

    /**
     * Chinese is the one Tier 1-adjacent language whose script is decided by
     * region rather than written in the tag. Without this, `zh-TW` and
     * `cmn-Hans-CN` would both have a null-vs-Hans script and look compatible.
     */
    private fun impliedScript(language: String, region: String?): String? = when (language) {
        "zh" -> when (region) {
            "TW", "HK", "MO" -> "Hant"
            "CN", "SG", "MY" -> "Hans"
            else -> null
        }
        else -> null
    }

    private fun scriptsAgree(a: String?, b: String?) = a == null || b == null || a == b

    /** Same language, same script, same region: `cmn-Hans-CN` is `zh-CN`. */
    fun same(a: String, b: String): Boolean {
        val x = parts(a); val y = parts(b)
        return x.language.isNotEmpty() && x.language == y.language && x.region == y.region &&
            scriptsAgree(x.script, y.script)
    }

    /** Same language and a compatible script, region ignored: en-US serves en-IN. */
    fun sameLanguage(a: String, b: String): Boolean {
        val x = parts(a); val y = parts(b)
        return x.language.isNotEmpty() && x.language == y.language && scriptsAgree(x.script, y.script)
    }

    /** A Locale the platform can name and speak: aliases resolved, script kept. */
    fun toLocale(tag: String): Locale {
        val p = parts(tag)
        return Locale.Builder().setLanguage(p.language)
            .apply { p.script?.let { runCatching { setScript(it) } } }
            .apply { p.region?.let { runCatching { setRegion(it) } } }
            .build()
    }

    /** "Hindi (India)", in the language the UI is in. */
    fun displayName(tag: String, uiLocale: Locale = Locale.getDefault()): String {
        val name = toLocale(tag).getDisplayName(uiLocale)
        return name.replaceFirstChar { if (it.isLowerCase()) it.titlecase(uiLocale) else it.toString() }
    }

    /** Just the language, no region: "Hindi", for sentences like "needs a download". */
    fun languageName(tag: String, uiLocale: Locale = Locale.getDefault()): String {
        val name = toLocale(tag).getDisplayLanguage(uiLocale).ifEmpty { tag }
        return name.replaceFirstChar { if (it.isLowerCase()) it.titlecase(uiLocale) else it.toString() }
    }

    /** One entry per language variant, first spelling kept, in display order. */
    fun distinct(tags: List<String>): List<String> {
        val out = mutableListOf<String>()
        tags.map { it.trim() }.filter { it.isNotEmpty() }.forEach { t ->
            if (out.none { same(it, t) }) out += t
        }
        return out
    }
}

/**
 * Which installed pack to speak to, given the language the user speaks.
 *
 * Exact tag first (after normalisation: `cmn-Hans-CN` IS `zh-CN`), then any
 * pack in the same LANGUAGE and script -- en-US is the right answer for a phone
 * set to en-IN. Then nothing. There used to be a third step, `langs.first()`,
 * "because a recogniser with one language is better used than not" -- and that
 * is how a phone set to Hindi with only an English pack transcribed Hindi
 * speech as English words. Null means the caller raises
 * ERROR_LANGUAGE_UNAVAILABLE and offers the download for the right language.
 */
internal fun pickRecognizerLanguage(langs: List<String>, want: Locale): String? {
    if (langs.isEmpty()) return null
    val tag = want.toLanguageTag()
    langs.firstOrNull { it.replace('_', '-').equals(tag, true) }?.let { return it }
    langs.firstOrNull { LanguageTags.same(it, tag) }?.let { return it }
    return langs.firstOrNull { LanguageTags.sameLanguage(it, tag) }
}

/**
 * The tag to hand the recogniser for a SAVED recording (transcribe later).
 *
 * The entry's own language wins: it is what the words were spoken in, and the
 * speaking language may have changed since. Otherwise the installed pack for
 * the language the user speaks now. When the probe has recorded no packs at
 * all the wanted tag itself is asked for -- the recogniser then answers with a
 * real error if it lacks it, which is what 1.2 did with the phone's locale.
 *
 * Null when the packs are known and none of them can hear this language: the
 * caller says so instead of transcribing Hindi through an English model.
 */
internal fun fileTranscriptionTag(entryLanguage: String?, installed: List<String>, want: Locale): String? {
    if (installed.isEmpty()) return entryLanguage ?: want.toLanguageTag()
    if (entryLanguage != null) {
        return pickRecognizerLanguage(installed, LanguageTags.toLocale(entryLanguage))
    }
    return pickRecognizerLanguage(installed, want)
}

/** One row of the "Language you speak" picker. */
internal data class SpeakingOption(
    /** Null is "same as the phone". */
    val tag: String?,
    val label: String,
    val state: State,
) {
    enum class State {
        /** An installed pack can hear it now. */
        ON_PHONE,
        /** The recogniser lists it as downloadable (or has not said): one download away. */
        NEEDS_DOWNLOAD,
        /** Known packs, none for this language. Only ever the "same as phone" row. */
        UNAVAILABLE,
    }
}

/**
 * The picker's rows (B-8): "same as phone" first, then every language the
 * on-device recogniser says it has or can fetch, one row per variant, sorted
 * by name in the UI's language. Nothing else: a language with no on-device
 * model is not offered, because choosing it could only ever fail.
 */
internal fun speakingOptions(
    installed: List<String>,
    supported: List<String>,
    phone: Locale,
    uiLocale: Locale = Locale.getDefault(),
): List<SpeakingOption> {
    val phoneState = when {
        pickRecognizerLanguage(installed, phone) != null -> SpeakingOption.State.ON_PHONE
        supported.isEmpty() && installed.isEmpty() -> SpeakingOption.State.NEEDS_DOWNLOAD
        pickRecognizerLanguage(supported, phone) != null -> SpeakingOption.State.NEEDS_DOWNLOAD
        else -> SpeakingOption.State.UNAVAILABLE
    }
    val phoneRow = SpeakingOption(null, LanguageTags.displayName(phone.toLanguageTag(), uiLocale), phoneState)
    val collator = java.text.Collator.getInstance(uiLocale)
    val rows = LanguageTags.distinct(installed + supported).map { tag ->
        SpeakingOption(
            tag = tag,
            label = LanguageTags.displayName(tag, uiLocale),
            state = if (installed.any { LanguageTags.same(it, tag) }) SpeakingOption.State.ON_PHONE
                    else SpeakingOption.State.NEEDS_DOWNLOAD,
        )
    }.sortedWith(compareBy(collator) { it.label })
    return listOf(phoneRow) + rows
}
