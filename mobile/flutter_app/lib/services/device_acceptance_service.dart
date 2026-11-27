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

  /// Required physical field checks grouped by the phase they help close.
  ///
  /// These identifiers are a checklist contract only. A generated template
  /// never marks a field check as passed or treats a system heuristic as proof.
  static const Map<String, List<String>> fieldEvidenceCheckIds =
      <String, List<String>>{
    'phase8': <String>[
      'physical_arm64_build_identity',
      'real_media_import_export',
      'full_track_decode_and_output_integrity',
      'workmanager_background_completion',
      'process_death_resume_and_durable_handoff',
      'notification_permission_and_cancellation',
      'force_stop_and_oem_battery_behavior',
      'targeted_rerender_peer_preservation_and_cleanup',
    ],
    'phase9': <String>[
      'arabic_rtl_and_english_ltr',
      'large_text_portrait_and_landscape',
      'system_bars_insets_and_cutouts',
      'keyboard_navigation_and_visible_focus',
      'clip_editor_trim_filmstrip_framing_and_export',
    ],
    'phase10': <String>[
      'hash_locked_arabic_english_media_corpus',
      'whisper_wer_and_word_timing',
      'candidate_precision_completeness_and_duplicates',
      'face_tracking_and_crop_continuity',
      'full_decode_and_caption_synchronization',
      'sustained_memory_storage_and_processing',
      'battery_and_thermal_behavior',
      'process_resume_and_saf_permission_lifecycle',
      'keystore_backup_restore_and_rotation',
      'network_consent_enforcement',
    ],
  };

  static const List<String> _fieldEvidenceDeviceFields = <String>[
    'manufacturer',
    'model',
    'androidRelease',
    'androidSdk',
    'cpuCoreCount',
    'totalMemoryBytes',
    'availableMemoryBytes',
    'processPssKb',
    'processPrivateDirtyKb',
    'availableStorageBytes',
    'batteryPercent',
    'batteryTemperatureTenthsC',
    'thermalStatus',
    'lowMemory',
    'appVersionName',
    'appVersionCode',
    'collectedAtUtc',
  ];

  /// Builds a privacy-filtered, versioned field-test template from diagnostics.
  ///
  /// Device identity is not manually confirmed, all checks remain not-run,
  /// and all phase acceptance fields remain not-accepted until evidence is
  /// entered and independently reviewed.
  static Map<String, Object?> createFieldEvidenceTemplate(
    Map<String, Object?> diagnosticReport,
  ) {
    final device = <String, Object?>{};
    for (final field in _fieldEvidenceDeviceFields) {
      final value = diagnosticReport[field];
      if (value != null) {
        device[field] = value;
      }
    }

    final checks = <String, Object?>{};
    for (final group in fieldEvidenceCheckIds.entries) {
      checks[group.key] = <String, Object?>{
        for (final checkId in group.value)
          checkId: <String, Object?>{
            'status': 'not-run',
            'evidence': <String>[],
            'measurements': <String, Object?>{},
            'notes': '',
          },
      };
    }

    final reportBuildSha = diagnosticReport['buildSha'];
    return <String, Object?>{
      'schema': 'org.cutawan.phase10.field-evidence',
      'schemaVersion': 1,
      'createdAtUtc': DateTime.now().toUtc().toIso8601String(),
      'application': <String, Object?>{
        'buildSha': reportBuildSha is String ? reportBuildSha : buildSha,
        'buildIdentityPinned': diagnosticReport['buildIdentityPinned'] == true,
        'versionName': diagnosticReport['appVersionName'],
        'versionCode': diagnosticReport['appVersionCode'],
      },
      'device': device,
      'physicalDeviceConfirmation': <String, Object?>{
        'status': 'not-confirmed',
        'method': null,
        'confirmedAtUtc': null,
      },
      'fixtures': <Map<String, Object?>>[],
      'checks': checks,
      'acceptance': <String, Object?>{
        'phase8': 'not-accepted',
        'phase9': 'not-accepted',
        'phase10': 'not-accepted',
      },
      'rules': <String, Object?>{
        'allowedCheckStatuses': <String>[
          'not-run',
          'passed',
          'failed',
          'not-applicable',
        ],
        'passedCheckRequiresEvidence': true,
        'manualPhysicalDeviceConfirmationRequired': true,
        'systemDeviceHeuristicIsNotConfirmation': true,
        'fixtureSha256Required': true,
        'reviewRequiredBeforeAcceptance': true,
        'excludedData': <String>[
          'serial numbers and device identifiers',
          'account credentials and API keys',
          'personal file paths and source filenames',
          'source media and media contents',
        ],
      },
    };
  }

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
      'diagnosticCollectionScope':
          'device-metadata-and-temporary-keystore-self-test',
      'physicalMediaTestsExecuted': false,
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
