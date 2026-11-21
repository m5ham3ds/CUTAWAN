# Android Phase 3–4 implementation record

**Target:** `m5ham3ds/CUTAWAN`, default branch `main`  
**Scope:** Flutter Android companion only. The existing Electron desktop app and its root domain pipeline are left intact.

## Repository and source-selection decision

The implementation was based on the checked-in roadmap and current `main` source, not a copy of another app. The selected upstream components are limited to their platform-specific responsibilities:

| Selected source | Files / component reused | Purpose | Excluded |
|---|---|---|---|
| `47gurvinder/whisper_cpp_flutter` (`whisper_cpp_flutter_plus`) | Flutter plugin API, checksum-pinned model catalog/manager, CPU Whisper engine | Offline Android speech-to-text and word-level timestamps | Its example application and UI |
| `ggml-org/whisper.cpp` | Android native speech runtime used by the Flutter plugin | Local speech inference | Desktop CLI and server |
| `dragneel2074/Llama-Flutter` (`llama_flutter_android`) | Android plugin API and JNI/llama.cpp integration | Local GGUF text annotation | Example app and unrelated chat UI |
| `ggml-org/llama.cpp` | Android native inference engine bundled by the plugin | On-device local GGUF inference | Desktop/server targets |
| `JeremySNR/cutawan` (this repository) | Existing project preferences, timestamp and editorial domain requirements | Native Dart contracts and behavior parity target | Electron, Node, Python and React runtime code |
| `Anil-matcha/AI-Youtube-Shorts-Generator`, `kiy0ni/auto-video-editor` | Reviewed conceptually only | Sentence/moment boundaries and evidence-oriented workflow reference | Python scripts, Tkinter/CLI and Python runtime |

No web UI, desktop process, PRoot environment, remote inference API, or additional arbitrary model runtime was introduced.

## Phase 3 — local transcription and model management

Implemented in the Flutter Android target:

- Android `MediaExtractor` + `MediaCodec` decode the first audio track from a SAF-persisted `content://` URI or a validated app-private `file://` path. They create an app-cache WAV file and clean partial output on failure.
- `WhisperPcmReader` parses native WAV files and reads bounded source ranges, downmixes PCM/float channel layouts to mono, and resamples actual samples to 16 kHz with a windowed-sinc low-pass filter. It does not load the entire long-form source into memory.
- `WhisperTranscriptionService` uses the reader for one-second RMS windows and 30-second Whisper input chunks, then maps timestamps back onto the source-video timeline.
- `WhisperChunkPlanner` assigns two-second context overlaps to contiguous, non-overlapping ownership windows. Each segment midpoint is committed to one chunk.
- Model Center exposes explicit user-triggered download, integrity checking, installed status, and removal. Model files are not embedded in the APK.
- The selected Whisper model descriptor is `base` (multilingual), pinned by the upstream package's immutable URL and SHA-256 catalog entry.

**Known limitations:** chunk ownership and timestamp mapping are deterministic, but Arabic/English speech accuracy is not certified. VAD-backed silence rejection remains unimplemented. Long-source latency, physical-device memory/thermal behavior, and real provider URI behavior remain required acceptance checks.

## Phase 4 — candidate discovery and evidence ranking

Implemented in Dart:

- Versioned transcript, word, audio-evidence, visual-sample, clip-candidate, and candidate-set contracts, with timestamp/source-boundary and score validation.
- Candidate boundaries are derived from sentence punctuation and pauses using Whisper token times. Proposals outside the selected duration band or source duration are rejected.
- Deterministic evidence ranking combines speech density with available audio RMS and sampled frame-change evidence. Missing evidence is omitted and remaining weights are normalized.
- Candidate selection applies overlap/text-similarity deduplication and a source-coverage bonus. It returns fewer results rather than inventing clips to meet the requested count.
- The Android source bridge samples low-resolution luma differences at bounded intervals. This is scene-change evidence only; it is not semantic scene understanding, face detection, or speaker diarization.
- The optional local Qwen model annotates title, hook, summary and explanation text only. Its output cannot change clip IDs, time boundaries, evidence, or scores. Strict JSON parsing ignores unknown/duplicate IDs and safely keeps deterministic results if the model output is invalid.
- Transcript and candidate artifacts are saved under a per-project artifact directory separately from the root project index; deleting a project also deletes its artifacts.

## Pinned local Qwen model

| Field | Value |
|---|---|
| Model | Qwen2.5-0.5B-Instruct Q4_K_M GGUF |
| Repository | `Qwen/Qwen2.5-0.5B-Instruct-GGUF` |
| Revision | `6dd44a1fb35d11b5d1b28902876ce3cc9e882d0e` |
| File | `qwen2.5-0.5b-instruct-q4_k_m.gguf` |
| Size | 491,400,032 bytes |
| SHA-256 | `74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db` |
| License | Apache-2.0 |

The model URL is revision-pinned. Download uses HTTPS only, checks redirects, exact length and SHA-256, writes a temporary file, and installs only after verification. The app requires free storage for the model plus a reserve before the user starts a download.

## Automated gates added

- Transcript contract serialization, timestamp, empty-timing and schema-version tests.
- `WhisperPcmReader` tests for 16 kHz mono passthrough, 44.1 kHz stereo downmix/resampling, 48 kHz stereo range reads, signed 24-bit PCM, silence, malformed/truncated WAV and out-of-range reads.
- Chunk planner tests for contiguous midpoint ownership and range-invariant streamed reads across chunk boundaries.
- Candidate duration/source bounds, no-fabricated-results, unreliable-timing rejection and serialization tests.
- Project artifact persistence, source-duration mismatch and recursive deletion tests.
- Qwen manifest and invalid-installed-file tests; multilingual Whisper catalog verification.
- LLM annotation allow-list tests proving that IDs, boundaries, scores and evidence remain unchanged.
- Existing Phase 1/2 contract, repository, download, import-flow and widget tests remain in place.
- Android CI continues to format, analyze, run Flutter tests, build an ARM64 debug APK and assert the APK contains only `arm64-v8a` native libraries. The native engines increase build cost; the mobile CI timeout is extended and native build parallelism is bounded.

## Acceptance still required

A green Actions run proves compilation, Dart unit/widget tests and the APK ABI packaging gate; it does **not** prove inference accuracy or real-device media behavior. Before marking Phases 3–4 fully accepted, run the documented Arabic single-speaker, Arabic multi-speaker and English reference clips on physical ARM64 Android devices and record:

1. Word error rate and word-time alignment against human references.
2. Long-source processing behavior, interruption/recovery and peak memory.
3. SAF access and extraction for local provider/cloud-provider content URIs.
4. Candidate boundary correctness, deduplication, source coverage and human editorial acceptance.
5. Qwen annotation quality, latency, memory and thermal behavior.

No physical-device corpus or reference transcript was available to this repository session; these checks must remain visibly open until evidence is recorded. Video reframing, speaker/face analysis, caption rendering and final clip export remain later roadmap phases.
