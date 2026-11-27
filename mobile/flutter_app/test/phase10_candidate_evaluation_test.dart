import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/tooling/phase10/candidate_evaluation.dart';

const _measuredAt = '2026-11-27T10:10:00.000Z';
const _reviewedAt = '2026-11-27T10:00:00.000Z';

Map<String, Object?> _moment(String id, int startMs, int endMs) =>
    <String, Object?>{
      'id': id,
      'startMs': startMs,
      'endMs': endMs,
      'label': 'human-approved editorial moment',
    };

Map<String, Object?> _candidate(
  String id,
  int startMs,
  int endMs, {
  double score = 80,
}) =>
    <String, Object?>{
      'id': id,
      'startMs': startMs,
      'endMs': endMs,
      'score': score,
    };

Map<String, Object?> _input({
  List<Map<String, Object?>>? moments,
  List<Map<String, Object?>>? candidates,
  List<Map<String, Object?>>? decisions,
  Map<String, Object?>? settings,
}) {
  return <String, Object?>{
    'schema': phase10CandidateEvaluationSchema,
    'schemaVersion': phase10CandidateEvaluationSchemaVersion,
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
      'id': 'interview-01',
      'sha256': 'b' * 64,
      'durationMs': 100000,
    },
    'reference': <String, Object?>{
      'reviewStatus': 'human-reviewed',
      'reviewerId': 'gold-reviewer-01',
      'reviewedAtUtc': _reviewedAt,
      'moments': moments ??
          <Map<String, Object?>>[
            _moment('gold-01', 10000, 20000),
            _moment('gold-02', 60000, 70000),
          ],
    },
    'candidateRun': <String, Object?>{
      'runId': 'run-01',
      'rankingEngine': 'deterministic-evidence-v1',
      'candidates': candidates ??
          <Map<String, Object?>>[
            _candidate('clip-01', 10000, 20000, score: 95),
            _candidate('clip-02', 60000, 70000, score: 90),
          ],
    },
    'humanReview': <String, Object?>{
      'reviewStatus': 'human-reviewed',
      'reviewerId': 'editor-01',
      'reviewedAtUtc': _reviewedAt,
      'decisions': decisions ??
          <Map<String, Object?>>[
            <String, Object?>{'candidateId': 'clip-01', 'decision': 'keep'},
            <String, Object?>{'candidateId': 'clip-02', 'decision': 'repair'},
          ],
    },
    'settings': ?settings,
  };
}

void main() {
  test('perfect one-to-one match reports precision, recall and F1 of one', () {
    final report = evaluatePhase10Candidates(_input());
    final metrics = report['metrics'] as Map;
    final matching = report['matching'] as Map;

    expect(metrics['candidatePrecision'], 1);
    expect(metrics['candidateRecall'], 1);
    expect(metrics['candidateF1'], 1);
    expect(matching['truePositiveCount'], 2);
    expect(matching['falsePositiveCount'], 0);
    expect(matching['falseNegativeCount'], 0);
    expect(matching['meanMatchedIntersectionOverUnion'], 1);
  });

  test('one-to-one matching counts false positives and missed reference moments', () {
    final report = evaluatePhase10Candidates(
      _input(
        moments: <Map<String, Object?>>[
          _moment('gold-01', 10000, 20000),
          _moment('gold-02', 60000, 70000),
          _moment('gold-03', 80000, 90000),
        ],
        candidates: <Map<String, Object?>>[
          _candidate('clip-01', 10000, 20000),
          _candidate('clip-fp', 30000, 40000),
        ],
      ),
    );
    final metrics = report['metrics'] as Map;
    final matching = report['matching'] as Map;

    expect(matching['truePositiveCount'], 1);
    expect(matching['falsePositiveCount'], 1);
    expect(matching['falseNegativeCount'], 2);
    expect(metrics['candidatePrecision'], 0.5);
    expect(metrics['candidateRecall'], 1 / 3);
  });

  test('one candidate cannot satisfy two overlapping reference labels', () {
    final report = evaluatePhase10Candidates(
      _input(
        moments: <Map<String, Object?>>[
          _moment('gold-a', 10000, 20000),
          _moment('gold-b', 15000, 25000),
        ],
        candidates: <Map<String, Object?>>[
          _candidate('broad-clip', 10000, 25000),
        ],
      ),
    );
    final matching = report['matching'] as Map;
    final metrics = report['metrics'] as Map;

    expect(matching['truePositiveCount'], 1);
    expect(matching['falseNegativeCount'], 1);
    expect(metrics['candidatePrecision'], 1);
    expect(metrics['candidateRecall'], 0.5);
  });

  test('duplicate candidates are counted once per redundant cluster member', () {
    final report = evaluatePhase10Candidates(
      _input(
        candidates: <Map<String, Object?>>[
          _candidate('clip-a', 10000, 20000),
          _candidate('clip-b', 10500, 20500),
          _candidate('clip-c', 60000, 70000),
        ],
        decisions: <Map<String, Object?>>[],
      ),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['duplicateCandidateCount'], 1);
    expect(metrics['duplicateCandidateRatio'], closeTo(1 / 3, 0.000001));
    final clusters = metrics['duplicateClusters'] as List;
    expect(clusters, hasLength(1));
    expect(
      (clusters.single as Map)['candidateIds'],
      <String>['clip-a', 'clip-b'],
    );
  });

  test('source coverage merges overlaps and reports occupied time buckets', () {
    final report = evaluatePhase10Candidates(
      _input(
        moments: <Map<String, Object?>>[],
        candidates: <Map<String, Object?>>[
          _candidate('first', 0, 15000),
          _candidate('first-overlap', 10000, 20000),
          _candidate('last', 90000, 100000),
        ],
        decisions: <Map<String, Object?>>[],
      ),
    );
    final metrics = report['metrics'] as Map;
    final coverage = report['sourceCoverage'] as Map;

    expect(metrics['sourceUnionCoverageMs'], 30000);
    expect(metrics['sourceUnionCoverageRatio'], 0.3);
    expect(metrics['coveredSourceBucketCount'], 3);
    expect(metrics['sourceCoverageBucketRatio'], 0.3);
    expect(coverage['buckets'], hasLength(10));
  });

  test('human selection reports keep, repair, reject and unreviewed separately', () {
    final report = evaluatePhase10Candidates(
      _input(
        candidates: <Map<String, Object?>>[
          _candidate('keep-me', 10000, 20000),
          _candidate('repair-me', 30000, 40000),
          _candidate('reject-me', 50000, 60000),
          _candidate('not-reviewed', 70000, 80000),
        ],
        decisions: <Map<String, Object?>>[
          <String, Object?>{'candidateId': 'keep-me', 'decision': 'keep'},
          <String, Object?>{'candidateId': 'repair-me', 'decision': 'repair'},
          <String, Object?>{'candidateId': 'reject-me', 'decision': 'reject'},
        ],
      ),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['humanReviewedCandidateCount'], 3);
    expect(metrics['unreviewedCandidateCount'], 1);
    expect(metrics['humanReviewCoverage'], 0.75);
    expect(metrics['keptAsSuggestedCount'], 1);
    expect(metrics['selectedForRepairCount'], 1);
    expect(metrics['rejectedCount'], 1);
    expect(metrics['selectedCandidateCount'], 2);
    expect(metrics['selectionRateAmongReviewed'], closeTo(2 / 3, 0.000001));
    expect(metrics['keptAsSuggestedRateAmongReviewed'], closeTo(1 / 3, 0.000001));
  });

  test('empty predictions and empty human labels remain explicit', () {
    final report = evaluatePhase10Candidates(
      _input(
        moments: <Map<String, Object?>>[],
        candidates: <Map<String, Object?>>[],
        decisions: <Map<String, Object?>>[],
      ),
    );
    final metrics = report['metrics'] as Map;

    expect(metrics['candidatePrecision'], isNull);
    expect(metrics['candidateRecall'], isNull);
    expect(metrics['candidateF1'], isNull);
    expect(metrics['duplicateCandidateRatio'], 0);
    expect(metrics['humanReviewCoverage'], 0);
    expect(metrics['selectionRateAmongReviewed'], isNull);
  });

  test('rejects unconfirmed handset, unreviewed gold labels and invalid hashes', () {
    final unconfirmed = _input();
    (unconfirmed['device'] as Map<String, Object?>)
        ['physicalDeviceConfirmationStatus'] = 'not-confirmed';
    expect(
      () => evaluatePhase10Candidates(unconfirmed),
      throwsFormatException,
    );

    final unreviewed = _input();
    (unreviewed['reference'] as Map<String, Object?>)['reviewStatus'] = 'draft';
    expect(
      () => evaluatePhase10Candidates(unreviewed),
      throwsFormatException,
    );

    final badHash = _input();
    (badHash['fixture'] as Map<String, Object?>)['sha256'] = 'not-a-hash';
    expect(
      () => evaluatePhase10Candidates(badHash),
      throwsFormatException,
    );
  });

  test('rejects duplicate IDs, invalid ranges and unknown human decisions', () {
    final duplicateIds = _input(
      candidates: <Map<String, Object?>>[
        _candidate('same', 10000, 20000),
        _candidate('same', 30000, 40000),
      ],
      decisions: <Map<String, Object?>>[],
    );
    expect(
      () => evaluatePhase10Candidates(duplicateIds),
      throwsFormatException,
    );

    final invalidRange = _input(
      candidates: <Map<String, Object?>>[
        _candidate('outside', 99000, 101000),
      ],
      decisions: <Map<String, Object?>>[],
    );
    expect(
      () => evaluatePhase10Candidates(invalidRange),
      throwsFormatException,
    );

    final unknownDecision = _input(
      decisions: <Map<String, Object?>>[
        <String, Object?>{'candidateId': 'not-in-run', 'decision': 'keep'},
      ],
    );
    expect(
      () => evaluatePhase10Candidates(unknownDecision),
      throwsFormatException,
    );
  });

  test('rejects comparison and duplicate-analysis workloads above hard limits', () {
    final manyCandidates = <Map<String, Object?>>[
      for (var index = 0; index < 501; index++)
        _candidate('clip-$index', 0, 100),
    ];
    final manyMoments = <Map<String, Object?>>[
      for (var index = 0; index < 500; index++)
        _moment('gold-$index', 0, 100),
    ];
    final oversizedMatching = _input(
      moments: manyMoments,
      candidates: manyCandidates,
      decisions: <Map<String, Object?>>[],
    );
    expect(
      () => evaluatePhase10Candidates(oversizedMatching),
      throwsFormatException,
    );

    final denseDuplicates = _input(
      moments: <Map<String, Object?>>[],
      candidates: <Map<String, Object?>>[
        for (var index = 0; index < 1420; index++)
          _candidate('dense-$index', 0, 100),
      ],
      decisions: <Map<String, Object?>>[],
    );
    expect(
      () => evaluatePhase10Candidates(denseDuplicates),
      throwsFormatException,
    );
  });
}
