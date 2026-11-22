import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/screens/features/dashboard_page.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

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
                    onOpenModels: () {},
                    onOpenSettings: () {},
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
    var models = 0;
    final projects = ValueNotifier<List<CutawanProject>>([]);

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: Scaffold(
          body: DashboardPage(
            projects: projects,
            onCreate: () => create++,
            onOpenJobs: () => jobs++,
            onOpenReview: () => review++,
            onOpenModels: () => models++,
            onOpenSettings: () => settings++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('dashboard-create-project')));
    await tester.tap(find.byTooltip('الإعدادات'));
    for (final label in ['المهام والمشاريع', 'المراجعة والتحرير', 'مركز النماذج']) {
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
    expect(models, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    projects.dispose();
  });
}
