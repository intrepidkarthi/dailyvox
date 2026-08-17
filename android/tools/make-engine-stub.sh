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
KOT

echo "Wrote engine stub to $DEST"
echo "This build will NOT detect names or score mood. It is for compilation only."
