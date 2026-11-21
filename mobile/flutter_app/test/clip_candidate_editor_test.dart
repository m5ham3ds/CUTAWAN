import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';

void main() {
  ClipCandidate makeCandidate() => const ClipCandidate(
    id: 'clip_1', startMs: 1000, endMs: 6000, score: 82,
    title: 'مقابلة قصيرة', hook: 'Hook', summary: 'Summary',
    explanations: ['clear payoff'], transcriptText: 'مرحبا بالعالم',
    averageAudioEnergy: 0.7, peakVisualChange: 0.4,
  );

  test('editor updates trim and title without losing candidate evidence', () {
    final original = makeCandidate();
    final edited = original.copyWith(startMs: 1500, endMs: 5200, title: 'النتيجة النهائية');
    expect(edited.id, original.id);
    expect(edited.startMs, 1500);
    expect(edited.endMs, 5200);
    expect(edited.durationMs, 3700);
    expect(edited.title, 'النتيجة النهائية');
    expect(edited.score, original.score);
    expect(edited.transcriptText, original.transcriptText);
    expect(edited.explanations, original.explanations);
  });

  test('candidate validation rejects an edited range outside its source', () {
    final set = CandidateSet(
      schemaVersion: CandidateSet.currentSchemaVersion,
      sourceDurationMs: 10000,
      createdAtUtc: DateTime.utc(2026, 11, 21),
      candidates: [makeCandidate().copyWith(endMs: 11000)],
      transcriptEvidence: true,
      audioEvidence: true,
      visualEvidence: false,
      rankingEngine: 'test',
    );
    expect(() => set.validate(), throwsFormatException);
  });
}
