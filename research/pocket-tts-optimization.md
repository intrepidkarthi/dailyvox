# Pocket TTS Optimization for DailyVox on iPhone

> **CLOSED 2026-08-10. Everything below is a record of a path we did not take.**
>
> Pocket TTS was rejected as a ship candidate after a controlled blind test. Eight forced-choice
> trials, each pairing a real recording of Karthik against sherpa-onnx INT8 Pocket TTS speaking the
> same words, with sample rate, RMS loudness and clip length all matched. He scored **8/8**
> (p = 0.0039). Trials 3-8 used exclusively held-out audio the model had never been conditioned on.
>
> This also overturns the premise of this document. The 28 Jul "A92" approval that justified the work
> was a *relative* judgement — better than OpenVoice, better than MOSS — not an absolute one. There was
> never a demonstrated bar for Pocket TTS to clear.
>
> The memory gate failed independently. Measured peak against a ~250 MB ceiling: sherpa-onnx INT8
> **685 MB** (377 MB after model load alone), FluidAudio CoreML **957 MB**. The ~159 MB projection
> below is wrong by roughly 4x, and every projection in this program has erred in the same direction.
>
> What ships remains v1.9's system-voice picker: accent approximated, not reproduced.
>
> **The lesson worth carrying forward:** comparing two synthetic clips tells you which is less bad, not
> whether either is good. Gate any future voice candidate on a forced-choice real-vs-synthetic blind
> test with format tells controlled, run *before* integration work. That test took about an hour and
> settled what three runtime spikes over two weeks could not.

## Context

DailyVox v1.10 aims to ship "your own voice" — the Twin reads replies aloud in the user's own accent, cloned from a 30-second slice of existing journal audio. The candidate is Kyutai Pocket TTS (109.5M params, autoregressive, BF16). The spike succeeded on 2026-07-28, reproducing Karthik's voice from journal audio. The feature is gated on a **measured** (not projected) iPhone peak memory footprint, after the chatterbox-turbo failure (projected to fit, measured 953.7 MB against a ~250 MB ceiling).

## Model Architecture

Pocket TTS has three components:

| Component | Purpose | Layers | Hidden Dim |
|-----------|---------|--------|------------|
| FlowLM | Autoregressive backbone transformer | 6 | 1024 (16 heads) |
| FlowNet | Flow-matching ODE step network | 6 residual blocks | 512 |
| Mimi Decoder | Latent → audio decoder | 2 transformer + SEANet | — |
| Mimi Encoder | Voice reference encoder | — | — |
| Text Conditioner | Phoneme → text embeddings | — | — |

The model is autoregressive — each audio frame depends on all previous frames. This is why it carries accent where non-autoregressive models (OpenVoice) could not: accent lives in the phone realisation and phonemic choice, which is inherently sequential.

## Runtime Paths

### Path 1: sherpa-onnx + INT8 ONNX (RECOMMENDED)

**Source**: [k2-fsa/sherpa-onnx](https://github.com/k2-fsa/sherpa-onnx) with [INT8 models](https://huggingface.co/csukuangfj2/sherpa-onnx-pocket-tts-int8-2026-01-26)

**Model files (INT8)**:

| File | Size | Role | Loaded |
|------|------|------|--------|
| `lm_main.int8.onnx` | 76.3 MB | Autoregressive backbone + EOS | Always |
| `lm_flow.int8.onnx` | 9.96 MB | Flow-matching ODE step | Always |
| `decoder.int8.onnx` | 22.7 MB | Mimi latent → audio | Always |
| `text_conditioner.onnx` | ~16 MB | Phoneme → embeddings | Always |
| `encoder.onnx` | 72.7 MB | Voice reference encoder | Enrollment only |
| `vocab.json` | ~1 MB | SentencePiece vocab | Runtime |
| `token_scores.json` | ~1 MB | Token scoring | Runtime |

**Synthesis path (encoder unloaded)**: ~126 MB on disk, ~140-150 MB estimated peak RSS
**Enrollment path (encoder loaded)**: ~199 MB on disk, ~198 MB estimated peak RSS

**Swift API**: Native Swift bindings via `SherpaOnnx.swift`, with Pocket TTS-specific config (`sherpaOnnxOfflineTtsPocketModelConfig`). Voice cloning via `referenceAudio` in `SherpaOnnxGenerationConfigSwift`. Streaming callback for low-latency first audio.

**iOS support**: sherpa-onnx has explicit iOS support (arm64), Swift API examples, and pre-built model archives.

### Path 2: ExecuTorch PTE (ALTERNATIVE)

**Source**: [sivasub987/Pocket-TTS-ExecuTorch](https://huggingface.co/sivasub987/Pocket-TTS-ExecuTorch)

| File | Size |
|------|------|
| `flow_lm_main_bundled.pte` | 96 MB |
| `flow_net.pte` | 37 MB |
| `mimi_encoder.pte` | 69 MB |
| `mimi_decoder.pte` | 39 MB |
| `text_conditioner.pte` | 16 MB |

**Total**: 257 MB (no INT8 quantization available). Larger than sherpa-onnx INT8 path.

### Path 3: Rust/Candle (UnaMentis port)

**Source**: [UnaMentis/pocket-tts-ios](https://github.com/UnaMentis/pocket-tts-ios)

Production-ready Rust port using Candle framework. Float32 (not BF16), ~300 MB RAM when loaded. Has an xcframework distribution and Swift wrapper. However, ~300 MB exceeds our ~250 MB ceiling — this path needs optimization before it can ship.

## Optimizations Applied

### 1. INT8 Quantization (4x compression)

The sherpa-onnx INT8 models use dynamic MatMul INT8 quantization. This reduces the model from ~400 MB (FP32) to ~126 MB (synthesis path) with comparable quality for TTS. This is the single most impactful optimization.

**Impact**: 4x smaller models, 4x less memory bandwidth, minimal quality loss for TTS (unlike ASR where quantization can hurt accuracy).

### 2. Encoder Unload After Enrollment

The mimi encoder (72.7 MB) is only needed once — to process the 30-second reference clip into a voice state (safetensors/KV cache). After enrollment, the voice state is cached to disk and the encoder is:
- Unloaded from memory (~73 MB freed)
- Deleted from disk (~73 MB reclaimed)

**Impact**: Persistent ~73 MB disk + ~73 MB runtime savings. The encoder never loads again as long as the voice state cache exists.

### 3. Voice State Disk Caching

After the encoder processes the reference audio, the resulting voice state (KV cache + conditioning) is saved to `voices/user.safetensors` (~4 MB). On subsequent app launches, the engine loads the cached state directly — no encoder, no reference audio processing.

**Impact**: Near-instant voice readiness after first enrollment. The ~4 MB cache is negligible.

### 4. 2 CPU Threads (Not All Cores)

Pocket TTS is designed for 2 CPU cores. Using more threads would:
- Compete with the app's UI thread and other workloads
- Increase memory pressure from thread-local buffers
- Not improve throughput (the model is autoregressive — inherently sequential per frame)

**Impact**: Predictable CPU usage, no UI jank, matches the model's design intent.

### 5. Streaming Callback for Low Latency

The sherpa-onnx API supports a progress callback that delivers audio chunks as they're generated. This means:
- First audio chunk arrives in ~200ms (TTFA)
- The user hears the beginning of the reply while the rest is still generating
- No need to wait for full synthesis before playback starts

**Impact**: Perceived latency drops from "wait for full synthesis" to ~200ms, matching the v1.9 system-voice experience.

### 6. Reference Audio Normalization (Spike's Key Unlock)

The spike discovered that normalizing the reference clip to full scale (peak = 1.0) before conditioning was the critical step that made accent reproduction work. Without normalization, the model's conditioning was too quiet and the accent was lost.

This is implemented in `PocketTTSModelManager.prepareReferenceAudio()`:
1. Resample to 24 kHz mono float32
2. Find peak amplitude
3. Scale all samples so peak = 1.0
4. Trim to 30 seconds (model's max reference length)

### 7. num_steps=2 for Flow Matching

The flow-matching ODE solver quality/speed tradeoff is controlled by `num_steps`:
- 1 step: Fastest, slightly lower quality
- 2 steps: Balanced (our choice)
- 4 steps: Best quality, 2x slower

For journal-style read-aloud (not real-time conversation), 2 steps is the right balance.

## Memory Budget Analysis

### iPhone Jetsam Ceiling

iOS kills apps that exceed their memory footprint limit. For foreground apps on typical iPhones:
- iPhone 15 Pro (6 GB RAM): ~2.5 GB total, ~250-300 MB per-app ceiling
- iPhone 14 (6 GB RAM): ~250 MB per-app ceiling
- iPhone 13 (4 GB RAM): ~200 MB per-app ceiling

The ~250 MB ceiling is the binding constraint. Chatterbox-turbo died at 953.7 MB — 3.8x over budget.

### Estimated Peak RSS (INT8, Encoder Unloaded)

| Component | Estimated RSS |
|-----------|--------------|
| lm_main.int8.onnx | ~76 MB |
| lm_flow.int8.onnx | ~10 MB |
| decoder.int8.onnx | ~23 MB |
| text_conditioner.onnx | ~16 MB |
| KV cache (6 layers × 512 × 16 × 64 × 2) | ~18 MB |
| Voice state | ~4 MB |
| ONNX Runtime overhead | ~10 MB |
| Audio output buffer | ~2 MB |
| **Total estimated peak** | **~159 MB** |

**Headroom against 250 MB ceiling: ~91 MB (36%)**

This is a projection. The entire point of the MemoryProbe harness is to turn this into a measurement. The estimate is conservative (ONNX Runtime may use less with INT8), but the only number that counts is the one from `MemoryProbe.measure(label: "PocketTTS synthesis")` on a real iPhone.

### Enrollment Peak RSS (Encoder Loaded)

| Component | Estimated RSS |
|-----------|--------------|
| All synthesis components | ~159 MB |
| encoder.onnx | ~73 MB |
| Reference audio buffer (30s × 24kHz × 4B) | ~2.9 MB |
| **Total estimated enrollment peak** | **~235 MB** |

**Headroom against 250 MB ceiling: ~15 MB (6%)**

Enrollment is the tightest moment. If this measures over 250 MB, the fallback is to unload the synthesis models during enrollment (load encoder only, enroll, unload encoder, load synthesis models). This would trade a longer enrollment flow for a lower peak.

## What Must Happen Before Shipping

### Gate 1: Measured Memory Footprint

```swift
// In MemoryProbeView, after calibration is verified:
let result = pocketTTS.measureSynthesisMemory(text: "A representative Twin reply of moderate length.")
print(result.headline)
// Must show peak < 250 MB with .exact confidence on a real iPhone
```

### Gate 2: Licensed Weights

The spike used an unlicensed mirror of a January checkpoint. The sherpa-onnx INT8 models from k2-fsa are derived from the official Kyutai release. Verify the license chain:
- Kyutai Pocket TTS: check [HuggingFace model card](https://huggingface.co/kyutai/pocket-tts) for license terms
- sherpa-onnx INT8 export: derived from the above, Apache 2.0 export code
- Commercial use: must be confirmed before shipping

### Gate 3: Real Audio Format Validation

The spike ran on 22 kHz mp3. Production must validate on real 44.1 kHz journal `.m4a`:
1. `prepareReferenceAudio()` resamples to 24 kHz — verify quality after resample
2. Confirm accent reproduction holds on real journal audio (not studio-quality test wav)
3. Test with varying recording conditions (quiet room, outdoor, different microphones)

## File Layout

```
solyn/solyn/
├── SherpaOnnxPocketTTS-Bridging-Header.h   ← C API declarations
├── SherpaOnnxPocketTTS.swift               ← Swift wrapper for sherpa-onnx Pocket TTS
├── PocketTTSModelManager.swift             ← Model file management, enrollment, encoder unload
├── PocketTTSVoiceService.swift             ← TTS service: load, enroll, synthesize, play
├── TwinVoiceService.swift                  ← Updated: routes to PocketTTS when enrolled, else system voice
├── MemoryProbe.swift                       ← Existing: measures peak RSS (gates the ship decision)
└── MemoryProbeView.swift                   ← Existing: DEBUG UI for running measurements
```

## Build Requirements

1. **sherpa-onnx iOS build**: Build `libsherpa-onnx.a` and `libonnxruntime.a` for arm64 iOS simulator + device
   ```sh
   git clone https://github.com/k2-fsa/sherpa-onnx
   cd sherpa-onnx
   mkdir build-ios && cd build-ios
   cmake .. -DCMAKE_SYSTEM_NAME=iOS -DCMAKE_OSX_ARCHITECTURES=arm64 \
     -DSHERPA_ONNX_ENABLE_TTS=ON -DBUILD_SHARED_LIBS=OFF
   make -j4
   ```

2. **Xcode project setup**:
   - Add `SherpaOnnxPocketTTS-Bridging-Header.h` as the bridging header
   - Link `libsherpa-onnx.a` and `libonnxruntime.a`
   - Add the four Swift files to the solyn target

3. **Model download**: Models are fetched on first use, not bundled (too large for App Store download). The `PocketTTSModelManager` manages storage in Application Support.

## Alternative: PocketTTS.cpp (ONNX Runtime, C++)

[VolgaGerm/PocketTTS.cpp](https://github.com/VolgaGerm/PocketTTS.cpp) is a single-file C++ runtime using ONNX Runtime, with INT8 by default, streaming, and a C FFI API. It includes an `export_onnx.py` script that exports, quantizes, and validates all ONNX models from upstream weights. This could replace sherpa-onnx if a lighter-weight dependency is preferred — the C API is simple enough to bridge directly. However, sherpa-onnx already has iOS builds and Swift examples, making it the lower-risk path.

## Status — CLOSED 2026-08-10

- ✅ Spike succeeded (2026-07-28): voice cloned from 30s journal audio, approved by ear
- ✅ MemoryProbe harness built and tested: calibration verified on simulator (app PR #70)
- ✅ INT8 weights obtained and validated end-to-end via the sherpa-onnx **Python** bindings — no iOS
  build needed to answer the quality question. RTF 0.13-0.18 on 2 CPU threads, model load 0.4s,
  198 MB on disk (125 MB once the encoder is dropped post-enrollment)
- ✅ Gate 2 partially answered: the k2-fsa INT8 repo is **ungated and ships a LICENSE file**, unlike
  the spike's mirror. Commercial-use chain was never fully walked, because the path closed first
- ❌ **Gate 0 (new, and the one that mattered): FAILED.** Forced-choice real-vs-synthetic blind test,
  8/8 to Karthik, p = 0.0039. Should have been run first, before any of the above
- ❌ **Gate 1 FAILED on the desktop proxy:** 685 MB peak, 377 MB after model load, vs a ~250 MB
  ceiling. Never run on iPhone — the ear result closed the path before the device measurement
- ⬜ ~~Build sherpa-onnx for iOS arm64~~ — not started, and now unnecessary
- ⬜ ~~Settings UI for voice enrollment~~ — not started
- 🗑 The Swift integration written for this (bridging header, `SherpaOnnxPocketTTS.swift`,
  `PocketTTSVoiceService.swift`, `PocketTTSModelManager.swift`) never compiled — it referenced C
  symbols with no library behind them — and was removed from the tree on closure

### If this is ever reopened

sherpa-onnx remains the best *runtime* found; the blocker is the *model*. The plumbing is proven in
Python, so a new candidate with a sherpa-onnx export can be ear-tested in about an hour without
touching Xcode. Reuse the blind-test harness (`blind_test.py` / `blind_test6.py`): slice held-out
segments from a source recording, transcribe each with whisper, synthesize the same words, match RMS
and sample rate, randomise slots, emit an answer key. Run that *before* anything else.
