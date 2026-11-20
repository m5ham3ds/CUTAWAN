import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/services/local_editorial_annotation_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CandidateSet sampleSet() => CandidateSet(
        schemaVersion: CandidateSet.currentSchemaVersion,
        sourceDurationMs: 30000,
        createdAtUtc: DateTime.utc(2026, 11, 20),
        candidates: const [
          ClipCandidate(
            id: 'clip_1000_18000',
            startMs: 1000,
            endMs: 18000,
            score: 73,
            title: 'Original title',
            hook: 'Original hook',
            summary: 'Original summary',
            explanations: ['Transcript density'],
            transcriptText: 'A supplied source sentence.',
            averageAudioEnergy: 0.4,
            peakVisualChange: 0.2,
          ),
        ],
        transcriptEvidence: true,
        audioEvidence: true,
        visualEvidence: true,
        rankingEngine: 'deterministic-evidence-v1',
      );

  test('local model annotations can only change editorial text for known IDs', () {
    final original = sampleSet();
    final updated =
        LocalEditorialAnnotationService.applyJsonAnnotations(
      original,
      '''
      {"items":[
        {"id":"clip_1000_18000","title":"A reviewed title",
         "hook":"A concise opening","summary":"Grounded summary",
         "explanations":["Clear statement","Useful context"]},
        {"id":"invented_0_999","title":"Must be ignored"}
      ]}
      ''',
    );

    final candidate = updated.candidates.single;
    expect(candidate.title, 'A reviewed title');
    expect(candidate.hook, 'A concise opening');
    expect(candidate.modelAnnotated, isTrue);
    expect(candidate.startMs, 1000);
    expect(candidate.endMs, 18000);
    expect(candidate.score, 73);
    expect(candidate.averageAudioEnergy, 0.4);
    expect(updated.rankingEngine, contains('qwen-local-annotation'));
  });

  test('invalid model JSON leaves deterministic candidate data unchanged', () {
    final original = sampleSet();
    final result =
        LocalEditorialAnnotationService.applyJsonAnnotations(
      original,
      'not JSON',
    );

    expect(result.candidates.single.title, 'Original title');
    expect(result.candidates.single.score, 73);
    expect(result.rankingEngine, 'deterministic-evidence-v1');
    expect(result.candidates.single.modelAnnotated, isFalse);
  });

  test('unknown IDs and duplicate model IDs are not used', () {
    final original = sampleSet();
    final result =
        LocalEditorialAnnotationService.applyJsonAnnotations(
      original,
      '''
      {"items":[
        {"id":"unknown","title":"Fake"},
        {"id":"clip_1000_18000","title":"First"},
        {"id":"clip_1000_18000","title":"Second"}
      ]}
      ''',
    );

    expect(result.candidates.single.title, 'First');
    expect(result.candidates.single.startMs, 1000);
  });
}
