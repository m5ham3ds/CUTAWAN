import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/screens/home_shell/shared_ui_primitives.dart';

void main() {
  test('byte formatting uses stable human-readable units', () {
    expect(formatCutawanBytes(0), 'غير متاح');
    expect(formatCutawanBytes(1024), '1 KB');
    expect(formatCutawanBytes(1024 * 1024), '1.0 MB');
  });

  testWidgets('status note renders its message accessibly', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: CutawanStatusNote(text: 'حالة الاختبار'),
        ),
      ),
    );

    expect(find.text('حالة الاختبار'), findsOneWidget);
    expect(find.byIcon(Icons.info_outline_rounded), findsOneWidget);
  });
}
