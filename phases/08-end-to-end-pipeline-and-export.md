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
- Historical snapshot dated 2026-11-21: render sessions were then held in an Activity-owned in-memory map. This blocker was superseded by the WorkManager foreground-render/durable-completion implementation recorded below on 2026-11-22; it is not the current architecture.
- At this 2026-11-21 snapshot, per-clip retry/manual re-render and output management were still open. The targeted re-render/cleanup implementation is recorded in the 2026-11-26 addendum below.
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
- Historical snapshot dated 2026-11-21: foreground/background WorkManager execution and process-death handoff had not yet been implemented at that point. This was superseded by the 2026-11-22 WorkManager implementation below. Real-device process-death/force-stop and OEM acceptance remain open.
- In this 2026-11-21 snapshot, per-clip retry/export management UI was still open. Targeted re-render/cleanup was implemented on 2026-11-26; physical export delivery, notification/cancellation, subtitle/crop continuity and device acceptance remain open.
- Caption overlay styling still does not match every Flutter preview animation/pixel layout.


## Full media decode implementation status — 2026-11-21

- Android output validation now decodes every selected video and audio track through MediaCodec to its end-of-stream marker before publishing an export.
- Resume verification performs the same full decode; metadata and SHA equality alone no longer accept an export.
- Flutter validates the native full-decode evidence and the pipeline persists decoded buffer counts in export records/manifests.
- Automated gate passed on Mobile Android workflow 44865751038 (Phase 8 full-decode patch), and the subsequent Stage 9/10 ARM64 build workflows also passed.
- Physical codec/format acceptance is still open: VFR, long duration, rotated input, silent/no-audio, AAC/other audio tracks and corrupt/truncated MP4 fixtures must be tested on actual ARM64 devices.
- Historical status dated 2026-11-21: WorkManager notification cancellation and durable completion handoff were not implemented in that snapshot. The following 2026-11-22 section supersedes this; the current code uses NativeRenderWorker, foreground progress/cancellation and durable completion records. Physical-device behavior remains unverified.


## WorkManager foreground rendering and durable completion — 2026-11-22

**Automated implementation delivered on main; physical-device acceptance remains open.**

- Extracted the native Media3 transform from the Activity-owned session into `NativeRenderEngine`; `NativeRenderWorker` executes project render requests through WorkManager's long-running foreground execution path.
- Work requests are serialized through unique work; requests carry validated project/clip identity and are tagged by project so a Jobs cancellation can stop queued and active work for that project.
- The worker publishes foreground progress notifications with a system cancellation action, and stores durable completion JSON tied to render identity/project so Flutter can recover a render completed while its process was absent.
- `MainActivity` now enqueues/queries/cancels WorkManager jobs and exposes project-active, completed-render and acknowledge-completion method-channel operations. It no longer depends on an Activity-owned render-session map for background work.
- Flutter's export service reads completed WorkManager output; the pipeline verifies it, saves the export record and checkpoint, and only then acknowledges/deletes the durable completion. This preserves the completion if the app process exits between render completion and Flutter persistence.
- Job recovery checks native WorkManager state before classifying a project as interrupted. The Jobs cancellation action persists cancellation and calls the native project-tag cancellation bridge.
- Android platform generation adds WorkManager 2.12.0, its required foreground-service manifest declarations/permissions and validates these generated declarations in CI.

### Automated evidence — 2026-11-22

- Android run [44970800438](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438), run 267, source SHA `645d2d349ecc9fe916b02a219a3ce0139f22b64a` — **success**.
- Format, strict analysis, **160/160 Flutter tests**, Android platform generation, ARM64 debug APK build, ARM64-only assertion, 10-unique-native-library/no-duplicate assertion and APK upload all passed.
- APK artifact [14733448407](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733448407), 59,996,128 bytes; archive SHA-256 `e7bf5a4a700b6c828d434c90667d3387ef26194c341d3c1bc42a2f8a72f440b5`.
- Root/desktop CI [44970800462](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800462), run 310 — **success** across checks, UI smoke, offline media pipeline and Apple Silicon package validation.

### Remaining acceptance gates

- Test background completion and relaunch recovery on a physical ARM64 handset; separately test ordinary process death versus explicit Android force-stop (force-stop may defer scheduled work until the app is launched again).
- Confirm notification visibility/action, app notification permission behavior, foreground execution, OEM battery restrictions, cancellation latency and cleanup during long-running renders.
- Exercise representative real media fixtures (long/VFR/rotated/no-audio/silent/corrupt/truncated), fully decoded audio/video outputs, crop continuity and Arabic/English subtitle timing/placement.
- Targeted per-clip re-render and retired-output cleanup were added on 2026-11-26 (see the addendum below). Full physical export delivery/cleanup and complete caption-animation preview/native parity remain open.

**Decision:** accept the WorkManager/background-render code slice as passing automated gates. Do not mark Phase 8 globally complete until the physical-device and remaining product/media acceptance items above are satisfied.


## Current status clarification — 2026-11-23

The three historical bullets above that describe an Activity-owned render map or state that WorkManager was not implemented are dated snapshots from 2026-11-21. They are **superseded** by the 2026-11-22 section titled “WorkManager foreground rendering and durable completion” and must not be used as the current implementation status.

Current source uses `NativeRenderEngine` and `NativeRenderWorker` through WorkManager long-running foreground work, project-tagged cancellation, progress/cancel notification, and durable completion handoff. Flutter validates and persists the export/checkpoint before acknowledging the durable completion.

Phase 8 is still not globally accepted: physical ARM64 background/relaunch/force-stop/OEM tests, notification and cancellation behavior, real media fixture/decode/crop/caption evidence, and complete on-device export/cleanup acceptance remain open. Targeted per-clip re-render code and its direct integration test are recorded below.


## Targeted per-clip re-render and retired-output cleanup — 2026-11-26

**Decision: accept the automated product-code slice; physical export/lifecycle acceptance remains open.**

- The Review page now exposes a per-candidate export/re-export action. It calls the existing processing pipeline with an explicit `onlyClipId`, not a separate renderer or a parallel export implementation.
- The pipeline rejects a requested clip ID that is not in the project's candidate set.
- For every non-target clip, the pipeline fails closed unless a checkpoint matches the current source/configuration/edit fingerprint, the saved export record has full-decode evidence, and Android's `verifyExport` confirms the existing file's SHA, dimensions, duration and full-decode evidence. A stale/edited/missing peer export requires a full-project resume rather than silently preserving it.
- The requested clip bypasses its prior render checkpoint and is freshly rendered. The new full-decode-validated export record is persisted before the previous public MediaStore URI is removed.
- If Android cannot delete a replaced export, its URI is retained in `supersededOutputUris`; Review exposes a cleanup action so the user can retry. Deleting the current export also attempts to clean any retained superseded URIs before deleting its record.
- Commit `43defa873129b59530211a37f565b099147de5b7` introduced the code; commits `5de39d437a7b47f9f35a21b2153d9d35b6f12f49`, `730f3c41ea79b1f11f0c266fa5217f321f635b30` and `8bd9d5fb1534dc0da52d6b8af484059873f5c397` fixed strict Dart analysis findings before acceptance.
- Android #446 on product source SHA `8bd9d5fb1534dc0da52d6b8af484059873f5c397` passed format, strict analysis, 257/257 Flutter tests, ARM64 APK build, Media3 emulator/parity checks, ARM64-only and native-library checks, and APK upload. Root CI #502 and Branch Policy #152 also passed.
- A direct integration test was added in test-only commit `83053e7284e9225a94797d82020235b1914563d1`. It seeds two clips and proves that the target clip alone is rendered, the untouched peer is reverified and retained, and only the target's previous output is deleted. Android #447 passed strict analysis and the Flutter Test step with this test; its subsequent APK build and emulator/package steps were still running when this record was written.
- This is automated evidence only. Physical ARM64 re-render/peer-preservation/old-output cleanup, WorkManager process-death/force-stop, notification/cancellation and real-media format acceptance remain field gates.



The complete device-level checklist is maintained in [`PHASE-08-PHYSICAL-MEDIA-AND-WORKMANAGER-ACCEPTANCE-2026-11-26.md`](PHASE-08-PHYSICAL-MEDIA-AND-WORKMANAGER-ACCEPTANCE-2026-11-26.md). All field items remain `NOT RUN` until a physical ARM64 handset report is attached.
