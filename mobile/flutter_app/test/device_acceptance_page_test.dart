import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/screens/device_acceptance_page.dart';
import 'package:cutawan_mobile/services/device_acceptance_service.dart';
import 'package:cutawan_mobile/theme/cutawan_theme.dart';

class _FakeDeviceAcceptanceService extends DeviceAcceptanceService {
  @override
  Future<Map<String, Object?>> collect() async => <String, Object?>{
        'manufacturer': 'HONOR',
        'model': 'X9c Long Device Model Name',
        'androidRelease': '16',
        'androidSdk': 36,
        'deviceClass': 'physical-candidate',
        'physicalDeviceManualConfirmationStatus': 'not-verified',
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
        'collectedAtUtc': '2026-11-21T00:00:00.000Z',
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Future<void> pumpPage(
    WidgetTester tester, {
    required Size size,
    required ThemeData theme,
    double textScale = 1,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    await tester.pumpWidget(
      MaterialApp(
        theme: theme,
        home: MediaQuery(
          data: MediaQueryData(
            size: size,
            textScaler: TextScaler.linear(textScale),
          ),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: DeviceAcceptancePage(
              service: _FakeDeviceAcceptanceService(),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
  }

  testWidgets('fits a narrow phone with enlarged text without overflow',
      (tester) async {
    await pumpPage(
      tester,
      size: const Size(320, 780),
      theme: CutawanTheme.light(),
      textScale: 1.25,
    );

    expect(find.text('تشخيص الجهاز'), findsOneWidget);
    expect(find.text('بوابة القبول الميداني'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('معلومات الجهاز'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('معلومات الجهاز'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('الأمان والخصوصية'),
      360,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('الأمان والخصوصية'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses dark colors and wraps long device identifiers',
      (tester) async {
    await pumpPage(
      tester,
      size: const Size(390, 844),
      theme: CutawanTheme.dark(),
    );

    await tester.scrollUntilVisible(
      find.text('1234567890abcdef1234567890abcdef12345678'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.text('1234567890abcdef1234567890abcdef12345678'),
      findsOneWidget,
    );
    expect(find.text('ربط البناء بمصدره'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
