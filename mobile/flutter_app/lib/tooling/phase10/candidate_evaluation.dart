import 'dart:math' as math;

const String phase10CandidateEvaluationSchema =
    'org.cutawan.phase10.candidate-evaluation';
const int phase10CandidateEvaluationSchemaVersion = 1;
const int _maximumCandidateReferenceComparisons = 250000;
const int _maximumDuplicatePairComparisons = 1000000;
const int _maximumCandidates = 2000;
const int _maximumReferenceMoments = 1000;

class _Interval {
  const _Interval({
    required this.id,
    required this.startMs,
    required this.endMs,
  });

  final String id;
  final int startMs;
  final int endMs;

  int get durationMs => endMs - startMs;
}

class _Candidate extends _Interval {
  const _Candidate({
    required super.id,
    required super.startMs,
    required super.endMs,
    required this.score,
  });

  final double score;
}

class _MatchEdge {
  const _MatchEdge({
    required this.referenceIndex,
    required this.candidateIndex,
    required this.intersectionOverUnion,
    required this.candidateScore,
    required this.referenceId,
    required this.candidateId,
  });

  final int referenceIndex;
  final int candidateIndex;
  final double intersectionOverUnion;
  final double candidateScore;
  final String referenceId;
  final String candidateId;
}

/// Calculates deterministic candidate-quality measurements for a reviewed
/// reference set and one physical-device candidate-discovery run.
///
/// This function reports measurements only. It does not decide whether a
/// model, candidate set, or development phase has passed acceptance.
Map<String, Object?> evaluatePhase10Candidates(Map<String, Object?> input) {
  _expect(
    input['schema'] == phase10CandidateEvaluationSchema,
    'schema must be $phase10CandidateEvaluationSchema',
  );
  _expect(
    input['schemaVersion'] == phase10CandidateEvaluationSchemaVersion,
    'unsupported schemaVersion',
  );
  final measuredAtUtc = _requiredUtc(input['measuredAtUtc'], 'measuredAtUtc');

  final application = _asMap(input['application'], 'application');
  final buildSha =
      _requiredString(application['buildSha'], 'application.buildSha');
  _expect(
    RegExp(r'^[a-fA-F0-9]{40}$').hasMatch(buildSha),
    'application.buildSha must be a 40-character Git SHA',
  );

  final device = _asMap(input['device'], 'device');
  final manufacturer =
      _requiredString(device['manufacturer'], 'device.manufacturer');
  final model = _requiredString(device['model'], 'device.model');
  final androidRelease =
      _requiredString(device['androidRelease'], 'device.androidRelease');
  final androidSdk = _requiredInt(device['androidSdk'], 'device.androidSdk');
  _expect(androidSdk >= 26, 'device.androidSdk must be 26 or newer');
  _expect(
    device['physicalDeviceConfirmationStatus'] == 'confirmed',
    'physical device must be manually confirmed before field scoring',
  );

  final fixture = _asMap(input['fixture'], 'fixture');
  final fixtureId = _requiredId(fixture['id'], 'fixture.id');
  final fixtureSha = _requiredString(fixture['sha256'], 'fixture.sha256');
  _expect(
    RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fixtureSha),
    'fixture.sha256 must be a 64-character SHA-256',
  );
  final durationMs = _requiredInt(fixture['durationMs'], 'fixture.durationMs');
  _expect(durationMs > 0, 'fixture.durationMs must be positive');

  final reference = _asMap(input['reference'], 'reference');
  _expect(
    reference['reviewStatus'] == 'human-reviewed',
    'reference.reviewStatus must be human-reviewed',
  );
  final referenceReviewerId =
      _requiredId(reference['reviewerId'], 'reference.reviewerId');
  final referenceReviewedAtUtc =
      _requiredUtc(reference['reviewedAtUtc'], 'reference.reviewedAtUtc');
  final referenceMoments = _parseIntervals(
    reference['moments'],
    'reference.moments',
    durationMs,
    maximumItems: _maximumReferenceMoments,
  );
  final referenceIds = referenceMoments.map((moment) => moment.id).toSet();
  _expect(
    referenceIds.length == referenceMoments.length,
    'reference moment IDs must be unique',
  );

  final candidateRun = _asMap(input['candidateRun'], 'candidateRun');
  final runId = _requiredId(candidateRun['runId'], 'candidateRun.runId');
  final rankingEngine =
      _requiredString(candidateRun['rankingEngine'], 'candidateRun.rankingEngine');
  final candidates = _parseCandidates(
    candidateRun['candidates'],
    durationMs,
  );
  final candidateIndexes = <String, int>{
    for (var index = 0; index < candidates.length; index++)
      candidates[index].id: index,
  };

  final humanReview = _asMap(input['humanReview'], 'humanReview');
  _expect(
    humanReview['reviewStatus'] == 'human-reviewed',
    'humanReview.reviewStatus must be human-reviewed',
  );
  final humanReviewerId =
      _requiredId(humanReview['reviewerId'], 'humanReview.reviewerId');
  final humanReviewedAtUtc =
      _requiredUtc(humanReview['reviewedAtUtc'], 'humanReview.reviewedAtUtc');
  final decisions = _parseDecisions(
    humanReview['decisions'],
    candidateIndexes,
  );

  final settings = _asMapOrEmpty(input['settings'], 'settings');
  final matchThreshold = _optionalRatio(
    settings['matchIouThreshold'],
    0.5,
    'settings.matchIouThreshold',
    allowZero: false,
  );
  final duplicateThreshold = _optionalRatio(
    settings['duplicateOverlapThreshold'],
    0.85,
    'settings.duplicateOverlapThreshold',
    allowZero: false,
  );
  final bucketCount = _optionalInt(
    settings['sourceCoverageBucketCount'],
    10,
    'settings.sourceCoverageBucketCount',
  );
  _expect(
    bucketCount >= 1 && bucketCount <= 100,
    'settings.sourceCoverageBucketCount must be between 1 and 100',
  );

  final pairCount = referenceMoments.length * candidates.length;
  _expect(
    pairCount <= _maximumCandidateReferenceComparisons,
    'candidate/reference comparison limit exceeded; evaluate a smaller fixture batch',
  );
  final matches = _matchCandidates(
    referenceMoments,
    candidates,
    matchThreshold,
  );
  final duplicateSummary = _measureDuplicates(
    candidates,
    duplicateThreshold,
  );
  final sourceCoverage = _measureSourceCoverage(
    candidates,
    durationMs,
    bucketCount,
  );
  final reviewSummary = _summarizeHumanReview(
    candidates.length,
    decisions,
  );

  final truePositives = matches.length;
  final falsePositives = candidates.length - truePositives;
  final falseNegatives = referenceMoments.length - truePositives;
  final precision =
      candidates.isEmpty ? null : truePositives / candidates.length;
  final recall = referenceMoments.isEmpty
      ? null
      : truePositives / referenceMoments.length;
  final f1 = precision == null || recall == null
      ? null
      : (precision + recall == 0)
          ? 0.0
          : 2 * precision * recall / (precision + recall);
  final meanIou = matches.isEmpty
      ? null
      : matches
              .map((match) => match.intersectionOverUnion)
              .reduce((left, right) => left + right) /
          matches.length;

  return <String, Object?>{
    'schema': phase10CandidateEvaluationSchema,
    'schemaVersion': phase10CandidateEvaluationSchemaVersion,
    'evaluatedAtUtc': DateTime.now().toUtc().toIso8601String(),
    'measuredAtUtc': measuredAtUtc.toIso8601String(),
    'application': <String, Object?>{'buildSha': buildSha.toLowerCase()},
    'device': <String, Object?>{
      'manufacturer': manufacturer,
      'model': model,
      'androidRelease': androidRelease,
      'androidSdk': androidSdk,
      'physicalDeviceConfirmationStatus': 'confirmed',
    },
    'fixture': <String, Object?>{
      'id': fixtureId,
      'sha256': fixtureSha.toLowerCase(),
      'durationMs': durationMs,
    },
    'reference': <String, Object?>{
      'reviewStatus': 'human-reviewed',
      'reviewerId': referenceReviewerId,
      'reviewedAtUtc': referenceReviewedAtUtc.toIso8601String(),
      'momentCount': referenceMoments.length,
    },
    'candidateRun': <String, Object?>{
      'runId': runId,
      'rankingEngine': rankingEngine,
      'candidateCount': candidates.length,
    },
    'humanReview': <String, Object?>{
      'reviewStatus': 'human-reviewed',
      'reviewerId': humanReviewerId,
      'reviewedAtUtc': humanReviewedAtUtc.toIso8601String(),
    },
    'matching': <String, Object?>{
      'strategy': 'greedy-one-to-one-iou-v1',
      'iouThreshold': matchThreshold,
      'truePositiveCount': truePositives,
      'falsePositiveCount': falsePositives,
      'falseNegativeCount': falseNegatives,
      'meanMatchedIntersectionOverUnion': meanIou,
      'pairs': matches
          .map((match) => <String, Object?>{
                'referenceMomentId': match.referenceId,
                'candidateId': match.candidateId,
                'intersectionOverUnion': match.intersectionOverUnion,
              })
          .toList(growable: false),
    },
    'metrics': <String, Object?>{
      'candidatePrecision': precision,
      'candidateRecall': recall,
      'candidateF1': f1,
      'candidateCount': candidates.length,
      'referenceMomentCount': referenceMoments.length,
      'duplicateCandidateCount': duplicateSummary.duplicateCount,
      'duplicateCandidateRatio': duplicateSummary.ratio,
      'duplicateClusters': duplicateSummary.clusters,
      'sourceUnionCoverageMs': sourceCoverage.unionDurationMs,
      'sourceUnionCoverageRatio': sourceCoverage.unionCoverageRatio,
      'sourceCoverageBucketCount': bucketCount,
      'coveredSourceBucketCount': sourceCoverage.coveredBucketCount,
      'sourceCoverageBucketRatio': sourceCoverage.bucketCoverageRatio,
      'humanReviewedCandidateCount': reviewSummary.reviewedCount,
      'unreviewedCandidateCount': reviewSummary.unreviewedCount,
      'humanReviewCoverage': reviewSummary.reviewCoverage,
      'keptAsSuggestedCount': reviewSummary.keepCount,
      'selectedForRepairCount': reviewSummary.repairCount,
      'rejectedCount': reviewSummary.rejectCount,
      'selectedCandidateCount': reviewSummary.selectedCount,
      'selectionRateAmongReviewed': reviewSummary.selectionRate,
      'keptAsSuggestedRateAmongReviewed': reviewSummary.keepRate,
      'repairRateAmongReviewed': reviewSummary.repairRate,
    },
    'sourceCoverage': <String, Object?>{
      'definition':
          'union of all candidate intervals and occupancy of equal-duration source-time buckets',
      'buckets': sourceCoverage.buckets,
    },
    'humanSelection': <String, Object?>{
      'decisionPolicy':
          'keep=selected as suggested; repair=selected after editing; reject=not selected',
      'notReviewedIsNotTreatedAsReject': true,
    },
    'scoring': <String, Object?>{
      'normalization': 'source-time-milliseconds-v1',
      'duplicateDefinition':
          'candidate is redundant when pairwise intersection divided by the shorter candidate duration meets duplicateOverlapThreshold; one item per connected duplicate cluster is retained',
      'duplicateOverlapThreshold': duplicateThreshold,
      'maximumCandidateReferenceComparisons':
          _maximumCandidateReferenceComparisons,
      'maximumDuplicatePairComparisons': _maximumDuplicatePairComparisons,
    },
  };
}

List<_Interval> _parseIntervals(
  Object? raw,
  String field,
  int durationMs, {
  required int maximumItems,
}) {
  if (raw is! List) {
    throw FormatException('$field must be an array');
  }
  _expect(raw.length <= maximumItems, '$field exceeds the item limit');
  final items = <_Interval>[];
  for (var index = 0; index < raw.length; index++) {
    final item = _asMap(raw[index], '$field[$index]');
    final id = _requiredId(item['id'], '$field[$index].id');
    final startMs = _requiredInt(item['startMs'], '$field[$index].startMs');
    final endMs = _requiredInt(item['endMs'], '$field[$index].endMs');
    _expect(startMs >= 0, '$field[$index].startMs cannot be negative');
    _expect(endMs > startMs, '$field[$index].endMs must follow startMs');
    _expect(endMs <= durationMs, '$field[$index] exceeds fixture duration');
    if (field == 'reference.moments') {
      _requiredString(item['label'], '$field[$index].label');
    }
    items.add(_Interval(id: id, startMs: startMs, endMs: endMs));
  }
  return items;
}

List<_Candidate> _parseCandidates(Object? raw, int durationMs) {
  if (raw is! List) {
    throw const FormatException('candidateRun.candidates must be an array');
  }
  _expect(raw.length <= _maximumCandidates, 'candidate count exceeds the limit');
  final candidates = <_Candidate>[];
  final ids = <String>{};
  for (var index = 0; index < raw.length; index++) {
    final item = _asMap(raw[index], 'candidateRun.candidates[$index]');
    final id = _requiredId(item['id'], 'candidateRun.candidates[$index].id');
    final startMs =
        _requiredInt(item['startMs'], 'candidateRun.candidates[$index].startMs');
    final endMs =
        _requiredInt(item['endMs'], 'candidateRun.candidates[$index].endMs');
    final scoreValue = item['score'];
    _expect(
      scoreValue is num,
      'candidateRun.candidates[$index].score must be numeric',
    );
    final score = (scoreValue as num).toDouble();
    _expect(
      score.isFinite && score >= 0 && score <= 100,
      'candidateRun.candidates[$index].score must be between 0 and 100',
    );
    _expect(ids.add(id), 'candidate IDs must be unique');
    _expect(
      startMs >= 0,
      'candidateRun.candidates[$index].startMs cannot be negative',
    );
    _expect(
      endMs > startMs,
      'candidateRun.candidates[$index].endMs must follow startMs',
    );
    _expect(
      endMs <= durationMs,
      'candidateRun.candidates[$index] exceeds fixture duration',
    );
    candidates.add(
      _Candidate(id: id, startMs: startMs, endMs: endMs, score: score),
    );
  }
  return candidates;
}

Map<String, String> _parseDecisions(
  Object? raw,
  Map<String, int> candidateIndexes,
) {
  if (raw is! List) {
    throw const FormatException('humanReview.decisions must be an array');
  }
  final decisions = <String, String>{};
  const allowed = <String>{'keep', 'repair', 'reject'};
  for (var index = 0; index < raw.length; index++) {
    final item = _asMap(raw[index], 'humanReview.decisions[$index]');
    final id = _requiredId(
      item['candidateId'],
      'humanReview.decisions[$index].candidateId',
    );
    final decision = _requiredString(
      item['decision'],
      'humanReview.decisions[$index].decision',
    );
    _expect(
      allowed.contains(decision),
      'humanReview.decisions[$index].decision must be keep, repair or reject',
    );
    _expect(
      candidateIndexes.containsKey(id),
      'human review references an unknown candidate: $id',
    );
    _expect(
      !decisions.containsKey(id),
      'human review contains more than one decision for candidate $id',
    );
    decisions[id] = decision;
  }
  return decisions;
}

List<_MatchEdge> _matchCandidates(
  List<_Interval> reference,
  List<_Candidate> candidates,
  double threshold,
) {
  final edges = <_MatchEdge>[];
  for (var referenceIndex = 0;
      referenceIndex < reference.length;
      referenceIndex++) {
    final moment = reference[referenceIndex];
    for (var candidateIndex = 0;
        candidateIndex < candidates.length;
        candidateIndex++) {
      final candidate = candidates[candidateIndex];
      final overlapStart = math.max(moment.startMs, candidate.startMs);
      final overlapEnd = math.min(moment.endMs, candidate.endMs);
      final intersection = math.max(0, overlapEnd - overlapStart);
      if (intersection == 0) continue;
      final union =
          moment.durationMs + candidate.durationMs - intersection;
      final iou = intersection / union;
      if (iou >= threshold) {
        edges.add(
          _MatchEdge(
            referenceIndex: referenceIndex,
            candidateIndex: candidateIndex,
            intersectionOverUnion: iou,
            candidateScore: candidate.score,
            referenceId: moment.id,
            candidateId: candidate.id,
          ),
        );
      }
    }
  }
  edges.sort((left, right) {
    final byIou =
        right.intersectionOverUnion.compareTo(left.intersectionOverUnion);
    if (byIou != 0) return byIou;
    final byScore = right.candidateScore.compareTo(left.candidateScore);
    if (byScore != 0) return byScore;
    final byReference = left.referenceId.compareTo(right.referenceId);
    if (byReference != 0) return byReference;
    return left.candidateId.compareTo(right.candidateId);
  });

  final usedReferences = <int>{};
  final usedCandidates = <int>{};
  final matches = <_MatchEdge>[];
  for (final edge in edges) {
    if (usedReferences.contains(edge.referenceIndex) ||
        usedCandidates.contains(edge.candidateIndex)) {
      continue;
    }
    usedReferences.add(edge.referenceIndex);
    usedCandidates.add(edge.candidateIndex);
    matches.add(edge);
  }
  return matches;
}

class _DuplicateSummary {
  const _DuplicateSummary({
    required this.duplicateCount,
    required this.ratio,
    required this.clusters,
  });

  final int duplicateCount;
  final double ratio;
  final List<Map<String, Object?>> clusters;
}

_DuplicateSummary _measureDuplicates(
  List<_Candidate> candidates,
  double threshold,
) {
  final count = candidates.length;
  if (count < 2) {
    return _DuplicateSummary(
      duplicateCount: 0,
      ratio: 0,
      clusters: const <Map<String, Object?>>[],
    );
  }
  final ordered = List<int>.generate(count, (index) => index)
    ..sort((left, right) {
      final byStart =
          candidates[left].startMs.compareTo(candidates[right].startMs);
      if (byStart != 0) return byStart;
      final byEnd = candidates[left].endMs.compareTo(candidates[right].endMs);
      if (byEnd != 0) return byEnd;
      return candidates[left].id.compareTo(candidates[right].id);
    });
  final parent = List<int>.generate(count, (index) => index);
  final size = List<int>.filled(count, 1);
  var comparisons = 0;

  int findRoot(int index) {
    var current = index;
    while (parent[current] != current) {
      parent[current] = parent[parent[current]];
      current = parent[current];
    }
    return current;
  }

  void union(int left, int right) {
    var leftRoot = findRoot(left);
    var rightRoot = findRoot(right);
    if (leftRoot == rightRoot) return;
    if (size[leftRoot] < size[rightRoot]) {
      final swap = leftRoot;
      leftRoot = rightRoot;
      rightRoot = swap;
    }
    parent[rightRoot] = leftRoot;
    size[leftRoot] += size[rightRoot];
  }

  for (var leftPosition = 0; leftPosition < ordered.length; leftPosition++) {
    final leftIndex = ordered[leftPosition];
    final left = candidates[leftIndex];
    for (var rightPosition = leftPosition + 1;
        rightPosition < ordered.length;
        rightPosition++) {
      final rightIndex = ordered[rightPosition];
      final right = candidates[rightIndex];
      if (right.startMs >= left.endMs) break;
      comparisons++;
      _expect(
        comparisons <= _maximumDuplicatePairComparisons,
        'duplicate comparison limit exceeded; evaluate a smaller candidate batch',
      );
      final intersection = math.max(
        0,
        math.min(left.endMs, right.endMs) -
            math.max(left.startMs, right.startMs),
      );
      if (intersection == 0) continue;
      final shorterDuration = math.min(left.durationMs, right.durationMs);
      if (intersection / shorterDuration >= threshold) {
        union(leftIndex, rightIndex);
      }
    }
  }

  final groups = <int, List<String>>{};
  for (var index = 0; index < count; index++) {
    groups
        .putIfAbsent(findRoot(index), () => <String>[])
        .add(candidates[index].id);
  }
  final duplicateGroups = groups.values.where((ids) => ids.length > 1).toList()
    ..forEach((ids) => ids.sort())
    ..sort((left, right) => left.first.compareTo(right.first));
  final duplicateCount =
      duplicateGroups.fold<int>(0, (sum, group) => sum + group.length - 1);
  return _DuplicateSummary(
    duplicateCount: duplicateCount,
    ratio: duplicateCount / count,
    clusters: duplicateGroups
        .map((ids) => <String, Object?>{
              'candidateIds': ids,
              'redundantCount': ids.length - 1,
            })
        .toList(growable: false),
  );
}

class _SourceCoverage {
  const _SourceCoverage({
    required this.unionDurationMs,
    required this.unionCoverageRatio,
    required this.coveredBucketCount,
    required this.bucketCoverageRatio,
    required this.buckets,
  });

  final int unionDurationMs;
  final double unionCoverageRatio;
  final int coveredBucketCount;
  final double bucketCoverageRatio;
  final List<Map<String, Object?>> buckets;
}

_SourceCoverage _measureSourceCoverage(
  List<_Candidate> candidates,
  int durationMs,
  int bucketCount,
) {
  final intervals = candidates
      .map((candidate) => _Interval(
            id: candidate.id,
            startMs: candidate.startMs,
            endMs: candidate.endMs,
          ))
      .toList()
    ..sort((left, right) {
      final byStart = left.startMs.compareTo(right.startMs);
      if (byStart != 0) return byStart;
      return left.endMs.compareTo(right.endMs);
    });
  var unionDuration = 0;
  var currentStart = -1;
  var currentEnd = -1;
  for (final interval in intervals) {
    if (currentStart < 0) {
      currentStart = interval.startMs;
      currentEnd = interval.endMs;
    } else if (interval.startMs <= currentEnd) {
      currentEnd = math.max(currentEnd, interval.endMs).toInt();
    } else {
      unionDuration += currentEnd - currentStart;
      currentStart = interval.startMs;
      currentEnd = interval.endMs;
    }
  }
  if (currentStart >= 0) {
    unionDuration += currentEnd - currentStart;
  }

  final buckets = <Map<String, Object?>>[];
  var coveredBuckets = 0;
  for (var index = 0; index < bucketCount; index++) {
    final startMs = (index * durationMs) ~/ bucketCount;
    final endMs = ((index + 1) * durationMs) ~/ bucketCount;
    final covered = candidates.any(
      (candidate) => candidate.startMs < endMs && candidate.endMs > startMs,
    );
    if (covered) coveredBuckets++;
    buckets.add(<String, Object?>{
      'index': index,
      'startMs': startMs,
      'endMs': endMs,
      'hasCandidate': covered,
    });
  }
  return _SourceCoverage(
    unionDurationMs: unionDuration,
    unionCoverageRatio: unionDuration / durationMs,
    coveredBucketCount: coveredBuckets,
    bucketCoverageRatio: coveredBuckets / bucketCount,
    buckets: buckets,
  );
}

class _HumanReviewSummary {
  const _HumanReviewSummary({
    required this.reviewedCount,
    required this.unreviewedCount,
    required this.reviewCoverage,
    required this.keepCount,
    required this.repairCount,
    required this.rejectCount,
    required this.selectedCount,
    required this.selectionRate,
    required this.keepRate,
    required this.repairRate,
  });

  final int reviewedCount;
  final int unreviewedCount;
  final double reviewCoverage;
  final int keepCount;
  final int repairCount;
  final int rejectCount;
  final int selectedCount;
  final double? selectionRate;
  final double? keepRate;
  final double? repairRate;
}

_HumanReviewSummary _summarizeHumanReview(
  int candidateCount,
  Map<String, String> decisions,
) {
  var keep = 0;
  var repair = 0;
  var reject = 0;
  for (final decision in decisions.values) {
    switch (decision) {
      case 'keep':
        keep++;
        break;
      case 'repair':
        repair++;
        break;
      case 'reject':
        reject++;
        break;
    }
  }
  final reviewed = decisions.length;
  final selected = keep + repair;
  final unreviewed = candidateCount - reviewed;
  return _HumanReviewSummary(
    reviewedCount: reviewed,
    unreviewedCount: unreviewed,
    reviewCoverage: candidateCount == 0 ? 0 : reviewed / candidateCount,
    keepCount: keep,
    repairCount: repair,
    rejectCount: reject,
    selectedCount: selected,
    selectionRate: reviewed == 0 ? null : selected / reviewed,
    keepRate: reviewed == 0 ? null : keep / reviewed,
    repairRate: reviewed == 0 ? null : repair / reviewed,
  );
}

Map<String, Object?> _asMap(Object? value, String field) {
  if (value is Map<String, Object?>) return value;
  if (value is Map) {
    return value.map((key, item) => MapEntry(key.toString(), item));
  }
  throw FormatException('$field must be an object');
}

Map<String, Object?> _asMapOrEmpty(Object? value, String field) {
  if (value == null) return <String, Object?>{};
  return _asMap(value, field);
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value.trim();
}

String _requiredId(Object? value, String field) {
  final id = _requiredString(value, field);
  _expect(
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,79}$').hasMatch(id),
    '$field must be a 1–80 character ID using letters, numbers, dot, underscore or hyphen',
  );
  return id;
}

int _requiredInt(Object? value, String field) {
  if (value is! int) {
    throw FormatException('$field must be an integer');
  }
  return value;
}

int _optionalInt(Object? value, int fallback, String field) {
  if (value == null) return fallback;
  if (value is! int) throw FormatException('$field must be an integer');
  return value;
}

double _optionalRatio(
  Object? value,
  double fallback,
  String field, {
  required bool allowZero,
}) {
  if (value == null) return fallback;
  if (value is! num) throw FormatException('$field must be numeric');
  final ratio = value.toDouble();
  _expect(ratio.isFinite, '$field must be finite');
  final allowedRange = allowZero
      ? 'between 0 and 1'
      : 'greater than 0 and at most 1';
  _expect(
    allowZero ? ratio >= 0 && ratio <= 1 : ratio > 0 && ratio <= 1,
    '$field must be $allowedRange',
  );
  return ratio;
}

DateTime _requiredUtc(Object? value, String field) {
  final text = _requiredString(value, field);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$field must be an ISO-8601 UTC timestamp');
  }
  return parsed.toUtc();
}

void _expect(bool condition, String message) {
  if (!condition) throw FormatException(message);
}
