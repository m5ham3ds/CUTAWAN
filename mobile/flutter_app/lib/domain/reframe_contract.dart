import 'dart:math' as math;

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
    this.centerY = 0.5,
    this.cut = false,
    this.confidence = 0,
  });

  final int timestampMs;
  final double centerX;
  final double centerY;
  final bool cut;
  final double confidence;

  String? validate() {
    if (timestampMs < 0 ||
        !centerX.isFinite ||
        centerX < 0 ||
        centerX > 1 ||
        !centerY.isFinite ||
        centerY < 0 ||
        centerY > 1 ||
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
        centerY: (json['centerY'] as num?)?.toDouble() ?? 0.5,
        cut: json['cut'] as bool? ?? false,
        confidence: (json['confidence'] as num?)?.toDouble() ?? -1,
      );

  Map<String, Object?> toJson() => {
        'timestampMs': timestampMs,
        'centerX': centerX,
        'centerY': centerY,
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
    if (raw is! List) {
      throw const FormatException('Focus keyframes must be an array.');
    }
    return FocusTrack(
      keyframes: raw.map((item) {
        if (item is! Map) {
          throw const FormatException('Focus keyframe must be an object.');
        }
        return FocusKeyframe.fromJson(Map<String, dynamic>.from(item));
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
    if (rawRegion != null && rawRegion is! Map) {
      throw const FormatException('Reframe region must be an object.');
    }
    return ReframeShot(
      startMs: (json['startMs'] as num?)?.toInt() ?? -1,
      endMs: (json['endMs'] as num?)?.toInt() ?? -1,
      mode: json['mode'] as String? ?? '',
      region: rawRegion == null
          ? null
          : FrameBox.fromJson(Map<String, dynamic>.from(rawRegion as Map)),
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
    if (rawShots is! List) {
      throw const FormatException('Reframe shots must be an array.');
    }
    final rawFocus = json['focusTrack'];
    if (rawFocus != null && rawFocus is! Map) {
      throw const FormatException('Focus track must be an object.');
    }
    final plan = ReframePlan(
      schemaVersion: (json['schemaVersion'] as num?)?.toInt() ?? -1,
      sourceDurationMs: (json['sourceDurationMs'] as num?)?.toInt() ?? -1,
      aspectRatio: (json['aspectRatio'] as num?)?.toDouble() ?? -1,
      shots: rawShots.map((item) {
        if (item is! Map) {
          throw const FormatException('Reframe shot must be an object.');
        }
        return ReframeShot.fromJson(Map<String, dynamic>.from(item));
      }).toList(growable: false),
      focusTrack: rawFocus == null
          ? null
          : FocusTrack.fromJson(Map<String, dynamic>.from(rawFocus as Map)),
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

class _ReframeSample {
  const _ReframeSample({
    required this.timestampMs,
    required this.box,
    required this.confidence,
    required this.cropEligible,
  });

  final int timestampMs;
  final FrameBox? box;
  final double confidence;
  final bool cropEligible;
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
    final samplesByTimestamp = <int, _ReframeSample>{};
    for (var i = 0; i < detections.length; i++) {
      final timestamp = timestampsMs[i];
      if (timestamp < 0 || timestamp >= sourceDurationMs) continue;
      final box = detections[i];
      final rawConfidence = confidenceScores[i];
      final confidence = rawConfidence.isFinite
          ? rawConfidence.clamp(0.0, 1.0).toDouble()
          : 0.0;
      final cropEligible = box.validate() == null &&
          rawConfidence.isFinite &&
          rawConfidence >= 0.65 &&
          rawConfidence <= 1 &&
          box.width * sourceWidth >= minimumCropWidthPx &&
          box.height * sourceHeight >= minimumCropWidthPx;
      final candidate = _ReframeSample(
        timestampMs: timestamp,
        box: cropEligible ? box : null,
        confidence: confidence,
        cropEligible: cropEligible,
      );
      final existing = samplesByTimestamp[timestamp];
      if (existing == null ||
          (candidate.cropEligible && !existing.cropEligible) ||
          (candidate.cropEligible == existing.cropEligible &&
              candidate.confidence > existing.confidence)) {
        samplesByTimestamp[timestamp] = candidate;
      }
    }

    final samples = samplesByTimestamp.values.toList()
      ..sort((a, b) => a.timestampMs.compareTo(b.timestampMs));
    final eligibleSamples =
        samples.where((sample) => sample.cropEligible).toList(growable: false);
    final keyframes = <FocusKeyframe>[];
    for (final sample in eligibleSamples) {
      final box = sample.box!;
      final centerX =
          (box.x + box.width / 2).clamp(0.0, 1.0).toDouble();
      keyframes.add(FocusKeyframe(
        timestampMs: sample.timestampMs,
        centerX: centerX,
        centerY: (box.y + box.height / 2).clamp(0.0, 1.0).toDouble(),
        confidence: sample.confidence,
        cut: keyframes.isNotEmpty &&
            (keyframes.last.centerX - centerX).abs() > 0.18,
      ));
    }

    // Preserve the historical denominator (all native samples, including
    // duplicate timestamps) so duplicate frames cannot inflate coverage.
    final coverage =
        detections.isEmpty ? 0.0 : eligibleSamples.length / detections.length;
    final confidenceSum = keyframes.fold<double>(
      0,
      (sum, frame) => sum + frame.confidence,
    );
    final averageConfidence =
        keyframes.isEmpty ? 0.0 : confidenceSum / keyframes.length;
    final focus = keyframes.isEmpty
        ? null
        : FocusTrack(
            keyframes: keyframes,
            averageConfidence: averageConfidence,
            coverage: coverage,
            source: 'android-frame-analysis',
          );
    final validTrack = focus != null &&
        focus.validate(durationMs: sourceDurationMs) == null &&
        !preferContext;

    final targetWidth = (sourceHeight * targetAspectRatio).round();
    final cropWidth = targetWidth.clamp(1, sourceWidth).toInt();
    final cropHeight =
        (cropWidth / targetAspectRatio).round().clamp(1, sourceHeight).toInt();
    final normalizedW = cropWidth / sourceWidth;
    final normalizedH = cropHeight / sourceHeight;
    final shots = <ReframeShot>[];

    void appendFit(int startMs, int endMs, String reason) {
      if (endMs <= startMs) return;
      if (shots.isNotEmpty &&
          shots.last.mode == 'fit' &&
          shots.last.endMs == startMs) {
        final previous = shots.removeLast();
        shots.add(ReframeShot(
          startMs: previous.startMs,
          endMs: endMs,
          mode: 'fit',
          confidence: averageConfidence,
          reviewReason: reason,
        ));
      } else {
        shots.add(ReframeShot(
          startMs: startMs,
          endMs: endMs,
          mode: 'fit',
          confidence: averageConfidence,
          reviewReason: reason,
        ));
      }
    }

    void appendCrop(_ReframeSample sample, int startMs, int endMs) {
      if (endMs <= startMs) return;
      final box = sample.box!;
      final centerX =
          (box.x + box.width / 2).clamp(0.0, 1.0).toDouble();
      final centerY =
          (box.y + box.height / 2).clamp(0.0, 1.0).toDouble();
      final left = (centerX - normalizedW / 2)
          .clamp(0.0, 1.0 - normalizedW)
          .toDouble();
      final top = (centerY - normalizedH / 2)
          .clamp(0.0, 1.0 - normalizedH)
          .toDouble();
      shots.add(ReframeShot(
        startMs: startMs,
        endMs: endMs,
        mode: 'crop',
        region: FrameBox(
          x: left,
          y: top,
          width: normalizedW,
          height: normalizedH,
        ),
        focusCenterX: centerX,
        confidence: sample.confidence,
      ));
    }

    if (!validTrack) {
      appendFit(
        0,
        sourceDurationMs,
        preferContext
            ? 'Context-preserving layout requested.'
            : 'No sufficiently confident face coverage; preserve the full scene.',
      );
    } else if (samples.isNotEmpty) {
      final intervals = <int>[];
      for (var index = 1; index < samples.length; index++) {
        final interval =
            samples[index].timestampMs - samples[index - 1].timestampMs;
        if (interval > 0) intervals.add(interval);
      }
      intervals.sort();
      final medianInterval = intervals.isEmpty
          ? 1200
          : intervals[intervals.length ~/ 2];
      final maximumTrackedGapMs = math.max(1600, medianInterval * 2).toInt();
      final halfSupportMs = math.math.max(1, maximumTrackedGapMs ~/ 2).toInt();
      var cursor = 0;

      for (var index = 0; index < samples.length; index++) {
        final sample = samples[index];
        final previous = index > 0 ? samples[index - 1] : null;
        final next = index + 1 < samples.length ? samples[index + 1] : null;

        final start = previous == null
            ? math.math.max(0, sample.timestampMs - halfSupportMs).toInt()
            : sample.timestampMs - previous.timestampMs <=
                    maximumTrackedGapMs
                ? (previous.timestampMs + sample.timestampMs) ~/ 2
                : math.math.max(
                    previous.timestampMs + halfSupportMs,
                    sample.timestampMs - halfSupportMs,
                  ).toInt();
        final end = next == null
            ? math.math.min(sourceDurationMs, sample.timestampMs + halfSupportMs)
                .toInt()
            : next.timestampMs - sample.timestampMs <= maximumTrackedGapMs
                ? (sample.timestampMs + next.timestampMs) ~/ 2
                : math.math.min(
                    sample.timestampMs + halfSupportMs,
                    next.timestampMs - halfSupportMs,
                  ).toInt();

        final safeStart = start.clamp(cursor, sourceDurationMs).toInt();
        final safeEnd = end.clamp(safeStart, sourceDurationMs).toInt();
        if (safeStart > cursor) {
          appendFit(
            cursor,
            safeStart,
            'No nearby confident face sample; preserve the full scene.',
          );
        }
        if (sample.cropEligible) {
          appendCrop(sample, safeStart, safeEnd);
        } else {
          appendFit(
            safeStart,
            safeEnd,
            'Face not confidently detected in this interval; preserve the full scene.',
          );
        }
        cursor = safeEnd;
      }

      if (cursor < sourceDurationMs) {
        appendFit(
          cursor,
          sourceDurationMs,
          'No recent confident face sample; preserve the full scene.',
        );
      }
    }

    if (shots.isEmpty) {
      appendFit(
        0,
        sourceDurationMs,
        'No valid focus intervals were produced; preserve the full scene.',
      );
    }

    final plan = ReframePlan(
      schemaVersion: ReframePlan.currentSchemaVersion,
      sourceDurationMs: sourceDurationMs,
      aspectRatio: targetAspectRatio,
      shots: shots,
      focusTrack: validTrack ? focus : null,
      fallbackReason: validTrack
          ? (shots.any((shot) => shot.mode == 'fit')
              ? 'Untracked intervals preserve the full scene.'
              : null)
          : (preferContext
              ? 'context-preserving layout'
              : 'insufficient face confidence or temporal coverage'),
      engine: 'conservative-frame-reframe-v1',
    );
    plan.validate();
    return plan;
  }
}
