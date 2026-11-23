# Phase 9 — Responsive page golden delivery

**Date:** 2026-11-23  
**Repository:** `m5ham3ds/CUTAWAN`  
**Golden commit:** `18c802456498ac7185d975f68a1d36505c7484da`

## Delivered

Twenty-four Flutter-rendered PNG baselines are stored in `mobile/flutter_app/test/goldens/pages/`:

- Dashboard: six variants.
- Settings: six variants.
- Models Center: six variants.
- Device Diagnostics: six variants.

The variants cover compact (320dp), regular (390dp), and wide (720dp); RTL and LTR; light and dark. Large text is used for compact/regular cases.

## Capture and normal-mode verification

- The first capture was triggered only because no golden baseline existed. Android run [45089102964](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089102964), run 318, generated/uploaded the PNGs and passed **196/196 tests**, APK build and package checks.
- Golden artifact [14781020409](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089102964/artifacts/14781020409): 676,053 bytes; SHA-256 `ff1f3b2860a2ea531c468bacfd5180d4de96fb3eee21977d85f4ef62aa3bb12c`.
- The guarded commit step verified 24 PNGs and wrote them to `main` in commit [18c802456498ac7185d975f68a1d36505c7484da](https://github.com/m5ham3ds/CUTAWAN/commit/18c802456498ac7185d975f68a1d36505c7484da). Branch Policy synchronized `CUTAWAN-TEST`.
- Android run [45089841288](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089841288), run 319, compared the saved PNG files in normal mode with `--update-goldens` disabled — **196/196 tests passed**.
- Format and `flutter analyze --fatal-infos`: passed.
- APK artifact [14780344052](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089841288/artifacts/14780344052): 60,029,458 bytes; ZIP SHA-256 `7b0a49eae512ee4b163efdc38859d9ae71d606b543792b486582ad71c18ffcb0`. Exactly `arm64-v8a`, 10 unique native libraries, GGML libraries present, no duplicate basenames.
- Coverage artifact [14780842110](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089841288/artifacts/14780842110): 18,306 bytes; SHA-256 `c3d80a455bf1a79d3ebb9625768f7181a725aefac419201a688f2bc6185790ad`.
- Desktop CI [45089841836](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45089841836), run 366 — **success** across all required checks.

## Remaining

- Full Tab-order traversal and visible-focus indicators.
- Per-page landscape and Android safe-area/system-inset tests.
- Physical handset visual review; widget goldens are not physical-device evidence.

**Decision:** accept the 24 page golden baselines and normal-mode comparisons as an automated Phase 9 slice. Phase 9 and Phase 10 remain in progress.
