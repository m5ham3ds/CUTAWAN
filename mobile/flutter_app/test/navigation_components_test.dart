import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/screens/home_shell/navigation_components.dart';

const _destinations = <CutawanNavigationDestination>[
  (
    label: 'الرئيسية',
    icon: Icons.home_outlined,
    selected: Icons.home,
    hint: 'Dashboard',
  ),
  (
    label: 'المهام',
    icon: Icons.list_alt_outlined,
    selected: Icons.list_alt,
    hint: 'Jobs',
  ),
  (
    label: 'المراجعة',
    icon: Icons.movie_outlined,
    selected: Icons.movie,
    hint: 'Review',
  ),
];

Widget _navigationHarness({
  required int selectedIndex,
  required ValueChanged<int> onSelected,
}) {
  return MaterialApp(
    home: Scaffold(
      bottomNavigationBar: CutawanNavigationBar(
        selectedIndex: selectedIndex,
        onSelected: onSelected,
        destinations: _destinations,
        animation: const AlwaysStoppedAnimation<double>(1),
      ),
    ),
  );
}

void main() {
  testWidgets('navigation tap emits the destination index', (tester) async {
    var selected = -1;
    await tester.pumpWidget(
      _navigationHarness(
        selectedIndex: 0,
        onSelected: (value) => selected = value,
      ),
    );

    await tester.tap(find.text('المهام'));
    expect(selected, 1);
  });

  testWidgets('destinations expose stable screen-reader labels', (tester) async {
    final semantics = tester.ensureSemantics();
    await tester.pumpWidget(
      _navigationHarness(
        selectedIndex: 2,
        onSelected: (_) {},
      ),
    );

    expect(find.bySemanticsLabel('Dashboard'), findsOneWidget);
    expect(find.bySemanticsLabel('Jobs'), findsOneWidget);
    expect(find.bySemanticsLabel('Review'), findsOneWidget);
    semantics.dispose();
  });
}
