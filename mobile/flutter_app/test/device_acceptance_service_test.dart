import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/services/ai_model_gateway.dart';
import 'package:cutawan_mobile/services/device_acceptance_service.dart';

class _MemorySecretStorage implements AiSecretStorage {
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

class _FailingReadStorage extends _MemorySecretStorage {
  @override
  Future<String?> read(String key) async => null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.cutawan.mobile/media');
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  test('collects a baseline and verifies temporary secure-storage cleanup', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDeviceAcceptanceDiagnostics');
      return <String, Object?>{
        'manufacturer': 'Example',
        'model': 'Physical Test Device',
        'androidRelease': '16',
        'androidSdk': 36,
        'isPhysicalDevice': true,
        'cpuCoreCount': 8,
        'appVersionName': '0.2.0',
        'appVersionCode': 2,
        'totalMemoryBytes': 8 * 1024 * 1024 * 1024,
        'availableMemoryBytes': 4 * 1024 * 1024 * 1024,
        'processPssKb': 256000,
        'availableStorageBytes': 20 * 1024 * 1024 * 1024,
        'thermalStatus': 0,
        'batteryPercent': 80,
      };
    });
    final secureStorage = _MemorySecretStorage();
    final service = DeviceAcceptanceService(secretStorage: secureStorage);

    final report = await service.collect();

    expect(report['manufacturer'], 'Example');
    expect(report['model'], 'Physical Test Device');
    expect(report['buildSha'], DeviceAcceptanceService.buildSha);
    expect(report['fixtureEvidenceStatus'], 'not-collected-by-device-baseline');
    expect(report['deviceClass'], 'physical-candidate');
    expect(report['physicalDeviceHeuristicPassed'], isTrue);
    expect(report['physicalDeviceManualConfirmationStatus'], 'not-verified');
    expect(report['diagnosticBaselineStatus'], 'ready-for-physical-media-tests');
    expect(report['diagnosticMissingFields'], isEmpty);
    expect(report['buildIdentityPinned'], isFalse);
    expect(report['buildIdentityStatus'], 'local-or-unpinned-build');
    expect(report['mediaCorpusStatus'], 'not-collected');
    expect(report['videoFullDecodeStatus'], 'not-collected-on-physical-device');
    expect(report['secureStorageRoundTrip'], 'passed');
    expect(report['secureStorageCanaryDeleted'], isTrue);
    expect(
      report['phase10Acceptance'],
      'incomplete-device-and-media-evidence-required',
    );
    expect(secureStorage.values, isEmpty);
  });

  test('emulator diagnostics never qualify as a physical-device baseline', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => <String, Object?>{
      'manufacturer': 'Generic',
      'model': 'Android SDK built for x86',
      'androidRelease': '16',
      'androidSdk': 36,
      'isPhysicalDevice': false,
      'cpuCoreCount': 4,
      'totalMemoryBytes': 8 * 1024 * 1024 * 1024,
      'availableMemoryBytes': 4 * 1024 * 1024 * 1024,
      'processPssKb': 180000,
      'availableStorageBytes': 10 * 1024 * 1024 * 1024,
      'appVersionName': '0.2.0',
      'appVersionCode': 2,
    });
    final report = await DeviceAcceptanceService(
      secretStorage: _MemorySecretStorage(),
    ).collect();

    expect(report['deviceClass'], 'emulator-or-unverified');
    expect(report['diagnosticBaselineStatus'], 'incomplete');
    expect(report['diagnosticMissingFields'], contains('physicalDeviceMarkerCheck'));
    expect(report['phase10Acceptance'],
        'incomplete-device-and-media-evidence-required');
    expect(report['mediaCorpusStatus'], 'not-collected');
    expect(report['sustainedPerformanceStatus'], 'not-collected');
  });

  test('invalid memory ranges remain listed as missing evidence', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => <String, Object?>{
      'manufacturer': 'Example',
      'model': 'Device',
      'androidRelease': '16',
      'androidSdk': 36,
      'isPhysicalDevice': true,
      'cpuCoreCount': 8,
      'totalMemoryBytes': 8 * 1024 * 1024 * 1024,
      'availableMemoryBytes': 9 * 1024 * 1024 * 1024,
      'processPssKb': 1000,
      'availableStorageBytes': 1000,
      'appVersionName': '0.2.0',
      'appVersionCode': 2,
    });
    final report = await DeviceAcceptanceService(
      secretStorage: _MemorySecretStorage(),
    ).collect();

    expect(report['diagnosticBaselineStatus'], 'incomplete');
    expect(report['diagnosticMissingFields'], contains('availableMemoryBytes'));
  });

  test('missing core diagnostics keep the baseline incomplete', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => <String, Object?>{
      'manufacturer': 'Example',
      'model': 'Unknown',
      'isPhysicalDevice': true,
    });
    final report = await DeviceAcceptanceService(
      secretStorage: _MemorySecretStorage(),
    ).collect();

    expect(report['diagnosticBaselineStatus'], 'incomplete');
    expect(report['diagnosticMissingFields'], contains('androidSdk'));
    expect(report['diagnosticMissingFields'], contains('cpuCoreCount'));
    expect(report['diagnosticMissingFields'], contains('totalMemoryBytes'));
    expect(report['phase10Acceptance'],
        'incomplete-device-and-media-evidence-required');
  });

  test('does not create acceptance evidence when native diagnostics are missing', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => null);
    final service = DeviceAcceptanceService(secretStorage: _MemorySecretStorage());

    await expectLater(service.collect(), throwsA(isA<StateError>()));
  });

  test('fails secure-storage acceptance when the canary cannot be read back', () async {
    messenger.setMockMethodCallHandler(channel, (call) async => <String, Object?>{
          'manufacturer': 'Example',
          'model': 'Device',
        });
    final secureStorage = _FailingReadStorage();
    final service = DeviceAcceptanceService(secretStorage: secureStorage);

    await expectLater(service.collect(), throwsA(isA<StateError>()));
    expect(secureStorage.values, isEmpty);
  });
}
