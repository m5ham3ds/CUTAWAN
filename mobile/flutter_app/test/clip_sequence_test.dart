import 'package:cutawan_mobile/domain/clip_candidate.dart';
import 'package:cutawan_mobile/domain/clip_sequence.dart';
import 'package:flutter_test/flutter_test.dart';

CandidateSet makeCandidates() => CandidateSet(
      schemaVersion: CandidateSet.currentSchemaVersion,
      sourceDurationMs: 90000,
      createdAtUtc: DateTime.utc(2026, 11, 24),
      candidates: [
        ClipCandidate(
          id: 'clip_001',
          startMs: 1000,
          endMs: 5000,
          score: 90,
          title: 'First',
          hook: 'Hook',
          summary: 'Summary',
          explanations: const [],
          transcriptText: 'First segment',
          averageAudioEnergy: 0.5,
          peakVisualChange: 0.4,
        ),
        ClipCandidate(
          id: 'clip_002',
          startMs: 8000,
          endMs: 14000,
          score: 85,
          title: 'Second',
          hook: 'Hook',
          summary: 'Summary',
          explanations: const [],
          transcriptText: 'Second segment',
          averageAudioEnergy: 0.4,
          peakVisualChange: 0.3,
        ),
      ],
      transcriptEvidence: true,
      audioEvidence: true,
      visualEvidence: true,
      rankingEngine: 'test',
    );

ClipSequence makeSequence() => ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: const [
        ClipSequenceTrack(
          id: 'track_video_main',
          type: ClipSequenceTrackType.video,
          name: 'Main video',
          order: 0,
        ),
        ClipSequenceTrack(
          id: 'track_audio_main',
          type: ClipSequenceTrackType.audio,
          name: 'Main audio',
          order: 1,
        ),
        ClipSequenceTrack(
          id: 'track_overlay_main',
          type: ClipSequenceTrackType.overlay,
          name: 'Overlay',
          order: 2,
        ),
      ],
      clips: const [
        ClipSequenceItem(
          id: 'item_video_001',
          candidateId: 'clip_001',
          trackId: 'track_video_main',
          sourceStartMs: 1000,
          sourceEndMs: 3000,
          timelineStartMs: 0,
        ),
        ClipSequenceItem(
          id: 'item_video_002',
          candidateId: 'clip_002',
          trackId: 'track_video_main',
          sourceStartMs: 8000,
          sourceEndMs: 12000,
          timelineStartMs: 2000,
        ),
        ClipSequenceItem(
          id: 'item_audio_001',
          candidateId: 'clip_001',
          trackId: 'track_audio_main',
          sourceStartMs: 1000,
          sourceEndMs: 4000,
          timelineStartMs: 500,
        ),
        ClipSequenceItem(
          id: 'item_overlay_001',
          candidateId: 'clip_002',
          trackId: 'track_overlay_main',
          sourceStartMs: 9000,
          sourceEndMs: 11000,
          timelineStartMs: 1000,
        ),
      ],
    );

void main() {
  test('empty sequence starts with a persisted-ready main video track', () {
    final sequence = ClipSequence.empty(sourceDurationMs: 90000);
    sequence.validate(
      candidateSet: makeCandidates(),
      expectedSourceDurationMs: 90000,
    );
    expect(sequence.tracks, hasLength(1));
    expect(sequence.tracks.single.type, ClipSequenceTrackType.video);
    expect(sequence.clips, isEmpty);
  });

  test('sequence JSON round-trips tracks, source ranges and timeline placement', () {
    final original = makeSequence();
    original.validate(
      candidateSet: makeCandidates(),
      expectedSourceDurationMs: 90000,
    );
    final restored = ClipSequence.fromJson(
      Map<String, dynamic>.from(original.toJson()),
    );
    restored.validate(
      candidateSet: makeCandidates(),
      expectedSourceDurationMs: 90000,
    );
    expect(restored.tracks.map((track) => track.id), [
      'track_video_main',
      'track_audio_main',
      'track_overlay_main',
    ]);
    expect(restored.clips, hasLength(4));
    expect(restored.clips.first.durationMs, 2000);
    expect(restored.clips.first.timelineEndMs, 2000);
  });

  test('overlays and separate tracks may overlap in timeline time', () {
    final sequence = makeSequence();
    expect(
      () => sequence.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      returnsNormally,
    );
  });

  test('clips cannot overlap within the same track, including overlay tracks', () {
    final sequence = ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: const [
        ClipSequenceTrack(
          id: 'track_video_main',
          type: ClipSequenceTrackType.video,
          name: 'Main video',
          order: 0,
        ),
      ],
      clips: const [
        ClipSequenceItem(
          id: 'item_video_001',
          candidateId: 'clip_001',
          trackId: 'track_video_main',
          sourceStartMs: 1000,
          sourceEndMs: 3000,
          timelineStartMs: 0,
        ),
        ClipSequenceItem(
          id: 'item_video_002',
          candidateId: 'clip_002',
          trackId: 'track_video_main',
          sourceStartMs: 8000,
          sourceEndMs: 10000,
          timelineStartMs: 1500,
        ),
      ],
    );
    expect(
      () => sequence.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );
  });

  test('overlay clips can overlap other tracks but not items in the same sequence', () {
    final sequence = ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: const [
        ClipSequenceTrack(
          id: 'track_video_main',
          type: ClipSequenceTrackType.video,
          name: 'Video',
          order: 0,
        ),
        ClipSequenceTrack(
          id: 'track_overlay_main',
          type: ClipSequenceTrackType.overlay,
          name: 'Overlay',
          order: 1,
        ),
      ],
      clips: const [
        ClipSequenceItem(
          id: 'item_video_001',
          candidateId: 'clip_001',
          trackId: 'track_video_main',
          sourceStartMs: 1000,
          sourceEndMs: 3000,
          timelineStartMs: 0,
        ),
        ClipSequenceItem(
          id: 'item_overlay_001',
          candidateId: 'clip_002',
          trackId: 'track_overlay_main',
          sourceStartMs: 8000,
          sourceEndMs: 10000,
          timelineStartMs: 1000,
        ),
      ],
    );
    expect(
      () => sequence.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      returnsNormally,
    );

    final overlappingOverlay = ClipSequence(
      schemaVersion: sequence.schemaVersion,
      sourceDurationMs: sequence.sourceDurationMs,
      tracks: sequence.tracks,
      clips: [
        sequence.clips.last,
        const ClipSequenceItem(
          id: 'item_overlay_002',
          candidateId: 'clip_001',
          trackId: 'track_overlay_main',
          sourceStartMs: 1000,
          sourceEndMs: 3000,
          timelineStartMs: 1500,
        ),
      ],
    );
    expect(
      () => overlappingOverlay.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );
  });

  test('sequence rejects missing candidates and source trims outside candidate bounds', () {
    final tracks = makeSequence().tracks;
    final unknownCandidate = ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: tracks,
      clips: const [
        ClipSequenceItem(
          id: 'item_unknown_candidate',
          candidateId: 'clip_missing',
          trackId: 'track_video_main',
          sourceStartMs: 1000,
          sourceEndMs: 2000,
          timelineStartMs: 0,
        ),
      ],
    );
    expect(
      () => unknownCandidate.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );

    final outOfBounds = ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: tracks,
      clips: const [
        ClipSequenceItem(
          id: 'item_outside_candidate',
          candidateId: 'clip_001',
          trackId: 'track_video_main',
          sourceStartMs: 900,
          sourceEndMs: 3000,
          timelineStartMs: 0,
        ),
      ],
    );
    expect(
      () => outOfBounds.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );
  });

  test('sequence rejects duplicate track IDs, duplicate orders and duplicate clip IDs', () {
    final duplicateTracks = ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: const [
        ClipSequenceTrack(
          id: 'track_video_main',
          type: ClipSequenceTrackType.video,
          name: 'Video',
          order: 0,
        ),
        ClipSequenceTrack(
          id: 'track_video_main',
          type: ClipSequenceTrackType.video,
          name: 'Duplicate',
          order: 1,
        ),
      ],
      clips: const [],
    );
    expect(
      () => duplicateTracks.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );

    final duplicateOrders = ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: const [
        ClipSequenceTrack(
          id: 'track_video_main',
          type: ClipSequenceTrackType.video,
          name: 'Video',
          order: 0,
        ),
        ClipSequenceTrack(
          id: 'track_audio_main',
          type: ClipSequenceTrackType.audio,
          name: 'Audio',
          order: 0,
        ),
      ],
      clips: const [],
    );
    expect(
      () => duplicateOrders.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );

    final sequence = makeSequence();
    final duplicateClips = ClipSequence(
      schemaVersion: sequence.schemaVersion,
      sourceDurationMs: sequence.sourceDurationMs,
      tracks: sequence.tracks,
      clips: [sequence.clips.first, sequence.clips.first],
    );
    expect(
      () => duplicateClips.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );
  });

  test('sequence requires a video track and rejects unsupported track type JSON', () {
    final audioOnly = ClipSequence(
      schemaVersion: ClipSequence.currentSchemaVersion,
      sourceDurationMs: 90000,
      tracks: const [
        ClipSequenceTrack(
          id: 'track_audio_main',
          type: ClipSequenceTrackType.audio,
          name: 'Audio',
          order: 0,
        ),
      ],
      clips: const [],
    );
    expect(
      () => audioOnly.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );
    expect(
      () => ClipSequenceTrack.fromJson({
        'id': 'track_video_main',
        'type': 'unsupported',
        'name': 'Track',
        'order': 0,
      }),
      throwsFormatException,
    );
  });

  test('sequence source duration must match the owning project and candidates', () {
    expect(
      () => makeSequence().validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 80000,
      ),
      throwsFormatException,
    );
  });
}
