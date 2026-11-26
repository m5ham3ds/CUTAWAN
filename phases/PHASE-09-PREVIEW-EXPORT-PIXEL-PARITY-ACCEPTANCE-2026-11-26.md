# Phase 9 — Clip Editor preview/export pixel-parity acceptance

**Date:** 2026-11-26  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `846c53c6078691c8af5fe8fe9a07f60823d80ecc`

## Decision

**Accept the eight-scenario automated preview/export pixel-parity matrix.** Android run 442 completed successfully. All 24 matched-timestamp comparisons passed without relaxing either threshold:

- Mean absolute pixel error (MAE): **less than 24**.
- Worst sampled patch mean: **less than 48**.

This is emulator-level evidence for the scenarios listed below. It is not physical-device acceptance and does not assert exhaustive parity for the full caption-animation catalogue, rotated camera sources or every real-world media format.

## Test matrix results

Each scenario was sampled at source/output timestamps **200ms, 1049ms and 1899ms**.

| Scenario | MAE at 200ms | MAE at 1049ms | MAE at 1899ms | Maximum worst-patch mean |
|---|---:|---:|---:|---:|
| Manual left portrait | 2.08 | 2.08 | 1.87 | 4.27 |
| Manual right portrait | 1.02 | 0.96 | 0.96 | 1.53 |
| Automatic left portrait | 2.08 | 2.08 | 1.87 | 4.27 |
| Manual top landscape | 11.76 | 11.57 | 11.46 | 38.35 |
| Manual bottom landscape | 2.50 | 2.59 | 2.59 | 7.20 |
| Vertical keyframe pan | 1.71 | 14.07 | 2.22 | 43.57 |
| Full-frame fit | 2.31 | 2.30 | 2.30 | 5.65 |
| Manual crop with fade-in/out | 1.81 | 1.40 | 6.02 | 8.67 |

**Result:** 8 scenarios × 3 timestamps = **24/24 comparisons passed**. The largest MAE and patch error occurred at the vertical-pan midpoint (14.07 and 43.57 respectively), both below the fixed limits.

## Earlier regressions corrected before acceptance

Two earlier Android parity runs exposed distinct export defects. Both failures were corrected in later source commits, and the unchanged MAE/worst-patch thresholds were then passed by Android run 442.

### Keyframed vertical crop interpolation — Android run 439

Run [439](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45721862410) failed at the vertical-pan midpoint (1049ms): MAE **105.17** and worst patch **141.80**, above the required limits. Flutter sent both the start crop region and `regionEnd`, but `NativeRenderEngine` parsed only the start region and applied it for the entire segment.

The native engine now parses and validates both rectangles, requires stable crop dimensions, and interpolates the crop origin at each Media3 presentation timestamp. The correction and regression coverage were committed in:
- `1aa7f735d50e234068268242ed7494785da65892` — native Media3 interpolation.
- `511230b5caa1b5fe8985e59cd5e51d487f8d3699` — Flutter crop-interpolation contract test.

### Full-frame fit geometry — Android run 441

Run [441](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45727137984) then exposed a separate full-frame-fit geometry defect: at 200ms, MAE was **62.01**, above the required limit of 24. The native output-size and fit-scale calculations did not consistently preserve the source aspect ratio for the target frame.

Commit [`846c53c6078691c8af5fe8fe9a07f60823d80ecc`](https://github.com/m5ham3ds/CUTAWAN/commit/846c53c6078691c8af5fe8fe9a07f60823d80ecc) corrected the output dimensions and scale factors so the source image is preserved and letterbox/pillarbox space is added on the appropriate axis.

### Verification after both corrections

Android [run 442](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357835) passed both previously failing scenarios:
- Vertical keyframe pan: MAE **1.71 / 14.07 / 2.22** at 200 / 1049 / 1899ms; maximum worst-patch mean **43.57**.
- Full-frame fit: MAE **2.31 / 2.30 / 2.30**; maximum worst-patch mean **5.65**.

All 24 comparisons in the eight-scenario matrix passed. The two historical failures are therefore resolved in the accepted source SHA; they are not outstanding failures on the current branch.

## Final automated build evidence

- Android run [45732357835](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357835), run 442 — **success**.
- Root CI [45732357805](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357805), run 495 — **success**.
- Branch Policy [45732357819](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357819), run 145 — **success**; `main` is the only branch.
- Current source SHA: `846c53c6078691c8af5fe8fe9a07f60823d80ecc`.
- Flutter tests: **257/257 passed**; strict analysis and formatting passed.
- Media3 transition/instrumentation, ARM64-only verification and duplicate-native-library checks passed.
- APK artifact [cutawan-mobile-arm64-debug — 15078655021](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357835/artifacts/15078655021): 60,639,483 bytes; SHA-256 `e46e015943ff4476b4f2ccde2c449894f8a1cc90a1c80bf8879c3716449e27ab`.
- Coverage artifact [cutawan-mobile-flutter-coverage — 15076684301](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357835/artifacts/15076684301): 21,334 bytes.

## Scope limits and next gate

The test matrix measures crop framing, manual/automatic selection, keyframe interpolation, full-frame fit and per-clip fade overlays. It does not establish:
- raster/pixel parity for all Caption Studio animation modes or every caption font/RTL layout;
- every rotated, variable-frame-rate, long, truncated or no-audio real-media source;
- real-device focus visibility, Tab behavior, safe-area handling or OEM UI behavior;
- Phase 8 background/relaunch/force-stop, notification, retry and physical full-decode acceptance.

The next Phase 9 gate is actual ARM64 handset visual/accessibility review. Phase 10 must not start until this physical Phase 9 evidence is attached; Phase 8's separate physical media/background gates must also remain visible and unaccepted until tested.

See [the physical handset checklist](PHASE-09-PHYSICAL-HANDSET-ACCEPTANCE-2026-11-26.md).


## Independent rerun on the targeted re-render product baseline — Android #446

- Android run [45854102190](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45854102190), source SHA `8bd9d5fb1534dc0da52d6b8af484059873f5c397` — **success**.
- The eight scenarios again passed all **24/24** timestamp comparisons at 200 ms, 1049 ms and 1899 ms. The highest MAE was 14.07 and the highest sampled-patch mean was 43.57, within the existing <24/<48 limits.
- The same run passed 257/257 Flutter tests, Media3 emulator/instrumentation, ARM64-only ABI and unique-native-library checks, and APK upload.
- This confirms the parity matrix on the same application-source baseline used for the targeted re-render feature. It remains emulator-level evidence and does not close the physical handset checklist.


## Independent rerun including targeted re-render regression — Android #447

- Android run [45859864265](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45859864265), build commit `83053e7284e9225a94797d82020235b1914563d1` — **success**. The commit adds only a direct pipeline integration test; application code remains at `8bd9d5fb1534dc0da52d6b8af484059873f5c397`.
- The run passed **258/258 Flutter tests**, including the targeted per-clip re-render / untouched-peer preservation test, and both Android preview/export integration tests.
- All eight preview/export scenarios again passed **24/24** matched-timestamp comparisons at 200 ms, 1049 ms and 1899 ms. Maximum observed MAE was **14.07** and maximum worst sampled patch mean was **43.57**, within the unchanged **<24 / <48** thresholds.
- Media3 emulator instrumentation, ARM64-only APK verification, ten unique native libraries/no duplicate basenames and APK upload all passed.
- APK artifact [cutawan-mobile-arm64-debug — 15138487911](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45859864265/artifacts/15138487911): 60,653,801 bytes; artifact ZIP SHA-256 `26e96cec9449b249bc1cf0a7d60e6caf62c535be7a1456d270a33b541898333f`.
- Root CI [45860851357](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45860851357), run 505, and Branch Policy [45860851360](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45860851360), run 155, passed on the prior documentation baseline; `main` remained the only branch.
- This independent emulator rerun strengthens automated evidence only. The Phase 9 physical handset checklist and Phase 8 physical media/background checklist remain `NOT RUN` until real-device results are recorded.
