import 'dart:math';

class CaptionAnimationFrame {
  const CaptionAnimationFrame({
    required this.opacity,
    required this.scale,
    required this.translateY,
    required this.revealedWords,
    required this.revealedCharacters,
    required this.highlightedWord,
    required this.glow,
  });

  final double opacity;
  final double scale;
  final double translateY;
  final int revealedWords;
  final int revealedCharacters;
  final int highlightedWord;
  final double glow;
}

class CaptionAnimationEngine {
  const CaptionAnimationEngine();

  CaptionAnimationFrame evaluate({
    required String animationId,
    required double progress,
    required int wordCount,
    required int activeWord,
    int characterCount = 0,
  }) {
    if (!progress.isFinite || wordCount < 0 || activeWord < -1 ||
        activeWord >= wordCount || characterCount < 0) {
      throw const FormatException('Caption animation input is invalid.');
    }
    final t = progress.clamp(0.0, 1.0).toDouble();
    final safeCount = wordCount;
    switch (animationId) {
      case 'static':
        return CaptionAnimationFrame(
          opacity: 1,
          scale: 1,
          translateY: 0,
          revealedWords: safeCount,
          revealedCharacters: characterCount,
          highlightedWord: -1,
          glow: 0,
        );
      case 'karaoke_fill':
      case 'highlight_sweep':
        return CaptionAnimationFrame(
          opacity: 1,
          scale: 1,
          translateY: 0,
          revealedWords: safeCount,
          revealedCharacters: characterCount,
          highlightedWord: activeWord,
          glow: animationId == 'highlight_sweep' ? t : 0,
        );
      case 'word_pop':
        return CaptionAnimationFrame(
          opacity: 1,
          scale: 1 + 0.09 * sin(pi * t),
          translateY: 0,
          revealedWords: safeCount,
          revealedCharacters: characterCount,
          highlightedWord: activeWord,
          glow: 0,
        );
      case 'bounce':
        return CaptionAnimationFrame(
          opacity: 1,
          scale: 1 + 0.12 * sin(2 * pi * t) * (1 - t),
          translateY: -8 * sin(pi * t) * (1 - t),
          revealedWords: safeCount,
          revealedCharacters: characterCount,
          highlightedWord: activeWord,
          glow: 0,
        );
      case 'fade':
        return CaptionAnimationFrame(
          opacity: t,
          scale: 1,
          translateY: 0,
          revealedWords: safeCount,
          revealedCharacters: characterCount,
          highlightedWord: activeWord,
          glow: 0,
        );
      case 'slide':
        return CaptionAnimationFrame(
          opacity: t,
          scale: 1,
          translateY: (1 - t) * 18,
          revealedWords: safeCount,
          revealedCharacters: characterCount,
          highlightedWord: activeWord,
          glow: 0,
        );
      case 'typewriter':
        return CaptionAnimationFrame(
          opacity: 1,
          scale: 1,
          translateY: 0,
          revealedWords: safeCount,
          revealedCharacters: (characterCount * t).ceil().clamp(0, characterCount).toInt(),
          highlightedWord: -1,
          glow: 0,
        );
      case 'staggered_words':
        return CaptionAnimationFrame(
          opacity: 1,
          scale: 1,
          translateY: 0,
          revealedWords: (safeCount * t).ceil().clamp(0, safeCount).toInt(),
          revealedCharacters: characterCount,
          highlightedWord: activeWord,
          glow: 0,
        );
      case 'glow_pulse':
        return CaptionAnimationFrame(
          opacity: 1,
          scale: 1,
          translateY: 0,
          revealedWords: safeCount,
          revealedCharacters: characterCount,
          highlightedWord: activeWord,
          glow: sin(pi * t),
        );
      default:
        throw FormatException('Unsupported caption animation: $animationId');
    }
  }
}
