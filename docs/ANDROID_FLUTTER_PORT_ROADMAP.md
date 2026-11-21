# Android / Flutter Port — Product and Engineering Roadmap

**Status (2026-11-21):** Phases 1–2 retain their implementation and historical automated gates; current-source Mobile Android and physical SAF/process-death evidence are still required. Phase 3 now has a bounded WAV reader that downmixes and resamples source audio to mono 16 kHz with a windowed-sinc low-pass filter, plus contiguous two-second-overlap chunk ownership. The latest implementation still requires a green Mobile Android run and physical Arabic/English WER, timing, memory and thermal acceptance.  
**Working repository:** `m5ham3ds/CUTAWAN`  
**Working branch:** `main` (all implementation updates are committed directly to the default branch).  
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
- **Gate:** plan and baseline are retained on `main`; no feature branch is used for this project.

### Phase 1 — Flutter Android shell (implementation/build gate passed; device gate open)
- Added the Flutter source project under `mobile/flutter_app/`.
- Added Create, Projects, Caption Studio, and AI Model Center screens, initial clip preferences, the 12 existing caption styles, and a separate proposed animation catalogue.
- Added GitHub Actions workflow `.github/workflows/mobile-android.yml` using Flutter 3.47.6.
- Run `44555130724` passed formatting, `flutter analyze --fatal-infos`, `flutter test`, ARM64 debug APK build, and artifact upload.
- Artifact: `cutawan-mobile-arm64-debug` (41,818,489 bytes; SHA-256 `f4fecaf83a8fcb220ecb68e6cc5c64906366df92d6a059ad3b8353d44cbf7708`; expires 2026-12-03).
- The post-UI Phase 1 run 44642837372 passed formatting, analysis, tests, ARM64 debug APK build, and artifact upload.
- Final combined Phase 1–2 run: `44659732349` (commit `21db8988350b7ad77fa6849e0326f2faf285856b`) passed all 31 tests, built the debug APK, verified that its native ABI set is exactly `{arm64-v8a}`, and uploaded artifact `14595760317`.
- Final APK SHA-256: `33723e853795f9941097ed65c3662407d127726e433c4a85970b2cb880d20108`; APK size is approximately 76 MB. The downloadable build artifact is `cutawan-mobile-arm64-debug`.
- **Remaining gate:** install on a physical Android device and verify startup/navigation.

### Phase 2 — Project contract and source ingestion (implementation committed; device gate open)
- Added a versioned project JSON contract (schemaVersion 1), schema-0 migration, unknown-future-version rejection, and strict source/preferences/job validation.
- Added the native Android Storage Access Framework picker (ACTION_OPEN_DOCUMENT) with a persistable read grant for the selected content URI. This avoids broad storage permission requests and avoids copying a local source video into app storage.
- Added direct HTTP/HTTPS video-file downloading with progress reporting, cancellation, redirect destination checks, HTTPS downgrade rejection, blocking of social-platform page URLs, MIME/extension validation, an 8 GiB per-download limit, and a 64 MiB storage reserve.
- Added free-space preflight and periodic checks while large files download. Partial downloads are removed on cancellation/failure and stale partials are cleaned on the next downloader run.
- Added Android metadata inspection for display name, MIME type, size when exposed by the provider, duration, width, height, and rotation through MediaMetadataRetriever. Both persisted content URIs and downloaded app-private files can be re-probed.
- Added durable project storage in the application-support directory. Writes use a temporary file followed by rename; saved projects can be listed, reopened, refreshed, and deleted.
- Persisted the user's clip settings with a prepared job record that can be cancelled. The UI explicitly states that this record is not an active AI-processing task.
- Connected Create, Jobs, and Review screens to the repository. Jobs shows app-managed download usage and supports deleting a downloaded source with its project; the final project using a SAF source releases its persisted read grant.
- Added contract/migration, repository, downloader, MethodChannel, and widget-flow tests for import/download → persist → reopen → cancel → re-probe → cleanup.
- CI compiles the generated Android app including the custom Kotlin bridge and runs the Flutter test suite.
- **Scope boundary:** direct file URLs are supported; social-platform page extraction, DRM/authentication bypass, AI analysis, transcription, clip generation, and export are not implemented in these two phases.
- Final automated validation: GitHub Actions run `44659732349` passed all 31 tests and built the Android debug APK. A post-build ZIP inspection confirmed that the only native ABI directory is `arm64-v8a`; CI now enforces this assertion before artifact upload.
- **Remaining acceptance gate:** perform a real local-file SAF import and a direct-video download, then force-stop/reopen the app and re-probe both sources on a physical Android device. Widget tests mock the native channel and do not replace device-level/OEM document-provider tests.

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

1. Commit all project work directly to `main`; do not create additional feature branches or alter the upstream `JeremySNR/cutawan` repository.
2. Add the Flutter project using a supported Flutter SDK template rather than hand-writing version-sensitive Android Gradle boilerplate.
3. Add a minimal ARM64 Android CI workflow and verify an installable shell APK.
4. Define and test the versioned mobile project contract before porting complex pipeline logic.
5. Build two isolated technical spikes: whisper.cpp Android transcription, and Media3-versus-FFmpeg caption/export comparison.
6. Only after these gates pass, port candidate discovery, speaker-aware reframing, and the full Caption Studio.

**Current limitation:** this planning environment can inspect and edit repository files, but it does not have the Flutter/Dart SDK installed. Flutter compilation must therefore be verified in the new GitHub Actions workflow or in the user's Android development environment; no APK should be described as built until that workflow actually passes.


## 16. Phase 1 execution record

- Working repository: `m5ham3ds/CUTAWAN`; all work is maintained directly on `main`.
- Original imported Cutawan source baseline: `084d0b2933f64800ee5ca1b22269704f060e65f5`. `main` now also contains the mobile shell, its successful CI workflow, and subsequent mainline quality fixes.
- Flutter baseline: 3.47.6.
- GitHub Actions run: https://github.com/m5ham3ds/CUTAWAN/actions/runs/44555130724
- Result: success. Formatting, static analysis, widget tests, ARM64 debug APK build, and artifact upload all passed.
- Artifact name: `cutawan-mobile-arm64-debug`; size 41,818,489 bytes; expires 2026-12-03.
- Artifact SHA-256: `f4fecaf83a8fcb220ecb68e6cc5c64906366df92d6a059ad3b8353d44cbf7708`.
- Not yet verified: installation/startup on a physical device, real media import, URL ingestion, transcription, local inference, speaker-aware reframing, animated caption rendering, and final media export. Those remain later acceptance gates.


## 17. Mainline consolidation and mobile-interface source selection (2026-11-19)

### Repository workflow

- The implementation target is the user's existing repository, `m5ham3ds/CUTAWAN`.
- The default branch `main` is the only branch to be used for ongoing work. No more feature branches are to be created.
- The previous `android-flutter-port` branch was created against the user's explicit preference; it is a cleanup item, not the working branch.
- A review of all 32 non-main branches compared their heads with `main` and inspected branch-specific commit summaries and changed paths. Most functionality on older branches is already present in later mainline releases/merge commits (including editorial ranking, adaptive presenter/screen layouts, rejected-bound repair, temporal layout checks, OpenRouter setup, and recovered updater fixes). Several branches are only stale pointers or contain desktop/website/release-only changes.
- Three quality fixes absent from the current mainline were recovered directly into `main`: stable karaoke word-pop layout, stereo-aware loudness measurement with bounded limiter refinement, and click-reducing fades at tighten-cut audio joins. Focused unit tests and three deterministic benchmark scripts were added.
- The old source branch could not be merged cleanly as a whole; its pull request was closed after the selected changes were ported to current mainline files. Do not merge that stale branch wholesale.
- Experimental shot-style triage, Metachlorian/B-roll handoff, and desktop promotional/website/design-system experiments were not merged: they are not validated for this Android implementation, and the shot-style thresholds are explicitly provisional.

### Four-source interface audit

The GitHub file trees of the four candidate projects were enumerated, and their READMEs, project manifests, and representative application/UI/pipeline files were inspected. This was a repository-structure and source-file audit, not a full binary archive download of every external repository.

| Candidate | Existing interface | Android/mobile finding | Decision |
| --- | --- | --- | --- |
| Cutawan (`JeremySNR/cutawan`) | Electron + React desktop application | No Android, iOS, Flutter, or native mobile project | Keep as the principal domain/pipeline/caption reference; rebuild the interface in Flutter |
| AutoClip (`artbyjazi/autoclip`) | React + Vite + Tailwind web interface; Ingest, Job Progress, Review, Settings, clip player, caption editor, and trim controls | Responsive small-screen web layout through Tailwind breakpoints, but not an Android APK or native mobile code; backend is Python/FastAPI | Use as the mobile interaction/layout reference, not as an Android runtime/backend |
| AI YouTube Shorts Generator (`Anil-matcha/AI-Youtube-Shorts-Generator`) | Python scripts and pipeline modules | No mobile UI or Flutter/Android project | Reuse ideas from its highlight/downloader pipeline only where justified |
| Auto Video Editor (`kiy0ni/auto-video-editor`) | Python CLI and Tkinter desktop GUI | No responsive phone interface or native Android project | Use selected audio/moment-analysis concepts only |

**Decision:** none of the four repositories provides a native Android mobile application. AutoClip is the only candidate among the four with a web interface that adapts to phone-sized layouts. The application will continue on the user's Cutawan repository because it contains the richer clipping/editorial/caption/reframing domain, while its Flutter screens will be designed using the mobile-responsive flows from AutoClip (source ingest, job progress, clip review, trim/caption editing, settings). Do not embed AutoClip in a WebView, depend on its Python/FastAPI backend, or claim it is a native phone app.

### Required next UI structure

1. **Create / Ingest:** prominent local-file and supported-link source cards; clear source status and storage estimate; clip count, duration band, aspect ratio, and caption toggle.
2. **Jobs:** durable task status, current stage, progress, cancel/retry/resume, and an honest error/recovery state.
3. **Review:** vertically stacked clip cards with preview, score explanation, clip timestamps, reordering, keep/reject, and per-clip retry.
4. **Clip / Caption Studio:** mobile timeline/trim controls, separate caption visual preset and animation selectors, RTL-safe preview, colors, font, size, position, and export-parity settings.
5. **Models / Settings:** model size, runtime compatibility, license, download/integrity status, storage usage, and explicit local/remote mode.

Do not show controls as working until their underlying Android/media operation is implemented and tested.

### Branch-cleanup note

The GitHub connection available for this session can read and update file contents and refs, but does not expose a branch-ref deletion operation. No branch has been deleted by this session. Delete the unwanted branch refs from the repository's GitHub **Branches** page after verifying that `main` contains the required content.

## 18. Mobile UI implementation update (2026-11-19)

The Flutter shell now adopts the phone-first navigation and information architecture inspired by AutoClip's existing responsive web interface, while remaining a native Flutter application:

- Four bottom destinations: source input, jobs/projects, clip review, and Caption Studio.
- Model Center is reachable from the app-bar action.
- Source input presents a URL field and local-file entry point, with clip count, target duration, aspect ratio, captions, and speaker-tracking preferences.
- Jobs and Review pages have explicit empty states that explain the pending media/job integration.
- Caption Studio separates visual presets from animation choices and makes it clear that its sample preview is static.
- Warm charcoal and muted amber theme replaces the generic violet theme, with mobile spacing and Material 3 controls.

The Flutter screen currently provides a UI and preference interaction shell. URL ingestion, file-picker integration, job persistence, media preview, actual animated rendering, AI inference, and export remain unimplemented. Buttons that would trigger those operations state that they are not yet connected instead of reporting a false success.

The current widget tests cover the four primary destinations, caption preset/animation separation, and honest empty states for Jobs and Review. A new Android ARM64 build is being verified from `main` after this UI update.


## 19. Phase 2 implementation record (2026-11-20)

- Working branch: main; no feature branch was created for Phase 2.
- Added the project_contract.dart versioned project/media contract and serialization/migration support in clip_preferences.dart.
- Added local_project_repository.dart for durable local project/job records.
- Added android_video_picker.dart and the native Kotlin source tooling/android/MainActivity.kt.
- Updated the Android generation script to install the native bridge after Flutter creates its SDK-matched Gradle project.
- Connected the Create, Jobs, and Review screens to persisted source and job data.
- Added automated tests for contract round-trip, v0 migration, future schema rejection, metadata validation, repository persistence/cancellation/deletion, MethodChannel mapping, and the end-to-end widget flow.
- Physical Android device verification remains open. The widget test simulates a fresh app shell with the same disk repository and mocks the native channel; it does not claim to prove OEM document-provider behavior after a real process death.


## 20. Direct media ingestion extension (2026-11-20)

- Added direct video-file URL ingestion and cancellable HTTP streaming in `mobile/flutter_app/lib/services/direct_video_downloader.dart`.
- Allowed protocols: HTTP and HTTPS. The downloader validates each redirect, rejects HTTPS-to-HTTP downgrade, platform-page URLs, literal private/local addresses, unsupported MIME types, non-video HTML, and downloads exceeding 8 GiB.
- Checks device free storage before download and periodically during larger transfers while preserving a 64 MiB reserve. It removes partial files on cancellation/failure and cleans stale partial files on the next run.
- Downloads are written to app-private support storage, then inspected by the native metadata bridge before a project is saved. A failed project save removes the downloaded media to avoid orphaning a large file.
- Jobs displays the app-managed download footprint and supports deliberate removal of downloaded media plus its project record. SAF records release their persisted read grant only when no other saved project refers to that same URI.
- Added download tests for successful transfer/progress, redirects, platform/private URL rejection, non-video responses, insufficient storage, cancellation before/during transfer, interrupted part cleanup, storage accounting/deletion, and unsafe filename/query handling.
- Physical Android verification is still required for actual URL network access, Android private-path checks, SAF permission persistence across process death, and media probing on the OEM document provider.


## 21. Automated completion record for Phases 1–2 (2026-11-20)

- Final source SHA on `main`: `21db8988350b7ad77fa6849e0326f2faf285856b`.
- Mobile workflow: `44659732349` — success.
- Root CI workflow: `44659732275` — success. Release workflow `44659732258` was skipped as expected; this was not a release build.
- Flutter 3.47.6: formatting, static analysis (`flutter analyze --fatal-infos`), and all **31 tests** passed.
- Android ARM64 debug build succeeded. The native ABI assertion passed with exactly `arm64-v8a` and no `armeabi-v7a` or `x86_64` directories.
- Artifact: `cutawan-mobile-arm64-debug` (artifact ID `14595760317`, 44,293,109-byte ZIP archive).
- Extracted APK: approximately 76 MB; SHA-256 `33723e853795f9941097ed65c3662407d127726e433c4a85970b2cb880d20108`.
- Licensing audit records: `THIRD_PARTY_NOTICES.md` and `docs/DEPENDENCY_LICENSE_INVENTORY.md`. Unverified ONNX asset licenses remain excluded from the mobile bundle.
- No feature branch was created for these phases; all implementation and fixes were pushed directly to `main`.
- Physical-device install and real SAF provider / direct URL process-restart verification remain open. This is the only Phase 1–2 acceptance item not completed within this environment.


## 22. Phase 3–4 implementation on mainline (2026-11-20)

The Phase 3–4 implementation is prepared directly against the inspected `main` baseline. It adds a native Android audio-decode bridge, a versioned transcript and candidate artifact contract, local Whisper transcription, deterministic candidate discovery, optional local Qwen annotation, model integrity management, and focused automated tests. The full component/source decision and remaining acceptance evidence are recorded in `docs/mobile/PHASES_3_4_INTEGRATION.md`.

### Planned gates 1–4 mapping

1. **Phase 1 — baseline/mobile shell:** retain the existing root CI and mobile shell/ARM64 packaging gates. The prior mainline run (Mobile run `44659732349`, root CI run `44659732275`) passed before these new native dependencies were introduced.
2. **Phase 2 — source/project lifecycle:** retain the existing project-contract, local repository, source downloader, import-flow, persisted SAF permission, and widget coverage. Additive analysis artifacts are stored outside the project index and deleted with their parent project.
3. **Phase 3 — transcription/model gate:** add transcript contract/timestamp tests, multilingual Whisper catalog checks, Android audio-decode integration at build time, user-controlled model download and SHA-256 verification. Overlapped 30-second chunking with two-second overlap is implemented, but its boundary accuracy and real Arabic/English acoustic accuracy remain unaccepted until fixture/device evidence is recorded.
4. **Phase 4 — candidate gate:** add duration/source-bound checks, no-fabricated-candidate checks, sentence/word timing tests, deduplication and JSON contract tests, and a guarded Qwen annotation boundary test that preserves IDs, timing, evidence and deterministic scores.

### Current implementation boundary

- The candidate engine proposes and stores moments; it does **not** cut or render final video files.
- Sampled visual evidence is a low-resolution frame-change signal; it is not face detection, active-speaker detection or semantic vision.
- Whisper processes decoded audio as 30-second tasks with two-second overlap and deterministic boundary de-duplication. Its Arabic/English stitching accuracy is not yet certified; VAD-backed silence rejection remains open.
- Qwen is an optional local annotation model. Candidate times, score and evidence remain deterministic and are not accepted from model output.
- Models are downloaded on user action and verified before installation; neither weight file is embedded in the APK.
- The Flutter Android build uses minSdk 26 and pinned NDK 28.2.13676358 for the selected local inference bridge; ARM64-only packaging remains mandatory.

**Validation status:** implementation and tests are added, but these gates are not considered passed until the resulting GitHub Actions runs are inspected. Physical Android tests using the documented Arabic/English corpus remain open regardless of CI outcome. The app must not be described as having full clip rendering, speaker tracking, or export until the later roadmap phases and their gates are complete.


## 21. Android Phase 5 implementation record (2026-11-20)

See [PHASES_5_6_INTEGRATION.md](mobile/PHASES_5_6_INTEGRATION.md). The Flutter Android companion now includes a bounded native frontal-face sampler, confidence/coverage-validated crop planning, safe full-frame fallback, and durable per-project reframe artifacts. This is a reframing foundation, not an audiovisual active-speaker model. Physical-device golden-footage review and a rendered crop pipeline remain open.

## 22. Android Phase 6 implementation record (2026-11-20)

See [PHASES_5_6_INTEGRATION.md](mobile/PHASES_5_6_INTEGRATION.md). The Flutter Caption Studio now uses the 12 existing CUTAWAN caption presets, bundled Anton/Poppins fonts with OFL notices, ten separate preview animations, Arabic RTL controls, editable/persisted style settings, and a tested caption layout engine. Real transcript-synchronized preview, shared preview/export rendering, golden visual regression, and MP4 parity remain open until Phase 7.


## 23. Provider integration, key security and execution-mode work (2026-11-20)

**Target commit for this implementation:** tracked in `phases/07-ai-providers-and-secure-credentials.md`.

### Existing completed capability retained

Phases 1–6 remain in place. The previously green mainline commit `06fee1ca9e042f2505b9314d1495eb127b1d7220` passed the Mobile Android workflow `44751288974` and root CI `44751289006`. The pipeline still has important unaccepted scope: it proposes/stores candidates and crop plans but does not render the final clip video; local acoustic accuracy, physical-device storage access and crop quality remain open.

### Provider work added

The first AI-provider integration adds provider-specific API adapters for OpenAI Chat Completions, Google Gemini (Interactions API with GenerateContent compatibility fallback), Hugging Face Inference Providers Router, and user-defined OpenAI-compatible HTTPS endpoints. Model IDs are fetched from the user's account rather than advertised as a static universal catalogue. The Hugging Face provider metadata may report trial/free eligibility; the client does not infer that a model is free when the upstream response omits such a field.

API keys and provider settings are persisted through `flutter_secure_storage`, never in the project JSON. Android backup is disabled for Keystore ciphertext. The user must explicitly consent before remote mode is enabled. Only bounded transcript excerpts for candidate annotation are sent; source video and API keys are not included in request content. Deterministic IDs, boundaries, evidence and scores are preserved by the existing annotation allow-list.

### Constraints and acceptance boundary

- The general endpoint is OpenAI Chat Completions-compatible; it is not a promise to speak every proprietary API. Other API formats require separate adapters.
- A model appearing in a provider's list does not prove it supports the selected task, that the account can afford it, or that its API access is enabled. The user-triggered test call confirms a small text completion only.
- Free/trial status is displayed only when the provider reports it; pricing and quota must be confirmed in the provider console.
- Gemini Interactions availability can differ by model/account; a restricted compatibility fallback is attempted only for unsupported/endpoint-not-found errors.
- Android Keystore persistence, rotation, deletion and backup behavior still require physical-device tests. Unit tests use a mock secure-storage adapter.
- Cloud execution is only attached to short editorial annotation of already-discovered candidates in this phase. Whisper transcription, face analysis, rendering and video transfer remain local/not wired to the cloud.

See `phases/README.md` for the current phase matrix and `phases/07-ai-providers-and-secure-credentials.md` for detailed design, tests and next steps.


## 24. Phase 7 provider integration — automated validation (2026-11-20)

The provider UI and service are now wired into the Flutter review path. OpenAI, Google Gemini, Hugging Face Inference Providers and compatible endpoints have provider-specific model discovery and text-completion adapters. API keys and provider selections use secure storage; cloud execution requires a saved model and explicit consent. The review pipeline sends bounded text excerpts only and retains deterministic IDs, timing, evidence and scores.

- Final tested main SHA: `4a9c8b3a22c62390ab43d1c5e84e90a7fa16fc95`.
- Mobile Android run [44767326112](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44767326112): success; all 79 Flutter tests, analysis, ARM64 build, and native packaging assertions passed.
- Root CI run [44767326104](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44767326104): success.
- APK ZIP artifact ID: `14643739562`; extracted APK SHA-256: `47b205348a5731aced8bfd50c56ebb46cbd08e2c6b8b2f8e6e14f9a5e86d31da`.
- Physical Android Keystore behavior, real provider keys/accounts, quota/cost, device model compatibility, and real transcript annotation quality have not been tested here.

This does not complete Phases 8–10. The Android app still does not produce final edited MP4 clips; the candidate and crop artifacts are not a renderer. The visual UI still needs the planned feature-screen refactor, professional design review, transcript-timed playback, and real-world acceptance evidence.
