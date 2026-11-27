# CUTAWAN Mobile — Native Flutter Android App

CUTAWAN Mobile is the native Android companion application built with Flutter and Dart under `mobile/flutter_app/`. It is the only mobile product target. The root Electron application is legacy/reference desktop code and remains separate; this app is not a WebView wrapper.

**Current phase status:** see the [canonical ten-phase register](../../phases/README.md). Detailed implementation status, CI evidence and physical-device gates are maintained there.  
**Current mobile app-code SHA:** `98e31ea4ef702c48eeace7093865e5fc6e282ae1` (subsequent documentation-only commits did not change application source).

## Product and architecture rules

- Flutter/Dart owns UI, domain contracts, repositories, job orchestration, local inference coordination and user preferences.
- Native Android integrations are maintained in `tooling/android/MainActivity.kt`, `NativeRenderEngine.kt` and `NativeRenderWorker.kt`.
- Keep presentation, domain, persistence and processing services separated.
- Preserve saved project data and migrate schema changes deliberately.
- Local-first processing remains the default. Remote provider calls require explicit consent and send only bounded editorial text; source video and provider secrets are not uploaded by the editorial provider feature.
- Preserve Arabic RTL and English LTR, narrow-phone layouts, large text, safe areas, keyboard insets, orientation and accessibility behavior.
- Do not present a placeholder action as a completed operation. Export success requires a real output and full native decode validation.
- The root Electron/React app is outside this mobile implementation scope and must remain untouched unless desktop work is explicitly requested.

## Implemented scope by phase

### Phase 1 — app shell and Android foundation

Flutter/Material 3 shell, shared navigation components, Dashboard, Create, Jobs, Review, Clip Editor, Caption Studio, Settings, Models Center and Diagnostics routes are present. Android platform generation and ARM64-only APK checks are part of Mobile Android CI.

### Phase 2 — source import and project lifecycle

- SAF video selection with persisted read grants and native metadata probing.
- Direct HTTP/HTTPS video-file streaming with progress/cancel, redirect and HTTPS-downgrade validation, MIME/platform/private-host checks, download limit, storage reserve and partial-file cleanup.
- Versioned project/source contracts, schema-0 migration, durable app-private project/job/artifact records and safe source/grant cleanup.

Direct URL import accepts a direct video-file URL; it does not extract media from social-platform pages or bypass DRM/authentication/access restrictions.

### Phase 3 — local Whisper

Android MediaExtractor/MediaCodec audio extraction, bounded WAV range reading, channel downmix, 16 kHz mono resampling with a low-pass filter, 30-second Whisper chunks with two-second overlap and midpoint ownership, user-installed multilingual Whisper Base model with SHA verification, and word-timed transcript records.

VAD-backed silence rejection and measured Arabic/English WER/word-timing accuracy are not accepted. Physical device memory, latency and thermal behavior remain to be measured.

### Phase 4 — candidate discovery

Deterministic transcript-timed candidate boundaries, source/duration validation, audio RMS and sampled frame-change evidence, ranking, overlap/text deduplication and source coverage are implemented. Optional local Qwen annotation can add approved editorial text only; it cannot alter candidate identity, timestamps, scores or evidence. Frame-change samples are not semantic scene understanding.

### Phase 5 — reframing

Bounded native frontal-face sampling produces validated focus tracks and full-source reframe plans with safe `fit` fallback. Media3 consumes time-ranged crop segments. This is not active-speaker detection or audiovisual diarization; physical crop retention and continuity review remain open.

### Phase 6 — Caption Studio

Twelve caption styles, ten independent preview animations, editable/persisted typography and color settings, RTL-aware caption layout, and saved-transcript word-timed groups are implemented. The Studio preview is not synchronized to a continuously playing video clock. The native overlay uses timed cues and karaoke-fill emphasis; full animation-catalogue preview/export parity is not claimed.

### Phase 7 — multi-provider AI and credentials

Provider adapters support OpenAI Chat Completions, Google Gemini, Hugging Face Inference Providers and user-supplied OpenAI-compatible HTTPS endpoints. Model discovery is account/provider scoped. Provider credentials/preferences use secure storage; remote execution and outbound annotation calls are consent-gated. Provider price, quota and task compatibility must be confirmed with the provider. Physical Keystore backup/restore/rotation/deletion tests remain open.

### Phase 8 — pipeline and video export

- Persisted processing stages/checkpoints and source/configuration fingerprints.
- Native Media3 render engine validates each output's audio/video tracks by decoding to end-of-stream before publish and on revalidation.
- WorkManager foreground worker, progress/cancellation notification, project-scoped cancellation and durable completion handoff.
- Targeted per-clip re-render: requested clip is regenerated, untouched peers require valid matching fingerprints/native verification, and prior output is cleaned only after replacement persistence; cleanup failures remain actionable.
- Timed captions and time-ranged reframing are rendered into MP4. Output records include validation evidence and SHA.

Real ARM64 media, process-death/force-stop/relaunch, notification, cancellation, OEM, playback and physical output quality checks remain open.

### Phase 9 — professional UI and editor workflows

- Dashboard, Settings, Models/Diagnostics and HomeShell/Create/Jobs/Review flows are extracted into feature-scoped screens.
- Clip Editor includes playback/trim, native Filmstrip thumbnails, automatic/fit/manual crop and source-time focus keyframes, clip-level visual fades, project clip sequencing and video-only dip-to-black transitions.
- Eight preview/export scenarios passed 24/24 matched-timestamp pixel comparisons at the fixed MAE/worst-patch thresholds.
- Responsive, page-golden, RTL/LTR, landscape/safe-area and keyboard-focus test slices are present.

Physical handset review remains open. Dip-to-black is video-only; no audio crossfade or complete multitrack audio mix is implemented. The eight-case parity matrix is not exhaustive caption-animation or all-media certification.

### Phase 10 — physical device quality and acceptance

Device Diagnostics collects non-identifying runtime/device metrics and performs an ephemeral secure-storage canary round-trip. A separate Diagnostics action exports a versioned, privacy-filtered field-evidence JSON template with Phase 8/9/10 check identifiers. It initializes tests as `not-run` and acceptance as `not-accepted`; it does not execute field tests or infer physical-device identity.

The Phase 10 tooling includes two deterministic field-evaluation utilities. The Arabic/English transcription evaluator requires a manually confirmed handset, pinned build SHA, SHA-256-locked fixture and human-reviewed word-timed reference; it reports S/D/I, WER, matched-word coverage and median/P95 timing errors, with an eight-million-cell alignment cap. The candidate evaluator compares a candidate-discovery run with human-reviewed gold moments using one-to-one temporal IoU, precision/recall/F1, duplicate clusters, source-time coverage and separate keep/repair/reject/unreviewed decisions. It caps pairwise workloads and does not set pass thresholds or mark any phase accepted. See [the transcription evaluator protocol](../../phases/PHASE-10-TRANSCRIPTION-EVALUATION-TOOL-2026-11-27.md) and [the candidate evaluator protocol](../../phases/PHASE-10-CANDIDATE-EVALUATION-TOOL-2026-11-27.md).

No physical handset evidence corpus, reviewed transcript WER/timing, candidate/crop quality result, full-decode field report, sustained performance/thermal/battery result, SAF/process-death/Keystore lifecycle or end-to-end consent field result has been collected.

## Current verified CI status — 2026-11-27

- Current mobile app-code SHA: `716408d244b688f028bececf5f72b9e356cee8e0`.
- Android #456: format and strict `flutter analyze --fatal-infos` passed; **279/279 Flutter tests passed**; ARM64 APK build passed; Media3 and all eight preview/export parity cases passed (24/24 timestamp comparisons); native package verification found exactly `arm64-v8a` and ten unique native libraries with no duplicates; APK and coverage artifacts uploaded.
- APK artifact: [cutawan-mobile-arm64-debug, artifact 15231197350](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622887/artifacts/15231197350), 60,654,040 bytes; ZIP SHA-256 `808461f0e618642c30c948667a9f03e6f0e0b1e5947051f2b46a832f0cc94728`.
- Flutter coverage artifact: [15231250678](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622887/artifacts/15231250678).
- Root CI #515 succeeded: checks, offline pipeline, Xvfb UI smoke and Apple Silicon packaging. Branch Policy #165 succeeded; `main` is the only branch.

The #456 APK contains the Phase 10 transcription and candidate-evaluation tooling, but no physical field evidence is prefilled. CI/emulator results do not replace physical-device acceptance.

See the [current phase register](../../phases/README.md) for exact workflow links, artifact metadata and the current field checklists.

## Build and validation

Run from this directory:

```bash
bash tooling/generate_android_platform.sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --reporter expanded
flutter build apk --debug --target-platform android-arm64
```

CI uses Flutter 3.47.6, generates Android platform files, compiles the Kotlin bridge, tests Flutter code, builds an ARM64 APK, asserts the packaged ABI/native libraries, runs Media3/integration checks when build dependencies are available, and uploads artifacts.
