import 'package:flutter/services.dart';

import '../domain/reframe_contract.dart';

class AndroidReframeAnalysisService {
  const AndroidReframeAnalysisService({
    MethodChannel channel = const MethodChannel('com.cutawan.mobile/media'),
    ReframePlanner planner = const ReframePlanner(),
  })  : _channel = channel,
        _planner = planner;

  final MethodChannel _channel;
  final ReframePlanner _planner;

  Future<ReframePlan> analyze({
    required String sourceUri,
    required int sourceDurationMs,
    required int sourceWidth,
    required int sourceHeight,
    required double targetAspectRatio,
    bool preferContext = false,
  }) async {
    if (sourceUri.trim().isEmpty ||
        sourceDurationMs <= 0 ||
        sourceWidth <= 0 ||
        sourceHeight <= 0) {
      throw const FormatException('Reframe source metadata is incomplete.');
    }

    final response = await _channel.invokeMapMethod<String, dynamic>(
      'analyzeFaces',
      <String, Object?>{'uri': sourceUri},
    );
    if (response == null) {
      throw const FormatException('Android returned no face-analysis response.');
    }
    final returnedDuration =
        (response['sourceDurationMs'] as num?)?.toInt() ?? -1;
    if ((returnedDuration - sourceDurationMs).abs() > 1000) {
      throw const FormatException(
        'Face-analysis duration does not match the selected project source.',
      );
    }

    final rawSamples = response['samples'];
    if (rawSamples is! List) {
      throw const FormatException('Android face-analysis samples are missing.');
    }
    final boxes = <FrameBox>[];
    final confidence = <double>[];
    final timestamps = <int>[];
    for (final raw in rawSamples) {
      if (raw is! Map) {
        throw const FormatException('Face-analysis sample must be an object.');
      }
      final sample = Map<String, dynamic>.from(raw);
      final timestamp = (sample['timestampMs'] as num?)?.toInt() ?? -1;
      final score = (sample['confidence'] as num?)?.toDouble() ?? 0;
      final rawBox = sample['box'];
      if (rawBox == null) {
        boxes.add(const FrameBox(x: -1, y: -1, width: 0, height: 0));
      } else if (rawBox is Map) {
        boxes.add(FrameBox.fromJson(Map<String, dynamic>.from(rawBox)));
      } else {
        throw const FormatException('Detected face geometry must be an object or null.');
      }
      timestamps.add(timestamp);
      confidence.add(score);
    }

    final plan = _planner.create(
      sourceDurationMs: sourceDurationMs,
      sourceWidth: sourceWidth,
      sourceHeight: sourceHeight,
      targetAspectRatio: targetAspectRatio,
      detections: boxes,
      confidenceScores: confidence,
      timestampsMs: timestamps,
      preferContext: preferContext,
    );
    plan.validate();
    return plan;
  }
}
