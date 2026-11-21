import 'dart:io';
import 'dart:typed_data';

import 'package:cutawan_mobile/services/wav_audio_normalizer.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List pcmWav({
  required int sampleRate,
  required int channels,
  required int frames,
  required int Function(int frame, int channel) sample,
}) {
  final dataBytes = frames * channels * 2;
  final bytes = Uint8List(44 + dataBytes);
  final data = ByteData.sublistView(bytes);

  void writeAscii(int offset, String value) {
    for (var i = 0; i < value.length; i++) {
      bytes[offset + i] = value.codeUnitAt(i);
    }
  }

  writeAscii(0, 'RIFF');
  data.setUint32(4, 36 + dataBytes, Endian.little);
  writeAscii(8, 'WAVE');
  writeAscii(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, channels, Endian.little);
  data.setUint32(24, sampleRate, Endian.little);
  data.setUint32(28, sampleRate * channels * 2, Endian.little);
  data.setUint16(32, channels * 2, Endian.little);
  data.setUint16(34, 16, Endian.little);
  writeAscii(36, 'data');
  data.setUint32(40, dataBytes, Endian.little);

  var offset = 44;
  for (var frame = 0; frame < frames; frame++) {
    for (var channel = 0; channel < channels; channel++) {
      data.setInt16(offset, sample(frame, channel), Endian.little);
      offset += 2;
    }
  }
  return bytes;
}

Future<NormalizedSpeechAudio> normalizeBytes(Uint8List bytes) async {
  final file = File(
    '${Directory.systemTemp.path}${Platform.pathSeparator}'
    'cutawan_audio_${DateTime.now().microsecondsSinceEpoch}.wav',
  );
  await file.writeAsBytes(bytes, flush: true);
  try {
    return await WavAudioNormalizer.readAsMono16k(file);
  } finally {
    if (await file.exists()) await file.delete();
  }
}

void main() {
  test('keeps 16kHz mono PCM at its original sample count and level', () async {
    final audio = await normalizeBytes(pcmWav(
      sampleRate: 16000,
      channels: 1,
      frames: 16000,
      sample: (_, _) => 8192,
    ));

    expect(audio.samples.length, 16000);
    expect(audio.sourceSampleRate, 16000);
    expect(audio.sourceChannels, 1);
    expect(audio.sourceDurationMs, 1000);
    expect(audio.samples[8000], closeTo(0.25, 0.0001));
  });

  test('downmixes 44.1kHz stereo and resamples actual samples to 16kHz', () async {
    final audio = await normalizeBytes(pcmWav(
      sampleRate: 44100,
      channels: 2,
      frames: 44100,
      sample: (_, channel) => channel == 0 ? 8192 : 16384,
    ));

    expect(audio.samples.length, 16000);
    expect(audio.sourceSampleRate, 44100);
    expect(audio.sourceChannels, 2);
    expect(audio.sourceDurationMs, 1000);
    expect(audio.samples[5000], closeTo(0.375, 0.002));
  });

  test('downmixes 48kHz stereo and resamples to exactly one second', () async {
    final audio = await normalizeBytes(pcmWav(
      sampleRate: 48000,
      channels: 2,
      frames: 48000,
      sample: (_, channel) => channel == 0 ? 4096 : 12288,
    ));

    expect(audio.samples.length, 16000);
    expect(audio.samples[10000], closeTo(0.25, 0.002));
  });

  test('preserves silence when resampling', () async {
    final audio = await normalizeBytes(pcmWav(
      sampleRate: 44100,
      channels: 2,
      frames: 44100,
      sample: (_, _) => 0,
    ));

    expect(audio.samples.length, 16000);
    expect(audio.samples.every((sample) => sample == 0), isTrue);
  });

  test('rejects truncated WAV and malformed PCM frame data', () async {
    final valid = pcmWav(
      sampleRate: 16000,
      channels: 1,
      frames: 160,
      sample: (_, _) => 1,
    );
    await expectLater(
      normalizeBytes(valid.sublist(0, 32)),
      throwsA(isA<FormatException>()),
    );

    final malformed = valid.sublist(0, valid.length - 1);
    final data = ByteData.sublistView(malformed);
    data.setUint32(40, data.getUint32(40, Endian.little) - 1, Endian.little);
    data.setUint32(4, data.getUint32(4, Endian.little) - 1, Endian.little);
    await expectLater(
      normalizeBytes(malformed),
      throwsA(isA<FormatException>()),
    );
  });
}
