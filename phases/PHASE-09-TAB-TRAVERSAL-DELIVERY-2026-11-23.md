# Phase 9 — Natural Tab traversal and focused-semantics delivery

**Date:** 2026-11-23  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `f4690770873e9362cab5e4c45f7d2649ad1c735f`

## Delivered

Added four tests to `mobile/flutter_app/test/page_keyboard_accessibility_test.dart` that send native Flutter test Tab key events from the initial page focus state and verify focused semantics on a representative action:

- **Dashboard:** Settings `IconButton`.
- **Settings:** Android diagnostics `ListTile`.
- **Models Center:** local-model refresh `TextButton`.
- **Device Diagnostics:** refresh `IconButton`.

The helper checks that the target publishes `SemanticsFlag.isFocused` after Tab traversal and that Flutter enters `FocusHighlightMode.traditional`. Unlike the earlier Enter tests, these four tests do not request focus programmatically.

## Diagnosed test-harness failures and corrections

- The first version called `Focus.of()` on the target child contexts. Those contexts were not necessarily descendants of the Material control's internal `Focus` node, so the test failed before sending Tab. The helper now watches the target's focused Semantics state instead of assuming a particular internal widget tree.
- The Models test initially targeted the local-mode label rather than the actual local-model refresh action. It now targets the `TextButton` that rechecks the installed local models.
- Semantics handles are explicitly disposed inside each test, preventing a leaked test handle when assertions exit early.
- One strict-analysis warning caused by the deprecated `SemanticsData.hasFlag` API was fixed by moving to `flagsCollection.isFocused.toBoolOrNull()`; its now-unused semantics import was removed.

## Android and desktop evidence

- Android run [45093466824](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45093466824), run 325, source SHA `f4690770873e9362cab5e4c45f7d2649ad1c735f` — **success**.
- Dart Format and `flutter analyze --fatal-infos`: passed.
- Flutter unit/widget suite: **200/200 passed**, including the four Tab traversal/focused-semantics tests and the previous 24 golden comparisons.
- ARM64 debug APK built and uploaded.
- Packaging verification: exactly `arm64-v8a`, 10 unique native libraries, GGML runtime present, no duplicate basenames.
- APK artifact [14782207705](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45093466824/artifacts/14782207705): 60,027,476 bytes; archive SHA-256 `6947d92f8022ff3299098a8dab12aef70698fd8534ca941260db1e9e76c2e304`.
- Coverage artifact [14782512316](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45093466824/artifacts/14782512316): 18,319 bytes; archive SHA-256 `ee958ac46288236376369faf22a874b9b2c82439cb4c754fc910e3f7093f994c`.
- Root/desktop CI [45093466603](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45093466603), run 372 — **success** across all required jobs.

## Scope and remaining acceptance

These checks prove representative natural Tab reachability, Flutter keyboard-highlight mode and focused semantics on one real action per page. They do not inventory every interactive control's exact Tab order or visually measure focus-ring contrast/pixels.

- Full per-control Tab-stop inventory and focus-indicator visual/contrast review remain open.
- Per-page landscape and Android safe-area/system-inset checks remain open.
- Physical ARM64 handset visual/accessibility acceptance remains open.

**Decision:** accept this representative natural Tab/focused-semantics slice. Phase 9 and Phase 10 remain in progress.
