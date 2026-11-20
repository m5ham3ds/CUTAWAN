import 'caption_catalog.dart';

class CaptionWordTiming {
  const CaptionWordTiming({
    required this.text,
    required this.startMs,
    required this.endMs,
  });

  final String text;
  final int startMs;
  final int endMs;
}

class CaptionWordGroup {
  const CaptionWordGroup({
    required this.words,
    required this.lines,
    required this.startMs,
    required this.endMs,
  });

  final List<CaptionWordTiming> words;
  final List<List<CaptionWordTiming>> lines;
  final int startMs;
  final int endMs;
}

class CaptionLayoutBudget {
  const CaptionLayoutBudget({
    required this.maxWords,
    required this.lineWidthEm,
    required this.glyphWidthEm,
    this.maxLines = 2,
  });

  final int maxWords;
  final double lineWidthEm;
  final double glyphWidthEm;
  final int maxLines;
}

class CaptionLayoutEngine {
  const CaptionLayoutEngine();

  static const safeWidth = 0.9;
  static const maxLines = 2;
  static const holdMs = 1500;
  static const pauseGroupMs = 900;

  CaptionLayoutBudget budget(CaptionStylePreset style, double aspectRatio) {
    if (!aspectRatio.isFinite || aspectRatio <= 0 ||
        !style.fontScale.isFinite || style.fontScale <= 0) {
      throw const FormatException('Caption style or aspect ratio is invalid.');
    }
    const glyphWidths = <String, (double, double)>{
      'Anton': (0.45, 0.46),
      'Poppins': (0.58, 0.65),
      'Poppins Medium': (0.56, 0.63),
    };
    final widths = glyphWidths[style.fontFamily] ?? (0.62, 0.7);
    return CaptionLayoutBudget(
      maxWords: style.wordsPerGroup,
      lineWidthEm: (aspectRatio.clamp(0.1, 4).toDouble() * safeWidth) / style.fontScale - 0.5,
      glyphWidthEm: style.uppercase ? widths.$2 : widths.$1,
    );
  }

  List<CaptionWordGroup> group(
    List<CaptionWordTiming> input,
    CaptionLayoutBudget budget,
  ) {
    if (budget.maxWords < 1 || budget.maxLines < 1 ||
        !budget.lineWidthEm.isFinite || budget.lineWidthEm <= 0 ||
        !budget.glyphWidthEm.isFinite || budget.glyphWidthEm <= 0) {
      throw const FormatException('Caption line budget is invalid.');
    }
    final words = [...input]..sort((a, b) => a.startMs.compareTo(b.startMs));
    for (final word in words) {
      if (word.text.trim().isEmpty || word.startMs < 0 || word.endMs <= word.startMs) {
        throw const FormatException('Caption words must contain text and valid timing.');
      }
    }
    final groups = <CaptionWordGroup>[];
    var lines = <List<CaptionWordTiming>>[];
    var lineWidth = 0.0;
    var count = 0;

    void flush() {
      if (count == 0) return;
      final flat = lines.expand((line) => line).toList(growable: false);
      groups.add(CaptionWordGroup(
        words: flat,
        lines: lines.map((line) => List<CaptionWordTiming>.unmodifiable(line)).toList(),
        startMs: flat.first.startMs,
        endMs: flat.last.endMs,
      ));
      lines = [];
      lineWidth = 0;
      count = 0;
    }

    for (final word in words) {
      final previous = count == 0 ? null : lines.last.last;
      final pause = previous != null && word.startMs - previous.endMs > pauseGroupMs;
      final sentence = previous != null &&
          RegExp(r'[.!?؟。！？…]["”’)\]]*$').hasMatch(previous.text.trim());
      final glyphWidth = word.text.runes.length * budget.glyphWidthEm;
      final wouldOverflowLine = count > 0 &&
          lineWidth + 0.26 + glyphWidth > budget.lineWidthEm;
      final needsThirdLine = wouldOverflowLine && lines.length >= budget.maxLines;
      if (count >= budget.maxWords || pause || sentence || needsThirdLine) {
        flush();
      }

      if (count == 0) {
        lines.add([word]);
        lineWidth = glyphWidth;
      } else if (lineWidth + 0.26 + glyphWidth <= budget.lineWidthEm) {
        lines.last.add(word);
        lineWidth += 0.26 + glyphWidth;
      } else {
        lines.add([word]);
        lineWidth = glyphWidth;
      }
      count++;
    }
    flush();
    return groups;
  }

  int displayEnd(List<CaptionWordGroup> groups, int index, int clipEndMs) {
    if (index < 0 || index >= groups.length || clipEndMs < 0) {
      throw RangeError('Caption group index or clip end is invalid.');
    }
    final group = groups[index];
    if (clipEndMs < group.endMs) {
      throw const FormatException('Clip end precedes the caption group end.');
    }
    final next = index + 1 < groups.length ? groups[index + 1] : null;
    var end = group.endMs + holdMs;
    if (next != null) end = end < next.startMs ? end : next.startMs;
    if (end > clipEndMs) end = clipEndMs;
    return end;
  }
}
