# CUTAWAN Mobile — Phase Register

**Repository:** `m5ham3ds/CUTAWAN`  
**Working branch:** `main` only.  
**Rule:** Continue from the last accepted commit; do not re-run completed implementation phases without a specific regression or acceptance reason.

## Baseline and verified state

- Existing mainline: `06fee1ca9e042f2505b9314d1495eb127b1d7220`.
- Last verified Mobile Android workflow: [44751288974](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44751288974) — success. It passed Flutter format, static analysis, Flutter test suite, ARM64 debug APK build and native-library/ABI assertions.
- Last verified root CI workflow: [44751289006](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44751289006) — success.
- These CI results validate the state of that commit only. They do not prove real-device inference accuracy, secure-storage lifecycle, full rendering/export, or third-party model access.

## Phase matrix

| Phase | Scope | Current state | Evidence / constraint |
|---|---|---|---|
| 1 | Flutter Android shell, basic navigation and ARM64 packaging | Implemented; automated gates passed | Device installation and OEM behavior still required |
| 2 | Media import, direct video download, project persistence and lifecycle | Implemented; automated gates passed | Real SAF provider/process-death testing remains open |
| 3 | Local Whisper transcription and model manager | Implemented foundation; device acceptance open | WER/timing/alignment and thermal/memory evidence absent; VAD not implemented |
| 4 | Candidate discovery, evidence, ranking and local Qwen annotations | Implemented foundation; editor review open | Proposes candidates but does not cut/render video; visual signal is frame-change only |
| 5 | Face sampling and validated reframing plans | Implemented foundation; renderer acceptance open | Not active-speaker recognition; no completed clip render |
| 6 | Caption Studio visual presets, motion preview, RTL and preference persistence | Implemented preview/domain foundation | Preview is not transcript-timed and is not the MP4 exporter |
| 7 | Multi-provider model selection, secure user credentials, consented cloud editorial annotations | Provider adapters/UI/test foundation in this changeset | Physical Keystore validation, API account/model compatibility and provider policy acceptance remain open |
| 8 | End-to-end pipeline, real-time job orchestration, editor timeline and FFmpeg export | Planned; not complete | Requires rendering design, checkpoints, cancellation/resume and output verification |
| 9 | Professional UI redesign and navigation/component architecture | Planned in depth; existing monolithic screen still needs refactor | Do not claim a full redesign has been delivered |
| 10 | Physical-device quality, security, performance and Arabic/English acceptance | Planned; incomplete | Needs representative real-video corpus and Android devices |

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

## Current next actions

1. Complete Phase 7 provider integration, secure storage and contract tests.
2. Run Mobile Android and root CI, repair failures before extending the UI.
3. Physical-device check: key save/replace/delete, backup disabled, reinstall/restore behavior, remote-consent gating and provider request success/failure without logging secrets.
4. Start Phase 8 by wiring the processing state machine to persisted jobs and artifacts, then add real clip rendering and output validation.
5. Start Phase 9 by extracting the large `home_shell.dart` into separate feature screens/components using a consistent Material 3 design system.
6. Do not mark Phase 3–10 complete until their listed acceptance evidence is attached.
