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

    fun add(text: String, durationSec: Int) = viewModelScope.launch {
        repo.add(text, durationSec)
        refreshStats()
    }

    fun delete(id: String) = viewModelScope.launch { repo.delete(id); refreshStats() }

    private suspend fun refreshStats() {
        _streak.value = repo.streakDays()
        _resolution.value = repo.resolution()
    }
}
