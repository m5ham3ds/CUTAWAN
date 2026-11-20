import 'dart:io';

import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late LocalProjectRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cutawan-projects-');
    repository = LocalProjectRepository(rootDirectory: directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  CutawanProject makeProject() {
    final now = DateTime.utc(2026, 11, 20);
    return CutawanProject.create(
      source: VideoAssetMetadata(
        uri: 'content://media/external/video/media/42',
        displayName: 'interview.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 2000000,
        durationMs: 90000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      ),
      preferences: const ClipPreferences(requestedClipCount: 5),
      now: now,
    );
  }

  test('save, list and load survive repository re-instantiation', () async {
    final project = makeProject();
    await repository.save(project);

    final reopenedRepository = LocalProjectRepository(rootDirectory: directory);
    final restored = await reopenedRepository.load(project.id);
    final listed = await reopenedRepository.listProjects();

    expect(restored, isNotNull);
    expect(restored!.source.displayName, 'interview.mp4');
    expect(restored.preferences.requestedClipCount, 5);
    expect(listed.map((item) => item.id), contains(project.id));
    expect(
      directory.listSync().where((item) => item.path.endsWith('.tmp')),
      isEmpty,
    );
  });

  test('cancelling a prepared job is persisted and cannot be repeated', () async {
    final project = makeProject();
    await repository.save(project);

    final cancelled = await repository.cancelJob(project.id);
    final restored = await repository.load(project.id);

    expect(cancelled.job.status, ProjectJobStatus.cancelled);
    expect(cancelled.job.cancelRequested, isTrue);
    expect(restored!.job.status, ProjectJobStatus.cancelled);
    await expectLater(
      repository.cancelJob(project.id),
      throwsA(isA<StateError>()),
    );
  });

  test('delete removes a project and load returns null', () async {
    final project = makeProject();
    await repository.save(project);

    await repository.delete(project.id);

    expect(await repository.load(project.id), isNull);
    expect(await repository.listProjects(), isEmpty);
  });


  test('job stage updates and cancellation state persist', () async {
    final project = makeProject();
    await repository.save(project);
    await repository.saveJobState(
      project.id,
      status: ProjectJobStatus.running,
      stage: 'transcribing',
      progress: 0.4,
    );
    final running = await repository.load(project.id);
    expect(running!.job.status, ProjectJobStatus.running);
    expect(running.job.stage, 'transcribing');
    expect(running.job.progress, 0.4);
    await repository.cancelJob(project.id);
    final cancelled = await repository.load(project.id);
    expect(cancelled!.job.status, ProjectJobStatus.cancelled);
    expect(cancelled.job.cancelRequested, isTrue);
    await expectLater(
      repository.saveJobState(project.id, progress: 1.1),
      throwsA(isA<FormatException>()),
    );
  });

  test('stage checkpoints validate fingerprints and all referenced artifacts', () async {
    final project = makeProject();
    await repository.save(project);
    final artifactDirectory = Directory(
      '\${directory.path}\${Platform.pathSeparator}artifacts'
      '\${Platform.pathSeparator}\${project.id}',
    );
    await artifactDirectory.create(recursive: true);
    final artifact = File(
      '\${artifactDirectory.path}\${Platform.pathSeparator}transcript.json',
    );
    await artifact.writeAsString('{"ok":true}');
    final fingerprint = List.filled(64, 'a').join();
    final otherFingerprint = List.filled(64, 'b').join();
    await repository.saveStageCheckpoint(
      project.id,
      stage: 'transcribing',
      fingerprint: fingerprint,
      artifactPaths: const ['transcript.json'],
    );
    expect(
      await repository.hasValidStageCheckpoint(
        project.id,
        stage: 'transcribing',
        fingerprint: fingerprint,
      ),
      isTrue,
    );
    expect(
      await repository.hasValidStageCheckpoint(
        project.id,
        stage: 'transcribing',
        fingerprint: otherFingerprint,
      ),
      isFalse,
    );
    await artifact.delete();
    expect(
      await repository.hasValidStageCheckpoint(
        project.id,
        stage: 'transcribing',
        fingerprint: fingerprint,
      ),
      isFalse,
    );
  });

  test('checkpoint rejects traversal and invalid hashes', () async {
    final project = makeProject();
    await repository.save(project);
    await expectLater(
      repository.saveStageCheckpoint(
        project.id,
        stage: 'render_clip',
        fingerprint: 'invalid',
        artifactPaths: const [],
      ),
      throwsA(isA<FormatException>()),
    );
    await expectLater(
      repository.saveStageCheckpoint(
        project.id,
        stage: 'render_clip',
        fingerprint: List.filled(64, 'a').join(),
        artifactPaths: const ['../../outside'],
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('repository rejects an unsafe project ID', () async {
    await expectLater(
      repository.load('../secrets'),
      throwsA(isA<FormatException>()),
    );
  });
}
