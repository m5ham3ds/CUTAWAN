import 'package:cutawan_mobile/services/video_composition_export_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.cutawan.mobile/media');
  final calls = <MethodCall>[];
  final expectedHash = List<String>.filled(64, 'a').join();

  Map<String, Object?> payload() => {
        'outputUri': 'content://media/external/video/media/9001',
        'displayName': 'CUTAWAN_sequence.mp4',
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
          return {'renderId': 'composition_render_1'};
        case 'getRenderProgress':
          return {
            'renderId': 'composition_render_1',
            'status': 'completed',
            'progress': 100,
            'error': '',
            'result': payload(),
          };
        case 'cancelRender':
        case 'releaseRender':
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

  List<Map<String, Object?>> validTracks() => [
        {
          'id': 'track_video_main',
          'type': 'video',
          'clips': [
            {
              'itemId': 'item_video_001',
              'candidateId': 'clip_001',
              'sourceUri': 'content://media/external/video/media/42',
              'sourceStartMs': 1000,
              'sourceEndMs': 6000,
              'timelineStartMs': 0,
            },
            {
              'itemId': 'item_video_002',
              'candidateId': 'clip_002',
              'sourceUri': 'content://media/external/video/media/42',
              'sourceStartMs': 8000,
              'sourceEndMs': 18000,
              'timelineStartMs': 5000,
            },
          ],
        },
        {
          'id': 'track_audio_main',
          'type': 'audio',
          'clips': [
            {
              'itemId': 'item_audio_001',
              'candidateId': 'clip_001',
              'sourceUri': 'content://media/external/video/media/42',
              'sourceStartMs': 1000,
              'sourceEndMs': 16000,
              'timelineStartMs': 0,
            },
          ],
        },
      ];

  test('starts Media3 composition with overlapping independent tracks', () async {
    final service = VideoCompositionExportService(channel: channel);
    String? startedId;
    var progress = 0.0;
    final tracks = validTracks();

    final result = await service.renderComposition(
      projectId: 'cut_project_001',
      compositionId: 'sequence',
      tracks: tracks,
      sourceDurationMs: 90000,
      expectedDurationMs: 15000,
      aspectRatio: 9 / 16,
      outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
      onStarted: (value) => startedId = value,
      onProgress: (value) => progress = value,
    );

    expect(result.validated, isTrue);
    expect(result.fullyDecodeValidated, isTrue);
    expect(startedId, 'composition_render_1');
    expect(progress, 1);
    expect(calls.map((call) => call.method), [
      'startRender',
      'getRenderProgress',
      'releaseRender',
    ]);
    final request = calls.first.arguments as Map<Object?, Object?>;
    expect(request['renderType'], 'composition');
    expect(request['projectId'], 'cut_project_001');
    expect(request['clipId'], 'sequence');
    expect(request['expectedDurationMs'], 15000);
    expect(request['tracks'], tracks);
  });


  test('sends validated dip-to-black transition metadata to Media3', () async {
    final service = VideoCompositionExportService(channel: channel);
    final tracks = validTracks();
    final videoClips =
        List<Map<String, Object?>>.from(tracks.first['clips']! as List);
    videoClips[0] = {
      ...videoClips[0],
      'transitionAfter': {'type': 'dipToBlack', 'durationMs': 800},
    };
    tracks[0] = {...tracks.first, 'clips': videoClips};

    await service.renderComposition(
      projectId: 'cut_project_001',
      compositionId: 'sequence',
      tracks: tracks,
      sourceDurationMs: 90000,
      expectedDurationMs: 15000,
      aspectRatio: 9 / 16,
      outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
    );

    final request = calls.first.arguments as Map<Object?, Object?>;
    final requestTracks = request['tracks']! as List;
    final requestVideo = requestTracks.first as Map<Object?, Object?>;
    final requestClips = requestVideo['clips']! as List;
    final firstClip = requestClips.first as Map<Object?, Object?>;
    expect(
      firstClip['transitionAfter'],
      {'type': 'dipToBlack', 'durationMs': 800},
    );
  });

  test('rejects transitions that point across a timeline gap before Android calls',
      () async {
    final service = VideoCompositionExportService(channel: channel);
    final tracks = validTracks();
    final videoClips =
        List<Map<String, Object?>>.from(tracks.first['clips']! as List);
    videoClips[0] = {
      ...videoClips[0],
      'transitionAfter': {'type': 'dipToBlack', 'durationMs': 800},
    };
    videoClips[1] = {...videoClips[1], 'timelineStartMs': 6000};
    tracks[0] = {...tracks.first, 'clips': videoClips};

    await expectLater(
      service.renderComposition(
        projectId: 'cut_project_001',
        compositionId: 'sequence',
        tracks: tracks,
        sourceDurationMs: 90000,
        expectedDurationMs: 16000,
        aspectRatio: 9 / 16,
        outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test('rejects audio-track transition metadata before Android calls', () async {
    final service = VideoCompositionExportService(channel: channel);
    final tracks = validTracks();
    final audioClips =
        List<Map<String, Object?>>.from(tracks[1]['clips']! as List);
    audioClips[0] = {
      ...audioClips[0],
      'transitionAfter': {'type': 'dipToBlack', 'durationMs': 800},
    };
    tracks[1] = {...tracks[1], 'clips': audioClips};

    await expectLater(
      service.renderComposition(
        projectId: 'cut_project_001',
        compositionId: 'sequence',
        tracks: tracks,
        sourceDurationMs: 90000,
        expectedDurationMs: 15000,
        aspectRatio: 9 / 16,
        outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test('rejects overlapping items within one track before Android calls', () async {
    final service = VideoCompositionExportService(channel: channel);
    final tracks = validTracks();
    final videoClips =
        List<Map<String, Object?>>.from(tracks.first['clips']! as List);
    videoClips[1] = {...videoClips[1], 'timelineStartMs': 4000};
    tracks[0] = {...tracks.first, 'clips': videoClips};

    await expectLater(
      service.renderComposition(
        projectId: 'cut_project_001',
        compositionId: 'sequence',
        tracks: tracks,
        sourceDurationMs: 90000,
        expectedDurationMs: 15000,
        aspectRatio: 9 / 16,
        outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test('rejects duplicate item IDs across composition tracks', () async {
    final service = VideoCompositionExportService(channel: channel);
    final tracks = validTracks();
    final audioClips =
        List<Map<String, Object?>>.from(tracks[1]['clips']! as List);
    audioClips[0] = {...audioClips[0], 'itemId': 'item_video_001'};
    tracks[1] = {...tracks[1], 'clips': audioClips};

    await expectLater(
      service.renderComposition(
        projectId: 'cut_project_001',
        compositionId: 'sequence',
        tracks: tracks,
        sourceDurationMs: 90000,
        expectedDurationMs: 15000,
        aspectRatio: 9 / 16,
        outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test('rejects a duration that does not match the track timeline', () async {
    final service = VideoCompositionExportService(channel: channel);
    await expectLater(
      service.renderComposition(
        projectId: 'cut_project_001',
        compositionId: 'sequence',
        tracks: validTracks(),
        sourceDurationMs: 90000,
        expectedDurationMs: 14000,
        aspectRatio: 9 / 16,
        outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });

  test('rejects network sources before Android calls', () async {
    final service = VideoCompositionExportService(channel: channel);
    final tracks = validTracks();
    final videoClips =
        List<Map<String, Object?>>.from(tracks.first['clips']! as List);
    videoClips[0] = {
      ...videoClips[0],
      'sourceUri': 'https://example.com/source.mp4',
    };
    tracks[0] = {...tracks.first, 'clips': videoClips};

    await expectLater(
      service.renderComposition(
        projectId: 'cut_project_001',
        compositionId: 'sequence',
        tracks: tracks,
        sourceDurationMs: 90000,
        expectedDurationMs: 15000,
        aspectRatio: 9 / 16,
        outputPath: '/data/user/0/cutawan/files/exports/sequence.mp4',
      ),
      throwsFormatException,
    );
    expect(calls, isEmpty);
  });
}
