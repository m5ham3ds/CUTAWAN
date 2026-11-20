# CUTAWAN Mobile — Native Flutter Android App

This is the primary CUTAWAN product target: a native Android phone application built with Flutter and Dart. All current product UI work, feature development, redesign, tests, and Android releases must be implemented here.

The Electron desktop application at the repository root is legacy/reference code. It is not the mobile application and must not be used as the implementation target for mobile requests. CUTAWAN Mobile is not a WebView wrapper.

## Product implementation rules

- Flutter/Dart is the application foundation.
- Native Android integrations use platform channels and Android APIs from `tooling/android/MainActivity.kt`.
- Keep presentation, domain models, repositories, and processing services separate.
- Every interactive control must have a real function and corresponding loading/error/cancel/disabled feedback.
- Preserve project data, local-first storage, privacy and cloud-consent rules.
- Arabic RTL and English LTR must both work.
- Layouts must adapt to 320dp phones, larger devices, safe areas, keyboard insets, text scaling, and landscape.
- Use real motion for navigation, screen entrance, progress, selection, editing and caption preview; motion must remain purposeful and accessible.
- Use open-source libraries and design references only after checking compatibility and licenses. Record any reused source, license, and modifications.

## Current implemented scope

### Phase 1 — Flutter application shell

- Native Flutter navigation for source input, jobs/projects, review, Caption Studio, and the AI Model Center.
- Versioned project and media domain models shared through JSON.
- Clip count, target duration, aspect ratio, resolution preference, caption and speaker-tracking controls.
- The 12 existing Cutawan caption visual presets and an independent animation catalogue.
- Warm dark Material 3 interface with Arabic labels and explicit status for capabilities that are not connected.

### Phase 2 — Local and direct-video source ingestion

- Versioned project JSON schema (schemaVersion 1), schema-0 migration, and rejection of unsupported future schemas.
- Local media import through Android Storage Access Framework (ACTION_OPEN_DOCUMENT), with persistable read access to content URIs.
- Direct HTTP/HTTPS video-file downloads with byte progress and user cancellation.
- Redirect validation, HTTPS downgrade rejection, social-platform host blocking, video MIME/extension validation, an 8 GiB download ceiling, and a 64 MiB free-space reserve.
- Free-space preflight plus periodic checks during larger downloads; incomplete temporary files are removed on cancel/failure and cleaned on the next run.
- Android metadata inspection: display name, MIME type, size, duration, dimensions, and rotation.
- Atomic local JSON project persistence under the application-support directory.
- Persisted clip preferences and prepared/cancellable job records.
- Jobs and Review read saved projects; Review can re-probe the source URI after app restart.
- Storage usage for app-managed downloads is displayed in Jobs. Users can remove a downloaded file with its project; removing a SAF project releases its saved read grant when no other project uses that source.

Direct URL import accepts a direct video-file endpoint only. It does not extract media from social platform pages or bypass DRM, authentication barriers, or access controls. An authorized direct CDN/file URL is required.

## Known limitations — do not describe as completed

The mobile app has real source import, local project persistence, job records, caption configuration and model-management foundations. However, the following still require implementation and acceptance:

- Full end-to-end pipeline integration on device for transcription, candidate discovery, reframing, caption render, and export.
- Complete interactive clip editor with trim handles, crop/focus controls, timeline and preview.
- Full screen-by-screen production redesign and navigation architecture.
- Persistent background processing and reliable resume after Android process death.
- Physical device tests for SAF permission persistence, media metadata and playback, model installation, memory/thermal behavior and export.
- Full bilingual/RTL, accessibility, text scale, narrow-width, keyboard and landscape golden/widget test matrix.

Never claim these functions are complete until implemented and tested.

## Build and validation

Run from this directory:

```bash
bash tooling/generate_android_platform.sh
dart format --output=none --set-exit-if-changed lib test
flutter analyze --fatal-infos
flutter test --reporter expanded
flutter build apk --debug --target-platform android-arm64
```

CI uses Flutter 3.47.6, generates the Android project, compiles the Kotlin bridge, analyzes and tests Dart code, builds an ARM64 APK and uploads the artifact.

## Physical Android acceptance

Install the generated APK and validate:
1. Local video selection via Android document picker.
2. Authorized direct video URL download, progress, cancellation and cleanup.
3. Close/force-stop/reopen and verify persisted source access and project metadata.
4. Run each implemented processing stage and validate its output, cancellation and recovery.
5. Verify Arabic RTL, English LTR, 320dp width, keyboard, safe areas and landscape.
6. Verify real device memory, thermal and background lifecycle behavior.

A passing CI build alone is not physical-device acceptance.
