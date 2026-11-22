import 'dart:io';

import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:cutawan_mobile/services/processing_job_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late LocalProjectRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cutawan-job-service-');
    repository = LocalProjectRepository(rootDirectory: directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  CutawanProject makeProject() {
    final now = DateTime.utc(2026, 11, 20);
    return CutawanProject.create(
      source: VideoAssetMetadata(
        uri: 'content://media/external/video/media/7',
        displayName: 'job.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 1000,
        durationMs: 10000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      ),
      preferences: const ClipPreferences(requestedClipCount: 1),
      now: now,
    );
  }

  test('stage fingerprints change when source or configuration changes', () {
    final jobs = ProcessingJobService(
      repository: repository,
      fingerprintVideo: (_) async => List.filled(64, 'a').join(),
    );
    final first = jobs.stageFingerprint(
      sourceSha256: List.filled(64, 'a').join(),
      stage: 'discovering',
      configuration: 'v1',
    );
    final stable = jobs.stageFingerprint(
      sourceSha256: List.filled(64, 'a').join(),
      stage: 'discovering',
      configuration: 'v1',
    );
    final changed = jobs.stageFingerprint(
      sourceSha256: List.filled(64, 'b').join(),
      stage: 'discovering',
      configuration: 'v1',
    );
    expect(first, stable);
    expect(first, isNot(changed));
  });

  test(
    'running jobs remain running while a durable background worker is active',
    () async {
    final project = makeProject();
    await repository.save(project);
    await repository.saveJobState(
      project.id,
      status: ProjectJobStatus.running,
      stage: 'rendering_clip_42',
      progress: 0.6,
    );
    final jobs = ProcessingJobService(
      repository: repository,
      fingerprintVideo: (_) async => List.filled(64, 'c').join(),
      hasActiveBackgroundRender: (projectId) async => projectId == project.id,
    );

    await jobs.recoverInterruptedJobs();

    final recovered = await repository.load(project.id);
    expect(recovered!.job.status, ProjectJobStatus.running);
    expect(recovered.job.stage, 'rendering_clip_42');
    expect(recovered.job.progress, 0.6);
      expect(recovered.job.cancelRequested, isFalse);
    },
  );

  test('interrupted running jobs are recovered as resumable failures', () async {
    final project = makeProject();
    await repository.save(project);
    await repository.saveJobState(
      project.id,
      status: ProjectJobStatus.running,
      stage: 'rendering_clip_42',
      progress: 0.6,
    );
    final jobs = ProcessingJobService(
      repository: repository,
      fingerprintVideo: (_) async => List.filled(64, 'c').join(),
    );
    await jobs.recoverInterruptedJobs();
    final recovered = await repository.load(project.id);
    expect(recovered!.job.status, ProjectJobStatus.failed);
    expect(
      recovered.job.stage,
      'interrupted_after_process_death:rendering_clip_42',
    );
    expect(recovered.job.progress, 0.6);
  });
}
