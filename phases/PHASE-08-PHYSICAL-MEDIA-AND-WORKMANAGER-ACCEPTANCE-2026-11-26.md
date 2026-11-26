# Phase 8 — Physical ARM64 media, background and export acceptance

**Status:** `BLOCKED — NOT RUN ON PHYSICAL HARDWARE`  
**Prepared:** 2026-11-26  
**Candidate app-code SHA:** `8bd9d5fb1534dc0da52d6b8af484059873f5c397`  
**Android build commit / in-app BUILD_SHA:** `83053e7284e9225a94797d82020235b1914563d1` (test-only changes after the app-code SHA)  
**Android build:** [#447](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45859864265) — automated success  
**APK:** [cutawan-mobile-arm64-debug, artifact 15138487911](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45859864265/artifacts/15138487911)  
**Artifact size:** 60,653,801 bytes  
**Artifact ZIP SHA-256:** `26e96cec9449b249bc1cf0a7d60e6caf62c535be7a1456d270a33b541898333f`

This is a physical-device field checklist. Android #447's automated run and emulator tests passed, but CI, emulator tests, mocked channels and generated short fixtures do not count as physical acceptance. The product source is unchanged from `8bd9d5f`; the APK's in-app build SHA is the test-only build commit `83053e7`. Record each item as `PASS`, `FAIL` or `NOT RUN`, with brief evidence.

## 1. Device and build identity

| Field | Recorded value |
|---|---|
| Manufacturer/model manually confirmed | NOT RECORDED |
| Android version/API | NOT RECORDED |
| ARM64 confirmed | NOT RECORDED |
| Installed in-app source/build SHA | NOT RECORDED |
| Installed APK SHA-256 | NOT RECORDED |
| Test timestamp | NOT RECORDED |
| Battery optimization state for CUTAWAN | NOT RECORDED |
| Notification permission state | NOT RECORDED |

Confirm the physical handset manually. Do not use a build-fingerprint heuristic as proof that a device is physical.

## 2. Real-media fixture matrix

Use media that the tester is permitted to process. Record the source SHA-256 and basic properties without attaching private source videos.

| Fixture | Required observation | Result |
|---|---|---|
| Short portrait MP4 with speech/audio | Import, transcription, candidates, export and full decode | NOT RUN |
| Long MP4 with speech/audio | Sustained processing, storage preflight, completion and full decode | NOT RUN |
| Landscape MP4 | Crop/fit, dimensions and source-time correctness | NOT RUN |
| Variable-frame-rate video | Trim timing and output duration remain correct | NOT RUN |
| Rotated camera footage (90°/270° metadata) | Correct orientation, crop bounds and output dimensions | NOT RUN |
| Video with no audio track | Valid video output; no false audio expectation | NOT RUN |
| Video with silent audio track | Audio track is retained/decoded where present | NOT RUN |
| Corrupt/truncated source | Clear failure; no false successful export or corrupt deliverable | NOT RUN |
| Corrupt/truncated exported file, where safely reproducible | Revalidation rejects it and resume does not skip it | NOT RUN |

## 3. Full-decode and output integrity

For each successful fixture, retain sanitized export validation metadata.

| Check | Required evidence | Result |
|---|---|---|
| Video track | Positive decoded video buffers through end-of-stream | NOT RUN |
| Audio track | If present, positive decoded audio buffers through end-of-stream | NOT RUN |
| Hash | SHA-256 recorded and stable on revalidation | NOT RUN |
| Duration | Output duration matches selected source range within the expected tolerance | NOT RUN |
| Dimensions | Output dimensions match the selected aspect/resolution | NOT RUN |
| Playback | MP4 opens and plays to the end in a real handset player | NOT RUN |
| Crop continuity | No unexpected jumps, stretching or out-of-bounds crop | NOT RUN |
| Captions | Arabic RTL, English LTR, mixed-script punctuation and source-time placement | NOT RUN |

## 4. WorkManager foreground lifecycle

Keep ordinary process death and explicit Android force-stop as separate experiments.

| Scenario | Required evidence | Result |
|---|---|---|
| Background completion | Start multi-clip processing, leave CUTAWAN in background, verify worker completes | NOT RUN |
| Ordinary process death | Terminate the app process without force-stop; relaunch and recover the active/completed render | NOT RUN |
| Durable handoff | Relaunch adopts a completed render without duplicating the render or losing its result | NOT RUN |
| Progress notification | Notification appears and progress changes during a long render | NOT RUN |
| Notification cancel | Notification action cancels the active render and project state becomes cancelled | NOT RUN |
| Notification permission denied | Record the Android permission behavior and whether foreground work remains correctly managed | NOT RUN |
| Explicit force-stop | Record that Android may defer work until the app is manually launched again; verify safe recovery after launch | NOT RUN |
| OEM battery restriction | Repeat with device battery restrictions/optimization enabled and record actual behavior | NOT RUN |
| Cancellation latency | Record time from user/notification cancel action to worker termination and UI state update | NOT RUN |
| Cleanup | Temporary outputs, durable completion records and notification state are reconciled after success/cancel/failure | NOT RUN |

## 5. Targeted per-clip re-render and output cleanup

Use a project with at least two fully validated clip exports.

| Scenario | Required evidence | Result |
|---|---|---|
| Re-render one clip | Only the selected clip starts a new render | NOT RUN |
| Preserve peers | Other clips remain accessible with unchanged output URIs and SHA-256 values | NOT RUN |
| Replace old target | New target is fully validated and saved before the old target is deleted | NOT RUN |
| Cleanup failure | If old-output deletion fails, its URI remains visible in the cleanup action; the working export remains usable | NOT RUN |
| Retry cleanup | Cleanup action removes the retained old URI and clears its pending record | NOT RUN |
| Invalid peer checkpoint | If another clip is missing, stale or unverifiable, targeted retry refuses and asks for full-project resume | NOT RUN |
| Failed replacement | Simulate/observe a failed render and confirm the prior valid export remains available | NOT RUN |
| Delete current export | Current file and any pending superseded files are handled safely; no unrelated clip is deleted | NOT RUN |

## 6. Evidence package and sign-off

Attach only the sanitized diagnostics JSON, source fixture hashes/properties, export validation metadata, screenshots/screen recordings of notifications and Clip Editor/export behavior, and test notes. Do not attach credentials, serial numbers, personal storage paths or private source media.

| Sign-off item | Status |
|---|---|
| Physical ARM64 device identity and installed build SHA match | NOT RUN |
| Applicable real-media fixtures pass | NOT RUN |
| Full-decode and output integrity pass | NOT RUN |
| WorkManager background/relaunch/force-stop/OEM checks pass | NOT RUN |
| Notification and cancellation checks pass | NOT RUN |
| Targeted re-render preserves peer exports and cleans/reports prior output | NOT RUN |
| Failures linked to issues/commits and retested on a new build | NOT RUN |
| Reviewer/date recorded | NOT RECORDED |

**Acceptance rule:** Phase 8 remains in progress until the physical ARM64 media, lifecycle, notification, cancellation, targeted re-render and output-integrity evidence is attached. A CI pass or emulator run does not satisfy this checklist.
