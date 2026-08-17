package com.dailyvox.app.ui

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

    private val _streak = MutableStateFlow(0)
    val streak: StateFlow<Int> = _streak

    private val _resolution = MutableStateFlow(0)
    val resolution: StateFlow<Int> = _resolution

    val entries: StateFlow<List<Entry>> = _query
        .flatMapLatest { q -> if (q.isBlank()) repo.observeAll() else repo.search(q) }
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

        repo.add(text, durationSec, audioPath, snapshot)
        refreshStats()
        // The widget is the only surface that can go stale without anyone
        // noticing -- it has no lifecycle of its own and its update period is an
        // hour. Push after every write, or tonight's star stays hollow until the
        // system feels like refreshing it.
        com.dailyvox.app.system.StarWidget.refresh(getApplication())
    }

    fun setSelfLabel(id: String, label: String?) = viewModelScope.launch {
        repo.setSelfLabel(id, label)
    }

    fun attachPhoto(id: String, path: String?) = viewModelScope.launch {
        repo.attachPhoto(id, path)
    }

    fun exportPdf(context: android.content.Context) = viewModelScope.launch {
        val all = repo.observeAll().first()
        if (all.isEmpty()) {
            toast(context, "Nothing to export yet.")
            return@launch
        }
        runCatching {
            com.dailyvox.app.system.Exporters.pdf(context, all, "")
        }.onSuccess {
            com.dailyvox.app.system.Exporters.share(context, it, "application/pdf")
        }.onFailure {
            toast(context, "Could not build the PDF.")
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
        if (bytes == null) { toast(context, "Could not read that file."); return@launch }

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
                toast(context, "That passphrase does not open this backup.")
                return@launch
            } catch (e: Exception) {
                toast(context, "That file is not a DailyVox backup.")
                return@launch
            }
        } else {
            String(bytes, Charsets.UTF_8)
        }
        val added = runCatching { repo.importJson(text) }.getOrElse {
            toast(context, "That does not look like a DailyVox export."); return@launch
        }
        refreshStats()
        com.dailyvox.app.system.StarWidget.refresh(getApplication())
        toast(context, if (added == 0) "Nothing new — those entries are already here."
                       else "Added ${'$'}added entries.")
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

    private fun renderJson(all: List<Entry>): String = buildString {
        append("{\n  \"app\": \"DailyVox for Android\",\n  \"entries\": [\n")
        all.forEachIndexed { i, e ->
            append("    {\"date\": ${e.createdAt}, \"seconds\": ${e.durationSec}, ")
            append("\"valence\": ${e.valence}, \"entities\": \"${e.entities}\", ")
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
                !ok -> "Could not write there."
                passphrase.isNullOrEmpty() -> "Journal written as readable JSON."
                else -> "Backup written. You will need that passphrase to restore it."
            },
        )
    }

    fun delete(id: String) = viewModelScope.launch {
        repo.delete(id); refreshStats()
        com.dailyvox.app.system.StarWidget.refresh(getApplication())
    }

    private suspend fun refreshStats() {
        _streak.value = repo.streakDays()
        _resolution.value = repo.resolution()
    }
}
