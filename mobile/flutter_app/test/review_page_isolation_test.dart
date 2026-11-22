import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/screens/home_shell/review_page.dart';
import 'package:cutawan_mobile/services/local_project_repository.dart';

void main() {
  testWidgets('Review page is independently importable at 320dp RTL',
      (tester) async {
    tester.view.physicalSize = const Size(320, 720);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final projects = ValueNotifier<List<CutawanProject>>(<CutawanProject>[]);
    addTearDown(projects.dispose);

    await tester.pumpWidget(
      MaterialApp(
        home: Directionality(
          textDirection: TextDirection.rtl,
          child: Scaffold(
            body: ReviewPage(
              projects: projects,
              repository: LocalProjectRepository(),
              onProjectsChanged: () async {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(ReviewPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
