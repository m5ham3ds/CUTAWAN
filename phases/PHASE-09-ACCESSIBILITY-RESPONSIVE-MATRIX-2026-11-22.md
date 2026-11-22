# Phase 9 — Accessibility and responsive UI matrix (in progress)

**Started:** 2026-11-22  
**Repository:** `m5ham3ds/CUTAWAN`

## Agreed acceptance matrix

- Compact 320dp viewport in Arabic RTL and English LTR.
- Light and dark Material 3 themes.
- Increased system text scale and no clipped/overlapping critical actions.
- Semantic labels, button roles, selected state and real tap actions for top and bottom navigation.
- Minimum 48dp interactive target size for primary navigation and top-bar icon actions.
- Focus traversal and keyboard activation; landscape and safe-area insets.
- Keep physical handset checks separate from widget/emulator evidence.

## Initial implementation slice

- Increase compact top-bar icon action targets from 40dp to 48dp without changing their icon glyphs.
- Add widget coverage for bottom-navigation semantics, selected state and minimum target height at 320dp across RTL/LTR and light/dark.
- Add compact top-bar target-size and action tests.
- This record remains **in progress** until the Android format/analyze/test/ARM64 build gates pass. The broader matrix and physical UI acceptance remain open.
