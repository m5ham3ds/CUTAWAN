import 'package:cutawan_mobile/services/android_video_picker.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const channel = MethodChannel('com.cutawan.mobile/media');
  final calls = <MethodCall>[];

  Map<String, Object?> payload() => {
        'uri': 'content://media/external/video/media/42',
        'displayName': 'sample.mp4',
        'mimeType': 'video/mp4',
        'sizeBytes': 1200000,
        'durationMs': 60000,
        'width': 1280,
        'height': 720,
        'rotationDegrees': 0,
        'importedAtUtc': '2026-11-20T01:00:00.000Z',
      };

  setUp(() {
    calls.clear();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
      calls.add(call);
      if (call.method == 'pickVideo' || call.method == 'inspectVideo') {
        return payload();
      }
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
  });

  test('pickVideo decodes Android metadata into the project media contract',
      () async {
    final metadata = await AndroidVideoPicker.pickVideo();

    expect(metadata, isNotNull);
    expect(metadata!.displayName, 'sample.mp4');
    expect(metadata.durationMs, 60000);
    expect(calls.single.method, 'pickVideo');
  });

  test('inspectVideo sends the persisted content URI back to Android', () async {
    final metadata = await AndroidVideoPicker.inspectVideo(
      'content://media/external/video/media/42',
    );

    expect(metadata.uri, 'content://media/external/video/media/42');
    expect(calls.single.method, 'inspectVideo');
    expect(calls.single.arguments, {
      'uri': 'content://media/external/video/media/42',
    });
  });

  test('releasing a persisted SAF grant is sent to Android', () async {
    await AndroidVideoPicker.releasePersistedPermission(
      'content://media/external/video/media/42',
    );

    expect(calls.single.method, 'releasePersistedPermission');
    expect(calls.single.arguments, {
      'uri': 'content://media/external/video/media/42',
    });
  });

  test('cancelled selection returns null', () async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async => null);

    expect(await AndroidVideoPicker.pickVideo(), isNull);
  });
}
