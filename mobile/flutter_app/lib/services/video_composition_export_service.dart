import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:flutter/services.dart';

import 'processing_job_service.dart';
import 'video_export_service.dart';

/// Sends validated project tracks to Android Media3 Composition.
/// Each track is linear; independent tracks may overlap, but clips within a
/// single track cannot overlap. Cross-fades are not supported by Media3.
class VideoCompositionExportService {
  VideoCompositionExportService({MethodChannel? channel})
      : _channel = channel ?? const MethodChannel('com.cutawan.mobile/media');

  final MethodChannel _channel;

  static final RegExp _projectIdPattern = RegExp(r'^[A-Za-z0-9_-]{1,160}$');
  static final RegExp _itemIdPattern = RegExp(r'^[A-Za-z0-9_-]{3,120}$');

  Future<VideoExportResult> renderComposition({
    required String projectId,
    required String compositionId,
    required List<Map<String, Object?>> tracks,
    required int sourceDurationMs,
    required int expectedDurationMs,
    required double aspectRatio,
    required String outputPath,
    String? renderKey,
    void Function(double progress)? onProgress,
    void Function(String renderId)? onStarted,
    Future<bool> Function()? shouldCancel,
    Duration timeout = const Duration(hours: 2),
  }) async {
    if (!_projectIdPattern.hasMatch(projectId) ||
        !_itemIdPattern.hasMatch(compositionId) ||
        tracks.isEmpty ||
        tracks.length > 16 ||
        sourceDurationMs <= 0 ||
        expectedDurationMs <= 0 ||
        expectedDurationMs > const Duration(hours: 6).inMilliseconds ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        aspectRatio > 4 ||
        outputPath.trim().isEmpty) {
      throw const FormatException(
        'Composition identity, duration, aspect ratio or output path is invalid.',
      );
    }

    final trackIds = <String>{};
    final itemIds = <String>{};
    final normalizedTracks = <Map<String, Object?>>[];
    var totalClips = 0;
    var maximumTimelineEndMs = 0;
    var hasMainVideo = false;

    for (final rawTrack in tracks) {
      final trackId = rawTrack['id'];
      final type = rawTrack['type'];
      final rawClips = rawTrack['clips'];
      if (trackId is! String ||
          !_itemIdPattern.hasMatch(trackId) ||
          !trackIds.add(trackId) ||
          type is! String ||
          !const {'video', 'audio', 'overlay'}.contains(type) ||
          rawClips is! List ||
          rawClips.length > 500) {
        throw const FormatException(
          'Composition track identity, type or clip list is invalid.',
        );
      }
      if (rawClips.isEmpty) continue;
      if (type == 'video') hasMainVideo = true;

      final normalizedClips = <Map<String, Object?>>[];
      var previousTimelineEndMs = 0;
      final ordered = rawClips.toList()
        ..sort((left, right) {
          if (left is! Map || right is! Map) return 0;
          final leftStart = (left['timelineStartMs'] as num?)?.toInt() ?? -1;
          final rightStart = (right['timelineStartMs'] as num?)?.toInt() ?? -1;
          return leftStart.compareTo(rightStart);
        });

      for (final rawClip in ordered) {
        if (rawClip is! Map) {
          throw const FormatException('Composition clip must be an object.');
        }
        final itemId = rawClip['itemId'];
        final candidateId = rawClip['candidateId'];
        final sourceUri = rawClip['sourceUri'];
        final sourceStartMs = (rawClip['sourceStartMs'] as num?)?.toInt();
        final sourceEndMs = (rawClip['sourceEndMs'] as num?)?.toInt();
        final timelineStartMs = (rawClip['timelineStartMs'] as num?)?.toInt();
        final parsedUri = sourceUri is String ? Uri.tryParse(sourceUri) : null;

        if (itemId is! String ||
            !_itemIdPattern.hasMatch(itemId) ||
            !itemIds.add(itemId) ||
            candidateId is! String ||
            !_itemIdPattern.hasMatch(candidateId) ||
            parsedUri == null ||
            !const {'content', 'file'}.contains(parsedUri.scheme) ||
            (parsedUri.scheme == 'content' && parsedUri.authority.isEmpty) ||
            (parsedUri.scheme == 'file' && parsedUri.path.isEmpty) ||
            sourceStartMs == null ||
            sourceEndMs == null ||
            timelineStartMs == null ||
            sourceStartMs < 0 ||
            sourceEndMs <= sourceStartMs ||
            sourceEndMs > sourceDurationMs ||
            timelineStartMs < previousTimelineEndMs ||
            timelineStartMs < 0 ||
            timelineStartMs + sourceEndMs - sourceStartMs > expectedDurationMs) {
          throw const FormatException('Composition clip URI or timing is invalid.');
        }

        final timelineEndMs = timelineStartMs + sourceEndMs - sourceStartMs;
        previousTimelineEndMs = timelineEndMs;
        if (timelineEndMs > maximumTimelineEndMs) {
          maximumTimelineEndMs = timelineEndMs;
        }
        totalClips++;
        if (totalClips > 500) {
          throw const FormatException(
            'A composition may contain at most 500 clips.',
          );
        }
        normalizedClips.add({
          'itemId': itemId,
          'candidateId': candidateId,
          'sourceUri': sourceUri,
          'sourceStartMs': sourceStartMs,
          'sourceEndMs': sourceEndMs,
          'timelineStartMs': timelineStartMs,
        });
      }

      normalizedTracks.add({
        'id': trackId,
        'type': type,
        'clips': normalizedClips,
      });
    }

    if (!hasMainVideo ||
        totalClips == 0 ||
        maximumTimelineEndMs != expectedDurationMs) {
      throw const FormatException(
        'A composition requires a non-empty video track and matching timeline duration.',
      );
    }

    final fingerprintInput = jsonEncode({
      'projectId': projectId,
      'compositionId': compositionId,
      'sourceDurationMs': sourceDurationMs,
      'expectedDurationMs': expectedDurationMs,
      'aspectRatio': aspectRatio,
      'tracks': normalizedTracks,
    });
    final stableRenderKey =
        renderKey ?? sha256.convert(utf8.encode(fingerprintInput)).toString();
    if (!ProcessingJobService.isSha256(stableRenderKey)) {
      throw const FormatException(
        'The composition fingerprint must be a SHA-256 value.',
      );
    }

    final start = await _channel.invokeMapMethod<String, dynamic>(
      'startRender',
      <String, Object?>{
        'renderType': 'composition',
        'renderKey': stableRenderKey,
        'projectId': projectId,
        'clipId': compositionId,
        'tracks': normalizedTracks,
        'sourceDurationMs': sourceDurationMs,
        'expectedDurationMs': expectedDurationMs,
        'aspectRatio': aspectRatio,
        'outputPath': outputPath,
      },
    );
    final renderId = start?['renderId'];
    if (renderId is! String || renderId.isEmpty) {
      throw const FormatException('Android did not start the composition export.');
    }
    onStarted?.call(renderId);

    final stopwatch = Stopwatch()..start();
    try {
      while (stopwatch.elapsed < timeout) {
        if (await shouldCancel?.call() ?? false) {
          await _cancelRender(renderId);
          throw const VideoExportCancelled();
        }

        final snapshot = await _channel.invokeMapMethod<String, dynamic>(
          'getRenderProgress',
          <String, Object?>{'renderId': renderId},
        );
        if (snapshot == null) {
          throw StateError('Android lost the active composition export session.');
        }
        final state = snapshot['status'] as String? ?? 'unknown';
        final percentage = (snapshot['progress'] as num?)?.toDouble() ?? 0;
        onProgress?.call((percentage / 100).clamp(0.0, 1.0));

        if (state == 'completed') {
          final raw = snapshot['result'];
          if (raw is! Map) {
            throw const FormatException(
              'Android completed without composition metadata.',
            );
          }
          final result = VideoExportResult.fromJson(
            renderId,
            Map<String, dynamic>.from(raw),
          );
          final durationToleranceMs =
              expectedDurationMs ~/ 10 > 1500 ? expectedDurationMs ~/ 10 : 1500;
          if ((result.durationMs - expectedDurationMs).abs() >
              durationToleranceMs) {
            throw const FormatException(
              'Rendered duration differs from the saved composition timeline.',
            );
          }
          return result;
        }
        if (state == 'cancelled') throw const VideoExportCancelled();
        if (state == 'failed') {
          throw StateError(
            snapshot['error'] as String? ?? 'Android composition export failed.',
          );
        }
        if (state != 'running' && state != 'queued') {
          throw StateError('Unknown Android composition status: $state');
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      await _cancelRender(renderId);
      throw TimeoutException('Composition export exceeded the time limit.');
    } finally {
      try {
        await _channel.invokeMethod<void>(
          'releaseRender',
          <String, Object?>{'renderId': renderId},
        );
      } on PlatformException {
        // The Android Activity may have been recreated while exporting.
      }
    }
  }

  Future<void> _cancelRender(String renderId) async {
    await _channel.invokeMethod<bool>(
      'cancelRender',
      <String, Object?>{'renderId': renderId},
    );
  }
}
