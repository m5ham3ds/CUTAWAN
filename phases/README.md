# CUTAWAN Mobile — Phase Register

**Repository:** `m5ham3ds/CUTAWAN`  
**Allowed branches:** `main` only.  
**Rule:** Continue from the last accepted commit; do not re-run completed implementation phases without a specific regression or acceptance reason. Commit product changes and validation-only changes directly to `main`. Do not create or synchronize a secondary test branch.

## Baseline and latest verified Android state

- Latest accepted Mobile Android run: [45313033547](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033547), run **379**, source SHA `7b6122f33d5aecb4e9d5be1ef3d0080a6b452376` — **success**.
- Dart format and `flutter analyze --fatal-infos`: passed.
- Flutter unit/widget suite: **228/228 tests passed**. Coverage includes the 24 committed page golden comparisons, page Enter/Tab actions, the page-level Tab target inventory for Dashboard, Settings and Models Center, Device Diagnostics refresh/details/report-copy focus targets, the four-page landscape/simulated-safe-area matrix, the conditional remote-model test action, plus clip-preview crop-alignment edge/center geometry and invalid-region rejection.
- The landscape matrix simulates horizontal/top/bottom insets through `MediaQuery.padding/viewPadding`; it does not replace real Android cutout, gesture-navigation, edge-to-edge or OEM handset review.
- ARM64 debug APK: built and uploaded; the workflow verified exactly `arm64-v8a`, **10 unique native libraries**, GGML runtime present (`libggml-cpu.so`, `libggml.so`, `libggml-base.so`) and no duplicate native-library basenames.
- APK artifact [14883968118](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033547/artifacts/14883968118): **60,050,476 bytes** (artifact archive); SHA-256 `ddb8220ac7be93152208840913ba48e32457707d7d622338a756ff46d10a9eca`.
- Coverage artifact [14883749112](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033547/artifacts/14883749112): **19,611 bytes**; archive SHA-256 `2279ccb0a42bc59f96b9284d15db80c62b02a9b0e629f7e8a36f221131e4e5ff`.
- Root/desktop CI [45313033480](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033480), run **431** — **success** across checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon package validation.
- Branch Policy [45313033620](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033620), run **81** — **success**; the repository has only `main`.
- The 228-test suite includes an ordered page-level Tab target inventory: Dashboard settings/create/storage refresh/navigation/recent-list action; Settings diagnostics/models/theme/reduced-motion controls; Models Center local model install/removal, segment selection, cloud consent, provider/key fields, save/delete, fetch and refresh actions. A separate conditional remote-model test covers the provider action with a fake gateway. Device Diagnostics coverage reaches refresh, expands technical details and reaches JSON report copy. These widget tests establish the declared targets are reachable in the recorded sequence; they are not a physical Android keyboard audit. Focus-style assertions cover button/input outline width and contrast in light/dark themes, while focus goldens cover representative controls only. Rasterized ListTile/SwitchListTile/chip focus visibility, actual hardware Tab behavior, real system bars/cutouts and OEM rendering remain field gates.

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
| 8 | End-to-end pipeline, job orchestration and clip export | Media3 full-track decode validation, deterministic checkpoints, WorkManager foreground worker, durable completion handoff, project-scoped cancellation and render notifications implemented; automated Android gates passed on run 267 | Physical ARM64 fixture/lifecycle/OEM tests remain open; targeted per-clip retry remains open |
| 9 | Professional UI redesign and navigation/component architecture | Accepted workflows, responsive/accessibility matrix, Filmstrip thumbnails, source-time focus keyframes, per-clip fades, sequence composition and visually verified dip-to-black clip transitions; Android run 413 passed 256/256 tests and ARM64 packaging | Still open: pixel-measured Clip Editor preview/export parity and physical ARM64 handset accessibility/visual acceptance; dip-to-black is visual-only and has no audio crossfade |
| 10 | Physical-device quality, security, performance and Arabic/English acceptance | Diagnostic workbench and automated baseline tests implemented; physical acceptance incomplete | Still needs human-confirmed handset report, hashed media corpus, WER/timing, on-device full decode, thermal/battery and lifecycle/consent evidence |

## Global engineering constraints

1. Root Electron desktop remains intact. Flutter Android is a sibling application.
2. Only `main` is allowed. Product source, automated tests and validation-only changes are committed directly to `main`. Branch Policy fails if any secondary branch exists. CI runs from `main`; do not create or synchronize a test branch.
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
2. Keep Phase 8 acceptance open until a physical ARM64 device run validates background completion, relaunch/recovery, cancellation notification, long/VFR/rotated/no-audio/silent/corrupt fixtures, crop/caption continuity, audio and full decode. Targeted per-clip retry remains separate product work.
3. Phase 9 HomeShell extraction is accepted on `d30695cf38c7fb1dd009427c3da8c029921e4a17`; see `PHASE-09-HOME-SHELL-SCREEN-EXTRACTION-RECORD-2026-11-22.md`. Do not repeat the page extraction or redesign the accepted Create, Review, Clip Editor, Caption Studio or Jobs workflows unless a regression is found.
4. Dashboard storage/quick-resume, persisted Settings, page Enter paths, 24 page goldens, page-level keyboard/focus inventory, the four-page landscape/simulated-safe-area matrix and the conditional Models Center remote-model test action remain accepted. The Clip Editor automated slices now also include native Filmstrip thumbnails, source-time keyframes, per-clip fades, sequence composition and dip-to-black transitions; Android run 413 on SHA `1e7f26c` passed 256/256 tests, strict analysis, Media3 frame assertions, ARM64-only ABI/native-library verification and APK upload. Do not repeat these accepted slices. The next Phase 9 engineering slice is pixel-measured preview/export parity. Physical ARM64 handset review of hardware Tab behavior, rendered focus visibility, RTL/landscape/large text and actual system bars/cutouts/OEM behavior remains a separate open gate.
5. Keep Phase 8 physical render/lifecycle and Phase 7 Keystore/provider acceptance open. Phase 10 starts only after Phase 9's remaining editor-scope and handset gates are accepted; it then requires real ARM64 fixture/quality/security/performance evidence below.

Phases 1–7 have a successful automated Android gate on SHA `80e182b`; physical-device checks and phase-specific quality acceptance are still separate and must not be inferred from CI.

## Phase 9 export gallery and delivery — 2026-11-22

- Implemented export-card **open**, **share** and confirmed **delete** actions for MP4 records that have both `validated == true` and `fullyDecodeValidated == true`.
- Android checks that MediaStore content URIs are published MP4s in `Movies/CUTAWAN/` owned by this package. Older app-owned file exports are exposed through a FileProvider confined to CUTAWAN export folders; arbitrary file/content URIs are rejected.
- Successful native deletion is followed by removal of the matching project export record. A failed native deletion leaves the record visible.
- Added MethodChannel service tests, repository record-deletion tests, and a 320dp RTL Review gallery interaction test covering open/share/confirm-delete.
- The first Android attempt exposed a widget-test timing defect: the test tapped a card before `ensureVisible` scrolling had settled. The test now pumps to a stable viewport before each tap; no production action behavior was changed for that failure.
- Final source SHA: `6b9ba1f4689c98567c6eb677d4d05e6037945616`.
- Android run [45034907917](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907917), run 286 — **success**: format, strict analysis, **172/172 tests**, ARM64 APK build, ARM64-only ABI verification, no duplicate native libraries and APK upload.
- APK artifact [14759537141](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907917/artifacts/14759537141): 59,998,467 bytes; archive SHA-256 `7be81d04380f9e981ec20e21a2b83ab692190fb518251467ee338026584a5617`.
- Coverage artifact [14759420912](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907917/artifacts/14759420912): 17,293 bytes.
- Root/desktop CI [45034907987](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907987), run 330 — **success** across checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon package validation.
- Physical testing of the chooser, third-party player access, old FileProvider paths and deletion against actual Android MediaStore remains part of handset acceptance; mocked widget tests do not replace it.

**Decision:** accept export gallery/delivery as an automated workflow slice. Proceed to the Phase 9 accessibility and responsive UI matrix.

## Phase 9 accessibility and responsive UI matrix — 2026-11-22 (in progress)

- Initial accessibility slice passed on source SHA `deecbd57744b2f06e6d989cec55cdd2f3dc70f3b`.
- Android run [45036283358](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283358), run 289 — **success**: Dart format, strict analysis, **174/174 Flutter tests**, ARM64 APK build, ARM64-only ABI and unique-native-library checks, and artifact upload.
- Compact HomeShell top-bar icon actions now have 48x48dp targets without changing their icon glyphs or callbacks.
- All five primary navigation destinations are covered for semantic labels/button roles/tap actions/selected state and minimum 48dp height at 320dp in RTL/LTR and light/dark Material 3.
- Top-bar actions are verified at 48x48dp with labels and working callbacks on a compact 320dp RTL viewport.
- APK artifact [`cutawan-mobile-arm64-debug`, ID 14760086606](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283358/artifacts/14760086606): 59,998,882 bytes; ZIP SHA-256 `d74b241347bad571eed7dc0431c5ec228f526d0a1fea58b81836e00481368de4`.
- Coverage artifact [14760176118](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283358/artifacts/14760176118): 17,311 bytes.
- Root/desktop CI [45036283366](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45036283366), run 333 — **success** across checks, Xvfb UI smoke, offline FFmpeg/render pipeline and Apple Silicon packaging.
- Two test-only failures in earlier attempts were corrected: modern Flutter semantics are asserted through `flagsCollection`/semantics data, and the semantics handle is explicitly disposed after the matrix. Production navigation behavior was not changed to mask those test failures.
- Broader matrix remains open: increased system text scale and no-clipping checks, focus traversal/keyboard activation, landscape, safe-area insets, light/dark RTL/LTR golden comparison and real handset UI acceptance.

## Phase 9 Dashboard, Settings, Models and Diagnostics responsive slice — 2026-11-22

- Final automated source SHA: `eabc20e3c7494a2030668bcac35a177881821e3b`.
- Dashboard: centered content capped at 880dp, compact/wide horizontal padding, adaptive metric grid (2/3/4 columns), and wrapped action/recent-project labels. Widget tests cover 320dp RTL at 200% text, 390dp LTR at 150%, 720dp RTL, and each route callback.
- CUTAWAN Settings: centered content capped at 760dp with responsive padding and grouped device, accessibility, privacy and legal sections. The appearance row follows Android system theme; it is explanatory rather than a fake toggle. The reduced-motion row also remains descriptive until a persisted setting exists.
- Models Center: centered content capped at 820dp, compact header and model-status stacking under narrow width, wrapped action controls. Widget layout tests use injected availability results to avoid real filesystem I/O; production still uses Whisper catalog lookup and Qwen file size/SHA verification.
- Device Diagnostics: the page distinguishes baseline metadata collection from field-test execution. Narrow detail/evidence rows stack under 350dp. The report explicitly says `physicalMediaTestsExecuted == false`; the current collector measures device metadata and performs one temporary secure-storage write/read/delete self-test only.
- Android run [45043179789](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789), run 296 — **success**: Format, `flutter analyze --fatal-infos`, **183/183 Flutter tests**, ARM64 debug APK build, ARM64-only ABI check, 10 unique native libraries/no duplicate basenames, and artifact upload.
- APK artifact [14763285423](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789/artifacts/14763285423): 60,020,680 bytes; archive SHA-256 `8954f75e5b9e81f611cc52c233b04067b5be81983113d7d14d0250b1c8200308`.
- Coverage artifact [14763115567](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179789/artifacts/14763115567): 17,699 bytes.
- Root/desktop CI [45043179788](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45043179788), run 341 — **success**: checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon packaging.
- Earlier Android attempts were corrected in sequence: run 291 formatting caught a malformed ModelsPage list closure; run 292 analysis caught a redundant test import; runs 293/294 exposed lazy-list scrolling, filesystem I/O in widget tests, and diagnostics text-wrap assumptions; run 295 exposed the real Settings ListTile/Chip overflow at 200% text. The final run 296 passed after these fixes.
- **Still open:** Dashboard does not yet display the available storage usage that is already supplied to Jobs via `HomeShell.storageUsageBytes`, and its recent-project tap opens Review rather than a project-aware resume action. Settings remains a grouped navigation/information page; actual stored appearance/language/export/accessibility preferences must be wired only when their backing state exists. Golden comparison and physical handset visual acceptance remain separate gates.

**Decision:** accept the responsive presentation slice for these four screens as an automated slice. Do not mark Phase 9 complete.
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
8. On a physical ARM64 handset, verify WorkManager background completion/relaunch recovery, notification action, cancellation latency, OEM battery restrictions and the difference between ordinary process death and explicit force-stop. The Activity-owned render map was removed by the 2026-11-22 WorkManager implementation; do not repeat that extraction.

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

### Next Phase 9 engineering slice — current as of 2026-11-23

- Accepted and do not repeat: Dashboard storage/quick-resume, persisted Settings theme/reduced-motion, four focus-plus-Enter actions, 24 saved page goldens, page-level keyboard/focus coverage, four landscape/safe-area page checks, native Filmstrip thumbnails, source-time focus keyframes, per-clip fades and clip-sequence dip-to-black transitions. Android run 413 passed 256/256 Flutter tests, Media3 frame assertions, ARM64-only ABI verification and APK upload.
- The landscape tests cover 720×320 and 844×390 with modeled horizontal/top/bottom insets, RTL/LTR, light/dark themes and 1.5×/1.0× text scaling. They assert page viewport/action bounds against the simulated safe rectangle.
- Next complete the per-control Tab-stop inventory and visual focus-indicator contrast/pixel review, then perform physical ARM64 handset visual/accessibility review using actual Android system bars/cutouts and OEM behavior.
- Phase 9 and Phase 10 remain in progress.


## Latest Phase 9 keyboard/focus extension — 2026-11-23

- Source SHA: `0835c19d00cf770c17fa48fd3e8252b2bf77e6a4`.
- Android run [45209870754](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45209870754), run 359 — **success**: format, `flutter analyze --fatal-infos`, **213/213 Flutter tests**, ARM64 APK build, ARM64-only ABI verification, 10 unique native-library/no-duplicate checks and APK upload.
- The additional Tab cases reach the Device Diagnostics JSON-copy action and the installed-model removal/saved-provider-key removal controls in Models Center. The existing page matrix also exercises representative ordered targets on Dashboard, Settings and Models Center.
- `focus_indicator_contrast_test.dart` asserts at least 3:1 contrast for focused Material button outlines and the focused text-field border in both themes. For ListTile, SwitchListTile and chips, this test currently checks that the shared focus overlay is configured; it does not measure the resulting rendered pixel contrast.
- APK artifact [14836142069](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45209870754/artifacts/14836142069): 60,024,888 bytes; archive SHA-256 `ead7c527999842a831d93a837c0e4a45853b42239fe33c950e01dd6119b2ce66`. Exactly `arm64-v8a`, 10 unique native libraries, GGML present, no duplicate basenames.
- Coverage artifact [14835623220](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45209870754/artifacts/14835623220): 18,639 bytes; SHA-256 `8dff1bb3b1beebda56ce896290871fe1f2a4cdb97bb3653ef038f96de5e3ad93`.
- Root/desktop CI [45209870719](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45209870719), run 408, attempt 2 — **success** across desktop checks, Xvfb UI smoke, offline FFmpeg/caption/render and Apple Silicon package verification. The first FFmpeg attempt failed only during dependency-network access to `onnxruntime-node`; rerunning that failed job alone succeeded.
- Branch Policy [45209870742](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45209870742) — **success**, confirming `main` is the only branch.

**Decision:** accept this automated keyboard/focus extension. Do not mark Phase 9 complete yet. Remaining gates are: enumerate any still-uncovered focusable controls (including the conditional remote-model test action), verify focus appearance on the rendered ListTile/switch/chip/button/input states, and perform actual handset landscape/safe-area/RTL/large-text visual review. Phase 10 remains a separate physical-media, performance, privacy and lifecycle acceptance phase.


## Latest conditional provider-action keyboard gate — 2026-11-23

- The conditional Models Center action **اختبار النموذج فعلياً** is now exercised after the lazy provider list is scrolled into view and a fake gateway returns one model. The test enters the rendered button through natural Tab focus, sends Enter, and asserts exactly one fake gateway test call.
- The test uses an in-memory credential store, a test-only API key, explicit test consent and a fake `AiModelGateway`; it performs no network request and does not read real user credentials.
- The first failed attempts were test-harness issues, not product regressions: `DropdownButtonFormField`/button wrappers did not expose the semantics/finder shape the test assumed, and the provider controls are in a lazy `ListView`. The final test finds the rendered labels only after `scrollUntilVisible`, taps the already-covered model-fetch action, then tests the conditional model-test button with the composite-focus helper.
- Android run [45267350030](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45267350030), run 366, source SHA `8593354bdaf583178ad4d86c20c6767dcd1b4e0e` — **success**: Dart Format, `flutter analyze --fatal-infos`, **214/214 tests**, Coverage Upload, ARM64 debug APK build, ARM64-only ABI verification, 10 unique native libraries/no duplicate basenames, and APK upload all passed.
- APK artifact [14862589238](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45267350030/artifacts/14862589238): 60,026,013 bytes (artifact archive); SHA-256 `b3a222233501c9f3865cfe35ef48433cbeb83e8d9b3bfafded0b27e1b5f486b8`. Verified ABI: exactly `arm64-v8a`; GGML libraries `libggml-cpu.so`, `libggml.so`, `libggml-base.so` present.
- Coverage artifact [14862963339](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45267350030/artifacts/14862963339): 18,667 bytes; SHA-256 `ad150d6495a3b3985ef36609a8901f9620080afd9f2eaa7b7fbc12c3307f1e0b`.
- Desktop CI [45267349925](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45267349925), run 416 — **success** across checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon package verification.
- Branch Policy [45267349999](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45267349999), run 66 — **success**; `main` is the only branch.

**Decision:** accept this additional automated conditional-action slice. Phase 9 remains open only for the remaining exhaustive Tab-stop review and actual handset visual/accessibility acceptance. Do not start Phase 10 until those Phase 9 device gates have evidence.


## Phase 9 clip-sequence dip-to-black transition acceptance — 2026-11-25

- Added a validated sequence-level clip-to-clip dip-to-black transition, with visual fade-out on the outgoing clip and fade-in on the incoming clip. Transition metadata remains attached to the clip boundary; duration and adjacency constraints are validated before export.
- Media3 renders the fade on the final Composition timeline rather than on per-item timestamps. The composition overlay calculates opacity from each frame's presentation timestamp and clears its reusable CanvasOverlay bitmap with PorterDuff.Mode.CLEAR before drawing.
- The clear is required because Media3 CanvasOverlay caches and reuses its backing bitmap and Canvas between getBitmap() calls. Without clearing, a previous fully black frame remains painted over later frames even when the calculated fade opacity decreases.
- The transition is visual-only. It does not crossfade audio and does not implement a full multitrack audio mix.
- Android instrumentation uses a deterministic FFmpeg-generated 160×120, 15fps red-to-blue MP4 and samples five exported frames: before fade-out (200ms), during fade-out (866ms), at the join (1000ms), during fade-in (1133ms), and after the transition (1800ms). All five pixel assertions passed on the Android 15 emulator.
- Mobile Android run [45500607722](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45500607722), run 413, source SHA `1e7f26c71e9b84888eff2dc33bfa6c1315a8ea51` — success: format, strict analysis, 256/256 Flutter tests, ARM64 debug APK build, Media3 instrumentation test, ARM64-only/unique-native-library verification and APK upload all passed.
- APK artifact [14970744768](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45500607722/artifacts/14970744768): 60,128,793 bytes. The workflow verified exactly arm64-v8a, 10 unique native libraries, libggml-cpu.so, libggml.so and libggml-base.so, with no duplicate native-library basenames.
- Coverage artifact [14971206974](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45500607722/artifacts/14971206974): 21,369 bytes.
- Desktop CI [45500607475](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45500607475), run 465 — success across checks, Xvfb UI smoke, offline FFmpeg/caption/render pipeline and Apple Silicon packaging.
- Branch Policy [45500607649](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45500607649), run 115 — success; main is the only branch.

**Decision:** accept the automated clip-sequence transition slice. Phase 9 remains in progress; physical ARM64 handset review is still not evidenced. Next engineering slice: capture and compare the actual Clip Editor preview against the Media3-exported frame at matched timestamps, including crop boundaries, automatic/manual framing, keyframe interpolation, fit gaps, aspect-ratio changes and fade/caption overlays. Do not start Phase 10 until the remaining Phase 9 pixel-parity and handset gates are recorded.
