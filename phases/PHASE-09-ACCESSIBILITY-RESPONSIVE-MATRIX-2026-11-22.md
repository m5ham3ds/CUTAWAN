# Phase 9 — Accessibility and responsive UI matrix (in progress)

**Started:** 2026-11-22  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted first-slice source SHA:** `deecbd57744b2f06e6d989cec55cdd2f3dc70f3b`

## First automated slice completed

- Compact HomeShell top-bar icon action targets increased from 40x40dp to 48x48dp without changing icon glyphs, callbacks or navigation behavior.
- Bottom navigation covers all five real destinations: Dashboard, Create, Projects/Jobs, Review and Captions.
- Widget tests assert semantic labels, button roles, tap actions, selected state and minimum 48dp height for each destination at 320dp in both RTL and LTR and in light and dark Material 3 themes.
- Compact top-bar widget test asserts all three visible actions are 48x48dp, have Arabic tooltip labels and invoke their callbacks.

## Corrections during acceptance

1. Android run 287 caught obsolete Flutter semantics test APIs (`SemanticsFlag`, `SemanticsAction` use and deprecated `hasFlag`); assertions moved to `SemanticsNode.getSemanticsData()`, `flagsCollection` and action bit data.
2. Android run 288 then caught a test-only resource leak: `SemanticsHandle` remained active at test completion. The test now calls `dispose()` explicitly after all four theme/direction combinations.
3. These were test defects; no navigation production behavior was altered to conceal them.

## Acceptance evidence

- Android run [45036283358](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283358), run 289, SHA `deecbd57744b2f06e6d989cec55cdd2f3dc70f3b` — **success**.
- Dart format and `flutter analyze --fatal-infos`: passed.
- Flutter unit/widget suite: **174/174 passed**.
- ARM64 debug APK build: passed.
- ABI verification: exactly `arm64-v8a`; duplicate-native-library check passed.
- APK artifact [`cutawan-mobile-arm64-debug`, ID 14760086606](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283358/artifacts/14760086606): 59,998,882 bytes; ZIP SHA-256 `d74b241347bad571eed7dc0431c5ec228f526d0a1fea58b81836e00481368de4`.
- Coverage artifact [ID 14760176118](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283358/artifacts/14760176118): 17,311 bytes.
- Root/desktop CI [run 45036283366](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283366), run 333 — **success** across checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon packaging.

## Remaining acceptance gates

- Increased system text scale, long labels and no clipping/overlap.
- Focus traversal, keyboard activation and visible focus state.
- Landscape layout and Android safe-area/system inset behavior.
- Golden comparison for light/dark and RTL/LTR at 320dp.
- Physical handset UI review remains separate from emulator/widget test evidence.

**Decision:** accept the first automated 48dp/semantics slice. Continue Phase 9 accessibility and responsive acceptance; do not mark the whole matrix or Phase 9 complete yet.

## Four-page responsive acceptance slice — 2026-11-22

- Dashboard, Settings, Models Center and Device Diagnostics responsive presentation passed on source SHA `eabc20e3c7494a2030668bcac35a177881821e3b`.
- Test matrix includes 320dp/RTL/light/200% text, 390dp/LTR/dark/150% text and 720dp/RTL/dark/normal text for Dashboard, Settings and Models Center; Diagnostics is exercised at 320dp with 200% text and lazy-list scrolling.
- Dashboard/Settings route callbacks and existing model/diagnostic data-contract tests remain in the 183-test suite.
- A real layout defect was caught and fixed: the Settings appearance ListTile's trailing Chip overflowed at 320dp/200% text. The tile now keeps the system-theme explanation in its subtitle without a no-op control.
- Models Center layout tests inject immediate local-model availability results and do not touch disk; production continues to validate Whisper catalog files and Qwen size/SHA-256 before treating them as installed.
- Diagnostics uses stable evidence labels and makes it explicit that baseline collection is not execution of physical field tests.
- Android run [45043179789](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789), run 296 — **success**, **183/183 tests**, strict analysis, ARM64 APK, ABI and duplicate-library checks passed.
- APK artifact [14763285423](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789/artifacts/14763285423): 60,020,680 bytes; ZIP SHA-256 `8954f75e5b9e81f611cc52c233b04067b5be81983113d7d14d0250b1c8200308`.
- CI [45043179788](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179788), run 341 — success.

## Resolved in the 2026-11-23 Dashboard/Settings follow-up

- Dashboard storage usage is wired to `HomeShell.storageUsageBytes`. The card exposes loading, measured usage, error and refresh states.
- Dashboard recent-project actions preserve the selected project ID. Review prioritizes that project and labels it as selected from Dashboard.
- Settings persists theme mode and reduced-motion preferences. Widget interaction uses an in-memory store; the standalone disk-backed store test verifies the persistence round-trip.
- The Settings widget-test hang was traced to filesystem temp-directory creation inside `testWidgets`. The diagnostic run recorded the blocking `Directory.systemTemp.createTemp` operation. Disk I/O now remains in the separate store test.
- The 320dp/RTL/200%-text matrix then exposed a 77px horizontal RenderFlex overflow. The AppBar title now ellipsizes and the appearance-row title is flexible.
- Source SHA `5f0a352417e48a54b9d59b14811563743754f576`; Android run [45086449500](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45086449500), run 312 — **success**, **188/188 tests**, format, strict analysis, ARM64 APK, ABI/native duplicate check and APK upload passed.
- APK artifact [14779307711](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45086449500/artifacts/14779307711): 60,029,566 bytes; archive SHA-256 `cf48374bfe7020f6cfd7c666e6e9673ea50d9b47f39b2dbc2c925629797bebb4`. Exactly `arm64-v8a`, 10 unique native libraries, GGML libraries present, no duplicate basenames.
- CI [45086449397](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45086449397), run 359 — **success**.

## Remaining matrix / page work

- Page golden comparisons for light/dark and RTL/LTR at compact/regular/wide widths.
- Page-level focus traversal, visible-focus state and keyboard activation for feature-specific controls.
- Per-page landscape and Android safe-area/system-inset acceptance.
- Physical handset UI review remains separate from emulator/widget/golden test evidence.

**Decision:** accept Dashboard storage/quick-resume and Settings persistence as automated responsive slices. Phase 9 and the full accessibility matrix remain in progress.


## Page-specific keyboard activation slice — 2026-11-23

- Added four page-level keyboard tests in `page_keyboard_accessibility_test.dart`: Dashboard create-project, Settings diagnostics route, Models Center local-model refresh, and Device Diagnostics refresh.
- Each test focuses the intended control, confirms it owns primary focus, sends Enter, and asserts the actual callback/service action. Fakes are injected for the credential and diagnostics dependencies.
- Android run [45087696784](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45087696784), run 315, SHA `e3fde4acc0f071f8eaf38e221031e0bd0644b004` — **success**, **192/192 tests**, format, strict analysis, ARM64 APK, ARM64-only ABI and duplicate-library checks, and APK upload all passed.
- APK artifact [14780067920](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45087696784/artifacts/14780067920): 60,028,683 bytes; SHA-256 `b316544128f52c01da425ad7db897248a0a2bbbc0bee06df42b9ddf97feb54d8`. Exactly `arm64-v8a`, 10 unique native libraries, GGML runtime present, no duplicate basenames.
- Root/desktop CI [45087696844](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45087696844), run 362 — **success**.

**Scope limit:** these tests prove Enter activation after explicitly requesting focus. They do not prove correct Tab order or visible-focus styling for every page control.

## Remaining matrix / page work

- Page golden comparisons for light/dark and RTL/LTR at compact/regular/wide widths.
- Full page-level Tab-order traversal and visible-focus state for interactive controls.
- Per-page landscape and Android safe-area/system-inset acceptance.
- Physical handset UI review remains separate from emulator/widget/golden test evidence.

**Decision:** accept the four page-specific Enter-activation checks as an automated slice. The complete accessibility matrix and Phase 9 remain in progress.


## Saved page golden baseline slice — 2026-11-23

- 24 Flutter golden PNGs are committed under `mobile/flutter_app/test/goldens/pages/`: four screens × six compact/regular/wide, RTL/LTR, light/dark variants.
- Capture run [45089102964](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089102964), run 318 — **196/196 tests passed**; images were committed at `18c802456498ac7185d975f68a1d36505c7484da`.
- Normal comparison run [45089841288](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089841288), run 319, used the saved images without `--update-goldens` and passed **196/196 tests**.
- APK artifact [14780344052](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089841288/artifacts/14780344052): 60,029,458 bytes; SHA-256 `7b0a49eae512ee4b163efdc38859d9ae71d606b543792b486582ad71c18ffcb0`. Exactly `arm64-v8a`, 10 unique native libraries, GGML present, no duplicate basenames.
- CI [45089841836](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089841836), run 366 — **success**.

**Scope limit:** these are deterministic widget rendering baselines, not physical handset screenshots. Full Tab-order/visible-focus, landscape/safe-area and handset validation remain open.


## Natural Tab traversal and focused semantics — 2026-11-23

- Four new tests send real Tab events (no programmatic `requestFocus()`) and wait for a representative action on each screen to expose focused semantics.
- Dashboard Settings action: `IconButton` found by tooltip. Settings diagnostics action: its clickable `ListTile`. Models Center: local-model refresh `TextButton`. Device Diagnostics: refresh `IconButton`.
- Each test verifies `SemanticsFlag.isFocused` on the target and `FocusManager.instance.highlightMode == FocusHighlightMode.traditional`.
- Android run [45093466824](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45093466824), run 325, SHA `f4690770873e9362cab5e4c45f7d2649ad1c735f` — **success**, **200/200 tests**, format, strict analysis, ARM64 APK, ARM64-only and 10-unique-native-library checks, and APK upload passed.
- APK artifact [14782207705](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45093466824/artifacts/14782207705): 60,027,476 bytes; SHA-256 `6947d92f8022ff3299098a8dab12aef70698fd8534ca941260db1e9e76c2e304`. Exactly `arm64-v8a`, GGML present, no duplicate native basenames.
- CI [45093466603](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45093466603), run 372 — **success**.

**Scope limit:** the four tests prove representative Tab reachability and focused semantics, not the complete traversal sequence of every interactive control or measured focus-ring contrast.

## Remaining matrix / page work

- Per-page landscape and safe-area/system-inset tests at compact and wide sizes with RTL/LTR and enlarged text.
- Complete per-control Tab-order inventory and visual focus-indicator review.
- Physical handset visual/accessibility review remains separate from emulator/widget/golden test evidence.

**Decision:** accept this representative Tab/focused-semantics slice. Phase 9 and the full accessibility matrix remain in progress.
