import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/screens/features/clip_sequence_editor_page.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory directory;
  late LocalProjectRepository repository;
  late CutawanProject project;
  late CandidateSet candidateSet;

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('cutawan-sequence-ui-');
    repository = LocalProjectRepository(rootDirectory: directory);
    final now = DateTime.utc(2026, 11, 24);
    project = CutawanProject.create(
      source: VideoAssetMetadata(
        uri: 'content://media/external/video/media/42',
        displayName: 'sequence-source.mp4',
        mimeType: 'video/mp4',
        sizeBytes: 4096,
        durationMs: 90000,
        width: 1920,
        height: 1080,
        rotationDegrees: 0,
        importedAtUtc: now,
      ),
      preferences: const ClipPreferences(),
      now: now,
    );
    candidateSet = CandidateSet(
      schemaVersion: CandidateSet.currentSchemaVersion,
      sourceDurationMs: 90000,
      createdAtUtc: now,
      candidates: [
        ClipCandidate(
          id: 'clip_001',
          startMs: 1000,
          endMs: 5000,
          score: 90,
          title: 'First segment',
          hook: 'Hook',
          summary: 'Summary',
          explanations: const [],
          transcriptText: 'First',
          averageAudioEnergy: 0.5,
          peakVisualChange: 0.4,
        ),
        ClipCandidate(
          id: 'clip_002',
          startMs: 8000,
          endMs: 14000,
          score: 80,
          title: 'Second segment',
          hook: 'Hook',
          summary: 'Summary',
          explanations: const [],
          transcriptText: 'Second',
          averageAudioEnergy: 0.4,
          peakVisualChange: 0.3,
        ),
      ],
      transcriptEvidence: true,
      audioEvidence: true,
      visualEvidence: true,
      rankingEngine: 'test',
    );
    await repository.save(project);
    await repository.saveCandidates(project.id, candidateSet);
  });

  tearDown(() async {
    if (await directory.exists()) await directory.delete(recursive: true);
  });

  Widget buildPage({Future<void> Function()? onSaved}) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ClipSequenceEditorPage(
            project: project,
            candidateSet: candidateSet,
            repository: repository,
            onSaved: onSaved ?? () async {},
          ),
        ),
      );

  testWidgets('track UI adds candidate clips and persists the sequence', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    expect(find.text('Main video'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sequence-add-clip-track_video_main')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sequence-candidate-choice-clip_001')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sequence-item-item_1')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sequence-save-button')));
    await tester.pumpAndSettle();

    final restored = await repository.loadClipSequence(project.id);
    expect(restored, isNotNull);
    expect(restored!.clips, hasLength(1));
    expect(restored.clips.single.candidateId, 'clip_001');
  });

  testWidgets('sequence UI adds typed tracks and allows cross-track timing overlap', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sequence-add-track-audio')));
    await tester.pumpAndSettle();

    expect(find.text('مسار صوتي 1'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('sequence-add-clip-track_audio_1')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sequence-candidate-choice-clip_001')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('sequence-item-item_1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attempted same-track overlap is rejected without losing the previous position', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.pumpAndSettle();
    final add = find.byKey(const ValueKey('sequence-add-clip-track_video_main'));
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sequence-candidate-choice-clip_001')));
    await tester.pumpAndSettle();
    await tester.tap(add);
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('sequence-candidate-choice-clip_002')));
    await tester.pumpAndSettle();

    final moveLeft = find.byKey(const ValueKey('sequence-move-left-item_2'));
    await tester.ensureVisible(moveLeft);
    await tester.pumpAndSettle();
    await tester.tap(moveLeft);
    await tester.pumpAndSettle();

    expect(find.textContaining('لا يمكن تحريك المقطع فوق مقطع آخر'), findsOneWidget);
    final savedSequence = await repository.loadClipSequence(project.id);
    expect(savedSequence, isNull);
    expect(tester.takeException(), isNull);
  });
}
