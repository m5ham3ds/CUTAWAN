# Android implementation record — Phases 5 and 6

**Repository:** `m5ham3ds/CUTAWAN`  
**Target:** `main`  
**Scope:** Flutter Android companion. The existing desktop application and its pipeline remain untouched.

## Phase 5 — face-guided reframing foundation

Implemented:

- Added a bounded native Android `analyzeFaces` method using `MediaMetadataRetriever` and the Android platform face detector. It samples at most 160 frames, scales each sample so its largest dimension is at most 320 pixels, and records empty samples as well as detections so missing frames count against coverage.
- When several frontal faces appear in a frame, the bridge favours face confidence, size and continuity with the previous selected centre. It returns normalized face geometry, timestamps and a focus score.
- Added Dart `FocusTrack`, `ReframeShot` and `ReframePlan` contracts with geometry, source-time, score and complete-timeline validation.
- Added `ReframePlanner`: faces smaller than 96 source pixels, samples below 0.65 score, insufficient track coverage, or low average confidence do not produce automatic crops. It requires at least 30% valid coverage and 0.55 average confidence; otherwise it creates a full-frame `fit` plan. Crop plans retain the selected portrait, square, landscape or original aspect ratio.
- Reframe shots must cover the source from timestamp zero to its exact end, without overlaps or gaps. Duplicate timestamps do not inflate coverage.
- Added `AndroidReframeAnalysisService`, a Review-page action, and a per-project `reframe.json` artifact. A saved plan can be loaded and validated after app restart.

**Important limits — not a completed active-speaker system:**

- The platform detector is a frontal-face detector. It does not reliably cover profile faces, occlusion, very small faces, or screen-only footage.
- The focus score is based on detector confidence, face size and position continuity. It is not LR-ASD, mouth-motion/audio correlation, speaker diarization, or proof that the selected face is speaking.
- The Flutter app currently stores and reviews a crop plan; it does not yet apply the plan to a rendered video. Pan easing, scene-aware composition layers, speaker split-screen and export are still renderer work.
- Golden-footage subject-retention review and real-device timing/memory measurements have not been recorded. The phase 5 acceptance gate remains open.

## Phase 6 — Caption Studio

Implemented:

- Retained all 12 caption style IDs from CUTAWAN's existing `src/shared/captionStyles.ts`: Beast, Karaoke, Pill, Minimal, Hormozi, Neon, Ember, Bubble, Lemon, Retro, Crimson and Whisper.
- Bundled the corresponding original Anton and Poppins font files from `resources/fonts/` in the Flutter app, with the original SIL Open Font License texts included and listed in the dependency inventory.
- Added ten independent animation modes: Static, Karaoke Fill, Word Pop, Bounce, Fade, Slide, Typewriter, Glow Pulse, Highlight Sweep and Staggered Words. Typewriter reveals Unicode characters; Staggered Words reveals one word after another.
- Added a live Flutter preview, Arabic/English switch, RTL/LTR direction, editable font family, font size, vertical position, text/highlight/background colors, uppercase and bold controls, plus a safe-frame overlay.
- Caption style, motion, colors, font family, size, position, uppercase and bold settings persist in the selected project's existing preferences. Old projects load with their preset defaults.
- Added the pure-Dart caption layout engine: style-dependent line-width budgets, no more than two lines, punctuation and pause boundaries (including Arabic punctuation), and a bounded caption hold. This is covered by unit tests.

**Important limits — preview/export parity is not yet accepted:**

- The preview demonstrates the selected style and animation using sample text. It is not yet connected to a real video playback clock or the source transcript's word timings.
- The caption layout engine is not yet the shared renderer used by both preview and MP4 output.
- Arabic uses Flutter's text direction and shaping in the on-device preview, but no golden screenshots across Arabic fonts/devices or rendered subtitle fixtures have been reviewed.
- Writing ASS subtitles and rendering them into video belong to Phase 7. Until then, exact preview/export parity and rendered-video tests remain open.

## Automated test coverage added

- Reframe planner: no-face fallback, low confidence, minimum face size, accepted focus coverage, context-preserving fallback, invalid geometry, complete source-time coverage, duplicate timestamps and JSON round-trip.
- Android bridge service: mocked MethodChannel response, crop plan construction, missing-face full-frame fallback and native/source duration mismatch rejection.
- Repository: reframe artifact persistence, source-duration mismatch and invalid timeline rejection.
- Caption layout: all 12 style identifiers, 10 animations, RTL text groups, two-line bounds, pauses, sentence punctuation, long words, hold limits and invalid timing.
- Caption animation: bounded output across every bundled animation, distinct typewriter/staggered/word-pop behavior and unknown animation rejection.
- Preferences and widgets: font/position/color/motion persistence, legacy project defaults, live RTL preview and saving Studio edits to the latest project.

The Mobile Android workflow runs Dart formatting, `flutter analyze --fatal-infos`, the entire Flutter test suite, an ARM64 debug APK build, and native-library packaging checks. The generated Android project is configured for API 26+ and NDK 28.2.13676358. Whisper's pinned Android CMake configuration builds its private GGML dependency statically so it does not package duplicate GGML shared-library names alongside llama.cpp.

## Acceptance still required

1. Run Arabic single-speaker, Arabic multi-speaker, English interview, gaming/webcam, screen demonstration and speech-light clips on physical ARM64 devices.
2. Compare face retention and crop stability with human-annotated frames. Validate the frontal-face detector across rotations and difficult footage.
3. Add an actual audiovisual active-speaker model and establish model-weight licensing before describing the system as active-speaker detection.
4. Connect reframing plans to the Phase 7 renderer, then test portrait/square/landscape output, transitions, crop continuity and source-time alignment.
5. Connect caption groups to playback timestamps and a shared preview/export renderer. Capture visual goldens for all 12 presets and 10 animations, including Arabic RTL.
6. Run the Android build on GitHub Actions and install the resulting APK on a physical device. A passing unit suite alone does not satisfy these gates.

No physical-device corpus or human-reviewed golden footage was available in this session. The implementation above is the tested-software foundation, not a claim that every Phase 5/6 acceptance criterion has passed.
