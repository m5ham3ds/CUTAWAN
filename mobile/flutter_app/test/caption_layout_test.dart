import 'package:cutawan_mobile/domain/caption_catalog.dart';
import 'package:cutawan_mobile/domain/caption_layout.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CaptionLayoutEngine();

  CaptionWordTiming word(String value, int start, int end) =>
      CaptionWordTiming(text: value, startMs: start, endMs: end);

  test('all 12 source caption presets retain unique stable identifiers', () {
    expect(captionStylePresets, hasLength(12));
    expect(captionStylePresets.map((style) => style.id).toSet(), hasLength(12));
    expect(captionStylePresets.first.id, 'beast');
    expect(captionStylePresets.last.id, 'whisper');
  });

  test('all bundled animation choices have a deterministic layout entry', () {
    expect(captionAnimationPresets, hasLength(10));
    expect(captionAnimationPresets.map((item) => item.id).toSet(), hasLength(10));
  });

  test('portrait layout respects the two-line limit and word grouping', () {
    final words = List.generate(
      18,
      (index) => word('كلمة$index', index * 350, index * 350 + 250),
    );
    for (final style in captionStylePresets) {
      final budget = engine.budget(style, 9 / 16);
      final groups = engine.group(words, budget);
      expect(groups, isNotEmpty);
      expect(groups.every((group) => group.lines.length <= 2), isTrue);
      expect(groups.every((group) => group.words.length <= style.wordsPerGroup), isTrue);
    }
  });

  test('sentence boundaries and pauses split groups predictably', () {
    final input = [
      word('Hello', 0, 300),
      word('world.', 320, 700),
      word('Second', 800, 1100),
      word('sentence.', 1150, 1500),
      word('After', 3000, 3300),
      word('pause.', 3350, 3700),
    ];
    final groups = engine.group(
      input,
      engine.budget(captionStylePresets.first, 9 / 16),
    );
    expect(groups.length, 3);
    expect(groups.first.words.last.text, 'world.');
    expect(groups.last.startMs, 3000);
  });

  test('single wide word remains present rather than being dropped', () {
    final input = [word('Supercalifragilisticexpialidocious', 0, 1200)];
    final groups = engine.group(
      input,
      engine.budget(captionStylePresets.last, 9 / 16),
    );
    expect(groups.single.words.single.text, input.single.text);
  });

  test('group hold never runs past next group or clip end', () {
    final input = [
      word('One.', 0, 500),
      word('Two.', 700, 1100),
    ];
    final groups = engine.group(
      input,
      engine.budget(captionStylePresets[1], 9 / 16),
    );
    expect(engine.displayEnd(groups, 0, 10000), 700);
    expect(engine.displayEnd(groups, 1, 1500), 1500);
  });

  test('invalid timings and invalid aspect ratios are rejected', () {
    expect(
      () => engine.group([word('bad', 10, 5)], engine.budget(captionStylePresets.first, 1)),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => engine.budget(captionStylePresets.first, 0),
      throwsA(isA<FormatException>()),
    );
  });
  test('custom font scale and family affect the timed caption layout budget', () {
    final preset = captionStylePresets.first;
    final normal = engine.budget(preset, 9 / 16);
    final larger = engine.budget(
      preset,
      9 / 16,
      fontScaleOverride: 0.07,
      fontFamilyOverride: 'Poppins',
      uppercaseOverride: true,
    );
    expect(larger.lineWidthEm, lessThan(normal.lineWidthEm));
    expect(larger.glyphWidthEm, greaterThan(normal.glyphWidthEm));
  });

}
