# Phase 9 — Create and Review workflow record

**Date:** 2026-11-21  
**Repository:** `m5ham3ds/CUTAWAN`  
**Branch:** `main`  
**Accepted head:** `cb0ca70b3bc6751b3c245ab576ff021593e20c92`

## Scope and design rule

Ssemble was used only as a reference for workflow sequencing: source → configure → process → review candidate results → enter the clip editor. Its visual design, branding and assets were not copied. This record prevents redoing Create or Review in later page iterations.

## Create — accepted before this Review pass

### Implemented
- Explicit step 1: select a local Android video or download a direct HTTP/HTTPS video URL; inspect and display its metadata.
- Explicit step 2: configure clip count, target duration/custom range, aspect ratio, export resolution, caption enablement, caption style and animation.
- Project state is not persisted when a source is merely selected. Persistence happens after the user confirms the settings and chooses Create.
- After persistence, HomeShell reloads projects and navigates to Review.
- Uncommitted Android SAF permissions and app-owned downloaded video files are cleaned safely when abandoned; referenced sources are preserved.
- Removed the inactive speaker-tracking switch and stale copy claiming that transcription/discovery engines were not connected.

### Accepted source and evidence
- Final Create commit: `4b91efb9ad587bd8395f580af05b8695f5805a1d` (see canonical full commit at `4b91efb9ad587bd8395f580af05b8695f5805a1d`).
- Mobile Android run: [44909044979](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44909044979).
- Results: format, strict Dart analysis, 142/142 tests, ARM64 APK, ARM64-only ABI and duplicate-library checks succeeded.
- APK artifact ID: `14709735177`; ZIP size 59,029,749 bytes; archive SHA-256 `44c79fdc95e5922f543cea35e04c2b614f520985bc1a821cff6539c94c4a9582`.
- Root/desktop CI: [44909045000](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44909045000) — success.

## Review — current accepted page

### Implemented
1. Source summary includes source dimensions, duration, size and a per-project source verification action.
2. Four workflow checkpoints are visible in order: source, analysis, clips and export.
3. One primary action starts or resumes the full pipeline and presents the current stage/progress.
4. Manual single-stage reruns are grouped under a collapsed “manual stage tools” panel.
5. Transcript and framing evidence are collapsed until requested; Arabic text is RTL, other transcript languages use LTR.
6. Candidate results show title, score, start/end, duration, optional model annotation and rationale. Each candidate opens its existing Clip Editor route.
7. Export records show metadata and whether the MP4 passed full decode validation.
8. Pipeline project identity is tracked so the active stage/progress is not attributed to a different project's card.
9. Review status badges use short labels on narrow phones to prevent the task-status text from forcing horizontal overflow.
10. Updated tests check the new empty state and the new source-check action. A dedicated 320dp RTL widget test covers the staged review page and manual-tools expansion.

### Preserved behavior
- No transcription, candidate discovery, Qwen annotation, framing, pipeline checkpoint, export algorithm or renderer was reimplemented.
- Existing Whisper/Media3/SAF/project-repository contracts remain in use.
- Create and Review were treated as presentation/workflow changes; the underlying domain and processing services were retained.

### Accepted source and evidence
- Review UI commit: `bba71559ff67627800eba5de39f8f3ee9d6d58a7`.
- Review regression test: `9594a735873ebd0b9a3e9100454307f979a1c45f`.
- Directionality/progress and strict-analysis corrections: `1d55a8f214a14dbe736f202a23e80500e708d4b6`, `be1e38b7705939a0c7b0d446efb74090ef060150`.
- Compact status and updated labels: `089ba6bf7163794f480737ae606e0eaab012e779`.
- Per-project source verification assertion and Material import: `ed52b55c81a2c4707ada8160941fee885c78e971`, `cb0ca70b3bc6751b3c245ab576ff021593e20c92`.
- Latest Mobile Android run: [44923605861](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44923605861), run 249.
- Results: **143/143 Flutter tests passed**, format and `flutter analyze --fatal-infos` passed, ARM64 debug APK build and upload passed, native library verification passed.
- APK artifact: `cutawan-mobile-arm64-debug`, ID `14715326297`, size 59,041,250 bytes; archive SHA-256 `9e225ad372fcbdbd4f94456b03104ef2f8cd5a59def43013b1bfcac3dd731fb3`.
- ABI/package check: one ABI, `arm64-v8a`; 10 unique native libraries, no duplicate basenames; GGML libraries `libggml-cpu.so`, `libggml.so`, `libggml-base.so` present.
- Coverage artifact: ID `14715165727`, size 14,416 bytes; archive SHA-256 `c8df52b38be214375b420d71cd7baaaf4c0e63f680d3611ddc57378460f58eed`.
- Root/desktop CI: [44923605965](https://github.com/m5ham3ds/CUTAWAN/actions/runs/44923605965) — success.

## Known limits — do not misrepresent as complete
- Review currently provides entry to edit candidates; it does not yet have independent keep/reject/reorder interactions.
- Exported MP4 records are displayed with validation evidence. A complete export gallery, file delivery/share surface and batch-download management are not in this pass.
- Full physical-device acceptance, long-media quality, process-death/background render acceptance, thermal/battery measurements and exact preview/export parity remain separate open gates.
- Broader Phase 9 is still in progress.

## Resume point — next page only

**Next page to redesign: Clip Editor.**

Order that page around:
1. Video playback and source-time trim.
2. Framing/aspect-ratio/crop/focus.
3. Caption appearance and timing controls relevant to the selected candidate.
4. Save/return to Review and retain candidate identity.

Preserve the existing source-time trim and candidate persistence contracts. Do not re-open the accepted Create/Review work unless a new regression is found. Jobs and Caption Studio are outside this next page pass.
