# Phase 9 — Caption Studio workflow record

**Date:** 2026-11-21  
**Repository:** `m5ham3ds/CUTAWAN`  
**Branch:** `main`  
**Accepted app head:** `e2d3c08e9f2d4559cd931f4b461607f6012a2a95`  
**Page status:** accepted for this workflow slice; broader Phase 9 and physical Phase 10 remain in progress.

## Scope and non-repetition

This pass followed the accepted Create, Review and Clip Editor pages. It changes Caption Studio and the smallest shared preference/export contract needed to make displayed settings persist for the selected project and accurately distinguish preview-only animation from supported MP4 rendering. It does not repeat or restyle the three accepted pages.

## Implemented behavior

### Selected-project ownership and persistence

- Added an explicit project dropdown. Loading, reloading and saving target the selected project ID, not the first project in the list.
- Selecting another project loads its saved caption preferences and transcript. A generation token prevents a slower previous transcript load from overwriting the current selection.
- A persisted preference snapshot allows the screen to notice project updates when it is not holding unsaved local edits.
- If there is no project, the studio remains a preview workspace, but the save action is disabled because there is no project record to persist into.

### Caption styling and timing

- Retained the existing 12 style preset IDs and 10 motion preview IDs.
- Saved fields include caption enablement, style preset, text/highlight/background colors, font family/scale, vertical position, uppercase/bold and word-timing offset.
- Preview is generated from saved Whisper word timing and maintains Arabic RTL / other-language LTR direction.
- Word timing offset is persisted into project preferences and continues through the existing sidecar and export pipeline.
- Custom background color is resolved into the caption style sent to the export pipeline and ASS sidecar. The same saved setting is used by Clip Editor's preview style resolution.

### Preview motion versus MP4 export

- Added nullable `captionPreviewAnimationId` to `ClipPreferences`, preserving compatibility with older preference JSON that does not contain the field.
- The preview effect remains saved and is restored in Caption Studio.
- The MP4 export field `captionAnimationId` remains restricted to effects currently implemented by the native Android renderer: `static` and `karaoke_fill`.
- If the user chooses another preview effect (for example Fade), the effect is retained for preview, the MP4 export setting safely falls back to Static, and the page explicitly identifies this as preview-only.
- This prevents a visual control from silently promising an effect that is not rendered into the actual exported video.

## Files changed

- `mobile/flutter_app/lib/screens/home_shell/caption_studio_page.dart`
- `mobile/flutter_app/lib/domain/clip_preferences.dart`
- `mobile/flutter_app/lib/services/processing_pipeline_service.dart`
- `mobile/flutter_app/lib/screens/features/clip_editor_page.dart` (shared caption-background preview style integration)
- `mobile/flutter_app/test/caption_studio_project_selection_test.dart` (new)
- `mobile/flutter_app/test/caption_sidecar_generator_test.dart`
- `mobile/flutter_app/test/caption_timed_preview_test.dart`
- `mobile/flutter_app/test/widget_test.dart`
- `mobile/flutter_app/test/project_contract_test.dart`

## Implementation and repair commits

- First Caption Studio workflow implementation: `1d1f6408fdc8e468a359aa736c790c39d1cae559`.
- Narrow-layout and widget/test correction: `6d89cb5ed63f4337b8569b6d0ce4f84f59a01283`.
- Lazy-control scroll ordering correction: `8ea3d75d54b7cceb7a10dfe140439fef786453dd`.
- Final exact animation-preview message expectation: `e2d3c08e9f2d4559cd931f4b461607f6012a2a95`.

The earlier attempts failed in test assertions and were corrected before acceptance. The accepted run is the final head/run below; do not resume from failed runs 44952913543, 44953293933 or 44953561180.

## Android and desktop CI evidence

- Mobile Android run [44953830473](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473), run number 257, accepted SHA `e2d3c08e9f2d4559cd931f4b461607f6012a2a95` — **success**.
- Dart format: passed.
- `flutter analyze --fatal-infos`: passed; `No issues found!`.
- Flutter unit/widget suite: **154/154 passed**.
- ARM64 debug APK build: passed.
- ABI verification: exactly `arm64-v8a`.
- Native library verification: 10 unique libraries, no duplicate basenames; `libggml-cpu.so`, `libggml.so` and `libggml-base.so` were present.
- APK artifact [14727205792](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473/artifacts/14727205792), 59,094,264 bytes; archive SHA-256 `366a66f02d012135b0bec933492642c6a487bdd9b1a7a532cd1978b5b5fb1adf`.
- Coverage artifact [14726905907](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473/artifacts/14726905907), 16,294 bytes; archive SHA-256 `13b8639dab36826fd00e3a20f61ef94ad8b2df28e167df63af4c8b66f21119f3`.
- Root/desktop CI [44953830478](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830478) — **success**, including typecheck/lint/tests, packaged Apple Silicon inference/export, Xvfb UI smoke and offline ffmpeg/caption/render pipeline.

These are automated CI results, not physical-device acceptance.

## Known limits — keep visible

- Caption preview is based on transcript word timing but does not run over a live video preview in this page.
- Only Static and Karaoke Fill are rendered by the native MP4 path. Other animation effects are preview-only and export safely falls back to Static.
- Caption preview/native overlay visual parity has not been measured pixel-by-pixel on a physical device.
- This page pass does not prove end-to-end subtitle synchronization on real media, sustained performance, or physical handset accessibility.

## Next page — do not repeat accepted work

**Jobs** is next. Work only on the Jobs page. Improve task status grouping, progress/stage clarity, per-project action ownership, cancellation/resume handoff and narrow-screen layout while using the existing processing and repository services. Do not repeat Create, Review, Clip Editor or Caption Studio unless a specific regression is reported.
