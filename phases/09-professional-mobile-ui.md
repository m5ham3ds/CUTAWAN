# Phase 9 — Professional mobile interface redesign

## Objective

Replace the current large, monolithic screen composition with a coherent mobile design system and task-focused screens. Preserve all domain logic and tests while moving presentation to small feature widgets.

## Proposed information architecture

- Dashboard / Projects: recent projects, storage use, quick resume, clear empty state.
- Create: source import, permitted direct video URL, media metadata, output profile and run options.
- Jobs: durable progress stage, active/queued/completed sections, cancel/retry/resume.
- Review: candidate preview, time range, rationale, model provenance, keep/reject/reorder.
- Clip editor: real preview, trim handles, safe crop, manual focus, transitions.
- Caption Studio: preset gallery, typography, animation, word timing, RTL preview, custom color controls.
- AI Center: local runtimes/models, provider selector, credentials, account-scoped model list and privacy mode.
- Settings: performance, language, storage, privacy, exports and licenses.

## Design system

- Define semantic color and type tokens, surface levels, radii, spacing, controls, status/error/success styles.
- Avoid dense raw controls and huge single-column forms; use progressive disclosure, collapsible advanced settings and clearly grouped cards.
- Add reusable project/clip/model cards and shared loading/error/empty patterns.
- Respect safe areas, keyboard insets, font scaling, landscape, narrow screens and RTL.
- Avoid claiming unavailable functions; disabled controls explain the missing dependency.
- Navigation and back-stack behavior must be consistent.

## Tests

- Golden/widget tests for light/dark theme, Arabic/English, small and large viewport, accessibility labels and keyboard.
- Navigation between screens without losing state.
- Every primary action has a callback to an implemented service and asserts state changes.
- Verify no card overflow on 320dp width.

## Implementation update — 2026-11-20

**Status: architecture and first visual-system slice delivered; redesign remains in progress.**

- Extracted the previous large home_shell.dart presentation into feature part files for Create, Jobs, Review, Caption Studio, Models and shared widgets. The root file retains shared state/navigation and service wiring.
- Added a shared Material 3 design system with light and dark themes selected using system appearance, semantic surfaces, shared card/input/button/navigation treatments and consistent radii.
- Added job stage/progress presentation, direct Jobs-to-Review navigation, a single full-pipeline/resume action, visible export records and disabled conflicting manual actions while the pipeline is running.
- Startup recovery converts interrupted running tasks into a visible resumable failure state.

### Explicit remaining work and acceptance blockers

- These are Dart part files in a single library, not yet fully isolated feature packages with independent state management and dependency boundaries.
- Dashboard/Create/Jobs/Review/Clip Editor/Caption Studio/AI Center/Settings are not all redesigned to the complete information architecture; there is no complete clip editor with interactive trim/crop/focus controls.
- New tests cover theme configuration and a narrow viewport smoke case, but comprehensive golden tests, RTL and English layouts, text scaling, keyboard insets, landscape, accessibility labels, back-stack navigation and state retention remain.
- UI smoke tests and Android Flutter tests/build are pending for the latest commit; no physical-device screenshots or overflow acceptance evidence exists.

Do not mark the phase complete until the remaining screens and design-system test matrix above pass.
