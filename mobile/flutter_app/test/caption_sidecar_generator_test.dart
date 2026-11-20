import 'package:cutawan_mobile/domain/caption_catalog.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/services/caption_sidecar_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final transcript = CutawanTranscript(
    schemaVersion: CutawanTranscript.currentSchemaVersion,
    language: 'ar',
    text: 'هذه لحظة مهمة للاختبار.',
    sourceDurationMs: 10000,
    createdAtUtc: DateTime.utc(2026, 11, 20),
    segments: const [
      TranscriptSegment(
        text: 'هذه لحظة مهمة للاختبار.',
        startMs: 500,
        endMs: 6000,
        words: [
          TranscriptWord(text: 'هذه', startMs: 500, endMs: 1100),
          TranscriptWord(text: 'لحظة', startMs: 1200, endMs: 2200),
          TranscriptWord(text: 'مهمة', startMs: 2300, endMs: 3400),
          TranscriptWord(text: 'للاختبار.', startMs: 3500, endMs: 6000),
        ],
      ),
    ],
    audioEnergy: const [],
    visualSamples: const [],
    wordTimingReliable: true,
    whisperModelId: 'base',
  );
  const candidate = ClipCandidate(
    id: 'clip_1000_5000',
    startMs: 1000,
    endMs: 5000,
    score: 80,
    title: 'Test',
    hook: 'Hook',
    summary: 'Summary',
    explanations: ['Transcript evidence'],
    transcriptText: 'لحظة مهمة',
    averageAudioEnergy: 0.2,
    peakVisualChange: 0.1,
  );

  test('creates relative-time Arabic SRT and styled ASS sidecars', () {
    final generated = const CaptionSidecarGenerator().generate(
      transcript: transcript,
      candidate: candidate,
      style: captionStylePresets.firstWhere((style) => style.id == 'karaoke'),
      aspectRatio: 9 / 16,
      animationId: 'karaoke_fill',
    );
    expect(generated.srt, contains('00:00:00,000 -->'));
    expect(generated.srt, contains('لحظة مهمة'));
    expect(generated.ass, contains('[V4+ Styles]'));
    expect(generated.ass, contains('[Events]'));
    expect(generated.ass, contains(r'{\kf'));
    expect(generated.ass, contains(r'\pos(540,'));
    expect(generated.ass, contains('لحظة'));
  });

  test('returns empty sidecars when no timed word overlaps the clip', () {
    const noOverlap = ClipCandidate(
      id: 'clip_7000_9000',
      startMs: 7000,
      endMs: 9000,
      score: 70,
      title: 'No words',
      hook: '',
      summary: '',
      explanations: [],
      transcriptText: '',
      averageAudioEnergy: 0,
      peakVisualChange: 0,
    );
    final generated = const CaptionSidecarGenerator().generate(
      transcript: transcript,
      candidate: noOverlap,
      style: captionStylePresets.first,
      aspectRatio: 9 / 16,
    );
    expect(generated.srt, isEmpty);
    expect(generated.ass, isEmpty);
  });
}
