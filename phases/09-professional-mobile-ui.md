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
