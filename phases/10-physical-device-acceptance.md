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

## Field evidence template export — preparatory implementation

The Android diagnostics workbench now offers a separate **نسخ قالب نتائج الاختبارات الميدانية JSON** action. It creates a versioned `org.cutawan.phase10.field-evidence` document to record the physical test session without mixing it with the device snapshot.

- The template carries the pinned build SHA (when present), app version and a privacy-filtered device snapshot.
- It deliberately excludes serial numbers, account credentials, API keys, personal file paths, source filenames and media contents.
- The physical-device confirmation starts as `not-confirmed`; fixture inventory starts empty.
- Phase 8, Phase 9 and Phase 10 checks all start as `not-run`, with empty evidence and measurement fields. All acceptance values start as `not-accepted`.
- Check identifiers are grouped by phase and use the stable statuses `not-run`, `passed`, `failed` and `not-applicable`. A `passed` result requires attached evidence and measurements where applicable.
- This is evidence-collection preparation only. It does not run media tests, prove a physical handset, approve a result, or close the Phase 8/9 prerequisites. A reviewer must inspect the completed evidence before any acceptance status changes.

The template's unit and widget tests run in the Mobile Android workflow. No real-device measurements are prefilled or inferred from the CI runner.

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
- Historical note (2026-11-21): Activity-owned renderer sessions were cancelled when the Activity was destroyed. This was superseded by the 2026-11-22 WorkManager foreground worker/durable completion handoff in Phase 8. Physical handset background, relaunch/force-stop and OEM behavior remain unverified and are still Phase 10 evidence requirements.

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


## Current implementation and automation update — 2026-11-27

The Diagnostics page now has a separate **نسخ قالب نتائج الاختبارات الميدانية JSON** action. `DeviceAcceptanceService.createFieldEvidenceTemplate(diagnosticReport)` creates schema `org.cutawan.phase10.field-evidence`, version 1, with stable check IDs grouped under Phase 8, Phase 9 and Phase 10. It copies only approved non-identifying device/build metadata, starts physical-device confirmation as `not-confirmed`, fixture inventory empty, every check as `not-run`, evidence/measurement fields empty, and all acceptance statuses as `not-accepted`. It does not run tests or infer results. Dedicated service and widget tests cover this contract and the copy action.

Current source SHA `98e31ea4ef702c48eeace7093865e5fc6e282ae1`, Android run [#448](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46034533321): format and strict `flutter analyze --fatal-infos` passed; **260/260 Flutter tests passed**. The APK build then failed because Maven Central returned HTTP 429 while Gradle resolved `org.jetbrains.kotlin:kotlin-gradle-plugins-bom:2.2.20` through `plugins.gradle.org`; the retry also failed with the same external rate-limit response. Therefore no APK from SHA `98e31ea` or Phase 10 template field run is available yet. Root CI [#507](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46034533276) and Branch Policy [#157](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46034533273) succeeded; `main` remains the only branch.

The previous latest successful ARM64 APK is Android [#447](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45859864265), built from `83053e7284e9225a94797d82020235b1914563d1`. It predates the field-evidence template and must not be represented as containing that UI. All physical metrics, corpus results, on-device security, lifecycle and quality acceptance remain uncollected.


## Transcript WER and word-timing evaluator — 2026-11-27

Added a Flutter/Dart field-evaluation utility at `mobile/flutter_app/lib/tooling/phase10/`:

- `transcript_evaluation.dart` validates the schema, pinned 40-character application build SHA, 64-character fixture SHA-256, manually confirmed physical-device metadata, human-reviewed reference transcript, Arabic/English language match, and ordered word timestamps within the media duration.
- It computes Levenshtein word-level substitutions, deletions, insertions and WER; exact-match coverage/precision; and median/P95 absolute word-start and word-end errors for exact normalized matches only.
- The versioned `cutawan-ar-en-v1` normalizer lowercases Latin, removes Arabic harakat/tatweel, normalizes alef forms/alef maqsura and trims leading/trailing Arabic/Latin punctuation.
- The DP implementation stores a byte per traceback cell and two cost rows, with an eight-million-cell hard limit. Longer transcripts must be split into consecutive source-time windows rather than risking unbounded memory.
- CLI entry point: `dart run lib/tooling/phase10/evaluate_transcript.dart --input <evaluation.json> --output <metrics.json>`.
- Unit tests cover exact matches, S/D/I counts, Arabic normalization, nearest-rank P95, missing hypothesis words, invalid physical/build/reference/hash evidence, invalid word times and oversized alignment rejection.

The evaluator reports measurements only. It defines no pass threshold, does not alter phase acceptance statuses and does not add synthetic data to the corpus. No physical-device WER/timing result has been collected by this implementation. See [the evaluator protocol and input contract](PHASE-10-TRANSCRIPTION-EVALUATION-TOOL-2026-11-27.md).


## Candidate quality and human-selection evaluator — 2026-11-27

Added a deterministic Flutter/Dart evaluator under `mobile/flutter_app/lib/tooling/phase10/`:

- `candidate_evaluation.dart` validates a pinned application Git SHA, manually confirmed physical-device metadata, a SHA-256-locked source fixture, human-reviewed gold editorial moments, a candidate run and a separately human-reviewed decision set.
- It computes one-to-one temporal IoU matching, candidate precision/recall/F1, false positives/false negatives, mean matched IoU, duplicate overlap clusters, duplicate candidate ratio, source-interval union coverage and equal-duration source-bucket coverage.
- It separates `keep`, `repair`, `reject` and `unreviewed`; unreviewed suggestions are not silently counted as rejects.
- Matching is deterministic greedy IoU-first matching, not an optimal-assignment guarantee. Duplicate detection uses overlap divided by the shorter candidate duration, with a default 0.85 threshold.
- Workloads are bounded: 2,000 candidates, 1,000 reference moments, 250,000 candidate/reference pairs and 1,000,000 duplicate-pair comparisons.
- CLI: `dart run lib/tooling/phase10/evaluate_candidates.dart --input <evaluation.json> --output <metrics.json>`.
- The test suite covers perfect/partial matching, duplicate clusters, source coverage, keep/repair/reject/unreviewed decisions, empty sets, invalid evidence and resource caps.

Android [#456](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622887) on source SHA `716408d244b688f028bececf5f72b9e356cee8e0` passed Format, strict analysis and **279/279 Flutter tests**, built the ARM64 APK, passed Media3 and all eight preview/export parity cases (24/24), verified exactly ARM64 with ten unique native libraries and uploaded APK/coverage artifacts. Root CI [#515](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622952) and Branch Policy [#165](https://github.com/m5ham3ds/CUTAWAN/actions/runs/46065622871) also passed.

This is automated evaluator and build evidence only. No human gold candidate set or physical-device candidate-quality result has been collected, and no acceptance threshold is inferred. See [the candidate evaluator protocol](PHASE-10-CANDIDATE-EVALUATION-TOOL-2026-11-27.md).
