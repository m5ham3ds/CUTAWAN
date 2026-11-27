# Phase 3 — Local Whisper transcription and model management

**Current state:** local multilingual Whisper integration, bounded PCM normalization and overlap-aware chunk planning are implemented and automated tests pass. Arabic/English accuracy and physical-device performance are not certified.

## Implemented scope

- Native Android `MediaExtractor`/`MediaCodec` decode the selected audio track to a temporary WAV.
- `WhisperPcmReader` reads bounded WAV ranges rather than loading an entire long source into memory. It supports the implemented PCM/float formats, downmixes to mono and resamples to 16 kHz using a windowed-sinc low-pass filter.
- `WhisperChunkPlanner` creates 30-second Whisper windows with two seconds of context overlap. Segment midpoints are assigned to contiguous, non-overlapping ownership windows to avoid duplicate boundary words.
- RMS/audio evidence and Whisper input use the same normalized mono 16 kHz timeline.
- The multilingual Whisper Base model is user-installed, downloaded on request and checksum-verified. Model weights are not bundled into the APK.
- Word-level transcript contracts and timestamp mapping are persisted as project-scoped analysis artifacts.

## Source map

- `lib/services/android_audio_extractor.dart`
- `lib/services/whisper_pcm_reader.dart`
- `lib/services/wav_audio_normalizer.dart`
- `lib/services/whisper_chunk_planner.dart`
- `lib/services/whisper_chunk_overlap_policy.dart`
- `lib/services/whisper_transcription_service.dart`
- `lib/domain/transcript_contract.dart`
- `lib/services/qwen_model_manager.dart` — model download/integrity management is also used by Phase 4.

## Automated coverage

- `whisper_pcm_reader_test.dart`, `wav_audio_normalizer_test.dart`, `whisper_chunk_planner_test.dart`, `whisper_chunk_overlap_policy_test.dart` and `transcript_contract_test.dart`.
- Fixtures cover 16 kHz mono, 44.1/48 kHz stereo, signed 24-bit PCM, silence, malformed/truncated WAV, bounded reads and consistent overlap ownership.

## Limits and required field tests

- VAD-backed silence rejection is not implemented as a completed acceptance feature.
- Passing PCM/chunk tests proves deterministic signal preparation and segmentation contracts, not transcription quality.
- Run a hash-locked Arabic single-speaker sample, Arabic overlapping/multi-speaker discussion and English interview/podcast on physical ARM64 hardware. Use manually reviewed transcripts to calculate WER insertion/deletion/substitution counts, word coverage and median/P95 word-start/end timing error.
- Record long-source time, peak PSS/RAM, temp storage, battery and thermal behavior. Do not substitute synthetic transcript fixtures for human reference transcripts.

**Related:** [Phase register](README.md), [Phase 3–4 integration record](../docs/mobile/PHASES_3_4_INTEGRATION.md), [Phase 10 evidence protocol](10-physical-device-acceptance.md).
