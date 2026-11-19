import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/app.dart';

void main() {
  testWidgets('Cutawan mobile shell opens and shows its main destinations', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    expect(find.text('CUTAWAN'), findsOneWidget);
    expect(find.text('إنشاء'), findsOneWidget);
    expect(find.text('مشاريعي'), findsOneWidget);
    expect(find.text('الكابشن'), findsOneWidget);
    expect(find.text('النماذج'), findsOneWidget);

    await tester.tap(find.text('الكابشن'));
    await tester.pumpAndSettle();

    expect(find.text('Caption Studio'), findsOneWidget);
    expect(find.text('Beast'), findsOneWidget);
  });
}
