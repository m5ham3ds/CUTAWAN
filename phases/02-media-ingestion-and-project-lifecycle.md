# Phase 2 — Media ingestion, downloads and durable project lifecycle

**Current state:** local import, direct video-file download and durable project/job persistence are implemented with automated coverage. Real SAF provider and process-death acceptance remain open.

## Implemented scope

- Versioned project/media contract with schema validation, round-trip serialization, schema-0 migration and rejection of unsupported future schema versions.
- Android Storage Access Framework import through the document picker with a persisted read grant for selected `content://` sources.
- Native media probing records supported source metadata such as display name, MIME type, size, duration, dimensions and rotation.
- Direct HTTP/HTTPS video-file download supports progress and user cancellation. Redirects are revalidated; HTTPS-to-HTTP downgrade, platform-page/social-host URLs, invalid/non-video responses and unsafe private/local destinations are rejected.
- Download size is bounded to 8 GiB and storage preflight preserves a 64 MiB reserve. Partial downloads are deleted on failure/cancellation and stale partials are cleaned on a later run.
- Projects, job state and analysis artifacts are stored in app-private support storage. Project writes use a durable local repository.
- A downloaded media file can be deliberately removed with its project. A persisted SAF grant is released only when no other saved project references that same URI.

## Source map

- `lib/domain/project_contract.dart`, `clip_preferences.dart` — versioned project and source preferences.
- `lib/services/android_video_picker.dart` — Flutter SAF bridge contract.
- `lib/services/direct_video_downloader.dart` — URL validation, streaming, progress, cancellation and cleanup.
- `lib/services/local_project_repository.dart` — durable project, job and artifact records.
- `lib/services/processing_job_service.dart` — job lifecycle operations.
- `tooling/android/MainActivity.kt` — native picker and metadata bridge.

## Automated coverage

- `project_contract_test.dart`, `local_project_repository_test.dart`, `android_video_picker_test.dart`, `direct_video_downloader_test.dart`, `mobile_import_flow_test.dart` and `jobs_workflow_test.dart`.
- Coverage includes schema migration/future-schema rejection, persistence/cancellation/deletion, bridge mapping, redirects, denied URL classes, MIME checks, storage exhaustion, cancellation and partial-file cleanup.

## Limits and required field tests

- Direct URL ingestion accepts a direct video-file endpoint; it is not a social-platform downloader and does not bypass DRM, authentication barriers or access controls.
- Mocked picker channels do not prove a third-party document provider retains read permission after force-stop/relaunch.
- On a physical ARM64 handset, test SAF URI persistence across process death and force-stop, provider-specific metadata behavior, repeat references to one URI, missing/moved source recovery, real network downloads, redirect failures and cleanup.
- Keep storage and source privacy in field reports; do not include personal paths or source filenames.

**Related:** [Phase register](README.md), [Physical Phase 8 checklist](PHASE-08-PHYSICAL-MEDIA-AND-WORKMANAGER-ACCEPTANCE-2026-11-26.md).
