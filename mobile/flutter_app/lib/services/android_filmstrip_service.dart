import 'dart:typed_data';

import 'package:flutter/services.dart';

class FilmstripFrame {
  const FilmstripFrame({
    required this.timestampMs,
    required this.imageBytes,
    required this.width,
    required this.height,
  });

  final int timestampMs;
  final Uint8List imageBytes;
  final int width;
  final int height;
}

class AndroidFilmstripService {
  const AndroidFilmstripService({
    MethodChannel channel = const MethodChannel('com.cutawan.mobile/media'),
  }) : _channel = channel;

  final MethodChannel _channel;

  Future<List<FilmstripFrame>> generate({
    required String sourceUri,
    required int startMs,
    required int endMs,
    int sampleCount = 7,
  }) async {
    final uri = Uri.tryParse(sourceUri);
    if (uri == null ||
        !{'content', 'file', 'http', 'https'}.contains(uri.scheme) ||
        startMs < 0 ||
        endMs <= startMs ||
        sampleCount < 3 ||
        sampleCount > 10) {
      throw const FormatException('Filmstrip source or time range is invalid.');
    }

    final response = await _channel.invokeListMethod<Object?>(
      'createFilmstrip',
      <String, Object?>{
        'uri': sourceUri,
        'startMs': startMs,
        'endMs': endMs,
        'sampleCount': sampleCount,
      },
    );
    if (response == null || response.isEmpty || response.length > sampleCount) {
      throw const FormatException('Android returned no valid filmstrip frames.');
    }

    final frames = <FilmstripFrame>[];
    var previousTimestamp = -1;
    for (final item in response) {
      if (item is! Map) {
        throw const FormatException('A filmstrip frame must be an object.');
      }
      final timestamp = (item['timestampMs'] as num?)?.toInt();
      final rawBytes = item['imageBytes'];
      final width = (item['width'] as num?)?.toInt();
      final height = (item['height'] as num?)?.toInt();
      final bytes = rawBytes is Uint8List
          ? rawBytes
          : rawBytes is List<int>
              ? Uint8List.fromList(rawBytes)
              : null;
      if (timestamp == null ||
          timestamp < startMs ||
          timestamp >= endMs ||
          timestamp <= previousTimestamp ||
          width == null ||
          height == null ||
          width <= 0 ||
          height <= 0 ||
          width > 320 ||
          height > 320 ||
          bytes == null ||
          bytes.length < 4 ||
          bytes.length > 1024 * 1024 ||
          bytes[0] != 0xff ||
          bytes[1] != 0xd8 ||
          bytes[bytes.length - 2] != 0xff ||
          bytes[bytes.length - 1] != 0xd9) {
        throw const FormatException('Android returned a malformed filmstrip frame.');
      }
      frames.add(FilmstripFrame(
        timestampMs: timestamp,
        imageBytes: bytes,
        width: width,
        height: height,
      ));
      previousTimestamp = timestamp;
    }
    return List<FilmstripFrame>.unmodifiable(frames);
  }
}
