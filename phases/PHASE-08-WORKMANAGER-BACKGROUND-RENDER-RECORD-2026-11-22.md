# Phase 8 — WorkManager foreground/background render record

**Date:** 2026-11-22  
**Repository:** `m5ham3ds/CUTAWAN`  
**Source SHA:** `645d2d349ecc9fe916b02a219a3ce0139f22b64a`  
**State:** Automated implementation gates passed; physical-device acceptance pending.

## Delivered code

- Native Media3 rendering is executed by a WorkManager long-running foreground worker rather than an Activity-owned in-memory render-session map.
- `NativeRenderEngine` contains the transform/validation path; `NativeRenderWorker` owns durable scheduling and foreground progress notification behavior.
- Work requests are serialized as unique work and carry validated project/clip identity. Per-project tags allow Jobs cancellation to cancel the project's queued/running work.
- A foreground notification exposes progress and a system cancellation action.
- Completion metadata is persisted durably, associated with project/render identity, and can be read after Flutter process recreation.
- `MainActivity` exposes WorkManager-backed start/progress/cancel, project-active, completed-result and acknowledge operations.
- Flutter recovers a completed render, verifies its actual output, persists the export record and stage checkpoint, and only then acknowledges the durable completion.
- Project startup/recovery checks WorkManager state so it does not mistakenly mark a live native background render as interrupted.
- Android platform generation pins WorkManager 2.12.0, adds the foreground-service manifest declarations/permissions and checks those declarations during CI.

## Automated acceptance evidence

- Mobile Android workflow [44970800438](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438), run 267, source SHA `645d2d349ecc9fe916b02a219a3ce0139f22b64a` — **success**.
- Android generation script validation, dependency resolution, format, strict analysis and **160/160 Flutter tests** all passed.
- ARM64 debug APK built and uploaded; ABI verification passed with exactly `arm64-v8a`, 10 unique native libraries, and no duplicated native-library basenames.
- APK artifact: [cutawan-mobile-arm64-debug, 14733448407](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733448407), **59,996,128 bytes**; archive SHA-256 `e7bf5a4a700b6c828d434c90667d3387ef26194c341d3c1bc42a2f8a72f440b5`.
- Flutter coverage artifact: [14733457471](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733457471), 16,981 bytes.
- Root/desktop CI [44970800462](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800462), run 310 — **success** for app checks/typecheck/lint/tests, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon packaging checks.

## Remaining acceptance gates

- Physical ARM64 handset: kill/recreate the app process during a render, reopen, verify worker completion is recovered and export record/checkpoint are persisted exactly once.
- Test explicit force-stop separately from process death; do not claim force-stop jobs resume while Android blocks the package.
- Verify progress notification display, notification action cancellation, notification permission, cancel latency, OEM battery/background restrictions and long render stability.
- Run actual media fixtures: short/long, VFR, portrait/landscape/rotated, audio-present, silent/no-audio and corrupt/truncated cases. Verify decoded tracks, duration, dimensions, crop continuity and RTL/English caption timing/placement.
- Remaining Phase 8 product work: targeted per-clip retry, export delivery/open/share/save controls and output cleanup/retention UI.
- Caption preview/native export parity remains partial: native MP4 export supports the verified static/karaoke-fill modes, not all Studio preview animations.

**Decision:** WorkManager code slice is accepted against automated gates. Phase 8 as a whole is not closed until the above device/media/product gates have evidence.
