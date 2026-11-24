import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/services/android_filmstrip_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('com.cutawan.mobile/media');

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  Uint8List jpeg(int marker) => Uint8List.fromList(
        <int>[0xff, 0xd8, 0xff, marker, 0xff, 0xd9],
      );

  test('filmstrip request returns validated sorted JPEG frames', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'createFilmstrip');
      expect(call.arguments, <String, Object?>{
        'uri': 'content://media/external/video/media/42',
        'startMs': 1000,
        'endMs': 9000,
        'sampleCount': 3,
      });
      return <Object?>[
        <String, Object?>{
          'timestampMs': 1000,
          'imageBytes': jpeg(1),
          'width': 240,
          'height': 135,
        },
        <String, Object?>{
          'timestampMs': 5000,
          'imageBytes': jpeg(2),
          'width': 240,
          'height': 135,
        },
        <String, Object?>{
          'timestampMs': 8999,
          'imageBytes': jpeg(3),
          'width': 240,
          'height': 135,
        },
      ];
    });

    final frames = await const AndroidFilmstripService().generate(
      sourceUri: 'content://media/external/video/media/42',
      startMs: 1000,
      endMs: 9000,
      sampleCount: 3,
    );

    expect(frames, hasLength(3));
    expect(frames.map((frame) => frame.timestampMs).toList(), [1000, 5000, 8999]);
    expect(frames.first.imageBytes, jpeg(1));
    expect(frames.last.width, 240);
  });

  test('filmstrip rejects out-of-range or non-JPEG native frames', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <Object?>[
      <String, Object?>{
        'timestampMs': 9500,
        'imageBytes': jpeg(1),
        'width': 120,
        'height': 80,
      },
    ]);

    await expectLater(
      const AndroidFilmstripService().generate(
        sourceUri: 'content://media/external/video/media/42',
        startMs: 1000,
        endMs: 9000,
      ),
      throwsA(isA<FormatException>()),
    );

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (_) async => <Object?>[
      <String, Object?>{
        'timestampMs': 2000,
        'imageBytes': Uint8List.fromList(<int>[1, 2, 3, 4]),
        'width': 120,
        'height': 80,
      },
    ]);
    await expectLater(
      const AndroidFilmstripService().generate(
        sourceUri: 'content://media/external/video/media/42',
        startMs: 1000,
        endMs: 9000,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('filmstrip validates request range and source URI before platform call', () async {
    await expectLater(
      const AndroidFilmstripService().generate(
        sourceUri: 'javascript:alert(1)',
        startMs: 0,
        endMs: 4000,
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      const AndroidFilmstripService().generate(
        sourceUri: 'content://media/external/video/media/42',
        startMs: 4000,
        endMs: 4000,
      ),
      throwsA(isA<FormatException>()),
    );
  });
}
