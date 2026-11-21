# CUTAWAN Mobile — Phase Register

**Repository:** `m5ham3ds/CUTAWAN`  
**Working branch:** `main` only.  
**Rule:** Continue from the last accepted commit; do not re-run completed implementation phases without a specific regression or acceptance reason.

## Baseline and verified state

- Last validated Mobile Android snapshot before the current PCM-reader changes: [run 44842722337](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44842722337) on SHA `377fe3a68e4377a790bb212bcfd06534e0380588` — success. It passed format, analysis, **95 Flutter tests**, ARM64 APK build, and ABI/native-library assertions. This is historical evidence, not validation of the newer PCM reader.
- That run's APK artifact: `cutawan-mobile-arm64-debug`, artifact ID `14681668484`, ZIP size 57,666,193 bytes.
- Root CI run [44841967682](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44841967682) succeeded for desktop workflows; it does not validate Flutter Android.
- CI success does not prove physical-device inference accuracy, SAF lifecycle, Android Keystore behavior, or final video rendering/export. The latest mobile workflow must be checked against its exact source SHA.

## Phase matrix

| Phase | Scope | Current state | Evidence / constraint |
|---|---|---|---|
| 1 | Flutter Android shell, basic navigation and ARM64 packaging | Implemented; automated gates passed | Device installation and OEM behavior still required |
| 2 | Media import, direct video download, project persistence and lifecycle | Implemented; automated gates passed | Real SAF provider/process-death testing remains open |
| 3 | Local Whisper transcription and model manager | Bounded mono/16kHz PCM reader, low-pass resampling and chunk planner implemented; current CI/device acceptance pending | WER/timing/alignment and thermal/memory evidence absent; VAD not implemented |
| 4 | Candidate discovery, evidence, ranking and local Qwen annotations | Implemented foundation; editor review open | Proposes candidates but does not cut/render video; visual signal is frame-change only |
| 5 | Face sampling and validated reframing plans | Implemented foundation; renderer acceptance open | Not active-speaker recognition; no completed clip render |
| 6 | Caption Studio visual presets, motion preview, RTL and preference persistence | Implemented preview/domain foundation | Preview is not transcript-timed and is not the MP4 exporter |
| 7 | Multi-provider model selection, secure user credentials, consented cloud editorial annotations | Implemented; automated gates passed on main | Physical Keystore validation, real provider account/model compatibility, billing and policy acceptance remain open |
| 8 | End-to-end pipeline, job orchestration and clip export | Implementation in progress; real MP4 trim/export and verification foundations added | Dynamic reframing, burned-in captions, full decode, process-death render recovery, fixture and physical-device gates remain open |
| 9 | Professional UI redesign and navigation/component architecture | First slice delivered; screen parts and shared Material 3 themes added | Full information architecture, isolated feature boundaries, Clip Editor, accessibility, golden/RTL/responsive matrix and device evidence remain open |
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

## Execution order agreed on 2026-11-21

Implement and gate in this order: Phases 1–3 together; then Phases 4–5; then Phases 6–7; then Phase 8; then Phase 9 once (the repeated 9 in the request is one phase); finally Phase 10. Later groups start only after the previous group has code and automated evidence. Physical-device requirements remain separate and cannot be inferred from CI.

## Execution order agreed on 2026-11-21

Implement and gate in this order: Phases 1–3 together; then Phases 4–5; then Phases 6–7; then Phase 8; then Phase 9 once (the repeated 9 in the request is one phase); finally Phase 10. Later groups start only after the previous group has code and automated evidence. Physical-device requirements remain separate and cannot be inferred from CI.

## Current next actions

1. Finish the current Phases 1–3 gate: verify the current Mobile Android run, then record physical SAF/process-death tests and Arabic/English Whisper WER and word-timing evidence.
2. After that gate, complete Phases 4–5 together, including candidate evaluation and reframing quality tests.
3. Then complete Phases 6–7 together, including transcript-timed caption UI foundations and secure provider/Keystore device checks.
4. Continue to Phase 8: finish dynamic reframing, burned-in captions, full MP4 decode/validation, durable background recovery and per-clip retry.
5. Then Phase 9: finish the full phone-first screen architecture, Clip Editor, feature boundaries, golden/RTL/accessibility/responsive tests.
6. Finally Phase 10: complete physical ARM64 Arabic/English quality, privacy, thermal, battery and performance acceptance.
5. Do not mark Phases 3–10 fully accepted until their specific device and output evidence is attached.

## Branch and upstream integration audit — 2026-11-21

- Added `docs/BRANCH-FEATURE-AND-SOURCE-INTEGRATION-AUDIT-2026-11-21.md`.
- Audited representative feature-bearing branches against main; stale snapshots are not merged wholesale. The audit maps branch scope, mobile equivalents, source-project roles and outstanding Flutter gaps.
- Flutter remains the product implementation target. Desktop root CI success is not mobile acceptance.
- Phase 8 remains in progress: dynamic reframe, burned-in transcript-timed captions, full decode, process-death rendering recovery, per-clip retry and physical-device gates remain open.
- Phase 9 remains in progress: production Clip Editor, full screen/navigation architecture, feature boundaries, golden/RTL/accessibility/keyboard matrix and physical UI evidence remain open.
- Phase 10 remains incomplete: physical ARM64 accuracy, lifecycle, security, thermal, battery and performance evidence is required.
- No branch merge or algorithm parity claim was made by the audit. Each port must have Dart/Kotlin code, upstream provenance/license and tests.
