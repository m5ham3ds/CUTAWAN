import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
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
  int maxTabs = 24,
}) async {
  final expectedNode = Focus.of(tester.element(target));
  var reached = false;

  for (var index = 0; index < maxTabs; index++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    if (identical(FocusManager.instance.primaryFocus, expectedNode)) {
      reached = true;
      break;
    }
  }

  expect(
    reached,
    isTrue,
    reason: 'Tab traversal did not reach the requested page action.',
  );
  expect(
    FocusManager.instance.highlightMode,
    FocusHighlightMode.traditional,
    reason: 'Keyboard navigation must activate the visible focus mode.',
  );
  expect(
    tester.getSemantics(target).hasFlag(SemanticsFlag.isFocused),
    isTrue,
    reason: 'The focused page action must expose its focused semantics state.',
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
      addTearDown(semantics.dispose);

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

      await _tabUntilFocused(tester, find.byKey(const ValueKey('dashboard-settings')));
      expect(tester.takeException(), isNull);
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
      addTearDown(semantics.dispose);
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
        find.text('تشخيص وقبول Android'),
      );
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Models Center Tab traversal reaches local mode with visible focus',
    (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final semantics = tester.ensureSemantics();
      addTearDown(semantics.dispose);

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

      await _tabUntilFocused(tester, find.text('محلي'));
      expect(tester.takeException(), isNull);
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
      addTearDown(semantics.dispose);

      final service = _CountingDeviceAcceptanceService();
      await tester.pumpWidget(
        MaterialApp(
          theme: CutawanTheme.light(),
          home: DeviceAcceptancePage(service: service),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final refresh = find.descendant(
        of: find.byTooltip('إعادة الفحص'),
        matching: find.byIcon(Icons.refresh_rounded),
      );
      await _tabUntilFocused(tester, refresh);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

}
