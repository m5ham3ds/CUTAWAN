import 'dart:math';

import '../domain/clip_candidate.dart';
import '../domain/clip_preferences.dart';
import '../domain/transcript_contract.dart';

class _Sentence {
  const _Sentence(this.words);

  final List<TranscriptWord> words;

  int get startMs => words.first.startMs;
  int get endMs => words.last.endMs;
  int get durationMs => endMs - startMs;
  String get text => words.map((word) => word.text).join(' ').trim();
}

class CandidateDiscoveryService {
  const CandidateDiscoveryService();

  CandidateSet discover(
    CutawanTranscript transcript,
    ClipPreferences preferences, {
    DateTime? now,
  }) {
    transcript.validate();
    final preferenceError = preferences.validate();
    if (preferenceError != null) throw FormatException(preferenceError);
    if (!transcript.wordTimingReliable || transcript.words.isEmpty) {
      throw const FormatException(
        'Reliable word-level timestamps are required before clip discovery.',
      );
    }

    final (minimumSeconds, maximumSeconds) = _durationRange(preferences);
    final minimumMs = minimumSeconds * 1000;
    final maximumMs = maximumSeconds * 1000;
    final targetMs = ((minimumMs + maximumMs) / 2).round();
    final sentences = _sentences(transcript.words);
    final proposals = <ClipCandidate>[];

    for (var startIndex = 0; startIndex < sentences.length; startIndex++) {
      var combinedWords = <TranscriptWord>[];
      for (var endIndex = startIndex; endIndex < sentences.length; endIndex++) {
        final sentence = sentences[endIndex];
        combinedWords = [...combinedWords, ...sentence.words];
        final startMs = sentences[startIndex].startMs;
        final endMs = sentence.endMs;
        final durationMs = endMs - startMs;
        if (endMs > transcript.sourceDurationMs) continue;
        if (durationMs > maximumMs) break;
        if (durationMs < minimumMs) continue;

        final text = combinedWords.map((word) => word.text).join(' ').trim();
        if (text.isEmpty) continue;
        final audio = _audioEvidence(
          transcript.audioEnergy,
          startMs,
          endMs,
        );
        final visual = _visualEvidence(
          transcript.visualSamples,
          startMs,
          endMs,
        );
        final density = (combinedWords.length /
                max(1.0, durationMs / 1000.0 * 2.6))
            .clamp(0.0, 1.0)
            .toDouble();
        var weighted = density * 0.50;
        var totalWeight = 0.50;
        if (audio != null) {
          weighted += audio * 0.30;
          totalWeight += 0.30;
        }
        if (visual != null) {
          weighted += visual * 0.20;
          totalWeight += 0.20;
        }
        final score = (weighted / totalWeight * 100)
            .clamp(0.0, 100.0)
            .toDouble();
        final explanations = <String>[
          'كثافة الكلام: ${(density * 100).round()}%',
          if (audio != null)
            'طاقة الصوت المتوسطة: ${(audio * 100).round()}%',
          if (visual != null)
            'أعلى تغير بصري مرصود: ${(visual * 100).round()}%',
          'الحدود مأخوذة من بدايات/نهايات الجمل المكتشفة بالتفريغ',
        ];
        final firstSentence = sentences[startIndex].text;
        final title = _truncate(firstSentence, 72);
        proposals.add(ClipCandidate(
          id: 'clip_${startMs}_$endMs',
          startMs: startMs,
          endMs: endMs,
          score: score,
          title: title,
          hook: title,
          summary: _truncate(text, 220),
          explanations: explanations,
          transcriptText: text,
          averageAudioEnergy: audio ?? 0,
          peakVisualChange: visual ?? 0,
        ));
      }
    }

    final selected = _selectDiverse(
      proposals,
      requestedCount: preferences.requestedClipCount,
      sourceDurationMs: transcript.sourceDurationMs,
      targetDurationMs: targetMs,
    );
    final result = CandidateSet(
      schemaVersion: CandidateSet.currentSchemaVersion,
      sourceDurationMs: transcript.sourceDurationMs,
      createdAtUtc: (now ?? DateTime.now()).toUtc(),
      candidates: selected,
      transcriptEvidence: true,
      audioEvidence: transcript.audioEnergy.isNotEmpty,
      visualEvidence: transcript.visualSamples.isNotEmpty,
      rankingEngine: 'deterministic-evidence-v1',
    );
    result.validate();
    return result;
  }

  static (int, int) _durationRange(ClipPreferences preferences) {
    switch (preferences.durationMode) {
      case ClipDurationMode.automatic:
        return (15, 90);
      case ClipDurationMode.seconds15To30:
        return (15, 30);
      case ClipDurationMode.seconds30To45:
        return (30, 45);
      case ClipDurationMode.seconds30To60:
        return (30, 60);
      case ClipDurationMode.seconds60To90:
        return (60, 90);
      case ClipDurationMode.custom:
        return (
          preferences.customMinimumSeconds,
          preferences.customMaximumSeconds,
        );
    }
  }

  static List<_Sentence> _sentences(List<TranscriptWord> words) {
    final sorted = [...words]..sort((a, b) => a.startMs.compareTo(b.startMs));
    final result = <_Sentence>[];
    var current = <TranscriptWord>[];
    for (var index = 0; index < sorted.length; index++) {
      final word = sorted[index];
      current.add(word);
      final next = index + 1 < sorted.length ? sorted[index + 1] : null;
      final gap = next == null ? 0 : next.startMs - word.endMs;
      if (_endsSentence(word.text) || next == null || gap > 1800) {
        if (current.isNotEmpty) {
          result.add(_Sentence(List.unmodifiable(current)));
        }
        current = <TranscriptWord>[];
      }
    }
    return result;
  }

  static bool _endsSentence(String word) {
    final value = word.trim();
    return RegExp(r'[.!?؟。！？…]["”’)\]]*$').hasMatch(value);
  }

  static double? _audioEvidence(
    List<AudioEnergyWindow> windows,
    int startMs,
    int endMs,
  ) {
    final values = windows.where(
      (window) => window.startMs < endMs && window.endMs > startMs,
    );
    if (values.isEmpty) return null;
    final items = values.toList(growable: false);
    return items.map((item) => item.rms).reduce((a, b) => a + b) / items.length;
  }

  static double? _visualEvidence(
    List<VisualSceneSample> samples,
    int startMs,
    int endMs,
  ) {
    final values = samples.where(
      (sample) => sample.timestampMs >= startMs &&
          sample.timestampMs <= endMs,
    );
    if (values.isEmpty) return null;
    return values
        .map((sample) => sample.changeScore)
        .reduce((a, b) => a > b ? a : b);
  }

  static List<ClipCandidate> _selectDiverse(
    List<ClipCandidate> proposals, {
    required int requestedCount,
    required int sourceDurationMs,
    required int targetDurationMs,
  }) {
    final remaining = [...proposals];
    final selected = <ClipCandidate>[];
    while (remaining.isNotEmpty && selected.length < requestedCount) {
      remaining.sort((a, b) {
        final aCoverage = _coverageBonus(a, selected, sourceDurationMs);
        final bCoverage = _coverageBonus(b, selected, sourceDurationMs);
        final byScore = (b.score + bCoverage).compareTo(a.score + aCoverage);
        if (byScore != 0) return byScore;
        final aDistance = (a.durationMs - targetDurationMs).abs();
        final bDistance = (b.durationMs - targetDurationMs).abs();
        return aDistance.compareTo(bDistance);
      });
      final best = remaining.removeAt(0);
      final duplicate = selected.any((existing) {
        final overlapStart = max(best.startMs, existing.startMs);
        final overlapEnd = min(best.endMs, existing.endMs);
        final overlap = max(0, overlapEnd - overlapStart);
        final overlapRatio =
            overlap / min(best.durationMs, existing.durationMs);
        final left = best.transcriptText
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toSet();
        final right = existing.transcriptText
            .toLowerCase()
            .split(RegExp(r'\s+'))
            .where((word) => word.isNotEmpty)
            .toSet();
        final union = left.union(right);
        final similarity = union.isEmpty
            ? 0.0
            : left.intersection(right).length / union.length;
        return overlapRatio >= 0.65 || similarity >= 0.72;
      });
      if (!duplicate) selected.add(best);
    }
    selected.sort((a, b) => a.startMs.compareTo(b.startMs));
    return selected;
  }

  static double _coverageBonus(
    ClipCandidate candidate,
    List<ClipCandidate> selected,
    int sourceDurationMs,
  ) {
    if (selected.isEmpty) return 0;
    final midpoint = (candidate.startMs + candidate.endMs) / 2;
    final nearest = selected.map((item) {
      final other = (item.startMs + item.endMs) / 2;
      return (midpoint - other).abs();
    }).reduce((a, b) => a < b ? a : b);
    return (nearest / max(1, sourceDurationMs) * 18)
        .clamp(0.0, 18.0)
        .toDouble();
  }

  static String _truncate(String text, int limit) =>
      text.length <= limit ? text : '${text.substring(0, limit - 1)}…';
}
