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
