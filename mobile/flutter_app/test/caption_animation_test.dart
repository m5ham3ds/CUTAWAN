import 'package:cutawan_mobile/domain/caption_animation.dart';
import 'package:cutawan_mobile/domain/caption_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const engine = CaptionAnimationEngine();

  test('every bundled animation produces finite bounded presentation values', () {
    for (final preset in captionAnimationPresets) {
      for (final progress in [0.0, 0.25, 0.5, 0.75, 1.0]) {
        final frame = engine.evaluate(
          animationId: preset.id,
          progress: progress,
          wordCount: 7,
          activeWord: 3,
        characterCount: 24,
        );
        expect(frame.opacity, inInclusiveRange(0, 1));
        expect(frame.scale, inInclusiveRange(0.8, 1.3));
        expect(frame.revealedWords, inInclusiveRange(0, 7));
        expect(frame.revealedCharacters, inInclusiveRange(0, 24));
        expect(frame.translateY.abs(), lessThan(30));
        expect(frame.glow, inInclusiveRange(0, 1));
      }
    }
  });

  test('static, typewriter, staggered and word pop have distinct behavior', () {
    final staticFrame = engine.evaluate(
      animationId: 'static',
      progress: 0.4,
      wordCount: 7,
      activeWord: 3,
        characterCount: 24,
    );
    final typewriter = engine.evaluate(
      animationId: 'typewriter',
      progress: 0.4,
      wordCount: 7,
      activeWord: 3,
        characterCount: 24,
    );
    final staggered = engine.evaluate(
      animationId: 'staggered_words',
      progress: 0.4,
      wordCount: 7,
      activeWord: 3,
        characterCount: 24,
    );
    final pop = engine.evaluate(
      animationId: 'word_pop',
      progress: 0.5,
      wordCount: 7,
      activeWord: 3,
        characterCount: 24,
    );

    expect(staticFrame.revealedWords, 7);
    expect(typewriter.revealedWords, 7);
    expect(typewriter.revealedCharacters, lessThan(24));
    expect(staggered.revealedWords, lessThan(7));
    expect(pop.scale, greaterThan(1));
  });

  test('unknown animation identifiers fail explicitly', () {
    expect(
      () => engine.evaluate(
        animationId: 'made-up',
        progress: 0.5,
        wordCount: 2,
        activeWord: 0,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
