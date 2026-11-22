import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/theme/cutawan_theme.dart';

import 'package:cutawan_mobile/screens/home_shell/navigation_components.dart';

const _destinations = <CutawanNavigationDestination>[
  (
    label: 'الرئيسية',
    icon: Icons.space_dashboard_outlined,
    selected: Icons.space_dashboard,
    hint: 'Dashboard',
  ),
  (
    label: 'إنشاء',
    icon: Icons.add_circle_outline,
    selected: Icons.add_circle,
    hint: 'Create',
  ),
  (
    label: 'المهام',
    icon: Icons.grid_view_outlined,
    selected: Icons.grid_view,
    hint: 'Projects',
  ),
  (
    label: 'المراجعة',
    icon: Icons.movie_outlined,
    selected: Icons.movie,
    hint: 'Review',
  ),
  (
    label: 'الاستوديو',
    icon: Icons.closed_caption_outlined,
    selected: Icons.closed_caption,
    hint: 'Captions',
  ),
];

Widget _navigationHarness({
  required int selectedIndex,
  required ValueChanged<int> onSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: CutawanNavigationBar(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        destinations: _destinations,
        animation: const AlwaysStoppedAnimation<double>(1),
      ),
    ),
  );
}

void main() {
  testWidgets('navigation tap emits the destination index', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      _navigationHarness(
        selectedIndex: 0,
        onSelected: (value) => selected = value,
      ),
    );

    await tester.tap(find.text('المهام'));
    expect(selected, 2);
  });

  testWidgets('destinations expose stable screen-reader labels', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _navigationHarness(
        selectedIndex: 2,
        onSelected: (_) {},
      ),
    );

    expect(find.bySemanticsLabel(RegExp('Dashboard')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Create')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Projects')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Review')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Captions')), findsOneWidget);
    semantics.dispose();
  });

  testWidgets(
    'navigation exposes 48dp semantic tap targets at 320dp in RTL/LTR and light/dark themes',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);
      for (final brightness in [Brightness.light, Brightness.dark]) {
        for (final direction in [TextDirection.rtl, TextDirection.ltr]) {
          await tester.pumpWidget(
            MaterialApp(
              theme: CutawanTheme.light(),
              darkTheme: CutawanTheme.dark(),
              themeMode: brightness == Brightness.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              home: Directionality(
                textDirection: direction,
                child: Scaffold(
                  bottomNavigationBar: CutawanNavigationBar(
                    selectedIndex: 2,
                    onSelected: (_) {},
                    destinations: _destinations,
                    animation: const AlwaysStoppedAnimation<double>(1),
                  ),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          for (final label in ['Dashboard', 'Create', 'Projects', 'Review', 'Captions']) {
            final finder = find.bySemanticsLabel(RegExp(label));
            expect(finder, findsOneWidget);
            final size = tester.getSize(finder);
            expect(size.height, greaterThanOrEqualTo(48));
            final node = tester.getSemantics(finder);
            expect(node.hasFlag(SemanticsFlag.isButton), isTrue);
            expect(node.hasAction(SemanticsAction.tap), isTrue);
            expect(
              node.hasFlag(SemanticsFlag.isSelected),
              label == 'Projects',
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
    },
  );

  testWidgets(
    'top bar actions provide 48dp labelled touch targets on a compact phone',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var settingsTaps = 0;
      var diagnosticsTaps = 0;
      var modelsTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Align(
                alignment: Alignment.topCenter,
                child: CutawanTopBar(
                  onModels: () => modelsTaps++,
                  onRefresh: () async {},
                  onDiagnostics: () => diagnosticsTaps++,
                  onSettings: () => settingsTaps++,
                ),
              ),
            ),
          ),
        ),
      );

      for (final tooltip in ['الإعدادات', 'تشخيص الجهاز', 'مركز النماذج']) {
        expect(find.byTooltip(tooltip), findsOneWidget);
        expect(
          tester.getSize(find.byTooltip(tooltip)),
          const Size(48, 48),
        );
      }
      await tester.tap(find.byTooltip('الإعدادات'));
      await tester.tap(find.byTooltip('تشخيص الجهاز'));
      await tester.tap(find.byTooltip('مركز النماذج'));
      expect(settingsTaps, 1);
      expect(diagnosticsTaps, 1);
      expect(modelsTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

}
