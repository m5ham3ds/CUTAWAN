import 'dart:math';
import 'dart:typed_data';

import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import '../domain/transcript_contract.dart';
import 'android_audio_extractor.dart';
import 'whisper_chunk_planner.dart';
import 'whisper_pcm_reader.dart';

class WhisperTranscriptionService {
  WhisperTranscriptionService({
    AndroidAudioExtractor? audioExtractor,
    WhisperModelManager? modelManager,
  })  : _audioExtractor = audioExtractor ?? AndroidAudioExtractor(),
        _modelManager = modelManager ?? WhisperModelManager();

  final AndroidAudioExtractor _audioExtractor;
  final WhisperModelManager _modelManager;

  static const model = WhisperModelCatalog.base;
  static const _sampleRate = WhisperChunkPlanner.sampleRate;
  static const _energyWindowSamples = _sampleRate;
  static const _energyProgressWeight = 10;

  Future<CutawanTranscript> transcribeVideo({
    required String sourceUri,
    required int sourceDurationMs,
    void Function(int percent)? onProgress,
    void Function(String stage, int? percent)? onStage,
  }) async {
    if (sourceDurationMs <= 0) {
      throw const FormatException('Source video duration must be positive.');
    }

    AudioExtractionResult? extracted;
    WhisperPcmReader? pcmReader;
    WhisperEngine? engine;
    try {
      final verifiedModel = await _modelManager.findCatalogModel(model);
      if (verifiedModel == null) {
        throw StateError(
          'ثبّت نموذج Whisper Base متعدد اللغات من مركز النماذج أولاً.',
        );
      }

      onStage?.call('extracting', null);
      extracted = await _audioExtractor.extract(sourceUri);
      pcmReader = await WhisperPcmReader.open(extracted.wavFile);
      final totalSamples = pcmReader.outputSampleCount;
      if (totalSamples <= 0) {
        throw const FormatException(
          'The source video contains no decodable audio.',
        );
      }

      // Measure one-second RMS windows on the normalized 16 kHz mono timeline.
      // Read the WAV incrementally so long sources do not require a full PCM
      // copy in memory.
      onStage?.call('transcribing', 0);
      final audioEnergy = <AudioEnergyWindow>[];
      final energyChunkSamples =
          WhisperChunkPlanner.chunkSamples;
      final energyChunkCount =
          (totalSamples + energyChunkSamples - 1) ~/ energyChunkSamples;
      var energyChunkIndex = 0;
      for (var offset = 0; offset < totalSamples; offset += energyChunkSamples) {
        final count = min(energyChunkSamples, totalSamples - offset).toInt();
        final samples = await pcmReader.readSamples(offset, count);
        audioEnergy.addAll(_measureEnergy(
          samples,
          offsetSample: offset,
          durationMs: sourceDurationMs,
        ));
        energyChunkIndex++;
        onProgress?.call(
          (energyChunkIndex / energyChunkCount * _energyProgressWeight).round(),
        );
      }

      final chunks = WhisperChunkPlanner.plan(totalSamples);
      final activeEngine = await WhisperEngine.load(
        verifiedModel.path,
        config: const WhisperConfig(backend: WhisperBackend.cpu),
      );
      engine = activeEngine;

      final segments = <TranscriptSegment>[];
      String? detectedLanguage;
      var chunkIndex = 0;
      for (final chunk in chunks) {
        final chunkLength = chunk.endSample - chunk.startSample;
        final samples = await pcmReader.readSamples(
          chunk.startSample,
          chunkLength,
        );
        final offsetMs = (chunk.startSample * 1000 / _sampleRate).round();
        final task = activeEngine.transcribe(
          samples,
          options: const TranscribeOptions(
            language: 'auto',
            threads: 4,
            tokenTimestamps: true,
            splitOnWord: true,
            noContext: true,
            suppressBlank: true,
          ),
        );
        final progressSubscription = task.progress.listen((value) {
          final normalized = (_energyProgressWeight +
                  (chunkIndex + value / 100) /
                      chunks.length *
                      (100 - _energyProgressWeight))
              .clamp(0, 100)
              .round();
          onProgress?.call(normalized);
        });

        late final WhisperResult result;
        try {
          result = await task.result;
        } finally {
          await progressSubscription.cancel();
        }
        detectedLanguage ??= result.language;

        for (final segment in result.segments) {
          final localStart = segment.start.inMilliseconds;
          final localEnd = segment.end.inMilliseconds;
          if (localEnd <= localStart) continue;

          final startMs = (offsetMs + localStart)
              .clamp(0, max(0, sourceDurationMs - 1))
              .toInt();
          final endMs = (offsetMs + localEnd)
              .clamp(startMs + 1, sourceDurationMs)
              .toInt();
          if (startMs >= sourceDurationMs || endMs <= startMs) continue;

          // A two-second context overlap is split at its midpoint. Each
          // utterance midpoint belongs to exactly one chunk, avoiding the
          // previous behavior that discarded the entire first two seconds of
          // every later chunk even when the earlier chunk missed a word.
          final midpointMs = (startMs + endMs) / 2;
          if (!chunk.ownsMidpointMs(midpointMs)) continue;

          final words = _tokensToWords(segment.tokens)
              .where((word) =>
                  word.endMs > localStart && word.startMs < localEnd)
              .map((word) {
                final wordStart = (offsetMs + word.startMs)
                    .clamp(startMs, endMs - 1)
                    .toInt();
                final wordEnd = (offsetMs + word.endMs)
                    .clamp(wordStart + 1, endMs)
                    .toInt();
                return TranscriptWord(
                  text: word.text,
                  startMs: wordStart,
                  endMs: wordEnd,
                  probability: word.probability,
                );
              })
              .where((word) => word.endMs > word.startMs)
              .toList(growable: false);

          final text = segment.text.trim();
          if (text.isEmpty) continue;
          final candidate = TranscriptSegment(
            text: text,
            startMs: startMs,
            endMs: endMs,
            words: words,
          );

          final duplicateIndex = segments.indexWhere((existing) {
            final overlapStart = max(existing.startMs, candidate.startMs);
            final overlapEnd = min(existing.endMs, candidate.endMs);
            final overlapMs = max(0, overlapEnd - overlapStart);
            final shorter = min(
              existing.endMs - existing.startMs,
              candidate.endMs - candidate.startMs,
            );
            final sameText = _normalize(existing.text) == _normalize(text);
            return shorter > 0 && overlapMs / shorter >= 0.25 && sameText;
          });
          if (duplicateIndex < 0) {
            segments.add(candidate);
          } else if (candidate.words.length >
              segments[duplicateIndex].words.length) {
            segments[duplicateIndex] = candidate;
          }
        }

        chunkIndex++;
        onProgress?.call(
          (_energyProgressWeight +
                  chunkIndex / chunks.length *
                      (100 - _energyProgressWeight))
              .round(),
        );
      }

      segments.sort((a, b) => a.startMs.compareTo(b.startMs));
      final transcript = CutawanTranscript(
        schemaVersion: CutawanTranscript.currentSchemaVersion,
        language: detectedLanguage ?? 'unknown',
        text: segments.map((segment) => segment.text).join(' ').trim(),
        sourceDurationMs: sourceDurationMs,
        createdAtUtc: DateTime.now().toUtc(),
        segments: segments,
        audioEnergy: audioEnergy,
        visualSamples: extracted.visualSamples
            .where((sample) => sample.timestampMs <= sourceDurationMs)
            .toList(growable: false),
        wordTimingReliable: segments.isNotEmpty &&
            segments.every((segment) => segment.words.isNotEmpty),
        whisperModelId: model.id,
      );
      transcript.validate();
      onProgress?.call(100);
      return transcript;
    } finally {
      engine?.dispose();
      try {
        await pcmReader?.close();
      } catch (_) {
        // Continue cleanup of the temporary native WAV even if close fails.
      }
      final wav = extracted?.wavFile;
      if (wav != null && await wav.exists()) {
        await wav.delete();
      }
      _modelManager.close();
    }
  }

  static String _normalize(String value) =>
      value.toLowerCase().replaceAll(RegExp(r'\s+'), ' ').trim();

  static List<TranscriptWord> _tokensToWords(List<WhisperToken> tokens) {
    final words = <TranscriptWord>[];
    final text = StringBuffer();
    var startMs = 0;
    var endMs = 0;
    var probabilityTotal = 0.0;
    var probabilityCount = 0;

    void flush() {
      final value = text.toString().trim();
      if (value.isNotEmpty && endMs > startMs) {
        words.add(TranscriptWord(
          text: value,
          startMs: startMs,
          endMs: endMs,
          probability: probabilityCount == 0
              ? 0
              : (probabilityTotal / probabilityCount)
                  .clamp(0.0, 1.0)
                  .toDouble(),
        ));
      }
      text.clear();
      probabilityTotal = 0;
      probabilityCount = 0;
    }

    for (final token in tokens) {
      final raw = token.text;
      final piece = raw.trim();
      if (piece.isEmpty || piece.startsWith('<|')) continue;
      final beginsNewWord =
          raw.startsWith(' ') || raw.startsWith('\n') || raw.startsWith('\t');
      if (beginsNewWord && text.isNotEmpty) flush();
      if (text.isEmpty) startMs = max(0, token.start.inMilliseconds).toInt();
      text.write(piece);
      endMs = max(endMs, token.end.inMilliseconds).toInt();
      if (token.probability >= 0 && token.probability <= 1) {
        probabilityTotal += token.probability;
        probabilityCount++;
      }
    }
    flush();
    return words;
  }

  static List<AudioEnergyWindow> _measureEnergy(
    Float32List samples, {
    required int offsetSample,
    required int durationMs,
  }) {
    final windows = <AudioEnergyWindow>[];
    for (var start = 0;
        start < samples.length;
        start += _energyWindowSamples) {
      final end = min(samples.length, start + _energyWindowSamples).toInt();
      var sumSquares = 0.0;
      for (var index = start; index < end; index++) {
        final value = samples[index];
        sumSquares += value * value;
      }
      final rms = sqrt(sumSquares / (end - start))
          .clamp(0.0, 1.0)
          .toDouble();
      final globalStart = offsetSample + start;
      final globalEnd = offsetSample + end;
      final startMs = (globalStart * 1000 / _sampleRate).round();
      final endMs = min(
        durationMs,
        (globalEnd * 1000 / _sampleRate).round(),
      ).toInt();
      if (endMs > startMs) {
        windows.add(AudioEnergyWindow(
          startMs: startMs,
          endMs: endMs,
          rms: rms,
        ));
      }
    }
    return windows;
  }
}
