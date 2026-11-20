# Cutawan Mobile (Flutter)

This directory contains the native Android app. The desktop Electron app at the repository root remains intact and is not wrapped in a WebView.

## Implemented scope

### Phase 1 — Flutter application shell

- Native Flutter navigation for source import, jobs/projects, review, Caption Studio, and the AI Model Center.
- Clip count, duration band, aspect ratio, captions, and speaker-tracking preferences.
- The 12 existing Cutawan caption visual presets and an independent animation catalogue.
- Warm dark Material 3 interface with Arabic labels and explicit status for capabilities that are not connected.

### Phase 2 — Project contract and local media

- Versioned project JSON schema (schemaVersion 1) with a migration path from schema 0 and rejection of unsupported future schemas.
- Android Storage Access Framework video selection using ACTION_OPEN_DOCUMENT.
- Persisted read permission for the selected content URI; no broad storage permission and no mandatory full-file copy.
- Android media metadata probe: display name, MIME type, size when available, duration, dimensions, and rotation.
- Atomic local JSON project persistence under the app support directory.
- Saved clip preferences and prepared/cancellable job records.
- Jobs and Review screens read saved projects; Review can re-probe the source URI and refresh stored metadata.

The project/job state is real and persistent. A prepared job is only a saved record: there is no AI analysis, downloading, transcription, clipping, or rendering engine connected yet.

## Generate the Android platform folder

The Flutter SDK creates Gradle/Kotlin boilerplate for its installed version. The generation script then installs the repository's native SAF/media bridge:

```bash
bash tooling/generate_android_platform.sh
flutter analyze --fatal-infos
flutter test --reporter expanded
flutter build apk --debug --target-platform android-arm64
```

The CI workflow uses Flutter 3.47.6. The generated android/ directory is not committed; the native MainActivity source of truth is tooling/android/MainActivity.kt.

## Automated coverage

Tests cover project JSON round-trip, schema migration and future-version rejection, media metadata validation, job-state validation, repository save/list/load/delete/cancel, the Flutter-to-Android media channel contract, and the import/reopen/cancel/re-probe widget flow.

GitHub Actions additionally generates the Android project, compiles the Kotlin bridge, analyzes Flutter code, runs tests, builds an ARM64 debug APK, and uploads the artifact.

## Acceptance still requiring a physical Android device

Install the generated APK, import a real local MP4, close the app completely, reopen it, and use Review → Recheck access and metadata. The persisted SAF grant and MediaMetadataRetriever path are compiled in CI, but a real document-provider round-trip across process death has not been executed on a physical device in this session.

The mobile project does not claim physical-device acceptance, media playback, AI inference, or video export until those tests and engines exist.
