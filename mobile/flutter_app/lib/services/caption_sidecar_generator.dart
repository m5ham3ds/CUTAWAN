import 'dart:math' as math;

import '../domain/caption_catalog.dart';
import '../domain/caption_layout.dart';
import '../domain/clip_candidate.dart';
import '../domain/transcript_contract.dart';

class CaptionSidecars {
  const CaptionSidecars({required this.srt, required this.ass});
  final String srt;
  final String ass;
}

class CaptionSidecarGenerator {
  const CaptionSidecarGenerator();

  CaptionSidecars generate({
    required CutawanTranscript transcript,
    required ClipCandidate candidate,
    required CaptionStylePreset style,
    required double aspectRatio,
    String animationId = 'static',
    int canvasWidth = 1080,
  }) {
    if (candidate.startMs < 0 ||
        candidate.endMs <= candidate.startMs ||
        candidate.endMs > transcript.sourceDurationMs ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        canvasWidth < 240) {
      throw const FormatException('Subtitle clip range or aspect ratio is invalid.');
    }
    final timings = transcript.words
        .where((word) =>
            word.endMs > candidate.startMs && word.startMs < candidate.endMs)
        .map((word) => CaptionWordTiming(
              text: word.text,
              startMs: math.max(candidate.startMs, word.startMs),
              endMs: math.min(candidate.endMs, word.endMs),
            ))
        .where((word) => word.endMs > word.startMs)
        .toList(growable: false);
    if (timings.isEmpty) return const CaptionSidecars(srt: '', ass: '');

    final engine = const CaptionLayoutEngine();
    final groups = engine.group(timings, engine.budget(style, aspectRatio));
    final height = (canvasWidth / aspectRatio).round();
    final srt = StringBuffer();
    final ass = StringBuffer()
      ..writeln('[Script Info]')
      ..writeln('ScriptType: v4.00+')
      ..writeln('WrapStyle: 2')
      ..writeln('ScaledBorderAndShadow: yes')
      ..writeln('PlayResX: $canvasWidth')
      ..writeln('PlayResY: $height')
      ..writeln()
      ..writeln('[V4+ Styles]')
      ..writeln('Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding')
      ..writeln(
        'Style: Default,${_assField(style.fontFamily)},${_fontSize(style, height)},'
        '${_assColor(style.textColor)},${_assColor(style.highlightColor)},'
        '${_assColor(style.outlineColor)},${_assColor(style.highlightBoxColor ?? '#000000')},'
        '${style.bold ? -1 : 0},0,0,0,100,100,0,0,1,${style.outlineWidth.toStringAsFixed(1)},'
        '${style.shadow.toStringAsFixed(1)},2,48,48,${_bottomMargin(style, height)},1',
      )
      ..writeln()
      ..writeln('[Events]')
      ..writeln('Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text');

    var index = 0;
    for (var groupIndex = 0; groupIndex < groups.length; groupIndex++) {
      final group = groups[groupIndex];
      final end = engine.displayEnd(groups, groupIndex, candidate.endMs);
      final start = math.max(candidate.startMs, group.startMs);
      if (end <= start) continue;
      final relativeStart = start - candidate.startMs;
      final relativeEnd = end - candidate.startMs;
      final lines = group.lines
          .map((line) => line.map((word) => _plainText(word.text, style)).join(' '))
          .join(r'\N');
      index++;
      srt
        ..writeln(index)
        ..writeln('${_srtTime(relativeStart)} --> ${_srtTime(relativeEnd)}')
        ..writeln(lines)
        ..writeln();

      final karaokeLines = group.lines.map((line) {
        return line.map((word) {
          final text = _assText(_plainText(word.text, style));
          if (animationId != 'karaoke_fill') return text;
          final duration = math.max(1, ((word.endMs - word.startMs) / 10).round());
          return r'{\kf' '$duration}' '$text';
        }).join(' ');
      }).join(r'\N');
      ass.writeln(
        'Dialogue: 0,${_assTime(relativeStart)},${_assTime(relativeEnd)},Default,,0,0,0,,${_positionTag(style, height, canvasWidth)}$karaokeLines',
      );
    }
    return CaptionSidecars(srt: srt.toString(), ass: ass.toString());
  }

  static String _plainText(String value, CaptionStylePreset style) =>
      (style.uppercase ? value.toUpperCase() : value)
          .replaceAll(RegExp(r'[\r\n]+'), ' ')
          .trim();

  static String _assText(String value) => value
      .replaceAll(r'\', r'\\')
      .replaceAll('{', r'\{')
      .replaceAll('}', r'\}');

  static String _assField(String value) =>
      value.replaceAll(',', '').replaceAll('\n', ' ').trim();

  static String _assColor(String hex) {
    final raw = hex.replaceFirst('#', '').padLeft(6, '0');
    final red = raw.substring(0, 2);
    final green = raw.substring(2, 4);
    final blue = raw.substring(4, 6);
    return '&H00$blue$green$red';
  }

  static int _fontSize(CaptionStylePreset style, int height) =>
      (height * style.fontScale).round().clamp(24, 120);

  static int _bottomMargin(CaptionStylePreset style, int height) =>
      ((1 - style.positionY.clamp(0.5, 0.95)) * height)
          .round()
          .clamp(24, height ~/ 2);

  static String _positionTag(
    CaptionStylePreset style,
    int height,
    int width,
  ) {
    final x = width ~/ 2;
    final y = (style.positionY.clamp(0.5, 0.95) * height).round();
    return r'{\an5\pos(' '$x,$y)}';
  }

  static String _srtTime(int milliseconds) {
    final total = milliseconds.clamp(0, 999999999);
    final hours = total ~/ 3600000;
    final minutes = (total % 3600000) ~/ 60000;
    final seconds = (total % 60000) ~/ 1000;
    final millis = total % 1000;
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')},'
        '${millis.toString().padLeft(3, '0')}';
  }

  static String _assTime(int milliseconds) {
    final total = milliseconds.clamp(0, 999999999);
    final hours = total ~/ 3600000;
    final minutes = (total % 3600000) ~/ 60000;
    final seconds = (total % 60000) ~/ 1000;
    final centiseconds = (total % 1000) ~/ 10;
    return '$hours:${minutes.toString.padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}.'
        '${centiseconds.toString().padLeft(2, '0')}';
  }
}
