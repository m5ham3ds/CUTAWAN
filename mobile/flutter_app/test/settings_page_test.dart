import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/app_preferences.dart';
import 'package:cutawan_mobile/screens/features/settings_page.dart';
import 'package:cutawan_mobile/services/app_preferences_store.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

Future<AppPreferencesStore> _createStore(Directory directory) async {
  final store = AppPreferencesStore(
    directoryProvider: () async => directory,
  );
  await store.load();
  return store;
}

void main() {
  testWidgets(
    'CUTAWAN settings fit narrow and wide screens with enlarged text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = await Directory.systemTemp.createTemp(
        'cutawan-settings-layout-',
      );
      final store = await _createStore(directory);
      addTearDown(store.dispose);
      addTearDown(() => directory.delete(recursive: true));
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
        await tester.scrollUntilVisible(
          find.text('الخصوصية والمعالجة'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(find.text('الخصوصية والمعالجة'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('المعلومات القانونية'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
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
    final directory = await Directory.systemTemp.createTemp(
      'cutawan-settings-routes-',
    );
    final store = await _createStore(directory);
    addTearDown(store.dispose);
    addTearDown(() => directory.delete(recursive: true));
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
    await tester.scrollUntilVisible(
      diagnosticsTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
    await tester.tap(diagnosticsTile);
    final modelsTile = find.text('مركز النماذج والاتصالات');
    await tester.scrollUntilVisible(
      modelsTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();
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

      final directory = await Directory.systemTemp.createTemp(
        'cutawan-settings-persist-',
      );
      final store = await _createStore(directory);
      addTearDown(store.dispose);
      addTearDown(() => directory.delete(recursive: true));

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
      await tester.scrollUntilVisible(
        darkTheme,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(darkTheme);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.preferences.value.themeMode, AppThemeMode.dark);

      final reduceMotion = find.byKey(
        const ValueKey('settings-reduce-motion'),
      );
      await tester.scrollUntilVisible(
        reduceMotion,
        180,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await tester.tap(reduceMotion);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(store.preferences.value.reduceMotion, isTrue);

      final restoredStore = AppPreferencesStore(
        directoryProvider: () async => directory,
      );
      addTearDown(restoredStore.dispose);
      await restoredStore.load();
      expect(restoredStore.preferences.value.themeMode, AppThemeMode.dark);
      expect(restoredStore.preferences.value.reduceMotion, isTrue);
    },
  );

}
