enum ClipFramingMode { automatic, fullFrame, manualFocus }

class ClipEditOverrides {
  const ClipEditOverrides({
    required this.clipId,
    this.framingMode = ClipFramingMode.automatic,
    this.focusX = 0.5,
    this.focusY = 0.5,
  });

  static const currentSchemaVersion = 1;

  final String clipId;
  final ClipFramingMode framingMode;
  final double focusX;
  final double focusY;

  ClipEditOverrides copyWith({
    ClipFramingMode? framingMode,
    double? focusX,
    double? focusY,
  }) =>
      ClipEditOverrides(
        clipId: clipId,
        framingMode: framingMode ?? this.framingMode,
        focusX: focusX ?? this.focusX,
        focusY: focusY ?? this.focusY,
      );

  void validate() {
    if (!RegExp(r'^[A-Za-z0-9_-]{3,160}$').hasMatch(clipId) ||
        !focusX.isFinite ||
        !focusY.isFinite ||
        focusX < 0 ||
        focusX > 1 ||
        focusY < 0 ||
        focusY > 1) {
      throw const FormatException('Clip framing overrides are invalid.');
    }
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': currentSchemaVersion,
        'clipId': clipId,
        'framingMode': framingMode.name,
        'focusX': focusX,
        'focusY': focusY,
      };

  factory ClipEditOverrides.fromJson(Map<String, dynamic> json) {
    final modeName = json['framingMode'] as String? ?? 'automatic';
    final modes = ClipFramingMode.values.where((item) => item.name == modeName);
    if ((json['schemaVersion'] as num?)?.toInt() != currentSchemaVersion ||
        modes.isEmpty) {
      throw const FormatException('Clip framing override schema is unsupported.');
    }
    final value = ClipEditOverrides(
      clipId: json['clipId'] as String? ?? '',
      framingMode: modes.first,
      focusX: (json['focusX'] as num?)?.toDouble() ?? 0.5,
      focusY: (json['focusY'] as num?)?.toDouble() ?? 0.5,
    );
    value.validate();
    return value;
  }

  /// Returns an override timeline in clip-relative milliseconds. An empty
  /// list means that the pipeline should keep its analyzed automatic plan.
  List<Map<String, Object?>> toExportShots({
    required int durationMs,
    required double sourceAspectRatio,
    required double targetAspectRatio,
  }) {
    validate();
    if (durationMs <= 0 ||
        !sourceAspectRatio.isFinite ||
        sourceAspectRatio <= 0 ||
        !targetAspectRatio.isFinite ||
        targetAspectRatio <= 0) {
      throw const FormatException('Clip framing dimensions or duration are invalid.');
    }
    if (framingMode == ClipFramingMode.automatic) {
      return const [];
    }
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
    final left = (focusX - cropWidth / 2)
        .clamp(0.0, 1.0 - cropWidth)
        .toDouble();
    final top = (focusY - cropHeight / 2)
        .clamp(0.0, 1.0 - cropHeight)
        .toDouble();
    return [
      {
        'startMs': 0,
        'endMs': durationMs,
        'mode': 'crop',
        'region': {
          'x': left,
          'y': top,
          'width': cropWidth,
          'height': cropHeight,
        },
      },
    ];
  }
}
