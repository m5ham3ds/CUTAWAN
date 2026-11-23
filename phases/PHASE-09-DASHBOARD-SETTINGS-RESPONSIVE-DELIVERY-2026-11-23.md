# Phase 9 — Dashboard, Settings and responsive follow-up

**Date:** 2026-11-23  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `5f0a352417e48a54b9d59b14811563743754f576`

## Delivered and verified

- Dashboard reads the `HomeShell.storageUsageBytes` provider and presents a storage card with loading, measured value, read failure and refresh states.
- Dashboard recent-project taps retain the selected project identity. `HomeShell` passes `initialProjectId` into Review, and Review puts the requested project first and labels it as the project chosen from Dashboard.
- Settings theme-mode and reduce-motion controls use `AppPreferencesStore` and are applied by the application. The widget test verifies state changes with an in-memory store; the standalone service test verifies actual disk persistence after store recreation.
- Settings responsive layout passed compact 320dp RTL at 200% text, 390dp LTR at 150%, and 720dp RTL normal scale. Its AppBar title is single-line/ellipsized and the appearance-row title uses flexible width to prevent horizontal overflow.

## Failure diagnosis and correction history

- Android 304 and 305 timed out in the three Settings widget tests after 10 minutes. Replacing `pumpAndSettle` with bounded pumps did not fix the hang.
- Diagnostic Android run 309 showed each affected test stopped at `Directory.systemTemp.createTemp`, before the preferences store or widget tree was created. This isolated the block to filesystem I/O inside `testWidgets`.
- The Settings UI tests now use `AppPreferencesStore.inMemory()`; temporary directories and file reads/writes remain in `app_preferences_store_test.dart`, outside WidgetTest's FakeAsync environment. That standalone test still proves theme and reduced-motion persistence across store recreation.
- Android 311 then exposed a separate layout issue: `RenderFlex overflowed by 77 pixels on the right` at 320dp/RTL/200% text. The final fix makes the AppBar title ellipsize and wraps the appearance title in `Expanded`.

## Test and build evidence

- Android run [45086449500](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45086449500), run 312, SHA `5f0a352417e48a54b9d59b14811563743754f576` — **success**.
- Dart format: passed.
- `flutter analyze --fatal-infos`: passed.
- Flutter unit/widget suite: **188/188 passed**.
- ARM64 debug APK build: passed and uploaded.
- ABI/package check: exactly `arm64-v8a`, 10 unique native libraries, GGML runtime libraries present, no duplicate basenames.
- APK artifact [14779307711](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45086449500/artifacts/14779307711): 60,029,566 bytes; archive SHA-256 `cf48374bfe7020f6cfd7c666e6e9673ea50d9b47f39b2dbc2c925629797bebb4`.
- Coverage artifact [14779431913](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45086449500/artifacts/14779431913): 18,177 bytes; archive SHA-256 `43112cc7d429c245e09ef42ccc4c427280bf169d774403d2d293bae9f5abc50f`.
- Root/desktop CI [45086449397](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45086449397), run 359 — **success** across checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon packaging.

## Still open

- Page-level goldens for Dashboard, Settings, Models Center and Device Diagnostics across compact/regular/wide widths, light/dark themes and RTL/LTR.
- Page-specific focus traversal/visible focus, keyboard activation, landscape and safe-area/inset coverage.
- Physical handset visual review. Automated widget tests and CI screenshots are not physical-device acceptance.

**Decision:** accept this Dashboard/Settings responsive slice. Phase 9 and Phase 10 remain in progress.
