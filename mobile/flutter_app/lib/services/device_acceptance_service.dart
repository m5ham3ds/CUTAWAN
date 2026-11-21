import 'dart:math';

import 'package:flutter/services.dart';

import 'ai_model_gateway.dart';

/// Collects on-device measurements for the Phase 10 acceptance record.
///
/// This is diagnostic evidence only; it does not mark physical acceptance complete.
class DeviceAcceptanceService {
  DeviceAcceptanceService({
    MethodChannel? channel,
    AiSecretStorage? secretStorage,
  })  : _channel = channel ?? const MethodChannel('com.cutawan.mobile/media'),
        _secretStorage = secretStorage ?? FlutterAiSecretStorage();

  final MethodChannel _channel;
  final AiSecretStorage _secretStorage;

  static const buildSha = String.fromEnvironment(
    'BUILD_SHA',
    defaultValue: 'local-or-untracked',
  );

  Future<Map<String, Object?>> collect() async {
    final native = await _channel.invokeMapMethod<String, dynamic>(
      'getDeviceAcceptanceDiagnostics',
    );
    if (native == null || native.isEmpty) {
      throw StateError('Android returned no device diagnostic data.');
    }

    final suffix = List<int>.generate(
      16,
      (_) => Random.secure().nextInt(256),
    ).map((value) => value.toRadixString(16).padLeft(2, '0')).join();
    final key = 'cutawan.phase10.keystore-self-test.$suffix';
    final canary = 'temporary-$suffix';

    try {
      await _secretStorage.write(key, canary);
      final stored = await _secretStorage.read(key);
      if (stored != canary) {
        throw StateError('Secure storage read-after-write did not match.');
      }
    } finally {
      await _secretStorage.delete(key);
    }
    final leftover = await _secretStorage.read(key);
    if (leftover != null) {
      throw StateError('Secure storage diagnostic canary was not deleted.');
    }

    final missingBaselineFields = <String>[];
    void requireField(bool condition, String field) {
      if (!condition) {
        missingBaselineFields.add(field);
      }
    }

    final manufacturer = native['manufacturer'];
    final model = native['model'];
    final androidRelease = native['androidRelease'];
    final androidSdk = native['androidSdk'];
    final cpuCores = native['cpuCoreCount'];
    final totalMemory = native['totalMemoryBytes'];
    final availableMemory = native['availableMemoryBytes'];
    final processPss = native['processPssKb'];
    final availableStorage = native['availableStorageBytes'];
    final appVersionName = native['appVersionName'];
    final appVersionCode = native['appVersionCode'];

    // Build.FINGERPRINT is a heuristic only; it cannot replace human confirmation.
    final physicalDeviceMarkerCheck = native['isPhysicalDevice'] == true;

    requireField(physicalDeviceMarkerCheck, 'physicalDeviceMarkerCheck');
    requireField(
      manufacturer is String && manufacturer.trim().isNotEmpty,
      'manufacturer',
    );
    requireField(model is String && model.trim().isNotEmpty, 'model');
    requireField(
      androidRelease is String && androidRelease.trim().isNotEmpty,
      'androidRelease',
    );
    requireField(androidSdk is num && androidSdk >= 26, 'androidSdk');
    requireField(cpuCores is num && cpuCores > 0, 'cpuCoreCount');
    requireField(totalMemory is num && totalMemory > 0, 'totalMemoryBytes');
    requireField(
      availableMemory is num &&
          totalMemory is num &&
          availableMemory >= 0 &&
          availableMemory <= totalMemory,
      'availableMemoryBytes',
    );
    requireField(processPss is num && processPss >= 0, 'processPssKb');
    requireField(
      availableStorage is num && availableStorage >= 0,
      'availableStorageBytes',
    );
    requireField(
      appVersionName is String && appVersionName.trim().isNotEmpty,
      'appVersionName',
    );
    requireField(
      appVersionCode is num && appVersionCode >= 0,
      'appVersionCode',
    );

    final baselineReady = missingBaselineFields.isEmpty;
    final buildShaPinned = RegExp(r'^[a-f0-9]{40}$').hasMatch(buildSha);

    return <String, Object?>{
      ...native.map((key, value) => MapEntry(key, value)),
      'collectedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'buildSha': buildSha,
      'fixtureEvidenceStatus': 'not-collected-by-device-baseline',
      'secureStorageRoundTrip': 'passed',
      'secureStorageCanaryDeleted': true,
      'diagnosticSchemaVersion': 2,
      'deviceClass': physicalDeviceMarkerCheck
          ? 'physical-candidate'
          : 'emulator-or-unverified',
      'physicalDeviceHeuristicPassed': physicalDeviceMarkerCheck,
      'physicalDeviceManualConfirmationStatus': 'not-verified',
      'diagnosticBaselineStatus':
          baselineReady ? 'ready-for-physical-media-tests' : 'incomplete',
      'diagnosticMissingFields': missingBaselineFields,
      'buildIdentityPinned': buildShaPinned,
      'buildIdentityStatus':
          buildShaPinned ? 'pinned-to-commit' : 'local-or-unpinned-build',
      'mediaCorpusStatus': 'not-collected',
      'speechQualityStatus': 'not-collected',
      'candidateQualityStatus': 'not-collected',
      'videoFullDecodeStatus': 'not-collected-on-physical-device',
      'sustainedPerformanceStatus': 'not-collected',
      'processDeathResumeStatus': 'not-verified-on-physical-device',
      'safLifecycleStatus': 'not-verified-across-force-stop',
      'keystoreLifecycleStatus': 'single-install-round-trip-only',
      'networkConsentEndToEndStatus': 'not-verified-on-physical-device',
      'phase10Acceptance': 'incomplete-device-and-media-evidence-required',
    };
  }
}
