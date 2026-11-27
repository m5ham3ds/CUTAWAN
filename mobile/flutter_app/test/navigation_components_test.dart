import 'dart:ui' show SemanticsAction;

import 'package:flutter/services.dart';

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
            final data = tester.getSemantics(finder).getSemanticsData();
            expect(data.flagsCollection.isButton, isTrue);
            expect(
              (data.actions & SemanticsAction.tap.index) != 0,
              isTrue,
            );
            expect(
              data.flagsCollection.toStrings().contains('isSelected'),
              label == 'Projects',
            );
          }
          expect(tester.takeException(), isNull);
        }
      }
      semantics.dispose();
    },
  );

  testWidgets(
    'global top bar keeps only the settings destination',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var settingsTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          home: Scaffold(
            body: Directionality(
              textDirection: TextDirection.rtl,
              child: Align(
                alignment: Alignment.topCenter,
                child: CutawanTopBar(
                  onRefresh: () async {},
                  onSettings: () => settingsTaps++,
                ),
              ),
            ),
          ),
        ),
      );

      expect(find.byTooltip('الإعدادات'), findsOneWidget);
      expect(tester.getSize(find.byTooltip('الإعدادات')), const Size(48, 48));
      expect(find.byTooltip('تشخيص الجهاز'), findsNothing);
      expect(find.byTooltip('مركز النماذج'), findsNothing);

      await tester.tap(find.byTooltip('الإعدادات'));
      expect(settingsTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );


  testWidgets(
    'navigation and top bar remain usable with 200 percent text at 320dp',
    (tester) async {
      tester.view.physicalSize = const Size(320, 720);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var settingsTaps = 0;
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(320, 720),
              textScaler: TextScaler.linear(2),
            ),
            child: Directionality(
              textDirection: TextDirection.rtl,
              child: Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      CutawanTopBar(
                        onRefresh: () async {},
                        onSettings: () => settingsTaps++,
                      ),
                      const Expanded(child: SizedBox.expand()),
                    ],
                  ),
                ),
                bottomNavigationBar: CutawanNavigationBar(
                  selectedIndex: 0,
                  onSelected: (_) {},
                  destinations: _destinations,
                  animation: const AlwaysStoppedAnimation<double>(1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(
        tester.getSize(find.byTooltip('الإعدادات')),
        const Size(48, 48),
      );
      expect(find.byTooltip('تشخيص الجهاز'), findsNothing);
      expect(find.byTooltip('مركز النماذج'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Dashboard')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('Captions')), findsOneWidget);
      await tester.tap(find.byTooltip('الإعدادات'));
      expect(settingsTaps, 1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'primary navigation supports keyboard focus and activation',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      var selected = -1;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            bottomNavigationBar: CutawanNavigationBar(
              selectedIndex: 4,
              onSelected: (value) => selected = value,
              destinations: _destinations,
              animation: const AlwaysStoppedAnimation<double>(1),
            ),
          ),
        ),
      );
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();

      expect(selected, 0);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'landscape navigation respects horizontal and bottom safe-area insets',
    (tester) async {
      tester.view.physicalSize = const Size(720, 320);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      const insets = EdgeInsets.fromLTRB(24, 10, 24, 24);
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.dark(),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(720, 320),
              padding: insets,
              viewPadding: insets,
            ),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Scaffold(
                body: SafeArea(
                  child: Column(
                    children: [
                      CutawanTopBar(
                        onRefresh: () async {},
                        onSettings: () {},
                      ),
                      const Expanded(child: SizedBox.expand()),
                    ],
                  ),
                ),
                bottomNavigationBar: CutawanNavigationBar(
                  selectedIndex: 2,
                  onSelected: (_) {},
                  destinations: _destinations,
                  animation: const AlwaysStoppedAnimation<double>(1),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final navigationSurface = find.descendant(
        of: find.byType(CutawanNavigationBar),
        matching: find.byType(ClipRect),
      );
      expect(navigationSurface, findsOneWidget);
      final rect = tester.getRect(navigationSurface);
      expect(rect.left, 0);
      expect(rect.right, 720);
      // The visual surface is edge-to-edge, including the transparent system
      // navigation inset; interactive destination targets remain above it.
      expect(rect.bottom, 320);

      final selectedDestination =
          tester.getRect(find.bySemanticsLabel(RegExp('Projects')));
      expect(selectedDestination.left, greaterThanOrEqualTo(24));
      expect(selectedDestination.right, lessThanOrEqualTo(696));
      expect(selectedDestination.bottom, lessThanOrEqualTo(296));
      expect(tester.takeException(), isNull);
    },
  );

}
