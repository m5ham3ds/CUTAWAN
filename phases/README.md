# CUTAWAN Mobile — Phase Register

**Repository:** `m5ham3ds/CUTAWAN`  
**Working branch:** `main` only.  
**Rule:** Continue from the last accepted commit; do not re-run completed implementation phases without a specific regression or acceptance reason.

## Baseline and verified state

- Current verified mainline: `4a9c8b3a22c62390ab43d1c5e84e90a7fa16fc95`.
- Latest Mobile Android workflow: [44767326112](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44767326112) — success. It passed script syntax validation, Android generation, dependency resolution, Dart format, `flutter analyze --fatal-infos`, the complete **79-test** Flutter suite, ARM64 APK build, ABI/native-library validation, and artifact upload.
- Latest root CI workflow: [44767326104](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44767326104) — success across checks, offline pipeline, UI smoke and packaged inference/export.
- APK artifact: `cutawan-mobile-arm64-debug`, artifact ID `14643739562`, ZIP size `54,394,021` bytes. Extracted APK size `95,279,731` bytes; SHA-256 `47b205348a5731aced8bfd50c56ebb46cbd08e2c6b8b2f8e6e14f9a5e86d31da`.
- Native packaging check: exactly `arm64-v8a`, 10 native libraries, no duplicate .so basenames, and all required Whisper/llama libraries present.
- Flutter coverage artifact: ID `14646152189`.
- These CI results validate the recorded commit. They do not prove real-device inference accuracy, actual Android Keystore lifecycle, full video rendering/export, account billing/access, or third-party model quality.

## Phase matrix

| Phase | Scope | Current state | Evidence / constraint |
|---|---|---|---|
| 1 | Flutter Android shell, basic navigation and ARM64 packaging | Implemented; automated gates passed | Device installation and OEM behavior still required |
| 2 | Media import, direct video download, project persistence and lifecycle | Implemented; automated gates passed | Real SAF provider/process-death testing remains open |
| 3 | Local Whisper transcription and model manager | Implemented foundation; device acceptance open | WER/timing/alignment and thermal/memory evidence absent; VAD not implemented |
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

## Current next actions

1. Perform physical-device checks for Phase 7: key save/replace/delete, backup disabled, restore/reinstall behavior, cloud-consent gating and provider success/failure without exposing secrets.
2. Continue Phase 8 by applying frame-level reframe plans and timed captions to MP4 output, then add full decode, fixture, process-death and physical-device acceptance.
3. Continue Phase 9 by completing screen architecture, Clip Editor, golden/RTL/accessibility/keyboard tests and device review.
4. Complete Phase 10 with Arabic/English media fixtures and physical ARM64 quality, privacy, thermal and performance evidence.
5. Do not mark Phases 3–10 fully accepted until their specific device and output evidence is attached.
