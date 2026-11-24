import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
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
    required this.fullyDecodeValidated,
    required this.decodedVideoBuffers,
    required this.decodedAudioBuffers,
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
  final bool fullyDecodeValidated;
  final int decodedVideoBuffers;
  final int decodedAudioBuffers;
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
      fullyDecodeValidated: json['fullyDecodeValidated'] as bool? ?? false,
      decodedVideoBuffers: (json['decodedVideoBuffers'] as num?)?.toInt() ?? 0,
      decodedAudioBuffers: (json['decodedAudioBuffers'] as num?)?.toInt() ?? 0,
      validated: json['validated'] as bool? ?? false,
    );
    if (value.outputUri.isEmpty ||
        !ProcessingJobService.isSha256(value.sha256) ||
        value.sizeBytes < 2048 ||
        value.durationMs <= 0 ||
        value.width <= 0 ||
        value.height <= 0 ||
        !value.fullyDecodeValidated ||
        value.decodedVideoBuffers <= 0 ||
        (value.hasAudio && value.decodedAudioBuffers <= 0) ||
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
    double? sourceAspectRatio,
    List<Map<String, Object?>> reframeShots = const [],
    int fadeInMs = 0,
    int fadeOutMs = 0,
    List<Map<String, Object?>> captionCues = const [],
    Map<String, Object?>? captionStyle,
    String captionAnimationId = 'static',
    String? renderKey,
    String projectId = 'standalone',
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
        fadeInMs < 0 ||
        fadeInMs > 1500 ||
        fadeOutMs < 0 ||
        fadeOutMs > 1500 ||
        fadeInMs + fadeOutMs > endMs - startMs ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        !(sourceAspectRatio ?? aspectRatio).isFinite ||
        (sourceAspectRatio ?? aspectRatio) <= 0 ||
        outputPath.trim().isEmpty ||
        !_validReframeShots(
          reframeShots,
          endMs - startMs,
          sourceAspectRatio ?? aspectRatio,
          aspectRatio,
        ) ||
        !_validCaptionCues(captionCues, endMs - startMs) ||
        (captionCues.isNotEmpty && !_validCaptionStyle(captionStyle))) {
      throw const FormatException('Video export arguments are incomplete or invalid.');
    }
    final stableRenderKey = renderKey ??
        sha256
            .convert(
              utf8.encode(
                '$clipId|$sourceUri|$startMs|$endMs|${DateTime.now().microsecondsSinceEpoch}',
              ),
            )
            .toString();
    if (!ProcessingJobService.isSha256(stableRenderKey)) {
      throw const FormatException('The render fingerprint must be a SHA-256 value.');
    }
    final start = await _channel.invokeMapMethod<String, dynamic>(
      'startRender',
      <String, Object?>{
        'renderKey': stableRenderKey,
        'projectId': projectId,
        'clipId': clipId,
        'uri': sourceUri,
        'startMs': startMs,
        'endMs': endMs,
        'aspectRatio': aspectRatio,
        'sourceAspectRatio': sourceAspectRatio ?? aspectRatio,
        'reframeShots': reframeShots,
        'fadeInMs': fadeInMs,
        'fadeOutMs': fadeOutMs,
        'captionCues': captionCues,
        'captionStyle': captionStyle,
        'captionAnimationId': captionAnimationId,
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
        if (state != 'running' && state != 'queued') {
          throw StateError('Unknown Android export status: $state');
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      await cancelRender(renderId);
      throw TimeoutException('Video export exceeded ${timeout.inMinutes} minutes.');
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

  /// Returns true while WorkManager owns queued/running work for this project,
  /// including a succeeded render whose durable completion has not been consumed.
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
    final projectPattern = RegExp(r'^[A-Za-z0-9_-]{1,160}    if (projectId.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'hasActiveBackgroundRender',
            <String, Object?>{'projectId': projectId},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Reads a render that WorkManager finished while the Flutter process was absent.
  /// The caller must persist the export record and stage checkpoint before acknowledging it.
  Future<VideoExportResult?> consumeCompletedRender({
    required String renderKey,
  }) async {
    if (!ProcessingJobService.isSha256(renderKey)) {
      throw const FormatException('The render fingerprint must be a SHA-256 value.');
    }
    final payload = await _channel.invokeMapMethod<String, dynamic>(
      'getCompletedRender',
      <String, Object?>{'renderKey': renderKey},
    );
    if (payload == null) return null;
    final renderId = payload['renderId'];
    final raw = payload['result'];
    if (renderId is! String || renderId.isEmpty || raw is! Map) {
      throw const FormatException('The durable render completion is malformed.');
    }
    return VideoExportResult.fromJson(
      renderId,
      Map<String, dynamic>.from(raw),
    );
  }

  /// Deletes the durable completion only after the caller has persisted its
  /// export record and stage checkpoint.
  Future<bool> acknowledgeCompletedRender({
    required String renderKey,
    required String sha256,
  }) async {
    if (!ProcessingJobService.isSha256(renderKey) ||
        !ProcessingJobService.isSha256(sha256)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'acknowledgeCompletedRender',
            <String, Object?>{'renderKey': renderKey, 'sha256': sha256},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static bool _validCaptionCues(List<Map<String, Object?>> cues, int clipDurationMs) {
    var previousStart = -1;
    for (final cue in cues) {
      final start = cue['startMs'];
      final end = cue['endMs'];
      final text = cue['text'];
      final rawWords = cue['words'];
      if (start is! int ||
          end is! int ||
          text is! String ||
          text.trim().isEmpty ||
          rawWords is! List ||
          start < 0 ||
          end <= start ||
          end > clipDurationMs ||
          start < previousStart) {
        return false;
      }
      previousStart = start;
      for (final rawWord in rawWords) {
        if (rawWord is! Map) {
          return false;
        }
        final wordText = rawWord['text'];
        final wordStart = rawWord['startMs'];
        final wordEnd = rawWord['endMs'];
        final textStart = rawWord['startOffset'];
        final textEnd = rawWord['endOffset'];
        if (wordText is! String ||
            wordText.isEmpty ||
            wordStart is! int ||
            wordEnd is! int ||
            textStart is! int ||
            textEnd is! int ||
            wordStart < start ||
            wordEnd <= wordStart ||
            wordEnd > end ||
            textStart < 0 ||
            textEnd <= textStart ||
            textEnd > text.length) {
          return false;
        }
        if (text.substring(textStart, textEnd) != wordText) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _validCaptionStyle(Map<String, Object?>? style) {
    if (style == null) {
      return false;
    }
    final fontFamily = style['fontFamily'];
    final fontScale = style['fontScale'];
    final positionY = style['positionY'];
    final outlineWidth = style['outlineWidth'];
    final shadow = style['shadow'];
    final bold = style['bold'];
    if (fontFamily is! String ||
        fontFamily.trim().isEmpty ||
        fontScale is! num ||
        positionY is! num ||
        outlineWidth is! num ||
        shadow is! num ||
        bold is! bool ||
        !fontScale.toDouble().isFinite ||
        !positionY.toDouble().isFinite ||
        !outlineWidth.toDouble().isFinite ||
        !shadow.toDouble().isFinite ||
        fontScale <= 0 ||
        positionY <= 0 ||
        positionY >= 1 ||
        outlineWidth < 0 ||
        shadow < 0) {
      return false;
    }
    for (final key in ['textColor', 'highlightColor', 'outlineColor']) {
      final color = style[key];
      if (color is! String || !_isHexColor(color)) {
        return false;
      }
    }
    final box = style['highlightBoxColor'];
    return box == null || (box is String && _isHexColor(box));
  }

  static bool _isHexColor(String value) {
    if (value.length != 7 || value.codeUnitAt(0) != 35) {
      return false;
    }
    for (final unit in value.codeUnits.skip(1)) {
      final isDigit = unit >= 48 && unit <= 57;
      final isUpperHex = unit >= 65 && unit <= 70;
      final isLowerHex = unit >= 97 && unit <= 102;
      if (!isDigit && !isUpperHex && !isLowerHex) {
        return false;
      }
    }
    return true;
  }
  static bool _validReframeShots(
    List<Map<String, Object?>> shots,
    int clipDurationMs,
    double sourceAspectRatio,
    double targetAspectRatio,
  ) {
    if (shots.isEmpty) return true;
    if (!sourceAspectRatio.isFinite ||
        sourceAspectRatio <= 0 ||
        !targetAspectRatio.isFinite ||
        targetAspectRatio <= 0) {
      return false;
    }
    var cursor = 0;
    for (final shot in shots) {
      final start = shot['startMs'];
      final end = shot['endMs'];
      final mode = shot['mode'];
      if (start is! int ||
          end is! int ||
          mode is! String ||
          start != cursor ||
          end <= start ||
          end > clipDurationMs ||
          (mode != 'fit' && mode != 'crop')) {
        return false;
      }
      final region = shot['region'];
      if (mode == 'fit') {
        if (region != null) return false;
      } else {
        if (region is! Map) return false;
        final x = region['x'];
        final y = region['y'];
        final width = region['width'];
        final height = region['height'];
        if (x is! num ||
            y is! num ||
            width is! num ||
            height is! num ||
            !x.toDouble().isFinite ||
            !y.toDouble().isFinite ||
            !width.toDouble().isFinite ||
            !height.toDouble().isFinite ||
            x < 0 ||
            y < 0 ||
            width <= 0 ||
            height <= 0 ||
            x + width > 1.0001 ||
            y + height > 1.0001 ||
            ((sourceAspectRatio * width.toDouble() / height.toDouble()) -
                        targetAspectRatio)
                    .abs() >
                targetAspectRatio * 0.03) {
          return false;
        }
      }
      cursor = end;
    }
    return cursor == clipDurationMs;
  }

  Future<bool> verifyExport({
    required String outputUri,
    required String sha256,
    required int sizeBytes,
    required int durationMs,
    required int width,
    required int height,
  }) async {
    if (outputUri.trim().isEmpty ||
        !ProcessingJobService.isSha256(sha256) ||
        sizeBytes < 2048 ||
        durationMs <= 0 ||
        width <= 0 ||
        height <= 0) {
      return false;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'verifyExport',
        <String, Object?>{
          'outputUri': outputUri,
          'sha256': sha256,
          'sizeBytes': sizeBytes,
          'durationMs': durationMs,
          'width': width,
          'height': height,
        },
      );
      return result?['valid'] == true &&
          result?['sha256'] == sha256 &&
          (result?['sizeBytes'] as num?)?.toInt() == sizeBytes &&
          (result?['durationMs'] as num?)?.toInt() == durationMs &&
          (result?['width'] as num?)?.toInt() == width &&
          (result?['height'] as num?)?.toInt() == height &&
          result?['hasVideo'] == true &&
          result?['fullyDecodeValidated'] == true &&
          ((result?['decodedVideoBuffers'] as num?)?.toInt() ?? 0) > 0 &&
          (!(result?['hasAudio'] == true) ||
              ((result?['decodedAudioBuffers'] as num?)?.toInt() ?? 0) > 0);
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openExport(String outputUri) =>
      _runExportAction('openExport', outputUri);

  Future<bool> shareExport(String outputUri) =>
      _runExportAction('shareExport', outputUri);

  Future<bool> deleteExport(String outputUri) =>
      _runExportAction('deleteExport', outputUri);

  Future<bool> _runExportAction(String method, String outputUri) async {
    final uri = Uri.tryParse(outputUri.trim());
    if (uri == null ||
        (uri.scheme != 'content' && uri.scheme != 'file') ||
        (uri.scheme == 'content' && uri.authority.isEmpty) ||
        (uri.scheme == 'file' && uri.path.isEmpty)) {
      throw const FormatException('Export URI is invalid or unsupported.');
    }
    return await _channel.invokeMethod<bool>(
          method,
          <String, Object?>{'outputUri': uri.toString()},
        ) ??
        false;
  }

  Future<void> cancelRender(String renderId) async {
    await _channel.invokeMethod<bool>(
      'cancelRender',
      <String, Object?>{'renderId': renderId},
    );
  }
}
);
    final itemPattern = RegExp(r'^[A-Za-z0-9_-]{3,120}    if (projectId.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'hasActiveBackgroundRender',
            <String, Object?>{'projectId': projectId},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Reads a render that WorkManager finished while the Flutter process was absent.
  /// The caller must persist the export record and stage checkpoint before acknowledging it.
  Future<VideoExportResult?> consumeCompletedRender({
    required String renderKey,
  }) async {
    if (!ProcessingJobService.isSha256(renderKey)) {
      throw const FormatException('The render fingerprint must be a SHA-256 value.');
    }
    final payload = await _channel.invokeMapMethod<String, dynamic>(
      'getCompletedRender',
      <String, Object?>{'renderKey': renderKey},
    );
    if (payload == null) return null;
    final renderId = payload['renderId'];
    final raw = payload['result'];
    if (renderId is! String || renderId.isEmpty || raw is! Map) {
      throw const FormatException('The durable render completion is malformed.');
    }
    return VideoExportResult.fromJson(
      renderId,
      Map<String, dynamic>.from(raw),
    );
  }

  /// Deletes the durable completion only after the caller has persisted its
  /// export record and stage checkpoint.
  Future<bool> acknowledgeCompletedRender({
    required String renderKey,
    required String sha256,
  }) async {
    if (!ProcessingJobService.isSha256(renderKey) ||
        !ProcessingJobService.isSha256(sha256)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'acknowledgeCompletedRender',
            <String, Object?>{'renderKey': renderKey, 'sha256': sha256},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static bool _validCaptionCues(List<Map<String, Object?>> cues, int clipDurationMs) {
    var previousStart = -1;
    for (final cue in cues) {
      final start = cue['startMs'];
      final end = cue['endMs'];
      final text = cue['text'];
      final rawWords = cue['words'];
      if (start is! int ||
          end is! int ||
          text is! String ||
          text.trim().isEmpty ||
          rawWords is! List ||
          start < 0 ||
          end <= start ||
          end > clipDurationMs ||
          start < previousStart) {
        return false;
      }
      previousStart = start;
      for (final rawWord in rawWords) {
        if (rawWord is! Map) {
          return false;
        }
        final wordText = rawWord['text'];
        final wordStart = rawWord['startMs'];
        final wordEnd = rawWord['endMs'];
        final textStart = rawWord['startOffset'];
        final textEnd = rawWord['endOffset'];
        if (wordText is! String ||
            wordText.isEmpty ||
            wordStart is! int ||
            wordEnd is! int ||
            textStart is! int ||
            textEnd is! int ||
            wordStart < start ||
            wordEnd <= wordStart ||
            wordEnd > end ||
            textStart < 0 ||
            textEnd <= textStart ||
            textEnd > text.length) {
          return false;
        }
        if (text.substring(textStart, textEnd) != wordText) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _validCaptionStyle(Map<String, Object?>? style) {
    if (style == null) {
      return false;
    }
    final fontFamily = style['fontFamily'];
    final fontScale = style['fontScale'];
    final positionY = style['positionY'];
    final outlineWidth = style['outlineWidth'];
    final shadow = style['shadow'];
    final bold = style['bold'];
    if (fontFamily is! String ||
        fontFamily.trim().isEmpty ||
        fontScale is! num ||
        positionY is! num ||
        outlineWidth is! num ||
        shadow is! num ||
        bold is! bool ||
        !fontScale.toDouble().isFinite ||
        !positionY.toDouble().isFinite ||
        !outlineWidth.toDouble().isFinite ||
        !shadow.toDouble().isFinite ||
        fontScale <= 0 ||
        positionY <= 0 ||
        positionY >= 1 ||
        outlineWidth < 0 ||
        shadow < 0) {
      return false;
    }
    for (final key in ['textColor', 'highlightColor', 'outlineColor']) {
      final color = style[key];
      if (color is! String || !_isHexColor(color)) {
        return false;
      }
    }
    final box = style['highlightBoxColor'];
    return box == null || (box is String && _isHexColor(box));
  }

  static bool _isHexColor(String value) {
    if (value.length != 7 || value.codeUnitAt(0) != 35) {
      return false;
    }
    for (final unit in value.codeUnits.skip(1)) {
      final isDigit = unit >= 48 && unit <= 57;
      final isUpperHex = unit >= 65 && unit <= 70;
      final isLowerHex = unit >= 97 && unit <= 102;
      if (!isDigit && !isUpperHex && !isLowerHex) {
        return false;
      }
    }
    return true;
  }
  static bool _validReframeShots(
    List<Map<String, Object?>> shots,
    int clipDurationMs,
    double sourceAspectRatio,
    double targetAspectRatio,
  ) {
    if (shots.isEmpty) return true;
    if (!sourceAspectRatio.isFinite ||
        sourceAspectRatio <= 0 ||
        !targetAspectRatio.isFinite ||
        targetAspectRatio <= 0) {
      return false;
    }
    var cursor = 0;
    for (final shot in shots) {
      final start = shot['startMs'];
      final end = shot['endMs'];
      final mode = shot['mode'];
      if (start is! int ||
          end is! int ||
          mode is! String ||
          start != cursor ||
          end <= start ||
          end > clipDurationMs ||
          (mode != 'fit' && mode != 'crop')) {
        return false;
      }
      final region = shot['region'];
      if (mode == 'fit') {
        if (region != null) return false;
      } else {
        if (region is! Map) return false;
        final x = region['x'];
        final y = region['y'];
        final width = region['width'];
        final height = region['height'];
        if (x is! num ||
            y is! num ||
            width is! num ||
            height is! num ||
            !x.toDouble().isFinite ||
            !y.toDouble().isFinite ||
            !width.toDouble().isFinite ||
            !height.toDouble().isFinite ||
            x < 0 ||
            y < 0 ||
            width <= 0 ||
            height <= 0 ||
            x + width > 1.0001 ||
            y + height > 1.0001 ||
            ((sourceAspectRatio * width.toDouble() / height.toDouble()) -
                        targetAspectRatio)
                    .abs() >
                targetAspectRatio * 0.03) {
          return false;
        }
      }
      cursor = end;
    }
    return cursor == clipDurationMs;
  }

  Future<bool> verifyExport({
    required String outputUri,
    required String sha256,
    required int sizeBytes,
    required int durationMs,
    required int width,
    required int height,
  }) async {
    if (outputUri.trim().isEmpty ||
        !ProcessingJobService.isSha256(sha256) ||
        sizeBytes < 2048 ||
        durationMs <= 0 ||
        width <= 0 ||
        height <= 0) {
      return false;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'verifyExport',
        <String, Object?>{
          'outputUri': outputUri,
          'sha256': sha256,
          'sizeBytes': sizeBytes,
          'durationMs': durationMs,
          'width': width,
          'height': height,
        },
      );
      return result?['valid'] == true &&
          result?['sha256'] == sha256 &&
          (result?['sizeBytes'] as num?)?.toInt() == sizeBytes &&
          (result?['durationMs'] as num?)?.toInt() == durationMs &&
          (result?['width'] as num?)?.toInt() == width &&
          (result?['height'] as num?)?.toInt() == height &&
          result?['hasVideo'] == true &&
          result?['fullyDecodeValidated'] == true &&
          ((result?['decodedVideoBuffers'] as num?)?.toInt() ?? 0) > 0 &&
          (!(result?['hasAudio'] == true) ||
              ((result?['decodedAudioBuffers'] as num?)?.toInt() ?? 0) > 0);
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openExport(String outputUri) =>
      _runExportAction('openExport', outputUri);

  Future<bool> shareExport(String outputUri) =>
      _runExportAction('shareExport', outputUri);

  Future<bool> deleteExport(String outputUri) =>
      _runExportAction('deleteExport', outputUri);

  Future<bool> _runExportAction(String method, String outputUri) async {
    final uri = Uri.tryParse(outputUri.trim());
    if (uri == null ||
        (uri.scheme != 'content' && uri.scheme != 'file') ||
        (uri.scheme == 'content' && uri.authority.isEmpty) ||
        (uri.scheme == 'file' && uri.path.isEmpty)) {
      throw const FormatException('Export URI is invalid or unsupported.');
    }
    return await _channel.invokeMethod<bool>(
          method,
          <String, Object?>{'outputUri': uri.toString()},
        ) ??
        false;
  }

  Future<void> cancelRender(String renderId) async {
    await _channel.invokeMethod<bool>(
      'cancelRender',
      <String, Object?>{'renderId': renderId},
    );
  }
}
);
    if (!projectPattern.hasMatch(projectId) ||
        !itemPattern.hasMatch(compositionId) ||
        tracks.isEmpty ||
        tracks.length > 16 ||
        sourceDurationMs <= 0 ||
        expectedDurationMs <= 0 ||
        expectedDurationMs > const Duration(hours: 6).inMilliseconds ||
        !aspectRatio.isFinite ||
        aspectRatio <= 0 ||
        aspectRatio > 4 ||
        outputPath.trim().isEmpty) {
      throw const FormatException('Composition identity, dimensions or output path are invalid.');
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
          !itemPattern.hasMatch(trackId) ||
          !trackIds.add(trackId) ||
          type is! String ||
          !const {'video', 'audio', 'overlay'}.contains(type) ||
          rawClips is! List ||
          rawClips.length > 500) {
        throw const FormatException('Composition track identity, type or clip list is invalid.');
      }
      if (rawClips.isEmpty) continue;
      if (type == 'video') hasMainVideo = true;

      final normalizedClips = <Map<String, Object?>>[];
      var previousTimelineEndMs = 0;
      final sortedClips = rawClips.toList()
        ..sort((left, right) {
          if (left is! Map || right is! Map) return 0;
          final leftStart = (left['timelineStartMs'] as num?)?.toInt() ?? -1;
          final rightStart = (right['timelineStartMs'] as num?)?.toInt() ?? -1;
          return leftStart.compareTo(rightStart);
        });
      for (final rawClip in sortedClips) {
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
            !itemPattern.hasMatch(itemId) ||
            !itemIds.add(itemId) ||
            candidateId is! String ||
            !itemPattern.hasMatch(candidateId) ||
            parsedUri == null ||
            !const {'content', 'file', 'http', 'https'}.contains(parsedUri.scheme) ||
            (parsedUri.scheme == 'content' && parsedUri.authority.isEmpty) ||
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
          throw const FormatException('A composition may contain at most 500 clips.');
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
    if (!hasMainVideo || totalClips == 0 || maximumTimelineEndMs != expectedDurationMs) {
      throw const FormatException(
        'A composition requires a non-empty main video track and a matching timeline duration.',
      );
    }

    final canonicalRenderInput = jsonEncode({
      'projectId': projectId,
      'compositionId': compositionId,
      'sourceDurationMs': sourceDurationMs,
      'expectedDurationMs': expectedDurationMs,
      'aspectRatio': aspectRatio,
      'tracks': normalizedTracks,
    });
    final stableRenderKey = renderKey ??
        sha256.convert(utf8.encode(canonicalRenderInput)).toString();
    if (!ProcessingJobService.isSha256(stableRenderKey)) {
      throw const FormatException('The composition fingerprint must be a SHA-256 value.');
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
          await cancelRender(renderId);
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
            throw const FormatException('Android completed without composition metadata.');
          }
          return VideoExportResult.fromJson(
            renderId,
            Map<String, dynamic>.from(raw),
          );
        }
        if (state == 'cancelled') throw const VideoExportCancelled();
        if (state == 'failed') {
          throw StateError(
            snapshot['error'] as String? ?? 'Android composition export failed.',
          );
        }
        if (state != 'running' && state != 'queued') {
          throw StateError('Unknown Android composition export status: $state');
        }
        await Future<void>.delayed(const Duration(milliseconds: 700));
      }
      await cancelRender(renderId);
      throw TimeoutException(
        'Composition export exceeded ${timeout.inMinutes} minutes.',
      );
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

  Future<bool> hasActiveBackgroundRender(String projectId) async {
    if (projectId.trim().isEmpty) return false;
    try {
      return await _channel.invokeMethod<bool>(
            'hasActiveBackgroundRender',
            <String, Object?>{'projectId': projectId},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  /// Reads a render that WorkManager finished while the Flutter process was absent.
  /// The caller must persist the export record and stage checkpoint before acknowledging it.
  Future<VideoExportResult?> consumeCompletedRender({
    required String renderKey,
  }) async {
    if (!ProcessingJobService.isSha256(renderKey)) {
      throw const FormatException('The render fingerprint must be a SHA-256 value.');
    }
    final payload = await _channel.invokeMapMethod<String, dynamic>(
      'getCompletedRender',
      <String, Object?>{'renderKey': renderKey},
    );
    if (payload == null) return null;
    final renderId = payload['renderId'];
    final raw = payload['result'];
    if (renderId is! String || renderId.isEmpty || raw is! Map) {
      throw const FormatException('The durable render completion is malformed.');
    }
    return VideoExportResult.fromJson(
      renderId,
      Map<String, dynamic>.from(raw),
    );
  }

  /// Deletes the durable completion only after the caller has persisted its
  /// export record and stage checkpoint.
  Future<bool> acknowledgeCompletedRender({
    required String renderKey,
    required String sha256,
  }) async {
    if (!ProcessingJobService.isSha256(renderKey) ||
        !ProcessingJobService.isSha256(sha256)) {
      return false;
    }
    try {
      return await _channel.invokeMethod<bool>(
            'acknowledgeCompletedRender',
            <String, Object?>{'renderKey': renderKey, 'sha256': sha256},
          ) ??
          false;
    } on PlatformException {
      return false;
    }
  }

  static bool _validCaptionCues(List<Map<String, Object?>> cues, int clipDurationMs) {
    var previousStart = -1;
    for (final cue in cues) {
      final start = cue['startMs'];
      final end = cue['endMs'];
      final text = cue['text'];
      final rawWords = cue['words'];
      if (start is! int ||
          end is! int ||
          text is! String ||
          text.trim().isEmpty ||
          rawWords is! List ||
          start < 0 ||
          end <= start ||
          end > clipDurationMs ||
          start < previousStart) {
        return false;
      }
      previousStart = start;
      for (final rawWord in rawWords) {
        if (rawWord is! Map) {
          return false;
        }
        final wordText = rawWord['text'];
        final wordStart = rawWord['startMs'];
        final wordEnd = rawWord['endMs'];
        final textStart = rawWord['startOffset'];
        final textEnd = rawWord['endOffset'];
        if (wordText is! String ||
            wordText.isEmpty ||
            wordStart is! int ||
            wordEnd is! int ||
            textStart is! int ||
            textEnd is! int ||
            wordStart < start ||
            wordEnd <= wordStart ||
            wordEnd > end ||
            textStart < 0 ||
            textEnd <= textStart ||
            textEnd > text.length) {
          return false;
        }
        if (text.substring(textStart, textEnd) != wordText) {
          return false;
        }
      }
    }
    return true;
  }

  static bool _validCaptionStyle(Map<String, Object?>? style) {
    if (style == null) {
      return false;
    }
    final fontFamily = style['fontFamily'];
    final fontScale = style['fontScale'];
    final positionY = style['positionY'];
    final outlineWidth = style['outlineWidth'];
    final shadow = style['shadow'];
    final bold = style['bold'];
    if (fontFamily is! String ||
        fontFamily.trim().isEmpty ||
        fontScale is! num ||
        positionY is! num ||
        outlineWidth is! num ||
        shadow is! num ||
        bold is! bool ||
        !fontScale.toDouble().isFinite ||
        !positionY.toDouble().isFinite ||
        !outlineWidth.toDouble().isFinite ||
        !shadow.toDouble().isFinite ||
        fontScale <= 0 ||
        positionY <= 0 ||
        positionY >= 1 ||
        outlineWidth < 0 ||
        shadow < 0) {
      return false;
    }
    for (final key in ['textColor', 'highlightColor', 'outlineColor']) {
      final color = style[key];
      if (color is! String || !_isHexColor(color)) {
        return false;
      }
    }
    final box = style['highlightBoxColor'];
    return box == null || (box is String && _isHexColor(box));
  }

  static bool _isHexColor(String value) {
    if (value.length != 7 || value.codeUnitAt(0) != 35) {
      return false;
    }
    for (final unit in value.codeUnits.skip(1)) {
      final isDigit = unit >= 48 && unit <= 57;
      final isUpperHex = unit >= 65 && unit <= 70;
      final isLowerHex = unit >= 97 && unit <= 102;
      if (!isDigit && !isUpperHex && !isLowerHex) {
        return false;
      }
    }
    return true;
  }
  static bool _validReframeShots(
    List<Map<String, Object?>> shots,
    int clipDurationMs,
    double sourceAspectRatio,
    double targetAspectRatio,
  ) {
    if (shots.isEmpty) return true;
    if (!sourceAspectRatio.isFinite ||
        sourceAspectRatio <= 0 ||
        !targetAspectRatio.isFinite ||
        targetAspectRatio <= 0) {
      return false;
    }
    var cursor = 0;
    for (final shot in shots) {
      final start = shot['startMs'];
      final end = shot['endMs'];
      final mode = shot['mode'];
      if (start is! int ||
          end is! int ||
          mode is! String ||
          start != cursor ||
          end <= start ||
          end > clipDurationMs ||
          (mode != 'fit' && mode != 'crop')) {
        return false;
      }
      final region = shot['region'];
      if (mode == 'fit') {
        if (region != null) return false;
      } else {
        if (region is! Map) return false;
        final x = region['x'];
        final y = region['y'];
        final width = region['width'];
        final height = region['height'];
        if (x is! num ||
            y is! num ||
            width is! num ||
            height is! num ||
            !x.toDouble().isFinite ||
            !y.toDouble().isFinite ||
            !width.toDouble().isFinite ||
            !height.toDouble().isFinite ||
            x < 0 ||
            y < 0 ||
            width <= 0 ||
            height <= 0 ||
            x + width > 1.0001 ||
            y + height > 1.0001 ||
            ((sourceAspectRatio * width.toDouble() / height.toDouble()) -
                        targetAspectRatio)
                    .abs() >
                targetAspectRatio * 0.03) {
          return false;
        }
      }
      cursor = end;
    }
    return cursor == clipDurationMs;
  }

  Future<bool> verifyExport({
    required String outputUri,
    required String sha256,
    required int sizeBytes,
    required int durationMs,
    required int width,
    required int height,
  }) async {
    if (outputUri.trim().isEmpty ||
        !ProcessingJobService.isSha256(sha256) ||
        sizeBytes < 2048 ||
        durationMs <= 0 ||
        width <= 0 ||
        height <= 0) {
      return false;
    }
    try {
      final result = await _channel.invokeMapMethod<String, dynamic>(
        'verifyExport',
        <String, Object?>{
          'outputUri': outputUri,
          'sha256': sha256,
          'sizeBytes': sizeBytes,
          'durationMs': durationMs,
          'width': width,
          'height': height,
        },
      );
      return result?['valid'] == true &&
          result?['sha256'] == sha256 &&
          (result?['sizeBytes'] as num?)?.toInt() == sizeBytes &&
          (result?['durationMs'] as num?)?.toInt() == durationMs &&
          (result?['width'] as num?)?.toInt() == width &&
          (result?['height'] as num?)?.toInt() == height &&
          result?['hasVideo'] == true &&
          result?['fullyDecodeValidated'] == true &&
          ((result?['decodedVideoBuffers'] as num?)?.toInt() ?? 0) > 0 &&
          (!(result?['hasAudio'] == true) ||
              ((result?['decodedAudioBuffers'] as num?)?.toInt() ?? 0) > 0);
    } on PlatformException {
      return false;
    }
  }

  Future<bool> openExport(String outputUri) =>
      _runExportAction('openExport', outputUri);

  Future<bool> shareExport(String outputUri) =>
      _runExportAction('shareExport', outputUri);

  Future<bool> deleteExport(String outputUri) =>
      _runExportAction('deleteExport', outputUri);

  Future<bool> _runExportAction(String method, String outputUri) async {
    final uri = Uri.tryParse(outputUri.trim());
    if (uri == null ||
        (uri.scheme != 'content' && uri.scheme != 'file') ||
        (uri.scheme == 'content' && uri.authority.isEmpty) ||
        (uri.scheme == 'file' && uri.path.isEmpty)) {
      throw const FormatException('Export URI is invalid or unsupported.');
    }
    return await _channel.invokeMethod<bool>(
          method,
          <String, Object?>{'outputUri': uri.toString()},
        ) ??
        false;
  }

  Future<void> cancelRender(String renderId) async {
    await _channel.invokeMethod<bool>(
      'cancelRender',
      <String, Object?>{'renderId': renderId},
    );
  }
}
