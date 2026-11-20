# Dependency and model license inventory

Audit snapshot: 2026-11-20  
Repository: `m5ham3ds/CUTAWAN`  
Primary application: MIT-licensed CUTAWAN Electron source with a separate Flutter Android app.

## Android app dependency scope

Direct Flutter dependencies from `mobile/flutter_app/pubspec.yaml`:

| Dependency | Constraint | License | Used for |
|---|---|---|---|
| Flutter SDK | CI uses 3.47.6 | BSD-3-Clause | UI/runtime/Android embedding |
| `path_provider` | ^2.1.6 | BSD-3-Clause | app support directory for persisted projects and downloads |
| `crypto` | ^3.0.6 | BSD-3-Clause | SHA-256 model integrity checks |
| `http` | ^1.5.0 | BSD-3-Clause | pinned model downloads |
| `whisper_cpp_flutter_plus` | ^0.5.1 | MIT | Whisper.cpp Android transcription |
| `llama_flutter_android` | ^0.2.6 | MIT | llama.cpp Android GGUF inference |

No FFmpeg package, ONNX Runtime package, or Python runtime is declared by the Flutter app. Direct source-video URL downloads use Dart `dart:io`; local media selection, audio extraction, and frame sampling use Android platform APIs through the MethodChannel bridge. The app now also declares the two native inference bridges listed above.

## Desktop dependency scope (from package-lock.json)

### Production dependencies

| Package | Locked version | Package license |
|---|---:|---|
| `electron-updater` | 6.8.9 | MIT |
| `ffmpeg-static` | 5.3.0 | GPL-3.0-or-later |
| `@ffprobe-installer/ffprobe` | 2.1.2 | LGPL-2.1 |
| `onnxruntime-node` | 1.27.0 | MIT |

Important: the FFmpeg binary/package license is a material distribution consideration for Electron desktop releases. Verify the binary's configuration and applicable notices/source obligations before redistribution. The Android implementation must not inherit these desktop binaries by accident.

### Development dependencies

The package lock identifies the direct development toolchain as MIT except where noted:

| Package | Locked version | License |
|---|---:|---|
| `@eslint/js` | 10.0.1 | MIT |
| `@tailwindcss/vite` | 4.3.2 | MIT |
| `@types/node` | 22.20.0 | MIT |
| `@types/react` | 19.2.17 | MIT |
| `@types/react-dom` | 19.2.3 | MIT |
| `@vitejs/plugin-react` | 4.7.0 | MIT |
| `electron` | 35.7.5 | MIT |
| `electron-builder` | 25.1.8 | MIT |
| `electron-vite` | 3.1.0 | MIT |
| `eslint` | 10.6.0 | MIT |
| `eslint-plugin-react-hooks` | 7.1.1 | MIT |
| `js-yaml` | 4.3.0 | MIT |
| `lucide-react` | 0.487.0 | ISC |
| `react` | 19.2.7 | MIT |
| `react-dom` | 19.2.7 | MIT |
| `tailwindcss` | 4.3.2 | MIT |
| `tsx` | 4.23.0 | MIT |
| `typescript` | 5.9.3 | Apache-2.0 |
| `typescript-eslint` | 8.62.1 | MIT |
| `vite` | 6.4.3 | MIT |
| `vitest` | 4.1.9 | MIT |
| `zustand` | 5.0.14 | MIT |

The lockfile remains the source of exact versions and the full transitive package inventory. This short table is the direct package summary, not a full generated SBOM.

## Model/font asset inventory

| Asset | License status | Source evidence |
|---|---|---|
| Silero VAD v5 ONNX | MIT | `resources/models/silero-vad-source.md` and adjacent license |
| YuNet face detector ONNX | MIT | `resources/models/yunet-source.md` and adjacent license |
| Anton | SIL OFL 1.1 | `resources/fonts/OFL-Anton.txt` |
| Poppins | SIL OFL 1.1 | `resources/fonts/OFL-Poppins.txt` |
| LR-ASD frontend/backend ONNX | Pending verification | No adjacent source/license notice found in the audited tree |
| UltraFace RFB-320 ONNX | Pending verification | No adjacent source/license notice found in the audited tree |

Do not bundle or redistribute model files with pending license provenance in a release until their exact upstream source, model version, and license terms are documented.

## Scope decisions for the first two mobile phases

- No `youtubedl-android` package or yt-dlp engine was added to the mobile app.
- No GPL FFmpeg package was added to `pubspec.yaml`.
- No ONNX models were copied into the Flutter assets.
- Keep mobile ingestion based on Android SAF for user-selected files and Dart HTTP streaming for user-provided direct video-file URLs.
- Re-audit when the AI/media engines are selected in later phases; do not assume that an MIT wrapper makes an underlying binary or model MIT.


## Phase 3–4 model manifest

| Model | Pinned revision | SHA-256 | Size | License | Packaging |
|---|---|---|---:|---|---|
| Whisper Base multilingual (`ggml-base.bin`) | `5359861c739e955e79d9a303bcbc70fb988958b1` | `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe` | 147,951,465 bytes | MIT (OpenAI Whisper model weights) | User download; never packaged in APK |
| Qwen2.5-0.5B-Instruct Q4_K_M | `6dd44a1fb35d11b5d1b28902876ce3cc9e882d0e` | `74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db` | 491,400,032 bytes | Apache-2.0 | User download; never packaged in APK |

See `docs/mobile/PHASES_3_4_INTEGRATION.md` for implementation boundaries and remaining physical-device acceptance gates.
