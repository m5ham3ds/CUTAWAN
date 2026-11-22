# Branch retirement and history-preservation audit — 2026-11-22

Repository: `m5ham3ds/CUTAWAN`  
Default branch at audit: `main`  
Main source head before archival merge: `79ddadf8a59725d4ce7a66cc47ceeddb30d84afd`  
Branch count at audit: **33 total** (main + 32 extra). No open PRs were found. Closed PR #1 is unmerged; its caption/loudness/tighten fixes are present in current main source/tests.

## Method and safety decision

All 32 extra branch heads were compared to `main` using GitHub's three-dot commit comparison. The audit found **29 branch heads with 66 unique commits** and **3 branches with no commits ahead of main**. All branches were unprotected at the time of inspection.

This repository's active product target is Flutter Android, while the root Electron/React desktop app remains preserved. Most feature branches are old snapshots, with merge bases hundreds of commits behind current main. A wholesale merge of their file trees would overwrite newer implementations, reintroduce old release versions/UI, or bring experimental third-party media/credential integrations into the product.

The functional-equivalence checks performed on current main include:
- OpenRouter provider/transcription adapters and OpenRouter tests.
- Caption active-word layer, stereo loudness refinement, limiter remeasurement, and 5ms tighten-join fades (including the associated benchmark scripts).
- Editorial/visual discovery schema bounds, editorial ranking/review, screen/presenter composition, layout memory, temporal guards and speaker-detail selection.
- Auto-zoom planner and tests, source-update relaunch retry and tests, size-target post-export warnings and tests, package-version-based Winget release tagging and tests.
- macOS updater/inference worker/package validation and lifecycle tests.

Some branches contain experimental Metachlorian/B-roll handoff, generated ClipForge launch video assets, old desktop UI/site redesign, CSS-only design foundations, or a Windows Codex/python launcher path not present in current main. They were not copied blindly into the Flutter product or current desktop tree. Their exact commit history is retained in the archive merge ancestry below, and their deferred status is documented here.

## Complete branch inventory

| Branch | Head (12 chars) | Ahead/behind | Review result |
|---|---|---:|---|
| `android-flutter-port` | `14187d9b61dd` | 0/342 | Already an ancestor of main; early Flutter port is integrated. |
| `ccr-8b709f89-hh58um` | `fbb4cd321315` | 5/362 | OpenRouter capability family is already in main (provider, transcription route, model catalogue and tests); preserve branch history, do not overwrite current adapters. |
| `ccr-72c986a6-jv6spo` | `ba23e4985837` | 3/361 | Experimental Metachlorian package handoff and remote footage/B-roll library; retained for review only. Requires rights, provenance, external-token, security and mobile architecture review before product integration. |
| `ccr-515534d3-9jh4xh` | `8cc5bab1b305` | 3/360 | Caption word-pop stability, stereo loudness/limiter refinement and tighten-join fades are present in main captions/loudness/render code with tests/benchmarks. PR #1 is closed unmerged, but current main contains these functions. |
| `claude/core-components-quality-lsnovg` | `8b89e0ac5f57` | 0/392 | Already an ancestor of main; no branch-only commits. |
| `claude/gallant-wright-9x80bu` | `7e57e562e67e` | 1/391 | Generated ClipForge /brag launch video and supporting media assets. Not merged into CUTAWAN application source because it is an old brand/demo artifact; original commit remains reachable. |
| `claude/intelligent-ptolemy-rwkam1` | `87f56e5d5667` | 4/365 | Experimental shot-style triage, webcam-panel detection and speaker/layout heuristics. Main has newer screenDetail/presenterComposition/speaker/layout modules; retain old implementations for comparison, not blind replacement. |
| `claude/session-no03x2` | `82ab57ab850d` | 2/494 | Legacy desktop navigation and deletion-confirmation fixes from July 2026. Current native Flutter project workflow differs; preserve history and re-port only a proven missing behavior. |
| `codex/adaptive-presenter-layouts` | `ce5708950742` | 3/375 | Adaptive presenter composition and bounded local analysis. Main already has clipLayout/composition/presenterComposition/screenDetail and related tests; no stale-file overlay. |
| `codex/adaptive-release-fixes` | `a013659b07f2` | 1/374 | Capped-export and composition review edge cases overlap main uploadBudget/editor cap verification and presenter composition; preserve original commit for audit. |
| `codex/cutawan-brand` | `ccf40d76f88b` | 7/387 | CUTAWAN branding is already the active product identity. Includes historical website/tablet-download CTA changes; site-specific files are not part of current app tree. |
| `codex/editorial-discovery-quality` | `705fcfe91fde` | 4/363 | Visual discovery, editorial ranking, bounded proposal schema and tests are represented by main sourceDiscovery/editorialRanking/editorialReview and test suites. |
| `codex/fix-draft-release-verification` | `ddacb1519c68` | 1/376 | Draft-release validation by release identity; main already uses version-pinned draft-aware release flow and release validation tests. Retain original commit. |
| `codex/layout-first-analysis` | `888ec22a2f5a` | 4/373 | Screen-first clipping, bounded analysis and layout migration guards overlap current clipLayout/composition/layoutMemory and test coverage. |
| `codex/layout-reuse-and-scheduling` | `777b3710adc5` | 2/372 | Verified layout reuse and bounded scheduling are represented by main layoutMemory, presenterComposition and their tests. |
| `codex/mac-stability-updates-0.10.3` | `9d0fc521f52f` | 1/377 | macOS updater/inference/package hardening; current main already has macUpdate, inference client/worker, package validation and lifecycle tests. Preserve the source commit without replacing current release code. |
| `codex/release-0.9.0` | `9494e6631f7b` | 1/390 | Historical v0.9.0 release metadata is superseded by later main version/release history; no version rollback. |
| `codex/repair-rejected-screen-bounds` | `1c04e82d59dc` | 2/370 | Geometric repair feedback and per-clip retry proposal. Main composition already has bounded repair loops; targeted per-clip retry is still a product gap and must be separately ported/tested, not declared complete. |
| `codex/selection-diversity` | `b3de4151e771` | 1/390 | Leading speaker-detail selection is explicitly present in main speaker.ts; duplicate feature change retained in history. |
| `codex/temporal-layout-guards` | `e16597b6a1d4` | 1/371 | Transient crop-collision/screen split guards overlap main temporalEdges and related layout tests. |
| `codex/video-quality-improvements` | `646bd180ff6b` | 4/391 | Quality/reframe/transcript-seam work overlaps current transcriptSeams, visualStory, visualScore, speaker and quality-benchmark modules. Its Windows python.cmd/Codex-shim fix has no matching launcher surface in the current main tree. |
| `codex/website-redesign` | `11c95799676c` | 2/389 | A separate docs/ static marketing site and binary assets; current main has no corresponding docs-site entry point. Preserved in commit history pending a decision to restore/deploy that site. |
| `cursor/auto-zoom-a650` | `a0207144df4e` | 1/531 | Auto-zoom timeline sync is represented by main shared zoom planner and zoom tests. |
| `cursor/in-app-auto-update-a650` | `86d511893857` | 1/534 | Packaged updater version handling is represented by current main updates/macUpdate and lifecycle tests. |
| `cursor/openai-compatible-endpoints-627e` | `03afb8abe453` | 1/403 | JSON-schema/object fallback and malformed-response retry are represented by current main openai provider adapter and OpenAI tests. |
| `cursor/set-up-dev-environment-8c7b` | `ca293f684301` | 0/408 | Already an ancestor of main; no branch-only commits. |
| `cursor/size-targeted-export-627e` | `ef5810b30874` | 1/408 | Actual post-export cap check and truthful over-limit messaging exist in main uploadBudget/EditorScreen and tests. |
| `cursor/source-self-update-a650` | `b8866cb9700d` | 1/518 | Source-update restart/relaunch handling exists in main updates.ts with relaunchPending and sourceUpdateRetry tests. |
| `cursor/winget-manifest-627e` | `a049ea5b969b` | 1/400 | Winget release tag is read from package.json in main release.yml; winget manifest tests are present. |
| `design/found-frame-foundations` | `4a036c45bf6b` | 1/361 | Desktop CSS token/focus/reduced-motion foundation only. Flutter has its own theme; the separate design-system asset pipeline is retained for later desktop design-system work. |
| `fix/dev-update-black-screen` | `7b0af8967823` | 1/423 | Source-update retry after failed process handover is present in main updates.ts and sourceUpdateRetry tests. |
| `fix/recover-lost-fixes` | `747d72c79a9c` | 6/365 | Contains cherry-picks of source-update retry, OpenAI fallback, size-cap and Winget fixes now represented in main, plus legacy Windows Codex/python.cmd launcher/path-with-spaces fixes and tests; launcher code has no current matching surface, so retain history. |

## History preservation

- The 3 already-merged/ancestor branch tips are already reachable from main.
- The other 29 branch heads are attached as additional parents to the archival merge commit created after this audit. The first parent is the pre-audit main head and the main tree contains this audit record; this preserves every branch-only commit/tree/blob in Git history.
- This is an **ancestry-preservation merge**, not a claim that experimental or obsolete source files were overlaid on the active main tree. Where equivalent behavior already exists in main, no duplicate implementation was copied. Where a feature is experimental, external-source dependent, desktop-only, or not present in the current architecture, the reason for deferral is recorded above.
- Closed PR #1 (`ccr-515534d3-9jh4xh`) is unmerged at the PR level; the functional changes it proposed are present in current main files/tests and its commits are retained through the archival parent.

## Branch policy from this point forward

Exactly two branch refs are allowed:
1. `main` — implementation/integration branch; source changes are committed directly here.
2. `CUTAWAN-TEST` — test-only branch; it is reset/synchronized to main and is the only branch that runs automated CI/Android workflows. No product feature development is kept exclusively on this branch.

A repository workflow will synchronize `CUTAWAN-TEST` from every main push, dispatch CI and Mobile Android tests against it, and delete any branch ref other than `main` or `CUTAWAN-TEST`. It must never delete either allowed branch. The two branch refs are verified after cleanup.

## Verified repository state after cleanup

- The two allowed branch refs were created/synchronized at `3e79df606d40a22618b2902256f05856a2ebd474`:
  - `main`
  - `CUTAWAN-TEST`
- Branch-policy workflow run [45049303735](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45049303735), run 1 — **success** for test-branch synchronization, Android/CI dispatch, and pruning.
- The cleanup job explicitly reported **32 legacy branches deleted**. A fresh GitHub branch-list read then returned exactly two refs, `main` and `CUTAWAN-TEST`; both pointed to the same SHA.
- CI 346 and Android 299 were dispatched against `CUTAWAN-TEST`. Android 299 is validating the Dashboard storage/project-resume slice after branch-governance setup.

## Scope limits

- The archival merge preserves every legacy branch-only commit in Git ancestry; it does not falsely claim experimental desktop/site/Metachlorian files were copied into the active Flutter product tree.
- It does not mark Phase 8 or Phase 10 physically accepted.
- The Dashboard test sequencing failure from Android 298 is being corrected in the main test suite; branch policy will mirror that main commit to `CUTAWAN-TEST` and rerun both validation workflows there.
