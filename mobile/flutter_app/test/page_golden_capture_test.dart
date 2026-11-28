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

class _GoldenVariant {
  const _GoldenVariant({
    required this.name,
    required this.size,
    required this.direction,
    required this.dark,
    required this.textScale,
  });

  final String name;
  final Size size;
  final TextDirection direction;
  final bool dark;
  final double textScale;

  ThemeData get theme => dark ? CutawanTheme.dark() : CutawanTheme.light();
}

const _variants = <_GoldenVariant>[
  _GoldenVariant(
    name: 'compact-rtl-light',
    size: Size(320, 780),
    direction: TextDirection.rtl,
    dark: false,
    textScale: 2,
  ),
  _GoldenVariant(
    name: 'compact-ltr-dark',
    size: Size(320, 780),
    direction: TextDirection.ltr,
    dark: true,
    textScale: 1.5,
  ),
  _GoldenVariant(
    name: 'regular-rtl-dark',
    size: Size(390, 844),
    direction: TextDirection.rtl,
    dark: true,
    textScale: 1,
  ),
  _GoldenVariant(
    name: 'regular-ltr-light',
    size: Size(390, 844),
    direction: TextDirection.ltr,
    dark: false,
    textScale: 1.5,
  ),
  _GoldenVariant(
    name: 'wide-rtl-light',
    size: Size(720, 900),
    direction: TextDirection.rtl,
    dark: false,
    textScale: 1,
  ),
  _GoldenVariant(
    name: 'wide-ltr-dark',
    size: Size(720, 900),
    direction: TextDirection.ltr,
    dark: true,
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

class _GoldenDeviceAcceptanceService extends DeviceAcceptanceService {
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

Widget _goldenFrame({
  required _GoldenVariant variant,
  required String key,
  required Widget page,
}) {
  return MaterialApp(
    theme: variant.theme,
    home: Builder(
      builder: (context) {
        final media = MediaQuery.of(context).copyWith(
          size: variant.size,
          textScaler: TextScaler.linear(variant.textScale),
        );
        return RepaintBoundary(
          key: ValueKey<String>(key),
          child: MediaQuery(
            data: media,
            child: Directionality(
              textDirection: variant.direction,
              child: page,
            ),
          ),
        );
      },
    ),
  );
}

Future<void> _captureVariant(
  WidgetTester tester, {
  required String pageName,
  required _GoldenVariant variant,
  required Widget page,
}) async {
  tester.view.physicalSize = variant.size;
  tester.view.devicePixelRatio = 1;

  final captureKey = 'page-golden-$pageName-${variant.name}';
  await tester.pumpWidget(
    _goldenFrame(
      variant: variant,
      key: captureKey,
      page: page,
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 150));
  await expectLater(
    find.byKey(ValueKey<String>(captureKey)),
    matchesGoldenFile('goldens/pages/$pageName-${variant.name}.png'),
  );
  expect(tester.takeException(), isNull);
  await tester.pumpWidget(const SizedBox.shrink());
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Dashboard page golden matrix', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final projects = ValueNotifier<List<CutawanProject>>([]);
    addTearDown(projects.dispose);

    for (final variant in _variants) {
      await _captureVariant(
        tester,
        pageName: 'dashboard',
        variant: variant,
        page: Scaffold(
          body: DashboardPage(
            projects: projects,
            onCreate: () {},
            onOpenJobs: () {},
            onOpenReview: () {},
            onOpenProject: (_) {},
            storageUsageBytes: () async => 2 * 1024 * 1024,
          ),
        ),
      );
    }
  });

  testWidgets('Settings page golden matrix', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    final store = AppPreferencesStore.inMemory();
    addTearDown(store.dispose);

    for (final variant in _variants) {
      await _captureVariant(
        tester,
        pageName: 'settings',
        variant: variant,
        page: SettingsPage(
          store: store,
          onDiagnostics: () {},
          onModels: () {},
        ),
      );
    }
  });

  testWidgets('Models Center page golden matrix', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final variant in _variants) {
      final credentials = AiCredentialStore(
        storage: _MemoryCredentialStorage(),
      );
      await _captureVariant(
        tester,
        pageName: 'models',
        variant: variant,
        page: ModelsPage(
          credentials: credentials,
          checkWhisperInstalled: () async => false,
          checkQwenInstalled: () async => false,
        ),
      );
    }
  });

  testWidgets('Device Diagnostics page golden matrix', (tester) async {
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    for (final variant in _variants) {
      await _captureVariant(
        tester,
        pageName: 'diagnostics',
        variant: variant,
        page: DeviceAcceptancePage(
          service: _GoldenDeviceAcceptanceService(),
        ),
      );
    }
  });
}
