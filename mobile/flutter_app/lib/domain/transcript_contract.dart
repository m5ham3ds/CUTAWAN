class TranscriptWord {
  const TranscriptWord({
    required this.text,
    required this.startMs,
    required this.endMs,
    this.probability = 0,
  });

  final String text;
  final int startMs;
  final int endMs;
  final double probability;

  factory TranscriptWord.fromJson(Map<String, dynamic> json) {
    final text = json['text'] as String? ?? '';
    final start = (json['startMs'] as num?)?.toInt() ?? -1;
    final end = (json['endMs'] as num?)?.toInt() ?? -1;
    final probability = (json['probability'] as num?)?.toDouble() ?? 0;
    if (text.trim().isEmpty || start < 0 || end <= start ||
        probability < 0 || probability > 1) {
      throw const FormatException('Transcript word timing or confidence is invalid.');
    }
    return TranscriptWord(
      text: text,
      startMs: start,
      endMs: end,
      probability: probability,
    );
  }

  Map<String, Object?> toJson() => {
        'text': text,
        'startMs': startMs,
        'endMs': endMs,
        'probability': probability,
      };
}

class TranscriptSegment {
  const TranscriptSegment({
    required this.text,
    required this.startMs,
    required this.endMs,
    required this.words,
  });

  final String text;
  final int startMs;
  final int endMs;
  final List<TranscriptWord> words;

  factory TranscriptSegment.fromJson(Map<String, dynamic> json) {
    final start = (json['startMs'] as num?)?.toInt() ?? -1;
    final end = (json['endMs'] as num?)?.toInt() ?? -1;
    final rawWords = json['words'];
    if (start < 0 || end <= start || rawWords is! List<dynamic>) {
      throw const FormatException('Transcript segment is invalid.');
    }
    return TranscriptSegment(
      text: json['text'] as String? ?? '',
      startMs: start,
      endMs: end,
      words: rawWords
          .map((item) {
                if (item is! Map<String, dynamic>) {
                  throw const FormatException('Transcript word must be a JSON object.');
                }
                return TranscriptWord.fromJson(item);
              })
          .toList(growable: false),
    );
  }

  Map<String, Object?> toJson() => {
        'text': text,
        'startMs': startMs,
        'endMs': endMs,
        'words': words.map((word) => word.toJson()).toList(),
      };
}

class AudioEnergyWindow {
  const AudioEnergyWindow({
    required this.startMs,
    required this.endMs,
    required this.rms,
  });

  final int startMs;
  final int endMs;
  final double rms;

  factory AudioEnergyWindow.fromJson(Map<String, dynamic> json) {
    final start = (json['startMs'] as num?)?.toInt() ?? -1;
    final end = (json['endMs'] as num?)?.toInt() ?? -1;
    final rms = (json['rms'] as num?)?.toDouble() ?? -1;
    if (start < 0 || end <= start || rms < 0 || rms > 1) {
      throw const FormatException('Audio energy window is invalid.');
    }
    return AudioEnergyWindow(startMs: start, endMs: end, rms: rms);
  }

  Map<String, Object?> toJson() => {
        'startMs': startMs,
        'endMs': endMs,
        'rms': rms,
      };
}

class VisualSceneSample {
  const VisualSceneSample({
    required this.timestampMs,
    required this.changeScore,
  });

  final int timestampMs;
  final double changeScore;

  factory VisualSceneSample.fromJson(Map<String, dynamic> json) {
    final timestamp = (json['timestampMs'] as num?)?.toInt() ?? -1;
    final score = (json['changeScore'] as num?)?.toDouble() ?? -1;
    if (timestamp < 0 || score < 0 || score > 1) {
      throw const FormatException('Visual scene sample is invalid.');
    }
    return VisualSceneSample(timestampMs: timestamp, changeScore: score);
  }

  Map<String, Object?> toJson() => {
        'timestampMs': timestampMs,
        'changeScore': changeScore,
      };
}

class CutawanTranscript {
  const CutawanTranscript({
    required this.schemaVersion,
    required this.language,
    required this.text,
    required this.sourceDurationMs,
    required this.createdAtUtc,
    required this.segments,
    required this.audioEnergy,
    required this.visualSamples,
    required this.wordTimingReliable,
    required this.whisperModelId,
  });

  static const currentSchemaVersion = 1;

  final int schemaVersion;
  final String language;
  final String text;
  final int sourceDurationMs;
  final DateTime createdAtUtc;
  final List<TranscriptSegment> segments;
  final List<AudioEnergyWindow> audioEnergy;
  final List<VisualSceneSample> visualSamples;
  final bool wordTimingReliable;
  final String whisperModelId;

  List<TranscriptWord> get words => segments
      .expand((segment) => segment.words)
      .toList(growable: false);

  factory CutawanTranscript.fromJson(Map<String, dynamic> json) {
    final version = (json['schemaVersion'] as num?)?.toInt() ?? 0;
    if (version != currentSchemaVersion) {
      throw FormatException('Unsupported transcript schema version: $version');
    }
    final duration = (json['sourceDurationMs'] as num?)?.toInt() ?? 0;
    final rawSegments = json['segments'];
    final rawEnergy = json['audioEnergy'];
    final rawVisual = json['visualSamples'];
    final createdAt = DateTime.tryParse(json['createdAtUtc'] as String? ?? '');
    if (duration <= 0 || rawSegments is! List<dynamic> ||
        rawEnergy is! List<dynamic> || rawVisual is! List<dynamic> || createdAt == null) {
      throw const FormatException('Transcript payload is incomplete.');
    }
    final transcript = CutawanTranscript(
      schemaVersion: version,
      language: json['language'] as String? ?? 'unknown',
      text: json['text'] as String? ?? '',
      sourceDurationMs: duration,
      createdAtUtc: createdAt.toUtc(),
      segments: rawSegments.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Transcript segment must be a JSON object.');
          }
          return TranscriptSegment.fromJson(item);
        })
          .toList(growable: false),
      audioEnergy: rawEnergy.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Audio evidence must be a JSON object.');
          }
          return AudioEnergyWindow.fromJson(item);
        })
          .toList(growable: false),
      visualSamples: rawVisual.map((item) {
          if (item is! Map<String, dynamic>) {
            throw const FormatException('Visual evidence must be a JSON object.');
          }
          return VisualSceneSample.fromJson(item);
        })
          .toList(growable: false),
      wordTimingReliable: json['wordTimingReliable'] as bool? ?? false,
      whisperModelId: json['whisperModelId'] as String? ?? '',
    );
    transcript.validate();
    return transcript;
  }

  void validate() {
    if (schemaVersion != currentSchemaVersion ||
        sourceDurationMs <= 0 ||
        whisperModelId.trim().isEmpty) {
      throw const FormatException('Transcript header is invalid.');
    }
    var previousStart = -1;
    for (final segment in segments) {
      if (segment.startMs < 0 || segment.endMs <= segment.startMs ||
          segment.endMs > sourceDurationMs + 1000 ||
          segment.startMs < previousStart) {
        throw const FormatException('Transcript segments are not time ordered or in source bounds.');
      }
      previousStart = segment.startMs;
      var wordStart = segment.startMs;
      for (final word in segment.words) {
        if (word.startMs < segment.startMs ||
            word.endMs > segment.endMs + 500 ||
            word.startMs < wordStart) {
          throw const FormatException('Transcript words are outside their segment or not time ordered.');
        }
        wordStart = word.startMs;
      }
    }
    for (final window in audioEnergy) {
      if (window.endMs > sourceDurationMs + 1000) {
        throw const FormatException('Audio evidence exceeds source duration.');
      }
    }
    for (final sample in visualSamples) {
      if (sample.timestampMs > sourceDurationMs + 1000) {
        throw const FormatException('Visual evidence exceeds source duration.');
      }
    }
    if (wordTimingReliable && words.isEmpty) {
      throw const FormatException('Reliable word timing cannot be empty.');
    }
  }

  Map<String, Object?> toJson() => {
        'schemaVersion': schemaVersion,
        'language': language,
        'text': text,
        'sourceDurationMs': sourceDurationMs,
        'createdAtUtc': createdAtUtc.toUtc().toIso8601String(),
        'segments': segments.map((segment) => segment.toJson()).toList(),
        'audioEnergy': audioEnergy.map((window) => window.toJson()).toList(),
        'visualSamples': visualSamples.map((sample) => sample.toJson()).toList(),
        'wordTimingReliable': wordTimingReliable,
        'whisperModelId': whisperModelId,
      };
}
