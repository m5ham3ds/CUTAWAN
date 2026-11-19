# Cutawan Mobile (Flutter)

This folder is the native Android application target. The desktop Electron app at the repository root remains unchanged.

## Current scope

Phase 1 shell only:

- Flutter navigation for Create, Projects, Caption Studio, and AI Model Center.
- Initial clip-count, target-duration, aspect-ratio, and caption toggle controls.
- The 12 existing visual caption presets ported as data.
- A separate proposed animation catalogue.
- No video download, transcription, local inference, or export engine is connected yet. UI actions explicitly state that these integrations are pending.

## Generate the Android platform folder

The Flutter SDK generates Android Gradle boilerplate for its own installed version. From this directory run:

```bash
flutter create --platforms=android --org com.m5ham3ds --project-name cutawan_mobile .
flutter pub get
flutter analyze
flutter test
flutter build apk --debug --target-platform android-arm64
```

The project targets Flutter 3.47.6 for the initial baseline. The CI workflow uses the same version to keep local and automated builds aligned.

## Next

1. Add the versioned project/job contract and local file import.
2. Add the Android media probe and resumable job state.
3. Integrate whisper.cpp and model management.
4. Add candidate discovery and ranking.
5. Add speaker-aware reframing and the native renderer.
6. Connect Caption Studio preview and export animations.
