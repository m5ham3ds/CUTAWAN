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


  test('dip-to-black transition round-trips and requires adjacent video clips', () {
    final original = makeSequence();
    final clips = original.clips.map((clip) {
      if (clip.id != 'item_video_001') return clip;
      return ClipSequenceItem(
        id: clip.id,
        candidateId: clip.candidateId,
        trackId: clip.trackId,
        sourceStartMs: clip.sourceStartMs,
        sourceEndMs: clip.sourceEndMs,
        timelineStartMs: clip.timelineStartMs,
        transitionAfter: const ClipSequenceTransition(durationMs: 800),
      );
    }).toList(growable: false);
    final sequence = ClipSequence(
      schemaVersion: original.schemaVersion,
      sourceDurationMs: original.sourceDurationMs,
      tracks: original.tracks,
      clips: clips,
    );
    sequence.validate(
      candidateSet: makeCandidates(),
      expectedSourceDurationMs: 90000,
    );

    final restored = ClipSequence.fromJson(
      Map<String, dynamic>.from(sequence.toJson()),
    );
    restored.validate(
      candidateSet: makeCandidates(),
      expectedSourceDurationMs: 90000,
    );
    expect(restored.clips.first.transitionAfter?.type,
        ClipSequenceTransitionType.dipToBlack);
    expect(restored.clips.first.transitionAfter?.durationMs, 800);
  });

  test('transitions reject gaps, final clips, non-video tracks and overlong fades', () {
    final base = makeSequence();
    final first = base.clips.first;
    final second = base.clips[1];

    ClipSequence sequenceWith(
      List<ClipSequenceItem> clips,
      List<ClipSequenceTrack> tracks,
    ) => ClipSequence(
          schemaVersion: base.schemaVersion,
          sourceDurationMs: base.sourceDurationMs,
          tracks: tracks,
          clips: clips,
        );

    final gap = sequenceWith([
      ClipSequenceItem(
        id: first.id,
        candidateId: first.candidateId,
        trackId: first.trackId,
        sourceStartMs: first.sourceStartMs,
        sourceEndMs: first.sourceEndMs,
        timelineStartMs: first.timelineStartMs,
        transitionAfter: const ClipSequenceTransition(durationMs: 800),
      ),
      ClipSequenceItem(
        id: second.id,
        candidateId: second.candidateId,
        trackId: second.trackId,
        sourceStartMs: second.sourceStartMs,
        sourceEndMs: second.sourceEndMs,
        timelineStartMs: second.timelineStartMs + 100,
      ),
    ], [base.tracks.first]);
    expect(
      () => gap.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );

    final finalClip = sequenceWith([
      ClipSequenceItem(
        id: first.id,
        candidateId: first.candidateId,
        trackId: first.trackId,
        sourceStartMs: first.sourceStartMs,
        sourceEndMs: first.sourceEndMs,
        timelineStartMs: first.timelineStartMs,
        transitionAfter: const ClipSequenceTransition(durationMs: 800),
      ),
    ], [base.tracks.first]);
    expect(
      () => finalClip.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );

    final audioTrack = base.tracks[1];
    final audioClip = base.clips[2];
    final audioTransition = sequenceWith([
      ClipSequenceItem(
        id: audioClip.id,
        candidateId: audioClip.candidateId,
        trackId: audioClip.trackId,
        sourceStartMs: audioClip.sourceStartMs,
        sourceEndMs: audioClip.sourceEndMs,
        timelineStartMs: audioClip.timelineStartMs,
        transitionAfter: const ClipSequenceTransition(durationMs: 800),
      ),
    ], [base.tracks.first, audioTrack]);
    expect(
      () => audioTransition.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
      throwsFormatException,
    );

    final tooLong = sequenceWith([
      const ClipSequenceItem(
        id: 'item_short_001',
        candidateId: 'clip_001',
        trackId: 'track_video_main',
        sourceStartMs: 1000,
        sourceEndMs: 1400,
        timelineStartMs: 0,
        transitionAfter: ClipSequenceTransition(durationMs: 800),
      ),
      const ClipSequenceItem(
        id: 'item_short_002',
        candidateId: 'clip_001',
        trackId: 'track_video_main',
        sourceStartMs: 1500,
        sourceEndMs: 1900,
        timelineStartMs: 400,
        transitionAfter: ClipSequenceTransition(durationMs: 800),
      ),
      const ClipSequenceItem(
        id: 'item_short_003',
        candidateId: 'clip_001',
        trackId: 'track_video_main',
        sourceStartMs: 2000,
        sourceEndMs: 2400,
        timelineStartMs: 800,
      ),
    ], [base.tracks.first]);
    expect(
      () => tooLong.validate(
        candidateSet: makeCandidates(),
        expectedSourceDurationMs: 90000,
      ),
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
