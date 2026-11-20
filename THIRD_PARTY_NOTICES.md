# Third-party notices

CUTAWAN is distributed under the MIT License in the repository root. This file records third-party components identified during the Android port audit. It is not a substitute for the complete license texts shipped with their source packages.

## Included by the Flutter Android app

| Component | Version / source | License | Usage |
|---|---|---|---|
| Flutter SDK and Flutter framework | CI toolchain: Flutter 3.47.6 | BSD-3-Clause | Application framework and Android embedding |
| `path_provider` | `^2.1.6` | BSD-3-Clause | Resolves app support/storage directories |

The package license is published by the verified Flutter publisher on pub.dev: https://pub.dev/packages/path_provider/license

The native Android bridge in `mobile/flutter_app/tooling/android/MainActivity.kt` uses Android SDK APIs (Storage Access Framework, MediaMetadataRetriever, StatFs) and does not add a separate third-party native package.

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
