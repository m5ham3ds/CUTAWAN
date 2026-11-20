import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/services/android_reframe_analysis_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.cutawan.mobile/media');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('Android face samples become a validated crop-focus plan', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'analyzeFaces');
      return <String, Object?>{
        'sourceDurationMs': 10000,
        'sampleIntervalMs': 1200,
        'sampleCount': 8,
        'samples': List.generate(
          8,
          (index) => <String, Object?>{
            'timestampMs': index * 1200,
            'confidence': 0.92,
            'box': <String, Object?>{
              'x': 0.35,
              'y': 0.2,
              'width': 0.22,
              'height': 0.32,
            },
          },
        ),
      };
    });

    final plan = await const AndroidReframeAnalysisService().analyze(
      sourceUri: 'content://media/external/video/media/9',
      sourceDurationMs: 10000,
      sourceWidth: 1920,
      sourceHeight: 1080,
      targetAspectRatio: 9 / 16,
    );

    expect(plan.focusTrack, isNotNull);
    expect(plan.shots.any((shot) => shot.mode == 'crop'), isTrue);
    expect(plan.sourceDurationMs, 10000);
    expect(plan.shots.last.endMs, 10000);
  });

  test('empty Android face samples create a full-frame safe fallback', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <String, Object?>{
      'sourceDurationMs': 10000,
      'sampleIntervalMs': 1000,
      'sampleCount': 4,
      'samples': List.generate(
        4,
        (index) => <String, Object?>{
          'timestampMs': index * 2000,
          'confidence': 0.0,
          'box': null,
        },
      ),
    });

    final plan = await const AndroidReframeAnalysisService().analyze(
      sourceUri: 'content://media/external/video/media/10',
      sourceDurationMs: 10000,
      sourceWidth: 1920,
      sourceHeight: 1080,
      targetAspectRatio: 1,
    );

    expect(plan.focusTrack, isNull);
    expect(plan.shots.single.mode, 'fit');
    expect(plan.fallbackReason, isNotNull);
  });

  test('mismatched native video duration is rejected', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <String, Object?>{
      'sourceDurationMs': 50000,
      'samples': <Object>[],
    });

    await expectLater(
      const AndroidReframeAnalysisService().analyze(
        sourceUri: 'content://media/external/video/media/11',
        sourceDurationMs: 10000,
        sourceWidth: 1920,
        sourceHeight: 1080,
        targetAspectRatio: 9 / 16,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
