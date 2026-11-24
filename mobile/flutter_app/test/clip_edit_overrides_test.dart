import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_edit_overrides.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';

void main() {
  test('automatic mode leaves the analyzed reframe timeline untouched', () {
    const value = ClipEditOverrides(clipId: 'clip_001');
    expect(
      value.toExportShots(
        durationMs: 4000,
        sourceAspectRatio: 16 / 9,
        targetAspectRatio: 9 / 16,
      ),
      isEmpty,
    );
  });

  test('full-frame override covers the whole candidate without cropping', () {
    const value = ClipEditOverrides(
      clipId: 'clip_001',
      framingMode: ClipFramingMode.fullFrame,
    );
    final shots = value.toExportShots(
      durationMs: 4200,
      sourceAspectRatio: 16 / 9,
      targetAspectRatio: 9 / 16,
    );
    expect(shots, hasLength(1));
    expect(shots.single['startMs'], 0);
    expect(shots.single['endMs'], 4200);
    expect(shots.single['mode'], 'fit');
    expect(shots.single['region'], isNull);
  });

  test('manual crop calculates a valid target-ratio region at frame edges', () {
    const value = ClipEditOverrides(
      clipId: 'clip_001',
      framingMode: ClipFramingMode.manualFocus,
      focusX: 1,
      focusY: 0.5,
    );
    final shot = value.toExportShots(
      durationMs: 5000,
      sourceAspectRatio: 16 / 9,
      targetAspectRatio: 9 / 16,
    ).single;
    final region = Map<String, Object?>.from(shot['region']! as Map);
    final x = region['x']! as double;
    final y = region['y']! as double;
    final width = region['width']! as double;
    final height = region['height']! as double;
    expect(x, greaterThan(0));
    expect(x + width, closeTo(1, 0.000001));
    expect(y, 0);
    expect(height, 1);
    expect((16 / 9) * width / height, closeTo(9 / 16, 0.000001));
  });

  test('manual focus keyframes export smooth contiguous regions using source time', () {
    final value = ClipEditOverrides(
      clipId: 'clip_001',
      framingMode: ClipFramingMode.manualFocus,
      focusKeyframes: const [
        ClipFocusKeyframe(timestampMs: 10000, focusX: 0.2, focusY: 0.4),
        ClipFocusKeyframe(timestampMs: 13000, focusX: 0.8, focusY: 0.6),
        ClipFocusKeyframe(timestampMs: 16000, focusX: 0.5, focusY: 0.3),
      ],
    );
    final shots = value.toExportShots(
      durationMs: 6000,
      clipStartMs: 10000,
      sourceAspectRatio: 16 / 9,
      targetAspectRatio: 9 / 16,
    );

    expect(shots, hasLength(2));
    expect(shots[0]['startMs'], 0);
    expect(shots[0]['endMs'], 3000);
    expect(shots[1]['startMs'], 3000);
    expect(shots[1]['endMs'], 6000);
    final firstStart = Map<String, double>.from(shots[0]['region']! as Map);
    final firstEnd = Map<String, double>.from(shots[0]['regionEnd']! as Map);
    final secondStart = Map<String, double>.from(shots[1]['region']! as Map);
    final secondEnd = Map<String, double>.from(shots[1]['regionEnd']! as Map);
    expect(firstStart['x'], lessThan(firstEnd['x']!));
    expect(firstEnd['x'], closeTo(secondStart['x']!, 0.000001));
    expect(secondEnd['x'], lessThan(secondStart['x']!));
    expect(firstStart['width'], firstEnd['width']);
    expect(firstStart['height'], firstEnd['height']);
  });

  test('manual focus keyframes interpolate across a trim that excludes the first key', () {
    const value = ClipEditOverrides(
      clipId: 'clip_001',
      framingMode: ClipFramingMode.manualFocus,
      focusKeyframes: [
        ClipFocusKeyframe(timestampMs: 8000, focusX: 0.1, focusY: 0.5),
        ClipFocusKeyframe(timestampMs: 12000, focusX: 0.9, focusY: 0.5),
      ],
    );
    final shot = value.toExportShots(
      durationMs: 4000,
      clipStartMs: 10000,
      sourceAspectRatio: 16 / 9,
      targetAspectRatio: 9 / 16,
    ).single;
    final start = Map<String, double>.from(shot['region']! as Map);
    final end = Map<String, double>.from(shot['regionEnd']! as Map);
    expect(start['x'], lessThan(end['x']!));
  });

  test('schema 1 static overrides migrate without losing their focus point', () {
    final migrated = ClipEditOverrides.fromJson({
      'schemaVersion': 1,
      'clipId': 'clip_001',
      'framingMode': 'manualFocus',
      'focusX': 0.27,
      'focusY': 0.61,
    });
    expect(migrated.focusX, 0.27);
    expect(migrated.focusY, 0.61);
    expect(migrated.focusKeyframes, isEmpty);
    expect(
      migrated.toJson()['schemaVersion'],
      ClipEditOverrides.currentSchemaVersion,
    );
  });

  test('manual focus keyframes round-trip and reject duplicate timestamps', () {
    const original = ClipEditOverrides(
      clipId: 'clip_001',
      framingMode: ClipFramingMode.manualFocus,
      focusKeyframes: [
        ClipFocusKeyframe(timestampMs: 1000, focusX: 0.2, focusY: 0.3),
        ClipFocusKeyframe(timestampMs: 4000, focusX: 0.8, focusY: 0.7),
      ],
    );
    final restored = ClipEditOverrides.fromJson(
      Map<String, dynamic>.from(original.toJson()),
    );
    expect(restored.focusKeyframes.length, 2);
    expect(restored.focusKeyframes.last.timestampMs, 4000);
    expect(restored.focusKeyframes.last.focusX, 0.8);
    expect(
      () => const ClipEditOverrides(
        clipId: 'clip_001',
        framingMode: ClipFramingMode.manualFocus,
        focusKeyframes: [
          ClipFocusKeyframe(timestampMs: 1000, focusX: 0.2, focusY: 0.3),
          ClipFocusKeyframe(timestampMs: 1000, focusX: 0.8, focusY: 0.7),
        ],
      ).validate(),
      throwsFormatException,
    );
  });

  test('clip overrides round-trip and reject invalid focus coordinates', () {
    const value = ClipEditOverrides(
      clipId: 'clip_001',
      framingMode: ClipFramingMode.manualFocus,
      focusX: 0.31,
      focusY: 0.68,
    );
    final restored = ClipEditOverrides.fromJson(
      Map<String, dynamic>.from(value.toJson()),
    );
    expect(restored.clipId, value.clipId);
    expect(restored.framingMode, ClipFramingMode.manualFocus);
    expect(restored.focusX, value.focusX);
    expect(restored.focusY, value.focusY);
    expect(
      () => const ClipEditOverrides(clipId: 'clip_001', focusX: 1.1).validate(),
      throwsFormatException,
    );
  });

  test('caption timing and style settings survive project preference JSON', () {
    const original = ClipPreferences();
    final edited = original.copyWith(
      aspectRatio: ClipAspectRatio.square11,
      captionsEnabled: false,
      captionStyleId: 'neon',
      captionAnimationId: 'bounce',
      mainTextColor: '#F472B6',
      highlightColor: '#22D3EE',
      captionFontFamily: 'Poppins',
      captionFontScale: 0.061,
      captionPositionY: 0.77,
      captionUppercase: false,
      captionBold: true,
      captionTimingOffsetMs: -275,
    );
    final restored = ClipPreferences.fromJson(
      Map<String, dynamic>.from(edited.toJson()),
    );
    expect(restored.aspectRatio, ClipAspectRatio.square11);
    expect(restored.captionsEnabled, isFalse);
    expect(restored.captionStyleId, 'neon');
    expect(restored.captionAnimationId, 'bounce');
    expect(restored.mainTextColor, '#F472B6');
    expect(restored.highlightColor, '#22D3EE');
    expect(restored.captionFontFamily, 'Poppins');
    expect(restored.captionFontScale, 0.061);
    expect(restored.captionPositionY, 0.77);
    expect(restored.captionUppercase, isFalse);
    expect(restored.captionBold, isTrue);
    expect(restored.captionTimingOffsetMs, -275);
    expect(
      original.copyWith(captionTimingOffsetMs: 5001).validate(),
      isNotNull,
    );
  });

  test('clip-specific framing overrides persist independently in the project', () async {
    final root = await Directory.systemTemp.createTemp('cutawan-clip-editor-');
    try {
      final repository = LocalProjectRepository(rootDirectory: root);
      final now = DateTime.utc(2026, 11, 21);
      final source = VideoAssetMetadata(
        uri: 'content://media/external/video/media/42',
        displayName: 'source.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 2048,
        durationMs: 10000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      );
      final project = CutawanProject.create(
        source: source,
        preferences: const ClipPreferences(),
        now: now,
      );
      await repository.save(project);
      const candidate = ClipCandidate(
        id: 'clip_001',
        startMs: 1000,
        endMs: 5000,
        score: 80,
        title: 'Opening',
        hook: 'Hook',
        summary: 'Summary',
        explanations: [],
        transcriptText: 'Hello',
        averageAudioEnergy: 0.5,
        peakVisualChange: 0.4,
      );
      await repository.saveCandidates(
        project.id,
        CandidateSet(
          schemaVersion: CandidateSet.currentSchemaVersion,
          sourceDurationMs: 10000,
          createdAtUtc: now,
          candidates: const [candidate],
          transcriptEvidence: true,
          audioEvidence: true,
          visualEvidence: true,
          rankingEngine: 'test',
        ),
      );
      const override = ClipEditOverrides(
        clipId: 'clip_001',
        framingMode: ClipFramingMode.manualFocus,
        focusX: 0.24,
        focusY: 0.63,
        focusKeyframes: [
          ClipFocusKeyframe(timestampMs: 2000, focusX: 0.24, focusY: 0.63),
          ClipFocusKeyframe(timestampMs: 4000, focusX: 0.74, focusY: 0.42),
        ],
      );
      await repository.saveClipEditOverrides(project.id, override);
      final restored = await repository.loadClipEditOverrides(
        project.id,
        candidate.id,
      );
      expect(restored?.framingMode, ClipFramingMode.manualFocus);
      expect(restored?.focusX, 0.24);
      expect(restored?.focusY, 0.63);
      expect(restored?.focusKeyframes, hasLength(2));
      expect(restored?.focusKeyframes.last.timestampMs, 4000);
      expect(restored?.focusKeyframes.last.focusX, 0.74);
    } finally {
      await root.delete(recursive: true);
    }
  });
}
