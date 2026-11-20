class FrameBox {
  const FrameBox({
    required this.x,
    required this.y,
    required this.width,
    required this.height,
  });

  final double x;
  final double y;
  final double width;
  final double height;

  String? validate() {
    if (![x, y, width, height].every((v) => v.isFinite) ||
        x < 0 || y < 0 || width <= 0 || height <= 0 ||
        x + width > 1.0001 || y + height > 1.0001) {
      return 'Frame box must be normalized and stay inside the source frame.';
    }
    return null;
  }

  Map<String, Object?> toJson() => {
        'x': x,
        'y': y,
        'width': width,
        'height': height,
      };

  factory FrameBox.fromJson(Map<String, dynamic> json) => FrameBox(
        x: (json['x'] as num?)?.toDouble() ?? -1,
        y: (json['y'] as num?)?.toDouble() ?? -1,
        width: (json['width'] as num?)?.toDouble() ?? -1,
        height: (json['height'] as num?)?.toDouble() ?? -1,
      );
}

class FocusKeyframe {
  const FocusKeyframe({
    required this.timestampMs,
    required this.centerX,
    this.cut = false,
    this.confidence = 0,
  });

  final int timestampMs;
  final double centerX;
  final bool cut;
  final double confidence;

  String? validate() {
    if (timestampMs < 0 ||
        !centerX.isFinite ||
        centerX < 0 ||
        centerX > 1 ||
        !confidence.isFinite ||
        confidence < 0 ||
        confidence > 1) {
      return 'Focus keyframe timestamp, center or confidence is invalid.';
    }
    return null;
  }

  factory FocusKeyframe.fromJson(Map<String, dynamic> json) => FocusKeyframe(
        timestampMs: (json['timestampMs'] as num?)?.toInt() ?? -1,
        centerX: (json['centerX'] as num?)?.toDouble() ?? -1,
        cut: json['cut'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? -1,
      );

  Map<String, Object?> toJson() => {
        'timestampMs': timestampMs,
        'centerX': centerX,
        'cut': cut,
        'confidence': confidence,
      };
}

class FocusTrack {
  const FocusTrack({
    required this.keyframes,
    required this.averageConfidence,
    required this.coverage,
    required this.source,
  });

  final List<FocusKeyframe> keyframes;
  final double averageConfidence;
  final double coverage;
  final String source;

  String? validate({required int durationMs}) {
    if (keyframes.isEmpty ||
        !averageConfidence.isFinite ||
        averageConfidence < 0 ||
        averageConfidence > 1 ||
        !coverage.isFinite ||
        coverage < 0 ||
        coverage > 1 ||
        source.isEmpty) {
      return 'Focus track confidence, coverage or source is invalid.';
    }
    var last = -1;
    for (final frame in keyframes) {
      final error = frame.validate();
      if (error != null ||
          frame.timestampMs <= last ||
          frame.timestampMs > durationMs ||
          frame.confidence < 0.35) {
        return error ?? 'Focus keyframes must be ordered, in range and sufficiently confident.';
      }
      last = frame.timestampMs;
    }
    if (coverage < 0.3 || averageConfidence < 0.55) {
      return 'Focus track does not meet minimum confidence and coverage thresholds.';
    }
    return null;
  }

  factory FocusTrack.fromJson(Map<String, dynamic> json) {
    final raw = json['keyframes'];
    if (raw is! List) throw const FormatException('Focus keyframes must be an array.');
    return FocusTrack(
      keyframes: raw.map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException('Focus keyframe must be an object.');
        return FocusKeyframe.fromJson(item);
      }).toList(growable: false),
      averageConfidence: (json['averageConfidence'] as num?)?.toDouble() ?? -1,
      coverage: (json['coverage'] as num?)?.toDouble() ?? -1,
      source: json['source'] as String? ?? '',
    );
  }

  Map<String, Object?> toJson() => {
        'keyframes': keyframes.map((frame) => frame.toJson()).toList(),
        'averageConfidence': averageConfidence,
        'coverage': coverage,
        'source': source,
      };
}

class ReframeShot {
  const ReframeShot({
    required this.startMs,
    required this.endMs,
    required this.mode,
    this.region,
    this.focusCenterX,
    this.confidence = 0,
    this.reviewReason,
  });

  final int startMs;
  final int endMs;
  final String mode;
  final FrameBox? region;
  final double? focusCenterX;
  final double confidence;
  final String? reviewReason;

  String? validate({required int sourceDurationMs}) {
    if (startMs < 0 || endMs <= startMs || endMs > sourceDurationMs ||
        !['crop', 'fit'].contains(mode) ||
        !confidence.isFinite || confidence < 0 || confidence > 1) {
      return 'Reframe shot timing, mode or confidence is invalid.';
    }
    if (mode == 'crop') {
      if (region == null || region!.validate() != null ||
          focusCenterX == null || !focusCenterX!.isFinite ||
          focusCenterX! < 0 || focusCenterX! > 1 || confidence < 0.55) {
        return 'A crop requires a valid region and a sufficiently confident focus.';
      }
    }
    if (mode == 'fit' && region != null) {
      return 'Fit shots cannot carry a crop region.';
    }
    return null;
  }

  factory ReframeShot.fromJson(Map<String, dynamic> json) {
    final rawRegion = json['region'];
    if (rawRegion != null && rawRegion is! Map<String, dynamic>) {
      throw const FormatException('Reframe region must be an object.');
    }
    return ReframeShot(
      startMs: (json['startMs'] as num?)?.toInt() ?? -1,
      endMs: (json['endMs'] as num?)?.toInt() ?? -1,
      mode: json['mode'] as String? ?? '',
      region: rawRegion == null ? null : FrameBox.fromJson(rawRegion),
      focusCenterX: (json['focusCenterX'] as num?)?.toDouble(),
      confidence: (json['confidence'] as num?)?.toDouble() ?? -1,
      reviewReason: json['reviewReason'] as String?,
    );
  }

  Map<String, Object?> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'mode': mode,
        'region': region?.toJson(),
        'focusCenterX': focusCenterX,
        'confidence': confidence,
        'reviewReason': reviewReason,
      };
}

class ReframePlan {
  const ReframePlan({
    required this.schemaVersion,
    required this.sourceDurationMs,
    required this.aspectRatio,
    required this.shots,
    required this.focusTrack,
    required this.fallbackReason,
    required this.engine,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final int sourceDurationMs;
  final double aspectRatio;
  final List<ReframeShot> shots;
  final FocusTrack? focusTrack;
  final String? fallbackReason;
  final String engine;

  factory ReframePlan.fromJson(Map<String, dynamic> json) {
    final rawShots = json['shots'];
    if (rawShots is! List) throw const FormatException('Reframe shots must be an array.');
    final rawFocus = json['focusTrack'];
    if (rawFocus != null && rawFocus is! Map<String, dynamic>) {
      throw const FormatException('Focus track must be an object.');
    }
    final plan = ReframePlan(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? -1,
      sourceDurationMs: (json['sourceDurationMs'] as num?)?.toInt() ?? -1,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? -1,
      shots: rawShots.map((item) {
        if (item is! Map<String, dynamic>) throw const FormatException('Reframe shot must be an object.');
        return ReframeShot.fromJson(item);
      }).toList(growable: false),
      focusTrack: rawFocus == null ? null : FocusTrack.fromJson(rawFocus),
      fallbackReason: json['fallbackReason'] as String?,
      engine: json['engine'] as String? ?? '',
    );
    plan.validate();
    return plan;
  }

  void validate() {
    if (schemaVersion != currentSchemaVersion ||
        sourceDurationMs <= 0 ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        engine.isEmpty ||
        shots.isEmpty) {
      throw const FormatException('Reframe plan header or shots are invalid.');
    }
    var end = 0;
    for (final shot in shots) {
      final error = shot.validate(sourceDurationMs: sourceDurationMs);
      if (error != null || shot.startMs != end) {
        throw FormatException(error ?? 'Reframe shots overlap or are not time ordered.');
      }
      end = shot.endMs;
    }
    if (shots.first.startMs != 0 ||
        shots.last.endMs != sourceDurationMs) {
      throw const FormatException('Reframe plan must cover the source duration.');
    }
    if (focusTrack != null) {
      final error = focusTrack!.validate(durationMs: sourceDurationMs);
      if (error != null) {
        throw FormatException(error);
      }
    }
    if (shots.any((shot) => shot.mode == 'crop') && focusTrack == null) {
      throw const FormatException('Automatic crop shots require a validated focus track.');
    }
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'sourceDurationMs': sourceDurationMs,
        'aspectRatio': aspectRatio,
        'shots': shots.map((shot) => shot.toJson()).toList(),
        'focusTrack': focusTrack?.toJson(),
        'fallbackReason': fallbackReason,
        'engine': engine,
      };
}

class ReframePlanner {
  const ReframePlanner();

  ReframePlan create({
    required int sourceDurationMs,
    required int sourceWidth,
    required int sourceHeight,
    required double targetAspectRatio,
    required List<FrameBox> detections,
    required List<double> confidenceScores,
    required List<int> timestampsMs,
    int minimumCropWidthPx = 96,
    bool preferContext = false,
  }) {
    if (sourceDurationMs <= 0 || sourceWidth <= 0 || sourceHeight <= 0 ||
        !targetAspectRatio.isFinite || targetAspectRatio <= 0 ||
        detections.length != confidenceScores.length ||
        detections.length != timestampsMs.length ||
        minimumCropWidthPx <= 0) {
      throw const FormatException('Reframe inputs are incomplete or mismatched.');
    }
    final eligible = <FocusKeyframe>[];
    for (var i = 0; i < detections.length; i++) {
      final box = detections[i];
      final confidence = confidenceScores[i];
      final timestamp = timestampsMs[i];
      if (box.validate() != null ||
          !confidence.isFinite || confidence < 0.65 || confidence > 1 ||
          timestamp < 0 || timestamp >= sourceDurationMs) {
        continue;
      }
      final widthPx = box.width * sourceWidth;
      final heightPx = box.height * sourceHeight;
      if (widthPx < minimumCropWidthPx || heightPx < minimumCropWidthPx) {
        continue;
      }
      eligible.add(FocusKeyframe(
        timestampMs: timestamp,
        centerX: (box.x + box.width / 2).clamp(0.0, 1.0).toDouble(),
        confidence: confidence,
        cut: eligible.isNotEmpty &&
            (eligible.last.centerX - (box.x + box.width / 2)).abs() > 0.18,
      ));
    }

    eligible.sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final deduplicated = <FocusKeyframe>[];
    for (final frame in eligible) {
      if (deduplicated.isNotEmpty &&
          frame.timestampMs <= deduplicated.last.timestampMs) {
        continue;
      }
      deduplicated.add(frame);
    }

    final coverage = detections.isEmpty ? 0.0 : deduplicated.length / detections.length;
    final confidenceSum = deduplicated.fold<double>(
      0,
      (sum, frame) => sum + frame.confidence,
    );
    final averageConfidence = deduplicated.isEmpty
        ? 0.0
        : confidenceSum / deduplicated.length;
    final focus = deduplicated.isEmpty
        ? null
        : FocusTrack(
            keyframes: deduplicated,
            averageConfidence: averageConfidence,
            coverage: coverage,
            source: 'android-frame-analysis',
          );
    final validTrack = focus != null &&
        focus.validate(durationMs: sourceDurationMs) == null &&
        !preferContext;

    final targetWidth = (sourceHeight * targetAspectRatio).round();
    final cropWidth = targetWidth.clamp(1, sourceWidth).toInt();
    final cropHeight = (cropWidth / targetAspectRatio).round().clamp(1, sourceHeight).toInt();
    final normalizedW = cropWidth / sourceWidth;
    final normalizedH = cropHeight / sourceHeight;
    final shots = <ReframeShot>[];

    if (!validTrack) {
      shots.add(ReframeShot(
        startMs: 0,
        endMs: sourceDurationMs,
        mode: 'fit',
        confidence: averageConfidence,
        reviewReason: preferContext
            ? 'Context-preserving layout requested.'
            : 'No sufficiently confident and continuous subject track; preserve the full scene.',
      ));
    } else {
      for (var index = 0; index < deduplicated.length; index++) {
        final frame = deduplicated[index];
        final start = frame.timestampMs;
        final end = index + 1 < deduplicated.length
            ? deduplicated[index + 1].timestampMs
            : sourceDurationMs;
        if (end <= start) continue;
        final left = (frame.centerX - normalizedW / 2)
            .clamp(0.0, 1.0 - normalizedW).toDouble();
        final region = FrameBox(
          x: left,
          y: (1 - normalizedH) / 2,
          width: normalizedW,
          height: normalizedH,
        );
        shots.add(ReframeShot(
          startMs: start,
          endMs: end,
          mode: 'crop',
          region: region,
          focusCenterX: frame.centerX,
          confidence: frame.confidence,
        ));
      }
      if (shots.isNotEmpty && shots.first.startMs > 0) {
        shots.insert(0, ReframeShot(
          startMs: 0,
          endMs: shots.first.startMs,
          mode: 'fit',
          confidence: averageConfidence,
          reviewReason: 'No preceding detection; preserve context.',
        ));
      }
      if (shots.isEmpty) {
        shots.add(ReframeShot(
          startMs: 0,
          endMs: sourceDurationMs,
          mode: 'fit',
          confidence: 0,
          reviewReason: 'No valid focus intervals were produced.',
        ));
      }
    }

    final plan = ReframePlan(
      schemaVersion: ReframePlan.currentSchemaVersion,
      sourceDurationMs: sourceDurationMs,
      aspectRatio: targetAspectRatio,
      shots: shots,
      focusTrack: validTrack ? focus : null,
      fallbackReason: validTrack ? null : (preferContext
          ? 'context-preserving layout'
          : 'insufficient face/speaker confidence or temporal coverage'),
      engine: 'conservative-frame-reframe-v1',
    );
    plan.validate();
    return plan;
  }
}
