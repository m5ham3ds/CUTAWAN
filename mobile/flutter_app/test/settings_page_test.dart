import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/screens/features/settings_page.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

void main() {
  testWidgets(
    'CUTAWAN settings fit narrow and wide screens with enlarged text',
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
                  onDiagnostics: () {},
                  onModels: () {},
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('إعدادات CUTAWAN'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('الخصوصية والمعالجة'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        expect(find.text('الخصوصية والمعالجة'), findsOneWidget);
        await tester.scrollUntilVisible(
          find.text('المعلومات القانونية'),
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
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
    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: SettingsPage(
          onDiagnostics: () => diagnostics++,
          onModels: () => models++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    final diagnosticsTile = find.text('تشخيص وقبول Android');
    await tester.scrollUntilVisible(
      diagnosticsTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(diagnosticsTile);
    final modelsTile = find.text('مركز النماذج والاتصالات');
    await tester.scrollUntilVisible(
      modelsTile,
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(modelsTile);

    expect(diagnostics, 1);
    expect(models, 1);
    expect(tester.takeException(), isNull);
  });
}
