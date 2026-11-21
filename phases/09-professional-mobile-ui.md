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
