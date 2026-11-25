import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:cutawan_mobile/domain/clip_edit_overrides.dart';
import 'package:cutawan_mobile/services/android_filmstrip_service.dart';
import 'package:cutawan_mobile/services/video_export_service.dart';
import 'package:cutawan_mobile/widgets/clip_preview_viewport.dart';

const _clipDurationMs = 2000;
const _sourceLandscape = 'assets/testdata/clip-preview-grid.png';
const _videoLandscape = 'assets/testdata/clip-preview-grid.mp4';
const _sourcePortrait = 'assets/testdata/clip-preview-grid-portrait.png';
const _videoPortrait = 'assets/testdata/clip-preview-grid-portrait.mp4';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Clip Editor preview/export parity matrix covers crop axes, keyframes, fit and fades',
    (tester) async {
      final support = await getApplicationSupportDirectory();
      final landscapeVideo = await _copyAsset(
        _videoLandscape,
        support,
        'clip-preview-parity-landscape.mp4',
      );
      final portraitVideo = await _copyAsset(
        _videoPortrait,
        support,
        'clip-preview-parity-portrait.mp4',
      );
      final images = <String, ui.Image>{};

      Future<ui.Image> imageFor(String assetPath) async {
        final cached = images[assetPath];
        if (cached != null) return cached;
        final data = await rootBundle.load(assetPath);
        final codec = await ui.instantiateImageCodec(
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        );
        try {
          final decoded = (await codec.getNextFrame()).image;
          images[assetPath] = decoded;
          return decoded;
        } finally {
          codec.dispose();
        }
      }

      final cases = <_ParityCase>[
        _ParityCase(
          id: 'manual-left-portrait',
          sourceVideo: landscapeVideo,
          sourceImage: _sourceLandscape,
          sourceAspectRatio: 16 / 9,
          targetAspectRatio: 9 / 16,
          overrides: const ClipEditOverrides(
            clipId: 'parity_manual_left',
            framingMode: ClipFramingMode.manualFocus,
            focusX: 0.08,
            focusY: 0.5,
          ),
        ),
        _ParityCase(
          id: 'manual-right-portrait',
          sourceVideo: landscapeVideo,
          sourceImage: _sourceLandscape,
          sourceAspectRatio: 16 / 9,
          targetAspectRatio: 9 / 16,
          overrides: const ClipEditOverrides(
            clipId: 'parity_manual_right',
            framingMode: ClipFramingMode.manualFocus,
            focusX: 0.92,
            focusY: 0.5,
          ),
        ),
        _ParityCase(
          id: 'automatic-left-portrait',
          sourceVideo: landscapeVideo,
          sourceImage: _sourceLandscape,
          sourceAspectRatio: 16 / 9,
          targetAspectRatio: 9 / 16,
          explicitShots: [
            {
              'startMs': 0,
              'endMs': _clipDurationMs,
              'mode': 'crop',
              'region': {
                'x': 0.0,
                'y': 0.0,
                'width': (9 / 16) / (16 / 9),
                'height': 1.0,
              },
            },
          ],
        ),
        _ParityCase(
          id: 'manual-top-landscape',
          sourceVideo: portraitVideo,
          sourceImage: _sourcePortrait,
          sourceAspectRatio: 9 / 16,
          targetAspectRatio: 16 / 9,
          overrides: const ClipEditOverrides(
            clipId: 'parity_manual_top',
            framingMode: ClipFramingMode.manualFocus,
            focusX: 0.5,
            focusY: 0.08,
          ),
        ),
        _ParityCase(
          id: 'manual-bottom-landscape',
          sourceVideo: portraitVideo,
          sourceImage: _sourcePortrait,
          sourceAspectRatio: 9 / 16,
          targetAspectRatio: 16 / 9,
          overrides: const ClipEditOverrides(
            clipId: 'parity_manual_bottom',
            framingMode: ClipFramingMode.manualFocus,
            focusX: 0.5,
            focusY: 0.92,
          ),
        ),
        _ParityCase(
          id: 'keyframe-vertical-pan',
          sourceVideo: portraitVideo,
          sourceImage: _sourcePortrait,
          sourceAspectRatio: 9 / 16,
          targetAspectRatio: 16 / 9,
          overrides: const ClipEditOverrides(
            clipId: 'parity_keyframe_pan',
            framingMode: ClipFramingMode.manualFocus,
            focusKeyframes: [
              ClipFocusKeyframe(
                timestampMs: 0,
                focusX: 0.5,
                focusY: 0.08,
              ),
              ClipFocusKeyframe(
                timestampMs: _clipDurationMs,
                focusX: 0.5,
                focusY: 0.92,
              ),
            ],
          ),
        ),
        _ParityCase(
          id: 'full-frame-fit',
          sourceVideo: portraitVideo,
          sourceImage: _sourcePortrait,
          sourceAspectRatio: 9 / 16,
          targetAspectRatio: 16 / 9,
          overrides: const ClipEditOverrides(
            clipId: 'parity_full_frame',
            framingMode: ClipFramingMode.fullFrame,
          ),
          fit: BoxFit.contain,
        ),
        _ParityCase(
          id: 'manual-crop-fade-in-out',
          sourceVideo: landscapeVideo,
          sourceImage: _sourceLandscape,
          sourceAspectRatio: 16 / 9,
          targetAspectRatio: 9 / 16,
          overrides: const ClipEditOverrides(
            clipId: 'parity_crop_fade',
            framingMode: ClipFramingMode.manualFocus,
            focusX: 0.9,
            focusY: 0.5,
            fadeInMs: 700,
            fadeOutMs: 700,
          ),
        ),
      ];

      try {
        for (final scenario in cases) {
          final previewSource = await imageFor(scenario.sourceImage);
          final shots = scenario.explicitShots ??
              scenario.overrides!.toExportShots(
                durationMs: _clipDurationMs,
                sourceAspectRatio: scenario.sourceAspectRatio,
                targetAspectRatio: scenario.targetAspectRatio,
              );
          final fit = scenario.fit ??
              (shots.any((shot) => shot['mode'] == 'fit')
                  ? BoxFit.contain
                  : BoxFit.cover);
          final outputFile = File(
            '${support.path}${Platform.pathSeparator}'
            'clip-preview-parity-${scenario.id}-output.mp4',
          );
          if (outputFile.existsSync()) await outputFile.delete();

          final exportService = VideoExportService();
          VideoExportResult? export;
          final exportedImages = <ui.Image>[];
          try {
            debugPrint('CLIP_PARITY_MATRIX_CASE_STARTED id=${scenario.id}');
            export = await exportService.renderClip(
              clipId: 'parity_${scenario.id}',
              projectId: 'parity_matrix',
              sourceUri: Uri.file(scenario.sourceVideo.path).toString(),
              startMs: 0,
              endMs: _clipDurationMs,
              aspectRatio: scenario.targetAspectRatio,
              sourceAspectRatio: scenario.sourceAspectRatio,
              reframeShots: shots,
              fadeInMs: scenario.overrides?.fadeInMs ?? 0,
              fadeOutMs: scenario.overrides?.fadeOutMs ?? 0,
              outputPath: outputFile.path,
              timeout: const Duration(minutes: 6),
              onStarted: (id) => debugPrint(
                'CLIP_PARITY_MATRIX_RENDER_STARTED id=${scenario.id} render=$id',
              ),
              onStatus: (status, progress) => debugPrint(
                'CLIP_PARITY_MATRIX_STATUS id=${scenario.id} '
                'status=$status progress=${(progress * 100).toStringAsFixed(0)}%',
              ),
            );
            expect(export.validated, isTrue, reason: scenario.id);
            expect(export.fullyDecodeValidated, isTrue, reason: scenario.id);

            final frames = await const AndroidFilmstripService().generate(
              sourceUri: export.outputUri,
              startMs: 200,
              endMs: 1900,
              sampleCount: 3,
            );
            expect(frames, hasLength(3), reason: scenario.id);

            for (final frame in frames) {
              expect(
                frame.width / frame.height,
                closeTo(scenario.targetAspectRatio, 0.025),
                reason: '${scenario.id}: decoded display aspect ratio',
              );
              final outputCodec = await ui.instantiateImageCodec(
                frame.imageBytes,
                targetWidth: frame.width,
                targetHeight: frame.height,
              );
              ui.Image exportedImage;
              try {
                exportedImage = (await outputCodec.getNextFrame()).image;
              } finally {
                outputCodec.dispose();
              }
              exportedImages.add(exportedImage);

              final region = _regionAt(shots, frame.timestampMs);
              final alignment = region == null
                  ? Alignment.center
                  : _alignmentFor(region);
              final fadeOpacity = ClipEditOverrides.blackFadeOpacity(
                localPositionMs: frame.timestampMs,
                durationMs: _clipDurationMs,
                fadeInMs: scenario.overrides?.fadeInMs ?? 0,
                fadeOutMs: scenario.overrides?.fadeOutMs ?? 0,
              );
              final previewImage = await _capturePreview(
                tester: tester,
                sourceImage: previewSource,
                width: frame.width,
                height: frame.height,
                fit: fit,
                alignment: alignment,
                fadeOpacity: fadeOpacity,
              );
              try {
                final metrics = await _compareInteriorPixels(
                  preview: previewImage,
                  exported: exportedImage,
                );
                debugPrint(
                  'CLIP_PREVIEW_EXPORT_PIXEL_PARITY_MATRIX '
                  'case=${scenario.id} timestampMs=${frame.timestampMs} '
                  'mae=${metrics.meanAbsoluteError.toStringAsFixed(2)} '
                  'worstPatch=${metrics.worstPatchMean.toStringAsFixed(2)} '
                  'size=${frame.width}x${frame.height} '
                  'fade=${fadeOpacity.toStringAsFixed(2)}',
                );
                expect(
                  metrics.meanAbsoluteError,
                  lessThan(24),
                  reason: '${scenario.id} at ${frame.timestampMs}ms: preview/export MAE',
                );
                expect(
                  metrics.worstPatchMean,
                  lessThan(48),
                  reason: '${scenario.id} at ${frame.timestampMs}ms: worst crop patch',
                );
              } finally {
                previewImage.dispose();
              }
            }
            debugPrint('CLIP_PARITY_MATRIX_CASE_PASSED id=${scenario.id}');
          } finally {
            await tester.binding.setSurfaceSize(null);
            for (final image in exportedImages) {
              image.dispose();
            }
            if (export != null) {
              try {
                await exportService.deleteExport(export.outputUri);
              } catch (_) {
                // Keep the parity failure visible; export cleanup is best effort.
              }
            }
            if (outputFile.existsSync()) await outputFile.delete();
          }
        }
      } finally {
        await tester.binding.setSurfaceSize(null);
        for (final image in images.values) {
          image.dispose();
        }
        if (landscapeVideo.existsSync()) await landscapeVideo.delete();
        if (portraitVideo.existsSync()) await portraitVideo.delete();
      }
    },
  );
}

class _ParityCase {
  const _ParityCase({
    required this.id,
    required this.sourceVideo,
    required this.sourceImage,
    required this.sourceAspectRatio,
    required this.targetAspectRatio,
    this.overrides,
    this.explicitShots,
    this.fit,
  });

  final String id;
  final File sourceVideo;
  final String sourceImage;
  final double sourceAspectRatio;
  final double targetAspectRatio;
  final ClipEditOverrides? overrides;
  final List<Map<String, Object?>>? explicitShots;
  final BoxFit? fit;
}

class _PixelMetrics {
  const _PixelMetrics({
    required this.meanAbsoluteError,
    required this.worstPatchMean,
  });

  final double meanAbsoluteError;
  final double worstPatchMean;
}

Future<File> _copyAsset(
  String assetPath,
  Directory directory,
  String fileName,
) async {
  final data = await rootBundle.load(assetPath);
  final file = File(
    '${directory.path}${Platform.pathSeparator}$fileName',
  );
  await file.writeAsBytes(
    data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
    flush: true,
  );
  return file;
}

Map<String, double>? _regionAt(
  List<Map<String, Object?>> shots,
  int timestampMs,
) {
  if (shots.isEmpty) return null;
  final shot = shots.firstWhere(
    (item) {
      final start = item['startMs']! as int;
      final end = item['endMs']! as int;
      return timestampMs >= start && timestampMs < end;
    },
    orElse: () => shots.last,
  );
  if (shot['mode'] == 'fit') return null;
  final start = Map<String, double>.from(
    (shot['region']! as Map).map(
      (key, value) => MapEntry(key as String, (value as num).toDouble()),
    ),
  );
  final rawEnd = shot['regionEnd'];
  if (rawEnd is! Map) return start;
  final end = Map<String, double>.from(
    rawEnd.map(
      (key, value) => MapEntry(key as String, (value as num).toDouble()),
    ),
  );
  final startMs = shot['startMs']! as int;
  final endMs = shot['endMs']! as int;
  final progress = ((timestampMs - startMs) / (endMs - startMs))
      .clamp(0.0, 1.0)
      .toDouble();
  return {
    'x': start['x']! + (end['x']! - start['x']!) * progress,
    'y': start['y']! + (end['y']! - start['y']!) * progress,
    'width': start['width']! + (end['width']! - start['width']!) * progress,
    'height': start['height']! + (end['height']! - start['height']!) * progress,
  };
}

Alignment _alignmentFor(Map<String, double> region) {
  final alignment = ClipEditOverrides.previewAlignmentForCropRegion(
    x: region['x']!,
    y: region['y']!,
    width: region['width']!,
    height: region['height']!,
  );
  return Alignment(alignment['x']!, alignment['y']!);
}

Future<ui.Image> _capturePreview({
  required WidgetTester tester,
  required ui.Image sourceImage,
  required int width,
  required int height,
  required BoxFit fit,
  required Alignment alignment,
  required double fadeOpacity,
}) async {
  final key = GlobalKey();
  await tester.binding.setSurfaceSize(
    Size(width.toDouble(), height.toDouble()),
  );
  await tester.pumpWidget(
    MaterialApp(
      home: Scaffold(
        backgroundColor: Colors.black,
        body: Center(
          child: RepaintBoundary(
            key: key,
            child: SizedBox(
              width: width.toDouble(),
              height: height.toDouble(),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  ClipPreviewViewport(
                    fit: fit,
                    alignment: alignment,
                    child: SizedBox(
                      width: 320,
                      height: 180,
                      child: RawImage(
                        image: sourceImage,
                        fit: BoxFit.fill,
                      ),
                    ),
                  ),
                  if (fadeOpacity > 0)
                    Positioned.fill(
                      child: ColoredBox(
                        color: Colors.black.withValues(alpha: fadeOpacity),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  final boundary = key.currentContext!.findRenderObject()
      as RenderRepaintBoundary;
  return boundary.toImage(pixelRatio: 1);
}

Future<_PixelMetrics> _compareInteriorPixels({
  required ui.Image preview,
  required ui.Image exported,
}) async {
  if (preview.width != exported.width || preview.height != exported.height) {
    throw StateError('Preview/export frame sizes differ.');
  }
  final previewData = await preview.toByteData(format: ui.ImageByteFormat.rawRgba);
  final outputData = await exported.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (previewData == null || outputData == null) {
    throw StateError('Could not read preview/export RGBA pixels.');
  }
  final previewBytes = Uint8List.fromList(
    previewData.buffer.asUint8List(
      previewData.offsetInBytes,
      previewData.lengthInBytes,
    ),
  );
  final outputBytes = Uint8List.fromList(
    outputData.buffer.asUint8List(
      outputData.offsetInBytes,
      outputData.lengthInBytes,
    ),
  );

  var totalDifference = 0;
  var comparedChannels = 0;
  var worstPatchMean = 0.0;
  const sampleX = [0.13, 0.37, 0.63, 0.87];
  const sampleY = [0.16, 0.47, 0.82];
  for (final yRatio in sampleY) {
    for (final xRatio in sampleX) {
      final centerX = (xRatio * preview.width)
          .round()
          .clamp(3, preview.width - 4)
          .toInt();
      final centerY = (yRatio * preview.height)
          .round()
          .clamp(3, preview.height - 4)
          .toInt();
      var patchDifference = 0;
      var patchChannels = 0;
      for (var dy = -2; dy <= 2; dy++) {
        for (var dx = -2; dx <= 2; dx++) {
          final index = ((centerY + dy) * preview.width + centerX + dx) * 4;
          for (var channel = 0; channel < 3; channel++) {
            patchDifference +=
                (previewBytes[index + channel] - outputBytes[index + channel])
                    .abs();
            patchChannels++;
          }
        }
      }
      final patchMean = patchDifference / patchChannels;
      if (patchMean > worstPatchMean) worstPatchMean = patchMean;
      totalDifference += patchDifference;
      comparedChannels += patchChannels;
    }
  }
  return _PixelMetrics(
    meanAbsoluteError: totalDifference / comparedChannels,
    worstPatchMean: worstPatchMean,
  );
}
