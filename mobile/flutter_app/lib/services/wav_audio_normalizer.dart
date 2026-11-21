import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Parsed and normalized speech audio. Samples are always mono Float32 PCM
/// with a 16 kHz time base, which is the format expected by whisper.cpp.
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

class WavAudioNormalizer {
  WavAudioNormalizer._();

  static const int targetSampleRate = 16000;
  static const int _filterRadius = 8;
  static const int _phaseCount = 128;

  /// Reads the PCM16 WAV emitted by the native MediaCodec bridge, downmixes
  /// all channels to mono, and resamples the actual samples to 16 kHz.
  ///
  /// The resampler uses a small windowed-sinc low-pass filter when changing
  /// sample rate, preventing high-frequency energy from folding into speech
  /// frequencies during common 44.1/48 kHz -> 16 kHz conversions.
  static Future<NormalizedSpeechAudio> readAsMono16k(File file) async {
    final bytes = await file.readAsBytes();
    if (bytes.length < 44) {
      throw const FormatException('WAV file is shorter than its RIFF header.');
    }

    final data = ByteData.sublistView(bytes);
    String fourCc(int offset) =>
        String.fromCharCodes(bytes.sublist(offset, offset + 4));

    if (fourCc(0) != 'RIFF' || fourCc(8) != 'WAVE') {
      throw const FormatException('Audio extractor returned a non-RIFF/WAVE file.');
    }

    final riffSize = data.getUint32(4, Endian.little);
    final riffEnd = 8 + riffSize;
    if (riffSize < 4 || riffEnd > bytes.length) {
      throw const FormatException('WAV RIFF length is truncated or invalid.');
    }

    int? formatTag;
    int? channels;
    int? sampleRate;
    int? bitsPerSample;
    int? blockAlign;
    int? audioOffset;
    int? audioBytes;

    var offset = 12;
    while (offset + 8 <= riffEnd) {
      final chunkId = fourCc(offset);
      final chunkSize = data.getUint32(offset + 4, Endian.little);
      final chunkData = offset + 8;
      final chunkEnd = chunkData + chunkSize;
      if (chunkEnd > riffEnd || chunkEnd > bytes.length) {
        throw const FormatException('WAV contains a truncated RIFF chunk.');
      }

      if (chunkId == 'fmt ') {
        if (chunkSize < 16) {
          throw const FormatException('WAV fmt chunk is incomplete.');
        }
        formatTag = data.getUint16(chunkData, Endian.little);
        channels = data.getUint16(chunkData + 2, Endian.little);
        sampleRate = data.getUint32(chunkData + 4, Endian.little);
        blockAlign = data.getUint16(chunkData + 12, Endian.little);
        bitsPerSample = data.getUint16(chunkData + 14, Endian.little);
      } else if (chunkId == 'data' && audioOffset == null) {
        audioOffset = chunkData;
        audioBytes = chunkSize;
      }

      offset = chunkEnd + (chunkSize.isOdd ? 1 : 0);
    }

    if (formatTag != 1) {
      throw FormatException('Only integer PCM WAV is supported (format=$formatTag).');
    }
    if (channels == null || channels < 1 || channels > 8 ||
        sampleRate == null || sampleRate < 8000 || sampleRate > 192000 ||
        bitsPerSample != 16 || blockAlign != channels * 2 ||
        audioOffset == null || audioBytes == null || audioBytes <= 0) {
      throw const FormatException('WAV PCM format or audio data is invalid.');
    }
    if (audioBytes % blockAlign! != 0) {
      throw const FormatException('WAV audio data ends in a partial PCM frame.');
    }

    final sourceFrames = audioBytes ~/ blockAlign;
    if (sourceFrames <= 0) {
      throw const FormatException('WAV contains no decoded audio frames.');
    }
    final sourceDurationMs = (sourceFrames * 1000 / sampleRate).round();
    final outputFrames =
        (((sourceFrames - 1) * targetSampleRate) / sampleRate).floor() + 1;

    final output = Float32List(outputFrames);
    if (sampleRate == targetSampleRate && channels == 1) {
      for (var frame = 0; frame < outputFrames; frame++) {
        output[frame] = data.getInt16(
              audioOffset + frame * blockAlign,
              Endian.little,
            ) /
            32768.0;
      }
    } else {
      final coefficients = _buildResampleKernel(sampleRate);
      final sourceStep = sampleRate / targetSampleRate;
      for (var outputIndex = 0; outputIndex < outputFrames; outputIndex++) {
        final sourcePosition = outputIndex * sourceStep;
        var center = sourcePosition.floor();
        var phase = ((sourcePosition - center) * _phaseCount).round();
        if (phase >= _phaseCount) {
          center++;
          phase = 0;
        }
        final weights = coefficients[phase];
        var value = 0.0;
        var weightTotal = 0.0;
        for (var tap = -_filterRadius; tap <= _filterRadius; tap++) {
          final sourceFrame =
              (center + tap).clamp(0, sourceFrames - 1).toInt();
          final weight = weights[tap + _filterRadius];
          final frameOffset = audioOffset + sourceFrame * blockAlign;
          var mixed = 0.0;
          for (var channel = 0; channel < channels; channel++) {
            mixed += data.getInt16(
                  frameOffset + channel * 2,
                  Endian.little,
                ) /
                32768.0;
          }
          mixed /= channels;
          value += mixed * weight;
          weightTotal += weight;
        }
        output[outputIndex] = (weightTotal == 0 ? 0.0 : value / weightTotal)
            .clamp(-1.0, 1.0)
            .toDouble();
      }
    }

    return NormalizedSpeechAudio(
      samples: output,
      sourceSampleRate: sampleRate,
      sourceChannels: channels,
      sourceDurationMs: sourceDurationMs,
    );
  }

  static List<Float64List> _buildResampleKernel(int sourceRate) {
    final double cutoff = math
        .min(0.48, 0.48 * targetSampleRate / sourceRate)
        .toDouble();
    final kernels = <Float64List>[];
    for (var phase = 0; phase < _phaseCount; phase++) {
      final fraction = phase / _phaseCount;
      final weights = Float64List(_filterRadius * 2 + 1);
      var total = 0.0;
      for (var tap = -_filterRadius; tap <= _filterRadius; tap++) {
        final distance = tap - fraction;
        final scaled = 2 * cutoff * distance;
        final sinc = scaled.abs() < 1e-12
            ? 1.0
            : math.sin(math.pi * scaled) / (math.pi * scaled);
        final windowPosition = distance / (_filterRadius + 1);
        final window = windowPosition.abs() >= 1
            ? 0.0
            : 0.54 + 0.46 * math.cos(math.pi * windowPosition);
        final weight = 2 * cutoff * sinc * window;
        weights[tap + _filterRadius] = weight;
        total += weight;
      }
      if (total.abs() > 1e-12) {
        for (var i = 0; i < weights.length; i++) {
          weights[i] /= total;
        }
      }
      kernels.add(weights);
    }
    return kernels;
  }
}
