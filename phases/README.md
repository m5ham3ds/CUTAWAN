# CUTAWAN Mobile — Phase Register

**Repository:** `m5ham3ds/CUTAWAN`  
**Working branch:** `main` only.  
**Rule:** Continue from the last accepted commit; do not re-run completed implementation phases without a specific regression or acceptance reason.

## Baseline and latest verified Android state

- Latest Mobile Android run: [44970800438](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438), run **267**, SHA `645d2d349ecc9fe916b02a219a3ce0139f22b64a` — **success**. Dart format, strict analysis, **160/160 Flutter tests**, ARM64 debug APK build, ARM64-only ABI check, unique-native-library verification and APK upload all passed.
- APK artifact: [cutawan-mobile-arm64-debug, artifact 14733448407](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733448407), **59,996,128 bytes**; artifact ZIP SHA-256 `e7bf5a4a700b6c828d434c90667d3387ef26194c341d3c1bc42a2f8a72f440b5`. It contains exactly `arm64-v8a`, **10 unique native libraries**, and no duplicate native-library basenames.
- Coverage artifact: [14733457471](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733457471), 16,981 bytes.
- Root/desktop CI run [44970800462](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800462), run **310** — **success** across checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon package validation.
- WorkManager-backed Android rendering and project-scoped cancellation are present on this head. This is automated build/test evidence, **not** physical-device acceptance after process death, force-stop, OEM background restrictions or long renders.
- Jobs workflow page remains accepted; its cancellation action now also requests cancellation of the project's queued/running native WorkManager renders. Per-clip retry and export delivery/management remain open.

- Latest accepted Mobile Android run: [44953830473](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473), run number 257, SHA `e2d3c08e9f2d4559cd931f4b461607f6012a2a95` — **success**.
- It passed Dart format, `flutter analyze --fatal-infos` (`No issues found!`), **154/154 Flutter tests**, ARM64 debug APK build, ARM64-only ABI verification, duplicate-native-library verification, and APK upload.
- APK artifact: [`cutawan-mobile-arm64-debug`, artifact 14727205792](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473/artifacts/14727205792), size 59,094,264 bytes; archive SHA-256 `366a66f02d012135b0bec933492642c6a487bdd9b1a7a532cd1978b5b5fb1adf`.
- Native package assertion: exactly `arm64-v8a`, 10 unique native libraries, including `libggml-cpu.so`, `libggml.so`, and `libggml-base.so`; no duplicate native-library basenames.
- Coverage artifact: [`cutawan-mobile-flutter-coverage`, artifact 14726905907](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473/artifacts/14726905907), size 16,294 bytes; archive SHA-256 `13b8639dab36826fd00e3a20f61ef94ad8b2df28e167df63af4c8b66f21119f3`.
- Root/desktop CI run [44953830478](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830478) — **success**, including app checks, UI smoke, and offline video/caption pipeline tests. This is independent of Android validation and does not replace physical-device acceptance.
- The successful CI run confirms formatting, static analysis, widget/unit tests, compilation and packaging only. It does not prove physical-device inference quality, SAF process-death behavior, Android Keystore backup/restore, sustained media decode, thermal limits or background render recovery.

## Phase matrix

| Phase | Scope | Current state | Evidence / constraint |
|---|---|---|---|
| 1 | Flutter Android shell, basic navigation and ARM64 packaging | Implemented; automated gates passed | Device installation and OEM behavior still required |
| 2 | Media import, direct video download, project persistence and lifecycle | Implemented; automated gates passed | Real SAF provider/process-death testing remains open |
| 3 | Local Whisper transcription and model manager | Streaming mono/16kHz PCM reader, low-pass resampling and overlap-aware chunk planning implemented; latest Android CI passed | Arabic/English WER and word-timing accuracy, VAD, thermal/memory and physical-device evidence remain open |
| 4 | Candidate discovery, evidence, ranking and local Qwen annotations | Implemented deterministic discovery foundation; unpunctuated long transcripts now split at timed word boundaries | Editor review and real-media candidate-quality evaluation remain open; visual evidence is frame-change, not semantic scene understanding |
| 5 | Face sampling and validated reframing plans | Face-position-aware crop planning and safe `fit` gaps implemented; native renderer consumes time-ranged crop segments | Not active-speaker recognition; physical render framing/continuity evaluation remains open |
| 6 | Caption Studio visual presets, motion preview, RTL and preference persistence | Studio preview now loads saved transcript words/timing and groups them using live style/font/scale settings | Not synchronized to actual video playback; Studio and Android overlay are not yet pixel-identical |
| 7 | Multi-provider model selection, secure user credentials, consented cloud editorial annotations | Provider-scoped model/key storage, consent gates on outbound requests, local fallback on key deletion; latest Android CI passed | Physical Keystore/backup/rotation tests, real provider account/model compatibility, billing and policy acceptance remain open |
| 8 | End-to-end pipeline, job orchestration and clip export | Media3 full-track decode validation, deterministic checkpoints, WorkManager foreground worker, durable completion handoff, project-scoped cancellation and render notifications implemented; automated Android gates passed on run 267 | Physical ARM64 fixture/lifecycle/OEM tests remain open; per-clip retry and export delivery/cleanup UI remain open |
| 9 | Professional UI redesign and navigation/component architecture | Dashboard, Settings, Create, Review, Clip Editor, Caption Studio and Jobs are isolated feature screens; HomeShell no longer owns `part` libraries; Android run 284 passed 167/167 tests and ARM64 packaging | Next: finish export gallery/delivery actions; then complete accessibility semantics/focus/tap targets, dark/light RTL/LTR goldens at 320dp, keyboard/landscape/safe-area and physical UI acceptance |
| 10 | Physical-device quality, security, performance and Arabic/English acceptance | Responsive diagnostic workbench, baseline gate and missing-evidence reporting implemented; physical acceptance incomplete | 142/142 Flutter tests and ARM64-only APK pass in run 44870965616; still needs handset confirmation, real media corpus, WER/timing, full-decode and lifecycle/thermal evidence |

## Global engineering constraints

1. Root Electron desktop remains intact. Flutter Android is a sibling application.
2. No new Git branch. Every source update is committed directly to `main`.
3. No API key in source, assets, project JSON, logs, screenshots, analytics, or GitHub Actions output.
4. Cloud calls need explicit consent. Send only the minimum text needed; do not upload a user's video by default.
5. Provider model lists are account-scoped and not a universal guarantee of cost, quota, availability, or task compatibility.
6. Local inference remains supported. Choosing a remote model must not uninstall or silently replace local models.
7. A failed optional model annotation must retain deterministic candidates and not corrupt project artifacts.
8. Candidate timestamps, project IDs, source evidence and deterministic scores remain app-owned; LLM output can only populate approved editorial text fields.
9. An incomplete render/export feature must remain visibly disabled rather than report a false success.
10. Each phase must add its own implementation record, test list, known limits and remaining acceptance evidence.

## Execution order agreed on 2026-11-21

Implement and gate in this order: Phases 1–3 together; then Phases 4–5; then Phases 6–7; then Phase 8; then Phase 9 once (the repeated 9 in the request is one phase); finally Phase 10. Later groups start only after the previous group has code and automated evidence. Physical-device requirements remain separate and cannot be inferred from CI.

## Current next actions

1. Phase 8's full-decode, durable WorkManager render worker, foreground progress notification, project cancellation and process-recovery handoff are implemented and have passed automated Android/desktop CI. Do not repeat this implementation.
2. Keep Phase 8 acceptance open until a physical ARM64 device run validates background completion, relaunch/recovery, cancellation notification, long/VFR/rotated/no-audio/silent/corrupt fixtures, crop/caption continuity, audio and full decode. Add targeted per-clip retry and export delivery/cleanup UI as remaining product work.
3. Phase 9 HomeShell extraction is accepted on `d30695cf38c7fb1dd009427c3da8c029921e4a17`; see `PHASE-09-HOME-SHELL-SCREEN-EXTRACTION-RECORD-2026-11-22.md`. Do not repeat the page extraction or redesign the accepted Create, Review, Clip Editor, Caption Studio or Jobs workflows unless a regression is found.
4. Continue Phase 9 with export gallery/delivery: open, share and safely delete only validated app-owned MP4 exports. Then complete accessibility semantics/focus/tap targets, dark/light RTL/LTR goldens at 320dp, keyboard/landscape/safe-area behavior and real interaction tests.
5. Finish Phase 10 with physical ARM64 accuracy, privacy, thermal, battery, lifecycle and performance acceptance.

Phases 1–7 have a successful automated Android gate on SHA `80e182b`; physical-device checks and phase-specific quality acceptance are still separate and must not be inferred from CI.

## Branch and upstream integration audit — 2026-11-21

- Added `docs/BRANCH-FEATURE-AND-SOURCE-INTEGRATION-AUDIT-2026-11-21.md`.
- Audited representative feature-bearing branches against main; stale snapshots are not merged wholesale. The audit maps branch scope, mobile equivalents, source-project roles and outstanding Flutter gaps.
- Flutter remains the product implementation target. Desktop root CI success is not mobile acceptance.
- Phase 8 remains in progress: Media3 now consumes time-ranged reframe transforms and burns timed caption cues into MP4; full decode validation, physical visual/media fixtures, process-death render recovery, background notifications and per-clip retry remain open.
- Phase 9 remains in progress: production Clip Editor, full screen/navigation architecture, feature boundaries, golden/RTL/accessibility/keyboard matrix and physical UI evidence remain open.
- Phase 10 remains incomplete: physical ARM64 accuracy, lifecycle, security, thermal, battery and performance evidence is required.
- No branch merge or algorithm parity claim was made by the audit. Each port must have Dart/Kotlin code, upstream provenance/license and tests.

## Phase 10 diagnostics instrumentation — 2026-11-21

- Added an Android MethodChannel diagnostic snapshot for manufacturer/model, Android release/API level, app version, CPU count, total/available RAM, process PSS/private-dirty memory, battery percentage/temperature, thermal status and app-private free storage.
- Added an in-app **تشخيص الجهاز** entry and a report-copy action. The report includes the exact source SHA embedded into CI-built APKs; local builds clearly identify themselves as `local-or-untracked`.
- Added an ephemeral, random secure-storage write/read/delete self-test. It never reads or changes saved provider credentials and never includes the canary value in the report.
- Added three Flutter tests covering successful capture/cleanup, missing native diagnostics and secure-storage read failure.
- This is an evidence-collection instrument, **not Phase 10 acceptance**. A physical-device run and real-media evidence have not been collected in CI or claimed here.

### Phase 10 remaining acceptance gates

1. Run the diagnostics screen on a physical ARM64 Android device and retain the JSON with model, OS, build SHA and timestamp.
2. Build a hash-locked Arabic/English corpus spanning solo/overlap speech, webcam/screen recordings, music/silence, portrait/landscape/rotation, short/long, truncated/corrupt and no-audio sources.
3. Measure WER, insertion/deletion/substitution rates, matched-word coverage and median/P95 word start/end timing against manually reviewed references.
4. Review candidate completeness/precision/duplicates and face-track retention/crop continuity on the same source fixtures.
5. Run exported MP4s through a full decode to end-of-stream; verify audio continuity, dimensions, duration, caption synchronization and playback on device.
6. Record peak PSS/RAM, processing time, battery delta, thermal status and temporary-storage peak during long runs.
7. Verify SAF grant after force-stop/relaunch, secure-key behavior across backup/restore/reinstall/key deletion, and that cloud requests remain blocked without consent.
8. Repeat cancellation/retry/resume and render recovery after process death. Phase 8's current Activity-owned render map still prevents this gate from being accepted.

**Acceptance rule:** no empty placeholder, synthetic fixture, CI pass or emulator snapshot may be counted as physical-device evidence. If a measurement is unavailable, it remains `null`/blocked and the phase stays incomplete.

## Phase 9 UI/editor implementation — 2026-11-21

- Added Dashboard and Settings screen modules; primary navigation now includes Dashboard, Create, Jobs, Review and Caption Studio.
- Dashboard metrics and recent projects are bound to persisted project state. Its actions open real app destinations.
- Settings exposes working routes to Android diagnostics and model/privacy controls.
- Added a source-backed playback editor with source-time trim, title and aspect-ratio changes persisted into existing records.
- Caption and render fingerprints include candidate timing; editor changes invalidate affected sidecars/exports but do not force discovery to overwrite manual edits.
- Added candidate-range and navigation/settings widget tests.
- Filmstrip, manual crop/focus handles, transition editing and exact preview/export parity remain open.


## Phase 10 baseline gate and Phase 9 build evidence — 2026-11-21

- Phase 9 acceptance run: Mobile Android run 44867941475, SHA 7770b3bb6a24efaf59606364a62280aab7ef0060.
- Automated gates: format success, strict Dart analysis success, 137/137 Flutter tests passed, ARM64 debug APK build success, ARM64-only/unique-native-library verification success.
- APK artifact: cutawan-mobile-arm64-debug, artifact ID 14693190037, size 59,010,179 bytes; archive digest SHA-256 176f1e21429f3d6b084d14fb522e94c53b727a1ada22f2a3d2d7e1883d8f56e0.
- Native packaging check: exactly ARM64 ABI; 10 unique native libraries; GGML runtime libraries present; no duplicate library basenames.
- Phase 10 report computes completeness of required diagnostics and enumerates missing fields.
- Build.FINGERPRINT classification is explicitly a heuristic. A physical-candidate result is not human-confirmed physical evidence.
- No real audio/video fixtures or handset diagnostic report exist in the repository. Speech/candidate quality, full media decode, thermal/performance, process-death, SAF lifecycle, Keystore restore/reinstall and end-to-end consent evidence remain open.
- Phase 10 remains incomplete; CI and an ARM64 APK cannot substitute for physical-device acceptance.


## Phase 10 automated CI result — 2026-11-21

- Latest Mobile Android run: [44868851973](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44868851973), SHA `bad891491288e67324932f81c261b6953916055c` — **success**.
- Format and `flutter analyze --fatal-infos`: passed.
- Full Flutter unit/widget suite: **139/139 passed**.
- ARM64 debug APK build, ARM64-only ABI assertion, unique native library assertion and artifact upload: passed.
- APK artifact: `cutawan-mobile-arm64-debug`, artifact ID `14693675362`, size 59,016,463 bytes; archive SHA-256 `56cf57b2c79b83ee5533b1897e212f607c11f200f854a80cb79c21069a101ae4`.
- Native package assertion: exactly `arm64-v8a`, 10 unique native libraries, including `libggml-cpu.so`, `libggml.so` and `libggml-base.so`; no duplicate native-library basenames.
- Coverage artifact: `cutawan-mobile-flutter-coverage`, artifact ID `14692079659`.
- Root/desktop CI run [44868851978](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44868851978) also passed; this does not replace Android physical-device acceptance.
- Phase 10 is **not physically accepted**. No Android handset report, media corpus, WER/timing reference set, sustained thermal/battery test, SAF force-stop/relaunch result, Keystore restore/reinstall test or end-to-end consent test has been collected.

## Phase 10 responsive acceptance workbench — 2026-11-21

- Reworked تشخيص الجهاز into a phone-first evidence workbench: compact device overview, adaptive memory/storage metrics, concise device details, and distinct media-quality, stability, and privacy evidence groups.
- Removed repeated per-value cards and redundant explanation blocks. Raw service states now use short Arabic descriptions; colors come from the current theme and distinguish success, pending and failure only.
- Long SHA/build identifiers remain selectable and can wrap. Metric cards adapt to narrow viewports; advanced technical readings are collapsed by default.
- Diagnostic schema v2 adds explicit buildIdentityStatus and flags impossible memory readings rather than accepting a value larger than total RAM.
- Added widget coverage for a 320dp RTL viewport with increased text scale, lazy-list scrolling, long build identifiers and dark theme. Added service coverage for invalid memory ranges.
- UI commit: 45ba1c6274bd45d7252c861af05b8695f5805a1d; lazy-scroll test correction: de632a7bdb44987a6af5c538223e3c1b8b8bb50a.
- Latest Mobile Android workflow: [44870965616](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44870965616), SHA de632a7bdb44987a6af5c538223e3c1b8b8bb50a — **success**. Format, strict analysis, **142/142 Flutter tests**, ARM64 debug APK build, ARM64-only ABI check, native-library duplicate check and artifact upload all passed.
- APK artifact: [cutawan-mobile-arm64-debug, artifact 14694345556](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44870965616/artifacts/14694345556), 59,012,693 bytes; ZIP digest SHA-256 d5bdbf27f5239f0833b8ca3ccc615174f7cf7ca89c6ca104589f0f0266714b42. It contains only arm64-v8a and 10 unique native libraries, including libggml-cpu.so, libggml.so and libggml-base.so.
- Coverage artifact: [artifact 14693648956](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44870965616/artifacts/14693648956).
- Root/desktop CI: [44870965558](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44870965558) — success.
- Phase 10 physical acceptance remains incomplete. No real handset confirmation/report, reference corpus, WER/timing/candidate score, on-device full MP4 decode, sustained performance/thermal measurements, process-death/SAF/Keystore lifecycle or physical consent-blocking result has been collected. CI/widget results are not substitutes for those gates.


## Page-by-page workflow redesign register — 2026-11-21

The page workflow sequence is tracked separately from the broader phase matrix. Do not repeat a page whose implementation and Android gates are recorded below.

### Accepted page work

- **Create — complete for this workflow slice.** Source selection and project creation are explicitly separated: step 1 selects/checks the video; step 2 configures clip count, duration, aspect ratio, resolution and caption options; only the final action persists the project. A saved project navigates to Review. Uncommitted SAF grants and app-owned downloads are cleaned up safely when the page is abandoned. Final Create implementation: commit `4b91efb9ad587bd839b8ff44667a05fe18f4b189`; Mobile Android run [44909044979](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44909044979), 142/142 tests and ARM64-only APK succeeded; artifact `14709735177`.
- **Review — complete for this workflow slice.** The page presents source verification, four workflow stages, a primary full-pipeline/resume action, collapsed manual stage tools and evidence, candidate cards with timing/score/rationale and Clip Editor entry, and validated MP4 output records. Processing services were preserved; active-stage identity is project-bound. The 320dp RTL workflow test passed. Final implementation commit `cb0ca70b3bc6751b3c245ab576ff021593e20c92`; Mobile Android run [44923605861](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44923605861), **143/143 tests** and ARM64 checks passed; artifact `14715326297`.
- **Clip Editor — accepted for this workflow slice.** Selected-candidate playback and source-time trim, title edit, 9:16/1:1/16:9/original output, automatic/full-frame/manual-focus framing, per-clip focus persistence, timed caption preview and project-level caption styling/timing controls are implemented. Candidate IDs and saved source-time ranges are preserved. The export pipeline consumes framing overrides, resolved caption styling and timing offset; those options are included in render/caption checkpoint fingerprints so stale exports are not reused. Implementation/fix commits: `c082254b3d2c6e5b879d2841826e7facb8fc7322`, `666bab1d54df0f67e5fecaea00ad1a9b56961f33`, `3519312919e9e0c8fb97a83f73ef36b991140133`, final lint correction `3c0e7ee077364a980670982671b2c34676dc638a`. Mobile Android run [44944753374](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44944753374), **150/150 tests**, format, strict analysis, ARM64 APK and unique native-library checks passed; APK artifact `14723029272`.
- **Caption Studio — accepted for this workflow slice.** The project selector loads and saves preferences for the explicitly selected project; edits include the 12 original style presets, font, color/background, position, bold/uppercase, caption enablement and word-timing offset. The 10 motion choices remain available in the preview, but export motion is stored independently: Android MP4 currently supports only `static` and `karaoke_fill`; other preview-only selections are saved separately and export safely falls back to `static`. Legacy preference JSON remains compatible. Arabic/English preview direction and saved transcript word timings are retained. Implementation/test commits: `1d1f6408fdc8e468a359aa736c790c39d1cae559`, `6d89cb5ed63f4337b8569b6d0ce4f84f59a01283`, `8ea3d75d54b7cceb7a10dfe140439fef786453dd`, final test-copy correction `e2d3c08e9f2d4559cd931f4b461607f6012a2a95`. Mobile Android run [44953830473](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44953830473), **154/154 tests**, format, strict analysis, ARM64 APK and unique native-library checks passed; APK artifact `14727205792`.
- Detailed records: `phases/PHASE-09-CREATE-REVIEW-WORKFLOW-RECORD-2026-11-21.md`, `phases/PHASE-09-CLIP-EDITOR-WORKFLOW-RECORD-2026-11-21.md`, and `phases/PHASE-09-CAPTION-STUDIO-WORKFLOW-RECORD-2026-11-21.md`.

### Do not repeat

- Do not rebuild or restyle Create unless a specific regression is reported. Its source/configuration split, deferred save, cleanup behavior and post-save navigation are implemented and tested.
- Do not rebuild the Review workflow already accepted. Its stages, primary processing control, evidence sections and candidate-to-editor route are implemented and tested.
- The successful APK/CI checks do not count as physical-device acceptance and do not close the broader Phase 8/10 limitations. Do not repeat the accepted Create, Review, Clip Editor or Caption Studio page passes unless a specific regression is reported.

### Next Phase 9 engineering slice

**The HomeShell page extraction is complete and must not be repeated.** `CaptionStudioPage` is now independently importable under `screens/features/`; Create, Jobs, Review, Models, Clip Editor, Dashboard and Settings are also feature-scoped libraries. `HomeShell` owns composition/navigation/state, not feature-page `part` declarations. Preserve the accepted page behavior and tests. **Next Phase 9 slice: finish export gallery/delivery** (open, share and safe deletion of validated app-owned MP4 files), followed by the accessibility/golden/RTL/keyboard acceptance matrix.


## WorkManager render implementation and Android gate — 2026-11-22

- Latest Android source head: `645d2d349ecc9fe916b02a219a3ce0139f22b64a`.
- WorkManager implementation record: [PHASE-08-WORKMANAGER-BACKGROUND-RENDER-RECORD-2026-11-22.md](PHASE-08-WORKMANAGER-BACKGROUND-RENDER-RECORD-2026-11-22.md).
- Android run [44970800438](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438), run 267 — **success**: Format, strict analysis, **160/160 Flutter tests**, ARM64 APK build, ARM64-only ABI check, duplicate-native-library check and APK upload.
- APK artifact [14733448407](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733448407): 59,996,128 bytes; ZIP SHA-256 `e7bf5a4a700b6c828d434c90667d3387ef26194c341d3c1bc42a2f8a72f440b5`. Exactly `arm64-v8a`, 10 unique native libraries, no duplicate basenames.
- Coverage artifact: [14733457471](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800438/artifacts/14733457471).
- Root/desktop CI [44970800462](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44970800462), run 310 — success for checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon package validation.
- Do not equate CI with physical ARM64 process-death/background/notification or visual/media-fixture acceptance.
