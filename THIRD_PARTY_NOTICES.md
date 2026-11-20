# Third-party notices

CUTAWAN is distributed under the MIT License in the repository root. This file records third-party components identified during the Android port audit. It is not a substitute for the complete license texts shipped with their source packages.

## Included by the Flutter Android app

| Component | Version / source | License | Usage |
|---|---|---|---|
| Flutter SDK and Flutter framework | CI toolchain: Flutter 3.47.6 | BSD-3-Clause | Application framework and Android embedding |
| `path_provider` | `^2.1.6` | BSD-3-Clause | Resolves app support/storage directories |
| `crypto` | `^3.0.6` | BSD-3-Clause | SHA-256 model integrity verification |
| `http` | `^1.5.0` | BSD-3-Clause | Pinned model downloads |
| `whisper_cpp_flutter_plus` | `^0.5.1` | MIT | Flutter API, native whisper.cpp integration and checksum model catalog |
| `llama_flutter_android` | `^0.2.6` | MIT | Android llama.cpp/JNI integration for GGUF inference |

The package license is published by the verified Flutter publisher on pub.dev: https://pub.dev/packages/path_provider/license

The native Android bridge in `mobile/flutter_app/tooling/android/MainActivity.kt` uses Android SDK APIs (Storage Access Framework, MediaMetadataRetriever, MediaExtractor, MediaCodec and StatFs).

Both selected Flutter inference packages and their underlying `ggml-org/whisper.cpp` / `ggml-org/llama.cpp` code are MIT-licensed. Retain the package and upstream license notices when redistributing the app:

- [whisper_cpp_flutter_plus MIT license](https://github.com/47gurvinder/whisper_cpp_flutter/blob/main/LICENSE)
- [whisper.cpp MIT license](https://github.com/ggml-org/whisper.cpp/blob/master/LICENSE)
- [llama_flutter_android MIT license](https://github.com/dragneel2074/Llama-Flutter/blob/master/LICENSE)
- [llama.cpp MIT license](https://github.com/ggml-org/llama.cpp/blob/master/LICENSE)
- [Dart crypto BSD-3-Clause](https://pub.dev/packages/crypto/versions/3.0.6/license)
- [Dart http BSD-3-Clause](https://pub.dev/packages/http/versions/1.5.0/license)

The Whisper Base weights originate from OpenAI Whisper and are covered by the [OpenAI Whisper MIT license](https://github.com/openai/whisper/blob/main/LICENSE). The Qwen GGUF weights are Apache-2.0. Neither model is embedded in the APK; keep each model's source, revision, digest and license record with the app's notices.

## Model and font assets retained in the source repository

| Asset | License | Notice/source file |
|---|---|---|
| Silero VAD ONNX model | MIT | `resources/models/silero-vad-LICENSE`, `silero-vad-source.md` |
| OpenCV Zoo YuNet ONNX model | MIT | `resources/models/yunet-LICENSE`, `yunet-source.md` |
| Anton font | SIL Open Font License 1.1 | `resources/fonts/OFL-Anton.txt` |
| Poppins fonts | SIL Open Font License 1.1 | `resources/fonts/OFL-Poppins.txt` |

Retain the relevant license and attribution files whenever these assets are redistributed. The current Flutter application does not declare the ONNX models or font files as Flutter assets; their presence in the desktop source tree must not be read as proof that they are packaged in the Android APK.

## Desktop/Electron dependency licenses — not Android dependencies

The versions below are taken from the repository's committed `package-lock.json`. They describe the desktop application dependency tree, not the Flutter Android app.

| Direct package | Locked version | Declared package license |
|---|---:|---|
| `electron-updater` | 6.8.9 | MIT |
| `ffmpeg-static` | 5.3.0 | GPL-3.0-or-later |
| `@ffprobe-installer/ffprobe` | 2.1.2 | LGPL-2.1 |
| `onnxruntime-node` | 1.27.0 | MIT |

The `ffmpeg-static` package declares GPL-3.0-or-later. Before distributing desktop binaries, review the actual FFmpeg build configuration and corresponding source/license obligations. Do not reuse this packaged desktop binary in the Android app without a separate compatibility and licensing review.

The package-level license field for `@ffprobe-installer/ffprobe` is LGPL-2.1. Review the exact installed FFprobe binary and its build configuration before redistribution.

## Other ONNX model files — provenance/license verification required

The repository also contains `lr-asd-backend.onnx`, `lr-asd-frontend.onnx`, and `ultraface-rfb-320.onnx`. The source tree inspected for this inventory does not provide a matching license notice/source record for each of these files. Their redistribution or inclusion in a mobile release remains blocked pending provenance, exact model version, and license verification.

## Inventory maintenance

Update this notice whenever a dependency or model is added, upgraded, removed, or packaged into the Android app. Use the generated lockfiles and each upstream package's license file as the source of truth; do not infer a license from a project name or from a wrapper package's license alone.


## Phase 3–4 model weights

| Model | Exact pinned source | License | Distribution |
|---|---|---|---|
| Whisper Base multilingual (`ggml-base.bin`) | `ggerganov/whisper.cpp`, revision `5359861c739e955e79d9a303bcbc70fb988958b1`; SHA-256 `60ed5bc3dd14eea856493d334349b405782ddcaf0028d4b5df4088345fba2efe` | MIT (OpenAI Whisper model weights) | Downloaded only after user action; not bundled in APK |
| Qwen2.5-0.5B-Instruct Q4_K_M | `Qwen/Qwen2.5-0.5B-Instruct-GGUF`, revision `6dd44a1fb35d11b5d1b28902876ce3cc9e882d0e`; SHA-256 `74a4da8c9fdbcd15bd1f6d01d621410d31c6fc00986f5eb687824e7b93d7a9db` | Apache-2.0 | Downloaded only after user action; not bundled in APK |

Model URLs, exact file size, digest, and user-controlled installation behavior are documented in `docs/mobile/PHASES_3_4_INTEGRATION.md`. The app verifies the digest before installing either model.

## Mobile caption fonts

The Android Flutter companion bundles the existing CUTAWAN caption font files:
- Anton Regular — SIL Open Font License 1.1; license text: `mobile/flutter_app/assets/fonts/OFL-Anton.txt`.
- Poppins Medium and Bold — SIL Open Font License 1.1; license text: `mobile/flutter_app/assets/fonts/OFL-Poppins.txt`.

These files are copied from `resources/fonts/` without modification and are used by the native caption preview. See the included license texts for the complete terms.


## Secure provider credentials

- `flutter_secure_storage` (Flutter package, Android implementation): MIT License. Used for user-entered provider API keys and provider preferences. Android data is encrypted using the platform secure-storage implementation; the generated application manifest disables backup so ciphertext cannot be restored without the original device Keystore key material.
- No API key is embedded in the APK, written into project JSON, or printed to logs.
