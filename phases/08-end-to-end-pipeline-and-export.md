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

## Implementation update — 2026-11-20

**Status: implementation in progress; not phase-accepted.**

The Flutter Android workspace now has a first end-to-end orchestration path:

- Persisted job state updates and per-stage SHA-256 checkpoints with artifact-existence and path/symlink containment checks.
- A source fingerprint operation executed in Android over the selected, persistently readable URI.
- A pipeline service connecting source inspection, existing Whisper transcription, candidate discovery, framing-plan analysis, caption sidecar generation, clip rendering, manifest creation and final job state.
- A Media3 Transformer Android renderer pinned to 1.11.1, producing H.264/AAC MP4 clips, trimming candidate time ranges and applying aspect-fit presentation.
- A second verification operation reopening the published CUTAWAN output and comparing SHA-256, byte size, duration, dimensions and video-track presence before a checkpoint can be reused.
- Output metadata records and per-project manifest. Interrupted running jobs are recovered as failed/resumable instead of remaining stuck.
- Cancellation and progress plumbing, storage preflight, and cleanup of temporary render output after publishing.
- Automated tests for repository checkpoints and job recovery, caption sidecars, export polling/cancellation/result validation and resume-verification channel behavior.

### Explicit remaining work and acceptance blockers

- The current Media3 export applies trim and aspect fit only. The persisted face/reframe plan is validated but its changing crop/focus keyframes are not yet applied to rendered frames.
- SRT/ASS sidecars are generated from transcript word timings, including Arabic text, but they are not burned into the MP4 and do not yet share a tested pixel-identical renderer with Caption Studio preview.
- Native output verification probes stream metadata and the video track; it does not yet perform a full end-to-end decode of every output or enforce all fixture cases.
- Per-clip manual re-render/retry, background execution and notifications that survive Activity/process death, and robust native render-session recovery remain required.
- No physical ARM64 device, thermal, memory, lifecycle, SAF provider, interrupted-render or Arabic/English golden-media test has been performed in this update.

Do not mark this phase complete until the remaining items and the original required gates above pass.
