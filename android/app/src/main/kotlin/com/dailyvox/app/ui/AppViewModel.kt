package com.dailyvox.app.ui

import com.dailyvox.app.R

import android.app.Application
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import com.dailyvox.app.data.Entry
import com.dailyvox.app.data.Repo
import kotlinx.coroutines.flow.*
import kotlinx.coroutines.launch

class AppViewModel(app: Application) : AndroidViewModel(app) {
    private val repo = Repo.get(app)

    private val _query = MutableStateFlow("")
    val query: StateFlow<String> = _query

    private val _resolution = MutableStateFlow(0)
    val resolution: StateFlow<Int> = _resolution

    /**
     * The reflection on the entry just saved, for the Speak screen. Null until
     * something is saved and again once the user closes it or starts the next
     * one. Process death drops it, which is fine: it is a moment, not a record.
     */
    private val _reflection = MutableStateFlow<com.dailyvox.app.system.Reflection.Card?>(null)
    val reflection: StateFlow<com.dailyvox.app.system.Reflection.Card?> = _reflection

    fun dismissReflection() { _reflection.value = null }

    /**
     * A mood picked (or cleared, with null) on the reflection card. The card
     * updates at once and the row follows; both apply the same rule, so the
     * suggestion is kept beside a choice and dropped with a clear.
     */
    fun setReflectionMood(label: String?) {
        val card = _reflection.value ?: return
        _reflection.value = card.withMood(label)
        viewModelScope.launch { repo.setSelfLabel(card.entryId, label) }
    }

    val entries: StateFlow<List<Entry>> = _query
        .flatMapLatest { q -> if (q.isBlank()) repo.observeAll() else repo.search(q) }
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    /**
     * Every entry, never search-filtered. What Today brings back from the past
     * must not depend on whatever is still typed in the Journal search box.
     */
    val all: StateFlow<List<Entry>> = repo.observeAll()
        .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    init {
        viewModelScope.launch {
            repo.seedIfEmpty(getApplication())
            refreshStats()
        }
    }

    fun setQuery(q: String) { _query.value = q }

    private val body = com.dailyvox.app.body.BodySignals(app)

    fun add(text: String, durationSec: Int, audioPath: String? = null) = viewModelScope.launch {
        val prefs = getApplication<Application>()
            .getSharedPreferences("dailyvox", android.content.Context.MODE_PRIVATE)
        val snapshot = if (prefs.getBoolean("body", false)) {
            runCatching { body.read() }.getOrNull()
        } else null

        // The tag the recogniser was asked for in the session that produced
        // these words (B-2). Typed text is classified inside Repo instead.
        val spoken = com.dailyvox.app.audio.SpeechCapture.lastSessionLanguage(getApplication())
        val saved = repo.add(text, durationSec, audioPath, snapshot, spokenLanguage = spoken)
        // Off the saved row and the rest of the table, nothing else. Wrapped so
        // a reflection that cannot be built never looks like a failed save.
        _reflection.value = runCatching {
            com.dailyvox.app.system.Reflection.of(saved, repo.observeAll().first())
        }.getOrNull()
        refreshStats()
        // The widget is the only surface that can go stale without anyone
        // noticing -- it has no lifecycle of its own and its update period is an
        // hour. Push after every write, or tonight's star stays hollow until the
        // system feels like refreshing it.
        com.dailyvox.app.system.StarWidget.refresh(getApplication())
    }

    /**
     * Correct what the recogniser heard (B4's Edit).
     *
     * Re-derives valence and entities from the corrected text rather than
     * keeping the originals: the whole point of fixing a transcript is that the
     * Twin was working from the wrong words, and leaving the derived fields
     * alone would fix what the user reads and not what the Twin knows.
     */
    fun editText(id: String, text: String, language: String? = null) = viewModelScope.launch {
        repo.updateText(id, text, language)
    }

    fun setSelfLabel(id: String, label: String?) = viewModelScope.launch {
        // Picked on the entry page while that entry's card is still up on
        // Speak: the card must not go on showing the old mood.
        _reflection.value?.takeIf { it.entryId == id }?.let { _reflection.value = it.withMood(label) }
        repo.setSelfLabel(id, label)
    }

    fun attachPhoto(id: String, path: String?) = viewModelScope.launch {
        repo.attachPhoto(id, path)
    }

    fun exportPdf(context: android.content.Context) = viewModelScope.launch {
        val all = repo.observeAll().first()
        if (all.isEmpty()) {
            toast(context, context.getString(R.string.toast_export_empty))
            return@launch
        }
        runCatching {
            com.dailyvox.app.system.Exporters.pdf(context, all, "")
        }.onSuccess {
            com.dailyvox.app.system.Exporters.share(context, it, "application/pdf")
        }.onFailure {
            toast(context, context.getString(R.string.toast_export_pdf_failed))
        }
    }

    fun importFrom(
        context: android.content.Context,
        uri: android.net.Uri,
        passphrase: String? = null,
        onPassphraseNeeded: (android.net.Uri) -> Unit = {},
    ) = viewModelScope.launch {
        val bytes = runCatching {
            context.contentResolver.openInputStream(uri)!!.use { it.readBytes() }
        }.getOrNull()
        if (bytes == null) { toast(context, context.getString(R.string.toast_import_unreadable)); return@launch }

        // Sniff the container rather than trusting the extension. A backup the
        // app cannot read back is not a backup, and .dvx is the format the
        // "Back up my journal" button produces — restoring it has to be the
        // same one tap.
        val sealed = bytes.size > 4 &&
            bytes.copyOfRange(0, 4).contentEquals("DVX1".toByteArray(Charsets.US_ASCII))
        if (sealed && passphrase.isNullOrEmpty()) {
            onPassphraseNeeded(uri)
            return@launch
        }
        val text = if (sealed) {
            try {
                com.dailyvox.app.security.Vault.decrypt(bytes, passphrase!!)
            } catch (e: com.dailyvox.app.security.Vault.WrongPassphrase) {
                toast(context, context.getString(R.string.toast_import_wrong_passphrase))
                return@launch
            } catch (e: Exception) {
                toast(context, context.getString(R.string.toast_import_not_backup))
                return@launch
            }
        } else {
            String(bytes, Charsets.UTF_8)
        }
        val added = runCatching { repo.importJson(text) }.getOrElse {
            toast(context, context.getString(R.string.toast_import_not_export)); return@launch
        }
        refreshStats()
        com.dailyvox.app.system.StarWidget.refresh(getApplication())
        toast(context, if (added == 0) context.getString(R.string.toast_import_nothing_new)
                       else context.resources.getQuantityString(R.plurals.toast_import_added, added, added))
    }

    private fun toast(context: android.content.Context, msg: String) =
        android.widget.Toast.makeText(context, msg, android.widget.Toast.LENGTH_LONG).show()

    /**
     * Builds the two export payloads. Writing them is the CALLER's job, through
     * the Storage Access Framework, because where they land is the whole point.
     *
     * The first version wrote to getExternalFilesDir(), which Android deletes
     * when the app is uninstalled — so the "backup" disappeared at exactly the
     * moment it was needed, and it was also invisible to every file manager. A
     * backup you cannot find and that dies with the app is not a backup.
     */
    suspend fun buildExport(): String = renderJson(repo.observeAll().first())

    /**
     * Every entry, regardless of the Journal search box. `entries` is the
     * search-filtered list, so exporting from it while a query was typed
     * silently wrote a partial journal to the file.
     */
    suspend fun allEntries(): List<Entry> = repo.observeAll().first()

    private fun renderJson(all: List<Entry>): String = buildString {
        append("{\n  \"app\": \"DailyVox for Android\",\n  \"entries\": [\n")
        all.forEachIndexed { i, e ->
            append("    {\"date\": ${e.createdAt}, \"seconds\": ${e.durationSec}, ")
            append("\"valence\": ${e.valence}, \"entities\": \"${e.entities}\", ")
            // Only when known. A reader that does not know the key ignores it;
            // this app's own import keeps it rather than re-guessing (B-2).
            e.language?.let { append("\"language\": ${org.json.JSONObject.quote(it)}, ") }
            append("\"text\": ${org.json.JSONObject.quote(e.text)}}")
            if (i < all.size - 1) append(",")
            append("\n")
        }
        append("  ]\n}\n")
    }

    fun writeExport(
        context: android.content.Context,
        uri: android.net.Uri,
        passphrase: String?,
    ) = viewModelScope.launch {
        val json = buildExport()
        val bytes = if (passphrase.isNullOrEmpty()) json.toByteArray(Charsets.UTF_8)
                    else com.dailyvox.app.security.Vault.encrypt(json, passphrase)
        val ok = runCatching {
            context.contentResolver.openOutputStream(uri)!!.use { it.write(bytes) }
        }.isSuccess
        toast(
            context,
            when {
                !ok -> context.getString(R.string.toast_write_failed)
                passphrase.isNullOrEmpty() -> context.getString(R.string.toast_export_json_written)
                else -> context.getString(R.string.toast_backup_written)
            },
        )
    }

    /**
     * The study export. Reads the whole table, not [entries]: that flow is the
     * Journal's search results, and an export taken with a search still typed
     * in would silently hand the study a fraction of someone's diary.
     */
    fun writeResearchExport(context: android.content.Context, uri: android.net.Uri) =
        viewModelScope.launch {
            val all = repo.observeAll().first()
            val json = com.dailyvox.app.system.Research.export(
                all, com.dailyvox.app.system.Research.device(context))
            val ok = runCatching {
                context.contentResolver.openOutputStream(uri)!!.use {
                    it.write(json.toByteArray(Charsets.UTF_8))
                }
            }.isSuccess
            toast(context, context.getString(if (ok) R.string.toast_research_written else R.string.toast_write_failed))
        }

    fun delete(id: String) = viewModelScope.launch {
        repo.delete(id); refreshStats()
        com.dailyvox.app.system.StarWidget.refresh(getApplication())
    }

    private suspend fun refreshStats() {
        _resolution.value = repo.resolution()
    }
}
