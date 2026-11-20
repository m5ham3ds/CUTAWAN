import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/app.dart';

void configureCaptionStudioViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  testWidgets('mobile shell shows the four primary destinations', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    expect(find.text('CUTAWAN'), findsOneWidget);
    expect(find.text('إدخال'), findsOneWidget);
    expect(find.text('المهام'), findsOneWidget);
    expect(find.text('المراجعة'), findsOneWidget);
    expect(find.text('الاستوديو'), findsOneWidget);
    expect(find.textContaining('فيديو طويل يدخل'), findsOneWidget);
  });

  testWidgets('caption studio exposes 12 presets, RTL preview and separate animation controls', (tester) async {
    configureCaptionStudioViewport(tester);
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('الاستوديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('اصنع أسلوبك الخاص'), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsWidgets);
    expect(find.byType(ChoiceChip), findsNWidgets(12));
    expect(find.text('Beast'), findsOneWidget);
    expect(find.text('Karaoke'), findsOneWidget);
    expect(find.text('معاينة عربية / RTL'), findsOneWidget);
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
        .firstWhere((widget) => widget.text.toPlainText().contains('This is the moment'));
    expect(englishPreview.textDirection, TextDirection.ltr);

    await tester.tap(find.text('Karaoke'));
    await tester.pump(const Duration(milliseconds: 100));
    final selectedStyle = tester.widget<ChoiceChip>(
      find.ancestor(
        of: find.text('Karaoke'),
        matching: find.byType(ChoiceChip),
      ),
    );
    expect(selectedStyle.selected, isTrue);

    await tester.tap(find.text('Word Pop'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('Karaoke Fill'), findsOneWidget);
  });

  testWidgets('jobs and review pages explain that processing is not connected yet', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('المهام'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مهام بعد'), findsOneWidget);

    await tester.tap(find.text('المراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مقاطع للمراجعة'), findsOneWidget);
  });
}
