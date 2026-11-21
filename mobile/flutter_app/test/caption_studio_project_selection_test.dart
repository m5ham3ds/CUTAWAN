import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/screens/home_shell.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _MemoryCaptionRepository extends LocalProjectRepository {
  final Map<String, CutawanProject> savedProjects = {};

  @override
  Future<void> save(CutawanProject project) async {
    savedProjects[project.id] = project;
  }

  @override
  Future<CutawanTranscript?> loadTranscript(String projectId) async => null;
}

CutawanProject _makeProject({
  required String name,
  required ClipPreferences preferences,
}) {
  final now = DateTime.utc(2026, 11, 21);
  return CutawanProject.create(
    source: VideoAssetMetadata(
      uri: 'content://media/external/video/${name.hashCode.abs()}',
      displayName: '$name.mp4',
      mimeType: 'video/mp4',
      sizeBytes: 1024 * 1024,
      durationMs: 12000,
      width: 1920,
      height: 1080,
      rotationDegrees: 0,
      importedAtUtc: now,
    ),
    preferences: preferences,
    now: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Caption Studio loads and saves preferences to the explicitly selected project',
    (tester) async {
      tester.view.physicalSize = const Size(430, 1200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final first = _makeProject(
        name: 'first-project',
        preferences: const ClipPreferences(captionStyleId: 'beast'),
      );
      final second = _makeProject(
        name: 'second-project',
        preferences: const ClipPreferences(
          captionStyleId: 'neon',
          captionAnimationId: 'word_pop',
          captionFontFamily: 'Poppins',
          captionFontScale: 0.061,
          captionPositionY: 0.77,
          captionTimingOffsetMs: 125,
          captionBackgroundColor: '#2563EB',
        ),
      );
      final projects = ValueNotifier<List<CutawanProject>>([first, second]);
      addTearDown(projects.dispose);
      final repository = _MemoryCaptionRepository();

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

      final projectPicker = tester.widget<DropdownButtonFormField<String>>(
        find.descendant(
          of: find.byKey(const ValueKey('caption-project-selector')),
          matching: find.byWidgetPredicate(
            (widget) => widget is DropdownButtonFormField<String>,
          ),
        ),
      );
      expect(projectPicker.initialValue, first.id);
      projectPicker.onChanged!(second.id);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final selectedNeon = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('caption-style-neon')),
      );
      expect(selectedNeon.selected, isTrue);
      expect(
        tester.widget<Text>(
          find.byKey(const ValueKey('caption-timing-offset-label')),
        ).data,
        contains('+125 ms'),
      );

      await tester.ensureVisible(
        find.byKey(const ValueKey('caption-animation-fade')),
      );
      await tester.tap(find.byKey(const ValueKey('caption-animation-fade')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('للمعاينة فقط'), findsWidgets);

      final timingSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('caption-timing-offset')),
      );
      timingSlider.onChanged!(-600);
      await tester.pump();

      await tester.ensureVisible(
        find.byKey(const ValueKey('caption-studio-save')),
      );
      await tester.tap(find.byKey(const ValueKey('caption-studio-save')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(repository.savedProjects.keys.toList(), [second.id]);
      final saved = repository.savedProjects[second.id]!;
      expect(saved.preferences.captionStyleId, 'neon');
      expect(saved.preferences.captionAnimationId, 'static');
      expect(saved.preferences.captionPreviewAnimationId, 'fade');
      expect(saved.preferences.captionPreviewAnimationId, 'fade');
      expect(saved.preferences.captionTimingOffsetMs, -600);
      expect(saved.preferences.captionFontFamily, 'Poppins');
      expect(saved.preferences.captionFontScale, 0.061);
      expect(saved.preferences.captionPositionY, 0.77);
      expect(saved.preferences.captionBackgroundColor, '#2563EB');
      expect(repository.savedProjects.containsKey(first.id), isFalse);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Caption Studio remains usable in a 320dp phone viewport without projects',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final projects = ValueNotifier<List<CutawanProject>>([]);
      addTearDown(projects.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: TickerMode(
              enabled: false,
              child: CaptionStudioPage(
                projects: projects,
                repository: _MemoryCaptionRepository(),
                onProjectsChanged: () async {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.text('مختبر الهوية النصية'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
}
