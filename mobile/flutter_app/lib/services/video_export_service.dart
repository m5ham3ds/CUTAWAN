import 'dart:async';

import 'package:flutter/services.dart';

import 'processing_job_service.dart';

class VideoExportCancelled implements Exception {
  const VideoExportCancelled();

  @override
  String toString() => 'Video export was cancelled.';
}

class VideoExportResult {
  const VideoExportResult({
    required this.renderId,
    required this.outputUri,
    required this.displayName,
    required this.sha256,
    required this.sizeBytes,
    required this.durationMs,
    required this.width,
    required this.height,
    required this.hasAudio,
    required this.validated,
  });

  final String renderId;
  final String outputUri;
  final String displayName;
  final String sha256;
  final int sizeBytes;
  final int durationMs;
  final int width;
  final int height;
  final bool hasAudio;
  final bool validated;

  factory VideoExportResult.fromJson(
    String renderId,
    Map<String, dynamic> json,
  ) {
    final value = VideoExportResult(
      renderId: renderId,
      outputUri: json['outputUri'] as String? ?? '',
      displayName: json['displayName'] as String? ?? '',
      sha256: json['sha256'] as String? ?? '',
      sizeBytes: (json['sizeBytes'] as num?)?.toInt() ?? 0,
      durationMs: (json['durationMs'] as num?)?.toInt() ?? 0,
      width: (json['width'] as num?)?.toInt() ?? 0,
      height: (json['height'] as num?)?.toInt() ?? 0,
      hasAudio: json['hasAudio'] as bool? ?? false,
      validated: json['validated'] as bool? ?? false,
    );
    if (value.outputUri.isEmpty ||
        !ProcessingJobService.isSha256(value.sha256) ||
        value.sizeBytes < 2048 ||
        value.durationMs <= 0 ||
        value.width <= 0 ||
        value.height <= 0 ||
        !value.validated) {
      throw const FormatException(
        'Android returned an export that did not pass output validation.',
      );
    }
    return value;
  }
}

class VideoExportService {
  VideoExportService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.cutawan.mobile/media');

  final MethodChannel _channel;

  Future<VideoExportResult> renderClip({
    required String clipId,
    required String sourceUri,
    required int startMs,
    required int endMs,
    required double aspectRatio,
    required String outputPath,
    void Function(double progress)? onProgress,
    void Function(String renderId)? onStarted,
    Future<bool> Function()? shouldCancel,
    Duration timeout = const Duration(hours: 2),
  }) async {
    if (clipId.trim().isEmpty ||
        sourceUri.trim().isEmpty ||
        startMs < 0 ||
        endMs <= startMs ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        outputPath.trim().isEmpty) {
      throw const FormatException('Video export arguments are incomplete or invalid.');
    }
    final start = await _channel.invokeMapMethod<String, dynamic>(
      'startRender',
      <String, Object?>{
        'clipId': clipId,
        'uri': sourceUri,
        'startMs': startMs,
        'endMs': endMs,
        'aspectRatio': aspectRatio,
        'outputPath': outputPath,
      },
    );
    final renderId = start?['renderId'];
    if (renderId is! String || renderId.isEmpty) {
      throw const FormatException('Android did not start the video export.');
    }
    onStarted?.call(renderId);
    final stopwatch = Stopwatch()..start();
    try {
      while (stopwatch.elapsed < timeout) {
        if (await shouldCancel?.call() ?? false) {
          await cancelRender(renderId);
          throw const VideoExportCancelled();
        }
        final snapshot = await _channel.invokeMapMethod<String, dynamic>(
          'getRenderProgress',
          <String, Object?>{'renderId': renderId},
        );
        if (snapshot == null) {
          throw StateError('Android lost the active video export session.');
        }
        final state = snapshot['status'] as String? ?? 'unknown';
        final percentage = (snapshot['progress'] as num?)?.toDouble() ?? 0;
        onProgress?.call((percentage / 100).clamp(0.0, 1.0));
        if (state == 'completed') {
          final raw = snapshot['result'];
          if (raw is! Map) {
            throw const FormatException('Android completed without export metadata.');
          }
          return VideoExportResult.fromJson(renderId, Map<String, dynamic>.from(raw));
        }
        if (state == 'cancelled') throw const VideoExportCancelled();
        if (state == 'failed') {
          throw StateError(
            snapshot['error'] as String? ?? 'Android video export failed.',
          );
        }
        if (state != 'running') {
          throw StateError('Unknown Android export status: $state');
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      await cancelRender(renderId);
      throw TimeoutException('Video export exceeded ' + timeout.inMinutes.toString() + ' minutes.');
    } finally {
      try {
        await _channel.invokeMethod<void>(
          'releaseRender',
          <String, Object?>{'renderId': renderId},
        );
      } on PlatformException {
        // The native Activity may have been recreated while exporting.
      }
    }
  }

  Future<void> cancelRender(String renderId) async {
    await _channel.invokeMethod<bool>(
      'cancelRender',
      <String, Object?>{'renderId': renderId},
    );
  }
}
