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
