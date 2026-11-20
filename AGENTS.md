# AGENTS.md

## Product direction — authoritative

**CUTAWAN is being developed as a native Android phone application. Flutter/Dart is the primary product implementation.** The target for current product work, UI redesign, feature development, acceptance tests, and release builds is `mobile/flutter_app/`.

- Do not implement requested mobile product features in the root Electron/React desktop application.
- Do not redesign or treat `src/renderer/**` as the mobile application.
- The root Electron application is legacy/reference desktop code and must remain untouched unless the user explicitly requests desktop work.
- Native Android integration belongs in `mobile/flutter_app/tooling/android/MainActivity.kt` and its Flutter MethodChannel contracts.
- Use Flutter Material 3 widgets and native Android APIs; do not wrap the desktop app in a WebView.
- Keep business/domain logic in Flutter domain and service layers. UI widgets must call real services/repositories; never ship decorative buttons with no action.
- Preserve Arabic RTL and English LTR behavior, adaptive phone layouts, accessibility semantics, lifecycle safety, local-first privacy, and explicit cloud consent.

## Mobile development environment

- Flutter project: `mobile/flutter_app/`
- Flutter SDK in CI: 3.47.6
- Generate Android project before building: `bash tooling/generate_android_platform.sh` from `mobile/flutter_app`.
- Validate with:
  - `dart format --output=none --set-exit-if-changed lib test`
  - `flutter analyze --fatal-infos`
  - `flutter test --reporter expanded`
  - `flutter build apk --debug --target-platform android-arm64`
- Use ARM64 Android builds as the primary release target unless the user requests otherwise.

## Mobile architecture rules

- Keep UI presentation separate from domain models, repositories, and processing services.
- Break large screens into feature-scoped widgets and small files; avoid adding more unrelated code to the root shell.
- Every visible action must be connected to a real callback/service, with loading, success, error, cancel, and disabled states where appropriate.
- Avoid placeholder functionality presented as working. Clearly label capabilities that are not yet connected.
- Preserve existing saved project schemas and migrate data safely; never silently discard project data.
- Design every screen for phone widths including 320dp, safe areas, keyboard insets, portrait/landscape, and font scaling.
- Add animation deliberately: navigation transitions, page entrance, interactive state changes, progress feedback, and caption previews. Respect reduced-motion/accessibility expectations.
- Add widget tests for actual state changes and user flows, not only widget presence.
- Do not claim physical-device acceptance based only on CI.

## Repository context

The root Electron + Vite + React + TypeScript app is still present and has its own scripts. It is not the active target for the requested native mobile redesign. Avoid modifying root desktop files while working on Flutter unless explicitly instructed.
