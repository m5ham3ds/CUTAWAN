# CUTAWAN visual system

This shared design direction is adapted from the handheld design language in the read-only reference repository \`m5ham3ds/RAVEN23\`. RAVEN23 is a visual reference only; it is not a dependency and is never modified.

## Palette

| Role | Dark | Light |
|---|---|---|
| Page | \`#111315\` | \`#FCFCFD\` |
| Foreground | \`#F7F7F7\` | \`#141516\` |
| Secondary text | \`#D6D7D7\` | \`#2F3134\` |
| Muted text | \`#A7A8A8\` | \`#5C5F63\` |
| Hairline | Foreground at 12% | Foreground at 12% |
| Surface | Page + foreground at 4.5% | Page + foreground at 3.5% |
| Raised surface | Page + foreground at 8.5% | Page + foreground at 7% |

The brand accent is RAVEN23 orange, \`#F57C00\`. Keep it restrained: wordmark/brand, determinate progress, small kickers where appropriate, text selection, and the active state of small switches. Ordinary icons, titles, buttons, chips, links, and navigation labels use neutral foreground roles. Video canvases and subtitle artwork keep their content colours.

## Components and geometry

- Cards: 6px corners, hairline border, no elevation.
- Buttons, icon actions and navigation targets: 48dp minimum touch targets, 6px corners where applicable, and neutral filled/outlined/text treatments.
- Chips: pill shape (18px radius); selected chips use foreground fill with inverse text.
- Sheets and modal surfaces: 16px corners.
- Hero/preview frames: 10px corners; preview imagery remains opaque and unaltered.
- Bottom navigation: full-width, edge-to-edge, no floating margin or shadow, 60dp row height, translucent page surface with 12px backdrop blur. Interactive targets respect device safe insets; reduce-motion mode uses a solid surface.

## Type and spacing

CUTAWAN keeps its bundled Poppins fonts so the interface remains usable offline. Type sizes follow the reference scale: hero 30/34, page title 28/32, section 18/24, card title 14/18, body 14/20, metadata 12/16, and button 15. Use 4/8/12/16/20/24/32 spacing steps, 16px phone gutters and 24px tablet gutters.

## Coverage

The shared theme applies these defaults throughout the Flutter app. Page-specific overrides remain only for actual media previews, semantic warning/error states, and progress. The desktop renderer shares the neutral surface, typography, and radius roles through its global Tailwind theme.
