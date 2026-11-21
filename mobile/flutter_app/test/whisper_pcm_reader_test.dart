import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:cutawan_mobile/services/whisper_pcm_reader.dart';
import 'package:flutter_test/flutter_test.dart';

void _writeFourCc(ByteData data, int offset, String value) {
  for (var index = 0; index < 4; index++) {
    data.setUint8(offset + index, value.codeUnitAt(index));
  }
}

void main() {
  late Directory tempDirectory;

  setUp(() async {
    tempDirectory = await Directory.systemTemp.createTemp('cutawan-whisper-test-');
  });

  tearDown(() async {
    if (await tempDirectory.exists()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<File> createWav({
    required int sampleRate,
    required int channels,
    required int frameCount,
    required double Function(int frame, int channel) sample,
  }) async {
    final dataLength = frameCount * channels * 2;
    final bytes = Uint8List(44 + dataLength);
    final data = ByteData.sublistView(bytes);
    _writeFourCc(data, 0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    _writeFourCc(data, 8, 'WAVE');
    _writeFourCc(data, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, channels, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * channels * 2, Endian.little);
    data.setUint16(32, channels * 2, Endian.little);
    data.setUint16(34, 16, Endian.little);
    _writeFourCc(data, 36, 'data');
    data.setUint32(40, dataLength, Endian.little);

    var offset = 44;
    for (var frame = 0; frame < frameCount; frame++) {
      for (var channel = 0; channel < channels; channel++) {
        final value = (sample(frame, channel).clamp(-1.0, 1.0) * 32767).round();
        data.setInt16(offset, value, Endian.little);
        offset += 2;
      }
    }

    final file = File('${tempDirectory.path}/fixture-$sampleRate-$channels.wav');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }


  Future<File> create24BitWav() async {
    const sampleRate = 16000;
    const dataLength = 6;
    final bytes = Uint8List(44 + dataLength);
    final data = ByteData.sublistView(bytes);
    _writeFourCc(data, 0, 'RIFF');
    data.setUint32(4, 36 + dataLength, Endian.little);
    _writeFourCc(data, 8, 'WAVE');
    _writeFourCc(data, 12, 'fmt ');
    data.setUint32(16, 16, Endian.little);
    data.setUint16(20, 1, Endian.little);
    data.setUint16(22, 1, Endian.little);
    data.setUint32(24, sampleRate, Endian.little);
    data.setUint32(28, sampleRate * 3, Endian.little);
    data.setUint16(32, 3, Endian.little);
    data.setUint16(34, 24, Endian.little);
    _writeFourCc(data, 36, 'data');
    data.setUint32(40, dataLength, Endian.little);
    // 0x400000 = +0.5 and 0xC00000 = -0.5 as signed PCM24.
    bytes.setRange(44, 47, const [0x00, 0x00, 0x40]);
    bytes.setRange(47, 50, const [0x00, 0x00, 0xc0]);
    final file = File('${tempDirectory.path}/pcm24.wav');
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  test('signed 24-bit PCM samples decode with correct sign extension', () async {
    final file = await create24BitWav();
    final reader = await WhisperPcmReader.open(file);
    try {
      final samples = await reader.readSamples(0, 2);
      expect(samples, hasLength(2));
      expect(samples[0], closeTo(0.5, 0.0001));
      expect(samples[1], closeTo(-0.5, 0.0001));
    } finally {
      await reader.close();
    }
  });

  test('16 kHz mono input preserves PCM samples and timeline', () async {
    final file = await createWav(
      sampleRate: 16000,
      channels: 1,
      frameCount: 1600,
      sample: (frame, _) => frame.isEven ? 0.25 : -0.25,
    );

    final reader = await WhisperPcmReader.open(file);
    try {
      expect(reader.sourceSampleRate, 16000);
      expect(reader.sourceChannels, 1);
      expect(reader.outputSampleCount, 1600);
      expect(reader.durationMs, 100);
      final samples = await reader.readSamples(0, 1600);
      expect(samples, hasLength(1600));
      expect(samples[0], closeTo(0.25, 0.0001));
      expect(samples[1], closeTo(-0.25, 0.0001));
    } finally {
      await reader.close();
    }
  });

  test('44.1 kHz stereo is downmixed and resampled to 16 kHz mono', () async {
    final file = await createWav(
      sampleRate: 44100,
      channels: 2,
      frameCount: 4410,
      sample: (_, channel) => channel == 0 ? 0.2 : 0.6,
    );

    final reader = await WhisperPcmReader.open(file);
    try {
      expect(reader.outputSampleCount, 1600);
      final samples = await reader.readSamples(0, reader.outputSampleCount);
      expect(samples, hasLength(1600));
      for (final value in samples) {
        expect(value, closeTo(0.4, 0.0002));
      }
    } finally {
      await reader.close();
    }
  });

  test('48 kHz stereo resampling keeps a stable one-second output window', () async {
    final file = await createWav(
      sampleRate: 48000,
      channels: 2,
      frameCount: 48000,
      sample: (_, channel) => channel == 0 ? -0.3 : 0.5,
    );

    final reader = await WhisperPcmReader.open(file);
    try {
      expect(reader.durationMs, 1000);
      expect(reader.outputSampleCount, 16000);
      final first = await reader.readSamples(0, 8000);
      final second = await reader.readSamples(8000, 8000);
      expect(first, hasLength(8000));
      expect(second, hasLength(8000));
      expect(first.first, closeTo(0.1, 0.0002));
      expect(first.last, closeTo(0.1, 0.0002));
      expect(second.first, closeTo(0.1, 0.0002));
    } finally {
      await reader.close();
    }
  });

  test('silence remains silence after normalization', () async {
    final file = await createWav(
      sampleRate: 48000,
      channels: 2,
      frameCount: 4800,
      sample: (_, _) => 0,
    );

    final reader = await WhisperPcmReader.open(file);
    try {
      final samples = await reader.readSamples(0, reader.outputSampleCount);
      expect(samples, isNotEmpty);
      expect(samples.every((value) => value == 0), isTrue);
    } finally {
      await reader.close();
    }
  });

  test('reader rejects invalid and truncated WAV files', () async {
    final invalid = File('${tempDirectory.path}/invalid.wav');
    await invalid.writeAsBytes(List<int>.filled(64, 0));
    await expectLater(
      WhisperPcmReader.open(invalid),
      throwsA(isA<FormatException>()),
    );

    final truncated = File('${tempDirectory.path}/truncated.wav');
    await truncated.writeAsBytes(Uint8List.fromList([
      82, 73, 70, 70, 255, 255, 255, 127,
      87, 65, 86, 69,
    ]));
    await expectLater(
      WhisperPcmReader.open(truncated),
      throwsA(isA<FormatException>()),
    );
  });

  test('reader rejects sample requests outside the normalized timeline', () async {
    final file = await createWav(
      sampleRate: 16000,
      channels: 1,
      frameCount: 1600,
      sample: (_, _) => 0.1,
    );

    final reader = await WhisperPcmReader.open(file);
    try {
      await expectLater(
        reader.readSamples(-1, 1),
        throwsA(isA<RangeError>()),
      );
      await expectLater(
        reader.readSamples(1500, 200),
        throwsA(isA<RangeError>()),
      );
    } finally {
      await reader.close();
    }
  });

  test('streamed WAV ranges preserve identical samples across chunk boundaries', () async {
    final file = await createWav(
      sampleRate: 44100,
      channels: 2,
      frameCount: 44100,
      sample: (frame, _) =>
          (math.sin(2 * math.pi * 6000 * frame / 44100) * 12000) / 32768,
    );
    final reader = await WhisperPcmReader.open(file);
    try {
      final full = await reader.readSamples(0, reader.outputSampleCount);
      final streamed = <double>[];
      const readSize = 233;
      for (var offset = 0; offset < reader.outputSampleCount; offset += readSize) {
        final count = math.min(
          readSize,
          reader.outputSampleCount - offset,
        ).toInt();
        final part = await reader.readSamples(offset, count);
        streamed.addAll(part);
      }

      expect(streamed, hasLength(full.length));
      for (var index = 0; index < full.length; index++) {
        expect(streamed[index], closeTo(full[index], 1e-7));
      }
    } finally {
      await reader.close();
    }
  });

}
