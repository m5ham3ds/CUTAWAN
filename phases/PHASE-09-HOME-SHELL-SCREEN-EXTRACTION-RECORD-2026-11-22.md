# Phase 9 — HomeShell feature-screen extraction record

**Date:** 2026-11-22  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `d30695cf38c7fb1dd009427c3da8c029921e4a17`

## Scope completed

- Extracted `CaptionStudioPage` from `part of '../home_shell.dart'` into `lib/screens/features/caption_studio_page.dart`.
- Replaced the private `_Eyebrow`, `_Panel`, `_EmptyState` and `_colorFromHex` dependencies with feature-safe public shared primitives and a page-local color parser.
- Removed `part 'home_shell/caption_studio_page.dart'` and `part 'home_shell/shared_widgets.dart'` from `home_shell.dart`; deleted the obsolete shared `part` file.
- Updated the Caption Studio project-selection and timed-preview tests to import the page directly, not through `HomeShell`.
- The HomeShell screen list is now assembled from independently importable feature libraries. The shell retains composition, project-list state, top-level navigation and routes; it does not reimplement page or media-processing behavior.
- Previously accepted Create, Jobs, Review, Models, Clip Editor, Dashboard and Settings modules remain in their existing feature-scoped files.

## Corrections during acceptance

1. Android run 281 exposed an old `caption_timed_preview_test.dart` import that still referenced `HomeShell`, plus an unnecessary `foundation.dart` import in the shell. Both were corrected.
2. Android run 283 then showed that the standalone Caption Studio itself needs `foundation.dart` for `ValueListenable` and `mapEquals`. That import was restored only in the feature page; it remains absent from `HomeShell`.
3. The corrected source passed Android run 284 on this accepted SHA.

These intermediate failures are resolved; do not repeat the extraction or revert the feature page's required foundation import.

## Acceptance evidence

- Android workflow [run 45030858232](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45030858232), run 284, SHA `d30695cf38c7fb1dd009427c3da8c029921e4a17` — **success**.
- Dart format: passed.
- `flutter analyze --fatal-infos`: passed with `No issues found!`.
- Flutter unit/widget suite: **167/167 passed**.
- ARM64 debug APK build: passed.
- ABI verification: exactly `arm64-v8a`; duplicate-native-library check passed.
- APK artifact [`cutawan-mobile-arm64-debug`, ID 14757722064](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45030858232/artifacts/14757722064): artifact ZIP size 60,001,970 bytes; SHA-256 `ab80c9c52604673e8da14a106cc1168a143edf3b3e5102c01f50ec1ab7a0f50a`.
- Coverage artifact [ID 14757249297](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45030858232/artifacts/14757249297): 16,962 bytes.
- Root/desktop CI [run 45030858228](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45030858228), run 328 — **success** for checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon packaging.

## Remaining limits

- This record accepts the automated page-extraction slice only. It does not accept the whole of Phase 9.
- Export gallery/delivery actions, accessibility/golden/RTL/keyboard/landscape/safe-area acceptance and physical-device UI checks remain open.
- Phase 8 physical-device background render/process-death/codec/thermal acceptance and Phase 10 quality/security/performance acceptance remain open. CI and an ARM64 APK are not substitutes for handset evidence.

**Decision:** accept HomeShell page extraction. Proceed directly to Phase 9 export gallery/delivery; preserve the completed feature pages and their tests.
