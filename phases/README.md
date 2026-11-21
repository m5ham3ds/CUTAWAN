# CUTAWAN Mobile — Phase Register

**Repository:** `m5ham3ds/CUTAWAN`  
**Working branch:** `main` only.  
**Rule:** Continue from the last accepted commit; do not re-run completed implementation phases without a specific regression or acceptance reason.

## Baseline and latest verified Android state

- Latest Mobile Android run: [44857222277](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44857222277) on SHA `80e182ba840f3dc0b6e9039d39877179cb142a3e` — **success**.
- It passed format, `flutter analyze --fatal-infos`, **129 Flutter unit/widget tests**, ARM64 debug APK build, and the native-library assertion.
- The APK check found exactly one packaged ABI (`arm64-v8a`) and 10 unique native libraries, with no duplicate native library basenames. Whisper/llama GGML shared libraries were present.
- APK artifact: `cutawan-mobile-arm64-debug`, artifact ID `14687879427`, ZIP size 57,695,187 bytes; archive SHA-256 `c7e914e2bd3f6bc6f97acf58b56d7835c4886449963723eac5ff215e70484d47`.
- Coverage artifact: `cutawan-mobile-flutter-coverage`, artifact ID `14688092967`.
- Root/desktop CI is separate and does not validate Flutter Android.
- This CI run validates compilation and automated tests only. It does not prove physical-device inference accuracy, SAF lifecycle, Android Keystore behavior, full MP4 decode, or background render recovery.

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
| 8 | End-to-end pipeline, job orchestration and clip export | Media3 Transformer pipeline consumes time-ranged reframe segments and timed caption cues; native overlay burns captions into MP4; metadata/hash verification exists | Full decode validation, physical visual/media fixtures, render recovery after process death, background execution/notifications and per-clip retry remain open |
| 9 | Professional UI redesign and navigation/component architecture | Dashboard, Settings route, five primary destinations and a functional playback/trim editor slice delivered; still in progress | Feature-state extraction, filmstrip/focus/transition editing, preview/export parity, accessibility/golden/device matrix remain open |
| 10 | Physical-device quality, security, performance and Arabic/English acceptance | Diagnostics instrumented; acceptance incomplete | Native device baseline + temporary secure-storage self-test added; still needs physical media corpus, WER/timing results, full-decode and lifecycle/thermal evidence |

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

1. Continue Phase 8 from the existing Media3 implementation: add full output decode validation and recoverable background render-session state without repeating completed provider/caption work.
2. Validate dynamic reframe and burned-in Arabic/English captions against physical ARM64 fixture videos, including portrait/landscape, scene cuts, silence and missing-face intervals.
3. Add process-death/relaunch, notification, cancellation, and per-clip retry acceptance for rendering.
4. Continue Phase 9 after Phase 8 automated gates: full phone-first navigation/screen architecture, Clip Editor, accessibility, golden/RTL/responsive tests.
5. Finish Phase 10 with physical ARM64 quality, privacy, thermal, battery, lifecycle and performance acceptance.

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
