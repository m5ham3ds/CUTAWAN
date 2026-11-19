import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/app.dart';

void main() {
  testWidgets('mobile shell shows the four AutoClip-inspired destinations', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    expect(find.text('CUTAWAN'), findsOneWidget);
    expect(find.text('إدخال'), findsOneWidget);
    expect(find.text('المهام'), findsOneWidget);
    expect(find.text('المراجعة'), findsOneWidget);
    expect(find.text('الاستوديو'), findsOneWidget);
    expect(find.textContaining('فيديو طويل يدخل'), findsOneWidget);
  });

  testWidgets('caption studio keeps visual presets separate from animation choices', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('الاستوديو'));
    await tester.pumpAndSettle();

    expect(find.text('اصنع أسلوبك الخاص'), findsOneWidget);
    expect(find.text('Beast'), findsOneWidget);
    await tester.tap(find.byType(DropdownButtonFormField));
    await tester.pumpAndSettle();
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
