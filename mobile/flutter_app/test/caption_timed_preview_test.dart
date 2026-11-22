import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/screens/features/caption_studio_page.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _TranscriptPreviewRepository extends LocalProjectRepository {
  _TranscriptPreviewRepository(this.transcript);

  final CutawanTranscript transcript;

  @override
  Future<CutawanTranscript?> loadTranscript(String projectId) async =>
      transcript;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Caption Studio previews saved transcript groups using word timing',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final now = DateTime.utc(2026, 11, 21);
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
      final transcript = CutawanTranscript(
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
      );
      final repository = _TranscriptPreviewRepository(transcript);
      final projects = ValueNotifier<List<CutawanProject>>([
        CutawanProject.create(
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
        ),
      ]);
      addTearDown(projects.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: false,
              child: CaptionStudioPage(
                projects: projects,
                repository: repository,
                onProjectsChanged: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('معاينة متزامنة مع الكلمات'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('caption-timed-group-selector')),
        findsOneWidget,
      );
      final firstGroupLabel = tester.widget<Text>(
        find.byKey(const ValueKey('caption-timed-group-label')),
      );
      expect(firstGroupLabel.data, startsWith('المجموعة 1 من '));

      final groupPicker = tester.widget<DropdownButton<int>>(
        find.byKey(const ValueKey('caption-timed-group-selector')),
      );
      expect(groupPicker.value, 0);
      expect(groupPicker.onChanged, isNotNull);
      groupPicker.onChanged!(1);
      await tester.pump();

      final secondGroupLabel = tester.widget<Text>(
        find.byKey(const ValueKey('caption-timed-group-label')),
      );
      expect(secondGroupLabel.data, startsWith('المجموعة 2 من '));
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
