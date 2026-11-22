# Phase 10 — Physical-device, security, quality and performance acceptance

## Purpose and acceptance rule

Phase 10 verifies the mobile release on a real ARM64 Android handset using a hash-locked media corpus. It is not accepted by a successful CI build, a mocked platform response, or a heuristic device-class marker. Every result must record the handset, Android release/API, application build SHA, fixture SHA-256, method, measurements, and limitations.

## Test corpus

- Arabic single-speaker interview and Arabic overlapping/multi-speaker discussion.
- English interview/podcast.
- Gaming/webcam and screen demonstration.
- Speech-light and music-heavy source.
- Portrait/landscape and rotated device footage.
- Short and long files, partial/corrupt video, and source with no audio.

The corpus must be versioned and SHA-256 locked. Each speech fixture needs a manually reviewed transcript and word boundaries. No generated or placeholder transcript is valid reference evidence.

## Required measurements

- Word error rate with insertion/deletion/substitution counts, matched-word coverage, and median/P95 word start/end timing error.
- Candidate completeness, editorial precision, duplicate ratio, source coverage, and human-selection outcome.
- Face-track retention and crop continuity across movement and scene cuts, not detector confidence alone.
- Full MediaCodec decode of every exported audio/video track to end-of-stream; record dimensions, duration, size, audio continuity and caption synchronization.
- Peak process PSS/RAM, processing time, temporary-storage peak, battery delta, and thermal state before/during/after sustained runs.
- Process restart/resume, SAF URI permission after force-stop/relaunch, secure-key lifecycle, and outbound network behavior with and without consent.

## Automated baseline instrumentation

The Android bridge collects only non-identifying runtime/device information: manufacturer/model, Android release/API, CPU count, RAM/available RAM, process PSS/private-dirty, app-private free storage, battery level/temperature, thermal status, app version and uptime. No serial number, media path, filename, provider key or media contents are included.

The Flutter service verifies required baseline fields and rejects impossible RAM ranges. `Build.FINGERPRINT` remains a heuristic only; `physical-candidate` is not a physical-device identity assertion. Manual handset confirmation remains separate. CI builds carry `BUILD_SHA`; local builds are marked unpinned.

A temporary random secure-storage canary is written/read/deleted. It does not access saved provider credentials. This is a single-install round-trip check only, not backup/restore, reinstall or key-rotation proof.

## Acceptance workbench UI

The diagnostic page groups device profile, headline memory/storage metrics, media quality, stability and privacy evidence. Status codes are translated into compact Arabic labels; raw values remain available in copied JSON. Long identifiers wrap/select rather than being forced into a fixed trailing width. The workbench does not display a green phase-complete state while any physical evidence is missing.

Widget tests cover a 320dp viewport with enlarged text, RTL, long build identifiers, light/dark theme, evidence rows and error-free layout. These are layout regression tests and do not substitute for device acceptance.

## Current automated evidence

- Mobile Android workflow [44868851973](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44868851973) validated the prior baseline instrumentation: 139 Flutter tests, strict analysis, format, ARM64-only APK, and unique native-library checks.
- The responsive workbench and its new tests are recorded in the subsequent implementation commit and must be verified by the new workflow run before calling this UI change accepted.

## Latest automated implementation gate — 2026-11-22

- Android run [45043179789](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789), run 296, source SHA `eabc20e3c7494a2030668bcac35a177881821e3b` — **success**.
- Format and `flutter analyze --fatal-infos`: passed.
- Flutter suite: **183/183 tests passed**, including diagnostics report scope assertions and 320dp/200%-text responsive widget checks.
- ARM64 debug APK build and packaging checks: passed; exactly `arm64-v8a`, 10 unique native libraries, no duplicate basenames.
- APK artifact [14763285423](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789/artifacts/14763285423): 60,020,680 bytes; ZIP SHA-256 `8954f75e5b9e81f611cc52c233b04067b5be81983113d7d14d0250b1c8200308`.
- Coverage artifact [14763115567](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789/artifacts/14763115567).
- Root/desktop CI [45043179788](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179788), run 341 — **success**.
- The app report states `physicalMediaTestsExecuted=false`: the page currently collects device metadata and performs one temporary secure-storage canary round-trip/delete. The media corpus, full decode, WER/timing, candidate quality, sustained performance, process-death, SAF force-stop, Keystore lifecycle and end-to-end consent tests are not run by the diagnostics page.

## Still not accepted — real-device gates

- No physical handset report or human device confirmation is attached.
- No SHA-locked audio/video corpus or manually reviewed Arabic/English transcript set has been committed.
- No physical Whisper WER/timing, candidate quality, crop continuity or full MP4 decode score has been collected.
- No sustained memory, battery, thermal or processing-time measurement exists.
- No process-death recovery, SAF force-stop/relaunch, Keystore backup/restore/reinstall/key-rotation or consent-blocking end-to-end physical result is attached.
- Activity-owned renderer sessions are cancelled when the Activity is destroyed; durable background render execution and session reconstruction remain Phase 8 work, not Phase 10 evidence.

## Required field procedure

1. Install an APK whose copied JSON contains the expected 40-character build SHA.
2. Run **تشخيص الجهاز** and copy the JSON report. Confirm the real handset manually; do not infer physical identity from the fingerprint heuristic.
3. Execute each versioned fixture and retain its SHA-256 and a manually checked reference transcript.
4. Record the measurements above for each fixture and export. Keep failed and inconclusive runs; do not replace them with synthetic values.
5. Run force-stop/relaunch, process-death, security lifecycle and cloud-consent checks on the physical phone.
6. Append results and known limitations to this record. Phase 10 remains incomplete until every required gate has evidence.

## Implementation history — responsive diagnostic workbench

- Replaced repetitive diagnostic cards and fixed-width trailing values with a compact responsive screen.
- Grouped evidence into media quality, performance/stability, and privacy/security.
- Translated raw service states to short Arabic labels and made status color semantic rather than decorative.
- Added adaptive metric cards, wrapping identifiers, selectable build SHA, retry feedback, expandable technical readings and a single JSON export action.
- Extended diagnostic metadata with an explicit build-identity status and schema version 2.
- Added a baseline test for impossible available-memory values and widget tests for 320dp + enlarged text and dark theme.
- No physical acceptance claim is made by these code and widget tests.

## Latest automated gate — responsive workbench — 2026-11-21

Mobile Android workflow [44870965616](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44870965616) on SHA de632a7bdb44987a6af5c538223e3c1b8b8bb50a completed successfully.

- Format: passed.
- flutter analyze --fatal-infos: passed.
- Flutter test suite: **142/142 passed**, including 320dp RTL with enlarged text, lazy section scrolling, long build SHA rendering, dark theme and invalid-memory-range handling.
- ARM64 debug APK build: passed.
- Packaging: exactly arm64-v8a; 10 unique native libraries; no duplicate native library basenames. GGML libraries verified: libggml-cpu.so, libggml.so and libggml-base.so.
- APK artifact: [cutawan-mobile-arm64-debug, artifact 14694345556](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44870965616/artifacts/14694345556), 59,012,693 bytes; ZIP SHA-256 d5bdbf27f5239f0833b8ca3ccc615174f7cf7ca89c6ca104589f0f0266714b42.
- Coverage artifact: [14693648956](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44870965616/artifacts/14693648956).

This is an accepted automated implementation/build gate only. Phase 10 is still not physically accepted: the device needs a human-confirmed handset report and actual hashed Arabic/English audio/video fixtures, manually reviewed word references, WER/timing/candidate/crop results, on-device full decode, sustained performance/thermal/battery measurements and lifecycle/security/consent tests. Mocked and widget tests do not count toward those field gates.
