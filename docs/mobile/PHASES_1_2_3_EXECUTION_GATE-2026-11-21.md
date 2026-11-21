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

### Confirmed correctness issue

The Kotlin decoder currently emits WAV at the decoded source sample rate and channel count. The Dart transcription path assumes 16kHz sample data for chunk size, timestamps and one-second RMS windows. Consequently, a common 44.1/48kHz or multichannel source can be interpreted at the wrong rate, producing incorrect transcription timing and input audio.

Before acceptance:
- Convert actual PCM samples to mono 16kHz before Whisper input; do not only change WAV header metadata.
- Generate RMS windows from the normalized samples on the same 16kHz timeline.
- Preserve mapping from normalized sample positions to source-video milliseconds.
- Correct overlap deduplication so an overlap is assigned once without losing valid words at the chunk boundary.
- Add deterministic generated audio fixtures for 16kHz mono, 44.1kHz stereo, 48kHz stereo, silence and malformed/truncated WAV.
- Verify resource cleanup on success and exceptions, and make no-audio/invalid WAV errors clear.
- Add long-file memory/progress tests where practical.

Physical Arabic and English clips must still be scored against reference transcripts for WER and word timing. Those device/accuracy checks cannot be claimed from unit tests or compilation.

## Current automation snapshot

The root CI run on `1e864887efbc2b58fdbbd1e7c94c1ac664122a88` passed, but it is the desktop workflow and does not validate Flutter. The mobile workflow must be triggered and inspected separately for the current Flutter source.

## Gate

Do not begin Phases 4–5 until Phase 1–3 implementation corrections and the Mobile Android workflow pass. Record physical-device tests as completed or explicitly blocked; never infer them from CI. No green Android build by itself certifies Whisper accuracy.
