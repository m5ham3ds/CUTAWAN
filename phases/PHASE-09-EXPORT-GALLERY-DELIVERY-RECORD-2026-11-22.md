# Phase 9 — Export gallery and delivery record

**Date:** 2026-11-22  
**Repository:** `m5ham3ds/CUTAWAN`  
**Accepted source SHA:** `6b9ba1f4689c98567c6eb677d4d05e6037945616`

## Delivered

- Review's exported-video cards retain display name, dimensions, duration, size and full-decode validation evidence.
- Open and share actions are exposed only for records whose metadata is validated and whose MP4 passed full decode.
- Delete requires an explicit confirmation. The local project export record is removed only after Android confirms that the underlying media object was deleted.
- Native MediaStore access is restricted to published `video/mp4` rows under `Movies/CUTAWAN/` whose owner package is this application.
- Older app-private file exports are shared using AndroidX FileProvider, with path declarations restricted to CUTAWAN's own export directories. Arbitrary external file URIs and unsupported URI schemes are rejected.
- Added service tests for open/share/delete MethodChannel actions and unsupported URI rejection; repository tests for record deletion and unsafe clip IDs; a Review widget test for the complete open/share/confirm-delete workflow at 320dp RTL.

## Correction during acceptance

- Android run 285 failed only in the new Review widget test. The log showed that the export card remained at y=2018, outside the 320x720 test viewport; `ensureVisible` was not allowed to settle before the tap.
- Added `pumpAndSettle()` after each scroll-to-visible and between actions. This was a test synchronization defect, not a production MethodChannel or Android URI failure.
- The corrected test passed in run 286.

## Acceptance evidence

- Android run [45034907917](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907917), run 286, SHA `6b9ba1f4689c98567c6eb677d4d05e6037945616` — **success**.
- Dart format: passed.
- `flutter analyze --fatal-infos`: passed.
- Flutter unit/widget suite: **172/172 passed**.
- ARM64 debug APK: built and uploaded successfully.
- ABI verification: exactly `arm64-v8a`; duplicate-native-library check passed.
- APK artifact [`cutawan-mobile-arm64-debug`, ID 14759537141](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907917/artifacts/14759537141): 59,998,467 bytes; ZIP SHA-256 `7be81d04380f9e981ec20e21a2b83ab692190fb518251467ee338026584a5617`.
- Coverage artifact [ID 14759420912](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907917/artifacts/14759420912): 17,293 bytes.
- Root/desktop CI [run 45034907987](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45034907987), run 330 — **success** across checks, UI smoke, offline FFmpeg/render pipeline and Apple Silicon package validation.

## Remaining limits

- This is automated export gallery/delivery acceptance, not physical-device acceptance of third-party chooser/player integration or MediaStore deletion on OEM Android builds.
- Accessibility/focus/keyboard/landscape/safe-area and visual golden matrices remain open.
- Phase 8 background-render/process-death/codec/thermal and Phase 10 media-quality/privacy/performance handset acceptance remain open.

**Decision:** accept the export gallery/delivery slice and proceed to Phase 9 accessibility/responsive UI acceptance.
