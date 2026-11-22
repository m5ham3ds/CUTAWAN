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


Future<T> _traceSettingsStep<T>(
  String label,
  Future<T> Function() action,
) async {
  print('[settings-test] $label:START');
  try {
    final result = await action().timeout(const Duration(seconds: 30));
    print('[settings-test] $label:DONE');
    return result;
  } catch (error) {
    print('[settings-test] $label:ERROR $error');
    rethrow;
  }
}

Future<void> _scrollSettingsUntilFound(
  WidgetTester tester,
  Finder target, {
  double distance = 480,
  int maxSwipes = 12,
}) async {
  print('[settings-scroll] START ${target.description}');
  final list = find.byKey(const ValueKey('cutawan-settings-list'));
  final scrollableFinder = find.descendant(
    of: list,
    matching: find.byType(Scrollable),
  ).first;
  final position = tester.state<ScrollableState>(scrollableFinder).position;
  final viewport = tester.getRect(list);

  for (var attempt = 0; attempt < maxSwipes; attempt++) {
    if (tester.any(target) && tester.getRect(target).overlaps(viewport)) {
      print('[settings-scroll] VISIBLE ${target.description}');
      return;
    }

    final nextOffset = (position.pixels + distance)
        .clamp(0.0, position.maxScrollExtent)
        .toDouble();
    if (nextOffset <= position.pixels) break;

    // jumpTo is synchronous; pump the frame before inspecting lazy children.
    // Awaiting ensureVisible before pumping can deadlock a widget test.
    print('[settings-scroll] step=$attempt from=${position.pixels} to=$nextOffset max=${position.maxScrollExtent}');
    position.jumpTo(nextOffset);
    await _traceSettingsStep('scroll-pump-$attempt', () => tester.pump());
  }

  print('[settings-scroll] EXHAUSTED ${target.description}');
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
      print('[settings-layout] START');
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final directory = await _traceSettingsStep('layout-create-temp', () => Directory.systemTemp.createTemp('cutawan-settings-layout-'));
      final store = await _traceSettingsStep('layout-create-store', () => _createStore(directory));
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
        await _traceSettingsStep('layout-pump-widget-${item.size.width}', () => tester.pumpWidget(
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
        ));
        await _traceSettingsStep('layout-initial-pump-${item.size.width}', () => tester.pump());
        await _traceSettingsStep('layout-settle-frame-${item.size.width}', () => tester.pump(const Duration(milliseconds: 400)));

        expect(find.text('إعدادات CUTAWAN'), findsOneWidget);
        await _traceSettingsStep('layout-scroll-privacy-${item.size.width}', () => _scrollSettingsUntilFound(tester, find.text('الخصوصية والمعالجة')));
        expect(find.text('الخصوصية والمعالجة'), findsOneWidget);
        await _traceSettingsStep('layout-scroll-legal-${item.size.width}', () => _scrollSettingsUntilFound(tester, find.text('المعلومات القانونية')));
        expect(find.text('المعلومات القانونية'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await _traceSettingsStep('layout-unmount-${item.size.width}', () => tester.pumpWidget(const SizedBox.shrink()));
      }
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

  testWidgets('settings routes open diagnostics and the models center',
      (tester) async {
    print('[settings-routes] START');
    var diagnostics = 0;
    var models = 0;
    final directory = await _traceSettingsStep('routes-create-temp', () => Directory.systemTemp.createTemp('cutawan-settings-routes-'));
    final store = await _traceSettingsStep('routes-create-store', () => _createStore(directory));
    addTearDown(store.dispose);
    addTearDown(() => directory.delete(recursive: true));
    await _traceSettingsStep('routes-pump-widget', () => tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: SettingsPage(
          store: store,
          onDiagnostics: () => diagnostics++,
          onModels: () => models++,
        ),
      ),
    ));
    await _traceSettingsStep('routes-initial-pump', () => tester.pump());

    final diagnosticsTile = find.text('تشخيص وقبول Android');
    await _traceSettingsStep('routes-scroll-diagnostics', () => _scrollSettingsUntilFound(tester, diagnosticsTile, distance: 360));
    await _traceSettingsStep('routes-tap-diagnostics', () => tester.tap(diagnosticsTile));
    final modelsTile = find.text('مركز النماذج والاتصالات');
    await _traceSettingsStep('routes-scroll-models', () => _scrollSettingsUntilFound(tester, modelsTile, distance: 360));
    await _traceSettingsStep('routes-tap-models', () => tester.tap(modelsTile));

    expect(diagnostics, 1);
    expect(models, 1);
    expect(tester.takeException(), isNull);
  }, timeout: const Timeout(Duration(seconds: 90)));

  testWidgets(
    'theme mode and reduced motion controls persist on this device',
    (tester) async {
      print('[settings-persistence] START');
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final directory = await _traceSettingsStep('persist-create-temp', () => Directory.systemTemp.createTemp('cutawan-settings-persist-'));
      final store = await _traceSettingsStep('persist-create-store', () => _createStore(directory));
      addTearDown(store.dispose);
      addTearDown(() => directory.delete(recursive: true));

      await _traceSettingsStep('persist-pump-widget', () => tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          darkTheme: CutawanTheme.dark(),
          home: SettingsPage(
            store: store,
            onDiagnostics: () {},
            onModels: () {},
          ),
        ),
      ));
      await _traceSettingsStep('persist-initial-pump', () => tester.pump());

      final darkTheme = find.byKey(
        const ValueKey('settings-theme-dark'),
      );
      await _traceSettingsStep('persist-scroll-theme', () => _scrollSettingsUntilFound(tester, darkTheme, distance: 360));
      await _traceSettingsStep('persist-tap-theme', () => tester.tap(darkTheme));
      await _traceSettingsStep('persist-post-theme-pump', () => tester.pump());
      await _traceSettingsStep('persist-theme-delay', () => tester.pump(const Duration(milliseconds: 50)));
      expect(store.preferences.value.themeMode, AppThemeMode.dark);

      final reduceMotion = find.byKey(
        const ValueKey('settings-reduce-motion'),
      );
      await _traceSettingsStep('persist-scroll-motion', () => _scrollSettingsUntilFound(tester, reduceMotion, distance: 300));
      await _traceSettingsStep('persist-tap-motion', () => tester.tap(reduceMotion));
      await _traceSettingsStep('persist-post-motion-pump', () => tester.pump());
      await _traceSettingsStep('persist-motion-delay', () => tester.pump(const Duration(milliseconds: 50)));
      expect(store.preferences.value.reduceMotion, isTrue);

      final restoredStore = AppPreferencesStore(
        directoryProvider: () async => directory,
      );
      addTearDown(restoredStore.dispose);
      await _traceSettingsStep('persist-reload-store', () => restoredStore.load());
      expect(restoredStore.preferences.value.themeMode, AppThemeMode.dark);
      expect(restoredStore.preferences.value.reduceMotion, isTrue);
    },
    timeout: const Timeout(Duration(seconds: 90)),
  );

}
