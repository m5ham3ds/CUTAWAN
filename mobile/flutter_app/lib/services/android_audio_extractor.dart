import 'dart:io';

import 'package:flutter/services.dart';

import '../domain/transcript_contract.dart';

class AudioExtractionResult {
  const AudioExtractionResult({
    required this.wavFile,
    required this.visualSamples,
  });

  final File wavFile;
  final List<VisualSceneSample> visualSamples;
}

class AndroidAudioExtractor {
  static const MethodChannel _channel =
      MethodChannel('com.cutawan.mobile/media');

  Future<AudioExtractionResult> extract(String sourceUri) async {
    final result = await _channel.invokeMapMethod<String, dynamic>(
      'extractAudio',
      <String, Object?>{'uri': sourceUri},
    );
    if (result == null || result['path'] is! String) {
      throw const FormatException('Android did not return an extracted audio file.');
    }
    final file = File(result['path'] as String);
    if (!await file.exists() || await file.length() < 44) {
      throw const FileSystemException('Extracted WAV file is missing or empty.');
    }
    final handle = await file.open(mode: FileMode.read);
    final header = await handle.read(12);
    await handle.close();
    if (header.length != 12 ||
        String.fromCharCodes(header.take(4)) != 'RIFF' ||
        String.fromCharCodes(header.skip(8).take(4)) != 'WAVE') {
      throw const FormatException('Android returned an invalid WAV container.');
    }
    final rawSamples = result['visualSamples'];
    final visual = rawSamples is List<dynamic>
        ? rawSamples
            .map((item) {
              if (item is! Map<String, dynamic>) {
                throw const FormatException('Visual sample must be a JSON object.');
              }
              return VisualSceneSample.fromJson(item);
            })
            .toList(growable: false)
        : const <VisualSceneSample>[];
    return AudioExtractionResult(wavFile: file, visualSamples: visual);
  }
}
