import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/app.dart';
import 'package:cutawan_mobile/screens/home_shell/navigation_components.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

void configureCaptionStudioViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(1200, 3200);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}

void main() {
  final binding = TestWidgetsFlutterBinding.ensureInitialized();
  binding.platformDispatcher.localeTestValue = const Locale('ar');
  binding.platformDispatcher.localesTestValue = const <Locale>[Locale('ar')];
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
    expect(find.byType(ListView), findsOneWidget);
    expect(find.text('CUTAWAN'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });


  testWidgets('mobile shell shows the five primary destinations', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    expect(find.text('CUTAWAN'), findsOneWidget);
    expect(find.text('AI CREATOR STUDIO'), findsOneWidget);
    expect(find.text('الرئيسية'), findsOneWidget);
    expect(find.text('إنشاء'), findsOneWidget);
    expect(find.text('المهام'), findsOneWidget);
    expect(find.text('المراجعة'), findsOneWidget);
    expect(find.text('الاستوديو'), findsOneWidget);
    expect(find.text('مرحباً بك في CUTAWAN'), findsOneWidget);
  });

  testWidgets('dashboard replaces both settings shortcuts with the CUTAWAN logo', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    expect(find.byKey(const ValueKey('dashboard-settings')), findsNothing);
    expect(find.byTooltip('الإعدادات'), findsNothing);
    expect(find.byKey(const ValueKey('cutawan-topbar-logo')), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('cutawan-open-drawer')));
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('cutawan-drawer-settings')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard recent-projects end state can scroll above the bottom navigation', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(const CutawanApp());
    await tester.pumpAndSettle();

    final list = find.byKey(const ValueKey('cutawan-dashboard-list'));
    expect(list, findsOneWidget);
    await tester.drag(list, const Offset(0, -2400));
    await tester.pumpAndSettle();

    final emptyState = find.byKey(const ValueKey('dashboard-empty-state'));
    expect(emptyState, findsOneWidget);
    final emptyStateRect = tester.getRect(emptyState);
    final navigationRect = tester.getRect(find.byType(CutawanNavigationBar));
    expect(emptyStateRect.bottom, lessThanOrEqualTo(navigationRect.top));
    expect(tester.takeException(), isNull);
  });

  testWidgets('dashboard create action opens the real import page', (tester) async {
    await tester.pumpWidget(const CutawanApp());
    expect(find.text('مرحباً بك في CUTAWAN'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('dashboard-create-project')));
    await tester.pumpAndSettle();
    expect(find.textContaining('من المصدر إلى'), findsOneWidget);
    expect(find.text('اختيار فيديو'), findsOneWidget);
  });

  testWidgets('settings route exposes diagnostics and model center actions', (tester) async {
    await tester.pumpWidget(const CutawanApp());
    expect(find.byTooltip('تشخيص الجهاز'), findsNothing);
    expect(find.byTooltip('مركز النماذج'), findsNothing);
    expect(find.text('مركز النماذج'), findsNothing);

    await tester.tap(find.byKey(const ValueKey('cutawan-open-drawer')));
    await tester.pumpAndSettle();
    final drawerSettings = find.byKey(const ValueKey('cutawan-drawer-settings'));
    await tester.ensureVisible(drawerSettings);
    await tester.pumpAndSettle();
    await tester.tap(drawerSettings);
    await tester.pumpAndSettle();
    expect(find.text('إعدادات CUTAWAN'), findsOneWidget);
    expect(find.text('تشخيص الجهاز'), findsOneWidget);
    expect(find.text('مركز النماذج'), findsOneWidget);
  });

  testWidgets(
    'device diagnostics and model center are available only through Settings',
    (tester) async {
      await tester.pumpWidget(const CutawanApp());

      const diagnosticsKey = ValueKey('settings-device-diagnostics');
      const modelsKey = ValueKey('settings-model-center');

      // The initial route is the project dashboard; neither destination is
      // exposed there or in the global top bar.
      expect(find.byKey(diagnosticsKey), findsNothing);
      expect(find.byKey(modelsKey), findsNothing);
      expect(find.byTooltip('تشخيص الجهاز'), findsNothing);
      expect(find.byTooltip('مركز النماذج'), findsNothing);

      await tester.tap(find.byKey(const ValueKey('cutawan-open-drawer')));
      await tester.pumpAndSettle();
      final drawerSettings = find.byKey(
        const ValueKey('cutawan-drawer-settings'),
      );
      await tester.ensureVisible(drawerSettings);
      await tester.pumpAndSettle();
      await tester.tap(drawerSettings);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 350));

      expect(find.byKey(diagnosticsKey), findsOneWidget);
      expect(find.byKey(modelsKey), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('caption studio exposes 12 presets, RTL preview and separate animation controls', (tester) async {
    configureCaptionStudioViewport(tester);
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('الاستوديو'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.text('مختبر الهوية النصية'), findsOneWidget);
    expect(find.byType(AnimatedBuilder), findsWidgets);
    expect(find.descendant(of: find.byKey(const ValueKey('caption-style-presets')), matching: find.byType(ChoiceChip)), findsNWidgets(12));
    expect(find.text('Beast'), findsOneWidget);
    expect(find.byKey(const ValueKey('caption-style-karaoke')), findsOneWidget);
    expect(find.text('اتجاه معاينة النص'), findsOneWidget);
    expect(find.byKey(const ValueKey('caption-project-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('caption-timing-offset')), findsOneWidget);
    expect(find.byKey(const ValueKey('caption-studio-save')), findsOneWidget);

    final arabicPreview = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText().contains('هذه لحظة'));
    expect(arabicPreview.textDirection, TextDirection.rtl);

    await tester.tap(find.byKey(const ValueKey('caption-direction-switch')));
    await tester.pump();
    expect(
      tester.widget<SwitchListTile>(find.byKey(const ValueKey('caption-direction-switch'))).value,
      isFalse,
    );
    await tester.pump(const Duration(milliseconds: 250));
    final englishPreview = tester
        .widgetList<RichText>(find.byType(RichText))
        .firstWhere((widget) => widget.text.toPlainText().contains('THIS IS THE MOMENT'));
    expect(englishPreview.textDirection, TextDirection.ltr);

    await tester.tap(find.byKey(const ValueKey('caption-style-karaoke')));
    await tester.pump(const Duration(milliseconds: 100));
    final selectedStyles = tester
        .widgetList<ChoiceChip>(find.descendant(of: find.byKey(const ValueKey('caption-style-presets')), matching: find.byType(ChoiceChip)))
        .where((chip) => chip.selected);
    expect(selectedStyles, hasLength(1));

    final motionTab = find.byKey(
      const ValueKey('caption-editor-tab-motion'),
    );
    await tester.ensureVisible(motionTab);
    await tester.pumpAndSettle();
    await tester.tap(motionTab);
    await tester.pumpAndSettle();
    await tester.ensureVisible(
      find.byKey(const ValueKey('caption-animation-karaoke_fill')),
    );
    await tester.tap(
      find.byKey(const ValueKey('caption-animation-karaoke_fill')),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      tester.widget<ChoiceChip>(
        find.byKey(const ValueKey('caption-animation-karaoke_fill')),
      ).selected,
      isTrue,
    );
    expect(
      find.textContaining('مدعومة في معاينة الاستوديو وتصدير MP4'),
      findsOneWidget,
    );
  });

  testWidgets('jobs and review show clear empty states when no project exists', (tester) async {
    await tester.pumpWidget(const CutawanApp());

    await tester.tap(find.text('المهام'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مهام بعد'), findsOneWidget);

    await tester.tap(find.text('المراجعة'));
    await tester.pumpAndSettle();
    expect(find.text('لا توجد مشاريع للمراجعة'), findsOneWidget);
  });
}
