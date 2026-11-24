import 'dart:io';

import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/clip_sequence.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late LocalProjectRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cutawan-sequence-');
    repository = LocalProjectRepository(rootDirectory: directory);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  CutawanProject makeProject() {
    final now = DateTime.utc(2026, 11, 24);
    return CutawanProject.create(
      source: VideoAssetMetadata(
        uri: 'content://media/external/video/media/42',
        displayName: 'source.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 2048,
        durationMs: 90000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      ),
      preferences: const ClipPreferences(),
      now: now,
    );
  }

  CandidateSet makeCandidates() => CandidateSet(
        schemaVersion: CandidateSet.currentSchemaVersion,
        sourceDurationMs: 90000,
        createdAtUtc: DateTime.utc(2026, 11, 24),
        candidates: [
          ClipCandidate(
            id: 'clip_001',
            startMs: 1000,
            endMs: 5000,
            score: 90,
            title: 'First',
            hook: 'Hook',
            summary: 'Summary',
            explanations: const [],
            transcriptText: 'First segment',
            averageAudioEnergy: 0.5,
            peakVisualChange: 0.4,
          ),
          ClipCandidate(
            id: 'clip_002',
            startMs: 8000,
            endMs: 14000,
            score: 85,
            title: 'Second',
            hook: 'Hook',
            summary: 'Summary',
            explanations: const [],
            transcriptText: 'Second segment',
            averageAudioEnergy: 0.4,
            peakVisualChange: 0.3,
          ),
        ],
        transcriptEvidence: true,
        audioEvidence: true,
        visualEvidence: true,
        rankingEngine: 'test',
      );

  ClipSequence makeSequence() => ClipSequence(
        schemaVersion: ClipSequence.currentSchemaVersion,
        sourceDurationMs: 90000,
        tracks: const [
          ClipSequenceTrack(
            id: 'track_video_main',
            type: ClipSequenceTrackType.video,
            name: 'Main video',
            order: 0,
          ),
          ClipSequenceTrack(
            id: 'track_audio_main',
            type: ClipSequenceTrackType.audio,
            name: 'Main audio',
            order: 1,
          ),
        ],
        clips: const [
          ClipSequenceItem(
            id: 'item_video_001',
            candidateId: 'clip_001',
            trackId: 'track_video_main',
            sourceStartMs: 1000,
            sourceEndMs: 3000,
            timelineStartMs: 0,
          ),
          ClipSequenceItem(
            id: 'item_video_002',
            candidateId: 'clip_002',
            trackId: 'track_video_main',
            sourceStartMs: 8000,
            sourceEndMs: 10000,
            timelineStartMs: 2000,
          ),
          ClipSequenceItem(
            id: 'item_audio_001',
            candidateId: 'clip_001',
            trackId: 'track_audio_main',
            sourceStartMs: 1000,
            sourceEndMs: 4000,
            timelineStartMs: 500,
          ),
        ],
      );

  Future<CutawanProject> prepareProject() async {
    final project = makeProject();
    await repository.save(project);
    await repository.saveCandidates(project.id, makeCandidates());
    return project;
  }

  test('sequence persists as an optional project sidecar and survives reopen', () async {
    final project = await prepareProject();
    final sequence = makeSequence();
    await repository.saveClipSequence(project.id, sequence);

    final reopened = LocalProjectRepository(rootDirectory: directory);
    final restored = await reopened.loadClipSequence(project.id);
    expect(restored, isNotNull);
    expect(restored!.tracks, hasLength(2));
    expect(restored.clips, hasLength(3));
    expect(restored.clips[1].candidateId, 'clip_002');
    expect(restored.clips[1].timelineStartMs, 2000);
    expect(restored.toJson(), sequence.toJson());
  });

  test('missing sequence returns null for projects created before this schema', () async {
    final project = makeProject();
    await repository.save(project);
    expect(await repository.loadClipSequence(project.id), isNull);
  });

  test('saving sequence requires an existing project and candidate set', () async {
    await expectLater(
      repository.saveClipSequence('cut_missing', makeSequence()),
      throwsA(isA<StateError>()),
    );
    final project = makeProject();
    await repository.save(project);
    await expectLater(
      repository.saveClipSequence(project.id, makeSequence()),
      throwsA(isA<StateError>()),
    );
  });

  test('repository rejects missing candidate references and out-of-candidate source trims', () async {
    final project = await prepareProject();
    final valid = makeSequence();
    final invalidMissingCandidate = ClipSequence(
      schemaVersion: valid.schemaVersion,
      sourceDurationMs: valid.sourceDurationMs,
      tracks: valid.tracks,
      clips: const [
        ClipSequenceItem(
          id: 'item_missing',
          candidateId: 'clip_missing',
          trackId: 'track_video_main',
          sourceStartMs: 1000,
          sourceEndMs: 2000,
          timelineStartMs: 0,
        ),
      ],
    );
    await expectLater(
      repository.saveClipSequence(project.id, invalidMissingCandidate),
      throwsA(isA<FormatException>()),
    );

    final invalidRange = ClipSequence(
      schemaVersion: valid.schemaVersion,
      sourceDurationMs: valid.sourceDurationMs,
      tracks: valid.tracks,
      clips: const [
        ClipSequenceItem(
          id: 'item_range',
          candidateId: 'clip_001',
          trackId: 'track_video_main',
          sourceStartMs: 900,
          sourceEndMs: 3000,
          timelineStartMs: 0,
        ),
      ],
    );
    await expectLater(
      repository.saveClipSequence(project.id, invalidRange),
      throwsA(isA<FormatException>()),
    );
  });

  test('invalid saved sequence is rejected when loaded from its sidecar', () async {
    final project = await prepareProject();
    final artifactDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}${project.id}',
    );
    await artifactDirectory.create(recursive: true);
    final sequenceFile = File(
      '${artifactDirectory.path}${Platform.pathSeparator}sequence.json',
    );
    await sequenceFile.writeAsString('{"schemaVersion":99}');
    await expectLater(
      repository.loadClipSequence(project.id),
      throwsA(isA<FormatException>()),
    );
  });
}
