# Cutawan Mobile (Flutter)

This directory contains the native Android app. The desktop Electron app at the repository root remains intact and is not wrapped in a WebView.

## Implemented scope

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

Direct URL import accepts a direct video-file endpoint only. It does not extract media from YouTube, TikTok, Instagram, Facebook, or other platform pages, and does not bypass DRM, authentication barriers, or access controls. An authorized direct CDN/file URL is required.

A prepared job is a durable project record, not a claim that AI analysis has started. URL ingestion and source storage are implemented; transcription, candidate discovery, reframing, caption rendering, and export engines are not connected yet.

## Generate the Android platform folder

The Flutter SDK creates Gradle/Kotlin boilerplate for its installed version. The generation script then installs the repository's native SAF, storage, and media-probe bridge:

```bash
bash tooling/generate_android_platform.sh
flutter analyze --fatal-infos
flutter test --reporter expanded
flutter build apk --debug --target-platform android-arm64
```

The CI workflow uses Flutter 3.47.6. The generated android/ directory is not committed; the native MainActivity source of truth is tooling/android/MainActivity.kt.

## Automated coverage

Tests cover project JSON round-trip, schema migration/future-version rejection, source metadata validation, persistent repository save/list/load/delete/cancel, download progress, redirects, unsafe redirect blocking, social-platform/private-IP rejection, HTML response rejection, insufficient storage, cancellation and partial-file cleanup, storage accounting/deletion, the Android MethodChannel contract, and the app import/reopen/cancel/re-probe flow.

GitHub Actions generates the Android project, compiles the Kotlin bridge, formats and analyzes Flutter code, runs tests, builds an ARM64 debug APK, and uploads the artifact.

## Acceptance still requiring a physical Android device

Install the generated APK, test both (1) selecting a local MP4 from the Android document picker and (2) downloading an authorized direct video URL, then force-stop/reopen the app and recheck the media metadata in Review. The SAF grant and MediaMetadataRetriever path are compiled in CI, but a real OEM document-provider and storage round-trip across process death has not been executed on a physical device in this session.

The mobile project does not claim physical-device acceptance, AI inference, actual clip generation, animated caption rendering, or video export until those tests and engines exist.
