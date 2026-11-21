import 'dart:convert';

import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:flutter_test/flutter_test.dart';

CutawanTranscript sampleTranscript({bool reliable = true}) {
  return CutawanTranscript(
    schemaVersion: CutawanTranscript.currentSchemaVersion,
    language: 'ar',
    text: 'مرحبًا بالعالم.',
    sourceDurationMs: 5000,
    createdAtUtc: DateTime.utc(2026, 11, 20),
    segments: const [
      TranscriptSegment(
        text: 'مرحبًا بالعالم.',
        startMs: 0,
        endMs: 2400,
        words: [
          TranscriptWord(
            text: 'مرحبًا',
            startMs: 0,
            endMs: 900,
            probability: 0.96,
          ),
          TranscriptWord(
            text: 'بالعالم.',
            startMs: 1000,
            endMs: 2400,
            probability: 0.93,
          ),
        ],
      ),
    ],
    audioEnergy: const [
      AudioEnergyWindow(startMs: 0, endMs: 1000, rms: 0.25),
    ],
    visualSamples: const [
      VisualSceneSample(timestampMs: 0, changeScore: 0),
    ],
    wordTimingReliable: reliable,
    whisperModelId: 'base',
  );
}

void main() {
  test('transcript JSON round-trips word timestamps and multimodal evidence', () {
    final value = sampleTranscript();
    final decoded = jsonDecode(jsonEncode(value.toJson()));
    final restored = CutawanTranscript.fromJson(
      Map<String, dynamic>.from(decoded as Map<String, dynamic>),
    );

    expect(restored.language, 'ar');
    expect(restored.words, hasLength(2));
    expect(restored.words.first.startMs, 0);
    expect(restored.words.last.endMs, 2400);
    expect(restored.audioEnergy.single.rms, 0.25);
    expect(restored.visualSamples.single.changeScore, 0);
    expect(restored.wordTimingReliable, isTrue);
  });

  test('transcript rejects word timing outside its segment', () {
    final json = sampleTranscript().toJson();
    final segments = json['segments'] as List<dynamic>;
    final segment = Map<String, dynamic>.from(segments.single as Map);
    final words = segment['words'] as List;
    final invalidWord = Map<String, dynamic>.from(words.first as Map)
      ..['startMs'] = 1000
      ..['endMs'] = 5000;
    segment['words'] = [invalidWord, words.last];
    json['segments'] = [segment];

    expect(
      () => CutawanTranscript.fromJson(Map<String, dynamic>.from(json)),
      throwsA(isA<FormatException>()),
    );
  });

  test('reliable word timing cannot be declared for an empty transcript', () {
    final json = sampleTranscript().toJson()
      ..['segments'] = <Object?>[];

    expect(
      () => CutawanTranscript.fromJson(Map<String, dynamic>.from(json)),
      throwsA(isA<FormatException>()),
    );
  });

  test('non-finite word confidence and audio/visual evidence are rejected', () {
    final wordJson = sampleTranscript().toJson();
    final segments = wordJson['segments'] as List<dynamic>;
    final segment = Map<String, dynamic>.from(segments.single as Map);
    final words = segment['words'] as List<dynamic>;
    final invalidWord = Map<String, dynamic>.from(words.first as Map)
      ..['probability'] = double.nan;
    segment['words'] = [invalidWord, words.last];
    wordJson['segments'] = [segment];
    expect(
      () => CutawanTranscript.fromJson(Map<String, dynamic>.from(wordJson)),
      throwsA(isA<FormatException>()),
    );

    final energyJson = sampleTranscript().toJson();
    final energy = Map<String, dynamic>.from(
      (energyJson['audioEnergy'] as List<dynamic>).single as Map,
    )..['rms'] = double.infinity;
    energyJson['audioEnergy'] = [energy];
    expect(
      () => CutawanTranscript.fromJson(Map<String, dynamic>.from(energyJson)),
      throwsA(isA<FormatException>()),
    );

    final visualJson = sampleTranscript().toJson();
    final visual = Map<String, dynamic>.from(
      (visualJson['visualSamples'] as List<dynamic>).single as Map,
    )..['changeScore'] = double.nan;
    visualJson['visualSamples'] = [visual];
    expect(
      () => CutawanTranscript.fromJson(Map<String, dynamic>.from(visualJson)),
      throwsA(isA<FormatException>()),
    );
  });

  test('unsupported transcript schema is rejected', () {
    final json = sampleTranscript().toJson()..['schemaVersion'] = 22;
    expect(
      () => CutawanTranscript.fromJson(Map<String, dynamic>.from(json)),
      throwsA(isA<FormatException>()),
    );
  });
}
