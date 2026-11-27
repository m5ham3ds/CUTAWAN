# Phase 6 — Caption Studio, visual presets and timed transcript preview

**Current state:** caption preferences, visual catalog, motion preview, RTL-aware layout and transcript-timed Studio groups are implemented. Real-time playback synchronization and exhaustive preview/export parity remain incomplete.

## Implemented scope

- Preserves 12 CUTAWAN caption style identifiers: Beast, Karaoke, Pill, Minimal, Hormozi, Neon, Ember, Bubble, Lemon, Retro, Crimson and Whisper.
- Provides ten separate preview motion modes: Static, Karaoke Fill, Word Pop, Bounce, Fade, Slide, Typewriter, Glow Pulse, Highlight Sweep and Staggered Words.
- Anton and Poppins font assets are bundled with their license notices.
- The user can edit font family, font size, vertical position, text/highlight/background colors, uppercase/bold, style and motion. Preferences persist with the selected project; older projects use safe defaults.
- The pure-Dart layout engine groups transcript text with punctuation/pause boundaries, supports Arabic punctuation and RTL layout, limits output to two lines and bounds caption holds.
- Caption Studio loads the saved project's transcript words/timing and groups them with the live style/font/scale preferences. The user can select among timed groups; when no transcript is present, the UI explicitly identifies the preview as a sample.

## Source map

- `lib/domain/caption_animation.dart`
- `lib/domain/caption_catalog.dart`
- `lib/domain/caption_layout.dart`
- `lib/screens/features/caption_studio_page.dart`
- `lib/services/caption_sidecar_generator.dart`

## Automated coverage

- `caption_animation_test.dart`, `caption_layout_test.dart`, `caption_sidecar_generator_test.dart`, `caption_timed_preview_test.dart` and `caption_studio_project_selection_test.dart`.
- Tests cover catalog IDs, animation bounds, Unicode Typewriter behavior, RTL groups, punctuation, long words, timing/hold validation, saved preferences and the selected project's transcript.

## Important boundaries

- The Studio groups and selects transcript-timed words but are not synchronized to a continuously playing source-video clock.
- Native Media3 output burns timed caption cues and supports timed `karaoke_fill` word emphasis. The complete ten-mode Flutter preview catalogue is not yet implemented with identical native behavior, font metrics and pixel output.
- The accepted Phase 9 pixel matrix covers eight editor crop/fit/fade scenarios. It is not an exhaustive 12-style × 10-animation subtitle parity certification.
- Human review of Arabic RTL, mixed-script punctuation, baseline placement and text appearance in real exported files is still required.

**Related:** [Phase register](README.md), [Phase 5–6 integration record](../docs/mobile/PHASES_5_6_INTEGRATION.md), [Phase 8 pipeline](08-end-to-end-pipeline-and-export.md).
