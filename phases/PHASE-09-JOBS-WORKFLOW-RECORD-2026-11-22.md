# Phase 9 — Jobs workflow record

**Date:** 2026-11-22  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `580879b5f29ffcbdbe1d2c06a2fc0136b19f180a`

## Delivered

- Jobs workspace lists persisted projects and presents running, ready, completed and attention counts.
- Status filters cover all, active, completed and attention states; search matches project title, source display name, current stage and job ID.
- Each project card preserves project identity, stage, progress, source metadata and update timestamp.
- The page routes to Review for inspect/resume and exposes persisted cancellation feedback.
- Running jobs cannot be deleted. This is an explicit UI guard; repository deletion is not presented as a way to stop an active render.
- Empty state routes to Create; storage usage and refresh are visible.
- The page uses the existing repository/job contract. It does not claim that rendering continues after Activity/process death, that notifications cancel a live render, or that per-clip retry already exists.

## Acceptance evidence

- Mobile Android run [44963196882](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44963196882), run 261, commit `580879b5f29ffcbdbe1d2c06a2fc0136b19f180a` — success.
- Dart format and `flutter analyze --fatal-infos`: passed.
- Flutter test suite: **157/157 passed**.
- ARM64 debug APK: built and uploaded.
- ABI check: exactly `arm64-v8a`; 10 unique native libraries; no duplicate native-library basenames; required Whisper, llama and GGML libraries present.
- APK artifact: [14730139932](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44963196882/artifacts/14730139932), 59,106,125 bytes; SHA-256 `1d88ab0a23253ed1fe44a0b2de88698baf8924bd8dcf27edc99400d8f888383e`.
- Coverage artifact: [14730412759](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44963196882/artifacts/14730412759).
- Root/desktop CI [44963196902](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44963196902), run 303 — success for desktop checks, UI smoke, offline pipeline and Apple Silicon package validation.

## Corrections made during acceptance

- Strict analysis exposed an unused shared status-label helper; Jobs now uses the shared helper.
- Widget tests initially assumed lazily-built list children were immediately mounted; test viewports/scrolling were corrected.
- The redesigned Jobs page no longer uses an old import status string; the end-to-end assertion now verifies the current prepared state and action copy.
- The active-job cancel test initially tapped a button below the viewport; the test now scrolls it into view before tapping.
- Deleting a running job was found to be enabled; the action is now disabled for a running job.

## Remaining scope — not accepted by this record

- Durable foreground/background rendering and notification-driven cancellation.
- Reconstructing a live Media3 render after process death instead of cancelling the Activity-owned Transformer.
- Targeted per-clip retry and export/cleanup management UI.
- Physical ARM64 device validation for lifecycle, codec, battery, memory and thermal behavior.

**Decision:** Jobs is accepted as a UI workflow slice. Continue with Phase 8's durable rendering work; do not repeat the accepted Jobs UI or earlier pages.


## Native WorkManager cancellation integration — 2026-11-22

A later implementation on main adds actual project-scoped background render cancellation without changing the accepted Jobs page layout:

- `JobsPage._cancel` persists the repository cancellation request, then calls `ProcessingJobService.cancelBackgroundRenderForProject(project.id)`.
- The Android method channel validates project identity and cancels WorkManager work by the matching project tag, including queued and running render workers.
- `NativeRenderWorker` is tagged per project and emits foreground notification progress with its own cancel action.
- This bridge passed the latest Mobile Android run [44970800438](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438), run 267, commit `645d2d349ecc9fe916b02a219a3ce0139f22b64a`: **160/160 Flutter tests**, format, strict analysis, ARM64 build, ABI/native uniqueness checks and artifact upload all succeeded.
- APK artifact [14733448407](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733448407). Full physical-device notification/cancellation behavior remains pending.

This update adds a native execution path to the previously accepted Jobs UI slice; it does not mark per-clip retry/output management or Phase 8 physical acceptance complete.
