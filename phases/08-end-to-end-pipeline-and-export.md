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
