import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/screens/features/dashboard_page.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';


CutawanProject _makeDashboardProject(String name) {
  final now = DateTime.utc(2026, 11, 22);
  return CutawanProject.create(
    source: VideoAssetMetadata(
      uri: 'content://media/external/video/101',
      displayName: '$name.mp4',
      mimeType: 'video/mp4',
      sizeBytes: 1024 * 1024,
      durationMs: 60000,
      width: 1920,
      height: 1080,
      rotationDegrees: 0,
      importedAtUtc: now,
    ),
    preferences: const ClipPreferences(),
    now: now,
  );
}

void main() {
  testWidgets(
    'dashboard remains readable and overflow-free across compact and wide viewports',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final cases = <({
        Size size,
        TextDirection direction,
        ThemeData theme,
        double scale,
      })>[
        (
          size: const Size(320, 720),
          direction: TextDirection.rtl,
          theme: CutawanTheme.light(),
          scale: 2,
        ),
        (
          size: const Size(390, 844),
          direction: TextDirection.ltr,
          theme: CutawanTheme.dark(),
          scale: 1.5,
        ),
        (
          size: const Size(720, 900),
          direction: TextDirection.rtl,
          theme: CutawanTheme.dark(),
          scale: 1,
        ),
      ];

      for (final item in cases) {
        tester.view.physicalSize = item.size;
        tester.view.devicePixelRatio = 1;
        final projects = ValueNotifier<List<CutawanProject>>([]);
        await tester.pumpWidget(
          MaterialApp(
            theme: item.theme,
            home: MediaQuery(
              data: MediaQueryData(
                size: item.size,
                textScaler: TextScaler.linear(item.scale),
              ),
              child: Directionality(
                textDirection: item.direction,
                child: Scaffold(
                  body: DashboardPage(
                    projects: projects,
                    onCreate: () {},
                    onOpenJobs: () {},
                    onOpenReview: () {},
                    onOpenSettings: () {},
                    onOpenProject: (_) {},
                    storageUsageBytes: () async => 2 * 1024 * 1024,
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('مرحباً بك في CUTAWAN'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('نظرة عامة'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('نظرة عامة'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('لا توجد مشاريع محفوظة بعد'),
          240,
          scrollable: find.byType(Scrollable).first,
        );
        expect(find.text('لا توجد مشاريع محفوظة بعد'), findsOneWidget);
        expect(tester.takeException(), isNull);

        await tester.pumpWidget(const SizedBox.shrink());
        projects.dispose();
      }
    },
  );

  testWidgets('dashboard routes invoke their intended callbacks',
      (tester) async {
    var create = 0;
    var settings = 0;
    var jobs = 0;
    var review = 0;
    final project = _makeDashboardProject('dashboard-resume');
    final projects = ValueNotifier<List<CutawanProject>>([project]);
    var openedProjectId = '';
    var storageReads = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: Scaffold(
          body: DashboardPage(
            projects: projects,
            onCreate: () => create++,
            onOpenJobs: () => jobs++,
            onOpenReview: () => review++,
            onOpenSettings: () => settings++,
            onOpenProject: (project) => openedProjectId = project.id,
            storageUsageBytes: () async {
              storageReads++;
              return 2 * 1024 * 1024;
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // The settings action is in the dashboard header. Tap it before
    // scrolling the ListView so its lazy child remains mounted.
    final settingsButton = find.byTooltip('الإعدادات');
    expect(settingsButton, findsOneWidget);
    await tester.tap(settingsButton);
    await tester.pump();

    final createButton = find.byKey(
      const ValueKey('dashboard-create-project'),
    );
    await tester.scrollUntilVisible(
      createButton,
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(createButton);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('dashboard-storage-card')),
      180,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    expect(find.text('2.0 MB'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-refresh-storage')));
    await tester.pumpAndSettle();
    expect(storageReads, 2);
    expect(find.text('مركز النماذج'), findsNothing);
    for (final label in ['المهام والمشاريع', 'المراجعة والتحرير']) {
      final finder = find.text(label);
      await tester.scrollUntilVisible(
        finder,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle();
      await tester.tap(finder);
    }

    expect(create, 1);
    expect(settings, 1);
    expect(jobs, 1);
    expect(review, 1);

    final projectTile = find.byKey(
      ValueKey('dashboard-project-${project.id}'),
    );
    await tester.scrollUntilVisible(
      projectTile,
      220,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(projectTile);
    expect(openedProjectId, project.id);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    projects.dispose();
  });
}
