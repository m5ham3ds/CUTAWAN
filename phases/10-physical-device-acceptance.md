# Phase 10 — Physical-device, security, quality and performance acceptance

## Test corpus

- Arabic single-speaker interview.
- Arabic overlapping/multi-speaker discussion.
- English interview/podcast.
- Gaming/webcam and screen demonstration.
- Speech-light and music-heavy source.
- Portrait/landscape and rotated device footage.
- Long file, short file, partial/corrupt video and source with no audio.

## Measurements

- Word error rate and word timestamp alignment against manually reviewed references.
- Candidate completeness, editorial precision, duplicate ratio, source coverage and human selection.
- Face-track retention and crop continuity, not just detector confidence.
- Output full-decode success, duration/size, dimensions, audio continuity and caption timing.
- Memory high-water mark, processing time, thermal throttling, battery and storage peak.
- App restart/resume, URI permission persistence, encrypted key lifecycle and network-consent behavior.

## Acceptance

No phase is marked complete using a unit-test result alone when it has a device or accuracy requirement. Every result records device model, Android version, build SHA, input fixture hashes, test method, metrics and known limitations.


## Diagnostic baseline gate — 2026-11-21

The automated device-class field uses a Build.FINGERPRINT marker heuristic. A result of physical-candidate is not proof that a human has inspected the handset. The UI keeps manual physical-device confirmation separate and leaves it not-verified until a real device session.

The baseline gate requires the physical-device marker check, manufacturer/model, Android release/API, CPU count, total/available RAM, app process PSS, app-private free storage and app version. Missing values remain listed; they are never replaced with zero or inferred data.

The report separately exposes media corpus, Whisper quality, candidate quality, physical full-decode, sustained thermal/performance, process-death resume, SAF lifecycle, Keystore lifecycle and end-to-end network-consent evidence. Each remains not collected or not verified until a real test run is recorded.

CI provides 137 passing Flutter tests and an ARM64-only APK. This validates source, test and packaging gates only. No committed audio/video acceptance fixtures or physical-device measurements exist in the repository. Phase 10 therefore remains incomplete.
