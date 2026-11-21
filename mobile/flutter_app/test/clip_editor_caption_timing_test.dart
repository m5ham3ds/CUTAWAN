import 'package:flutter_test/flutter_test.dart';
import 'package:cutawan_mobile/domain/caption_catalog.dart';
import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/transcript_contract.dart';
import 'package:cutawan_mobile/services/caption_sidecar_generator.dart';

void main() {
  test('caption timing offset is applied to generated word overlays', () {
    final transcript = CutawanTranscript(
      schemaVersion: CutawanTranscript.currentSchemaVersion,
      language: 'en',
      text: 'Hello world',
      sourceDurationMs: 5000,
      createdAtUtc: DateTime.utc(2026, 11, 21),
      segments: const [
        TranscriptSegment(
          text: 'Before Hello world',
          startMs: 400,
          endMs: 2500,
          words: [
            TranscriptWord(text: 'Before', startMs: 400, endMs: 450),
            TranscriptWord(text: 'Hello', startMs: 1000, endMs: 1500),
            TranscriptWord(text: 'world', startMs: 1700, endMs: 2200),
          ],
        ),
      ],
      audioEnergy: const [],
      visualSamples: const [],
      wordTimingReliable: true,
      whisperModelId: 'whisper-base',
    );
    const candidate = ClipCandidate(
      id: 'clip_timing',
      startMs: 500,
      endMs: 3000,
      score: 80,
      title: 'Clip',
      hook: 'Hook',
      summary: 'Summary',
      explanations: [],
      transcriptText: 'Hello world',
      averageAudioEnergy: 0.5,
      peakVisualChange: 0.4,
    );
    const generator = CaptionSidecarGenerator();
    final style = captionStylePresets.first;
    final baseline = generator.generate(
      transcript: transcript,
      candidate: candidate,
      style: style,
      aspectRatio: 9 / 16,
    );
    final shifted = generator.generate(
      transcript: transcript,
      candidate: candidate,
      style: style,
      aspectRatio: 9 / 16,
      timingOffsetMs: 250,
    );
    final baseWords = baseline.cues.single['words']! as List;
    final shiftedWords = shifted.cues.single['words']! as List;
    expect(baseWords, hasLength(2));
    expect((baseWords.first as Map)['text'], 'HELLO');
    final shiftedBefore = shiftedWords.cast<Map>().firstWhere(
      (word) => word['text'] == 'BEFORE',
    );
    final shiftedHello = shiftedWords.cast<Map>().firstWhere(
      (word) => word['text'] == 'HELLO',
    );
    expect(shiftedBefore['startMs'], 150);
    expect(shiftedHello['startMs'], 750);
    expect(shifted.cues.single['startMs'], 150);
    expect(
      () => generator.generate(
        transcript: transcript,
        candidate: candidate,
        style: style,
        aspectRatio: 9 / 16,
        timingOffsetMs: 5001,
      ),
      throwsFormatException,
    );
  });
}
