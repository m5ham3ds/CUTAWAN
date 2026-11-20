import 'package:cutawan_mobile/domain/reframe_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const planner = ReframePlanner();

  ReframePlan plan({
    required List<FrameBox> boxes,
    required List<double> scores,
    required List<int> times,
    bool context = false,
  }) => planner.create(
        sourceDurationMs: 10000,
        sourceWidth: 1920,
        sourceHeight: 1080,
        targetAspectRatio: 9 / 16,
        detections: boxes,
        confidenceScores: scores,
        timestampsMs: times,
        preferContext: context,
      );

  test('no detections always preserve the full scene with fit fallback', () {
    final value = plan(boxes: [], scores: [], times: []);
    value.validate();
    expect(value.focusTrack, isNull);
    expect(value.shots.single.mode, 'fit');
    expect(value.fallbackReason, isNotNull);
  });

  test('low confidence and small faces are rejected from automatic crop', () {
    final value = plan(
      boxes: List.filled(5, const FrameBox(x: 0.3, y: 0.2, width: 0.08, height: 0.08)),
      scores: List.filled(5, 0.4),
      times: [0, 2000, 4000, 6000, 8000],
    );
    expect(value.shots.single.mode, 'fit');
    expect(value.focusTrack, isNull);
  });

  test('high confidence coverage creates source-bounded crop shots', () {
    final value = plan(
      boxes: List.generate(
        8,
        (index) => FrameBox(
          x: 0.35 + (index.isEven ? 0 : 0.01),
          y: 0.2,
          width: 0.22,
          height: 0.32,
        ),
      ),
      scores: List.filled(8, 0.92),
      times: [0, 1200, 2400, 3600, 4800, 6000, 7200, 8400],
    );
    value.validate();
    expect(value.focusTrack, isNotNull);
    expect(value.shots.any((shot) => shot.mode == 'crop'), isTrue);
    expect(value.shots.every((shot) => shot.endMs <= 10000), isTrue);
    expect(value.shots.every((shot) => shot.validate(sourceDurationMs: 10000) == null), isTrue);
  });

  test('context preference overrides detections and forces full-frame fit', () {
    final value = plan(
      boxes: List.generate(8, (index) => const FrameBox(
        x: 0.35, y: 0.2, width: 0.22, height: 0.32,
      )),
      scores: List.filled(8, 0.95),
      times: [0, 1200, 2400, 3600, 4800, 6000, 7200, 8400],
      context: true,
    );
    expect(value.focusTrack, isNull);
    expect(value.shots.single.mode, 'fit');
  });

  test('out-of-frame regions and invalid shot timestamps are rejected', () {
    expect(
      const FrameBox(x: 0.9, y: 0.2, width: 0.2, height: 0.2).validate(),
      isNotNull,
    );
    const bad = ReframeShot(
      startMs: 0,
      endMs: 12000,
      mode: 'crop',
      region: FrameBox(x: 0, y: 0, width: 1, height: 1),
      focusCenterX: 0.5,
      confidence: 0.4,
    );
    expect(bad.validate(sourceDurationMs: 10000), isNotNull);
  });

  test('duplicate timestamp detections do not inflate focus-track coverage', () {
    final value = plan(
      boxes: List.generate(
        8,
        (index) => const FrameBox(
          x: 0.35, y: 0.2, width: 0.22, height: 0.32,
        ),
      ),
      scores: List.filled(8, 0.92),
      times: [0, 0, 1200, 1200, 2400, 2400, 3600, 3600],
    );
    expect(value.focusTrack, isNotNull);
    expect(value.focusTrack!.keyframes, hasLength(4));
    expect(value.focusTrack!.coverage, 0.5);
  });

  test('reframe plan JSON round-trips with validated time coverage', () {
    final original = plan(boxes: [], scores: [], times: []);
    final restored = ReframePlan.fromJson(
      Map<String, dynamic>.from(original.toJson()),
    );
    restored.validate();
    expect(restored.shots.single.mode, 'fit');
    expect(restored.sourceDurationMs, original.sourceDurationMs);
    expect(restored.fallbackReason, original.fallbackReason);
  });

  test('overlapping and uncovered shot plans are rejected', () {
    final invalid = ReframePlan(
      schemaVersion: 1,
      sourceDurationMs: 10000,
      aspectRatio: 9 / 16,
      shots: const [
        ReframeShot(startMs: 0, endMs: 7000, mode: 'fit'),
        ReframeShot(startMs: 6000, endMs: 10000, mode: 'fit'),
      ],
      focusTrack: null,
      fallbackReason: 'test',
      engine: 'test',
    );
    expect(invalid.validate, throwsA(isA<FormatException>()));
  });
}
