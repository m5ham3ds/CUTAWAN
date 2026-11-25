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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Clip Editor preview crop matches Media3-exported frame pixels',
    (tester) async {
      debugPrint('CLIP_PREVIEW_PARITY_TEST_STARTED');
      final supportDirectory = await getApplicationSupportDirectory();
      debugPrint('CLIP_PREVIEW_PARITY_SUPPORT_DIRECTORY_READY');
      final sourceFile = File(
        '${supportDirectory.path}${Platform.pathSeparator}clip-preview-parity-source.mp4',
      );
      final temporaryOutput = File(
        '${supportDirectory.path}${Platform.pathSeparator}clip-preview-parity-output.mp4',
      );
      final sourceAsset = await rootBundle.load('assets/testdata/clip-preview-grid.mp4');
      await sourceFile.writeAsBytes(
        sourceAsset.buffer.asUint8List(
          sourceAsset.offsetInBytes,
          sourceAsset.lengthInBytes,
        ),
        flush: true,
      );
      if (temporaryOutput.existsSync()) await temporaryOutput.delete();

      final exportService = VideoExportService();
      VideoExportResult? export;
      ui.Image? previewImage;
      ui.Image? exportedImage;
      try {
        const sourceAspectRatio = 16 / 9;
        const targetAspectRatio = 9 / 16;
        const startMs = 0;
        const endMs = 2000;
        const overrides = ClipEditOverrides(
          clipId: 'parity_clip',
          framingMode: ClipFramingMode.manualFocus,
          focusX: 0.68,
          focusY: 0.5,
        );
        final shots = overrides.toExportShots(
          durationMs: endMs - startMs,
          clipStartMs: startMs,
          sourceAspectRatio: sourceAspectRatio,
          targetAspectRatio: targetAspectRatio,
        );
        expect(shots, hasLength(1));
        final region = Map<String, Object?>.from(shots.single['region']! as Map);
        final alignment = ClipEditOverrides.previewAlignmentForCropRegion(
          x: (region['x']! as num).toDouble(),
          y: (region['y']! as num).toDouble(),
          width: (region['width']! as num).toDouble(),
          height: (region['height']! as num).toDouble(),
        );

        debugPrint('CLIP_PREVIEW_PARITY_RENDER_REQUESTED');
        String? lastRenderStatus;
        double? lastRenderProgress;
        export = await exportService.renderClip(
          clipId: 'parity_clip',
          projectId: 'parity_project',
          sourceUri: Uri.file(sourceFile.path).toString(),
          startMs: startMs,
          endMs: endMs,
          aspectRatio: targetAspectRatio,
          sourceAspectRatio: sourceAspectRatio,
          reframeShots: shots,
          outputPath: temporaryOutput.path,
          timeout: const Duration(minutes: 6),
          onStarted: (renderId) => debugPrint('CLIP_PREVIEW_PARITY_RENDER_STARTED id=$renderId'),
          onStatus: (status, progress) {
            if (status != lastRenderStatus || progress != lastRenderProgress) {
              debugPrint('CLIP_PREVIEW_PARITY_RENDER_STATUS status=$status progress=${(progress * 100).toStringAsFixed(0)}%');
              lastRenderStatus = status;
              lastRenderProgress = progress;
            }
          },
        );
        debugPrint('CLIP_PREVIEW_PARITY_RENDER_COMPLETED uri=${export.outputUri}');
        expect(export.validated, isTrue);
        expect(export.fullyDecodeValidated, isTrue);
        expect(export.width, greaterThan(0));
        expect(export.height, greaterThan(0));

        // Transformer may store portrait output in landscape-coded dimensions
        // for encoder compatibility and signal display orientation separately.
        // Measure the decoded frame returned by Android, not the raw track size.
        debugPrint('CLIP_PREVIEW_PARITY_EXTRACTING_EXPORTED_FRAMES');
        final filmstrip = await const AndroidFilmstripService().generate(
          sourceUri: export.outputUri,
          startMs: 400,
          endMs: 1600,
          sampleCount: 3,
        );
        expect(filmstrip, hasLength(3));
        final referenceFrame = filmstrip[1];
        debugPrint(
          'CLIP_PREVIEW_PARITY_DIMENSIONS '
          'coded=${export.width}x${export.height} '
          'display=${referenceFrame.width}x${referenceFrame.height}',
        );
        expect(
          referenceFrame.width / referenceFrame.height,
          closeTo(targetAspectRatio, 0.02),
          reason: 'The decoded exported frame must use the requested display aspect ratio.',
        );
        final outputCodec = await ui.instantiateImageCodec(
          referenceFrame.imageBytes,
          targetWidth: referenceFrame.width,
          targetHeight: referenceFrame.height,
        );
        try {
          exportedImage = (await outputCodec.getNextFrame()).image;
        } finally {
          outputCodec.dispose();
        }
        expect(exportedImage.width, referenceFrame.width);
        expect(exportedImage.height, referenceFrame.height);

        final previewKey = GlobalKey();
        await tester.binding.setSurfaceSize(
          Size(referenceFrame.width.toDouble(), referenceFrame.height.toDouble()),
        );
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Center(
                child: RepaintBoundary(
                  key: previewKey,
                  child: SizedBox(
                    width: referenceFrame.width.toDouble(),
                    height: referenceFrame.height.toDouble(),
                    child: ClipPreviewViewport(
                      fit: BoxFit.cover,
                      alignment: Alignment(alignment['x']!, alignment['y']!),
                      child: const SizedBox(
                        width: 320,
                        height: 180,
                        child: Image(
                          image: AssetImage('assets/testdata/clip-preview-grid.png'),
                          fit: BoxFit.fill,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final boundary = previewKey.currentContext!.findRenderObject()
            as RenderRepaintBoundary;
        previewImage = await boundary.toImage(pixelRatio: 1);
        expect(previewImage.width, referenceFrame.width);
        expect(previewImage.height, referenceFrame.height);

        final previewData = await previewImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        final outputData = await exportedImage.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(previewData, isNotNull);
        expect(outputData, isNotNull);
        final previewBytes = Uint8List.fromList(
          previewData!.buffer.asUint8List(
            previewData.offsetInBytes,
            previewData.lengthInBytes,
          ),
        );
        final outputBytes = Uint8List.fromList(
          outputData!.buffer.asUint8List(
            outputData.offsetInBytes,
            outputData.lengthInBytes,
          ),
        );

        // Compare interior color patches; H.264/YUV and JPEG add bounded noise,
        // while a crop-position mismatch produces large patch-wide deltas.
        const sampleX = [0.13, 0.37, 0.63, 0.87];
        const sampleY = [0.16, 0.47, 0.82];
        var totalDifference = 0;
        var comparedChannels = 0;
        var worstPatchMean = 0.0;
        for (final yRatio in sampleY) {
          for (final xRatio in sampleX) {
            final centerX = (xRatio * referenceFrame.width)
                .round()
                .clamp(3, referenceFrame.width - 4)
                .toInt();
            final centerY = (yRatio * referenceFrame.height)
                .round()
                .clamp(3, referenceFrame.height - 4)
                .toInt();
            var patchDifference = 0;
            var patchChannels = 0;
            for (var dy = -2; dy <= 2; dy++) {
              for (var dx = -2; dx <= 2; dx++) {
                final index = (
                  (centerY + dy) * referenceFrame.width + centerX + dx
                ) * 4;
                for (var channel = 0; channel < 3; channel++) {
                  patchDifference += (
                    previewBytes[index + channel] -
                    outputBytes[index + channel]
                  ).abs();
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
        final meanAbsoluteError = totalDifference / comparedChannels;
        debugPrint(
          'CLIP_PREVIEW_EXPORT_PIXEL_PARITY '
          'mae=${meanAbsoluteError.toStringAsFixed(2)} '
          'worstPatch=${worstPatchMean.toStringAsFixed(2)} '
          'size=${referenceFrame.width}x${referenceFrame.height}',
        );
        expect(
          meanAbsoluteError,
          lessThan(24),
          reason: 'Preview and Media3 export should agree at matched interior pixels.',
        );
        expect(
          worstPatchMean,
          lessThan(48),
          reason: 'No sampled crop region should show a large positional/color mismatch.',
        );
      } finally {
        await tester.binding.setSurfaceSize(null);
        previewImage?.dispose();
        exportedImage?.dispose();
        if (export != null) {
          try {
            await exportService.deleteExport(export.outputUri);
          } catch (_) {
            // Preserve rendering errors; cleanup is best effort.
          }
        }
        if (sourceFile.existsSync()) await sourceFile.delete();
        if (temporaryOutput.existsSync()) await temporaryOutput.delete();
      }
    },
  );
}
