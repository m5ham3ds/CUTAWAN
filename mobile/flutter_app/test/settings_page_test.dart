import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/app_preferences.dart';
import 'package:cutawan_mobile/screens/features/settings_page.dart';
import 'package:cutawan_mobile/services/app_preferences_store.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

Future<void> _scrollSettingsUntilFound(
  WidgetTester tester,
  Finder target, {
  double distance = 480,
  int maxSwipes = 12,
}) async {
  final list = find.byKey(const ValueKey('cutawan-settings-list'));
  final scrollableFinder = find.descendant(
    of: list,
    matching: find.byType(Scrollable),
  ).first;
  final position = tester.state<ScrollableState>(scrollableFinder).position;
  final viewport = tester.getRect(list);

  for (var attempt = 0; attempt < maxSwipes; attempt++) {
    if (tester.any(target) && tester.getRect(target).overlaps(viewport)) {
      return;
    }

    final nextOffset = (position.pixels + distance)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    if (nextOffset <= position.pixels) break;
    position.jumpTo(nextOffset);
    await tester.pump();
  }

  expect(
    target,
    findsOneWidget,
    reason: 'Settings list did not build the target within $maxSwipes scroll steps.',
  );
  expect(
    tester.getRect(target).overlaps(viewport),
    isTrue,
    reason: 'Settings target was built but remained outside the visible list viewport.',
  );
}




void main() {
  testWidgets(
    'CUTAWAN settings fit narrow and wide screens with enlarged text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final store = AppPreferencesStore.inMemory();
      addTearDown(store.dispose);
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
                child: SettingsPage(
                  store: store,
                  onDiagnostics: () {},
                  onModels: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        expect(find.text('إعدادات CUTAWAN'), findsOneWidget);
        await _scrollSettingsUntilFound(tester, find.text('الخصوصية والمعالجة'));
        expect(find.text('الخصوصية والمعالجة'), findsOneWidget);
        await _scrollSettingsUntilFound(tester, find.text('المعلومات القانونية'));
        expect(find.text('المعلومات القانونية'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.pumpWidget(const SizedBox.shrink());
      }
    },
  );

  testWidgets('settings routes open diagnostics and the models center',
      (tester) async {
    var diagnostics = 0;
    var models = 0;
    final store = AppPreferencesStore.inMemory();
    addTearDown(store.dispose);
    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: SettingsPage(
          store: store,
          onDiagnostics: () => diagnostics++,
          onModels: () => models++,
        ),
      ),
    );
    await tester.pump();

    final diagnosticsTile = find.text('تشخيص وقبول Android');
    await _scrollSettingsUntilFound(tester, diagnosticsTile, distance: 360);
    await tester.tap(diagnosticsTile);
    final modelsTile = find.text('مركز النماذج والاتصالات');
    await _scrollSettingsUntilFound(tester, modelsTile, distance: 360);
    await tester.tap(modelsTile);

    expect(diagnostics, 1);
    expect(models, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'theme mode and reduced motion controls persist on this device',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = AppPreferencesStore.inMemory();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          darkTheme: CutawanTheme.dark(),
          home: SettingsPage(
            store: store,
            onDiagnostics: () {},
            onModels: () {},
          ),
        ),
      );
      await tester.pump();

      final darkTheme = find.byKey(
        const ValueKey('settings-theme-dark'),
      );
      await _scrollSettingsUntilFound(tester, darkTheme, distance: 360);
      await tester.tap(darkTheme);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.preferences.value.themeMode, AppThemeMode.dark);

      final reduceMotion = find.byKey(
        const ValueKey('settings-reduce-motion'),
      );
      await _scrollSettingsUntilFound(tester, reduceMotion, distance: 300);
      await tester.tap(reduceMotion);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.preferences.value.reduceMotion, isTrue);


    },
  );

}
