import 'package:cutawan_mobile/services/video_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.cutawan.mobile/media');
  final calls = <MethodCall>[];
  final expectedHash = List<String>.filled(64, 'a').join();

  Map<String, Object?> exportPayload() => {
        'outputUri': 'content://media/external/video/media/9001',
        'displayName': 'CUTAWAN_clip_9001.mp4',
        'sha256': expectedHash,
        'sizeBytes': 8192,
        'durationMs': 15000,
        'width': 1080,
        'height': 1920,
        'hasAudio': true,
        'validated': true,
      };

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      switch (call.method) {
        case 'startRender':
          return {'renderId': 'render_test_1'};
        case 'getRenderProgress':
          return {
            'renderId': 'render_test_1',
            'status': 'completed',
            'progress': 100,
            'error': '',
            'result': exportPayload(),
          };
        case 'verifyExport':
          return {
            'valid': true,
            'sha256': expectedHash,
            'sizeBytes': 8192,
            'durationMs': 15000,
            'width': 1080,
            'height': 1920,
            'hasVideo': true,
          };
        case 'cancelRender':
          return true;
        default:
          return null;
      }
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('renders a clip and accepts only validated MP4 metadata', () async {
    final service = VideoExportService(channel: channel);
    String? startedId;
    var progress = 0.0;
    final result = await service.renderClip(
      clipId: 'clip_1',
      sourceUri: 'content://media/external/video/media/42',
      startMs: 1000,
      endMs: 16000,
      aspectRatio: 9 / 16,
      outputPath: '/data/user/0/com.cutawan/files/exports/clip_1.mp4',
      onStarted: (id) => startedId = id,
      onProgress: (value) => progress = value,
    );

    expect(startedId, 'render_test_1');
    expect(progress, 1);
    expect(result.renderId, 'render_test_1');
    expect(result.outputUri, startsWith('content://'));
    expect(result.sha256, expectedHash);
    expect(result.validated, isTrue);
    expect(calls.map((call) => call.method), [
      'startRender',
      'getRenderProgress',
      'releaseRender',
    ]);
    expect(calls.first.arguments, containsPair('startMs', 1000));
    expect(calls.first.arguments, containsPair('endMs', 16000));
  });

  test('cancellation requests cancel the native render and release the session', () async {
    final service = VideoExportService(channel: channel);
    await expectLater(
      service.renderClip(
        clipId: 'clip_2',
        sourceUri: 'content://media/external/video/media/42',
        startMs: 0,
        endMs: 5000,
        aspectRatio: 9 / 16,
        outputPath: '/data/user/0/com.cutawan/files/exports/clip_2.mp4',
        shouldCancel: () async => true,
      ),
      throwsA(isA<VideoExportCancelled>()),
    );
    expect(calls.map((call) => call.method), [
      'startRender',
      'cancelRender',
      'releaseRender',
    ]);
  });

  test('resume verification checks URI and exact native file metadata', () async {
    final service = VideoExportService(channel: channel);
    final valid = await service.verifyExport(
      outputUri: 'content://media/external/video/media/9001',
      sha256: expectedHash,
      sizeBytes: 8192,
      durationMs: 15000,
      width: 1080,
      height: 1920,
    );
    expect(valid, isTrue);
    expect(calls.single.method, 'verifyExport');
    expect(calls.single.arguments, containsPair('sha256', expectedHash));
  });

  test('invalid export fingerprints are rejected before calling Android', () async {
    final service = VideoExportService(channel: channel);
    final valid = await service.verifyExport(
      outputUri: 'content://media/external/video/media/9001',
      sha256: 'not-a-sha256',
      sizeBytes: 8192,
      durationMs: 15000,
      width: 1080,
      height: 1920,
    );
    expect(valid, isFalse);
    expect(calls, isEmpty);
  });
}
