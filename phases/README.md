# CUTAWAN Mobile — canonical phase register

**Last synchronized:** 2026-11-27  
**Repository:** `m5ham3ds/CUTAWAN`  
**Authoritative branch:** `main` only  
**Current source HEAD:** `98e31ea4ef702c48eeace7093865e5fc6e282ae1`

This file is the current source of truth for the ten-phase CUTAWAN Mobile plan. The individual Phase 1–10 files below describe the implementation mapped to the checked-in project. Dated implementation records are retained as historical evidence; when an older snapshot says that a feature is still missing, this register and the newest dated addendum take precedence.

The Android Flutter app at `mobile/flutter_app/` is the only active mobile product target. The root Electron application is legacy/reference desktop code and is not part of these mobile changes.

## Current repository and CI baseline

| Check | Current result |
|---|---|
| Main branch | `98e31ea4ef702c48eeace7093865e5fc6e282ae1` |
| Branch inventory | Only `main` exists |
| Android #448, current SHA | Format passed; strict `flutter analyze --fatal-infos` passed; **260/260 Flutter tests passed**; APK packaging failed on external Maven Central HTTP 429 resolving `org.jetbrains.kotlin:kotlin-gradle-plugins-bom:2.2.20` via `plugins.gradle.org` |
| Android #447, latest fully successful APK | Success on build SHA `83053e7284e9225a94797d82020235b1914563d1`; 258/258 Flutter tests, Media3 instrumentation, eight-scenario pixel matrix (24/24), ARM64-only ABI and unique native-library checks, APK and coverage artifacts passed |
| Root CI #507 | Success: checks/typecheck/lint/tests, offline pipeline, Xvfb UI smoke and Apple Silicon packaging |
| Branch Policy #157 | Success: `main` is the only branch |
| Release #499 | Skipped as expected; not a release build |

Links: [current Android #448](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46034533321) · [latest successful Android APK #447](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45859864265) · [Root CI #507](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46034533276) · [Branch Policy #157](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46034533273).

**Important build distinction:** Android #447 is the latest APK that completed packaging and native/emulator checks; it predates the Phase 10 field-evidence-template addition. Android #448 exercised the current source and all 260 Flutter tests passed, but the Gradle dependency download was rate-limited twice and no APK from SHA `98e31ea` was produced. Do not label #448 a successful Android build or claim its APK contains the new template. Retry the package gate after Maven Central is available.

## Phase matrix

| Phase | Scope | Current implementation state | Remaining acceptance |
|---|---|---|---|
| [1](01-android-foundation-and-arm64.md) | Native Flutter shell and ARM64 packaging | Flutter/Material 3 mobile shell, route architecture, Arabic/English directionality and ARM64 workflow delivered | Install/startup, orientation, system UI and OEM behavior on a real handset |
| [2](02-media-ingestion-and-project-lifecycle.md) | Media import, direct video-file download and project lifecycle | SAF import/grants, metadata probing, guarded HTTP(S) file download, durable project/job storage and cleanup delivered | Real provider URI permission after force-stop/relaunch and real network/provider edge cases |
| [3](03-local-whisper-transcription.md) | Local Whisper audio preparation and transcription | Native audio extraction, bounded PCM reading, mono/16 kHz low-pass resampling, overlapping chunks and word-timed transcript contracts delivered | Arabic/English WER and word-time error, VAD, long-file memory/thermal and physical-device evaluation |
| [4](04-candidate-discovery-and-editorial-evidence.md) | Candidate discovery, evidence, ranking and local Qwen annotation | Deterministic sentence/word-timed candidate generation, duration/source bounds, evidence ranking, deduplication, source coverage and guarded editorial annotation delivered | Real-media candidate completeness/precision, human editorial selection and duplicate/source coverage review |
| [5](05-face-guided-reframing.md) | Face sampling and crop planning | Bounded frontal-face sampler, validated full-timeline reframe plans and native time-ranged crop/fit renderer delivered | Real-footage face retention, crop continuity and difficult-scene evaluation; not active-speaker detection |
| [6](06-caption-studio-and-timed-preview.md) | Caption Studio, styles, motion and transcript preview | 12 style IDs, 10 preview modes, saved style preferences, RTL-aware layout and saved transcript-timed groups delivered | Live-video clock synchronization and complete preview/native-export animation parity |
| [7](07-ai-providers-and-secure-credentials.md) | Multi-provider AI and credential security | OpenAI, Gemini, Hugging Face and OpenAI-compatible provider adapters, account model discovery, secure credential store and explicit consent gates delivered | Physical Keystore backup/restore/rotation/deletion, real accounts/models, billing and policy acceptance |
| [8](08-end-to-end-pipeline-and-export.md) | Durable processing, rendering and export | Media3 full-track end-of-stream decode validation, WorkManager foreground rendering, durable completion handoff, project cancellation and targeted per-clip re-render/cleanup delivered; automated Android #447 passed | Physical ARM64 real-media, background/relaunch/force-stop, notifications/cancellation, OEM behavior, playback and output integrity |
| [9](09-professional-mobile-ui.md) | Professional UI, editor workflows and responsive/accessibility work | Dashboard/Create/Jobs/Review/Clip Editor/Caption Studio/Settings/Models/Diagnostics workflows, Filmstrip, source-time keyframes, visual fades, sequence composition/dip-to-black and eight-scenario 24/24 parity matrix delivered | Physical handset RTL/LTR, large text, landscape, insets, real keyboard focus, editor/export and OEM acceptance; no audio crossfade/full multitrack mix |
| [10](10-physical-device-acceptance.md) | Physical-device quality, security and performance acceptance | Diagnostics and privacy-filtered versioned field-evidence JSON template implemented; Phase 10 preparation is active | Human-confirmed handset, hash-locked corpus, WER/timing, candidate/crop quality, full decode, sustained PSS/battery/thermal, process/SAF/Keystore/consent evidence and review |

## Current interpretation

- Phases 1–7 have their core mobile implementation and automated test coverage. Their remaining hardware, quality, security and provider checks are explicitly listed; a CI pass does not close them.
- Phase 8's rendering implementation is present and automated checks have passed on #447. Phase 8 remains **open** until the physical ARM64 checklist is completed.
- Phase 9's listed automated editor/UI slices are implemented. The eight-scenario pixel-parity matrix is accepted only for its measured cases; Phase 9 remains **open** until physical handset visual/accessibility acceptance.
- Phase 10 is the final phase in the current ten-phase plan. The diagnostics/evidence-template tooling is preparation, not field acceptance. No physical measurements or evidence corpus have been reported.
- At the user's explicit direction on 2026-11-27, Phase 10 preparatory engineering may proceed in parallel with unresolved Phase 8/9 field gates. This does **not** waive prerequisites or permit marking Phase 10 accepted before Phase 8/9 evidence is reviewed.
- There is no Phase 11 in the active plan.

## Current next actions

1. Retry the Android ARM64 packaging gate from current SHA `98e31ea` once Maven Central no longer returns HTTP 429. The current-source 260-test suite, formatting and strict analysis already passed; do not rewrite passing application code to address a dependency-host rate limit.
2. After that build succeeds, use its exact APK and embedded `BUILD_SHA` as the current candidate. The #447 APK may be used for Phase 8/9 device checks, but it does not contain the Phase 10 JSON template.
3. Complete [Phase 8 physical media/WorkManager checklist](PHASE-08-PHYSICAL-MEDIA-AND-WORKMANAGER-ACCEPTANCE-2026-11-26.md) and [Phase 9 physical handset checklist](PHASE-09-PHYSICAL-HANDSET-ACCEPTANCE-2026-11-26.md) with real device evidence; keep each unrun item explicitly unrun.
4. Use Diagnostics to copy the privacy-filtered device report and the versioned field-evidence template, then populate fixture hashes, methods, measurements and review outcomes only from actual tests.
5. Update these phase records after results are reproducible and reviewed. Never fill physical evidence from emulator/CI fixtures or inferred device identity.

## Detailed phase documents

- [Phase 1 — Android foundation and ARM64](01-android-foundation-and-arm64.md)
- [Phase 2 — media ingestion and project lifecycle](02-media-ingestion-and-project-lifecycle.md)
- [Phase 3 — local Whisper transcription](03-local-whisper-transcription.md)
- [Phase 4 — candidate discovery and editorial evidence](04-candidate-discovery-and-editorial-evidence.md)
- [Phase 5 — face-guided reframing](05-face-guided-reframing.md)
- [Phase 6 — Caption Studio and timed preview](06-caption-studio-and-timed-preview.md)
- [Phase 7 — AI providers and secure credentials](07-ai-providers-and-secure-credentials.md)
- [Phase 8 — pipeline and export](08-end-to-end-pipeline-and-export.md)
- [Phase 9 — professional mobile UI](09-professional-mobile-ui.md)
- [Phase 10 — physical-device acceptance](10-physical-device-acceptance.md)

### Detailed acceptance and implementation evidence

- [Phase 8 physical media/WorkManager checklist](PHASE-08-PHYSICAL-MEDIA-AND-WORKMANAGER-ACCEPTANCE-2026-11-26.md)
- [Phase 8 WorkManager implementation record](PHASE-08-WORKMANAGER-BACKGROUND-RENDER-RECORD-2026-11-22.md)
- [Phase 9 physical handset checklist](PHASE-09-PHYSICAL-HANDSET-ACCEPTANCE-2026-11-26.md)
- [Phase 9 preview/export pixel-parity acceptance](PHASE-09-PREVIEW-EXPORT-PIXEL-PARITY-ACCEPTANCE-2026-11-26.md)
- [Phase 9 Clip Editor keyframes/transitions/preview geometry](PHASE-09-CLIP-EDITOR-THUMBNAILS-KEYFRAMES-TRANSITIONS-PREVIEW-GEOMETRY-2026-11-24.md)
- [Phase 10 Diagnostics implementation and field-evidence template](PHASE-10-DEVICE-DIAGNOSTICS-IMPLEMENTATION-RECORD-2026-11-21.md)
- [Phase 3–4 detailed integration record](../docs/mobile/PHASES_3_4_INTEGRATION.md)
- [Phase 5–6 detailed integration record](../docs/mobile/PHASES_5_6_INTEGRATION.md)

## Global engineering constraints

1. Root Electron desktop remains intact. Flutter Android is a sibling application and is the sole mobile implementation target.
2. Only `main` is allowed. Do not create, use or synchronize a secondary branch.
3. Never put an API key in source, assets, project JSON, logs, screenshots, analytics or GitHub Actions output.
4. Cloud calls require explicit user consent. Send only the minimum text required; do not upload source video by default.
5. Provider model discovery does not guarantee task compatibility, free use, quota, price or account access.
6. Local inference remains supported. Selecting a remote model must not silently uninstall or replace local models.
7. Failure of optional model annotation must preserve deterministic candidates and project artifacts.
8. Candidate IDs, timestamps, project IDs, source evidence and deterministic scores remain app-owned; LLM output is restricted to approved editorial text fields.
9. A render/export feature must not report success until the output exists and passes the native validation contract, including full track decode.
10. Physical-device identity and field acceptance require human-confirmed, traceable evidence. Do not infer them from a CI runner, emulator, mock channel or device fingerprint heuristic.

## History and supersession rule

The original planning sequence dated 2026-11-21 was: Phases 1–3, then 4–5, then 6–7, then 8, then 9, then 10. The user later explicitly permitted **Phase 10 preparation only** to proceed in parallel. Old dated implementation notes remain preserved as historical evidence; this current register controls current status and ordering.
