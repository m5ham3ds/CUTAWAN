import 'dart:io';
import 'dart:typed_data';

import 'whisper_pcm_reader.dart';

/// Parsed speech audio. Samples are mono Float32 PCM on a 16 kHz time base.
class NormalizedSpeechAudio {
  const NormalizedSpeechAudio({
    required this.samples,
    required this.sourceSampleRate,
    required this.sourceChannels,
    required this.sourceDurationMs,
  });

  final Float32List samples;
  final int sourceSampleRate;
  final int sourceChannels;
  final int sourceDurationMs;
}

/// Compatibility facade for callers that need a complete normalized buffer.
///
/// The production Whisper pipeline uses WhisperPcmReader directly and reads
/// bounded 30-second chunks. This method intentionally keeps the older
/// whole-buffer API for fixtures and small audio consumers while sharing the
/// exact same parser, downmixer, and filtered resampler.
class WavAudioNormalizer {
  WavAudioNormalizer._();

  static const int targetSampleRate = WhisperPcmReader.targetSampleRate;

  static Future<NormalizedSpeechAudio> readAsMono16k(File file) async {
    final reader = await WhisperPcmReader.open(file);
    try {
      final samples = await reader.readSamples(0, reader.outputSampleCount);
      return NormalizedSpeechAudio(
        samples: samples,
        sourceSampleRate: reader.sourceSampleRate,
        sourceChannels: reader.sourceChannels,
        sourceDurationMs: reader.durationMs,
      );
    } finally {
      await reader.close();
    }
  }
}
