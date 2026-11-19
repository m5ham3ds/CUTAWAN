class CaptionStylePreset {
  const CaptionStylePreset({
    required this.id,
    required this.name,
    required this.fontFamily,
    required this.fontScale,
    required this.uppercase,
    required this.textColor,
    required this.highlightColor,
    required this.outlineColor,
    required this.outlineWidth,
    required this.shadow,
    required this.bold,
    required this.positionY,
    required this.wordsPerGroup,
    this.highlightBoxColor,
  });

  final String id;
  final String name;
  final String fontFamily;
  final double fontScale;
  final bool uppercase;
  final String textColor;
  final String highlightColor;
  final String? highlightBoxColor;
  final String outlineColor;
  final double outlineWidth;
  final double shadow;
  final bool bold;
  final double positionY;
  final int wordsPerGroup;
}

class CaptionAnimationPreset {
  const CaptionAnimationPreset({
    required this.id,
    required this.name,
    required this.description,
    required this.defaultDurationMs,
  });

  final String id;
  final String name;
  final String description;
  final int defaultDurationMs;
}

/// The 12 visual presets ported from Cutawan's existing caption style catalogue.
const captionStylePresets = <CaptionStylePreset>[
  CaptionStylePreset(
    id: 'beast', name: 'Beast', fontFamily: 'Anton', fontScale: 0.052,
    uppercase: true, textColor: '#FFFFFF', highlightColor: '#FFD400',
    outlineColor: '#000000', outlineWidth: 3.2, shadow: 1, bold: false,
    positionY: 0.72, wordsPerGroup: 3,
  ),
  CaptionStylePreset(
    id: 'karaoke', name: 'Karaoke', fontFamily: 'Poppins', fontScale: 0.046,
    uppercase: false, textColor: '#FFFFFF', highlightColor: '#4ADE80',
    outlineColor: '#000000', outlineWidth: 2.6, shadow: 1, bold: true,
    positionY: 0.74, wordsPerGroup: 4,
  ),
  CaptionStylePreset(
    id: 'pill', name: 'Pill', fontFamily: 'Anton', fontScale: 0.044,
    uppercase: true, textColor: '#FFFFFF', highlightColor: '#FFFFFF',
    highlightBoxColor: '#7C3AED', outlineColor: '#000000',
    outlineWidth: 0, shadow: 0, bold: false,
    positionY: 0.74, wordsPerGroup: 3,
  ),
  CaptionStylePreset(
    id: 'minimal', name: 'Minimal', fontFamily: 'Poppins Medium',
    fontScale: 0.038, uppercase: false, textColor: '#FFFFFF',
    highlightColor: '#FFFFFF', outlineColor: '#000000',
    outlineWidth: 1.6, shadow: 0, bold: false,
    positionY: 0.80, wordsPerGroup: 6,
  ),
  CaptionStylePreset(
    id: 'hormozi', name: 'Hormozi', fontFamily: 'Anton', fontScale: 0.05,
    uppercase: true, textColor: '#FFFFFF', highlightColor: '#FFFFFF',
    highlightBoxColor: '#16A34A', outlineColor: '#000000',
    outlineWidth: 2.8, shadow: 1, bold: false,
    positionY: 0.70, wordsPerGroup: 3,
  ),
  CaptionStylePreset(
    id: 'neon', name: 'Neon', fontFamily: 'Poppins', fontScale: 0.046,
    uppercase: false, textColor: '#FFFFFF', highlightColor: '#22D3EE',
    outlineColor: '#164E63', outlineWidth: 3, shadow: 2, bold: true,
    positionY: 0.74, wordsPerGroup: 4,
  ),
  CaptionStylePreset(
    id: 'ember', name: 'Ember', fontFamily: 'Anton', fontScale: 0.052,
    uppercase: true, textColor: '#FFF7ED', highlightColor: '#FB923C',
    outlineColor: '#431407', outlineWidth: 3.2, shadow: 1, bold: false,
    positionY: 0.72, wordsPerGroup: 3,
  ),
  CaptionStylePreset(
    id: 'bubble', name: 'Bubble', fontFamily: 'Poppins', fontScale: 0.042,
    uppercase: false, textColor: '#FFFFFF', highlightColor: '#FFFFFF',
    highlightBoxColor: '#2563EB', outlineColor: '#000000',
    outlineWidth: 0, shadow: 0, bold: true,
    positionY: 0.76, wordsPerGroup: 4,
  ),
  CaptionStylePreset(
    id: 'lemon', name: 'Lemon', fontFamily: 'Anton', fontScale: 0.046,
    uppercase: true, textColor: '#FFFFFF', highlightColor: '#111111',
    highlightBoxColor: '#FACC15', outlineColor: '#000000',
    outlineWidth: 1.8, shadow: 0, bold: false,
    positionY: 0.74, wordsPerGroup: 3,
  ),
  CaptionStylePreset(
    id: 'retro', name: 'Retro', fontFamily: 'Anton', fontScale: 0.05,
    uppercase: true, textColor: '#FDE68A', highlightColor: '#F472B6',
    outlineColor: '#3B0764', outlineWidth: 3, shadow: 2, bold: false,
    positionY: 0.72, wordsPerGroup: 3,
  ),
  CaptionStylePreset(
    id: 'crimson', name: 'Crimson', fontFamily: 'Poppins', fontScale: 0.048,
    uppercase: true, textColor: '#FFFFFF', highlightColor: '#EF4444',
    outlineColor: '#000000', outlineWidth: 3, shadow: 1, bold: true,
    positionY: 0.72, wordsPerGroup: 3,
  ),
  CaptionStylePreset(
    id: 'whisper', name: 'Whisper', fontFamily: 'Poppins Medium',
    fontScale: 0.034, uppercase: false, textColor: '#E4E4E7',
    highlightColor: '#A5F3FC', outlineColor: '#000000',
    outlineWidth: 1.2, shadow: 0, bold: false,
    positionY: 0.82, wordsPerGroup: 7,
  ),
];

/// Independent animation choices; these are not claimed to be rendered yet.
const captionAnimationPresets = <CaptionAnimationPreset>[
  CaptionAnimationPreset(
    id: 'static', name: 'Static', description: 'No motion.',
    defaultDurationMs: 0,
  ),
  CaptionAnimationPreset(
    id: 'karaoke_fill', name: 'Karaoke Fill',
    description: 'Highlight each spoken word in sync with its timing.',
    defaultDurationMs: 180,
  ),
  CaptionAnimationPreset(
    id: 'word_pop', name: 'Word Pop',
    description: 'Briefly scale up the active word.',
    defaultDurationMs: 160,
  ),
  CaptionAnimationPreset(
    id: 'bounce', name: 'Bounce',
    description: 'A short spring-like entrance for each word.',
    defaultDurationMs: 240,
  ),
  CaptionAnimationPreset(
    id: 'fade', name: 'Fade',
    description: 'Fade captions in and out smoothly.',
    defaultDurationMs: 220,
  ),
  CaptionAnimationPreset(
    id: 'slide', name: 'Slide',
    description: 'Slide caption groups into the safe area.',
    defaultDurationMs: 240,
  ),
  CaptionAnimationPreset(
    id: 'typewriter', name: 'Typewriter',
    description: 'Reveal text progressively by character.',
    defaultDurationMs: 400,
  ),
  CaptionAnimationPreset(
    id: 'glow_pulse', name: 'Glow Pulse',
    description: 'Pulse a soft glow around the active word.',
    defaultDurationMs: 320,
  ),
  CaptionAnimationPreset(
    id: 'highlight_sweep', name: 'Highlight Sweep',
    description: 'Move a colored highlight behind the current text.',
    defaultDurationMs: 260,
  ),
  CaptionAnimationPreset(
    id: 'staggered_words', name: 'Staggered Words',
    description: 'Reveal words one after another.',
    defaultDurationMs: 300,
  ),
];
