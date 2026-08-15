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

    fun add(text: String, durationSec: Int, audioPath: String? = null) = viewModelScope.launch {
        repo.add(text, durationSec, audioPath)
        refreshStats()
    }

    fun export(context: android.content.Context) = viewModelScope.launch {
        val all = entries.value
        val json = buildString {
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
        // Two files, deliberately. The encrypted one is the backup and can only
        // be read on this device; the plaintext one is the portability promise
        // and is the whole point of "never locked in".
        val plain = java.io.File(context.getExternalFilesDir(null), "dailyvox-export.json")
        plain.writeText(json)
        val sealed = runCatching {
            com.dailyvox.app.security.Vault.encryptToFile(context, json, "dailyvox-backup.dvx")
        }.getOrNull()
        val msg = if (sealed != null)
            "Exported ${all.size} entries — JSON + AES-256 backup"
        else
            "Exported ${all.size} entries as JSON (encryption unavailable on this device)"
        android.widget.Toast.makeText(context, msg, android.widget.Toast.LENGTH_LONG).show()
    }

    fun delete(id: String) = viewModelScope.launch { repo.delete(id); refreshStats() }

    private suspend fun refreshStats() {
        _streak.value = repo.streakDays()
        _resolution.value = repo.resolution()
    }
}
