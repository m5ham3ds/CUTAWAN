import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/app.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

void configureCaptionStudioViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('Cutawan design system exposes consistent Material 3 light and dark themes', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: CutawanTheme.light(),
      darkTheme: CutawanTheme.dark(),
      themeMode: ThemeMode.dark,
      home: const Scaffold(body: Text('Theme check')),
    ));

    final context = tester.element(find.text('Theme check'));
    final theme = Theme.of(context);
    expect(theme.useMaterial3, isTrue);
    expect(theme.brightness, Brightness.dark);
    expect(theme.cardTheme.shape, isNotNull);
    expect(theme.filledButtonTheme.style, isNotNull);
    expect(CutawanTheme.light().brightness, Brightness.light);
  });

  testWidgets('mobile shell remains stable at a narrow 320dp viewport', (tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(const CutawanApp());
    await tester.pump();
    expect(tester.takeException(), isNull);
  });


  testWidgets('mobile shell shows the four primary destinations', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    expect(find.text('CUTAWAN'), findsOneWidget);
    expect(find.text('AI CREATOR STUDIO'), findsOneWidget);
    expect(find.text('إنشاء'), findsOneWidget);
    expect(find.text('المشاريع'), findsOneWidget);
    expect(find.text('المراجعة'), findsOneWidget);
    expect(find.text('الكابشن'), findsOneWidget);
    expect(find.textContaining('من المصدر إلى'), findsOneWidget);
  });

  testWidgets('caption studio exposes 12 presets, RTL preview and separate animation controls', (tester) async {
    configureCaptionStudioViewport(tester);
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('الاستوديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('مختبر الهوية النصية'), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsWidgets);
    expect(find.byType(ChoiceChip), findsNWidgets(12));
    expect(find.text('Beast'), findsOneWidget);
    expect(find.text('Karaoke'), findsOneWidget);
    expect(find.text('معاينة اتجاه النص'), findsOneWidget);
    expect(find.text('حفظ إعدادات الاستوديو في المشروع'), findsOneWidget);

    final arabicPreview = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText().contains('هذه لحظة'));
    expect(arabicPreview.textDirection, TextDirection.rtl);

    await tester.tap(find.byType(Switch).first);
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('English'), findsOneWidget);
    final englishPreview = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText().contains('THIS IS THE MOMENT'));
    expect(englishPreview.textDirection, TextDirection.ltr);

    await tester.tap(find.text('Karaoke'));
    await tester.pump(const Duration(milliseconds: 100));
    final selectedStyles = tester
        .widgetList<ChoiceChip>(find.byType(ChoiceChip))
        .where((chip) => chip.selected);
    expect(selectedStyles, hasLength(1));

    await tester.tap(find.text('Word Pop'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Karaoke Fill'), findsOneWidget);
  });

  testWidgets('jobs and review show clear empty states when no project exists', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('المهام'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مهام بعد'), findsOneWidget);

    await tester.tap(find.text('المراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مقاطع للمراجعة'), findsOneWidget);
  });
}
