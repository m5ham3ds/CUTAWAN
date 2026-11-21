import 'dart:io';

import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/screens/home_shell.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory root;
  late LocalProjectRepository repository;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('cutawan-caption-timed-');
    repository = LocalProjectRepository(rootDirectory: root);
  });

  tearDown(() async {
    if (await root.exists()) await root.delete(recursive: true);
  });

  testWidgets(
    'Caption Studio previews saved transcript groups using word timing',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 3200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final projects = ValueNotifier<List<CutawanProject>>([]);
      addTearDown(projects.dispose);
      final now = DateTime.utc(2026, 11, 21);
      final project = CutawanProject.create(
        source: VideoAssetMetadata(
          uri: 'content://media/external/video/media/caption-preview',
          displayName: 'caption-preview.mp4',
          mimeType: 'video/mp4',
          sizeBytes: 1000000,
          durationMs: 5000,
          width: 1080,
          height: 1920,
          rotationDegrees: 0,
          importedAtUtc: now,
        ),
        preferences: const ClipPreferences(
          aspectRatio: ClipAspectRatio.portrait916,
        ),
        now: now,
      );
      await repository.save(project);

      const words = [
        TranscriptWord(
          text: 'مرحباً',
          startMs: 0,
          endMs: 350,
          probability: 0.95,
        ),
        TranscriptWord(
          text: 'بك.',
          startMs: 360,
          endMs: 700,
          probability: 0.95,
        ),
        TranscriptWord(
          text: 'هذا',
          startMs: 2000,
          endMs: 2300,
          probability: 0.94,
        ),
        TranscriptWord(
          text: 'تفريغ',
          startMs: 2350,
          endMs: 2600,
          probability: 0.93,
        ),
        TranscriptWord(
          text: 'فعلي.',
          startMs: 2650,
          endMs: 3000,
          probability: 0.92,
        ),
      ];
      final transcriptText = words.map((word) => word.text).join(' ');
      await repository.saveTranscript(
        project.id,
        CutawanTranscript(
          schemaVersion: CutawanTranscript.currentSchemaVersion,
          language: 'ar',
          text: transcriptText,
          sourceDurationMs: 5000,
          createdAtUtc: now,
          segments: [
            TranscriptSegment(
              text: transcriptText,
              startMs: 0,
              endMs: 3000,
              words: words,
            ),
          ],
          audioEnergy: const [],
          visualSamples: const [],
          wordTimingReliable: true,
          whisperModelId: 'base',
        ),
      );
      projects.value = [project];

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: CaptionStudioPage(
              projects: projects,
              repository: repository,
              onProjectsChanged: () async {},
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.text('معاينة من التفريغ المحفوظ'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('caption-timed-group-selector')),
        findsOneWidget,
      );
      expect(find.text('المجموعة 1 من 2'), findsOneWidget);

      await tester.tap(
        find.byKey(const ValueKey('caption-timed-group-selector')),
      );
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('مجموعة 2'), findsOneWidget);
      await tester.tap(find.text('مجموعة 2').last);
      await tester.pump(const Duration(milliseconds: 250));
      expect(find.text('المجموعة 2 من 2'), findsOneWidget);

      final visibleCaptions = tester.widgetList<RichText>(find.byType(RichText));
      expect(
        visibleCaptions.any(
          (item) => item.text.toPlainText().contains('هذا تفريغ فعلي.'),
        ),
        isTrue,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
