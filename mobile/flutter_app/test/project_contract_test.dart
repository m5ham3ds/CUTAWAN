import 'dart:convert';

import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final importedAt = DateTime.utc(2026, 11, 20, 1);
  final source = VideoAssetMetadata(
    uri: 'content://media/external/video/media/42',
    displayName: 'interview.mp4',
    mimeType: 'video/mp4',
    sizeBytes: 128000000,
    durationMs: 372500,
    width: 1920,
    height: 1080,
    rotationDegrees: 0,
    importedAtUtc: importedAt,
  );

  test('project JSON round-trips schema, source metadata, preferences and job', () {
    final project = CutawanProject.create(
      source: source,
      preferences: const ClipPreferences(
        requestedClipCount: 10,
        captionsEnabled: false,
        speakerTrackingEnabled: true,
      ),
      now: importedAt,
    );

    final decoded = jsonDecode(jsonEncode(project.toJson()));
    final restored = CutawanProject.fromJson(
      Map<String, dynamic>.from(decoded as Map),
    );

    expect(restored.schemaVersion, CutawanProject.currentSchemaVersion);
    expect(restored.id, project.id);
    expect(restored.source.uri, source.uri);
    expect(restored.source.durationMs, source.durationMs);
    expect(restored.source.width, 1920);
    expect(restored.preferences.requestedClipCount, 10);
    expect(restored.preferences.captionsEnabled, isFalse);
    expect(restored.preferences.speakerTrackingEnabled, isTrue);
    expect(restored.job.status, ProjectJobStatus.prepared);
  });

  test('schema zero migrates by adding schema version and a prepared job', () {
    final project = CutawanProject.create(
      source: source,
      preferences: const ClipPreferences(),
      now: importedAt,
    );
    final legacy = project.toJson()
      ..remove('schemaVersion')
      ..remove('job');

    final migrated = CutawanProject.fromJson(legacy);

    expect(migrated.schemaVersion, 1);
    expect(migrated.job.id, 'job_${project.id}');
    expect(migrated.job.stage, 'migrated');
    expect(migrated.job.status, ProjectJobStatus.prepared);
  });

  test('future schema versions are rejected instead of being misread', () {
    final project = CutawanProject.create(
      source: source,
      preferences: const ClipPreferences(),
      now: importedAt,
    ).toJson()
      ..['schemaVersion'] = 99;

    expect(
      () => CutawanProject.fromJson(project),
      throwsA(isA<FormatException>()),
    );
  });

  test('invalid file URIs and incomplete video metadata are rejected', () {
    expect(
      () => VideoAssetMetadata.fromJson({
        ...source.toJson(),
        'uri': '/storage/emulated/0/Movies/video.mp4',
      }),
      throwsA(isA<FormatException>()),
    );
    expect(
      () => VideoAssetMetadata.fromJson({
        ...source.toJson(),
        'durationMs': 0,
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('app-managed file URIs are accepted in the versioned source contract', () {
    final fileSource = VideoAssetMetadata.fromJson({
      'uri': 'file:///data/user/0/com.m5ham3ds.cutawan_mobile/files/app_flutter/sources/sample.mp4',
      'displayName': 'sample.mp4',
      'mimeType': 'video/mp4',
      'sizeBytes': 1000,
      'durationMs': 10000,
      'width': 1280,
      'height': 720,
      'rotationDegrees': 0,
      'importedAtUtc': '2026-11-20T01:00:00.000Z',
    });

    expect(fileSource.uri, startsWith('file://'));
    expect(
      () => VideoAssetMetadata.fromJson({
        ...fileSource.toJson(),
        'uri': 'file://relative/sample.mp4',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('local file URI cannot include a non-empty authority', () {
    expect(
      () => VideoAssetMetadata.fromJson({
        'uri': 'file://remote-host/private/video.mp4',
        'displayName': 'video.mp4',
        'mimeType': 'video/mp4',
        'sizeBytes': 100,
        'durationMs': 1000,
        'width': 640,
        'height': 360,
        'rotationDegrees': 0,
        'importedAtUtc': '2026-11-20T01:00:00.000Z',
      }),
      throwsA(isA<FormatException>()),
    );
  });

  test('job progress is range checked', () {
    expect(
      () => ProjectJob.fromJson({
        'id': 'job-test',
        'status': 'running',
        'progress': 1.5,
      }),
      throwsA(isA<FormatException>()),
    );
  });
}
