# Phase 8–9 implementation record — 2026-11-20

Repository: m5ham3ds/CUTAWAN
Target branch: main
Status: implementation in progress; CI and Android build are being validated. Neither phase is marked accepted.

## Phase 8 — processing and export

### Delivered in this change set
- Durable project-job state updates, stage progress and cancellation.
- Source and configuration fingerprint checkpoints with safe artifact path checks.
- Android source fingerprint via SHA-256.
- Orchestration of existing transcription, candidate discovery and framing-plan services.
- SRT/ASS caption sidecar generation based on transcript word timestamps.
- AndroidX Media3 Transformer MP4 output (H.264/AAC), clip time-range trimming and aspect-fit.
- Native output validation: SHA-256, file size, duration, width, height and video-track presence.
- Per-clip export metadata, project manifest and validation before checkpoint reuse.
- Interrupted job recovery and storage preflight.
- Automated tests for repository state/checkpoints, job recovery, caption sidecars and export channel behavior.

### Not yet delivered / not accepted
- Dynamic face/reframe keyframes applied during rendering.
- Burning subtitle sidecars into final MP4; matching caption preview/render pixel output.
- Full decoder pass and full fixture corpus (orientation, corrupt, no speech, audio-only, portrait/landscape, long media).
- Persistent background rendering/notification and process-death resume of native renderer session.
- Per-clip retry/re-render, robust cleanup and full output playback test.
- Physical ARM64 memory/thermal/lifecycle/SAF URI testing.

## Phase 9 — mobile interface

### Delivered in this change set
- Split HomeShell presentation into Create, Jobs, Review, Caption Studio, Models and shared-widget part files.
- Material 3 semantic light/dark themes and system theme selection.
- Job stage/progress visibility, Jobs-to-Review navigation and one full-pipeline/resume action.
- Export result list and disabled manual actions during full-pipeline execution.
- Startup recovery for interrupted jobs.
- Theme and narrow-width widget tests added.

### Not yet delivered / not accepted
- Fully independent feature packages/state ownership; current feature files remain Dart parts of one library.
- Full Dashboard/Create/Jobs/Review/Clip Editor/Caption Studio/AI Center/Settings redesign.
- Real clip editor with preview, trim handles, crop/focus and transitions.
- Comprehensive golden, RTL and bilingual, large text, keyboard, landscape, safe-area, accessibility, navigation and state-retention test matrix.
- Physical-device visual validation.

## CI evidence
The Android generator shell syntax check passed on the latest submitted run. The latest Android Flutter job and root CI jobs are still running at the time this record was written. No new APK is marked as built or uploaded until the workflow reports successful build and ABI verification.
