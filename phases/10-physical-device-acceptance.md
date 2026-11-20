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
