# Phase 9 — Landscape layout and simulated safe-area delivery

**Date:** 2026-11-23  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `91429dce5f4917b75072f54e6b79b231c17649e2`

## Delivered

Added `mobile/flutter_app/test/page_landscape_safe_area_test.dart` with one widget test for each of Dashboard, Settings, Models Center and Device Diagnostics. Each case runs in two landscape variants:

- 720×320, RTL, light theme, text scale 1.5×, insets 28dp left/right, 12dp top and 20dp bottom.
- 844×390, LTR, dark theme, text scale 1.0×, insets 36dp left/right, 10dp top and 24dp bottom.

The harness supplies the simulated insets through both `MediaQuery.padding` and `viewPadding`, wraps each page in `SafeArea`, and checks page viewports plus representative actions against the safe rectangle. All four tests also assert no Flutter layout exception/overflow.

## Test corrections

- Initial analysis caught a test-only compile error: `CutawanTheme.light/dark()` were invoked inside a `const` list. The cases are a `final` list because themes are constructed at runtime.
- The first Settings layout attempt located a lazy diagnostics ListTile before it had been built; the correction uses the AppBar title and settings-list viewport as stable geometry assertions. This avoids an artificial drag/scroll failure and leaves production UI behavior unchanged.
- No production screen changes were needed for this automated slice.

## Android and desktop evidence

- Android run [45096664414](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45096664414), run 330, source SHA `91429dce5f4917b75072f54e6b79b231c17649e2` — **success**.
- Format and `flutter analyze --fatal-infos`: passed.
- Flutter unit/widget suite: **204/204 passed**.
- ARM64 APK built and uploaded; packaging verification confirms exactly `arm64-v8a`, 10 unique native libraries including GGML and no duplicate basenames.
- APK artifact [14783514048](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45096664414/artifacts/14783514048): 60,028,674 bytes; archive SHA-256 `54b52d795659ac3f699344c63ad77c81ff21fdc60ccd5dbab76cb49e45f43023`.
- Coverage artifact [14784045542](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45096664414/artifacts/14784045542): 18,526 bytes; SHA-256 `1d533fc46f7cd9241b5bc796f9765cea87a7ae7e069015a33e59e6348508e896`.
- Root/desktop CI [45096664356](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45096664356), run 377 — **success** across checks, UI smoke, offline pipeline and Apple Silicon packaging.

## Remaining acceptance

- Full per-control Tab-order inventory and visual focus-indicator contrast/pixel review.
- Physical ARM64 handset review of landscape, real cutouts, gesture navigation/system bars, edge-to-edge and OEM behavior. The widget harness models these insets; it does not constitute physical-device evidence.

**Decision:** accept the four-page landscape/simulated-safe-area widget slice. Phase 9 and Phase 10 remain in progress.
