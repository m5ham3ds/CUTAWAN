import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/domain/project_contract.dart';
import 'package:cutawan_mobile/screens/device_acceptance_page.dart';
import 'package:cutawan_mobile/screens/features/dashboard_page.dart';
import 'package:cutawan_mobile/screens/features/settings_page.dart';
import 'package:cutawan_mobile/screens/home_shell/models_page.dart';
import 'package:cutawan_mobile/services/ai_model_gateway.dart';
import 'package:cutawan_mobile/services/app_preferences_store.dart';
import 'package:cutawan_mobile/services/device_acceptance_service.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

class _MemoryCredentialStorage implements AiSecretStorage {
  final Map<String, String> values = {};

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async {
    values[key] = value;
  }
}

class _CountingDeviceAcceptanceService extends DeviceAcceptanceService {
  int calls = 0;

  @override
  Future<Map<String, Object?>> collect() async {
    calls++;
    return <String, Object?>{
      'manufacturer': 'HONOR',
      'model': 'X9c',
      'androidRelease': '16',
      'androidSdk': 36,
      'deviceClass': 'physical-candidate',
      'physicalDeviceManualConfirmationStatus': 'not-verified',
      'diagnosticCollectionScope':
          'device-metadata-and-temporary-keystore-self-test',
      'physicalMediaTestsExecuted': false,
      'diagnosticBaselineStatus': 'ready-for-physical-media-tests',
      'diagnosticMissingFields': <String>[],
      'appVersionName': '0.2.0',
      'appVersionCode': 2,
      'cpuCoreCount': 8,
      'buildSha': '1234567890abcdef1234567890abcdef12345678',
      'buildIdentityPinned': true,
      'totalMemoryBytes': 8 * 1024 * 1024 * 1024,
      'availableMemoryBytes': 4 * 1024 * 1024 * 1024,
      'availableStorageBytes': 20 * 1024 * 1024 * 1024,
      'processPssKb': 256000,
      'processPrivateDirtyKb': 180000,
      'lowMemory': false,
      'batteryPercent': 80,
      'batteryTemperatureTenthsC': 320,
      'thermalStatus': 0,
      'collectedAtUtc': '2026-11-23T00:00:00.000Z',
      'mediaCorpusStatus': 'not-collected',
      'speechQualityStatus': 'not-collected',
      'candidateQualityStatus': 'not-collected',
      'videoFullDecodeStatus': 'not-collected-on-physical-device',
      'sustainedPerformanceStatus': 'not-collected',
      'processDeathResumeStatus': 'not-verified-on-physical-device',
      'safLifecycleStatus': 'not-verified-across-force-stop',
      'secureStorageRoundTrip': 'passed',
      'secureStorageCanaryDeleted': true,
      'keystoreLifecycleStatus': 'single-install-round-trip-only',
      'networkConsentEndToEndStatus': 'not-verified-on-physical-device',
      'phase10Acceptance': 'incomplete-device-and-media-evidence-required',
    };
  }
}

Future<void> _focusAndActivate(
  WidgetTester tester,
  Finder target,
) async {
  final focusNode = Focus.of(tester.element(target));
  focusNode.requestFocus();
  await tester.pump();

  expect(
    FocusManager.instance.primaryFocus,
    same(focusNode),
    reason: 'The selected page control must receive keyboard focus.',
  );

  await tester.sendKeyEvent(LogicalKeyboardKey.enter);
  await tester.pump();
}


Future<void> _tabUntilFocused(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 48,
}) async {
  var reached = false;

  for (var index = 0; index < maxTabs; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    final focused = tester
            .getSemantics(target)
            .flagsCollection
            .isFocused
            .toBoolOrNull() ==
        true;
    if (focused) {
      reached = true;
      break;
    }
  }

  expect(
    reached,
    isTrue,
    reason:
        'Natural Tab traversal did not focus the requested page action: ${target.describeMatch(Plurality.one)}',
  );
  expect(
    FocusManager.instance.highlightMode,
    FocusHighlightMode.traditional,
    reason: 'Keyboard navigation must activate the visible focus mode.',
  );
  expect(
    tester
        .getSemantics(target)
        .flagsCollection
        .isFocused
        .toBoolOrNull(),
    isTrue,
    reason: 'The current focused action must expose its focused semantics state.',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard create action supports focus and Enter activation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var createCalls = 0;
    final projects = ValueNotifier<List<CutawanProject>>([]);

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: Scaffold(
          body: DashboardPage(
            projects: projects,
            onCreate: () => createCalls++,
            onOpenJobs: () {},
            onOpenReview: () {},
            onOpenModels: () {},
            onOpenSettings: () {},
            onOpenProject: (_) {},
            storageUsageBytes: () async => 0,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await _focusAndActivate(tester, find.text('إنشاء مشروع جديد'));

    expect(createCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
    projects.dispose();
  });

  testWidgets('Settings diagnostics route supports focus and Enter activation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var diagnosticsCalls = 0;
    final store = AppPreferencesStore.inMemory();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: SettingsPage(
          store: store,
          onDiagnostics: () => diagnosticsCalls++,
          onModels: () {},
        ),
      ),
    );
    await tester.pump();

    final diagnostics = find.text('تشخيص وقبول Android');
    await tester.scrollUntilVisible(
      diagnostics,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    await _focusAndActivate(tester, diagnostics);

    expect(diagnosticsCalls, 1);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Models Center local-model refresh supports focus and Enter activation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var whisperChecks = 0;
    var qwenChecks = 0;
    final credentials = AiCredentialStore(
      storage: _MemoryCredentialStorage(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.dark(),
        home: ModelsPage(
          credentials: credentials,
          checkWhisperInstalled: () async {
            whisperChecks++;
            return false;
          },
          checkQwenInstalled: () async {
            qwenChecks++;
            return false;
          },
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    final refresh = find.text('إعادة فحص النماذج المحلية');
    await tester.scrollUntilVisible(
      refresh,
      260,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump();

    final whisperBefore = whisperChecks;
    final qwenBefore = qwenChecks;
    await _focusAndActivate(tester, refresh);
    await tester.pump(const Duration(milliseconds: 50));

    expect(whisperChecks, greaterThan(whisperBefore));
    expect(qwenChecks, greaterThan(qwenBefore));
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
      'Device Diagnostics refresh supports focus and Enter activation',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final service = _CountingDeviceAcceptanceService();
    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: DeviceAcceptancePage(service: service),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    expect(service.calls, 1);

    final refresh = find.byTooltip('إعادة الفحص');
    final refreshIcon = find.descendant(
      of: refresh,
      matching: find.byIcon(Icons.refresh_rounded),
    );
    await _focusAndActivate(tester, refreshIcon);
    await tester.pump(const Duration(milliseconds: 50));

    expect(service.calls, 2);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets(
    'Dashboard Tab traversal reaches the settings action with visible focus',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final projects = ValueNotifier<List<CutawanProject>>([]);
      addTearDown(projects.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          home: Scaffold(
            body: DashboardPage(
              projects: projects,
              onCreate: () {},
              onOpenJobs: () {},
              onOpenReview: () {},
              onOpenModels: () {},
              onOpenSettings: () {},
              onOpenProject: (_) {},
              storageUsageBytes: () async => 0,
            ),
          ),
        ),
      );
      await tester.pump();

      await _tabUntilFocused(tester, find.byTooltip('الإعدادات'));
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Settings Tab traversal reaches diagnostics with visible focus',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      final store = AppPreferencesStore.inMemory();
      addTearDown(store.dispose);

      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          home: SettingsPage(
            store: store,
            onDiagnostics: () {},
            onModels: () {},
          ),
        ),
      );
      await tester.pump();

      await _tabUntilFocused(
        tester,
        find.ancestor(
          of: find.text('تشخيص وقبول Android'),
          matching: find.byType(ListTile),
        ).first,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Models Center Tab traversal reaches local-model refresh with visible focus',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final credentials = AiCredentialStore(
        storage: _MemoryCredentialStorage(),
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.dark(),
          home: ModelsPage(
            credentials: credentials,
            checkWhisperInstalled: () async => false,
            checkQwenInstalled: () async => false,
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final refreshLabel = find.text('إعادة فحص النماذج المحلية');
      await tester.scrollUntilVisible(
        refreshLabel,
        260,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      await _tabUntilFocused(
        tester,
        find.ancestor(
          of: refreshLabel,
          matching: find.byType(TextButton),
        ).first,
      );
      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Device Diagnostics Tab traversal reaches refresh with visible focus',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();

      final service = _CountingDeviceAcceptanceService();
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          home: DeviceAcceptancePage(service: service),
        ),
      );
      await tester.pumpAndSettle();
      expect(service.calls, 1);

      final refresh = find.ancestor(
        of: find.byTooltip('إعادة الفحص'),
        matching: find.byType(IconButton),
      ).first;
      await _tabUntilFocused(tester, refresh);

      // Scroll to the lazy list child before resolving its ancestor control.
      final copyReportLabel = find.text('نسخ تقرير التشخيص JSON');
      await tester.scrollUntilVisible(
        copyReportLabel,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      expect(copyReportLabel, findsOneWidget);
      final copyReport = find.ancestor(
        of: copyReportLabel,
        matching: find.byType(FilledButton),
      ).first;
      await _tabUntilFocused(tester, copyReport);

      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );


bool primaryFocusIsWithin(WidgetTester tester, Finder target) {
  final targets = target.evaluate().toSet();
  final focusedContext = FocusManager.instance.primaryFocus?.context;
  if (focusedContext == null || targets.isEmpty) {
    return false;
  }

  var found = false;
  focusedContext.visitAncestorElements((ancestor) {
    if (targets.contains(ancestor)) {
      found = true;
      return false;
    }
    return true;
  });
  return found;
}

Future<void> tabUntilFocusWithin(
  WidgetTester tester,
  Finder target, {
  int maxTabs = 64,
}) async {
  var reached = false;

  for (var index = 0; index < maxTabs; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    if (primaryFocusIsWithin(tester, target)) {
      reached = true;
      break;
    }
  }

  expect(
    reached,
    isTrue,
    reason:
        'Natural Tab traversal did not enter the requested composite control: '
        '${target.describeMatch(Plurality.one)}',
  );
  expect(
    FocusManager.instance.highlightMode,
    FocusHighlightMode.traditional,
    reason: 'Keyboard navigation must activate the visible focus mode.',
  );
}

Future<void> expectFullTabOrder(
  WidgetTester tester,
  List<Finder> targets, {
  int maxTabsPerTarget = 48,
}) async {
  final scrollable = find.byType(Scrollable).first;
  for (final target in targets) {
    final uniqueTarget = target.first;
    await tester.scrollUntilVisible(
      uniqueTarget,
      220,
      scrollable: scrollable,
    );
    await tester.pump();
    await _tabUntilFocused(
      tester,
      uniqueTarget,
      maxTabs: maxTabsPerTarget,
    );
  }
}

Finder pageTile(String label) => find.ancestor(
      of: find.text(label),
      matching: find.byType(ListTile),
    ).first;

void setPhoneViewport(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
}

void resetPhoneViewport(WidgetTester tester) {
  tester.view.resetPhysicalSize();
  tester.view.resetDevicePixelRatio();
}

void fullPageTabOrderTests() {
  testWidgets('Dashboard exposes every interactive control in reading order',
      (tester) async {
    setPhoneViewport(tester);
    addTearDown(() => resetPhoneViewport(tester));
    final semantics = tester.ensureSemantics();
    final projects = ValueNotifier<List<CutawanProject>>([]);
    addTearDown(projects.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: Scaffold(
          body: DashboardPage(
            projects: projects,
            onCreate: () {},
            onOpenJobs: () {},
            onOpenReview: () {},
            onOpenModels: () {},
            onOpenSettings: () {},
            onOpenProject: (_) {},
            storageUsageBytes: () async => 0,
          ),
        ),
      ),
    );
    await tester.pump();

    await expectFullTabOrder(tester, [
      find.byTooltip('الإعدادات'),
      find.byKey(const ValueKey('dashboard-create-project')),
      find.byKey(const ValueKey('dashboard-refresh-storage')),
      pageTile('المهام والمشاريع'),
      pageTile('المراجعة والتحرير'),
      pageTile('مركز النماذج'),
      find.ancestor(
        of: find.text('عرض الكل'),
        matching: find.byType(TextButton),
      ).first,
    ]);

    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Settings exposes navigation, theme and accessibility controls in order',
      (tester) async {
    setPhoneViewport(tester);
    addTearDown(() => resetPhoneViewport(tester));
    final semantics = tester.ensureSemantics();
    final store = AppPreferencesStore.inMemory();
    addTearDown(store.dispose);

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.light(),
        home: SettingsPage(
          store: store,
          onDiagnostics: () {},
          onModels: () {},
        ),
      ),
    );
    await tester.pump();

    await expectFullTabOrder(tester, [
      pageTile('تشخيص وقبول Android'),
      pageTile('مركز النماذج والاتصالات'),
      find.byKey(const ValueKey('settings-theme-system')),
      find.byKey(const ValueKey('settings-theme-light')),
      find.byKey(const ValueKey('settings-theme-dark')),
      find.byKey(const ValueKey('settings-reduce-motion')),
    ]);

    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('Models Center exposes local and remote controls in reading order',
      (tester) async {
    setPhoneViewport(tester);
    addTearDown(() => resetPhoneViewport(tester));
    final semantics = tester.ensureSemantics();
    final credentials = AiCredentialStore(
      storage: _MemoryCredentialStorage(),
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: CutawanTheme.dark(),
        home: ModelsPage(
          credentials: credentials,
          checkWhisperInstalled: () async => false,
          checkQwenInstalled: () async => false,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 60));

    for (final modelTitle in [
      'Whisper Base متعدد اللغات',
      'Qwen2.5-0.5B-Instruct Q4_K_M',
    ]) {
      final titleFinder = find.text(modelTitle).first;
      await tester.scrollUntilVisible(
        titleFinder,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final modelCard = find.ancestor(
        of: titleFinder,
        matching: find.byType(Card),
      ).first;
      final installButton = find.descendant(
        of: modelCard,
        matching: find.byWidgetPredicate(
          (widget) => widget is ButtonStyleButton,
        ),
      ).first;
      await _tabUntilFocused(tester, installButton, maxTabs: 64);
    }

    // SegmentedButton has internal segment semantics; assert focus entered
    // the composite control rather than asking for a non-existent group node.
    await tabUntilFocusWithin(
      tester,
      find.byType(SegmentedButton<String>).first,
    );

    await expectFullTabOrder(tester, [
      find.ancestor(
        of: find.text('أوافق على إرسال مقتطفات نص التفريغ للمزوّد الخارجي'),
        matching: find.byType(CheckboxListTile),
      ).first,
      find.byType(DropdownButtonFormField<AiProviderId>).first,
      find.byType(TextField).last,
      find.ancestor(
        of: find.text('حفظ الإعدادات بأمان'),
        matching: find.byType(FilledButton),
      ).first,
      find.ancestor(
        of: find.text('جلب النماذج'),
        matching: find.byType(OutlinedButton),
      ).first,
      find.ancestor(
        of: find.text('إعادة فحص النماذج المحلية'),
        matching: find.byType(TextButton),
      ).first,
    ], maxTabsPerTarget: 64);

    expect(tester.takeException(), isNull);
    semantics.dispose();
    await tester.pumpWidget(const SizedBox.shrink());
  });


  testWidgets(
    'Models Center exposes installed-model and saved-key removal controls',
    (tester) async {
      setPhoneViewport(tester);
      addTearDown(() => resetPhoneViewport(tester));
      final semantics = tester.ensureSemantics();
      final storage = _MemoryCredentialStorage();
      final credentials = AiCredentialStore(storage: storage);
      await credentials.saveApiKey(AiProviderId.openAi, 'test-only-api-key');

      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.dark(),
          home: ModelsPage(
            credentials: credentials,
            checkWhisperInstalled: () async => true,
            checkQwenInstalled: () async => true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      for (final modelTitle in [
        'Whisper Base متعدد اللغات',
        'Qwen2.5-0.5B-Instruct Q4_K_M',
      ]) {
        final titleFinder = find.text(modelTitle).first;
        await tester.scrollUntilVisible(
          titleFinder,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        final modelCard = find.ancestor(
          of: titleFinder,
          matching: find.byType(Card),
        ).first;
        final removeLabel = find.descendant(
          of: modelCard,
          matching: find.text('إزالة'),
        );
        expect(removeLabel, findsOneWidget);
        final removeButton = find.ancestor(
          of: removeLabel,
          matching: find.byWidgetPredicate(
            (widget) => widget is ButtonStyleButton,
          ),
        ).first;
        await _tabUntilFocused(tester, removeButton, maxTabs: 64);
      }

      final remainingControls = <({String label, Type type})>[
        (label: 'حفظ الإعدادات بأمان', type: FilledButton),
        (label: 'حذف المفتاح', type: TextButton),
        (label: 'جلب النماذج', type: OutlinedButton),
        (label: 'إعادة فحص النماذج المحلية', type: TextButton),
      ];
      for (final control in remainingControls) {
        // The model center uses a lazy ListView. Build the text child first,
        // then resolve its enclosing Material button.
        final label = find.text(control.label);
        await tester.scrollUntilVisible(
          label,
          220,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        expect(label, findsOneWidget);
        final target = find.ancestor(
          of: label,
          matching: find.byType(control.type),
        ).first;
        await _tabUntilFocused(tester, target, maxTabs: 64);
      }

      expect(tester.takeException(), isNull);
      semantics.dispose();
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

}


  fullPageTabOrderTests();
}
