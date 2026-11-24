enum ClipFramingMode { automatic, fullFrame, manualFocus }

class ClipFocusKeyframe {
  const ClipFocusKeyframe({
    required this.timestampMs,
    required this.focusX,
    required this.focusY,
  });

  /// Absolute source-video time, so trim changes do not shift focus edits.
  final int timestampMs;
  final double focusX;
  final double focusY;

  String? validate() {
    if (timestampMs < 0 ||
        !focusX.isFinite ||
        !focusY.isFinite ||
        focusX < 0 ||
        focusX > 1 ||
        focusY < 0 ||
        focusY > 1) {
      return 'Manual focus keyframe timestamp or coordinates are invalid.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'timestampMs': timestampMs,
        'focusX': focusX,
        'focusY': focusY,
      };

  factory ClipFocusKeyframe.fromJson(Map<String, dynamic> json) =>
      ClipFocusKeyframe(
        timestampMs: (json['timestampMs'] as num?)?.toInt() ?? -1,
        focusX: (json['focusX'] as num?)?.toDouble() ?? -1,
        focusY: (json['focusY'] as num?)?.toDouble() ?? -1,
      );
}

class ClipEditOverrides {
  const ClipEditOverrides({
    required this.clipId,
    this.framingMode = ClipFramingMode.automatic,
    this.focusX = 0.5,
    this.focusY = 0.5,
    this.focusKeyframes = const [],
  });

  static const currentSchemaVersion = 2;

  final String clipId;
  final ClipFramingMode framingMode;
  final double focusX;
  final double focusY;
  final List<ClipFocusKeyframe> focusKeyframes;

  ClipEditOverrides copyWith({
    ClipFramingMode? framingMode,
    double? focusX,
    double? focusY,
    List<ClipFocusKeyframe>? focusKeyframes,
  }) =>
      ClipEditOverrides(
        clipId: clipId,
        framingMode: framingMode ?? this.framingMode,
        focusX: focusX ?? this.focusX,
        focusY: focusY ?? this.focusY,
        focusKeyframes: focusKeyframes ?? this.focusKeyframes,
      );

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{3,160}$').hasMatch(clipId) ||
        !focusX.isFinite ||
        !focusY.isFinite ||
        focusX < 0 ||
        focusX > 1 ||
        focusY < 0 ||
        focusY > 1 ||
        focusKeyframes.length > 120) {
      throw const FormatException('Clip framing overrides are invalid.');
    }
    var previousTimestamp = -1;
    for (final keyframe in focusKeyframes) {
      final error = keyframe.validate();
      if (error != null || keyframe.timestampMs <= previousTimestamp) {
        throw FormatException(
          error ?? 'Manual focus keyframes must be unique and time ordered.',
        );
      }
      previousTimestamp = keyframe.timestampMs;
    }
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'clipId': clipId,
        'framingMode': framingMode.name,
        'focusX': focusX,
        'focusY': focusY,
        'focusKeyframes':
            focusKeyframes.map((keyframe) => keyframe.toJson()).toList(),
      };

  factory ClipEditOverrides.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt();
    final modeName = json['framingMode'] as String? ?? 'automatic';
    final modes = ClipFramingMode.values.where((item) => item.name == modeName);
    if ((version != 1 && version != currentSchemaVersion) || modes.isEmpty) {
      throw const FormatException('Clip framing override schema is unsupported.');
    }

    final keyframes = <ClipFocusKeyframe>[];
    if (version == currentSchemaVersion) {
      final rawKeyframes = json['focusKeyframes'];
      if (rawKeyframes != null && rawKeyframes is! List) {
        throw const FormatException('Manual focus keyframes must be an array.');
      }
      for (final item in (rawKeyframes as List?) ?? const []) {
        if (item is! Map) {
          throw const FormatException('Manual focus keyframe must be an object.');
        }
        keyframes.add(
          ClipFocusKeyframe.fromJson(Map<String, dynamic>.from(item)),
        );
      }
    }

    final value = ClipEditOverrides(
      clipId: json['clipId'] as String? ?? '',
      framingMode: modes.first,
      focusX: (json['focusX'] as num?)?.toDouble() ?? 0.5,
      focusY: (json['focusY'] as num?)?.toDouble() ?? 0.5,
      focusKeyframes: List<ClipFocusKeyframe>.unmodifiable(keyframes),
    );
    value.validate();
    return value;
  }

  /// Returns clip-relative export segments. Keyframe timestamps stay on the
  /// source-video clock so changing the trim range does not move the edits.
  List<Map<String, Object?>> toExportShots({
    required int durationMs,
    required double sourceAspectRatio,
    required double targetAspectRatio,
    int clipStartMs = 0,
  }) {
    validate();
    if (durationMs <= 0 ||
        clipStartMs < 0 ||
        !sourceAspectRatio.isFinite ||
        sourceAspectRatio <= 0 ||
        !targetAspectRatio.isFinite ||
        targetAspectRatio <= 0) {
      throw const FormatException(
        'Clip framing dimensions, start time or duration are invalid.',
      );
    }
    if (framingMode == ClipFramingMode.automatic) return const [];
    if (framingMode == ClipFramingMode.fullFrame) {
      return [
        {
          'startMs': 0,
          'endMs': durationMs,
          'mode': 'fit',
          'region': null,
        },
      ];
    }

    var cropWidth = 1.0;
    var cropHeight = 1.0;
    if (sourceAspectRatio > targetAspectRatio) {
      cropWidth = targetAspectRatio / sourceAspectRatio;
    } else if (sourceAspectRatio < targetAspectRatio) {
      cropHeight = sourceAspectRatio / targetAspectRatio;
    }

    Map<String, double> regionAt(double x, double y) {
      final left = (x - cropWidth / 2)
          .clamp(0.0, 1.0 - cropWidth)
          .toDouble();
      final top = (y - cropHeight / 2)
          .clamp(0.0, 1.0 - cropHeight)
          .toDouble();
      return {
        'x': left,
        'y': top,
        'width': cropWidth,
        'height': cropHeight,
      };
    }

    if (focusKeyframes.isEmpty) {
      return [
        {
          'startMs': 0,
          'endMs': durationMs,
          'mode': 'crop',
          'region': regionAt(focusX, focusY),
        },
      ];
    }

    Map<String, double> focusAt(int sourceTimeMs) {
      final first = focusKeyframes.first;
      if (sourceTimeMs <= first.timestampMs) {
        return {'x': first.focusX, 'y': first.focusY};
      }
      for (var index = 1; index < focusKeyframes.length; index++) {
        final previous = focusKeyframes[index - 1];
        final next = focusKeyframes[index];
        if (sourceTimeMs <= next.timestampMs) {
          final span = next.timestampMs - previous.timestampMs;
          final progress = ((sourceTimeMs - previous.timestampMs) / span)
              .clamp(0.0, 1.0)
              .toDouble();
          return {
            'x': previous.focusX + (next.focusX - previous.focusX) * progress,
            'y': previous.focusY + (next.focusY - previous.focusY) * progress,
          };
        }
      }
      final last = focusKeyframes.last;
      return {'x': last.focusX, 'y': last.focusY};
    }

    final clipEndMs = clipStartMs + durationMs;
    final boundaries = <int>{0, durationMs};
    for (final keyframe in focusKeyframes) {
      if (keyframe.timestampMs > clipStartMs &&
          keyframe.timestampMs < clipEndMs) {
        boundaries.add(keyframe.timestampMs - clipStartMs);
      }
    }
    final orderedBoundaries = boundaries.toList()..sort();
    final segments = <Map<String, Object?>>[];
    for (var index = 0; index < orderedBoundaries.length - 1; index++) {
      final start = orderedBoundaries[index];
      final end = orderedBoundaries[index + 1];
      final startFocus = focusAt(clipStartMs + start);
      final endFocus = focusAt(clipStartMs + end);
      segments.add({
        'startMs': start,
        'endMs': end,
        'mode': 'crop',
        'region': regionAt(startFocus['x']!, startFocus['y']!),
        'regionEnd': regionAt(endFocus['x']!, endFocus['y']!),
      });
    }
    return List<Map<String, Object?>>.unmodifiable(segments);
  }
}
