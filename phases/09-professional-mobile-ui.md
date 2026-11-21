# Phase 9 — Native Flutter phone app redesign

## Non-negotiable target

This phase applies **only** to `mobile/flutter_app/`, the native Android application implemented in Flutter/Dart. Do not implement the redesign in Electron/React or reuse desktop-only UI code. The root desktop application is outside this phase.

## Objective

Deliver a complete, coherent, modern mobile creator studio. Rebuild the actual screen hierarchy and interactions, not just the theme colors. Preserve domain logic and repositories while replacing presentation with reusable, feature-scoped Flutter widgets.

## Target information architecture

- **Dashboard / Projects:** recent projects, real storage usage, processing overview, quick resume, create-project entry and a polished empty state.
- **Create:** local import, safe direct-video URL import, actual source metadata and preview, output profiles, clip duration/count, caption and speaker options, progressive disclosure for advanced settings.
- **Jobs:** active, queued, failed and completed tasks; real stage/progress, cancel, retry and resume actions bound to durable job records.
- **Review:** candidate preview, time range, score/rationale/provenance, keep/reject/reorder, inspect source and export state.
- **Clip Editor:** real video playback, timeline/filmstrip, draggable trim handles, crop/aspect ratio, manual focus/reframe and transitions. No fake editor controls.
- **Caption Studio:** real preset gallery, font and color controls, word timing, RTL/LTR preview and animated caption examples; persist selections to the project and export contract.
- **AI Center:** installed/downloadable local runtimes and models, provider selection, credentials in secure storage, remote model catalogue, privacy mode and explicit cloud consent.
- **Settings:** storage, performance, language, privacy, export defaults, accessibility, licenses and app diagnostics.

## Visual system

Create a distinct mobile-first design language rather than recoloring the current layout:
- Material 3 foundation with semantic color roles, typography scale, surfaces, gradients only where meaningful, spacing, radii, elevations and responsive breakpoints.
- Strong visual hierarchy, spacious editorial cards, meaningful iconography, polished empty/loading/error states and touch-friendly controls.
- Bottom navigation for top-level destinations and nested routes/sheets for editing and configuration.
- Distinct visual treatment for import, progress, review, editor and caption studio rather than repeating one generic card layout.
- Dark and light themes with system mode; check contrast and selection visibility.
- Arabic RTL and English LTR with correct text direction and mirrored navigation where appropriate.
- Motion: page transition, shared-axis or fade-through navigation, staggered list entrance, progress animation, button/selection feedback, bottom sheets, editor playhead/trim updates and real caption animation previews.
- Honor reduced-motion preferences and avoid motion that delays core actions.

## Open-source research and reuse

Research and evaluate open-source Flutter/Android projects before coding. Prefer components suitable for direct Flutter adaptation, such as video player/trim/timeline/caption editors and animation primitives. For each adopted component:
- Verify repository activity, Flutter/Dart compatibility, Android support and license.
- Reuse focused packages/components rather than copying entire applications.
- Record upstream repository, exact version or commit, license, files adapted and modifications in `mobile/flutter_app/THIRD_PARTY_UI_NOTICES.md`.
- Do not copy incompatible React/Electron UI into Flutter. Cross-platform repositories can be visual/interaction references only.
- Do not add a dependency without checking Android compatibility, maintenance and size impact.

## Architecture

Split `HomeShell` into feature-scoped screens and reusable widgets. Avoid a monolithic `part of` library as the long-term structure. Introduce explicit routing/navigation and clear state ownership. Keep service/repository calls outside presentational widgets where practical. All visible controls must be one of:
1. implemented and testable,
2. disabled with an honest reason and a path to resolve it, or
3. removed.

Preserve schema compatibility and existing project data. Never fabricate AI results or job completion.

## Acceptance tests

- Every primary CTA and interactive control asserts a real state change or service invocation.
- End-to-end navigation and back behavior without losing state.
- Golden/widget tests for dark/light, Arabic/English, RTL/LTR, 320dp and larger screens, landscape, keyboard insets, safe areas and large text.
- Semantics/accessibility labels, focus order and adequate tap targets.
- Test cancellation, failure, retry and process-recovery paths.
- Build ARM64 debug APK in CI. Run physical-device visual and workflow acceptance before declaring complete.

## Current status

Redesign is **not complete**. Existing Flutter shell and feature parts are an initial implementation only. The current UI is not evidence that the target information architecture or editor has been delivered. Do not mark Phase 9 done until all applicable acceptance criteria pass.

## Implementation update — 2026-11-21

A first product-facing redesign slice is delivered in Flutter:

- Five primary destinations: Dashboard, Create, Jobs, Review and Caption Studio.
- Dedicated Dashboard showing project counts/recent projects with working navigation.
- Dedicated Settings route linking to device diagnostics and AI/model/privacy settings.
- A source-backed Clip Editor with playback, source-time trim-range adjustment, title edits and output aspect-ratio changes saved to existing project/candidate contracts.
- Candidate timing is included in caption fingerprints. Changing aspect ratio does not rerun discovery and overwrite manually edited candidate ranges.
- Added tests for candidate trim updates, out-of-source range rejection, Dashboard-to-import navigation and Settings navigation.

**Still not complete:** feature-state extraction from the shared `part` library, filmstrip thumbnails, manual crop/focus keyframes and transitions, caption playback synchronized with video, exact preview/export parity, full light/dark + RTL/LTR golden matrix, accessibility audit, keyboard/landscape coverage and physical-device acceptance. The current editor preview is a centered crop; final exports use the saved reframe timeline.


## Workflow-page implementation — Create and Review — 2026-11-21

This page-by-page delivery uses Ssemble as a **workflow reference only**. No visual skin, brand assets or layout were copied.

### Create page

- The creation interaction is split into source selection and project configuration.
- Source selection supports the Android file picker and the existing direct HTTP/HTTPS video downloader. The selected file is inspected and presented before continuing.
- Project settings are confirmed in a second step: requested clip count, duration mode/custom range, target aspect ratio, output resolution, captions and caption preset/animation.
- Project persistence occurs only after the explicit final create action. The saved project then opens Review.
- The implementation retains safe cleanup of uncommitted SAF grants and app-owned downloads; it does not delete a source referenced by another saved project.
- The former inactive speaker-tracking switch and obsolete “engines not connected” message were removed.
- Accepted Create commit: `4b91efb9ad587bd839b8ff44667a05fe18f4b189`.
- Create verification: Mobile Android run [44909044979](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44909044979), 142/142 Flutter tests, strict analysis, ARM64 build and native package checks passed. APK artifact ID: `14709735177`.

### Review page

- The project card is arranged in workflow order: verified source, analysis progress, discovered clips, and exported files.
- A single primary action starts/resumes the full pipeline. Its current stage and progress are displayed; state belongs to the project being processed.
- Per-stage reruns are under a collapsed manual-tools section rather than competing with the primary workflow.
- Transcript and framing evidence are collapsible. Arabic transcript text renders RTL and Latin transcript text renders LTR.
- Candidate cards show title, score, time range, duration and available rationale, with a direct action to open the existing Clip Editor.
- Export records remain visible with their full-decode validation result.
- Existing Whisper, discovery, Qwen annotation, framing, pipeline, checkpoint and Media3 export services were preserved. This was a presentation/orchestration pass, not a reimplementation of processing algorithms.
- Review status labels are deliberately compact on narrow viewports; detailed task-state copy remains in the Jobs page.
- A dedicated 320dp widget test verifies the staged workflow, manual-tools expansion and no layout exception. Existing empty-state and import/reopen/verify workflow tests were updated to the new labels/actions.
- Accepted Review commit: `cb0ca70b3bc6751b3c245ab576ff021593e20c92`.
- Review verification: Mobile Android run [44923605861](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44923605861), **143/143 Flutter tests passed**, format and `flutter analyze --fatal-infos` passed, ARM64 debug APK built, native package verification passed and APK upload succeeded.
- APK artifact: `cutawan-mobile-arm64-debug`, ID `14715326297`, size 59,041,250 bytes, archive SHA-256 `9e225ad372fcbdbd4f94456b03104ef2f8cd5a59def43013b1bfcac3dd731fb3`.
- ABI verification: exactly `arm64-v8a`; 10 unique native libraries, no duplicate basenames; `libggml-cpu.so`, `libggml.so` and `libggml-base.so` are present.
- Coverage artifact ID: `14715165727`. Root/desktop CI run [44923605965](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44923605965) passed separately.

### Remaining Phase 9 work and exact resume point

- Create and Review are accepted for this workflow slice. Do not repeat them without a regression.
- Review does not yet implement keep/reject/reorder controls. Candidate selection is via opening the Clip Editor.
- Export records are presented with validation status; a dedicated export gallery, share/download interaction and delivery management remain separate work.
- The broader Clip Editor still needs its page-by-page workflow pass (playback/trim, framing/crop, caption edit, save/return) and its narrow-width/accessibility tests.
- Filmstrip thumbnails, manual focus keyframes, transitions, pixel-exact preview/export parity, larger-text/landscape accessibility and physical-device visual acceptance remain open.
- **Next page:** Clip Editor only. Keep the current source-time trim/edit persistence and output invalidation contracts. Do not start Jobs or Caption Studio redesign as part of the Clip Editor pass.


## Clip Editor workflow delivery — 2026-11-21

- Rebuilt `clip_editor_page.dart` as a focused mobile editing flow: selected clip playback, bounded 500ms-minimum source-time trim, title edit, output-ratio selection, framing choices and caption controls.
- The preview uses the original media source and loops/pauses at the candidate boundaries. Supported source forms remain content URI, local file and HTTP/HTTPS video URLs.
- Added aspect choices for portrait 9:16, square 1:1, landscape 16:9 and original.
- Framing choices: automatic (existing analyzed reframe plan), full frame (fit) and manual static focus. Manual focus X/Y is saved per candidate in a separate versioned `clip_edit_<clipId>.json` artifact; the repository confirms the clip belongs to the selected project before writing.
- Caption controls: enable/disable, existing preset and animation identifiers, text/highlight colors, font family/scale, vertical position, uppercase/bold flags and a bounded timing offset. The timing shift is applied to source word times before they are clipped to the candidate window for SRT/ASS and render cues.
- Caption preview is built from saved transcript word timing and follows Arabic RTL / other-language LTR. The export pipeline resolves the same caption style fields and reads per-clip framing overrides. Clip and caption fingerprints include edit settings, preventing old validated exports from being accepted as current after edits.
- Save preserves the candidate ID, writes the modified candidate range/title, stores clip-local framing, saves project preferences and returns to Review. A new processing run is required to create the changed MP4.
- Added tests for override serialization/validation, manual crop aspect ratio and edge clamping, independent per-clip persistence, preference round-trip and subtitle timing offset.
- Final accepted app head: `3c0e7ee077364a980670982671b2c34676dc638a`. Preceding source fixes include repository persistence correction and strict analyzer cleanup; no Create or Review implementation was repeated.
- Mobile Android run [44944753374](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753374), run 253 — **success**: format passed, `flutter analyze --fatal-infos` passed, **150/150 Flutter tests passed**, ARM64 debug APK built, ABI check and duplicate-library verification passed, artifact uploaded.
- APK artifact [14723029272](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753374/artifacts/14723029272): 59,076,229 bytes; archive SHA-256 `a4e46370c6df2c29d2bc4fe7a6dbf48ad4f4e9edc43831e2f046931dad689f8f`. APK contains only `arm64-v8a`, 10 unique native libraries and no duplicate native basenames.
- Coverage artifact [14723970064](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753374/artifacts/14723970064): 15,719 bytes; archive SHA-256 `b9ea9364ffe609a0f9b88183df3ffb2b2d2becebf4174df0a8d2f693af02ed60`.
- Root/desktop CI [44944753329](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753329) — success.
- **Not yet complete:** no filmstrip thumbnails; manual focus is a static point, not keyframed; no transition or multitrack editing; preview crop/caption rendering is not pixel-identical to Media3 output; the animation catalogue is broader than the editor's verified visual preview/export parity; physical-device/long-video testing remains open. This page slice therefore remains accepted while broader Phase 9 and Phase 10 remain in progress.
- **Next page:** Caption Studio only. Do not repeat Create, Review or Clip Editor.


## Caption Studio workflow delivery — 2026-11-21

- Reworked `caption_studio_page.dart` into an explicit project-scoped workspace. The project selector reloads the selected project's preferences and saved transcript; save writes only to that project's record. A preference snapshot detects external changes when the page is not dirty.
- Retained the existing 12 caption style preset IDs and 10 motion preview IDs. Style controls include font family/scale, text/highlight/background colors, position, bold/uppercase, caption enablement and word timing offset.
- Split preview motion from MP4 export motion with nullable, backward-compatible `captionPreviewAnimationId` in `ClipPreferences`. The preview keeps the chosen effect on reopen, while export stores only the modes verified by the native MP4 renderer (`static`, `karaoke_fill`). Other effects remain preview-only and safely fall back to Static in MP4; the UI states this explicitly.
- Caption background is now carried through caption style resolution, ASS sidecar style and renderer fingerprint. Clip Editor preview resolves the same saved background preference.
- Timed transcript preview uses saved Whisper word timings and preserves Arabic RTL / other-language LTR. Caption timing offset is persisted and passed through the existing sidecar/export contract.
- Tests cover selected-project ownership and preference save, preview-vs-export motion separation, backwards compatibility of old preference JSON, custom caption background in ASS, updated timed preview and a 320dp RTL narrow viewport.
- Final accepted head: `e2d3c08e9f2d4559cd931f4b461607f6012a2a95`. Earlier test attempts exposed UI-test ordering/expectation issues and were corrected; do not resume from failed runs 44952913543, 44953293933 or 44953561180.
- Mobile Android run [44953830473](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473), run number 257 — **success**: Dart format passed, `flutter analyze --fatal-infos` passed with no issues, **154/154 tests passed**, ARM64 debug APK built, ARM64-only ABI verification passed, duplicate native library check passed and APK uploaded.
- APK artifact [14727205792](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473/artifacts/14727205792): 59,094,264 bytes; archive SHA-256 `366a66f02d012135b0bec933492642c6a487bdd9b1a7a532cd1978b5b5fb1adf`. It contains only `arm64-v8a`, 10 unique native libraries and no duplicate basenames.
- Coverage artifact [14726905907](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473/artifacts/14726905907): 16,294 bytes; archive SHA-256 `13b8639dab36826fd00e3a20f61ef94ad8b2df28e167df63af4c8b66f21119f3`.
- Root/desktop CI [44953830478](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830478) — **success**. The packaging, Xvfb UI smoke, typecheck/lint/tests and offline video/caption pipeline jobs passed.
- **Known limits:** the preview animates transcript groups but is not synchronized with live video playback. Export supports only Static and Karaoke Fill; other effects are preview-only, not falsely claimed as rendered in MP4. Caption preview/native overlay parity and physical-device appearance still require visual acceptance.
- **Next page:** Jobs only. Do not repeat Create, Review, Clip Editor or Caption Studio.
