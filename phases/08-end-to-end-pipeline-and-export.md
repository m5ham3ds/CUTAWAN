# Phase 8 — End-to-end processing pipeline and real video export

## Objective

Convert the current domain foundations into a usable pipeline that produces individually playable, verified video clips.

## Work packages

1. Persisted job state machine: queued, inspecting, extracting, transcribing, discovering, annotating, reframing, captioning, rendering, validating, complete, failed, cancelled.
2. Per-stage checkpoints and artifact fingerprints (source SHA, model/version, configuration, prompt version, edit revision).
3. Cancellation, resume after process death, retry only the failed stage and progress notifications.
4. Native Android rendering decision: evaluate a supported FFmpegKit alternative or an owned FFmpeg build with legally compatible codecs and ARM64 binaries; record licenses and build reproducibility.
5. Use candidate time ranges and crop plans to render clips without altering the source project; maintain timestamp mapping.
6. Generate ASS/SRT caption artifacts from transcript word times, with RTL punctuation and mixed-script support.
7. Share one caption layout/style model between preview and rendered output; compare with golden images.
8. Validate every output via a second metadata probe and complete decode, duration and dimensions.
9. Provide per-clip re-render, output location, failure detail and cleanup.
10. Export bundle/sidecar metadata after video validation.

## Required gates

- Fixture videos (short/long, portrait/landscape, audio-only, no speech, corrupt source).
- Boundary and source-time correctness, audio presence, frame dimensions, and full decode.
- Interrupt/cancel/relaunch/resume at every stage.
- Disk preflight, bounded concurrency, temporary artifact cleanup.
- Arabic/English/RTL subtitle golden set.
- Physical ARM64 execution, memory/thermal/load and background-notification tests.

## Restrictions

No UI may state an export succeeded until a real output file exists and passes validation. The current phase 3–6 candidate and reframe artifacts are not final video files.
