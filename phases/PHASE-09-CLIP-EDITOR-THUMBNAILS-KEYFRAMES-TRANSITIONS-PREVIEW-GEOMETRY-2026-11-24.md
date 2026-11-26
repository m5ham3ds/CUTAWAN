# Phase 9 Clip Editor — Filmstrip, keyframes, fades and preview crop geometry

**Date:** 2026-11-24  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `7b6122f33d5aecb4e9d5be1ef3d0080a6b452376`

## Delivered editor behavior

- The native Android Filmstrip service extracts bounded JPEG frames from the selected video. Flutter validates frame order and image payloads, displays the strip in the Clip Editor, supports tap-to-seek, and refreshes after trim changes.
- Manual focus keyframes are persisted against absolute source-video timestamps, so trimming a clip does not shift existing focus edits. The export plan interpolates focus across contiguous crop regions and Media3 interpolates between the region endpoints.
- Clip-local visual fade-in and fade-out are stored in ClipEditOverrides schema 3. Existing schema 1 and schema 2 files continue to load with zero fade values. Each fade is limited to 1,500 ms and their combined duration must fit inside the selected clip.
- Fade effects are a black visual overlay rendered by Media3 and mirrored by the Flutter preview. They do not alter audio amplitude and do not implement transitions between two separate clips.
- Preview crop alignment now uses one shared normalized-region conversion for both manual and automatic crop framing. The helper converts crop left/top and width/height into FittedBox overflow alignment; using the normalized crop center directly was not equivalent near the frame edges.

## Implementation commits

- Filmstrip: `eb8de1c8d66645666b25bf4899c884e9532211fb`; strict analyzer follow-up: `58625c700a7640f8b875058fee1bac11a51162cf`.
- Source-time focus keyframes and persistence: `8b5961455b06224858c9995f086a82ec840732b7`, `ddea1f2304ee64c1265fc786d870b9d8eebf51d5`, and test correction `d6e84c41e921eb4f1721ee1d152f0c52a70a2bd8`.
- Per-clip fades, schema migration and Media3 overlay integration: `f6104fadd05500ed9723e349fa62422342218dbf`; strict Dart lint correction `e790ed85214050794dc50b342ac184d89e930bbd`; invalid test-range correction `2ad3af33f0ea9283b301051f86df171cee7c9bcb`; Kotlin TextureOverlay type correction `b9c48e3f9a308c75481f33ae32b467f71ad92828`.
- Preview/export crop-geometry correction: `7b6122f33d5aecb4e9d5be1ef3d0080a6b452376`.

## Automated evidence

- Mobile Android run [45313033547](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033547), run 379, passed format, `flutter analyze --fatal-infos`, **228/228 Flutter tests**, ARM64 debug build, ABI/native-library verification and APK upload.
- The APK contains exactly `arm64-v8a`, 10 unique native libraries, the required GGML files (`libggml-cpu.so`, `libggml.so`, `libggml-base.so`) and no duplicate native-library basenames.
- APK artifact [14883968118](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033547/artifacts/14883968118): 60,050,476 bytes; archive SHA-256 `ddb8220ac7be93152208840913ba48e32457707d7d622338a756ff46d10a9eca`.
- Coverage artifact [14883749112](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033547/artifacts/14883749112): 19,611 bytes; SHA-256 `2279ccb0a42bc59f96b9284d15db80c62b02a9b0e629f7e8a36f221131e4e5ff`.
- Root/desktop CI [45313033480](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033480), run 431 — success across checks, Xvfb UI smoke, offline FFmpeg/render pipeline and Apple Silicon packaging.
- Branch Policy [45313033620](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45313033620), run 81 — success; `main` is the only branch.

## Remaining Phase 9 acceptance

- Add an actual sequence/composition model before implementing true clip-to-clip transitions or multitrack edits. Current ProcessingPipelineService exports each candidate as an independent MP4; do not expose a fake multi-track interface.
- Measure preview/export parity on hash-locked test media, including manual and automatic crop edges, keyframe interpolation, captions, fade timing, aspect-ratio changes, rotated sources and fit gaps. The current tests validate geometry math, not pixel-level render equivalence.
- Perform actual ARM64 handset acceptance for hardware Tab behavior, visible focus, RTL/LTR, large text, landscape, system bars, gesture insets, cutouts and OEM rendering.
- Do not infer physical-device acceptance from GitHub Actions, widget tests or simulated insets. Phase 9 remains in progress; Phase 10 must not start until these gates are recorded.


## Sequence transition follow-up — 2026-11-25

This follow-up supersedes the older open transition item above; the earlier clip-editor delivery record remains historically accurate for the accepted per-clip fade slice.

- A sequence model and Media3 Composition export now support adjacent video clips with a bounded dip-to-black transition. The incoming and outgoing visual halves are represented against the composition timeline, so the join is black and the next clip fades in from black.
- The composition overlay is stateless with respect to frame order and explicitly clears its reused CanvasOverlay backing bitmap before every draw. This fixes the stale opaque-black surface observed in the first composition-wide implementation.
- Android instrumentation verifies red-before, dim-red-during, near-black-at-join, dim-blue-during and bright-blue-after pixels from an exported MP4. The full test passes in run [45500607722](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45500607722), run 413.
- The transition affects video only; no audio crossfade is implemented.
- Next: exact preview/export pixel parity remains open and is the next Phase 9 engineering slice. Physical handset accessibility and visual review remain an independent gate.


## Preview/export pixel-parity follow-up — 2026-11-26

This follow-up supersedes the prior statement that pixel parity remained open for the entire Clip Editor preview/export path. The accepted scope is the eight-scenario automated matrix below; it is not a claim of exhaustive caption-animation or all-real-media parity.

- The Android export engine now consumes `regionEnd` and interpolates the crop rectangle at Media3 presentation timestamps. This corrected the ignored end-region behavior exposed by the first keyframe-pan run.
- Android run [45732357835](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357835), run 442, source SHA `846c53c6078691c8af5fe8fe9a07f60823d80ecc`: **24/24 comparisons passed** across 8 scenarios and timestamps 200ms, 1049ms and 1899ms. Limits remained MAE <24 and worst-patch <48.
- The cases cover manual left/right portrait crops, automatic left portrait framing, manual top/bottom landscape crops, vertical keyframe pan, full-frame fit and manual crop with fade-in/out. See the detailed [pixel-parity result table](PHASE-09-PREVIEW-EXPORT-PIXEL-PARITY-ACCEPTANCE-2026-11-26.md).
- The sequence-level dip-to-black remains a separate accepted video-only transition. No audio crossfade or complete multitrack audio mix is claimed.
- **Still open:** actual ARM64 handset visual/accessibility acceptance (hardware Tab, visible focus, RTL/LTR, enlarged text, landscape, real system bars/gesture insets/cutouts and OEM behavior). The physical handset gate is not inferred from CI or the Android emulator.
