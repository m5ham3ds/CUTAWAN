import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/clip_sequence.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/screens/features/clip_sequence_editor_page.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';

class _MemorySequenceRepository extends LocalProjectRepository {
  ClipSequence? sequence;

  @override
  Future<void> saveClipSequence(
    String projectId,
    ClipSequence sequence,
  ) async {
    this.sequence = sequence;
  }

  @override
  Future<ClipSequence?> loadClipSequence(String projectId) async => sequence;
}

Future<void> pumpSequenceTransition(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
  await tester.pump();
}

Future<void> tapSequenceControl(
  WidgetTester tester,
  Finder finder,
) async {
  await tester.tapAt(tester.getCenter(finder));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MemorySequenceRepository repository;
  late CutawanProject project;
  late CandidateSet candidateSet;

  setUp(() async {
    repository = _MemorySequenceRepository();
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
  });

  Widget buildPage({Future<void> Function()? onSaved}) => MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: ClipSequenceEditorPage(
            project: project,
            candidateSet: candidateSet,
            repository: repository,
            onSaved: onSaved ?? () async {},
            initialSequence: ClipSequence.empty(
              sourceDurationMs: project.source.durationMs,
            ),
          ),
        ),
      );

  testWidgets('track UI adds candidate clips and persists the sequence', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.pump();
    expect(find.text('Main video'), findsOneWidget);
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-add-clip-track_video_main')));
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-candidate-choice-clip_001')));
    await pumpSequenceTransition(tester);

    expect(find.byKey(const ValueKey('sequence-item-item_1')), findsOneWidget);
    final exportButton = find.byKey(const ValueKey('sequence-export-button'));
    await tester.scrollUntilVisible(exportButton, 280);
    await pumpSequenceTransition(tester);
    expect(exportButton, findsOneWidget);
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-save-button')));
    await pumpSequenceTransition(tester);

    final restored = await repository.loadClipSequence(project.id);
    expect(restored, isNotNull);
    expect(restored!.clips, hasLength(1));
    expect(restored.clips.single.candidateId, 'clip_001');
  });


  testWidgets('adjacent video clips can receive and persist a dip-to-black transition',
      (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.pump();
    final add = find.byKey(
      const ValueKey('sequence-add-clip-track_video_main'),
    );
    await tapSequenceControl(tester, add);
    await pumpSequenceTransition(tester);
    await tapSequenceControl(
      tester,
      find.byKey(const ValueKey('sequence-candidate-choice-clip_001')),
    );
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, add);
    await pumpSequenceTransition(tester);
    await tapSequenceControl(
      tester,
      find.byKey(const ValueKey('sequence-candidate-choice-clip_002')),
    );
    await pumpSequenceTransition(tester);

    final transition = find.byKey(
      const ValueKey('sequence-transition-item_1'),
    );
    expect(transition, findsOneWidget);
    await tapSequenceControl(tester, transition);
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, find.text('تعتيم 800 ms'));
    await pumpSequenceTransition(tester);

    await tapSequenceControl(
      tester,
      find.byKey(const ValueKey('sequence-save-button')),
    );
    await pumpSequenceTransition(tester);

    final restored = await repository.loadClipSequence(project.id);
    expect(restored, isNotNull);
    expect(restored!.clips, hasLength(2));
    expect(restored.clips.first.transitionAfter?.type,
        ClipSequenceTransitionType.dipToBlack);
    expect(restored.clips.first.transitionAfter?.durationMs, 800);
    expect(tester.takeException(), isNull);
  });

  testWidgets('sequence UI adds typed tracks and allows cross-track timing overlap', (tester) async {
    tester.view.physicalSize = const Size(390, 900);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.pump();
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-add-track-audio')));
    await pumpSequenceTransition(tester);

    expect(find.text('مسار صوتي 1'), findsOneWidget);
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-add-clip-track_audio_1')));
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-candidate-choice-clip_001')));
    await pumpSequenceTransition(tester);

    expect(find.byKey(const ValueKey('sequence-item-item_1')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('attempted same-track overlap is rejected without losing the previous position', (tester) async {
    tester.view.physicalSize = const Size(390, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(buildPage());
    await tester.pump();
    final add = find.byKey(const ValueKey('sequence-add-clip-track_video_main'));
    await tapSequenceControl(tester, add);
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-candidate-choice-clip_001')));
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, add);
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, find.byKey(const ValueKey('sequence-candidate-choice-clip_002')));
    await pumpSequenceTransition(tester);

    final moveLeft = find.byKey(const ValueKey('sequence-move-left-item_2'));
    await tester.ensureVisible(moveLeft);
    await pumpSequenceTransition(tester);
    await tapSequenceControl(tester, moveLeft);
    await pumpSequenceTransition(tester);

    expect(find.textContaining('لا يمكن تحريك المقطع فوق مقطع آخر'), findsOneWidget);
    final savedSequence = await repository.loadClipSequence(project.id);
    expect(savedSequence, isNull);
    expect(tester.takeException(), isNull);
  });
}
