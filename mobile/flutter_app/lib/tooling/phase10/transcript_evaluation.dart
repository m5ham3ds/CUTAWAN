import 'dart:typed_data';

const String phase10TranscriptionEvaluationSchema =
    'org.cutawan.phase10.transcription-evaluation';
const int phase10TranscriptionEvaluationSchemaVersion = 1;
const int _maximumAlignmentCells = 8000000;

class _TimedWord {
  const _TimedWord({
    required this.normalized,
    required this.startMs,
    required this.endMs,
  });

  final String normalized;
  final int startMs;
  final int endMs;
}

class _AlignmentResult {
  const _AlignmentResult({
    required this.substitutions,
    required this.deletions,
    required this.insertions,
    required this.matches,
  });

  final int substitutions;
  final int deletions;
  final int insertions;
  final List<List<int>> matches;
}

/// Evaluates a manually reviewed word-timed reference against a device transcript.
///
/// The input is bound to a confirmed physical handset, a pinned application
/// build and a SHA-256-locked media fixture. The output contains measurements
/// only; it never changes Phase 8/9/10 acceptance statuses.
Map<String, Object?> evaluatePhase10Transcription(
  Map<String, Object?> input,
) {
  _expect(
    input['schema'] == phase10TranscriptionEvaluationSchema,
    'schema must be $phase10TranscriptionEvaluationSchema',
  );
  _expect(
    input['schemaVersion'] == phase10TranscriptionEvaluationSchemaVersion,
    'unsupported schemaVersion',
  );

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
  final fixtureId = _requiredString(fixture['id'], 'fixture.id');
  final fixtureSha = _requiredString(fixture['sha256'], 'fixture.sha256');
  _expect(
    RegExp(r'^[a-fA-F0-9]{64}$').hasMatch(fixtureSha),
    'fixture.sha256 must be a 64-character SHA-256',
  );
  final language = _requiredString(fixture['language'], 'fixture.language');
  final languageFamily = _languageFamily(language);
  _expect(
    languageFamily == 'ar' || languageFamily == 'en',
    'fixture.language must identify Arabic (ar) or English (en)',
  );
  final durationMs = _requiredInt(fixture['durationMs'], 'fixture.durationMs');
  _expect(durationMs > 0, 'fixture.durationMs must be positive');

  final reference = _asMap(input['reference'], 'reference');
  _expect(
    reference['reviewStatus'] == 'human-reviewed',
    'reference.reviewStatus must be human-reviewed',
  );
  final reviewerId =
      _requiredString(reference['reviewerId'], 'reference.reviewerId');
  _expect(
    RegExp(r'^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$').hasMatch(reviewerId),
    'reference.reviewerId must be a pseudonymous ID (1–64 safe characters)',
  );
  final reviewedAtUtc =
      _requiredUtc(reference['reviewedAtUtc'], 'reference.reviewedAtUtc');

  final hypothesis = _asMap(input['hypothesis'], 'hypothesis');
  final engine = _requiredString(hypothesis['engine'], 'hypothesis.engine');
  final modelName = _requiredString(hypothesis['model'], 'hypothesis.model');
  final hypothesisLanguage =
      _requiredString(hypothesis['language'], 'hypothesis.language');
  _expect(
    _languageFamily(hypothesisLanguage) == languageFamily,
    'hypothesis.language must match fixture.language',
  );
  final measuredAtUtc = _requiredUtc(input['measuredAtUtc'], 'measuredAtUtc');

  final referenceWords = _parseWords(
    reference['words'],
    'reference.words',
    durationMs,
  );
  final hypothesisWords = _parseWords(
    hypothesis['words'],
    'hypothesis.words',
    durationMs,
  );
  _expect(referenceWords.isNotEmpty, 'reference.words must contain speech words');

  final alignment = _align(referenceWords, hypothesisWords);
  final referenceCount = referenceWords.length;
  final hypothesisCount = hypothesisWords.length;
  final matchedCount = alignment.matches.length;
  final editCount = alignment.substitutions +
      alignment.deletions +
      alignment.insertions;
  final startErrors = <double>[];
  final endErrors = <double>[];
  for (final pair in alignment.matches) {
    final expected = referenceWords[pair[0]];
    final actual = hypothesisWords[pair[1]];
    startErrors.add((actual.startMs - expected.startMs).abs().toDouble());
    endErrors.add((actual.endMs - expected.endMs).abs().toDouble());
  }

  return <String, Object?>{
    'schema': phase10TranscriptionEvaluationSchema,
    'schemaVersion': phase10TranscriptionEvaluationSchemaVersion,
    'evaluatedAtUtc': DateTime.now().toUtc().toIso8601String(),
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
      'language': language,
      'durationMs': durationMs,
    },
    'reference': <String, Object?>{
      'reviewStatus': 'human-reviewed',
      'reviewerId': reviewerId,
      'reviewedAtUtc': reviewedAtUtc.toIso8601String(),
      'wordCount': referenceCount,
    },
    'hypothesis': <String, Object?>{
      'engine': engine,
      'model': modelName,
      'language': hypothesisLanguage,
      'wordCount': hypothesisCount,
    },
    'metrics': <String, Object?>{
      'wordErrorRate': editCount / referenceCount,
      'wordErrorRatePercent': editCount * 100 / referenceCount,
      'substitutions': alignment.substitutions,
      'deletions': alignment.deletions,
      'insertions': alignment.insertions,
      'editCount': editCount,
      'referenceWordCount': referenceCount,
      'hypothesisWordCount': hypothesisCount,
      'exactMatchedWordCount': matchedCount,
      'matchedWordCoverage': matchedCount / referenceCount,
      'matchedWordPrecision':
          hypothesisCount == 0 ? 0.0 : matchedCount / hypothesisCount,
      'timingMatchedWordCount': matchedCount,
      'medianAbsoluteStartErrorMs': _median(startErrors),
      'p95AbsoluteStartErrorMs': _percentile95(startErrors),
      'medianAbsoluteEndErrorMs': _median(endErrors),
      'p95AbsoluteEndErrorMs': _percentile95(endErrors),
    },
    'scoring': <String, Object?>{
      'alignment': 'levenshtein-word-alignment',
      'tieBreak': 'diagonal-then-deletion-then-insertion',
      'timingPolicy':
          'absolute start/end error on exact normalized word matches only',
      'normalization': 'cutawan-ar-en-v1',
      'normalizationRules': <String>[
        'lowercase Latin text',
        'remove Arabic harakat and tatweel',
        'normalize alef variants and alef maqsura',
        'trim leading and trailing Arabic/Latin punctuation',
      ],
      'maximumAlignmentCells': _maximumAlignmentCells,
    },
  };
}

List<_TimedWord> _parseWords(Object? raw, String field, int durationMs) {
  if (raw is! List) {
    throw FormatException('$field must be an array');
  }
  final result = <_TimedWord>[];
  var previousStart = -1;
  for (var index = 0; index < raw.length; index++) {
    final item = _asMap(raw[index], '$field[$index]');
    final text = _requiredString(item['text'], '$field[$index].text');
    final startMs = _requiredInt(item['startMs'], '$field[$index].startMs');
    final endMs = _requiredInt(item['endMs'], '$field[$index].endMs');
    _expect(startMs >= 0, '$field[$index].startMs cannot be negative');
    _expect(endMs > startMs, '$field[$index].endMs must follow startMs');
    _expect(endMs <= durationMs, '$field[$index] exceeds fixture duration');
    _expect(
      startMs >= previousStart,
      '$field must be ordered by nondecreasing startMs',
    );
    previousStart = startMs;

    final normalized = _normalizeWord(text);
    if (normalized.isEmpty) {
      continue;
    }
    _expect(
      !RegExp(r'\s').hasMatch(normalized),
      '$field[$index].text must contain a single word token',
    );
    result.add(
      _TimedWord(
        normalized: normalized,
        startMs: startMs,
        endMs: endMs,
      ),
    );
  }
  return result;
}

String _normalizeWord(String value) {
  var token = value.trim().toLowerCase();
  token = token.replaceAll(
    RegExp(r'[\u064B-\u065F\u0670\u06D6-\u06ED\u0640]'),
    '',
  );
  token = token
      .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
      .replaceAll('ى', 'ي');

  const punctuation = ".,!?;:'\"\x60~()[]{}<>،؛؟۔…。，！？：；«»“”‘’";
  final runes = token.runes.toList(growable: false);
  var start = 0;
  var end = runes.length;
  while (start < end && punctuation.contains(String.fromCharCode(runes[start]))) {
    start++;
  }
  while (end > start && punctuation.contains(String.fromCharCode(runes[end - 1]))) {
    end--;
  }
  return String.fromCharCodes(runes.skip(start).take(end - start)).trim();
}

_AlignmentResult _align(
  List<_TimedWord> reference,
  List<_TimedWord> hypothesis,
) {
  final rows = reference.length + 1;
  final columns = hypothesis.length + 1;
  final cells = rows * columns;
  _expect(
    cells <= _maximumAlignmentCells,
    'transcript is too long for one alignment; split it into shorter source-time windows',
  );

  // Two cost rows plus one byte per cell for deterministic traceback keep
  // memory bounded even for the maximum accepted alignment size.
  final backtrack = Uint8List(cells);
  var previous = Uint32List(columns);
  var current = Uint32List(columns);
  for (var column = 0; column < columns; column++) {
    previous[column] = column;
    if (column > 0) {
      backtrack[column] = 2; // insertion
    }
  }
  for (var row = 1; row < rows; row++) {
    current[0] = row;
    backtrack[row * columns] = 1; // deletion
    for (var column = 1; column < columns; column++) {
      final same = reference[row - 1].normalized ==
          hypothesis[column - 1].normalized;
      final diagonal = previous[column - 1] + (same ? 0 : 1);
      final deletion = previous[column] + 1;
      final insertion = current[column - 1] + 1;
      final index = row * columns + column;

      if (diagonal <= deletion && diagonal <= insertion) {
        current[column] = diagonal;
        backtrack[index] = 0;
      } else if (deletion <= insertion) {
        current[column] = deletion;
        backtrack[index] = 1;
      } else {
        current[column] = insertion;
        backtrack[index] = 2;
      }
    }
    final swap = previous;
    previous = current;
    current = swap;
  }

  var row = reference.length;
  var column = hypothesis.length;
  var substitutions = 0;
  var deletions = 0;
  var insertions = 0;
  final matches = <List<int>>[];
  while (row > 0 || column > 0) {
    final direction = backtrack[row * columns + column];
    if (row > 0 && column > 0 && direction == 0) {
      if (reference[row - 1].normalized ==
          hypothesis[column - 1].normalized) {
        matches.add(<int>[row - 1, column - 1]);
      } else {
        substitutions++;
      }
      row--;
      column--;
    } else if (row > 0 && (column == 0 || direction == 1)) {
      deletions++;
      row--;
    } else if (column > 0) {
      insertions++;
      column--;
    } else {
      throw StateError('Invalid transcript alignment traceback.');
    }
  }

  return _AlignmentResult(
    substitutions: substitutions,
    deletions: deletions,
    insertions: insertions,
    matches: matches,
  );
}

double? _median(List<double> values) {
  if (values.isEmpty) {
    return null;
  }
  final sorted = values.toList()..sort();
  final middle = sorted.length ~/ 2;
  if (sorted.length.isOdd) {
    return sorted[middle];
  }
  return (sorted[middle - 1] + sorted[middle]) / 2;
}

double? _percentile95(List<double> values) {
  if (values.isEmpty) {
    return null;
  }
  final sorted = values.toList()..sort();
  final index = (sorted.length * 0.95).ceil() - 1;
  return sorted[index];
}

Map<String, Object?> _asMap(Object? value, String field) {
  if (value is Map<String, Object?>) {
    return value;
  }
  if (value is Map) {
    return value.map(
      (key, item) => MapEntry(key.toString(), item),
    );
  }
  throw FormatException('$field must be an object');
}

String _requiredString(Object? value, String field) {
  if (value is! String || value.trim().isEmpty) {
    throw FormatException('$field must be a non-empty string');
  }
  return value.trim();
}

int _requiredInt(Object? value, String field) {
  if (value is! int) {
    throw FormatException('$field must be an integer');
  }
  return value;
}

DateTime _requiredUtc(Object? value, String field) {
  final text = _requiredString(value, field);
  final parsed = DateTime.tryParse(text);
  if (parsed == null || !parsed.isUtc) {
    throw FormatException('$field must be an ISO-8601 UTC timestamp');
  }
  return parsed.toUtc();
}

String _languageFamily(String language) {
  return language.toLowerCase().split(RegExp(r'[-_]')).first;
}

void _expect(bool condition, String message) {
  if (!condition) {
    throw FormatException(message);
  }
}
