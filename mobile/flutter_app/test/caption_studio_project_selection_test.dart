import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/screens/features/caption_studio_page.dart';
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

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caption-style-neon')),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      final selectedNeon = tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('caption-style-neon')),
      );
      expect(selectedNeon.selected, isTrue);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caption-editor-section-tabs')),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(
        find.byKey(const ValueKey('caption-editor-tab-motion')),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('caption-style-presets')), findsNothing);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caption-animation-fade')),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.byKey(const ValueKey('caption-animation-fade')));
      await tester.pump(const Duration(milliseconds: 50));
      expect(find.textContaining('مثال بصري فقط؛ سيحفظ تأثير التصدير على Static.'), findsOneWidget);

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caption-timing-offset-label')),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      expect(
        tester.widget<Text>(
          find.byKey(const ValueKey('caption-timing-offset-label')),
        ).data,
        contains('+125 ms'),
      );
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caption-timing-offset')),
        320,
        scrollable: find.byType(Scrollable).first,
      );
      final timingSlider = tester.widget<Slider>(
        find.byKey(const ValueKey('caption-timing-offset')),
      );
      timingSlider.onChanged!(-600);
      await tester.pump();

      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('caption-studio-save')),
        320,
        scrollable: find.byType(Scrollable).first,
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

  testWidgets(
    'Caption Studio pins the synchronized preview while the editor scrolls',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final project = _makeProject(
        name: 'pinned-preview',
        preferences: const ClipPreferences(captionStyleId: 'beast'),
      );
      final projects = ValueNotifier<List<CutawanProject>>([project]);
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

      final preview = find.byKey(const ValueKey('caption-preview-pinned'));
      final previewTitle = find.text('معاينة متزامنة مع الكلمات');
      expect(preview, findsOneWidget);
      expect(tester.getTopLeft(preview).dy, greaterThan(0));

      final scrollable = find.byType(Scrollable).first;
      await tester.drag(scrollable, const Offset(0, -1400));
      await tester.pumpAndSettle();
      final pinnedTitleTop = tester.getTopLeft(previewTitle).dy;
      expect(pinnedTitleTop, lessThan(40));

      await tester.drag(scrollable, const Offset(0, -360));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(previewTitle).dy, closeTo(pinnedTitleTop, 1));
      expect(find.byKey(const ValueKey('caption-editor-section-tabs')), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Caption Studio editor tabs show only the selected control group',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
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

      expect(find.byKey(const ValueKey('caption-style-presets')), findsOneWidget);
      expect(find.byKey(const ValueKey('caption-animation-presets')), findsNothing);
      expect(find.byKey(const ValueKey('caption-font-family')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('caption-editor-tab-motion')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('caption-animation-presets')), findsOneWidget);
      expect(find.byKey(const ValueKey('caption-style-presets')), findsNothing);
      expect(find.byKey(const ValueKey('caption-font-family')), findsNothing);

      await tester.tap(find.byKey(const ValueKey('caption-editor-tab-typography')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('caption-font-family')), findsOneWidget);
      expect(find.byKey(const ValueKey('caption-style-presets')), findsNothing);
      expect(find.byKey(const ValueKey('caption-animation-presets')), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'Caption Studio help hints start as one line and expand on demand',
    (tester) async {
      tester.view.physicalSize = const Size(430, 932);
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

      final previewText = find.byKey(const ValueKey('caption-preview-hint-text'));
      expect(previewText, findsOneWidget);
      expect(tester.widget<Text>(previewText).maxLines, 1);
      expect(find.textContaining('اختر مشروعاً بعد إنشائه'), findsOneWidget);

      final previewHintToggle = find.byKey(
        const ValueKey('caption-preview-hint-toggle'),
      );
      await tester.ensureVisible(previewHintToggle);
      await tester.pumpAndSettle();
      await tester.tap(previewHintToggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(previewText).maxLines, isNull);
      expect(find.textContaining('Karaoke Fill'), findsOneWidget);
      expect(find.textContaining('Live video playback synchronisation'), findsOneWidget);

      await tester.ensureVisible(previewHintToggle);
      await tester.pumpAndSettle();
      await tester.tap(previewHintToggle);
      await tester.pumpAndSettle();
      expect(tester.widget<Text>(previewText).maxLines, 1);
      expect(tester.takeException(), isNull);
    },
  );
}
