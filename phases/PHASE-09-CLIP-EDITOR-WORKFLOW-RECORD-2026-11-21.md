# Phase 9 — Clip Editor workflow record

**Date:** 2026-11-21  
**Repository:** `m5ham3ds/CUTAWAN`  
**Branch:** `main`  
**Accepted app head:** `3c0e7ee077364a980670982671b2c34676dc638a`  
**Page status:** accepted for this workflow slice; broader Phase 9 remains in progress.

## Scope and non-repetition

This pass continued after the already accepted Create and Review pages. It changed the selected-candidate Clip Editor workflow and the minimum domain/repository/pipeline contracts required to make the editor's settings persistent and effective in export. It did not rework Create, Review, Jobs or Caption Studio.

The selected candidate remains the identity anchor. Timing stays in source milliseconds in the candidate record; clip-specific framing uses a separate versioned artifact. Caption and export checkpoint fingerprints include the relevant edited values.

## Implemented behavior

### Playback and trim

- Source video preview supports Android `content://`, app/local `file://` and direct HTTP/HTTPS URLs through the existing `video_player` integration.
- Playback is scoped to the selected candidate: at its end, preview pauses and seeks back to its start.
- Source-time start/end trim uses a bounded range control and a 500ms minimum duration. Buttons can set the start or end at the current playhead.
- Candidate title, start/end and duration are saved back into the existing candidate set without replacing the candidate ID, score, transcript evidence or rationale.

### Framing and aspect ratio

- Output choices: portrait 9:16, square 1:1, landscape 16:9 and original.
- Framing choices: automatic analyzed reframe plan, full-frame fit and manual static focus point.
- Manual focus coordinates are normalized to 0..1 and clamped to a valid crop rectangle with the requested output ratio.
- Per-clip overrides are stored in versioned `clip_edit_<clipId>.json` artifacts. The repository validates the project ID and clip ID, verifies the candidate belongs to the project, and validates override schema/coordinates when loading.
- The processing pipeline reads the saved override for the exact candidate. Automatic mode retains the existing analyzed reframe shots; full-frame emits a fit segment; manual focus emits a clip-relative crop segment. These overrides are included in the per-clip render fingerprint.

### Caption appearance and timing

- Editor-level options include caption enablement, the existing 12 preset IDs, the existing animation IDs, text/highlight color, font family, font scale, vertical position, uppercase/bold flags and a bounded word-timing offset.
- Timed preview cues are generated from the saved transcript's word timestamps and candidate range, and the active spoken word is highlighted. Direction is Arabic RTL when transcript language/content is Arabic and otherwise LTR.
- Timing offset is applied to original transcript word timestamps before the words are clipped to the current candidate window. It is passed to sidecar SRT/ASS generation and the cue payload used by export.
- The processing pipeline resolves the style overrides into the caption style payload rather than only displaying them in the editor. Style fields and timing offset participate in caption/render checkpoint fingerprints.

### Save and return

- Save retains candidate ID and writes edited candidate title/range, per-clip framing overrides and project-level caption/aspect preferences.
- After save, the page returns to the existing Review destination. The user must run/resume processing again to create an MP4 with the latest edits; the editor does not show an updated export before a new render occurs.
- Existing analysis, Whisper, candidate discovery, Qwen annotation, framing planner, checkpoint service and Media3 render service were preserved. The editor does not introduce a separate media-processing engine.

## Files changed

- `mobile/flutter_app/lib/screens/features/clip_editor_page.dart`
- `mobile/flutter_app/lib/domain/clip_edit_overrides.dart` (new)
- `mobile/flutter_app/lib/domain/clip_preferences.dart`
- `mobile/flutter_app/lib/services/local_project_repository.dart`
- `mobile/flutter_app/lib/services/caption_sidecar_generator.dart`
- `mobile/flutter_app/lib/services/processing_pipeline_service.dart`
- `mobile/flutter_app/test/clip_edit_overrides_test.dart` (new)
- `mobile/flutter_app/test/clip_editor_caption_timing_test.dart` (new)

## Implementation and repair commits

- UI/domain/pipeline first slice: `c082254b3d2c6e5b879d2841826e7facb8fc7322`.
- Repository persistence syntax recovery: `666bab1d54df0f67e5fecaea00ad1a9b56961f33`.
- Strict analyzer cleanup in editor/repository/tests: `3519312919e9e0c8fb97a83f73ef36b991140133`.
- Final interpolation lint correction: `3c0e7ee077364a980670982671b2c34676dc638a`.

The initial workflow attempts failed at formatting/analyzer gates and were repaired before acceptance. Do not resume from those failed commits; the accepted Android result is the final head/run below.

## Android and desktop CI evidence

- Mobile Android run [44944753374](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753374), run number 253, accepted SHA `3c0e7ee077364a980670982671b2c34676dc638a` — **success**.
- Dart format: passed.
- `flutter analyze --fatal-infos`: passed.
- Flutter unit/widget suite: **150/150 passed**.
- ARM64 debug APK build: passed.
- ABI verification: exactly `arm64-v8a`.
- Native library verification: 10 unique libraries, no duplicate basenames; `libggml-cpu.so`, `libggml.so` and `libggml-base.so` were present.
- APK artifact [14723029272](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753374/artifacts/14723029272), 59,076,229 bytes; archive SHA-256 `a4e46370c6df2c29d2bc4fe7a6dbf48ad4f4e9edc43831e2f046931dad689f8f`.
- Coverage artifact [14723970064](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753374/artifacts/14723970064), 15,719 bytes; archive SHA-256 `b9ea9364ffe609a0f9b88183df3ffb2b2d2becebf4174df0a8d2f693af02ed60`.
- Root/desktop CI [44944753329](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753329) — **success**.

These are automated CI results, not physical-device acceptance.

## Known limits — keep visible

- No filmstrip thumbnails or frame-by-frame timeline.
- Manual focus is one static point per clip, not a keyframed focus track; the preview does not provide direct drag-to-focus handles.
- No clip transitions or multi-track editing.
- Flutter preview crop/caption display is an approximation and is not proven pixel-identical to the Media3 render output.
- The broader caption animation catalogue and native render behavior still need mode-by-mode visual parity verification.
- No long real-media fixture, physical ARM64 device playback/export quality test, background render/process-death validation, sustained thermal/battery test or physical accessibility review was performed in this page pass.

## Next page — do not repeat accepted work

**Caption Studio** is next. Work only on that page. Start by resolving selected-project ownership (currently its preference loader/saver uses the first project), then align preview controls, preset/motion behavior and persisted timing/style preferences with the existing caption contract. Verify actual preview/export support per animation instead of presenting unimplemented effects as complete.

Do not repeat or restyle Create, Review or Clip Editor unless a specific regression is reported.
