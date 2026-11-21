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
    var canaryWritten = false;
    try {
      await _secretStorage.write(key, canary);
      canaryWritten = true;
      final stored = await _secretStorage.read(key);
      if (stored != canary) {
        throw StateError('Secure storage read-after-write did not match.');
      }
    } finally {
      if (canaryWritten) {
        await _secretStorage.delete(key);
      }
    }
    final leftover = await _secretStorage.read(key);
    if (leftover != null) {
      throw StateError('Secure storage diagnostic canary was not deleted.');
    }

    return <String, Object?>{
      ...native.map((key, value) => MapEntry(key, value)),
      'collectedAtUtc': DateTime.now().toUtc().toIso8601String(),
      'secureStorageRoundTrip': 'passed',
      'secureStorageCanaryDeleted': true,
      'phase10Acceptance': 'incomplete-device-and-media-evidence-required',
    };
  }
}
