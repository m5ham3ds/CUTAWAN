# Phase 5 — Face sampling and validated reframing plans

**Current state:** bounded frontal-face sampling, validated focus tracks and time-ranged crop plans are implemented. This is not active-speaker recognition; real-footage crop quality remains open.

## Implemented scope

- Native Android face analysis uses bounded sampling: no more than 160 frames, scaled so the largest sampled dimension is at most 320 pixels.
- Empty samples are retained in coverage calculations. Multiple frontal-face detections are ranked using confidence, face size and continuity with the previous selected centre.
- Dart contracts represent focus tracks, reframe shots and complete source-time reframe plans.
- The planner validates normalized geometry, timestamps and coverage. Very small/low-confidence faces or insufficient track coverage result in a safe full-frame `fit` plan rather than an unsafe automatic crop.
- Plans preserve a selected output aspect ratio and are saved as project-scoped `reframe.json` artifacts.
- Phase 8's native renderer consumes the time-ranged crop segments and applies the validated crop/fit transform at Media3 presentation timestamps. Keyframed crop interpolation is part of the measured Phase 9 editor/export matrix.

## Source map

- `lib/domain/reframe_contract.dart`
- `lib/services/android_reframe_analysis_service.dart`
- `tooling/android/MainActivity.kt` — native face sampling bridge.
- `tooling/android/NativeRenderEngine.kt` — time-ranged crop/fit rendering.

## Automated coverage

- `android_reframe_analysis_service_test.dart` and reframe-contract tests in `reframe_contract_test.dart`.
- Coverage includes no-face fallback, low confidence, minimum face size, track coverage, invalid geometry, full source-time coverage, duplicate timestamps and persisted-plan validation.
- Phase 9 instrumentation/pixel-parity tests exercise representative manual/automatic crops, keyframe interpolation and full-frame fit; see [pixel-parity acceptance](PHASE-09-PREVIEW-EXPORT-PIXEL-PARITY-ACCEPTANCE-2026-11-26.md).

## Known limits and field requirements

- The platform detector is a frontal-face detector. Profile faces, occlusion, very small faces and screen-only content may not produce reliable focus.
- Confidence/size/continuity is not audiovisual speaker diarization or proof that the selected person is talking. Do not describe this as active-speaker detection.
- Measure face-track retention, subject position and crop continuity across movement, scene cuts, occlusion and missing-face intervals on the hash-locked field corpus.
- Validate output framing and fit gaps on a real ARM64 handset; emulator pixel tests do not replace physical media evaluation.

**Related:** [Phase register](README.md), [Phase 5–6 integration record](../docs/mobile/PHASES_5_6_INTEGRATION.md), [Phase 8 physical checklist](PHASE-08-PHYSICAL-MEDIA-AND-WORKMANAGER-ACCEPTANCE-2026-11-26.md).
