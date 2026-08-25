#!/usr/bin/env bash
# Generates a STUB of the private Twin engine so the app compiles without it.
#
# The engine is proprietary and lives in a separate private repository. Anyone
# without access — a fork, an outside pull request, or CI on the public repo —
# still needs the app itself to compile, or app-side breakage goes unnoticed
# until a maintainer happens to build locally.
#
# What this produces is NOT a working engine. Every function returns an empty or
# neutral value, loudly enough that nobody mistakes a stub build for a real one:
# no names are detected, every mood is 0.0, and prosody is unavailable. It exists
# to typecheck the app, nothing more.
#
# KEEP IT IN STEP WITH THE APP. This file is the only thing standing between an
# outside contributor and a build that cannot compile, and it goes stale in
# exactly one way: someone adds an engine call to the app, builds locally
# against the real engine, and never learns the stub lost a symbol. That is how
# it broke -- the Ask Your Twin work added six types and the findings move added
# a seventh, and CI on the public repo failed on `Assemble` from then on.
#
# The surface below must equal what the app imports. To check:
#
#     grep -rhoE "com\.dailyvox\.twin\.[A-Za-z]+" app/src | sort -u
set -euo pipefail

DEST="${1:-$(cd "$(dirname "$0")/../.." && pwd)/DailyVoxTwin/kotlin/engine}"
SRC="$DEST/src/main/kotlin/com/dailyvox/twin"

if [ -f "$SRC/NameDetector.kt" ]; then
  echo "Real engine already present at $DEST — refusing to overwrite it."
  exit 0
fi

mkdir -p "$SRC"

cat > "$DEST/build.gradle.kts" <<'KTS'
plugins { kotlin("jvm") }
kotlin { jvmToolchain(21) }
KTS

cat > "$SRC/Stub.kt" <<'KOT'
// GENERATED STUB — not the real DailyVox Twin engine.
//
// Present so the app compiles without the private engine. Every value here is
// empty or neutral on purpose. A build using this file detects no names, scores
// every entry 0.0, and reports no prosody.
package com.dailyvox.twin

const val DAILYVOX_ENGINE_IS_STUB = true

object NameDetector {
    fun vocabulary(texts: List<String>): Pair<Set<String>, Set<String>> = emptySet<String>() to emptySet()
    fun extract(text: String, midSentence: Set<String>, seenLower: Set<String>): List<String> = emptyList()
    fun detect(text: String, corpus: List<String>): List<String> = emptyList()
}

object Sentiment {
    val entryCount: Int get() = 0
    fun parseLexicon(lines: Sequence<String>): Map<String, Float> = emptyMap()
    fun install(table: Map<String, Float>) {}
    fun valence(text: String): Float = 0f
    fun valence(text: String, table: Map<String, Float>): Float = 0f
}

data class ProsodyFeatures(
    val speakingRate: Double, val pitchMean: Double, val pitchVariability: Double,
    val energyMean: Double, val energyVariability: Double, val pauseRatio: Double,
    val longPauseCount: Int, val durationSeconds: Double,
) {
    val available: Boolean get() = false
    companion object { val UNAVAILABLE = ProsodyFeatures(0.0,0.0,0.0,0.0,0.0,0.0,0,0.0) }
}

object Prosody {
    fun analyse(pcm: ShortArray, sampleRate: Int, wordCount: Int): ProsodyFeatures =
        ProsodyFeatures.UNAVAILABLE
}

// ── The chat surface ─────────────────────────────────────────────────────────
// Field-for-field with the real ChatEntry, because the app constructs it by
// named argument and a missing parameter is a compile error rather than a
// degraded answer.
data class ChatEntry(
    val id: String,
    val createdAt: Long,
    val text: String,
    val valence: Float,
    val entities: List<String> = emptyList(),
    val sleepHours: Float? = null,
    val hourOfDay: Int? = null,
    val dayOfWeek: Int? = null,
    val stepsToday: Int? = null,
    val speakingRate: Float? = null,
)

data class PersonNode(val label: String, val mentions: Int, val sentimentAssociation: Double)

data class TwinChatEvidence(
    val entryId: String,
    val date: Long,
    val snippet: String,
    val score: Float,
)

data class TwinChatTurn(
    val answer: String,
    val citations: List<TwinChatEvidence> = emptyList(),
    val suggestedFollowUps: List<String> = emptyList(),
    val usedFallback: Boolean = true,
)

class TwinFacts private constructor() {
    val hasEnoughData: Boolean get() = false
    companion object { fun from(entries: List<ChatEntry>): TwinFacts = TwinFacts() }
}

// The real bank has ten questions with fixed wording shared with iOS. A stub
// with no questions is the honest shape: `available` returns nothing, so the
// Ask screen shows its empty state rather than offering a question that would
// be answered with silence.
enum class TwinQuestion(val text: String) {
    PLACEHOLDER("");
    companion object {
        fun matching(text: String): TwinQuestion? = null
        fun available(facts: TwinFacts): List<TwinQuestion> = emptyList()
    }
}

object TwinResponseGenerator {
    fun answer(question: TwinQuestion, facts: TwinFacts): TwinChatTurn =
        TwinChatTurn(answer = "")
}

object RetrievalAnswerComposer {
    fun compose(question: String, evidence: List<TwinChatEvidence>, facts: TwinFacts): TwinChatTurn =
        TwinChatTurn(answer = "")
}

// ── Findings ─────────────────────────────────────────────────────────────────
object Insights {
    data class Finding(val lead: String, val detail: String, val effect: Double)
    fun find(entries: List<ChatEntry>): List<Finding> = emptyList()
}
KOT

echo "Wrote engine stub to $DEST"
echo "This build will NOT detect names or score mood. It is for compilation only."
