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

class _FocusVariant {
  const _FocusVariant({
    required this.name,
    required this.theme,
    required this.direction,
  });

  final String name;
  final ThemeData theme;
  final TextDirection direction;
}

final _focusVariants = <_FocusVariant>[
  _FocusVariant(
    name: 'light-rtl',
    theme: CutawanTheme.light(),
    direction: TextDirection.rtl,
  ),
  _FocusVariant(
    name: 'dark-ltr',
    theme: CutawanTheme.dark(),
    direction: TextDirection.ltr,
  ),
];

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

class _FocusGoldenDeviceAcceptanceService extends DeviceAcceptanceService {
  @override
  Future<Map<String, Object?>> collect() async => <String, Object?>{
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

Future<void> _tabToFocusedSemantics(
  WidgetTester tester,
  Finder target,
) async {
  for (var attempt = 0; attempt < 32; attempt++) {
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    if (tester
            .getSemantics(target)
            .flagsCollection
            .isFocused
            .toBoolOrNull() ==
        true) {
      expect(
        FocusManager.instance.highlightMode,
        FocusHighlightMode.traditional,
      );
      return;
    }
  }
  fail('Tab traversal did not focus the golden target.');
}

Future<void> _expectFocusedGolden(
  WidgetTester tester, {
  required String fileName,
  required Finder target,
}) async {
  await _tabToFocusedSemantics(tester, target);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 80));
  expect(
    tester.getSemantics(target).flagsCollection.isFocused.toBoolOrNull(),
    isTrue,
  );
  await expectLater(
    find.byKey(const ValueKey('focused-page-golden')),
    matchesGoldenFile('goldens/pages/$fileName.png'),
  );
  expect(tester.takeException(), isNull);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard keyboard focus indicator goldens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final projects = ValueNotifier<List<CutawanProject>>([]);
    addTearDown(projects.dispose);

    for (final variant in _focusVariants) {
      await tester.pumpWidget(
        MaterialApp(
          theme: variant.theme,
          home: Directionality(
            textDirection: variant.direction,
            child: RepaintBoundary(
              key: const ValueKey('focused-page-golden'),
              child: Scaffold(
                body: DashboardPage(
                  projects: projects,
                  onCreate: () {},
                  onOpenJobs: () {},
                  onOpenReview: () {},
                  onOpenSettings: () {},
                  onOpenProject: (_) {},
                  storageUsageBytes: () async => 2 * 1024 * 1024,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await _expectFocusedGolden(
        tester,
        fileName: 'focus-dashboard-${variant.name}',
        target: find.byTooltip('الإعدادات'),
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Settings keyboard focus indicator goldens', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final store = AppPreferencesStore.inMemory();
    addTearDown(store.dispose);

    for (final variant in _focusVariants) {
      await tester.pumpWidget(
        MaterialApp(
          theme: variant.theme,
          home: Directionality(
            textDirection: variant.direction,
            child: RepaintBoundary(
              key: const ValueKey('focused-page-golden'),
              child: SettingsPage(
                store: store,
                onDiagnostics: () {},
                onModels: () {},
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      final target = find.ancestor(
        of: find.text('تشخيص الجهاز'),
        matching: find.byType(ListTile),
      ).first;
      await _expectFocusedGolden(
        tester,
        fileName: 'focus-settings-${variant.name}',
        target: target,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Models Center keyboard focus indicator goldens',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    final credentials = AiCredentialStore(
      storage: _MemoryCredentialStorage(),
    );

    for (final variant in _focusVariants) {
      await tester.pumpWidget(
        MaterialApp(
          theme: variant.theme,
          home: Directionality(
            textDirection: variant.direction,
            child: RepaintBoundary(
              key: const ValueKey('focused-page-golden'),
              child: ModelsPage(
                credentials: credentials,
                checkWhisperInstalled: () async => false,
                checkQwenInstalled: () async => false,
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));

      final label = find.text('تحديث حالة النماذج');
      await tester.scrollUntilVisible(
        label,
        220,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pump();
      final target = find.ancestor(
        of: label,
        matching: find.byType(TextButton),
      ).first;
      await _expectFocusedGolden(
        tester,
        fileName: 'focus-models-${variant.name}',
        target: target,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });

  testWidgets('Device Diagnostics keyboard focus indicator goldens',
      (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final semantics = tester.ensureSemantics();

    for (final variant in _focusVariants) {
      await tester.pumpWidget(
        MaterialApp(
          theme: variant.theme,
          home: Directionality(
            textDirection: variant.direction,
            child: RepaintBoundary(
              key: const ValueKey('focused-page-golden'),
              child: DeviceAcceptancePage(
                service: _FocusGoldenDeviceAcceptanceService(),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 60));
      final target = find.ancestor(
        of: find.byTooltip('إعادة الفحص'),
        matching: find.byType(IconButton),
      ).first;
      await _expectFocusedGolden(
        tester,
        fileName: 'focus-diagnostics-${variant.name}',
        target: target,
      );
      await tester.pumpWidget(const SizedBox.shrink());
    }
    semantics.dispose();
    expect(tester.takeException(), isNull);
  });
}
