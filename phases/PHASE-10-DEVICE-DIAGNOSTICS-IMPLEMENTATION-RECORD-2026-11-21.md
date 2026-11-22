# Phase 10 diagnostics implementation record — 2026-11-21

## Implemented in CUTAWAN Mobile

- `MainActivity.getDeviceAcceptanceDiagnostics` returns a non-identifying Android snapshot:
  - manufacturer, device model and codename;
  - Android release and API level;
  - CPU core count and app version;
  - total/available system RAM and process PSS/private dirty memory;
  - battery percentage and temperature, when supplied by Android;
  - thermal status, when supported by Android API 29+;
  - free bytes in the app-private storage volume;
  - elapsed-realtime capture point.
- Flutter exposes this snapshot through `DeviceAcceptanceService`.
- An ephemeral random canary is written, read back and deleted through the existing secure credential-storage abstraction. The canary is never returned, printed or sent remotely; persisted user credentials are not accessed.
- `DeviceAcceptancePage` can be opened from the application header and copies a JSON report.
- CI builds embed `github.sha` as `BUILD_SHA`; local APK builds without that define are labelled `local-or-untracked`.
- Three unit tests cover the successful diagnostic path, absent native diagnostics and secure-storage read failure/cleanup.

## Safety and evidence boundaries

The screen is a diagnostic instrument, not a test execution claim. The report explicitly keeps fixture evidence marked as not collected and Phase 10 marked incomplete. A secure-storage round trip on the current installation does not prove backup/restore, reinstall or rotation safety. The native thermal/battery snapshot is a point-in-time observation, not a sustained-load benchmark.

## Still not accepted

- No physical-device diagnostics snapshot has been captured and attached to the repository.
- No hashed, manually reviewed Arabic/English speech corpus or Whisper WER/timestamp report has been recorded.
- No candidate precision/completeness/duplicate or visual crop continuity review has been recorded.
- Phase 8 now requires MediaCodec to decode every output audio/video track to end-of-stream before publish or resume. This code has passed automated tests/build, but has not yet been validated against the physical Arabic/English media corpus and real devices.
- Background render execution and process-death reconstruction remain open in Phase 8.
- No physical measurements of peak memory, battery drain, sustained thermal behavior or processing time have been collected.
- No device test has verified SAF permissions across force-stop/relaunch, Android Keystore behavior across backup/restore/reinstall, or network-consent behavior end-to-end.
- Phase 9's full feature architecture, interactive Clip Editor and accessibility/golden/device matrix remain incomplete.

## Required next step

Install an APK built from a SHA recorded in GitHub Actions on a physical ARM64 Android device, open **تشخيص الجهاز**, and preserve the copied JSON. Then run the versioned real-media acceptance corpus and append fixture hashes, methods, metrics and failures. Never use synthetic examples or hosted CI results to fill physical-device fields.


## Baseline completeness and device-class caution — 2026-11-21

- The report computes diagnostic baseline status from mandatory fields instead of treating any non-empty native response as complete.
- Build.FINGERPRINT is explicitly a physical-device heuristic. The UI reports physical-candidate, not confirmed physical device.
- Manual confirmation remains not-verified until a real handset session is performed.
- Media corpus, transcription/candidate quality, full MP4 decode, sustained thermal/performance, process-death recovery, SAF persistence, Keystore lifecycle and end-to-end network-consent states are explicit evidence statuses and remain uncollected.
- Tests validate the gate logic using mocked platform responses only; no mocked result is counted as physical acceptance.


## Latest CI evidence — 2026-11-21

- The baseline-gate service/UI changes passed Mobile Android workflow [44868851973](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44868851973) at SHA `bad891491288e67324932f81c261b6953916055c`.
- Result: 139/139 Flutter tests, strict analysis and format passed; ARM64-only APK and unique native library assertions passed.
- APK artifact 14693675362, 59,016,463 bytes; SHA-256 `56cf57b2c79b83ee5533b1897e212f607c11f200f854a80cb79c21069a101ae4`.
- The physical handset marker remains heuristic and manual confirmation is not verified. Media corpus and all physical quality/performance/lifecycle results remain uncollected.

## Latest automated gate and diagnostic execution scope — 2026-11-22

- Android run [45043179789](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789), run 296, SHA `eabc20e3c7494a2030668bcac35a177881821e3b` — **success**: Format, strict analysis, **183/183 Flutter tests**, ARM64 APK build, ARM64-only ABI and duplicate-library verification, artifact upload.
- The responsive Diagnostics page test explicitly asserts that the screen is a device measurement snapshot, not an executor for physical media tests. The service report sets `physicalMediaTestsExecuted=false` and identifies its scope as device metadata plus a temporary secure-storage self-test.
- Service/widget tests use mocked platform-channel responses. They verify baseline completeness/missing-field logic, invalid RAM ranges, secure-storage canary cleanup, and responsive UI; they do not collect physical handset/media evidence.
- APK artifact [14763285423](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789/artifacts/14763285423): 60,020,680 bytes; ZIP SHA-256 `8954f75e5b9e81f611cc52c233b04067b5be81983113d7d14d0250b1c8200308`.
- Root/desktop CI [45043179788](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179788), run 341 — success.

**Field status remains unchanged:** no physical handset diagnostic JSON, hash-locked Arabic/English media corpus, WER/timing report, manually reviewed candidate/crop quality, on-device full decode, sustained battery/thermal/performance measurements, process-death/SAF/Keystore lifecycle or end-to-end consent result has been collected. Phase 10 remains incomplete.
