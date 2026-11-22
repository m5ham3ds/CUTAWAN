import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/screens/home_shell/create_page.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';

void main() {
  testWidgets('Create page is independently importable and responsive at 320dp',
      (tester) async {
    tester.view.physicalSize = const Size(320, 700);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: CreatePage(
              repository: LocalProjectRepository(),
              onProjectSaved: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('مشروع فيديو جديد'), findsOneWidget);
    expect(find.byKey(const ValueKey('create-workflow-scroll')), findsOneWidget);
    expect(find.byKey(const ValueKey('create-pick-local')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
