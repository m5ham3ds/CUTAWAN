import 'dart:io';

import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/domain/reframe_contract.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late Directory directory;
  late LocalProjectRepository repository;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cutawan-analysis-');
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
        displayName: 'analysis.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 1000000,
        durationMs: 30000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      ),
      preferences: const ClipPreferences(
        requestedClipCount: 1,
        durationMode: ClipDurationMode.seconds15To30,
      ),
      now: now,
    );
  }

  CutawanTranscript makeTranscript() => CutawanTranscript(
        schemaVersion: CutawanTranscript.currentSchemaVersion,
        language: 'en',
        text: 'This is a complete sentence.',
        sourceDurationMs: 30000,
        createdAtUtc: DateTime.utc(2026, 11, 20),
        segments: const [
          TranscriptSegment(
            text: 'This is a complete sentence.',
            startMs: 0,
            endMs: 18000,
            words: [
              TranscriptWord(text: 'This', startMs: 0, endMs: 1800),
              TranscriptWord(text: 'is', startMs: 2000, endMs: 3500),
              TranscriptWord(text: 'a', startMs: 4000, endMs: 5000),
              TranscriptWord(text: 'complete', startMs: 6000, endMs: 11000),
              TranscriptWord(text: 'sentence.', startMs: 12000, endMs: 18000),
            ],
          ),
        ],
        audioEnergy: const [],
        visualSamples: const [],
        wordTimingReliable: true,
        whisperModelId: 'base',
      );

  CandidateSet makeCandidates() => CandidateSet(
        schemaVersion: CandidateSet.currentSchemaVersion,
        sourceDurationMs: 30000,
        createdAtUtc: DateTime.utc(2026, 11, 20),
        candidates: const [
          ClipCandidate(
            id: 'clip_0_18000',
            startMs: 0,
            endMs: 18000,
            score: 82,
            title: 'Complete sentence',
            hook: 'This is a complete sentence.',
            summary: 'A complete sentence.',
            explanations: ['Transcript evidence'],
            transcriptText: 'This is a complete sentence.',
            averageAudioEnergy: 0,
            peakVisualChange: 0,
          ),
        ],
        transcriptEvidence: true,
        audioEvidence: false,
        visualEvidence: false,
        rankingEngine: 'deterministic-evidence-v1',
      );

  ReframePlan makeReframePlan() => const ReframePlan(
        schemaVersion: ReframePlan.currentSchemaVersion,
        sourceDurationMs: 30000,
        aspectRatio: 9 / 16,
        shots: [
          ReframeShot(
            startMs: 0,
            endMs: 30000,
            mode: 'fit',
            confidence: 0,
            reviewReason: 'No confident frontal face track.',
          ),
        ],
        focusTrack: null,
        fallbackReason: 'No confident frontal face track.',
        engine: 'android-frontal-face-tracker-v1',
      );

  test('reframe plans persist as validated per-project artifacts', () async {
    final project = makeProject();
    await repository.save(project);
    final plan = makeReframePlan();
    await repository.saveReframePlan(project.id, plan);

    final restored = await repository.loadReframePlan(project.id);

    expect(restored, isNotNull);
    expect(restored!.shots.single.mode, 'fit');
    expect(restored.fallbackReason, contains('frontal face'));
    expect(restored.sourceDurationMs, project.source.durationMs);
  });

  test('reframe plans reject invalid source duration and uncovered timelines', () async {
    final project = makeProject();
    await repository.save(project);
    final valid = makeReframePlan();
    final mismatched = ReframePlan(
      schemaVersion: valid.schemaVersion,
      sourceDurationMs: 40000,
      aspectRatio: valid.aspectRatio,
      shots: valid.shots,
      focusTrack: valid.focusTrack,
      fallbackReason: valid.fallbackReason,
      engine: valid.engine,
    );

    await expectLater(
      repository.saveReframePlan(project.id, mismatched),
      throwsA(isA<FormatException>()),
    );
    final invalid = ReframePlan(
      schemaVersion: valid.schemaVersion,
      sourceDurationMs: valid.sourceDurationMs,
      aspectRatio: valid.aspectRatio,
      shots: const [
        ReframeShot(startMs: 0, endMs: 10000, mode: 'fit'),
      ],
      focusTrack: null,
      fallbackReason: 'test',
      engine: 'test',
    );
    expect(invalid.validate, throwsA(isA<FormatException>()));
  });

  test('transcript and candidates persist outside the project index', () async {
    final project = makeProject();
    await repository.save(project);
    await repository.saveTranscript(project.id, makeTranscript());
    await repository.saveCandidates(project.id, makeCandidates());

    final restoredTranscript = await repository.loadTranscript(project.id);
    final restoredCandidates = await repository.loadCandidates(project.id);

    expect(restoredTranscript?.text, 'This is a complete sentence.');
    expect(restoredTranscript?.words, hasLength(5));
    expect(restoredCandidates?.candidates.single.id, 'clip_0_18000');
    expect(await repository.listProjects(), hasLength(1));
  });

  test('source duration mismatch is rejected for saved analysis artifacts', () async {
    final project = makeProject();
    await repository.save(project);
    final invalid = makeTranscript();
    final mismatch = CutawanTranscript(
      schemaVersion: invalid.schemaVersion,
      language: invalid.language,
      text: invalid.text,
      sourceDurationMs: 40000,
      createdAtUtc: invalid.createdAtUtc,
      segments: invalid.segments,
      audioEnergy: invalid.audioEnergy,
      visualSamples: invalid.visualSamples,
      wordTimingReliable: invalid.wordTimingReliable,
      whisperModelId: invalid.whisperModelId,
    );

    await expectLater(
      repository.saveTranscript(project.id, mismatch),
      throwsA(isA<FormatException>()),
    );
  });

  test('deleting a project also removes its transcript and candidate artifacts', () async {
    final project = makeProject();
    await repository.save(project);
    await repository.saveTranscript(project.id, makeTranscript());
    await repository.saveCandidates(project.id, makeCandidates());
    final artifactDirectory = Directory(
      '${directory.path}${Platform.pathSeparator}artifacts'
      '${Platform.pathSeparator}${project.id}',
    );
    expect(await artifactDirectory.exists(), isTrue);

    await repository.delete(project.id);

    expect(await repository.load(project.id), isNull);
    expect(await artifactDirectory.exists(), isFalse);
  });
}
