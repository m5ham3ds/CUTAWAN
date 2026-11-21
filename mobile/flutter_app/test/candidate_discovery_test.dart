import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_preferences.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/services/candidate_discovery_service.dart';
import 'package:flutter_test/flutter_test.dart';

CutawanTranscript makeTranscript({
  int durationMs = 65000,
  bool reliable = true,
  int sentenceCount = 13,
}) {
  final words = <TranscriptWord>[];
  for (var sentence = 0; sentence < sentenceCount; sentence++) {
    final sentenceStart = sentence * 5000;
    final parts = [
      'topic$sentence',
      'clear',
      'context',
      'useful',
      'moment$sentence.',
    ];
    for (var word = 0; word < parts.length; word++) {
      final start = sentenceStart + word * 800;
      words.add(TranscriptWord(
        text: parts[word],
        startMs: start,
        endMs: start + 650,
        probability: 0.9,
      ));
    }
  }
  final end = words.last.endMs;
  return CutawanTranscript(
    schemaVersion: CutawanTranscript.currentSchemaVersion,
    language: 'en',
    text: words.map((word) => word.text).join(' '),
    sourceDurationMs: durationMs,
    createdAtUtc: DateTime.utc(2026, 11, 20),
    segments: [
      TranscriptSegment(
        text: words.map((word) => word.text).join(' '),
        startMs: 0,
        endMs: end,
        words: words,
      ),
    ],
    audioEnergy: List.generate(
      (durationMs / 1000).ceil(),
      (index) => AudioEnergyWindow(
        startMs: index * 1000,
        endMs: (index + 1) * 1000 > durationMs
            ? durationMs
            : (index + 1) * 1000,
        rms: 0.2 + (index % 3) * 0.1,
      ),
    ),
    visualSamples: List.generate(
      sentenceCount,
      (index) => VisualSceneSample(
        timestampMs: index * 5000,
        changeScore: index % 2 == 0 ? 0.3 : 0.6,
      ),
    ),
    wordTimingReliable: reliable,
    whisperModelId: 'base',
  );
}

void main() {
  const preferences = ClipPreferences(
    requestedClipCount: 4,
    durationMode: ClipDurationMode.seconds15To30,
  );

  test('discovery respects duration, source bounds, and unique candidates', () {
    final result = const CandidateDiscoveryService().discover(
      makeTranscript(),
      preferences,
      now: DateTime.utc(2026, 11, 20),
    );

    expect(result.transcriptEvidence, isTrue);
    expect(result.audioEvidence, isTrue);
    expect(result.visualEvidence, isTrue);
    expect(result.rankingEngine, 'deterministic-evidence-v1');
    expect(result.candidates, isNotEmpty);
    expect(result.candidates.length, lessThanOrEqualTo(4));
    expect(
      result.candidates.every(
        (candidate) =>
            candidate.durationMs >= 15000 &&
            candidate.durationMs <= 30000 &&
            candidate.startMs >= 0 &&
            candidate.endMs <= 65000 &&
            candidate.score >= 0 &&
            candidate.score <= 100,
      ),
      isTrue,
    );
    expect(
      result.candidates.map((candidate) => candidate.id).toSet().length,
      result.candidates.length,
    );
    expect(
      result.candidates.map((candidate) => candidate.startMs).toList(),
      orderedEquals(
        [...result.candidates.map((candidate) => candidate.startMs)]..sort(),
      ),
    );
  });

  test('discovery does not invent clips to meet requested count', () {
    final short = makeTranscript(durationMs: 10000, sentenceCount: 2);
    final result = const CandidateDiscoveryService().discover(
      short,
      preferences,
    );

    expect(result.candidates, isEmpty);
  });

  test('discovery refuses transcripts without reliable word timing', () {
    expect(
      () => const CandidateDiscoveryService().discover(
        makeTranscript(reliable: false),
        preferences,
      ),
      throwsA(isA<FormatException>()),
    );
  });

  test('unpunctuated long transcripts are split at timed word boundaries', () {
    const durationMs = 60000;
    final words = List.generate(
      65,
      (index) => TranscriptWord(
        text: 'word$index',
        startMs: index * 900,
        endMs: index * 900 + 500,
        probability: 0.94,
      ),
    );
    final text = words.map((word) => word.text).join(' ');
    final transcript = CutawanTranscript(
      schemaVersion: CutawanTranscript.currentSchemaVersion,
      language: 'en',
      text: text,
      sourceDurationMs: durationMs,
      createdAtUtc: DateTime.utc(2026, 11, 21),
      segments: [
        TranscriptSegment(
          text: text,
          startMs: 0,
          endMs: words.last.endMs,
          words: words,
        ),
      ],
      audioEnergy: List.generate(
        60,
        (index) => AudioEnergyWindow(
          startMs: index * 1000,
          endMs: (index + 1) * 1000,
          rms: 0.35,
        ),
      ),
      visualSamples: List.generate(
        12,
        (index) => VisualSceneSample(
          timestampMs: index * 5000,
          changeScore: 0.25 + (index % 3) * 0.1,
        ),
      ),
      wordTimingReliable: true,
      whisperModelId: 'base',
    );

    final result = const CandidateDiscoveryService().discover(
      transcript,
      preferences,
      now: DateTime.utc(2026, 11, 21),
    );

    expect(result.candidates, isNotEmpty);
    expect(result.candidates.length, greaterThanOrEqualTo(2));
    expect(
      result.candidates.every((candidate) =>
          candidate.durationMs >= 15000 &&
          candidate.durationMs <= 30000),
      isTrue,
    );
    expect(
      result.candidates.any((candidate) => candidate.explanations.any(
            (item) => item.contains('حدود احتياطية عند الكلمات'),
          )),
      isTrue,
    );
  });

  test('candidate set rejects non-finite deterministic scores and evidence', () {
    final result = const CandidateDiscoveryService().discover(
      makeTranscript(),
      preferences,
    );
    final invalidScore = result.toJson();
    final scoreItems = invalidScore['candidates'] as List<dynamic>;
    final firstScore = Map<String, dynamic>.from(scoreItems.first as Map)
      ..['score'] = double.nan;
    invalidScore['candidates'] = [firstScore];
    expect(
      () => CandidateSet.fromJson(Map<String, dynamic>.from(invalidScore)),
      throwsA(isA<FormatException>()),
    );

    final invalidEnergy = result.toJson();
    final energyItems = invalidEnergy['candidates'] as List<dynamic>;
    final firstEnergy = Map<String, dynamic>.from(energyItems.first as Map)
      ..['averageAudioEnergy'] = double.infinity;
    invalidEnergy['candidates'] = [firstEnergy];
    expect(
      () => CandidateSet.fromJson(Map<String, dynamic>.from(invalidEnergy)),
      throwsA(isA<FormatException>()),
    );
  });

  test('candidate set JSON validates source bounds and scores', () {
    final result = const CandidateDiscoveryService().discover(
      makeTranscript(),
      preferences,
    );
    final json = result.toJson();
    final items = json['candidates'] as List<dynamic>;
    final first = Map<String, dynamic>.from(items.first as Map<String, dynamic>)
      ..['endMs'] = 90000;
    json['candidates'] = [first];

    expect(
      () => CandidateSet.fromJson(Map<String, dynamic>.from(json)),
      throwsA(isA<FormatException>()),
    );
  });
}
