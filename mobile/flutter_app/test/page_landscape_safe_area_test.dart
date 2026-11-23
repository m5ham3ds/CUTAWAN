import 'package:flutter/material.dart';
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

class _LandscapeCase {
  const _LandscapeCase({
    required this.name,
    required this.size,
    required this.insets,
    required this.direction,
    required this.theme,
    required this.textScale,
  });

  final String name;
  final Size size;
  final EdgeInsets insets;
  final TextDirection direction;
  final ThemeData theme;
  final double textScale;

  Rect get safeRect => Rect.fromLTRB(
        insets.left,
        insets.top,
        size.width - insets.right,
        size.height - insets.bottom,
      );
}

final _landscapeCases = <_LandscapeCase>[
  _LandscapeCase(
    name: 'wide-landscape-rtl-large-text',
    size: Size(720, 320),
    insets: EdgeInsets.fromLTRB(28, 12, 28, 20),
    direction: TextDirection.rtl,
    theme: CutawanTheme.light(),
    textScale: 1.5,
  ),
  _LandscapeCase(
    name: 'wide-landscape-ltr-standard-text',
    size: Size(844, 390),
    insets: EdgeInsets.fromLTRB(36, 10, 36, 24),
    direction: TextDirection.ltr,
    theme: CutawanTheme.dark(),
    textScale: 1,
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

class _LandscapeDeviceAcceptanceService extends DeviceAcceptanceService {
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

Widget _landscapeHarness(
  _LandscapeCase variant, {
  required Widget page,
  bool dashboardNeedsScaffold = false,
}) {
  final pageContent = dashboardNeedsScaffold
      ? Scaffold(body: page)
      : page;
  return MaterialApp(
    theme: variant.theme,
    home: MediaQuery(
      data: MediaQueryData(
        size: variant.size,
        padding: variant.insets,
        viewPadding: variant.insets,
        textScaler: TextScaler.linear(variant.textScale),
      ),
      child: Directionality(
        textDirection: variant.direction,
        child: SafeArea(child: pageContent),
      ),
    ),
  );
}

void _expectInsideSafeRegion(
  WidgetTester tester,
  Finder target,
  _LandscapeCase variant,
) {
  final rect = tester.getRect(target);
  final safe = variant.safeRect;

  expect(
    rect.left,
    greaterThanOrEqualTo(safe.left - 1),
    reason: '${variant.name}: page content crossed the left system inset.',
  );
  expect(
    rect.top,
    greaterThanOrEqualTo(safe.top - 1),
    reason: '${variant.name}: page content crossed the top system inset.',
  );
  expect(
    rect.right,
    lessThanOrEqualTo(safe.right + 1),
    reason: '${variant.name}: page content crossed the right system inset.',
  );
  expect(
    rect.bottom,
    lessThanOrEqualTo(safe.bottom + 1),
    reason: '${variant.name}: page content crossed the bottom system inset.',
  );
}

Future<void> _pumpLandscapeCase(
  WidgetTester tester,
  _LandscapeCase variant,
  Widget app,
) async {
  expect(
    variant.size.width,
    greaterThan(variant.size.height),
    reason: '${variant.name} must exercise a landscape viewport.',
  );
  expect(
    variant.insets.horizontal,
    greaterThan(0),
    reason: 'The landscape case must model horizontal cutout/gesture insets.',
  );
  expect(
    variant.insets.vertical,
    greaterThan(0),
    reason: 'The landscape case must model top and bottom system insets.',
  );

  tester.view.physicalSize = variant.size;
  tester.view.devicePixelRatio = 1;
  await tester.pumpWidget(app);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'Dashboard remains inside landscape safe bounds with large text',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final projects = ValueNotifier<List<CutawanProject>>([]);
      addTearDown(projects.dispose);

      for (final variant in _landscapeCases) {
        await _pumpLandscapeCase(
          tester,
          variant,
          _landscapeHarness(
            variant,
            dashboardNeedsScaffold: true,
            page: DashboardPage(
              projects: projects,
              onCreate: () {},
              onOpenJobs: () {},
              onOpenReview: () {},
              onOpenModels: () {},
              onOpenSettings: () {},
              onOpenProject: (_) {},
              storageUsageBytes: () async => 4 * 1024 * 1024,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        _expectInsideSafeRegion(
          tester,
          find.byKey(const ValueKey('cutawan-dashboard-list')),
          variant,
        );
        _expectInsideSafeRegion(
          tester,
          find.byTooltip('الإعدادات'),
          variant,
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Settings remains inside landscape safe bounds with system insets',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final store = AppPreferencesStore.inMemory();
      addTearDown(store.dispose);

      for (final variant in _landscapeCases) {
        await _pumpLandscapeCase(
          tester,
          variant,
          _landscapeHarness(
            variant,
            page: SettingsPage(
              store: store,
              onDiagnostics: () {},
              onModels: () {},
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        _expectInsideSafeRegion(
          tester,
          find.byKey(const ValueKey('cutawan-settings-list')),
          variant,
        );

        final diagnostics = find.ancestor(
          of: find.text('تشخيص وقبول Android'),
          matching: find.byType(ListTile),
        ).first;
        await tester.ensureVisible(diagnostics);
        await tester.pump();
        _expectInsideSafeRegion(tester, diagnostics, variant);
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Models Center remains inside landscape safe bounds with system insets',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final credentials = AiCredentialStore(
        storage: _MemoryCredentialStorage(),
      );

      for (final variant in _landscapeCases) {
        await _pumpLandscapeCase(
          tester,
          variant,
          _landscapeHarness(
            variant,
            page: ModelsPage(
              credentials: credentials,
              checkWhisperInstalled: () async => false,
              checkQwenInstalled: () async => false,
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        final list = find.byType(ListView).first;
        _expectInsideSafeRegion(tester, list, variant);

        final refreshLabel = find.text('إعادة فحص النماذج المحلية');
        await tester.scrollUntilVisible(
          refreshLabel,
          180,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pump();
        final refresh = find.ancestor(
          of: refreshLabel,
          matching: find.byType(TextButton),
        ).first;
        _expectInsideSafeRegion(tester, refresh, variant);
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'Device Diagnostics remains inside landscape safe bounds with system insets',
    (tester) async {
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      for (final variant in _landscapeCases) {
        await _pumpLandscapeCase(
          tester,
          variant,
          _landscapeHarness(
            variant,
            page: DeviceAcceptancePage(
              service: _LandscapeDeviceAcceptanceService(),
            ),
          ),
        );

        expect(tester.takeException(), isNull);
        _expectInsideSafeRegion(
          tester,
          find.byType(ListView).first,
          variant,
        );
        _expectInsideSafeRegion(
          tester,
          find.byTooltip('إعادة الفحص'),
          variant,
        );
      }

      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
