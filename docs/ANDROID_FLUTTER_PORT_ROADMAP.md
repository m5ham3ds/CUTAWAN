# Android / Flutter Port — Product and Engineering Roadmap

**Status:** Baseline and roadmap committed; Phase 1 Flutter shell implemented. GitHub Actions successfully formatted, analyzed, tested, built, and uploaded an ARM64 debug APK. Physical-device installation and runtime verification remain open.  
**Working repository:** `m5ham3ds/CUTAWAN`  
**Working branch:** `android-flutter-port`  
**Baseline:** Cutawan v0.14.0, commit `084d0b2933f64800ee5ca1b22269704f060e65f5`  
**Decision:** Preserve the existing desktop application. Add a native Android application using Flutter, and reuse/port selected domain logic and assets. Do not wrap the Electron application in a WebView.

## 1. Verified baseline

The supplied `cutawan-main.zip` was checked for archive integrity and its embedded commit identifier matches the current `main` head of this repository. That commit also matches the inspected upstream Cutawan commit. The extracted archive contains 351 files, including 93 test files.

Current repository characteristics:

- Electron + Vite + React + TypeScript desktop application.
- MIT project license.
- Existing AI clipping, transcript, clip ranking, editorial review, timeline editing, reframing, speaker detection, ASS caption generation, FFmpeg rendering, project persistence, and desktop packaging.
- Existing caption style data contains 12 visual presets: Beast, Karaoke, Pill, Minimal, Hormozi, Neon, Ember, Bubble, Lemon, Retro, Crimson, and Whisper.
- The caption renderer currently has word-level active-word emphasis with a modest scale transform and a fade for the opening title. It does not yet provide the full independent animation catalogue planned below.
- Existing bundled assets include Anton and Poppins fonts, YuNet/UltraFace face models, Silero VAD, and LR-ASD ONNX model files. Each model and font must retain its own provenance and license notice.
- Local transcription currently uses a desktop Python/CTranslate2 path; parts of the existing app still use external AI providers for clip discovery. Neither is a ready-made Android-native local AI runtime.
- The repository currently contains no Flutter project, Android manifest, Android Gradle project, Media3 integration, or Android NDK/JNI bridge.

The existing desktop code and its test suite remain the reference implementation. The mobile app is a new target, not a destructive rewrite of the desktop application.

## 2. Product definition

The product is an AI short-form video repurposing studio:

1. The user supplies a supported video URL or selects a local video.
2. The app obtains media the user is authorized to process and probes its duration, streams, dimensions, frame rate, and audio.
3. Speech is transcribed with word-level timestamps; video and audio are analyzed for scene changes, speakers, faces, reactions, energy, and visual events.
4. The discovery engine proposes self-contained moments with a beginning, context, hook, and payoff.
5. Candidates are ranked, deduplicated, and spread across the source so the output is not twenty variations of the same moment.
6. The user chooses or adjusts the number and target duration of clips.
7. Each candidate is reframed for the selected destination format, styled, captioned, and optionally enhanced with titles, branding, and audio treatment.
8. The user reviews, edits, includes/excludes, reorders, and re-renders individual clips.
9. The app exports separate, verified video files and an optional project bundle/subtitles.

Popularity or virality must never be presented as guaranteed. Scores are provisional editorial recommendations, with evidence and uncertainty visible to the user.

## 3. Repository and migration strategy

### 3.1 Keep the desktop app working

Do not replace or rename the root Electron app. It remains useful as a working reference and a regression oracle for desktop functionality.

### 3.2 Add a sibling mobile application

Create the Flutter application under:

- `mobile/flutter_app/` — Flutter UI, domain orchestration, project and model management.
- `mobile/android/` — Android-specific Kotlin integration and lifecycle services (inside the Flutter app's generated Android project).
- `native/` — native build scripts and JNI/C++ bridges where required.
- `docs/mobile/` — mobile architecture, model compatibility, renderer decisions, and test protocols.

The Flutter application must be a genuine Android application. It must not depend on Electron, a desktop Node process, a local web server, or PRoot/Ubuntu being installed on the user's phone.

### 3.3 Reuse strategy

Reuse directly where it is platform-neutral and the license permits:

- Versioned domain concepts and JSON project structures.
- The existing 12 caption preset definitions as the starting visual library.
- Editorial ranking concepts, sentence-aware boundaries, deduplication, candidate review, and clip-length policy.
- Reframe/composition concepts, focus tracks, zoom plans, and output geometry after porting and parity tests.
- Font assets and compatible ONNX model assets, subject to model-specific provenance and licensing.

Reimplement platform-bound code:

- Electron main/preload/IPC and Node filesystem/process APIs.
- React desktop screens and desktop window management.
- Desktop FFmpeg binary resolution and process management.
- Python/CTranslate2 transcription execution for the Android target.
- ONNX Runtime Node bindings.
- Desktop update, installer, and OS-keyring flows.

Do not bulk-copy desktop source files into the Flutter app and assume they work. Each reused algorithm must have a defined Dart/Kotlin/C++ owner and tests.

## 4. Target mobile architecture

### 4.1 Flutter presentation and application layer

Flutter owns:

- Home/import flow and project library.
- Processing queue and progress timeline.
- Candidate clip gallery, ranking explanations, and review state.
- Clip editor and preview controls.
- Caption Studio and animation controls.
- Output format, clip duration, color, audio, and branding settings.
- AI Model Center, storage display, model downloads, and model selection.
- Export queue, file destinations, and error/retry UI.

### 4.2 Dart domain layer

Create platform-independent Dart modules for:

- Project and clip data contracts.
- Transcript, word timing, and sentence boundaries.
- Candidate validation, duration constraints, and deduplication.
- Ranking result normalization and explanation display.
- Caption presets, animation presets, color palettes, and brand kits.
- Edit-plan validation and preview/export settings.
- Job state, checkpoints, and retry policy.

The Dart domain layer must not call Android APIs directly. Use typed interfaces/adapters.

### 4.3 Android native layer

Kotlin owns Android-specific capabilities:

- Storage Access Framework and persisted content URI access.
- Notifications and a visible foreground service for long-running user-requested processing when required.
- WorkManager for durable/recoverable deferred work where appropriate.
- Battery, thermal, memory, and storage capability probes.
- Media3 integration or the selected native media backend.
- Native library/model loading and lifecycle control.

C++/JNI is reserved for engines that need it, such as whisper.cpp and llama.cpp. Avoid an unnecessary JNI layer when a stable Android AAR or Kotlin API is sufficient.

### 4.4 Engine adapters

Keep engines behind replaceable interfaces:

- `VideoSourceAdapter`: local files and supported URL ingestion.
- `MediaProbeAdapter`: stream metadata and timestamps.
- `SpeechToTextAdapter`: local Whisper engine and optional future providers.
- `LanguageModelAdapter`: local GGUF model through llama.cpp; optional explicitly selected remote provider.
- `VisionAdapter`: face/person detection, speaker association, scene and visual-event analysis.
- `MediaRenderAdapter`: preview and final export.
- `ModelRegistryAdapter`: model manifest, download, integrity check, install, compatibility, and removal.

The user-facing product must not depend on one model or one media engine.

## 5. Processing pipeline

The intended resumable pipeline is:

1. **Input and authorization:** validate URL/file, retain the source reference, and explain any required login/cookie or platform restriction. Do not bypass DRM, paywalls, or access controls.
2. **Download/import:** obtain the best permitted source rendition or copy/access the local file; support cancellation, disk preflight, and partial-download cleanup.
3. **Probe and fingerprint:** read duration, streams, rotation, sample aspect ratio, time base, frame rate, audio channels, and source hash.
4. **Prepare:** extract audio, create analysis proxies/thumbnails, detect silence and scene boundaries, and establish source timestamps.
5. **Transcribe:** chunk long audio with overlap, obtain word-level timing, stitch chunks, reject hallucinations over silence, and preserve original text.
6. **Analyze audio and people:** VAD, vocal energy, speaker turns, face tracks, and active-speaker evidence when enabled and supported.
7. **Discover candidates:** combine speech-led, audio-event-led, and visual-event-led candidates. Keep evidence references and coverage gaps.
8. **Editorial ranking:** evaluate hook, clarity, context, payoff, useful information, emotion, visual interest, audience fit, and repetition. Normalize and validate model output in deterministic code.
9. **Select and refine:** apply user count/duration preferences, source coverage, duplicate removal, sentence boundaries, and context-preserving pre/post-roll. Never pad a weak moment just to hit a duration.
10. **Reframe and compose:** track the speaker or subject, preserve relevant content, choose a portrait layout, stabilize camera movement, and obey safe-area constraints.
11. **Caption and style:** map word timings to output time, apply caption style, animation, position, language direction, and brand colors.
12. **Render:** export one file per accepted clip, with controlled concurrency.
13. **Validate:** probe the output, decode it, verify dimensions/duration/audio, inspect subtitle bounds/timing, and mark issues for review.
14. **Review and export:** allow individual retry/re-render without repeating source download, transcription, or candidate discovery.

Every stage writes a checkpoint/artifact keyed by source fingerprint, model/version, prompt version, configuration, and edit revision. A changed caption should invalidate only caption/render artifacts, not the source analysis.

## 6. Clip duration and batch controls

Initial user-facing controls:

- Number of clips: Auto, 5, 10, 15, 20, or a custom count.
- Target duration: Auto, 15–30s, 30–45s, 30–60s, 60–90s, or custom minimum/maximum.
- The selected duration is a target band, not permission to cut a sentence or pad a moment. A shorter complete moment is preferable to a longer incomplete one.
- Clip ordering: highest score, source chronology, or user-defined order.
- Source coverage: balanced across the video or strongest moments regardless of location.
- Duplicate strictness: conservative/standard/strict.
- Optional opening hook overlay and ending hold.
- User may manually include a lower-ranked moment with the reason/quality caveat still visible.

The processing engine must report how many usable candidates exist. It must not invent additional clips merely to satisfy a requested count.

## 7. Caption Studio: independent style and animation systems

### 7.1 Preserve and extend the existing visual presets

Port the existing 12 Cutawan styles. Add new original presets after the mobile renderer can reproduce the existing ones. Do not remove any existing style without migration.

A visual preset defines:

- Font family, weight, size, letter spacing, line spacing, uppercase behavior.
- Main text, active word, inactive word, background, outline, and shadow colors.
- Outline width, shadow, pill/box shape, padding, radius, opacity.
- Anchor position, alignment, safe area, maximum words/lines, and wrapping.
- Speaker-specific color rules and optional speaker labels.

### 7.2 Animation is a separate selectable property

Initial proposed animation catalogue:

- Karaoke fill / word highlight.
- Word pop / scale punch.
- Bounce.
- Fade in/out.
- Slide in/out.
- Typewriter.
- Glow pulse.
- Highlight sweep.
- Staggered word reveal.
- Static/no animation.

Animations must support speed/intensity controls and must be safely combinable with compatible visual presets. Unsupported combinations should fall back explicitly, never silently change appearance.

### 7.3 Caption controls

Provide:

- Preview and export parity.
- Word or phrase grouping.
- Timing offset and per-word duration adjustment.
- Entrance/exit duration and active-word animation duration.
- Position and safe-area adjustment.
- Main/highlight/background/outline colors and opacity.
- Font upload/selection with font-license checks.
- Per-speaker color mapping.
- Custom presets and reusable brand kits.
- Captions on/off and optional SRT/VTT sidecar output.

Arabic is a first-class requirement: RTL line layout, Arabic shaping/ligatures, punctuation, mixed Arabic/English text, numerals, and word highlighting must be tested. Do not assume a Latin-oriented word-grouping algorithm is adequate for Arabic.

## 8. Video appearance and export controls

Per project and per clip, support:

- Aspect ratio: 9:16, 1:1, 16:9, and original.
- Resolution profiles: 720p, 1080p, and device-supported higher tiers after benchmarking.
- Frame rate: preserve source, 24, 30, or 60 where valid.
- Reframing: active speaker, face/subject tracking, manual focal point, center crop, fit with blur background, fit with letterbox, split/stacked layout.
- Color: brightness, contrast, saturation, temperature, tint, and named color presets; advanced LUT support later.
- Motion: auto zoom, manual zoom keyframes, pan speed, and transition choices.
- Audio: source gain, background music, ducking, fade, normalization, and optional silence tightening.
- Branding: logo/watermark image, placement, scale, opacity, and intro/outro options.
- Export: MP4/H.264/AAC first; other codecs only after device compatibility validation.
- Cover frame and suggested title/description/hashtags as editable metadata.

Export quality must be separate from analysis speed. A weak device may process fewer jobs concurrently or use a smaller model; it must not silently lower output quality or claim that a lower-quality result passed the same gate.

## 9. Local AI Model Center

Do not package large model weights inside the APK. Use a signed/versioned model manifest with:

- Model ID, name, task, provider/runtime, format, version, source URL.
- File size, SHA-256, supported ABI, minimum RAM/storage, and recommended device tier.
- Model license, attribution, and redistribution constraints.
- Runtime compatibility and minimum app version.
- Installation state, download progress, integrity state, and removal support.

Initial runtime candidates:

- **Speech recognition:** whisper.cpp Android build; test Tiny/Base/Small alternatives on Arabic and English.
- **Text reasoning/highlight selection:** llama.cpp with a tested GGUF model. Begin with one small model and one medium model; freeze exact model IDs only after format/runtime, license, quality, and memory benchmarks.
- **Vision:** reuse existing ONNX assets where their provenance permits, using ONNX Runtime Android. Test YuNet/UltraFace and LR-ASD separately; do not assume desktop ONNX preprocessing transfers unchanged.
- **VAD:** evaluate the existing Silero VAD ONNX model through ONNX Runtime Android.
- **Media analysis:** use deterministic scene, timestamp, audio-energy, and frame-sampling tools before adding a large vision-language model.

A model is not eligible for the in-app catalogue until both its code/runtime license and the model-weight license are reviewed. A permissively licensed engine does not make all weights permissively licensed.

The default must be a transparent local mode. If remote analysis is later offered, make it opt-in per project and disclose exactly which transcript, frames, or other data will be sent. Never upload the source video silently.

## 10. Android media backend decision gate

Do not select a renderer by name alone. Build a small spike comparing:

- AndroidX Media3 Transformer for native Android decoding/effects/encoding.
- An Android FFmpeg build with the exact required filters and subtitle capabilities, with a documented LGPL/GPL configuration and reproducible build.

The spike must test portrait crop, blur-fill, picture-in-picture/split composition, frame-accurate cuts, audio mixing/ducking, word-timed animated captions, Arabic shaping, fonts, color handling, cancel/resume, and output validation.

Choose one primary renderer. A hybrid is allowed only where a measured feature gap justifies it. Preview and export must use the same versioned edit plan and geometry/time functions.

## 11. Persistence, performance, and background work

- Use a durable job journal and checkpointed artifacts; do not rely on in-memory queue state.
- Process one heavy inference/render stage at a time by default on phones. Add concurrency only after memory/thermal tests.
- Prioritize the clip currently opened by the user over background renders.
- Support pause, cancel, restart recovery, and cleanup of abandoned temporary files.
- Check free space before downloading a source/model or starting a batch render.
- Display estimate ranges based on measured progress and device profile; do not display invented countdowns.
- Persist access to user-selected content URIs safely.
- Avoid requiring PRoot, Ubuntu, desktop Node.js, or a separate local server.
- Provide GitHub Actions builds for Android ARM64 APK first; AAB/release signing follows after debug and release validation.

## 12. Phased implementation and acceptance gates

### Phase 0 — Baseline and design (completed)
- Verify repository snapshot and preserve desktop baseline.
- Record licenses, model provenance, and dependency inventory.
- Approve module boundaries, data contracts, and renderer spike criteria.
- **Gate:** plan and baseline are committed on the mobile work branch; `main` remains unchanged.

### Phase 1 — Flutter Android shell (implementation/build gate passed; device gate open)
- Added the Flutter source project under `mobile/flutter_app/`.
- Added Create, Projects, Caption Studio, and AI Model Center screens, initial clip preferences, the 12 existing caption styles, and a separate proposed animation catalogue.
- Added GitHub Actions workflow `.github/workflows/mobile-android.yml` using Flutter 3.47.6.
- Run `44555130724` passed formatting, `flutter analyze --fatal-infos`, `flutter test`, ARM64 debug APK build, and artifact upload.
- Artifact: `cutawan-mobile-arm64-debug` (41,818,489 bytes; SHA-256 `f4fecaf83a8fcb220ecb68e6cc5c64906366df92d6a059ad3b8353d44cbf7708`; expires 2026-12-03).
- **Remaining gate:** install the APK on a physical Android device and verify startup/navigation. Native media/model integration is not yet present.

### Phase 2 — Project contract and local media
- Define versioned project JSON and migration tests.
- Import local media through Android storage APIs and inspect media metadata.
- Add local project persistence and a cancellable job record.
- **Gate:** import, reopen, and metadata inspection work after process restart.

### Phase 3 — Transcription and local model management
- Integrate whisper.cpp on Android ARM64.
- Add model manifest/download/SHA-256/integrity/install/remove.
- Validate Arabic and English word timing and chunk stitching.
- **Gate:** reproducible offline transcription for the reference fixtures; no cloud required.

### Phase 4 — Candidate discovery and ranking
- Port candidate/duration/deduplication contracts.
- Integrate llama.cpp and one tested local GGUF model.
- Combine transcript, audio, and sampled visual evidence.
- **Gate:** candidate JSON is validated, explainable, non-duplicated, and respects source boundaries.

### Phase 5 — Reframing and composition
- Integrate face detection and active speaker inference.
- Port stable crop/focus/zoom logic.
- Add portrait, square, and landscape composition choices.
- **Gate:** golden footage passes framing/subject-retention review; fallback to full-scene fit on uncertainty.

### Phase 6 — Caption Studio
- Port the 12 visual presets.
- Add independent animation definitions and user-editable style values.
- Implement Arabic RTL/shaping and exact preview/export parity.
- **Gate:** visual regression captures and rendered video tests pass for all bundled styles and supported animations.

### Phase 7 — Renderer and batch export
- Complete Media3-versus-FFmpeg spike and freeze the renderer choice.
- Export separate MP4s with audio, captions, color, branding, and target dimensions.
- Add per-clip rerender, failure recovery, and output verification.
- **Gate:** every output passes probe, full decode, timing, audio, dimensions, and subtitle checks.

### Phase 8 — Hardening and release
- Long-video, low-storage, app-kill, thermal, and battery testing.
- Benchmark lower/mid/high device profiles.
- Complete third-party notices and model-license manifest.
- Produce signed/release Android artifacts only after debug acceptance.
- **Gate:** documented test corpus, known limitations, repeatable CI, and no unresolved critical export defects.

## 13. Test corpus and quality rules

Use only videos the project owner has the right to process. The initial reference corpus should include:

1. Arabic single-speaker podcast.
2. Arabic multi-speaker interview.
3. English podcast/interview.
4. Gaming stream with webcam overlay.
5. Screen demonstration/tutorial.
6. Speech-light or visual-event source.

Track:

- Transcript and word timing accuracy.
- Candidate boundary correctness and sentence completeness.
- Duplicate rate and source-time coverage.
- Editorial reviewer acceptance and severe omissions.
- Face/speaker retention and crop jitter.
- Caption timing, legibility, RTL shaping, and preview/export parity.
- Output dimensions, duration, audio continuity, full-decode success, and file playability.
- Peak RAM, storage, thermal behavior, battery cost, and elapsed time.

The existing 93 desktop test files must remain intact. Port pure-domain behavior with equivalent Dart tests and add Android instrumentation/native tests. Passing desktop tests does not prove Android compatibility.

## 14. License and security requirements

- Preserve the root MIT license and all required upstream notices.
- Maintain `THIRD_PARTY_NOTICES.md` and a machine-readable dependency/model license inventory.
- Review FFmpeg configuration and its LGPL/GPL implications before packaging.
- Review each model weight independently from its runtime.
- Keep API credentials out of source, project exports, and logs.
- Validate downloaded model/source hashes and reject truncated or mismatched artifacts.
- Do not bypass DRM, paywalls, or website access controls.
- Treat media metadata, transcripts, subtitles, and model output as untrusted input; validate paths, timestamps, geometry, and generated JSON.

## 15. Immediate next implementation steps

1. Keep all work on `android-flutter-port`; do not change `main` or the upstream repository.
2. Add the Flutter project using a supported Flutter SDK template rather than hand-writing version-sensitive Android Gradle boilerplate.
3. Add a minimal ARM64 Android CI workflow and verify an installable shell APK.
4. Define and test the versioned mobile project contract before porting complex pipeline logic.
5. Build two isolated technical spikes: whisper.cpp Android transcription, and Media3-versus-FFmpeg caption/export comparison.
6. Only after these gates pass, port candidate discovery, speaker-aware reframing, and the full Caption Studio.

**Current limitation:** this planning environment can inspect and edit repository files, but it does not have the Flutter/Dart SDK installed. Flutter compilation must therefore be verified in the new GitHub Actions workflow or in the user's Android development environment; no APK should be described as built until that workflow actually passes.


## 16. Phase 1 execution record

- Working repository: `m5ham3ds/CUTAWAN`; all mobile work remains on `android-flutter-port`.
- The repository's `main` branch was checked and remains at baseline commit `084d0b2933f64800ee5ca1b22269704f060e65f5`.
- Flutter baseline: 3.47.6.
- GitHub Actions run: https://github.com/m5ham3ds/CUTAWAN/actions/runs/44555130724
- Result: success. Formatting, static analysis, widget tests, ARM64 debug APK build, and artifact upload all passed.
- Artifact name: `cutawan-mobile-arm64-debug`; size 41,818,489 bytes; expires 2026-12-03.
- Artifact SHA-256: `f4fecaf83a8fcb220ecb68e6cc5c64906366df92d6a059ad3b8353d44cbf7708`.
- Not yet verified: installation/startup on a physical device, real media import, URL ingestion, transcription, local inference, speaker-aware reframing, animated caption rendering, and final media export. Those remain later acceptance gates.
