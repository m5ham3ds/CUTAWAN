# CUTAWAN Mobile — canonical phase register

**Last synchronized:** 2026-11-27  
**Repository:** `m5ham3ds/CUTAWAN`  
**Authoritative branch:** `main` only  
**Current mobile app-code SHA:** `716408d244b688f028bececf5f72b9e356cee8e0` (subsequent phase documentation synchronization commits do not change application source)

This file is the current source of truth for the ten-phase CUTAWAN Mobile plan. The individual Phase 1–10 files below describe the implementation mapped to the checked-in project. Dated implementation records are retained as historical evidence; when an older snapshot says that a feature is still missing, this register and the newest dated addendum take precedence.

The Android Flutter app at `mobile/flutter_app/` is the only active mobile product target. The root Electron application is legacy/reference desktop code and is not part of these mobile changes.

## Current repository and CI baseline

| Check | Current result |
|---|---|
| Main branch / mobile app-code SHA | `716408d244b688f028bececf5f72b9e356cee8e0` |
| Branch inventory | Only `main` exists |
| Android #456 | <badge>Success</badge>: Format, strict `flutter analyze --fatal-infos`, **279/279 Flutter tests**, ARM64 APK build, Media3 integration, eight-scenario preview/export matrix (24/24 timestamp comparisons), ARM64-only ABI check and APK upload all passed |
| Android #456 APK | Artifact [`cutawan-mobile-arm64-debug`](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622887/artifacts/15231197350), 60,654,040 bytes; ZIP SHA-256 `808461f0e618642c30c948667a9f03e6f0e0b1e5947051f2b46a832f0cc94728` |
| Android #456 native packaging | Exactly `arm64-v8a`; 10 unique native libraries, no duplicate basenames; GGML libraries `libggml-cpu.so`, `libggml.so`, `libggml-base.so` verified |
| Flutter coverage #456 | Artifact [`cutawan-mobile-flutter-coverage`](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622887/artifacts/15231250678), ZIP SHA-256 `b711840f1f7dd9c47505938d8a450e44bc2f02d2eed676983c877cbe53ac6c61` |
| Root CI #515 | Success: checks, typecheck/lint/tests, offline pipeline, Xvfb UI smoke and Apple Silicon packaging |
| Branch Policy #165 | Success: `main` is the only branch |
| Release #507 | Skipped as expected; this push was not a release build |

Links: [Android #456](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622887) · [Root CI #515](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622952) · [Branch Policy #165](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622871).

The APK is built from source SHA `716408d` and includes the Phase 10 candidate-evaluation tooling. The successful automated gates do not constitute physical handset acceptance; Phase 8/9/10 device evidence remains open.

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
| [8](08-end-to-end-pipeline-and-export.md) | Durable processing, rendering and export | Media3 full-track end-of-stream decode validation, WorkManager foreground rendering, durable completion handoff, project cancellation and targeted per-clip re-render/cleanup delivered; Android #456 passed the current 279-test suite and Media3 integration | Physical ARM64 real-media, background/relaunch/force-stop, notifications/cancellation, OEM behavior, playback and output integrity |
| [9](09-professional-mobile-ui.md) | Professional UI, editor workflows and responsive/accessibility work | Dashboard/Create/Jobs/Review/Clip Editor/Caption Studio/Settings/Models/Diagnostics workflows, Filmstrip, source-time keyframes, visual fades, sequence composition/dip-to-black and eight-scenario 24/24 parity matrix passed on Android #456 | Physical handset RTL/LTR, large text, landscape, insets, real keyboard focus, editor/export and OEM acceptance; no audio crossfade/full multitrack mix |
| [10](10-physical-device-acceptance.md) | Physical-device quality, security and performance acceptance | Diagnostics, privacy-filtered versioned field-evidence template, bounded Arabic/English WER/word-timing evaluator and candidate-quality/editorial-selection evaluator implemented; Phase 10 preparation remains active | Human-confirmed handset, hash-locked corpus, human-reviewed transcripts, actual WER/timing results, candidate/crop quality, full decode, sustained PSS/battery/thermal, process/SAF/Keystore/consent evidence and review |

## Current interpretation

- Phases 1–7 have their core mobile implementation and automated test coverage. Their remaining hardware, quality, security and provider checks are explicitly listed; a CI pass does not close them.
- Phase 8's rendering implementation is present and automated checks have passed on #456. Phase 8 remains **open** until the physical ARM64 checklist is completed.
- Phase 9's listed automated editor/UI slices are implemented. Android #456 passed the eight-scenario pixel-parity matrix (24/24 timestamp comparisons); this acceptance applies only to its measured cases; Phase 9 remains **open** until physical handset visual/accessibility acceptance.
- Phase 10 is the final phase in the current ten-phase plan. The diagnostics/evidence-template tooling is preparation, not field acceptance. No physical measurements or evidence corpus have been reported.
- At the user's explicit direction on 2026-11-27, Phase 10 preparatory engineering may proceed in parallel with unresolved Phase 8/9 field gates. This does **not** waive prerequisites or permit marking Phase 10 accepted before Phase 8/9 evidence is reviewed.
- There is no Phase 11 in the active plan.

## Current next actions

1. Install the Android #456 APK on a real ARM64 handset and manually confirm device identity, embedded `BUILD_SHA`, import/export behavior and the Phase 8/9 field checklists. Keep emulator results separate from physical evidence.
2. Build a hash-locked Arabic/English media corpus with manually reviewed word-level references and gold editorial moments. Keep source splits, licenses and fixture hashes with the records.
3. Run the Phase 10 transcription evaluator against each human-reviewed reference and matching physical-device Whisper output; preserve source SHA, build SHA, device identity and source-time window ranges.
4. Run the Phase 10 candidate evaluator against the same source fixture and human-reviewed gold moments; capture all keep/repair/reject decisions and leave unreviewed candidates explicitly unreviewed.
5. Complete [Phase 8 physical media/WorkManager checklist](PHASE-08-PHYSICAL-MEDIA-AND-WORKMANAGER-ACCEPTANCE-2026-11-26.md), [Phase 9 physical handset checklist](PHASE-09-PHYSICAL-HANDSET-ACCEPTANCE-2026-11-26.md), and the remaining Phase 10 performance/security/lifecycle/consent checks. Never fill physical evidence from emulator/CI fixtures or inferred device identity.

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
- [Phase 10 transcription WER/timing evaluator](PHASE-10-TRANSCRIPTION-EVALUATION-TOOL-2026-11-27.md)
- [Phase 10 candidate quality/human-selection evaluator](PHASE-10-CANDIDATE-EVALUATION-TOOL-2026-11-27.md)
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
