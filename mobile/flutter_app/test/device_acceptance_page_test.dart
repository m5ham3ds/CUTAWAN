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
        'diagnosticCollectionScope': 'device-metadata-and-temporary-keystore-self-test',
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
      textScale: 2,
    );

    expect(find.text('تشخيص الجهاز'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('معلومات الجهاز'),
      220,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('معلومات الجهاز'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('البطارية والذاكرة'),
      280,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('البطارية والذاكرة'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('production diagnostics hide development acceptance details',
      (tester) async {
    await pumpPage(
      tester,
      size: const Size(390, 844),
      theme: CutawanTheme.dark(),
    );

    expect(find.text('بوابة القبول الميداني'), findsNothing);
    expect(find.textContaining('المرحلة 10'), findsNothing);
    expect(find.text('الأمان والخصوصية'), findsNothing);
    expect(
      find.text('نسخ قالب نتائج الاختبارات الميدانية JSON'),
      findsNothing,
    );
    expect(find.text('نسخ تقرير الدعم'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('support diagnostics omit build identifiers and acceptance data',
      (tester) async {
    await pumpPage(
      tester,
      size: const Size(390, 844),
      theme: CutawanTheme.dark(),
    );

    await tester.scrollUntilVisible(
      find.textContaining('X9c Long Device Model Name'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(
      find.textContaining('HONOR X9c Long Device Model Name'),
      findsOneWidget,
    );
    expect(find.text('إصدار التطبيق'), findsOneWidget);
    expect(find.text('ربط البناء بمصدره'), findsNothing);
    expect(
      find.text('1234567890abcdef1234567890abcdef12345678'),
      findsNothing,
    );
    expect(tester.takeException(), isNull);
  });
}
