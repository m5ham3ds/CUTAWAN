import 'package:flutter/services.dart';

import '../domain/project_contract.dart';

class AndroidVideoPicker {
  AndroidVideoPicker._();

  static const MethodChannel _channel =
      MethodChannel('com.cutawan.mobile/media');

  static Future<VideoAssetMetadata?> pickVideo() async {
    final result = await _channel.invokeMapMethod<String, Object?>('pickVideo');
    if (result == null) return null;
    return VideoAssetMetadata.fromJson(
      Map<String, dynamic>.from(result),
    );
  }

  static Future<void> releasePersistedPermission(String uri) async {
    final parsed = Uri.tryParse(uri);
    if (parsed == null || parsed.scheme != 'content') return;
    await _channel.invokeMethod<void>(
      'releasePersistedPermission',
      <String, Object?>{'uri': uri},
    );
  }

  static Future<int> availableStorageBytes() async {
    final result = await _channel.invokeMethod<num>('getAvailableStorageBytes');
    if (result == null || result < 0) {
      throw const FormatException('Android returned an invalid free-space value.');
    }
    return result.toInt();
  }

  static Future<VideoAssetMetadata> inspectLocalFile(String path) {
    return inspectVideo(Uri.file(path).toString());
  }

  static Future<String> fingerprintVideo(String uri) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'fingerprintVideo',
      <String, Object?>{'uri': uri},
    );
    final fingerprint = result?['sha256'];
    if (fingerprint is! String || !_isSha256(fingerprint)) {
      throw const FormatException('Android returned an invalid source SHA-256 fingerprint.');
    }
    return fingerprint;
  }

  static bool _isSha256(String value) {
    if (value.length != 64) return false;
    for (final unit in value.codeUnits) {
      final valid = (unit >= 48 && unit <= 57) || (unit >= 97 && unit <= 102);
      if (!valid) return false;
    }
    return true;
  }

  static Future<VideoAssetMetadata> inspectVideo(String uri) async {
    final result = await _channel.invokeMapMethod<String, Object?>(
      'inspectVideo',
      <String, Object?>{'uri': uri},
    );
    if (result == null) {
      throw const FormatException('Android returned no video metadata.');
    }
    return VideoAssetMetadata.fromJson(
      Map<String, dynamic>.from(result),
    );
  }
}
