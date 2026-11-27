import 'dart:convert';

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
    expect(report['diagnosticCollectionScope'], 'device-metadata-and-temporary-keystore-self-test');
    expect(report['physicalMediaTestsExecuted'], isFalse);
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

  test('baseline readiness never claims media or performance acceptance', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (call) async => <String, Object?>{
        'manufacturer': 'Example',
        'model': 'Physical Candidate',
        'androidRelease': '16',
        'androidSdk': 36,
        'isPhysicalDevice': true,
        'cpuCoreCount': 8,
        'totalMemoryBytes': 8 * 1024 * 1024 * 1024,
        'availableMemoryBytes': 4 * 1024 * 1024 * 1024,
        'processPssKb': 160000,
        'availableStorageBytes': 20 * 1024 * 1024 * 1024,
        'appVersionName': '0.2.0',
        'appVersionCode': 2,
      },
    );
    final report = await DeviceAcceptanceService(
      secretStorage: _MemorySecretStorage(),
    ).collect();

    expect(report['diagnosticBaselineStatus'], 'ready-for-physical-media-tests');
    expect(report['physicalMediaTestsExecuted'], isFalse);
    expect(report['mediaCorpusStatus'], 'not-collected');
    expect(report['speechQualityStatus'], 'not-collected');
    expect(report['candidateQualityStatus'], 'not-collected');
    expect(report['videoFullDecodeStatus'], 'not-collected-on-physical-device');
    expect(report['sustainedPerformanceStatus'], 'not-collected');
    expect(report['processDeathResumeStatus'], 'not-verified-on-physical-device');
    expect(report['safLifecycleStatus'], 'not-verified-across-force-stop');
    expect(report['networkConsentEndToEndStatus'], 'not-verified-on-physical-device');
    expect(report['phase10Acceptance'], 'incomplete-device-and-media-evidence-required');
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

  test('field evidence template stays unrun and excludes private identifiers', () {
    final diagnosticReport = <String, Object?>{
      'buildSha': 'a' * 40,
      'buildIdentityPinned': true,
      'appVersionName': '0.2.0',
      'appVersionCode': 2,
      'manufacturer': 'HONOR',
      'model': 'X9c',
      'androidRelease': '16',
      'androidSdk': 36,
      'cpuCoreCount': 8,
      'totalMemoryBytes': 8 * 1024 * 1024 * 1024,
      'availableMemoryBytes': 4 * 1024 * 1024 * 1024,
      'processPssKb': 120000,
      'availableStorageBytes': 20 * 1024 * 1024 * 1024,
      'serialNumber': 'must-not-be-exported',
      'providerApiKey': 'must-not-be-exported',
      'sourceMediaPath': '/private/source/video.mp4',
      'sourceFilename': 'private-interview.mp4',
    };

    final template =
        DeviceAcceptanceService.createFieldEvidenceTemplate(diagnosticReport);

    expect(template['schema'], 'org.cutawan.phase10.field-evidence');
    expect(template['schemaVersion'], 1);
    expect(
      (template['application'] as Map)['buildSha'],
      'a' * 40,
    );
    expect((template['device'] as Map)['model'], 'X9c');
    expect((template['physicalDeviceConfirmation'] as Map)['status'],
        'not-confirmed');
    expect((template['fixtures'] as List), isEmpty);
    expect(
      template['acceptance'],
      <String, Object?>{
        'phase8': 'not-accepted',
        'phase9': 'not-accepted',
        'phase10': 'not-accepted',
      },
    );

    final groups = template['checks'] as Map;
    expect(groups.keys, containsAll(<String>['phase8', 'phase9', 'phase10']));
    for (final group in groups.values) {
      for (final check in (group as Map).values) {
        expect((check as Map)['status'], 'not-run');
        expect(check['evidence'], isEmpty);
        expect(check['measurements'], isEmpty);
      }
    }

    final encoded = jsonEncode(template);
    expect(encoded, isNot(contains('must-not-be-exported')));
    expect(encoded, isNot(contains('serialNumber')));
    expect(encoded, isNot(contains('providerApiKey')));
    expect(encoded, isNot(contains('/private/source')));
    expect(encoded, isNot(contains('private-interview.mp4')));
    expect(encoded, isNot(contains('systemDeviceHeuristicIsNotConfirmation":false')));
  });

}
