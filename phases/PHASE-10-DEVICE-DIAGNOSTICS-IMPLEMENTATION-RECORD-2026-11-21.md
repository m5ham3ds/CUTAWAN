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
- Rendered MP4 outputs are not yet fully decoded to end-of-stream. Existing metadata probing alone is insufficient.
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
