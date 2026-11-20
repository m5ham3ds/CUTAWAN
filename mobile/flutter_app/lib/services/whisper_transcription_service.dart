import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:whisper_cpp_flutter_plus/whisper_cpp_flutter_plus.dart';

import '../domain/transcript_contract.dart';
import 'android_audio_extractor.dart';

class WhisperTranscriptionService {
  WhisperTranscriptionService({
    AndroidAudioExtractor? audioExtractor,
    WhisperModelManager? modelManager,
  })  : _audioExtractor = audioExtractor ?? AndroidAudioExtractor(),
        _modelManager = modelManager ?? WhisperModelManager();

  final AndroidAudioExtractor _audioExtractor;
  final WhisperModelManager _modelManager;

  static const model = WhisperModelCatalog.base;
  static const _sampleRate = 16000;
  static const _chunkSeconds = 30;
  static const _overlapSeconds = 2;

  Future<CutawanTranscript> transcribeVideo({
    required String sourceUri,
    required int sourceDurationMs,
    void Function(int percent)? onProgress,
    void Function(String stage, int? percent)? onStage,
  }) async {
    AudioExtractionResult? extracted;
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
      onStage?.call('transcribing', 0);
      final pcm = await WhisperAudio.readWav(extracted.wavFile);
      if (pcm.isEmpty) {
        throw const FormatException(
          'The source video contains no decodable audio.',
        );
      }

      final audioEnergy = _measureEnergy(pcm, sourceDurationMs);
      final activeEngine = await WhisperEngine.load(
        verifiedModel.path,
        config: const WhisperConfig(backend: WhisperBackend.cpu),
      );
      engine = activeEngine;

      final chunkSamples = _chunkSeconds * _sampleRate;
      final overlapSamples = _overlapSeconds * _sampleRate;
      final stepSamples = chunkSamples - overlapSamples;
      final segments = <TranscriptSegment>[];
      String? detectedLanguage;
      final totalChunks = max(
        1,
        (pcm.length <= chunkSamples)
            ? 1
            : ((pcm.length - overlapSamples + stepSamples - 1) ~/ stepSamples),
      );

      var chunkIndex = 0;
      for (var offset = 0; offset < pcm.length; offset += stepSamples) {
        final end = min(pcm.length, offset + chunkSamples).toInt();
        final samples = Float32List.fromList(pcm.sublist(offset, end));
        final offsetMs = (offset * 1000 / _sampleRate).round();
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
          final normalized = ((chunkIndex + value / 100) / totalChunks * 100)
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
          var endMs = (offsetMs + localEnd)
              .clamp(startMs + 1, sourceDurationMs)
              .toInt();
          if (startMs >= sourceDurationMs || endMs <= startMs) continue;

          // Each subsequent chunk repeats the previous two seconds. Keep the
          // previous chunk's overlap and discard duplicated early segments.
          if (offset > 0) {
            final midpoint = (startMs + endMs) / 2;
            if (midpoint < offsetMs + _overlapSeconds * 1000) continue;
          }

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
          if (text.isEmpty || endMs <= startMs) continue;
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
            return shorter > 0 &&
                overlapMs / shorter >= 0.25 &&
                sameText;
          });
          if (duplicateIndex < 0) {
            segments.add(candidate);
          } else if (candidate.words.length >
              segments[duplicateIndex].words.length) {
            segments[duplicateIndex] = candidate;
          }
        }
        chunkIndex++;
        onProgress?.call((chunkIndex / totalChunks * 100).round());
        if (end >= pcm.length) break;
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
      return transcript;
    } finally {
      engine?.dispose();
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
    Float32List samples,
    int durationMs,
  ) {
    const windowSamples = _sampleRate;
    final windows = <AudioEnergyWindow>[];
    for (var start = 0; start < samples.length; start += windowSamples) {
      final end = min(samples.length, start + windowSamples).toInt();
      var sumSquares = 0.0;
      for (var index = start; index < end; index++) {
        final value = samples[index];
        sumSquares += value * value;
      }
      final rms = sqrt(sumSquares / (end - start))
          .clamp(0.0, 1.0)
          .toDouble();
      final startMs = (start * 1000 / _sampleRate).round();
      final endMs = min(durationMs, (end * 1000 / _sampleRate).round()).toInt();
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
