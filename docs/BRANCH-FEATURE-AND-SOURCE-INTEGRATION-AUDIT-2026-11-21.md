# CUTAWAN branch, feature and upstream-source integration audit — 2026-11-21

## Active target
The requested product target is the native Android app at `mobile/flutter_app/` using Flutter/Dart. Root Electron/React is reference/legacy desktop only. Continue work on `main`; do not merge stale branches wholesale.

## Repository and CI snapshot
- Repository: `m5ham3ds/CUTAWAN`
- `main` head observed during audit: `cc3720ca59a30e0c1ad033d1d44108ba0a88c3ce`.
- Root CI run 189 (`44840654499`) succeeded: typecheck, lint, tests, offline desktop pipeline, UI smoke and packaged inference/export.
- Latest Mobile Android run observed: run 165 (`44840644142`) succeeded for Flutter generation, format, analysis, Flutter tests, ARM64 APK build, native ABI checks and upload. It ran on `4ffb57d73b990fdc449a8f721a9dac14b91aacbc`, before the latest documentation commits; a new mobile run is needed to attest current HEAD.
- The phase register records 79 Flutter tests. These do not prove physical-device inference accuracy or a complete export/editor.

## Branch audit
Representative feature-bearing branches were compared with `main`. These are divergent snapshots with old bases; selected logic must be ported and tested, not blindly merged.

| Branch | Ahead / behind | Scope and decision |
|---|---:|---|
| `android-flutter-port` | 0 / 187 | Early Flutter shell is already in mainline history; do not merge. |
| `codex/adaptive-presenter-layouts` | 3 / 220 | Presenter/screen composition, focus tracks, reframe and preview. Port missing algorithms to Dart/Kotlin only after renderer gate. |
| `codex/editorial-discovery-quality` | 4 / 208 | Candidate discovery, editorial review/ranking and benchmark fixtures. Main has substantial related logic; compare individual missing rules only. |
| `codex/video-quality-improvements` | 4 / 236 | Transcript seams, visual scoring, speaker/reframe and audio/video quality. Extract useful tests/algorithms after Dart parity review. |
| `cursor/openai-compatible-endpoints-627e` | 1 / 248 | Provider request behavior. Compare with Flutter Phase 7 gateway; port edge-case fixes only. |
| `cursor/auto-zoom-a650` | 1 / 376 | Zoom planning/preview. Flutter parity is not proven; port domain behavior, not React UI. |
| `cursor/size-targeted-export-627e` | 1 / 253 | Size-targeted export. Not confirmed in Flutter; implement after renderer contract is stable. |
| `ccr-515534d3-9jh4xh` | 3 / 205 | Caption, loudness and tighten-join quality fixes. Desktop changes were recovered to mainline; evaluate mobile-specific audio/render parity. |
| `ccr-8b709f89-hh58um` | 5 / 207 | OpenRouter/provider integration. Flutter has separate multi-provider support; compare provider capability and tests. |
| `ccr-72c986a6-jv6spo` | 3 / 206 | B-roll/Metachlorian handoff. Experimental and not approved for Flutter without architecture, policy and license review. |
| `claude/intelligent-ptolemy-rwkam1` | 4 / 210 | Shot-style triage/reframe thresholds. Experimental; require Dart implementation, corpus evidence and golden review. |
| `design/found-frame-foundations` | 1 / 206 | CSS design system for desktop React. Visual reference only; implement native Flutter tokens/widgets. |

This is a changed-path/branch-level audit of representative branches, not a claim that every historical branch commit was ported or every line of every branch was manually reviewed.

## Original upstream/source repositories in the roadmap

| Source | Agreed role | Current integration evidence | Remaining work |
|---|---|---|---|
| `JeremySNR/cutawan` / this codebase | Domain behavior, project concepts, 12 caption styles, editorial/reframe/export reference | Flutter has selected Dart contracts/services; desktop source still present | Maintain behavioral parity for edit history, timeline ops, zoom, composition, audio, branding, render and validation; desktop APIs must be reimplemented for Android. |
| `47gurvinder/whisper_cpp_flutter` (`whisper_cpp_flutter_plus`) | Flutter API, Android Whisper runtime and model catalog | `whisper_cpp_flutter_plus: 0.5.1`; transcription/model manager in Flutter | Arabic/English WER/timing, long-source stitching, device RAM/thermal and VAD/silence rejection acceptance. |
| `ggml-org/whisper.cpp` | Native speech runtime | Included through selected package | Pin exact transitive runtime, verify notices and device behavior. |
| `dragneel2074/Llama-Flutter` (`llama_flutter_android`) | Android llama.cpp/JNI local GGUF inference | `llama_flutter_android: ^0.2.6`; Qwen manager/gateway present | Device compatibility, model quality, memory/thermal, cancellation and model provenance tests. |
| `ggml-org/llama.cpp` | Native local inference | Included through selected package | Pin exact transitive runtime and test lifecycle/ABI. |
| `Anil-matcha/AI-Youtube-Shorts-Generator` | Conceptual highlight/downloader reference | Roadmap says conceptual review only; no runtime dependency | Port only validated ideas/tests to Dart. No Python runtime/scripts. |
| `kiy0ni/auto-video-editor` | Conceptual audio/moment analysis reference | Roadmap says conceptual review only; no runtime dependency | Port only independently validated ideas. No Tkinter/CLI/Python runtime. |
| `artbyjazi/autoclip` | Responsive mobile interaction reference for ingest/jobs/review/trim/captions/settings | Roadmap records repository/UI audit and selected flow inspiration | No code/backend integration; rebuild natively in Flutter, not WebView or FastAPI dependency. |

Other inspected references: `OpenCut-app/OpenCut` is MIT but its web editor route was “Coming soon”; its React components are not Flutter widgets. `mifi/editly` is a Node/FFmpeg framework, not an Android Flutter interface. Neither is integrated as mobile code.

## Flutter implementation status against product plan

| Area | Current state | Gap / acceptance blocker |
|---|---|---|
| Shell/navigation | Material 3, Arabic-first Create/Jobs/Review/Caption Studio and Models entry | Full Dashboard/Settings IA, feature boundaries, back stack and adaptive navigation incomplete |
| Local import | SAF picker, persisted URI grant, metadata bridge | Physical OEM/provider/process-death test open |
| Direct URL | Validated HTTP(S) direct video file download, progress/cancel/cleanup | Direct file only; social platform page extraction intentionally unsupported |
| Projects | Versioned schema/migration/local repository/artifacts | Device lifecycle and stronger concurrent mutation acceptance open |
| Whisper | MediaCodec extraction, mono 16 kHz, local Whisper Base and timed tokens | WER, Arabic/English accuracy, long-source timing, VAD, RAM/thermal checks open |
| Candidate discovery | Sentence/pause boundaries, deterministic score, deduplication/coverage, frame-change evidence | Semantic visual understanding, richer audio events and human review quality open |
| Qwen | Local model manager and constrained annotation | Physical model quality/performance acceptance open |
| Remote providers | OpenAI, Gemini, Hugging Face, generic OpenAI-compatible; secure storage and explicit consent | Real Android Keystore, provider/account/model/billing validation open |
| Reframe | Android frontal-face sampling and saved validated plans | Not active-speaker detection; no audiovisual correlation; render does not apply keyframes |
| Captions | 12 styles, bundled Anton/Poppins, 10 animation modes, RTL preview and preferences | Preview not transcript/playback-timed; no accepted export parity/burn-in |
| Jobs/pipeline | Durable job model, checkpoints, orchestration and interrupted-job state | Background processing/notifications and robust process-death render resume open |
| Editor | No complete mobile editor | Playback, timeline, drag trim, crop/focus, transitions, edit history/undo still required |
| Export | Media3 Transformer H.264/AAC trim/aspect-fit, sidecars, file metadata/hash/duration/dimensions/video-track verification | Dynamic reframing, burned-in animated captions, full decode, audio mix/branding/transitions, per-clip retry and robust recovery incomplete |
| Audio polish | Basic source audio pipeline foundation | Normalization, ducking, mix and tighten-join parity not accepted on Android |
| B-roll | Desktop experimental branch only | Not integrated; needs policy, provenance, offline and render design |
| UI tests | 79 tests per phase register; Flutter CI gates pass on observed commit | Golden/RTL/LTR/accessibility/keyboard/orientation/device screenshot matrix incomplete |

## Critical findings against the original roadmap
1. The original roadmap and newer 0–10 phase register number phases differently. Maintain a crosswalk; do not mark work accepted because code exists under another phase number.
2. Original renderer gate required a Media3-vs-FFmpeg capability spike and preview/export parity. Current Media3 output is a trim/aspect-fit foundation only; full matrix is not passed.
3. Transcripts, candidates, reframe plans and caption preferences exist, but the full chain does not yet produce a polished rendered clip with dynamic crops and timed animated captions.
4. A production mobile Clip Editor remains a major missing feature.
5. The current shared shell uses Dart `part` files; independent feature packages/state ownership and full IA remain incomplete.
6. The current face detector is not active-speaker recognition. Silero VAD and LR-ASD/UltraFace/YuNet mobile runtime/provenance must be resolved before claims or bundling.
7. No complete physical-device corpus/evidence for Arabic/English WER, source URI lifecycle, model install, long videos, video export, thermal/memory/battery or process-death resume.
8. Runtime licenses and model-weight licenses must be assessed separately. LR-ASD and UltraFace provenance/license still unresolved in notices; do not redistribute these model weights until verified.
9. UI/algorithm inspiration from a repo is not equivalent to code/feature integration. Every actual code reuse must record exact upstream commit, source paths, license, modifications and mobile tests.

## Required next actions
1. Keep a machine-readable branch-to-feature inventory and map each unique branch commit to existing Flutter equivalents or concrete missing mobile work; never merge stale branches wholesale.
2. Build a domain parity matrix for source ingestion, transcript, VAD, discovery/ranking, deduplication, edit operations/history, reframe, zoom, composition, captions, audio, branding, renderer and export validation.
3. Finish Flutter screen architecture and deliver the real Clip Editor before more cosmetic-only changes.
4. Implement dynamic reframe in Media3 output and a transcript-timed caption renderer sharing the same edit-plan/layout logic as preview.
5. Add audio mix/normalization, branding, transitions and per-clip retry with real output tests.
6. Integrate VAD and clear license/runtime provenance for LR-ASD/YuNet/UltraFace before claiming active-speaker/face tracking.
7. Complete golden/widget/accessibility matrix and physical ARM64 device acceptance; record device/build/fixture hashes and evidence.
8. Run Mobile Android CI on the exact new main HEAD and record the resulting APK artifact/hash.

## Audit integrity
No stale branch was merged in this audit. The document is a read-only source/branch assessment plus integration plan; it does not claim every external repo or branch feature has been ported. Integration is complete only when native Flutter implementation, license/provenance and acceptance tests exist.
