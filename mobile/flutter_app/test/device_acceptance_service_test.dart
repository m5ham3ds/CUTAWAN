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

  test('collects device baseline and verifies temporary secure-storage cleanup', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'getDeviceAcceptanceDiagnostics');
      return <String, Object?>{
        'manufacturer': 'Example',
        'model': 'Physical Test Device',
        'androidRelease': '16',
        'androidSdk': 36,
        'isPhysicalDevice': true,
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
    expect(report['secureStorageRoundTrip'], 'passed');
    expect(report['secureStorageCanaryDeleted'], isTrue);
    expect(
      report['phase10Acceptance'],
      'incomplete-device-and-media-evidence-required',
    );
    expect(secureStorage.values, isEmpty);
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
