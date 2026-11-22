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
        'fullyDecodeValidated': true,
        'decodedVideoBuffers': 450,
        'decodedAudioBuffers': 680,
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
            'hasAudio': true,
            'fullyDecodeValidated': true,
            'decodedVideoBuffers': 450,
            'decodedAudioBuffers': 680,
          };
        case 'cancelRender':
          return true;
        case 'getCompletedRender':
          return null;
        case 'acknowledgeCompletedRender':
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

  test('renders a clip and passes its crop plan to Android', () async {
    final service = VideoExportService(channel: channel);
    String? startedId;
    var progress = 0.0;
    final cropPlan = <Map<String, Object?>>[
      <String, Object?>{
        'startMs': 0,
        'endMs': 15000,
        'mode': 'crop',
        'region': <String, Object?>{
          'x': 0.342,
          'y': 0.0,
          'width': 0.316,
          'height': 1.0,
        },
      },
    ];
    final result = await service.renderClip(
      clipId: 'clip_1',
      sourceUri: 'content://media/external/video/media/42',
      startMs: 1000,
      endMs: 16000,
      aspectRatio: 9 / 16,
      sourceAspectRatio: 16 / 9,
      reframeShots: cropPlan,
      captionCues: [
        <String, Object?>{
          'startMs': 0,
          'endMs': 15000,
          'text': 'مرحبا بالعالم',
          'words': [
            <String, Object?>{
              'text': 'مرحبا',
              'startMs': 0,
              'endMs': 800,
              'startOffset': 0,
              'endOffset': 5,
            },
            <String, Object?>{
              'text': 'بالعالم',
              'startMs': 850,
              'endMs': 1500,
              'startOffset': 6,
              'endOffset': 13,
            },
          ],
        },
      ],
      captionStyle: <String, Object?>{
        'fontFamily': 'Poppins',
        'fontScale': 0.046,
        'uppercase': false,
        'textColor': '#FFFFFF',
        'highlightColor': '#4ADE80',
        'highlightBoxColor': null,
        'outlineColor': '#000000',
        'outlineWidth': 2.6,
        'shadow': 1.0,
        'bold': true,
        'positionY': 0.74,
      },
      captionAnimationId: 'karaoke_fill',
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
    expect(result.fullyDecodeValidated, isTrue);
    expect(result.decodedVideoBuffers, 450);
    expect(result.decodedAudioBuffers, 680);
    expect(calls.map((call) => call.method), [
      'startRender',
      'getRenderProgress',
      'releaseRender',
    ]);
    final arguments = Map<String, Object?>.from(calls.first.arguments as Map);
    expect(arguments, containsPair('projectId', 'standalone'));
    expect(arguments, containsPair('startMs', 1000));
    expect(arguments, containsPair('endMs', 16000));
    expect(arguments, containsPair('sourceAspectRatio', 16 / 9));
    expect(arguments['reframeShots'], cropPlan);
    expect(arguments['captionAnimationId'], 'karaoke_fill');
    expect(arguments['captionCues'], isA<List<dynamic>>());
    final sentCues = arguments['captionCues'] as List<dynamic>;
    expect(sentCues, hasLength(1));
    final sentCue = sentCues.single as Map<dynamic, dynamic>;
    expect(sentCue['text'], 'مرحبا بالعالم');
    expect(arguments['captionStyle'], isA<Map<dynamic, dynamic>>());
    final sentStyle = arguments['captionStyle'] as Map<dynamic, dynamic>;
    expect(sentStyle['positionY'], 0.74);
  });

  test('recovers a durable render completion and acknowledges it after persistence', () async {
    final recoveredCalls = <MethodCall>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      recoveredCalls.add(call);
      if (call.method == 'getCompletedRender') {
        return {
          'renderId': 'render_recovered_1',
          'result': exportPayload(),
        };
      }
      if (call.method == 'acknowledgeCompletedRender') return true;
      return null;
    });

    final service = VideoExportService(channel: channel);
    final recovered = await service.consumeCompletedRender(
      renderKey: expectedHash,
    );
    expect(recovered, isNotNull);
    expect(recovered!.renderId, 'render_recovered_1');
    expect(recovered.outputUri, startsWith('content://'));
    expect(recovered.fullyDecodeValidated, isTrue);
    expect(
      await service.acknowledgeCompletedRender(
        renderKey: expectedHash,
        sha256: recovered.sha256,
      ),
      isTrue,
    );
    expect(recoveredCalls.map((call) => call.method), [
      'getCompletedRender',
      'acknowledgeCompletedRender',
    ]);
    expect(
      recoveredCalls.last.arguments,
      containsPair('renderKey', expectedHash),
    );
    expect(
      recoveredCalls.last.arguments,
      containsPair('sha256', expectedHash),
    );
  });

  test('rejects malformed durable render identities before parsing payloads', () async {
    final service = VideoExportService(channel: channel);
    await expectLater(
      service.consumeCompletedRender(renderKey: 'not-a-fingerprint'),
      throwsA(isA<FormatException>()),
    );
    expect(calls, isEmpty);
  });

  test('rejects reframe segments that do not cover the complete clip', () async {
    final service = VideoExportService(channel: channel);
    await expectLater(
      service.renderClip(
        clipId: 'clip_invalid',
        sourceUri: 'content://media/external/video/media/42',
        startMs: 1000,
        endMs: 6000,
        aspectRatio: 9 / 16,
        sourceAspectRatio: 16 / 9,
        outputPath: '/data/user/0/com.cutawan/files/exports/clip_invalid.mp4',
        reframeShots: [
          <String, Object?>{
            'startMs': 0,
            'endMs': 4000,
            'mode': 'fit',
            'region': null,
          },
        ],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(calls, isEmpty);
  });

  test('rejects crop geometry with the wrong target aspect ratio', () async {
    final service = VideoExportService(channel: channel);
    await expectLater(
      service.renderClip(
        clipId: 'clip_wrong_ratio',
        sourceUri: 'content://media/external/video/media/42',
        startMs: 0,
        endMs: 15000,
        aspectRatio: 9 / 16,
        sourceAspectRatio: 16 / 9,
        outputPath: '/data/user/0/com.cutawan/files/exports/clip_wrong_ratio.mp4',
        reframeShots: [
          <String, Object?>{
            'startMs': 0,
            'endMs': 15000,
            'mode': 'crop',
            'region': <String, Object?>{
              'x': 0.1,
              'y': 0.0,
              'width': 0.8,
              'height': 1.0,
            },
          },
        ],
      ),
      throwsA(isA<FormatException>()),
    );
    expect(calls, isEmpty);
  });

  test('rejects caption word offsets that do not match the cue text', () async {
    final service = VideoExportService(channel: channel);
    await expectLater(
      service.renderClip(
        clipId: 'clip_bad_caption',
        sourceUri: 'content://media/external/video/media/42',
        startMs: 0,
        endMs: 5000,
        aspectRatio: 9 / 16,
        sourceAspectRatio: 16 / 9,
        outputPath: '/data/user/0/com.cutawan/files/exports/clip_bad_caption.mp4',
        captionCues: [
          <String, Object?>{
            'startMs': 0,
            'endMs': 3000,
            'text': 'مرحبا بالعالم',
            'words': [
              <String, Object?>{
                'text': 'خطأ',
                'startMs': 0,
                'endMs': 800,
                'startOffset': 0,
                'endOffset': 3,
              },
            ],
          },
        ],
        captionStyle: <String, Object?>{
          'fontFamily': 'Poppins',
          'fontScale': 0.046,
          'uppercase': false,
          'textColor': '#FFFFFF',
          'highlightColor': '#4ADE80',
          'highlightBoxColor': null,
          'outlineColor': '#000000',
          'outlineWidth': 2.6,
          'shadow': 1.0,
          'bold': true,
          'positionY': 0.74,
        },
      ),
      throwsA(isA<FormatException>()),
    );
    expect(calls, isEmpty);
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
        sourceAspectRatio: 16 / 9,
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

  test('resume verification checks exact native file metadata', () async {
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

  test('rejects an export that reports metadata validation without full decode', () {
    final payload = exportPayload()
      ..['fullyDecodeValidated'] = false;
    expect(
      () => VideoExportResult.fromJson(
        'render_metadata_only',
        payload,
      ),
      throwsA(isA<FormatException>()),
    );
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
