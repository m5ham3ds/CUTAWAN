> **Historical execution-gate snapshot — 2026-11-21.** The test counts, source SHAs, "latest run" instructions and phase sequencing below belong to that date and are not the current acceptance status. Use [`phases/README.md`](../../phases/README.md) and [Phase 1](../../phases/01-android-foundation-and-arm64.md), [Phase 2](../../phases/02-media-ingestion-and-project-lifecycle.md) and [Phase 3](../../phases/03-local-whisper-transcription.md) for the synchronized project state.

---

# Phase 1–3 execution plan and acceptance gate — 2026-11-21

**Repository:** `m5ham3ds/CUTAWAN`  
**Implementation target:** native Flutter Android under `mobile/flutter_app/`.  
**Branch:** `main` only. The Electron desktop application remains untouched.

## Agreed order

1. Phases 1, 2 and 3 together.
2. Next, Phases 4 and 5 together.
3. Next, Phases 6 and 7 together.
4. Then Phase 8.
5. Then Phase 9 once (the user's repeated “9” is one phase).
6. Finally Phase 10.

Existing code is retained and improved; the work must not restart previously implemented foundations. No later group is accepted by virtue of already having placeholder or partial files.

## Phase 1 — native Flutter shell

Existing implementation includes Flutter/Material 3, primary app destinations, Arabic interface, app theme, and an Android ARM64 workflow.

Acceptance:
- Run formatting, static analysis, all Flutter tests, Android generation and ARM64 APK build against the current `main` source.
- Verify package identity, minimum SDK, backup policy and ARM64-only native libraries.
- Verify 320dp layout, navigation, orientation and app startup. CI does not replace a physical install check.

## Phase 2 — ingestion and project lifecycle

Existing implementation includes Android SAF video picker, persisted read grants, native metadata probing, versioned project JSON/migration, local project/job/artifact persistence, direct HTTP(S) video-file downloads, redirect validation, low-storage checks, cancellation and partial-file cleanup.

Acceptance:
- Test valid/invalid/cancelled SAF selection, local metadata probing and saved grant reuse after app restart.
- Test direct-file URL success, redirects, denied/private/platform URLs, low storage, user cancellation, network failure and interrupted partial cleanup.
- Test repeated references to one SAF URI before permission release.
- Test corrupted project JSON, deleted/moved sources and artifact cleanup.
- Physical Android provider/force-stop/process-death evidence is required separately.

## Phase 3 — local Whisper transcription

Existing implementation includes Kotlin MediaExtractor/MediaCodec WAV extraction, a pinned multilingual Whisper model, integrity-checked model download/management, and Dart word-timed transcript artifacts.

### Correction now implemented; acceptance still pending

The original mismatch was real: Android emits WAV at the decoded source sample rate and channel count, while the earlier Whisper service assumed 16kHz mono. `WhisperPcmReader` now reads bounded source ranges, downmixes channels, and resamples actual samples to 16kHz mono with a windowed-sinc low-pass filter. RMS and Whisper chunks use that same normalized sample timeline. `WhisperChunkPlanner` assigns overlapped segment midpoints to contiguous, non-overlapping ownership windows.

Automated fixtures now cover 16kHz mono, 44.1kHz stereo, 48kHz stereo, signed 24-bit PCM, silence, malformed/truncated WAV, range bounds, streamed-read boundary equivalence and chunk-ownership continuity. The latest Mobile Android workflow must still pass on the current source. Before acceptance:
- Verify resource cleanup on success and exceptions and clear no-audio/invalid-WAV errors.
- Measure normalization and transcription on long files, including peak memory and progress monotonicity.
- Score Arabic and English reference clips for WER and word-time alignment; unit tests do not certify ASR accuracy.

Physical Arabic and English clips must still be scored against reference transcripts for WER and word timing. Those device/accuracy checks cannot be claimed from unit tests or compilation.

## Current automation snapshot

The root CI run on `1e864887efbc2b58fdbbd1e7c94c1ac664122a88` passed, but it is the desktop workflow and does not validate Flutter. A prior Mobile Android run [44842722337](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44842722337) passed all 95 then-existing tests and built the ARM64 APK on SHA `377fe3a`; it predates the streaming PCM reader and does not validate the latest implementation. Inspect the Mobile Android run for the current source SHA before passing this gate.

## Gate

Do not begin Phases 4–5 until Phase 1–3 implementation corrections and the Mobile Android workflow pass. Record physical-device tests as completed or explicitly blocked; never infer them from CI. No green Android build by itself certifies Whisper accuracy.
