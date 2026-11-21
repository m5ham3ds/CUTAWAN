class ClipCandidate {
  const ClipCandidate({
    required this.id,
    required this.startMs,
    required this.endMs,
    required this.score,
    required this.title,
    required this.hook,
    required this.summary,
    required this.explanations,
    required this.transcriptText,
    required this.averageAudioEnergy,
    required this.peakVisualChange,
    this.modelAnnotated = false,
  });

  final String id;
  final int startMs;
  final int endMs;
  final double score;
  final String title;
  final String hook;
  final String summary;
  final List<String> explanations;
  final String transcriptText;
  final double averageAudioEnergy;
  final double peakVisualChange;
  final bool modelAnnotated;

  int get durationMs => endMs - startMs;

  ClipCandidate copyWith({
    int? startMs,
    int? endMs,
    String? title,
    String? hook,
    String? summary,
    List<String>? explanations,
    bool? modelAnnotated,
  }) =>
      ClipCandidate(
        id: id,
        startMs: startMs ?? this.startMs,
        endMs: endMs ?? this.endMs,
        score: score,
        title: title ?? this.title,
        hook: hook ?? this.hook,
        summary: summary ?? this.summary,
        explanations: explanations ?? this.explanations,
        transcriptText: transcriptText,
        averageAudioEnergy: averageAudioEnergy,
        peakVisualChange: peakVisualChange,
        modelAnnotated: modelAnnotated ?? this.modelAnnotated,
      );

  factory ClipCandidate.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String? ?? '';
    final start = (json['startMs'] as num?)?.toInt() ?? -1;
    final end = (json['endMs'] as num?)?.toInt() ?? -1;
    final score = (json['score'] as num?)?.toDouble() ?? -1;
    final energy = (json['averageAudioEnergy'] as num?)?.toDouble() ?? -1;
    final visual = (json['peakVisualChange'] as num?)?.toDouble() ?? -1;
    final explanations = json['explanations'];
    if (id.trim().isEmpty || start < 0 || end <= start ||
        !score.isFinite || score < 0 || score > 100 ||
        !energy.isFinite || energy < 0 || energy > 1 ||
        !visual.isFinite || visual < 0 || visual > 1 ||
        explanations is! List<dynamic>) {
      throw const FormatException('Clip candidate is invalid.');
    }
    return ClipCandidate(
      id: id,
      startMs: start,
      endMs: end,
      score: score,
      title: json['title'] as String? ?? '',
      hook: json['hook'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      explanations: explanations.whereType<String>().toList(growable: false),
      transcriptText: json['transcriptText'] as String? ?? '',
      averageAudioEnergy: energy,
      peakVisualChange: visual,
      modelAnnotated: json['modelAnnotated'] as bool? ?? false,
    );
  }

  Map<String, Object?> toJson() => {
        'id': id,
        'startMs': startMs,
        'endMs': endMs,
        'score': score,
        'title': title,
        'hook': hook,
        'summary': summary,
        'explanations': explanations,
        'transcriptText': transcriptText,
        'averageAudioEnergy': averageAudioEnergy,
        'peakVisualChange': peakVisualChange,
        'modelAnnotated': modelAnnotated,
      };
}

class CandidateSet {
  const CandidateSet({
    required this.schemaVersion,
    required this.sourceDurationMs,
    required this.createdAtUtc,
    required this.candidates,
    required this.transcriptEvidence,
    required this.audioEvidence,
    required this.visualEvidence,
    required this.rankingEngine,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final int sourceDurationMs;
  final DateTime createdAtUtc;
  final List<ClipCandidate> candidates;
  final bool transcriptEvidence;
  final bool audioEvidence;
  final bool visualEvidence;
  final String rankingEngine;

  CandidateSet copyWith({
    List<ClipCandidate>? candidates,
    String? rankingEngine,
  }) =>
      CandidateSet(
        schemaVersion: schemaVersion,
        sourceDurationMs: sourceDurationMs,
        createdAtUtc: createdAtUtc,
        candidates: candidates ?? this.candidates,
        transcriptEvidence: transcriptEvidence,
        audioEvidence: audioEvidence,
        visualEvidence: visualEvidence,
        rankingEngine: rankingEngine ?? this.rankingEngine,
      );

  factory CandidateSet.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    final duration = (json['sourceDurationMs'] as num?)?.toInt() ?? 0;
    final created = DateTime.tryParse(json['createdAtUtc'] as String? ?? '');
    final raw = json['candidates'];
    if (version != currentSchemaVersion || duration <= 0 ||
        created == null || raw is! List<dynamic>) {
      throw const FormatException('Candidate set is incomplete or uses an unsupported schema.');
    }
    final value = CandidateSet(
      schemaVersion: version,
      sourceDurationMs: duration,
      createdAtUtc: created.toUtc(),
      candidates: raw.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Clip candidate must be a JSON object.');
          }
          return ClipCandidate.fromJson(item);
        })
          .toList(growable: false),
      transcriptEvidence: json['transcriptEvidence'] as bool? ?? false,
      audioEvidence: json['audioEvidence'] as bool? ?? false,
      visualEvidence: json['visualEvidence'] as bool? ?? false,
      rankingEngine: json['rankingEngine'] as String? ?? 'heuristic',
    );
    value.validate();
    return value;
  }

  void validate() {
    if (sourceDurationMs <= 0 || rankingEngine.trim().isEmpty) {
      throw const FormatException('Candidate set header is invalid.');
    }
    final ids = <String>{};
    for (final candidate in candidates) {
      if (candidate.id.trim().isEmpty ||
          !ids.add(candidate.id) ||
          candidate.startMs < 0 ||
          candidate.endMs <= candidate.startMs ||
          candidate.endMs > sourceDurationMs ||
          !candidate.score.isFinite ||
          candidate.score < 0 ||
          candidate.score > 100 ||
          !candidate.averageAudioEnergy.isFinite ||
          candidate.averageAudioEnergy < 0 ||
          candidate.averageAudioEnergy > 1 ||
          !candidate.peakVisualChange.isFinite ||
          candidate.peakVisualChange < 0 ||
          candidate.peakVisualChange > 1) {
        throw const FormatException('Candidate IDs must be unique and times must stay inside the source.');
      }
    }
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'sourceDurationMs': sourceDurationMs,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'candidates': candidates.map((candidate) => candidate.toJson()).toList(),
        'transcriptEvidence': transcriptEvidence,
        'audioEvidence': audioEvidence,
        'visualEvidence': visualEvidence,
        'rankingEngine': rankingEngine,
      };
}
