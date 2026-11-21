import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

/// Reads PCM WAV audio in bounded ranges and converts it to the format
/// required by Whisper: mono, signed float samples, 16 kHz.
///
/// The source file stays on disk. Only the requested output range and the
/// corresponding source frames are held in memory, so long videos are not
/// decoded into one enormous Float32List.
class WhisperPcmReader {
  WhisperPcmReader._({
    required RandomAccessFile file,
    required this.sourceSampleRate,
    required this.sourceChannels,
    required this.sourceBitsPerSample,
    required this.sourceFormat,
    required int dataOffset,
    required int dataLength,
    required int blockAlign,
  })  : _file = file,
        _dataOffset = dataOffset,
        _dataLength = dataLength,
        _blockAlign = blockAlign;

  static const int targetSampleRate = 16000;

  final RandomAccessFile _file;
  final int sourceSampleRate;
  final int sourceChannels;
  final int sourceBitsPerSample;
  final int sourceFormat;
  final int _dataOffset;
  final int _dataLength;
  final int _blockAlign;
  bool _closed = false;

  int get sourceFrameCount => _dataLength ~/ _blockAlign;

  int get outputSampleCount =>
      (sourceFrameCount * targetSampleRate / sourceSampleRate).round();

  int get durationMs =>
      (sourceFrameCount * 1000 / sourceSampleRate).round();

  static Future<WhisperPcmReader> open(File wavFile) async {
    final file = await wavFile.open(mode: FileMode.read);
    try {
      final fileLength = await file.length();
      if (fileLength < 44) {
        throw const FormatException('WAV file is too short.');
      }

      await file.setPosition(0);
      final riff = await _readExact(file, 12);
      if (_fourCc(riff, 0) != 'RIFF' || _fourCc(riff, 8) != 'WAVE') {
        throw const FormatException('Audio extractor did not return a RIFF/WAVE file.');
      }

      final riffSize = _u32(riff, 4);
      final riffEnd = riffSize + 8;
      if (riffEnd < 12 || riffEnd > fileLength) {
        throw const FormatException('WAV RIFF length is invalid or truncated.');
      }

      int? format;
      int? channels;
      int? sampleRate;
      int? bitsPerSample;
      int? blockAlign;
      int? dataOffset;
      int? dataLength;

      var cursor = 12;
      while (cursor + 8 <= riffEnd) {
        await file.setPosition(cursor);
        final chunkHeader = await _readExact(file, 8);
        final chunkId = _fourCc(chunkHeader, 0);
        final chunkLength = _u32(chunkHeader, 4);
        final chunkStart = cursor + 8;
        final chunkEnd = chunkStart + chunkLength;
        if (chunkEnd > riffEnd) {
          throw const FormatException('WAV chunk exceeds the declared RIFF length.');
        }

        if (chunkId == 'fmt ') {
          if (chunkLength < 16) {
            throw const FormatException('WAV format chunk is incomplete.');
          }
          await file.setPosition(chunkStart);
          final fmt = await _readExact(file, 16);
          format = _u16(fmt, 0);
          channels = _u16(fmt, 2);
          sampleRate = _u32(fmt, 4);
          blockAlign = _u16(fmt, 12);
          bitsPerSample = _u16(fmt, 14);
        } else if (chunkId == 'data' && dataOffset == null) {
          dataOffset = chunkStart;
          dataLength = chunkLength;
        }

        cursor = chunkEnd + (chunkLength.isOdd ? 1 : 0);
      }

      if (format == null ||
          channels == null ||
          sampleRate == null ||
          bitsPerSample == null ||
          blockAlign == null ||
          dataOffset == null ||
          dataLength == null) {
        throw const FormatException('WAV file is missing its format or data chunk.');
      }

      final bytesPerSample = bitsPerSample ~/ 8;
      final supportedPcmBits = const {8, 16, 24, 32}.contains(bitsPerSample);
      final supportedFloat = format == 3 && bitsPerSample == 32;
      if (format != 1 && !supportedFloat) {
        throw FormatException('Unsupported WAV encoding: $format / $bitsPerSample-bit.');
      }
      if (format == 1 && !supportedPcmBits) {
        throw FormatException('Unsupported PCM bit depth: $bitsPerSample.');
      }
      if (channels < 1 ||
          channels > 8 ||
          sampleRate < 8000 ||
          sampleRate > 192000 ||
          bytesPerSample == 0 ||
          blockAlign != channels * bytesPerSample ||
          dataLength <= 0 ||
          dataLength % blockAlign != 0) {
        throw const FormatException('WAV audio format or frame alignment is invalid.');
      }

      return WhisperPcmReader._(
        file: file,
        sourceSampleRate: sampleRate,
        sourceChannels: channels,
        sourceBitsPerSample: bitsPerSample,
        sourceFormat: format,
        dataOffset: dataOffset,
        dataLength: dataLength,
        blockAlign: blockAlign,
      );
    } catch (_) {
      await file.close();
      rethrow;
    }
  }

  /// Returns a normalized sample range indexed on the 16 kHz output timeline.
  Future<Float32List> readSamples(int outputStart, int outputCount) async {
    if (_closed) {
      throw StateError('WAV reader is already closed.');
    }
    if (outputStart < 0 ||
        outputCount < 0 ||
        outputStart + outputCount > outputSampleCount) {
      throw RangeError('Requested Whisper sample range is outside the WAV.');
    }
    if (outputCount == 0) return Float32List(0);

    final ratio = sourceSampleRate / targetSampleRate;
    final sourceStart = (outputStart * ratio).floor();
    final sourceEnd = math.min(
      sourceFrameCount,
      ((outputStart + outputCount) * ratio).ceil(),
    );
    final sourceCount = sourceEnd - sourceStart;
    if (sourceCount <= 0) {
      throw const FormatException('WAV range contains no source audio frames.');
    }

    final byteCount = sourceCount * _blockAlign;
    await _file.setPosition(_dataOffset + sourceStart * _blockAlign);
    final bytes = await _readExact(_file, byteCount);
    final data = ByteData.sublistView(bytes);
    final mono = Float32List(sourceCount);

    for (var frame = 0; frame < sourceCount; frame++) {
      var total = 0.0;
      final frameOffset = frame * _blockAlign;
      for (var channel = 0; channel < sourceChannels; channel++) {
        total += _readPcmSample(
          data,
          frameOffset + channel * (sourceBitsPerSample ~/ 8),
        );
      }
      mono[frame] = (total / sourceChannels).clamp(-1.0, 1.0).toDouble();
    }

    final output = Float32List(outputCount);
    for (var index = 0; index < outputCount; index++) {
      final globalOutput = outputStart + index;
      final intervalStart = globalOutput * ratio;
      final intervalEnd = math.min(
        sourceFrameCount.toDouble(),
        (globalOutput + 1) * ratio,
      );
      if (intervalEnd <= intervalStart) continue;

      final firstFrame = intervalStart.floor();
      final endFrame = intervalEnd.ceil();
      var weighted = 0.0;
      var covered = 0.0;
      for (var sourceFrame = firstFrame;
          sourceFrame < endFrame;
          sourceFrame++) {
        if (sourceFrame < sourceStart || sourceFrame >= sourceEnd) continue;
        final overlap = math.min(intervalEnd, sourceFrame + 1.0) -
            math.max(intervalStart, sourceFrame.toDouble());
        if (overlap <= 0) continue;
        weighted += mono[sourceFrame - sourceStart] * overlap;
        covered += overlap;
      }
      if (covered > 0) {
        output[index] = (weighted / covered).clamp(-1.0, 1.0).toDouble();
      }
    }
    return output;
  }

  double _readPcmSample(ByteData data, int offset) {
    if (sourceFormat == 3) {
      final value = data.getFloat32(offset, Endian.little);
      return value.isFinite ? value.clamp(-1.0, 1.0).toDouble() : 0;
    }

    switch (sourceBitsPerSample) {
      case 8:
        return (data.getUint8(offset) - 128) / 128.0;
      case 16:
        return data.getInt16(offset, Endian.little) / 32768.0;
      case 24:
        var value = data.getUint8(offset) |
            (data.getUint8(offset + 1) << 8) |
            (data.getUint8(offset + 2) << 16);
        if ((value & 0x800000) != 0) value |= 0xff000000;
        return value / 8388608.0;
      case 32:
        return data.getInt32(offset, Endian.little) / 2147483648.0;
      default:
        throw FormatException('Unsupported PCM bit depth: $sourceBitsPerSample.');
    }
  }

  Future<void> close() async {
    if (_closed) return;
    _closed = true;
    await _file.close();
  }

  static Future<Uint8List> _readExact(
    RandomAccessFile file,
    int count,
  ) async {
    final result = Uint8List(count);
    var offset = 0;
    while (offset < count) {
      final part = await file.read(count - offset);
      if (part.isEmpty) {
        throw const FormatException('WAV file ended unexpectedly.');
      }
      result.setRange(offset, offset + part.length, part);
      offset += part.length;
    }
    return result;
  }

  static String _fourCc(Uint8List bytes, int offset) =>
      String.fromCharCodes(bytes.skip(offset).take(4));

  static int _u16(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes).getUint16(offset, Endian.little);

  static int _u32(Uint8List bytes, int offset) =>
      ByteData.sublistView(bytes).getUint32(offset, Endian.little);
}
