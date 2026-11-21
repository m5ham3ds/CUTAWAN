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

## Implementation update — 2026-11-21

**Status: substantial native render path implemented; phase not yet accepted.** The earlier description that Media3 applied trim/aspect-fit only is superseded by the current Android source.

### Implemented path

- Persisted job state, per-stage SHA-256 fingerprints/checkpoints, artifact path/symlink containment, source fingerprinting, progress, cancellation, disk preflight, and project export records/manifest remain in the Flutter pipeline.
- `ProcessingPipelineService` builds a per-clip reframe timeline by intersecting the saved `ReframePlan` with each candidate range and converting it to clip-relative milliseconds.
- The same service builds caption style payloads and per-clip timed word cues, and includes both reframe segments and caption cues in the render-stage fingerprint.
- `VideoExportService.renderClip` sends `reframeShots`, timed `captionCues`, caption style and animation ID to Android, polls progress, handles cancellation/timeout and requires validated output metadata.
- Android `MainActivity.startRender` parses and validates the clip-relative reframe and caption data, sets Media3 clipping positions, constructs a `MatrixTransformation`, adds the aspect-ratio `Presentation`, and attaches a `TimedCaptionOverlay` through `OverlayEffect` when timed cues are provided.
- `createReframeTransformation` selects the segment using Media3 presentation time and applies either a safe `fit` transform or the segment's normalized crop region. The current path therefore consumes time-varying reframe segments; it is not limited to a static aspect-fit.
- `TimedCaptionOverlay` chooses the active cue from presentation time and draws text with Android `CanvasOverlay`/RTL-first `StaticLayout`, style colors, outline, shadow, highlight box and timed karaoke word emphasis. This path burns caption text into the rendered MP4; SRT/ASS sidecars are also retained for interchange.
- Native result validation checks the output exists, size, duration, dimensions and video metadata, then computes/publishes the output SHA-256 and records the result.

### Remaining acceptance blockers

- No representative physical-device fixture run has yet proved crop framing continuity, subject placement, subtitle baseline, RTL punctuation/mixed-script rendering or source-time synchronization in the actual MP4.
- Android `TimedCaptionOverlay` currently implements timed `karaoke_fill` word emphasis. The full range of Flutter Studio preview animation IDs is not yet pixel/behavior parity in the native renderer.
- Caption Studio's Flutter preview and Android CanvasOverlay use separate layout/font implementations; a golden/pixel-identical visual comparison is not in place.
- Output validation probes the file/metadata and video track; it does **not** yet fully decode every output frame and audio packet to end-of-stream.
- Render sessions are held in an Activity-owned in-memory map. Cancellation and progress work while the process remains alive, but robust process-death recovery, foreground/background execution, durable render-session reconstruction and notifications remain open.
- Per-clip retry/manual re-render, output management UI and cleanup/retention acceptance remain open.
- Fixture coverage still needs short/long, portrait/landscape, VFR, audio-only/no-speech, silence, corrupt/truncated source, scene cuts, missing-face intervals and Arabic/English/RTL cases.
- Physical ARM64 testing for memory/thermal/load, audio presence, frame decode, output duration/dimensions and Android OEM/background restrictions has not been completed.

### Automated evidence available on 2026-11-21

- Android run [44857222277](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44857222277) on SHA `80e182ba840f3dc0b6e9039d39877179cb142a3e` passed: Format, Analyze, 129 Flutter tests, ARM64 APK build, ABI/native-library assertion and APK upload.
- This is compile/unit/packaging evidence. It is not a physical-device render, full-decode or process-death acceptance result.

Do not mark Phase 8 accepted until the remaining full-decode, output-fixture, background/process-death and physical-device gates pass.


## Phase 8 implementation update — full decode and deterministic recovery

**Code delivered on main; physical/background acceptance is still open.**

- The native Android output gate now enumerates every audio/video track and decodes each selected track with MediaCodec through its end-of-stream flag before publishing an MP4.
- Validation counts decoded output buffers/bytes without retaining frame data, rejects a track that produces no decoded output, and enforces a 30-minute safety deadline for each track decode.
- Both the immediate render path and persisted-export revalidation use the same full-decode routine. A SHA-256/metadata match alone can no longer mark an output as verified.
- Flutter's `VideoExportResult` rejects payloads without `fullyDecodeValidated=true`, a positive decoded video-buffer count, and decoded audio output where an audio track exists. The pipeline stores the full-decode evidence in each export record and labels the manifest validation contract.
- A recovered interrupted job now retains the exact prior stage in `interrupted_after_process_death:<stage>`, rather than losing the recovery location. The existing pipeline rechecks its SHA/configuration checkpoints and fully revalidates previously exported MP4s before skipping them; only missing or invalid clip outputs are rendered again.
- Added Flutter tests that reject metadata-only render results and assert that interrupted-stage context survives recovery.

### Still open before Phase 8 acceptance

- MediaCodec full-decode must be exercised on real ARM64 fixtures and devices, including VFR, long files, no-audio, silent audio, rotated footage and deliberately truncated/corrupt output.
- Full process-death/background execution and notification behavior are not yet implemented as a durable foreground WorkManager service; the current Activity-owned Transformer session is cancelled when the Activity is destroyed. Reopening Review and invoking its resume action restarts from validated checkpoints, but does not continue the same live native Transformer process in the background.
- Per-clip retry/export management UI, render cancellation from Android system notifications, and physical subtitle/crop continuity checks remain open.
- Caption overlay styling still does not match every Flutter preview animation/pixel layout.


## Full media decode implementation status — 2026-11-21

- Android output validation now decodes every selected video and audio track through MediaCodec to its end-of-stream marker before publishing an export.
- Resume verification performs the same full decode; metadata and SHA equality alone no longer accept an export.
- Flutter validates the native full-decode evidence and the pipeline persists decoded buffer counts in export records/manifests.
- Automated gate passed on Mobile Android workflow 44865751038 (Phase 8 full-decode patch), and the subsequent Stage 9/10 ARM64 build workflows also passed.
- Physical codec/format acceptance is still open: VFR, long duration, rotated input, silent/no-audio, AAC/other audio tracks and corrupt/truncated MP4 fixtures must be tested on actual ARM64 devices.
- Background WorkManager execution, notification cancellation and process-death reconstruction of a live render are still not implemented; a destroyed Activity still cancels the in-memory Media3 session. Resume relies on persisted checkpoints and revalidation when the app is reopened.
