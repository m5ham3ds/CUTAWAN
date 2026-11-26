# Phase 9 — Physical ARM64 handset acceptance checklist

**Status:** `BLOCKED — NOT RUN ON PHYSICAL HARDWARE`  
**Prepared:** 2026-11-26  
**Candidate build SHA:** `846c53c6078691c8af5fe8fe9a07f60823d80ecc`  
**APK:** [cutawan-mobile-arm64-debug, artifact 15078655021](https://github.com/m5ham3ds/CUTAWAN/actions/runs/45732357835/artifacts/15078655021)  
**APK size:** 60,639,483 bytes  
**APK SHA-256:** `e46e015943ff4476b4f2ccde2c449894f8a1cc90a1c80bf8879c3716449e27ab`

This checklist is the remaining physical gate after Android #442 passed the automated build and emulator pixel matrix. Do not convert any unrun item into a pass. Record each item as `PASS`, `FAIL` or `NOT RUN` and attach the observation/evidence.

## 1. Build and device identity

| Field | Recorded value |
|---|---|
| Installed build SHA from **تشخيص الجهاز** | `NOT RECORDED` |
| Manufacturer/model confirmed by tester | `NOT RECORDED` |
| Android release/API | `NOT RECORDED` |
| Physical ARM64 device confirmed by human | `NOT RECORDED` |
| Test timestamp | `NOT RECORDED` |
| APK artifact installed from run 442 | `NOT CONFIRMED` |

Do not use the Android fingerprint heuristic alone as proof that the handset is physical. Confirm the device manually and verify that the in-app build SHA equals the candidate SHA above.

## 2. Visual and responsive behavior

| Check | Required evidence | Result |
|---|---|---|
| Arabic RTL | Dashboard, Settings, Models, Diagnostics and Clip Editor; no clipped or reversed controls | NOT RUN |
| English LTR | Same routes and primary actions | NOT RUN |
| Large text | System font scale 1.5× and 2.0×; no horizontal/vertical overflow or obscured actions | NOT RUN |
| Portrait | App bars, bottom navigation, scroll regions and editor controls | NOT RUN |
| Landscape | Dashboard, Settings, Models, Diagnostics and Clip Editor remain usable | NOT RUN |
| System UI | Real status bar, navigation bar, edge-to-edge and gesture navigation insets | NOT RUN |
| Cutouts/OEM | Actual cutout/rounded-corner and OEM window behavior | NOT RUN |
| Light/dark | System light and dark modes, selected states and readability | NOT RUN |

## 3. Hardware keyboard and visible focus

Use a physical keyboard where available. If the handset test setup does not include one, record hardware Tab checks as `NOT RUN`, not pass.

| Control/behavior | Required evidence | Result |
|---|---|---|
| Tab traversal | Actual order through each page's interactive controls | NOT RUN |
| Enter/Space activation | Focused buttons, switches, chips and navigation items invoke the intended action once | NOT RUN |
| Buttons and text fields | Visible focus indicator against light/dark surfaces | NOT RUN |
| ListTile | Raster-visible focus and contrast | NOT RUN |
| SwitchListTile | Raster-visible focus without obscuring switch state | NOT RUN |
| Chips | Raster-visible focus, selected and unselected states | NOT RUN |
| Back/navigation | Hardware/system Back returns correctly without losing saved editor state | NOT RUN |

Capture screenshots or short screen recordings showing the focused state. Widget semantics alone are not sufficient.

## 4. Clip Editor on the physical handset

Use a permitted source video with visible landmarks and retain its hash outside personal/private media paths.

| Check | Required evidence | Result |
|---|---|---|
| Filmstrip | Thumbnails load, tapping seeks correctly, trim changes refresh the strip | NOT RUN |
| Trim | Start/end handles and source-time boundaries remain correct | NOT RUN |
| Manual focus | Start, middle and end keyframes visibly move the crop as expected | NOT RUN |
| Crop edges | Left/right/top/bottom focus remains inside source bounds | NOT RUN |
| Full-frame fit | Letterbox/pillarbox regions are intentional; source is not unexpectedly stretched | NOT RUN |
| Fade in/out | Preview and rendered file show the expected visual black fades | NOT RUN |
| Sequence transition | Adjacent clips show dip-to-black; note that this transition is video-only | NOT RUN |
| Export playback | Exported MP4 opens and plays on the physical handset; retain the export validation report | NOT RUN |

The automated 24-frame emulator matrix is already accepted and must not be re-run as a substitute for this field check. This section is a device-level visual/workflow check, not an assertion that every real-media class is covered.

## 5. Evidence package and sign-off

Attach only evidence needed for acceptance: the sanitized diagnostics JSON, screenshots/screen recordings of the listed visual and focus states, test notes, and relevant export validation metadata. Do not attach account credentials, serial numbers, personal paths or private source media.

| Sign-off item | Status |
|---|---|
| Device/build identity matches candidate SHA | NOT RUN |
| All applicable visual/layout checks pass | NOT RUN |
| Hardware Tab/focus checks pass or are explicitly unavailable | NOT RUN |
| Clip Editor field checks pass | NOT RUN |
| Failures have linked issues/commits and a new verified build | NOT RUN |
| Reviewer/date recorded | NOT RECORDED |

**Acceptance rule:** Phase 9 remains in progress until the applicable physical handset checks and evidence are recorded. A build, emulator, widget test or simulated inset is not physical-device acceptance.

Phase 8 has separate field gates for WorkManager process-death/relaunch/force-stop/OEM behavior, notification/cancellation, real-media full decode and performance. Phase 10 remains blocked until Phase 9 is physically accepted and the Phase 8 prerequisite evidence is available.
