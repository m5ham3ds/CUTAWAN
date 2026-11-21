# Phases 6–7 implementation record — 2026-11-21

## Scope delivered

### Phase 6 — transcript-timed Caption Studio
- Caption Studio now reads the selected project's saved transcript via `LocalProjectRepository.loadTranscript`.
- Word timings are grouped using the project's aspect ratio and live preset/font/scale/uppercase settings.
- The preview can move between timed groups; the active word is derived from the selected group's word timestamps.
- If no saved transcript exists, the Studio clearly labels its sample as a preview rather than presenting fake transcript timing.
- Caption layout budget accepts font family, scale and uppercase overrides so grouping follows current controls.
- Added a widget test for loading transcript-timed groups and changing the selected group, plus a layout-budget test.

### Phase 7 — provider consent and credential state
- Remote execution cannot be saved without persisted cloud consent.
- Stale persisted remote mode is repaired to local if consent is absent.
- The gateway blocks external provider model-list and completion requests before making HTTP calls without consent.
- Local loopback OpenAI-compatible endpoints remain available for emulator/local development.
- Removing a provider key clears its selected model; removing the active remote provider switches execution back to local.
- Added tests for stale consent recovery, no-request-before-consent and provider-scoped model deletion.

## Regression diagnosis and repair

Two failures were observed in the new transcript-preview widget test:

1. Run [44850408350](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44850408350) on SHA `e1aef789` reached 128 completed tests but timed out after 10 minutes in `caption_timed_preview_test.dart`. The test exercised an infinite `AnimationController.repeat()` and popup dropdown interaction while doing real filesystem repository I/O.
2. The first test repair isolated the animation, but run [44856922474](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44856922474) on SHA `96d1e575` showed a quick assertion failure: the test expected the exact label `المجموعة 1 من 2`, while the widget appends a formatted time range to that text.

Fixes:
- The widget test now uses `TickerMode(enabled: false)`, a normal phone viewport, an in-memory `LocalProjectRepository` test double for transcript loading, and calls the real DropdownButton callback directly instead of waiting on a popup route.
- Label assertions now inspect the keyed group-label Text and assert the stable prefix, leaving the formatted time suffix free to change.

## Latest accepted Android CI

- Run: [44857222277](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44857222277)
- Source SHA: `80e182ba840f3dc0b6e9039d39877179cb142a3e`
- Conclusion: success
- Format: passed
- `flutter analyze --fatal-infos`: passed
- Flutter unit/widget tests: **129 passed**
- ARM64 debug APK: built successfully
- APK native ABI assertion: `arm64-v8a` only
- Native library assertion: 10 unique library basenames; no duplicate native library names
- APK artifact: ID `14687879427`, size 57,695,187 bytes, ZIP SHA-256 `c7e914e2bd3f6bc6f97acf58b56d7835c4886449963723eac5ff215e70484d47`
- Coverage artifact: ID `14688092967`

## Still open

- Phase 6: synchronize the preview to actual video playback; make Flutter preview and native overlay visually consistent; verify typography, active word timing and RTL on physical videos.
- Phase 7: physical Android Keystore/backup/key-rotation tests and real provider account/model/billing/policy checks.
- Phase 8: physical MP4 fixtures and full decode validation, renderer continuity, background execution and process-death recovery remain separate acceptance work.

CI success is not physical-device acceptance.
