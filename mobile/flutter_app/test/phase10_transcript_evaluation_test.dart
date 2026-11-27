import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/tooling/phase10/transcript_evaluation.dart';

const _reviewedAt = '2026-11-27T10:00:00.000Z';
const _measuredAt = '2026-11-27T10:10:00.000Z';

Map<String, Object?> _word(String text, int startMs, int endMs) =>
    <String, Object?>{
      'text': text,
      'startMs': startMs,
      'endMs': endMs,
    };

Map<String, Object?> _input({
  String language = 'en',
  List<Map<String, Object?>>? referenceWords,
  List<Map<String, Object?>>? hypothesisWords,
}) {
  return <String, Object?>{
    'schema': phase10TranscriptionEvaluationSchema,
    'schemaVersion': phase10TranscriptionEvaluationSchemaVersion,
    'measuredAtUtc': _measuredAt,
    'application': <String, Object?>{'buildSha': 'a' * 40},
    'device': <String, Object?>{
      'manufacturer': 'HONOR',
      'model': 'X9c',
      'androidRelease': '16',
      'androidSdk': 36,
      'physicalDeviceConfirmationStatus': 'confirmed',
    },
    'fixture': <String, Object?>{
      'id': 'speech-sample-01',
      'sha256': 'b' * 64,
      'language': language,
      'durationMs': 10000,
    },
    'reference': <String, Object?>{
      'reviewStatus': 'human-reviewed',
      'reviewerId': 'reviewer-01',
      'reviewedAtUtc': _reviewedAt,
      'words': referenceWords ??
          <Map<String, Object?>>[
            _word('hello', 100, 400),
            _word('world', 450, 800),
          ],
    },
    'hypothesis': <String, Object?>{
      'engine': 'whisper.cpp',
      'model': 'base',
      'language': language,
      'words': hypothesisWords ??
          <Map<String, Object?>>[
            _word('Hello,', 100, 400),
            _word('world!', 450, 800),
          ],
    },
  };
}

void main() {
  test('exact English transcript reports zero WER and zero timing error', () {
    final report = evaluatePhase10Transcription(_input());
    final metrics = report['metrics'] as Map;

    expect(metrics['wordErrorRate'], 0);
    expect(metrics['wordErrorRatePercent'], 0);
    expect(metrics['substitutions'], 0);
    expect(metrics['deletions'], 0);
    expect(metrics['insertions'], 0);
    expect(metrics['exactMatchedWordCount'], 2);
    expect(metrics['matchedWordCoverage'], 1);
    expect(metrics['medianAbsoluteStartErrorMs'], 0);
    expect(metrics['p95AbsoluteEndErrorMs'], 0);
  });

  test('WER separates substitutions, deletions and insertion counts', () {
    final report = evaluatePhase10Transcription(
      _input(
        referenceWords: <Map<String, Object?>>[
          _word('hello', 100, 400),
          _word('world', 450, 800),
          _word('from', 850, 1000),
          _word('cutawan', 1050, 1500),
        ],
        hypothesisWords: <Map<String, Object?>>[
          _word('hello', 120, 420),
          _word('word', 470, 820),
          _word('cutawan', 1070, 1520),
        ],
      ),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['substitutions'], 1);
    expect(metrics['deletions'], 1);
    expect(metrics['insertions'], 0);
    expect(metrics['editCount'], 2);
    expect(metrics['wordErrorRate'], 0.5);
    expect(metrics['exactMatchedWordCount'], 2);
    expect(metrics['matchedWordCoverage'], 0.5);
    expect(metrics['medianAbsoluteStartErrorMs'], 20);
    expect(metrics['p95AbsoluteEndErrorMs'], 20);
  });

  test('Arabic harakat, alef forms, alef maqsura and punctuation normalize', () {
    final report = evaluatePhase10Transcription(
      _input(
        language: 'ar',
        referenceWords: <Map<String, Object?>>[
          _word('أَحْمَدُ،', 100, 500),
          _word('هُدَى؟', 600, 900),
        ],
        hypothesisWords: <Map<String, Object?>>[
          _word('احمد', 100, 500),
          _word('هدي', 600, 900),
        ],
      ),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['wordErrorRate'], 0);
    expect(metrics['exactMatchedWordCount'], 2);
    expect(metrics['medianAbsoluteStartErrorMs'], 0);
  });

  test('P95 uses the nearest-rank percentile for absolute timing errors', () {
    final offsets = <int>[1, 2, 3, 4, 100];
    final words = <Map<String, Object?>>[
      for (var i = 0; i < offsets.length; i++)
        _word('w$i', i * 500, i * 500 + 200),
    ];
    final shifted = <Map<String, Object?>>[
      for (var i = 0; i < offsets.length; i++)
        _word('w$i', i * 500 + offsets[i], i * 500 + 200 + offsets[i]),
    ];
    final report = evaluatePhase10Transcription(
      _input(referenceWords: words, hypothesisWords: shifted),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['medianAbsoluteStartErrorMs'], 3);
    expect(metrics['p95AbsoluteStartErrorMs'], 100);
    expect(metrics['medianAbsoluteEndErrorMs'], 3);
    expect(metrics['p95AbsoluteEndErrorMs'], 100);
  });

  test('extra hypothesis words are counted as insertions', () {
    final report = evaluatePhase10Transcription(
      _input(
        referenceWords: <Map<String, Object?>>[
          _word('hello', 100, 400),
          _word('world', 450, 800),
        ],
        hypothesisWords: <Map<String, Object?>>[
          _word('hello', 100, 400),
          _word('extra', 420, 440),
          _word('world', 450, 800),
        ],
      ),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['substitutions'], 0);
    expect(metrics['deletions'], 0);
    expect(metrics['insertions'], 1);
    expect(metrics['wordErrorRate'], 0.5);
    expect(metrics['exactMatchedWordCount'], 2);
  });

  test('missing hypothesis words are counted as deletions with null timing', () {
    final report = evaluatePhase10Transcription(
      _input(
        hypothesisWords: <Map<String, Object?>>[],
      ),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['deletions'], 2);
    expect(metrics['wordErrorRate'], 1);
    expect(metrics['matchedWordCoverage'], 0);
    expect(metrics['medianAbsoluteStartErrorMs'], isNull);
    expect(metrics['p95AbsoluteEndErrorMs'], isNull);
  });

  test('rejects an unconfirmed device, unreviewed reference and invalid hashes',
      () {
    final unconfirmed = _input();
    (unconfirmed['device'] as Map<String, Object?>)
        ['physicalDeviceConfirmationStatus'] = 'not-confirmed';
    expect(
      () => evaluatePhase10Transcription(unconfirmed),
      throwsFormatException,
    );

    final unreviewed = _input();
    (unreviewed['reference'] as Map<String, Object?>)['reviewStatus'] =
        'machine-generated';
    expect(
      () => evaluatePhase10Transcription(unreviewed),
      throwsFormatException,
    );

    final badHash = _input();
    (badHash['fixture'] as Map<String, Object?>)['sha256'] = 'not-a-hash';
    expect(
      () => evaluatePhase10Transcription(badHash),
      throwsFormatException,
    );
  });

  test('rejects unordered or out-of-duration word timings', () {
    final unordered = _input(
      referenceWords: <Map<String, Object?>>[
        _word('first', 500, 700),
        _word('second', 100, 300),
      ],
    );
    expect(
      () => evaluatePhase10Transcription(unordered),
      throwsFormatException,
    );

    final beyondDuration = _input(
      referenceWords: <Map<String, Object?>>[
        _word('late', 9900, 10100),
      ],
    );
    expect(
      () => evaluatePhase10Transcription(beyondDuration),
      throwsFormatException,
    );
  });

  test('rejects oversized alignments rather than risking unbounded memory', () {
    final words = <Map<String, Object?>>[
      for (var i = 0; i < 3000; i++) _word('w$i', i, i + 1),
    ];
    final oversized = _input(
      referenceWords: words,
      hypothesisWords: words,
    );

    expect(
      () => evaluatePhase10Transcription(oversized),
      throwsFormatException,
    );
  });
}
